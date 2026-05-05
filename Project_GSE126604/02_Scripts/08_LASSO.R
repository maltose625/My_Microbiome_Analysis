# ==========================================
# 机器学习：LASSO 回归特征基因筛选
# ==========================================

# 清除环境
rm(list = ls())
options(stringsAsFactors = FALSE)

# 安装核心包
# if(!require("glmnet")) install.packages("glmnet")
# if(!require("GEOquery")) BiocManager::install("GEOquery")
# install.packages("data.table")
library(glmnet)
library(GEOquery)
library(data.table)
library(dplyr)

cat("🚀 LASSO 特征筛选流程启动...\n")

# ==========================================
# 1. 读取 GEO 临床表型数据
# ==========================================
file_path <- "D:/A/WSL/WSL/GSE126604-supplyment/GSE193066_series_matrix.txt.gz"

cat("📥 读取 GEO 临床表型数据...\n")
gset <- getGEO(filename = file_path, getGPL = FALSE)

pheno_data <- pData(gset)

# ==========================================
# 2. 清洗临床表型数据
# ==========================================
cat("🧹 清洗临床表型数据...\n")

# 保留 1st biopsy 样本
valid_samples_idx <- grepl("1st", pheno_data$`biopsy:ch1`, ignore.case = TRUE)
valid_pheno <- pheno_data[valid_samples_idx, , drop = FALSE]

cat("有效样本数量:", nrow(valid_pheno), "\n")

# 提取风险标签
risk_col_name <- "pls-nafld-based risk prediction at 1st biopsy:ch1"
y <- ifelse(valid_pheno[[risk_col_name]] == "high-risk", 1, 0)

cat("High-risk 样本数:", sum(y), " | Low-risk 样本数:", sum(y == 0), "\n")

# ==========================================
# 3. 读取表达矩阵（.gct 文件）
# ==========================================
expr_file_path <- "D:/A/WSL/WSL/GSE126604-supplyment/GSE193066_NAFLD.HUn164.gct.gz"

cat("📥 读取表达矩阵 (.gct)...\n")
real_expr_df <- fread(expr_file_path, 
                      skip = 2, 
                      header = TRUE, 
                      data.table = FALSE)

# 处理行名（基因）
rownames(real_expr_df) <- real_expr_df[[1]]   # 第一列通常是 gene_name 或 gene_id
expr_matrix <- as.matrix(real_expr_df[, -1])

cat("表达矩阵维度:", dim(expr_matrix), "\n")
cat("表达矩阵前6个样本名:\n")
print(colnames(expr_matrix)[1:6])

# ==========================================
# 4. 样本精准对齐（核心改进部分）
# ==========================================
cat("\n🔄 执行样本ID对齐...\n")

# 使用 title 列作为匹配桥梁（HUnafld001 等）
common_samples <- intersect(colnames(expr_matrix), valid_pheno$title)

cat("表达矩阵样本数 :", ncol(expr_matrix), "\n")
cat("临床有效样本数 :", nrow(valid_pheno), "\n")
cat("成功匹配样本数 :", length(common_samples), "\n")

if(length(common_samples) == 0) {
  stop("❌ 未找到共同样本，请检查数据！")
}

# 按表达矩阵顺序进行对齐
clean_expr_matrix <- expr_matrix[, common_samples, drop = FALSE]

# 对齐临床表型
rownames(valid_pheno) <- valid_pheno$title          # 关键：把 title 设为行名
clean_pheno <- valid_pheno[common_samples, , drop = FALSE]

# 最终检查
if(all(colnames(clean_expr_matrix) == rownames(clean_pheno))) {
  cat("✅ 样本对齐成功！最终用于分析的样本数：", ncol(clean_expr_matrix), "\n")
} else {
  cat("⚠️  对齐后顺序不一致，请检查！\n")
}

# ==========================================
# 5. 为 LASSO 准备数据
# ==========================================
x <- t(clean_expr_matrix)   # 转置：样本为行，基因为列（glmnet 要求格式）

cat("最终建模数据维度 -> 样本:", nrow(x), " | 基因:", ncol(x), "\n")

