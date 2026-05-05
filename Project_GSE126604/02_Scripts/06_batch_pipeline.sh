#!/usr/bin/env bash
# =================================================================
# 脚本名称: 06_batch_pipeline.sh
# 核心功能: 6 样本全自动流水线 (解压 -> 比对 -> 过滤已完成 -> 全局定量)
# =================================================================

set -euo pipefail
shopt -s nullglob

# 1. 定义你的所有样本名 (请核对这 6 个名字是否与你的文件一致)
SAMPLES=(
    "SRR8581315"
    "SRR8581316"
    "SRR8581317"
    "SRR8581318"
    "SRR8581319"
    "SRR8581320"
)

# 2. 路径定义 (保持我们之前调优的绝对稳定路径)
INDEX="$HOME/Databases/GRCm39/GRCm39_hisat2"
GTF="/mnt/d/A/WSL_Microbiome_Project/Databases/Mus_musculus/GRCm39/Mus_musculus.GRCm39.111.gtf"

INPUT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results"
ALIGN_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/02_Alignment"
QUANT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/03_Quantification"

mkdir -p "${ALIGN_DIR}"
mkdir -p "${QUANT_DIR}"

echo "================================================="
echo "🚀 开启 6 样本全自动大循环批处理..."
echo "================================================="

# 3. 循环比对每个样本
for SAMPLE in "${SAMPLES[@]}"; do
    echo "-------------------------------------------------"
    echo "🧬 正在处理样本: ${SAMPLE} ..."
    
    # 【智能防呆机制】检查是否已经生成过 BAM，避免重复跑！
    if [ -f "${ALIGN_DIR}/${SAMPLE}_sorted.bam" ]; then
        echo "⏭️ 发现 ${SAMPLE} 的 BAM 文件已存在，为您自动跳过比对步骤！"
        continue
    fi

    # 解压
    echo "📦 物理解压 ${SAMPLE} (D 盘读写中)..."
    rm -f "${INPUT_DIR}/${SAMPLE}_temp_*.fq"
    gunzip -c "${INPUT_DIR}/${SAMPLE}_clean_1.fq.gz" > "${INPUT_DIR}/${SAMPLE}_temp_1.fq"
    gunzip -c "${INPUT_DIR}/${SAMPLE}_clean_2.fq.gz" > "${INPUT_DIR}/${SAMPLE}_temp_2.fq"

    # 比对
    echo "⚙️ 开始 HISAT2 比对 (单样本稳态内存 < 8GB)..."
    hisat2 -p 2 \
        -x "${INDEX}" \
        -1 "${INPUT_DIR}/${SAMPLE}_temp_1.fq" \
        -2 "${INPUT_DIR}/${SAMPLE}_temp_2.fq" \
        --summary-file "${ALIGN_DIR}/${SAMPLE}_summary.txt" \
        | samtools sort -@ 2 -m 1G \
          -T "${ALIGN_DIR}/${SAMPLE}_temp_sort" \
          -o "${ALIGN_DIR}/${SAMPLE}_sorted.bam"

    # 清理
    echo "🧹 清理 ${SAMPLE} 的临时庞然大物..."
    rm -f "${INPUT_DIR}/${SAMPLE}_temp_1.fq"
    rm -f "${INPUT_DIR}/${SAMPLE}_temp_2.fq"
done

echo "================================================="
echo "✅ 所有样本的 BAM 文件均已就绪！开始全局大融合..."
echo "================================================="

# 4. 全局定量 (featureCounts 的终极魔法)
echo "📊 正在生成最终的 6 样本全局基因表达汇总矩阵..."

# 动态获取刚才生成的所有 bam 文件路径
BAM_FILES=("${ALIGN_DIR}"/*_sorted.bam)

# 喂给 featureCounts 一次性统计
featureCounts -T 4 -p \
    -t exon -g gene_id \
    -a "${GTF}" \
    -o "${QUANT_DIR}/All_Samples_counts.txt" \
    "${BAM_FILES[@]}"

echo "🎉 [SUCCESS] 伟大的工程竣工！去 ${QUANT_DIR} 提取你的终极矩阵吧！"