# 🧬 生信分析核心备忘录 (RNA-Seq)

> **使用说明：**
> 1. 不要死记硬背，按 `Ctrl + F` 搜索关键词。
> 2. 遇到新的好用代码，随时在对应模块下用 ` ```语言名称 ` 的格式添加。

---

## 💻 一、 Linux 与环境生存指令 (Shell)

```bash
set -euo pipefail 
# e:err-exit、u:no-unset、o代表option，开启后面的pipefail选项。
# 该命令等同于set -o errexit\set -o nounset\set -o pipefail。
 
```
生信分析.docx
### 1. 高频基础命令
```bash
pwd              # print working directory 查看当前绝对路径
ls -lh           # list, long format, human-readable 列表显示，长格式，人类可读大小 (KB/MB/GB)
ls -l            # 列出详细清单
cd 文件夹名      # change directory 进入文件夹 (cd .. 是退回上一级)
mkdir 文件夹名   # make directory 新建文件夹
cp 源文件 目标   # copy 复制文件 (复制文件夹加 -r, recursive 递归)
mv 源文件 目标   # move 移动文件(在同目录下移动相当于 rename 重命名)
rm 文件名        # remove 删除文件 (危险操作！慎用！)
cd ~/miniconda3/bin # linux底层根目录
source ~/.bashrc # 刷新系统配置出现base
-c bioconda     # 指定从“生物信息软件仓库”找：kingfisher、sra-tools
-c conda-forge  # 指定从“通用高性能工具仓库”找：aria2、pigz
cp -r 00_Template Project_数据集 # 新的数据集标准化操作
free -h         # 查看物理内存
htop            # 目前所用CPU、内存量 sudo apt install htop
head/tail       # 用于快速查看大文件的前几行或后几行。如 head -n 10 file.gtf，用来确认文件格式有没有问题，而不必把整个文件加载到内存
grep            # 用于精准提取包含特定字符的行。如从注释文件里提取“外显子”的信息：grep "exon" reference.gtf
awk             # Linux 里最强大的列提取和矩阵处理语言。如提取一个矩阵的第 1 列和第 5 列：awk '{print $1, $5}' matrix.txt

```

### 2. 数据窥探命令
```bash
head 文件名      # head 头部，查看文件前 10 行 (查表头必备)
tail 文件名      # tail 尾部，查看文件最后 10 行
wc -l 文件名     # word count - lines 单词计数工具，-l 统计一共有多少行
grep "词" 文件   # global regular expression print 全局正则表达式打印 (快速搜索包含某词的行)
less -S 文件名   # less is more 分页器 (安全查看几个G的大文件，-S 防止长句子自动换行，按 q 退出)
```

### 3. Miniconda 隔离车间
```bash
# 环境就像一个个独立的实验室操作间。不要在默认的 (base) 大厅里混装工具！下载用 (kingfisher)，质控去杂用 (bioinfo)，画图用 (R_stat)，避免工具之间的依赖发生“化学爆炸”（版本冲突）。工具的安装必须在当前激活的环境下进行。
source ~/.bashrc                   # 激活conda设置
conda env list                     # environment list 环境列表 (查看所有环境)
conda create -n rnaseq_test        # create -name 创建，-n 指定名称为 rnaseq_test
conda activate rnaseq_test         # activate 激活 (进入指定的虚拟环境)
conda deactivate                   # deactivate 取消激活 (退出当前虚拟环境)
conda install -c bioconda 软件名    # install -channel 安装，-c 指定从 bioconda 频道/仓库下载
conda install -c bioconda multiqc  # 合并质控报告
```

### 数据极速获取 (Kingfisher 智能级联下载)
```bash
# 抛弃缓慢的 prefetch，利用 Kingfisher 配合 aria2 多线程，优先去欧洲 ENA 获取现成的 fastq.gz 成品。若无成品，则去 AWS/GCP 抓取原始 SRA，并在后台自动调用 fasterq-dump 和 pigz 极速完成解压与高压缩比打包。
# 安装包
conda install -c bioconda -c conda-forge kingfisher aria2 pigz sra-tools -y
# 切换环境
conda activate kingfisher

# 检查是否有直接下载的链接（终端运行）
# 1、确定存在可以直接下载的链接
# 在 02_Scripts 目录下新建一个文本文件，叫 ena_links.txt， 把链接粘贴进去，保存。
# 终端运行 bash 02_fetch_raw_data.sh -m direct -l ena_link.txt
# 2、不确定是否有现成的压缩包，手中只有SRR编号
在 02_Scripts 目录下新建一个文本文件，叫 srr_list.txt，把编号每行一个粘贴进去，保存。
终端运行 bash 02_fetch_raw_data.sh -m kingfisher -l srr-list.txt

