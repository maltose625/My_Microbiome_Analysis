#!/usr/bin/env bash
# =================================================================
# 脚本名称: 05_quantification.sh
# 核心功能: 使用 featureCounts 对 BAM 文件进行基因水平定量
# =================================================================

set -euo pipefail

# 1. 定义路径
# 你的注释文件 (基因坐标本)
GTF="/mnt/d/A/WSL_Microbiome_Project/Databases/Mus_musculus/GRCm39/Mus_musculus.GRCm39.111.gtf"
# 你的输入 BAM 文件目录
BAM_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/02_Alignment"
# 输出目录
OUT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/03_Quantification"
mkdir -p "${OUT_DIR}"

SAMPLE="SRR8581315"

echo "================================================="
echo "📊 开始对样本进行基因定量: ${SAMPLE}"
echo "================================================="

# 2. 运行 featureCounts
# -T 4: 使用 4 个线程
# -p: 声明这是双端测序数据 (Paired-end)
# -t exon: 只统计落在外显子 (exon) 上的 Reads
# -g gene_id: 最终以 gene_id (基因) 为单位进行汇总
# -a: 指定 GTF 注释文件
# -o: 输出的表达矩阵文件名

featureCounts -T 4 -p \
    -t exon -g gene_id \
    -a "${GTF}" \
    -o "${OUT_DIR}/${SAMPLE}_counts.txt" \
    "${BAM_DIR}/${SAMPLE}_sorted.bam"

echo "✅ [SUCCESS] 基因定量完成！表达矩阵已生成！"