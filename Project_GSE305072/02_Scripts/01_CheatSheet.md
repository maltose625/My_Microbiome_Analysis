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
conda activate kingfisher # 激活kingfisher环境
-c bioconda     # 指定从“生物信息软件仓库”找：kingfisher、sra-tools
-c conda-forge  # 指定从“通用高性能工具仓库”找：aria2、pigz
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
在 02_Scripts 目录下新建一个文本文件，叫 ena_links.txt， 把链接粘贴进去，保存。
终端运行 bash 02_fetch_raw_data.sh -m direct -l ena_link.txt
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


# 2. 循环处理每一个样本
for i in "${SAMPLES[@]}"; do # “对于 (for) 数组 SAMPLES 里的 每一个 ([@]) 成员，请暂时把它叫作 i，然后 开始执行 (do) 以下操作……”
    echo "========================================"
    echo "正在处理样本: $i"
    echo "========================================"

    # 注意：下载下来的文件名是 SRRXXXX_1.fastq.gz 的格式
    # 如果你的文件名没有 .gz 后缀，请把下面代码里的 .gz 删掉
    fastp \
        --in1 "$RAW_DIR/${i}_1.fastq.gz" \
        --in2 "$RAW_DIR/${i}_2.fastq.gz" \
        --out1 "$QC_DIR/${i}_clean_1.fq.gz" \
        --out2 "$QC_DIR/${i}_clean_2.fq.gz" \
        --json "$QC_DIR/${i}_fastp.json" \
        --html "$QC_DIR/${i}_fastp.html" \
        --thread 4 \
        --detect_adapter_for_pe
done
```
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



---
## 📊 二、 下游核心分析与绘图 (R 语言)
### 1. DESeq2 差异表达分析
```R
# 加载依赖包
library(DESeq2)

# 读取表达矩阵与样本分组信息 (假设第一列是基因名)
count_data <- read.csv("count_matrix.csv", row.names = 1)
col_data <- read.csv("sample_info.csv", row.names = 1)

# 构建 DESeq2 核心对象
dds <- DESeqDataSetFromMatrix(countData = count_data, 
                              colData = col_data, 
                              design = ~ condition)
dds <- DESeq(dds)

# 提取 HFD 组对比 WT 组的差异结果
res <- results(dds, contrast=c("condition", "HFD", "WT"))

# 保存输出到本地
write.csv(res, "DESeq2_results.csv")
```

### 2. ggplot2 绘制高水平火山图
```R
library(ggplot2)

# 读取差异分析结果
res_data <- read.csv("DESeq2_results.csv")

# 设定阈值打标签 (P值<0.05 且 |log2FC|>1)
res_data$Significance <- "Not Significant"
res_data$Significance[res_data$padj < 0.05 & res_data$log2FoldChange > 1] <- "Up"
res_data$Significance[res_data$padj < 0.05 & res_data$log2FoldChange < -1] <- "Down"

# 绘制散点图
ggplot(data = res_data, aes(x = log2FoldChange, y = -log10(padj), color = Significance)) +
  geom_point(alpha = 0.8, size = 1.5) +  
  scale_color_manual(values = c("Up" = "#d73027", "Down" = "#4575b4", "Not Significant" = "grey")) + 
  theme_minimal() + 
  labs(title = "Volcano Plot: HFD vs WT", x = "Log2 Fold Change", y = "-Log10(P-value)") +
  geom_vline(xintercept = c(-1, 1), linetype = "dashed", color = "black") + 
  geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "black")
```

---

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