# 样本下载
kingfisher get -r SRR34942226 -m ena-ftp aws-http prefetch -f fastq.gz --download-threads 16
# -m 设定获取优先级：欧洲ENA FTP -> AWS云 -> NCBI兜底
# -f 强制索要 fastq.gz 格式
# --download-threads 16 开启16线程狂奔
watch -n 5 "ls -lh /mnt/d/A/WSL_Microbiome_Project/01_RawData/样本号*"  # 查看fasterq-dump运行情况
```

### 4.自动化 for 循环模板（以fastp质控为例）
```bash
# 1. 定义包含所有样本编号的变量 (等号两边千万别加空格)
SAMPLES=("SRR111" "SRR112" "SRR113")

# 2. 获取动态路径
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
# $0：代表当前正在执行的脚本文件本身
# dirname：一个命令，作用是“取路径中的目录部分”。
# $( ... )：命令替换符：先运行括号里的命令，然后把结果“吐”出来给外面的变量。
# cd ... && pwd：cd 进入那个目录。&& 意思是“如果前面的成功了，就接着做后面的”。
RAW_DIR="$WORK_DIR/../01_RawData"
# $WORK_DIR：刚才拿到的脚本所在目录。
# /..：代表上一级目录。
# /01_RawData：进入上一级目录下的这个文件夹。

1. 原始数据质控与去接头 (fastp)
应用场景：上游分析第一步，拿到双端 .fastq.gz 数据后，切除机器接头并过滤低质量序列。
核心代码模板：
fastp \
  --in1 "$RAW_DIR/${i}_1.fastq.gz" \
  --in2 "$RAW_DIR/${i}_2.fastq.gz" \
  --out1 "$QC_DIR/${i}_clean_1.fq.gz" \
  --out2 "$QC_DIR/${i}_clean_2.fq.gz" \
  --json "$QC_DIR/${i}_fastp.json" \
  --html "$QC_DIR/${i}_fastp.html" \
  --thread 4 \
  --detect_adapter_for_pe
核心参数释义:
--thread 4：调用 4 个 CPU 线程加速
--detect_adapter_for_pe：双端测序自动检测接头（直接套用 nf-core 大牛参数，免去手动输入接头序列的麻烦）。
避坑与报错记录 (Bug Ledger)
Linux 里变量赋值的等号两边绝对不能有空格！（错误：DIR = "x"，正确：DIR="x"）。
syntax error near unexpected token ')'：不要只盯报错的那一行，上一行多打了一个反括号 ) 或引号 "。

### 合并质控报告
```bash
multiqc /mnt/d/A/WSL_Microbiome_Project/03_Results -o /mnt/d/A/WSL_Microbiome_Project/03_Results/MultiQC_Report
```


```bash
if [[ ! -f "$fastq1_gz" || ! -f "$fastq2_gz" ]]; then # 
```
### 5.给脚本执行权限，并后台运行
```bash
chmod +x download_data.sh

nohup ./download_data.sh > download.log 2>&1 &
```



```Bash
## 📊 二、 下游核心分析与绘图 (R 语言)
模块一：DESeq2 差异基因分析（找不同）
🎯 模块目标：比较两个组别（如 Treatment vs Control），找出具有统计学显著差异的基因。

📥 核心输入：
count_matrix：原始（未标准化） 的整数计数矩阵（行是基因，列是样本）。
group_info：样本分组信息表（行是样本，且顺序必须与矩阵列名完全一致）。

📤 核心输出：包含 log2FoldChange 和 padj（校正后P值）的差异基因表格。

⚠️ 避坑：对照组（Control）必须被强制设为参考水平（Reference level），否则上调/下调的结果会完全反过来！
🧠 必须记住的骨架代码：

```R
# 1. 指定对照组（极其重要）
group_info$Condition <- relevel(group_info$Condition, ref = "Control")
# 2. 构建 DESeq2 数据对象
dds <- DESeqDataSetFromMatrix(countData = count_matrix, colData = group_info, design = ~ Condition)
# 3. 运行核心算法（内部包含标准化和负二项分布检验）
dds <- DESeq(dds)
# 4. 提取对比结果
res <- results(dds, contrast = c("Condition", "Treatment", "Control"))


