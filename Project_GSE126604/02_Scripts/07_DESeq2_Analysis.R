# =========================================================================
# 脚本名称: 07_DESeq2_Analysis.R
# 核心功能: 从特征计数矩阵(Counts)到差异表达基因(DEGs)与火山图可视化
# =========================================================================

# 清除之前环境
rm(list = ls())
options(stringsAsFactors = FALSE)

# ==========================================
# 1.加载必要包
# ==========================================
# if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
# BiocManager::install("DESeq2")
# BiocManager::install("ggplot2")
library(DESeq2)
library(ggplot2)

# ==========================================
# 2.数据准备
# ==========================================
# 设置项目基础路径（推荐使用相对路径或 file.path，提高兼容性）
base_dir <- "D:/A/WSL_Microbiome_Project/Project_GSE126604"

# 读取原始计数矩阵
count_file <- file.path(base_dir, "03_Results/03_Quantification/All_Samples_counts.txt")
raw_counts <- read.table(count_file, 
                         header = TRUE, 
                         row.names = 1, 
                         sep = "\t", 
                         )

# 保留计数列，去除前5列注释信息（Chr, Start, End, Strand, Length）
count_matrix <- raw_counts[, -c(1:5)]

# 设置样本名并计数
colnames(count_matrix) <- c("Ctrl_1", "Ctrl_2", "Ctrl_3", 
                            "Treat_1", "Treat_2", "Treat_3")

cat("计数矩阵加载完成，共有", nrow(count_matrix), "个基因，", 
    ncol(count_matrix), "个样本。\n")

# ==========================================
# 3. 创建样本分组信息 (group_info)
# ==========================================
group_info <- data.frame(
  row.names = colnames(count_matrix),
  Condition = factor(rep(c("Control", "Treatment"), each = 3),
                     levels = c("Control", "Treatment"))
)

# 明确设置 Control 为参考水平（非常重要）
group_info$Condition <- relevel(group_info$Condition, ref = "Control")

# 安全性检查
if (nrow(group_info) != ncol(count_matrix)) {
  stop("样本数量与分组信息不匹配！")
}

# ==========================================
# 4.构建 DESeq2 模型与运行计算
# ==========================================
dds <- DESeqDataSetFromMatrix(countData = count_matrix,
                              colData = group_info,
                              design = ~ Condition)

# 过滤掉那些在所有样本中几乎不表达的“幽灵基因” (提高计算速度和统计学效能)
keep <- rowSums(counts(dds) >= 10) >= 3   # 至少在 3 个样本中表达量 >= 10
dds <- dds[keep, ]
cat("✅ 低表达基因过滤完成，保留", nrow(dds), "个基因用于分析。\n")

# 运行 DESeq2 核心算法 (标准化 -> 离散度估计 -> 负二项分布检验)
# 这一步包含了极其复杂的统计学原理，但 R 语言只需要这一行代码
dds <- DESeq(dds)
cat("✅ DESeq2 分析完成。\n")

# ==========================================
# 5.提取结果与数据准备
# ==========================================
res <- results(dds, 
               contrast = c("Condition", "Treatment", "Control"),
               alpha = 0.05)

res_df <- as.data.frame(res) # 仅执行一次

# 根据阈值打标签 (注意：这里直接处理，保留 NA 行，将 NA 视作不显著)
res_df$Significance <- "Not Significant"
# 使用 which() 避免 NA 带来的逻辑判断问题
res_df$Significance[which(res_df$padj < 0.05 & res_df$log2FoldChange > 0.58)] <- "Up-regulated"
res_df$Significance[which(res_df$padj < 0.05 & res_df$log2FoldChange < -0.58)] <- "Down-regulated"

# 提取真正显著的差异基因表格用于保存 (局部剔除 NA)
sig_res_df <- res_df[res_df$Significance != "Not Significant", ]
out_dir <- file.path(base_dir, "03_Results/04_DESeq2_Analysis")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
write.csv(sig_res_df, 
          file = file.path(out_dir, "DESeq2_Significant_Results.csv"), 
          row.names = TRUE)