# ==========================================
# 5. 跨物种靶点映射与矩阵提取（优化版）
# ==========================================
cat("🧬 正在提取小鼠 Hub Genes 的人类同源特征...\n")

# 小鼠 Hub Genes（请根据 Cytoscape 结果自行补充完整）
mouse_hub_genes <- c("Cox4i1", "Cox6b1", "Cox6a1", "Ndufs8", "Cox5a",
                     "Ndufa5", "Cox7c", "Uqcrfs1", "Ndufa6", "Ndufb9")

# 小鼠→人类基因名转换（更稳健的方式）
human_hub_genes <- toupper(mouse_hub_genes)

# 严格检查基因是否存在
available_genes <- human_hub_genes[human_hub_genes %in% rownames(clean_expr_matrix)]
missing_genes   <- setdiff(human_hub_genes, available_genes)

if(length(missing_genes) > 0) {
  cat("⚠️ 警告：以下", length(missing_genes), "个基因在人类表达矩阵中未找到：\n")
  print(missing_genes)
  cat("提示：可能需要检查基因别名或使用 ortholog 数据库（如 HGNC、Ensembl）进行精确映射。\n")
}

if(length(available_genes) == 0) {
  stop("❌ 错误：没有找到任何匹配的人类同源基因，请检查基因名！")
}

cat("✅ 成功匹配基因数量：", length(available_genes), "\n")

# 提取目标基因表达矩阵
target_matrix <- clean_expr_matrix[available_genes, , drop = FALSE]

# 转置为 glmnet 要求的格式：行=样本，列=基因
x <- t(target_matrix)
x <- as.matrix(x)                    # 确保是纯数值矩阵
class(x) <- "numeric"

# 最终数据检查
cat("🎯 LASSO 输入数据准备完成！\n")
cat("   样本数 =", nrow(x), " | 特征基因数 =", ncol(x), "\n")
cat("   High-risk (1) =", sum(y==1), " | Low-risk (0) =", sum(y==0), "\n")

# ==========================================
# 6. 正式运行 LASSO + 交叉验证（强烈推荐改进版）
# ==========================================
cat("\n🔥 启动 LASSO Logistic Regression 交叉验证...\n")

set.seed(123)   # 保证结果可重复

cv_fit <- cv.glmnet(x, y, 
                    family = "binomial", 
                    alpha = 1,           # 1 = LASSO
                    nfolds = 10, 
                    type.measure = "class", 
                    standardize = TRUE)  # 推荐标准化

# 保存交叉验证曲线
pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/06_LASSO/LASSO_CrossValidation_GSE193066.pdf", width = 8, height = 6)
plot(cv_fit, main = "LASSO Cross-Validation (GSE193066)")
dev.off()

# 同时考虑 lambda.min 和 lambda.1se（更简约模型）
best_lambda_min <- cv_fit$lambda.min
best_lambda_1se <- cv_fit$lambda.1se

cat("最佳 lambda (min)  :", best_lambda_min, "\n")
cat("最佳 lambda (1se) :", best_lambda_1se, "\n")

# 使用 lambda.1se（推荐，更少的特征，更好的泛化能力）
lasso_model <- glmnet(x, y, 
                      family = "binomial", 
                      alpha = 1, 
                      lambda = best_lambda_1se)

# 提取非零系数
lasso_coef <- coef(lasso_model)
non_zero_idx <- which(lasso_coef != 0)
selected_features <- rownames(lasso_coef)[non_zero_idx]
selected_features <- selected_features[selected_features != "(Intercept)"]

cat("\n", strrep("=", 50), "\n", sep = "")
cat("🏆 LASSO 最终筛选出的核心诊断标志物 (lambda.1se)：\n")
if(length(selected_features) > 0) {
  print(selected_features)
  cat("共筛选出", length(selected_features), "个特征基因\n")
} else {
  cat("警告：本次未筛选出任何特征基因，可尝试使用 lambda.min\n")
}

# 保存结果
write.table(data.frame(Gene = selected_features), 
            "D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/06_LASSO/LASSO_Selected_Hub_Genes.txt", 
            row.names = FALSE, quote = FALSE, sep = "\t")

cat("结果已保存至：LASSO_Selected_Hub_Genes.txt\n")