模块二：数据可视化（画火山图与热图）
🎯 模块目标：将枯燥的差异基因表格转化为 SCI 级别的直观图表。
📥 核心输入：
火山图：DESeq2 输出的带有打好标签（Up/Down）的 res_df。
热图：经过 vst() 标准化转换的表达矩阵（不能用原始 Counts 画热图！）。
📤 核心输出：直观展示差异倍数和 P 值的散点图（火山图），以及展示样本聚类情况的方块图（热图）。
🧠 代码：
```R
# --- 火山图 (ggplot2) ---
ggplot(res_df, aes(x = log2FoldChange, y = -log10(padj), color = Significance)) +
  geom_point() +  # 画散点
  geom_vline(xintercept = c(-0.58, 0.58)) + # 画垂直阈值线
  geom_hline(yintercept = -log10(0.05))     # 画水平阈值线
# --- 热图 (pheatmap) ---
vsd <- vst(dds, blind = FALSE)  # 必须先标准化！
pheatmap(assay(vsd)[top_genes, ], cluster_rows = TRUE, annotation_col = group_info)


模块三：功能富集分析（讲生物学故事）
🎯 模块目标：把找出来的一堆基因名字，翻译成它们参与了什么生命活动（GO）或疾病代谢通路（KEGG）。
📥 核心输入：显著差异基因的名称列表（一维向量）。
📤 核心输出：富集气泡图（Dotplot）和柱状图（Barplot）。
⚠️ 致命避坑：KEGG 极其“死板”，它绝大多数时候不认识英文缩写（Symbol，如 COX6B1），必须先用代码将其强制转换为纯数字的“身份证号”（Entrez ID）。
🧠 必须记住的骨架代码：
```R
# 1. GO 富集分析（直接用 Symbol）
ego <- enrichGO(gene = sig_genes, OrgDb = org.Mm.eg.db, keyType = 'SYMBOL', ont = "ALL")
dotplot(ego) # 画气泡图

# 2. KEGG 富集分析（必须先转换 Entrez ID）
kk <- enrichKEGG(gene = gene_entrez, organism = 'mmu') # mmu代表小鼠，hsa代表人类
barplot(kk)  # 画柱状图

模块四:PPI 蛋白互作网络分析
🎯 模块目标：基因不是孤立工作的。这个模块旨在探索差异基因在蛋白质层面的物理互作和逻辑联系，从成百上千个散沙般的基因中，找出处于网络最中心、牵一发而动全身的核心枢纽基因（Hub Genes）。
📥 核心输入：DESeq2 筛选出的显著差异基因列表（通常不需要全放，最好按 P 值或 Log2FC 排序，取前 200 - 500 个，否则图会变成毫无意义的“黑毛线球”）。
📤 核心输出：PPI 网络图，以及基于节点连接度（Degree）排名的 Top 10 Hub 基因列表（如你在 LASSO 之前输入的 Cox4i1, Ndufs8 等）。
⚠️ 致命避坑：
不要迷信“全代码化”：虽然 R 语言有 STRINGdb 或 igraph 包可以画网络图，但在真实的生信工业界，大家极少用 R 去做 PPI 的图。因为 R 画网络图极其痛苦且丑陋。业界金标准是：R 语言导出列表 -> STRING 网站算互作 -> Cytoscape 软件画图与算权重。 你代码里保留的“人工干预”步骤，说明你走的路线非常职业！

物种背景墙：在 STRING 数据库里，极其容易手滑选成人类（Homo sapiens），请务必再三确认为小鼠（Mus musculus）。

🧠 必须记住的骨架代码与流转流程：

对于 PPI 分析，你的“代码字典”里应该记录的是一半 R 代码，一半软件操作流程：