# ==========================================
# 5.5 基因身份证(Ensembl)转换为俗名(Symbol)
# ==========================================
library(org.Mm.eg.db)
ensembl_ids <- gsub("\\..*", "", rownames(res_df))

res_df$Symbol <- mapIds(org.Mm.eg.db,
                        keys = ensembl_ids,
                        column = "SYMBOL",      
                        keytype = "ENSEMBL",    
                        multiVals = "first")    

res_df$Symbol[is.na(res_df$Symbol)] <- rownames(res_df)[is.na(res_df$Symbol)]

# Top 10 提取逻辑 ---
# 1. 提取显著上调 Top 10
up_genes <- res_df[res_df$Significance == "Up-regulated", ]
top10_up <- up_genes[order(up_genes$padj), ]
if(nrow(top10_up) > 10) top10_up <- top10_up[1:10, ] # 防止显著基因不足10个时产生 NA

# 2. 提取显著下调 Top 10
down_genes <- res_df[res_df$Significance == "Down-regulated", ]
top10_down <- down_genes[order(down_genes$padj), ]
if(nrow(top10_down) > 10) top10_down <- top10_down[1:10, ]

top_genes_combined <- rbind(top10_up, top10_down)

# 6. 绘制高质量火山图
# ==========================================
cat("🎨 正在绘制火山图...\n")

volcano_plot <- ggplot(res_df, aes(x = log2FoldChange, 
                                   y = -log10(padj), 
                                   color = Significance)) +
  geom_point(alpha = 0.75, size = 1.8) +
  scale_color_manual(values = c("Up-regulated"   = "#e41a1c",   # 红色
                                "Down-regulated" = "#377eb8",   # 蓝色
                                "Not Significant"= "grey70")) + # 灰色
  theme_minimal(base_size = 14) +
  geom_vline(xintercept = c(-0.58, 0.58), 
             linetype = "dashed", color = "black", linewidth = 0.5) +
  geom_hline(yintercept = -log10(0.05), 
             linetype = "dashed", color = "black", linewidth = 0.5) +
  labs(title = "Volcano Plot: Treatment vs Control",
       subtitle = "DESeq2 Analysis (padj < 0.05, |log2FC| > 0.58)",
       x = expression(Log[2] * " Fold Change"),
       y = expression(-Log[10] * " Adjusted P-value")) +
  theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
        plot.subtitle = element_text(hjust = 0.5, size = 12),
        legend.title = element_blank(),
        legend.position = "top")

# 显示图像
print(volcano_plot)

# 保存高分辨率 PDF
ggsave(file.path(out_dir, "Volcano_Plot_HighRes.pdf"), 
       plot = volcano_plot, 
       width = 9, height = 7, dpi = 300)

cat("✅ 火山图绘制并保存完成！\n")
cat("🎉 DESeq2 差异表达分析流程全部执行完毕。\n")
# ==========================================
# 7. 全局表达聚类热图 (Heatmap)
# ==========================================
library(pheatmap)

vsd <- vst(dds, blind = FALSE)
vst_matrix <- assay(vsd)

top50_var_genes <- head(order(rowVars(vst_matrix), decreasing = TRUE), 50)
plot_matrix <- vst_matrix[top50_var_genes, ]

# 此时 res_df 没有经过全局 na.omit，维度和行名包含了所有的 dds 基因
# 映射 Symbol 不会产生报错
rownames(plot_matrix) <- res_df[rownames(plot_matrix), "Symbol"]

# 绘制热图
pheatmap(plot_matrix, 
         cluster_rows = TRUE, 
         cluster_cols = TRUE, 
         annotation_col = group_info, 
         show_colnames = TRUE, 
         show_rownames = TRUE,
         scale = "row", 
         color = colorRampPalette(c("#377eb8", "white", "#e41a1c"))(100),
         main = "Top 50 Most Variable Genes Heatmap",
         filename = file.path(out_dir, "Global_Clustering_Heatmap.pdf"),
         width = 8, height = 10)

