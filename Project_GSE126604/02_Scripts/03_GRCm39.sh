#!/usr/bin/env bash
# =============================================================================
# 脚本名称：run_pipeline.sh
# 功能描述：下载 GRCm39 参考基因组序列和注释文件
# =============================================================================

set -euo pipefail
shopt -s nullglob

# 1. 创建并进入专门存放公共数据库的目录
mkdir -p /mnt/d/A/WSL_Microbiome_Project/Databases/Mus_musculus/GRCm39
cd /mnt/d/A/WSL_Microbiome_Project/Databases/Mus_musculus/GRCm39

# 2. 下载参考基因组序列 (Primary Assembly, 约 800MB，解压后约 3GB)
echo "开始下载基因组 FASTA..."
wget -c https://ftp.ensembl.org/pub/release-111/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna.primary_assembly.fa.gz

# 3. 下载基因组注释文件 (GTF, 约 30MB)
echo "开始下载基因组注释文件..."
wget -c https://ftp.ensembl.org/pub/release-111/gtf/mus_musculus/Mus_musculus.GRCm39.111.gtf.gz

# 4. 解压它们 (比对软件建索引时通常需要解压后的文本文件)
gzip -d *.gz