```R
# ========================================================
# 第一阶段：R 语言负责“准备食材”（提取差异基因）
# ========================================================
# 1. 提取符合条件的显著差异基因的名字
ppi_genes <- res_df %>% 
  filter(Significance != "Not Significant") %>% 
  pull(Symbol)
# 2. 导出为纯文本列表，方便去网站复制粘贴
write.table(ppi_genes, file = "PPI_input_genes.txt", 
            row.names = FALSE, col.names = FALSE, quote = FALSE)
# ========================================================
# 第二阶段：脱离 R 语言的行业标准流转步骤 (STRING + Cytoscape)
# ========================================================
# 1. 登录 STRING 网站 (Search -> Multiple Proteins)。
# 2. 粘贴 ppi_genes 列表，物种选 Mus musculus。
# 3. 核心设置：设置 Confidence Score (通常大于 0.4 或 0.7)，必须隐藏无连接的游离节点 (Hide disconnected nodes in the network)。
# 4. 导出表格：Export -> "string_interactions.tsv"。
# 5. 导入 Cytoscape 软件，进行美化排版。
# 6. 使用 CytoHubba 插件，算法选择 Degree (连通度)，计算出排名前 10 的 Hub 基因。
# 7. 拿到这 10 个基因的名字，回填到接下来的 LASSO 降维 R 代码中！

模块五：LASSO 回归特征筛选（找核心 Biomarker）
🎯 模块目标：面对成千上万个差异基因，利用机器学习降维，剔除冗余基因，锁定最具临床诊断价值的极少数核心基因（Hub Genes）。
📥 核心输入：
  x：纯数值类型的表达矩阵（注意：在 glmnet 中，行必须是样本，列必须是基因，需要用 t() 转置）。
  y：临床表型结果（如：0 代表低风险，1 代表高风险）。
📤 核心输出：非零系数的基因列表（通常是个位数）。
🧠 代码：
```R
# 1. 运行 LASSO 交叉验证 (alpha=1代表LASSO，0代表Ridge)
cv_fit <- cv.glmnet(x, y, family = "binomial", alpha = 1)
# 2. 提取临床泛化能力更强的保守模型系数 (lambda.1se)
lasso_model <- glmnet(x, y, family = "binomial", alpha = 1, lambda = cv_fit$lambda.1se)
# 3. 提取最终挑中的非零特征基因
coef(lasso_model)


模块六：临床模型评估（证明 Biomarker 真的有用）
🎯 模块目标：用上一步挑出的几个核心基因构建诊断公式，并多维度向临床医生证明这个公式的准确性和实用性。
📥 核心输入：包含样本风险标签（Risk）和所选 Hub 基因表达量的 Dataframe。
📤 核心输出：三大护法图（ROC曲线看准确度、Nomogram看临床直观概率、DCA看临床真实获益）。
⚠️ 致命避坑：把基因塞进 Logistic 回归前，强烈建议先用 scale() 对基因表达量进行标准化，否则表达量绝对值巨大的基因会错误地霸占权重。
🧠 代码：
```R
# 1. 构建 Logistic 回归模型 (lrm 或 glm)
f <- lrm(Risk ~ COX6B1 + NDUFS8 + NDUFA5, data = model_data)

# 2. 预测概率并画 ROC 曲线 (pROC 包)
pred_prob <- predict(f, type = "fitted")
roc_obj <- roc(model_data$Risk, pred_prob)
plot(roc_obj) # AUC越接近1越好

# 3. 画临床常用的列线图 Nomogram (rms 包)
nom <- nomogram(f, fun = plogis)
plot(nom)

# 4. 临床决策曲线 DCA (dcurves 包)
dca_fit <- dca(Risk ~ pred_prob, data = model_data)
plot(dca_fit)
```

## 三、 数据清洗辅助 (Python)
### 1. Pandas 批量合并文件模板
```python
import pandas as pd
import glob
import functools

# 获取当前文件夹下所有后缀为 _counts.txt 的文件
file_list = glob.glob("*_counts.txt")
dataframes = []

for file in file_list:
    sample_name = file.replace("_counts.txt", "")
    # 读取文件，指定分隔符为制表符
    df = pd.read_csv(file, sep='\t', header=None, names=['Gene_ID', sample_name])
    dataframes.append(df)

# 按基因名 (Gene_ID) 对齐合并所有样本表
final_matrix = functools.reduce(lambda left, right: pd.merge(left, right, on='Gene_ID', how='outer'), dataframes)

# 将 NA 值替换为 0 并导出
final_matrix.fillna(0, inplace=True)
final_matrix.to_csv("combined_count_matrix.csv", index=False)
```

---
## 📦 四、 Git 与 GitHub (作品集管理)
### 1. 代码版本控制基础指令
```bash
git init                           # 1. 初始化项目 (只需要在项目刚开始执行一次)
git add .                          # 2. 把当前修改的所有文件装进暂存箱
git commit -m "完成 fastp 批量清洗"  # 3. 给这次修改贴上说明标签
git push                           # 4. 一键推送到云端 GitHub (需提前绑定仓库)
```
### 2、每日github上传
```bash
# 1. 回到项目主仓库
cd /mnt/d/A/WSL_Microbiome_Project
# 2. 查看当前修改了哪些文件（养成好习惯，先看一眼红色的未提交文件）
git status
# 3. 将新项目脚本添加到暂存区（注意末尾的点代表当前目录所有更改，或者你也可以具体指定路径）
git add .
# 4. 提交更改，打上规范的工业级 Commit 标签
git commit -m "feat(QC): 完成全自动下载与 fastp 双端质控流水线构建"
# 5. 推送到远端 GitHub 仓库 
git push origin master
```