cat("✅ 完美！标签火山图与聚类热图彻底修复完毕！\n")

# ==========================================
# 8. 功能富集分析 (GO & KEGG) - clusterProfiler
# ==========================================
# 首次运行请去掉下面两行的注释以安装核心包
# BiocManager::install("clusterProfiler")
# BiocManager::install("enrichplot")
library(clusterProfiler)
library(enrichplot)

cat("🚀 启动功能富集分析管线...\n")
# ==========================================
# 8.1 提取目标基因并进行双重 ID 转换
# ==========================================
# 1. 提取所有显著差异基因的 Symbol (上调 + 下调统包分析)
sig_genes <- res_df$Symbol[res_df$Significance %in% c("Up-regulated", "Down-regulated")]
sig_genes <- na.omit(sig_genes)

# 2. 将 Symbol 转换为 Entrez ID (KEGG 分析底层极其依赖数值型的 Entrez ID)
cat("🔤 正在转换为 KEGG 专属 Entrez ID...\n")
gene_entrez <- mapIds(org.Mm.eg.db,
                      keys = sig_genes,
                      column = "ENTREZID",
                      keytype = "SYMBOL",
                      multiVals = "first")
gene_entrez <- na.omit(gene_entrez)

# ==========================================
# 8.2 GO 富集分析 (Gene Ontology)
# ==========================================
cat("📊 正在运行 GO 富集分析 (涵盖 BP生物学过程, MF分子功能, CC细胞组分)...\n")
# 这一步计算量较大，可能需要等待十几秒
ego <- enrichGO(gene          = sig_genes,
                OrgDb         = org.Mm.eg.db,
                keyType       = 'SYMBOL',
                ont           = "ALL",      # "ALL" 表示一次性跑完三大分类
                pAdjustMethod = "BH",       # 多重假设检验校正方法
                pvalueCutoff  = 0.05,       # 极其严格的显著性截断值
                qvalueCutoff  = 0.2)

# 绘制 GO 分面气泡图 (Dotplot)
go_dotplot <- dotplot(ego, showCategory = 8, split="ONTOLOGY") +
  facet_grid(ONTOLOGY~., scale="free") +    # 将图按 BP, CC, MF 切分为三块
  theme_minimal(base_size = 12) +
  labs(title = "GO Enrichment Analysis") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

print(go_dotplot)
ggsave(file.path(out_dir, "GO_Enrichment_Dotplot.pdf"), plot = go_dotplot, width = 10, height = 9)

# ==========================================
# 8.3 KEGG 通路富集分析
# ==========================================
cat("🧬 正在运行 KEGG 经典代谢与信号通路分析...\n")
kk <- enrichKEGG(gene         = gene_entrez,
                 organism     = 'mmu',      # 核心参数：mmu 代表小鼠 (Mus musculus)
                 pvalueCutoff = 0.05)

# 将 KEGG 结果中的 Entrez ID 翻译回人类可读的 Symbol (为了图表美观)
kk <- setReadable(kk, OrgDb = org.Mm.eg.db, keyType="ENTREZID")

# 绘制 KEGG 柱状图 (Barplot)
kegg_barplot <- barplot(kk, showCategory = 15) +
  theme_minimal(base_size = 12) +
  scale_fill_gradient(low = "#e41a1c", high = "#377eb8") + # 优化配色
  labs(title = "KEGG Pathway Enrichment") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

print(kegg_barplot)
ggsave(file.path(out_dir, "KEGG_Enrichment_Barplot.pdf"), plot = kegg_barplot, width = 9, height = 7)

# 保存富集分析的纯文本表格结果（后续写文章查具体基因列表极其有用）
write.csv(as.data.frame(ego), file.path(out_dir, "GO_Enrichment_Results.csv"), row.names = FALSE)
write.csv(as.data.frame(kk), file.path(out_dir, "KEGG_Enrichment_Results.csv"), row.names = FALSE)

cat("✅ 富集分析全流程竣工！数据已入库，请查看气泡图与柱状图。\n")
