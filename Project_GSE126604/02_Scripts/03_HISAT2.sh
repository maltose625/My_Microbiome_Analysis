#!/usr/bin/env bash
# =============================================================================
# 脚本名称：HISAT2.sh
# 功能描述：构建 HISAT2 索引
# =============================================================================

set -euo pipefail
shopt -s nullglob

# 1. 确保在 base 环境中，并安装好 hisat2 软件(终端运行)
# conda activate base
# conda install -c bioconda hisat2 -y

# 2. 进入我们刚才存放解压后基因组和注释文件的目录
cd /mnt/d/A/WSL_Microbiome_Project/Databases/Mus_musculus/GRCm39

# 3. 【高阶操作：提取剪接位点和外显子】
# 从 GTF 说明书中把“基因断点”单独提取出来，喂给比对软件，能极大提升 RNA 比对的准确率
echo "正在提取剪接位点和外显子信息..."
hisat2_extract_splice_sites.py Mus_musculus.GRCm39.111.gtf > splicesites.txt
hisat2_extract_exons.py Mus_musculus.GRCm39.111.gtf > exons.txt

# 4. 【正式构建索引】
# -p 8 表示调用 8 个 CPU 核心火力全开
# 过程大概需要 30分钟 ~ 1小时，屏幕上会不断打印构建进度
echo "🚀 启动 HISAT2 索引构建..."
hisat2-build -p 6 --ss splicesites.txt --exon exons.txt \
    Mus_musculus.GRCm39.dna.primary_assembly.fa \
    GRCm39_hisat2