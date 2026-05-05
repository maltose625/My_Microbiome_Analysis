#!/usr/bin/env bash
# =================================================================
# 脚本名称: 04_alignment.sh (WSL2 极限稳定版)
# 核心策略: Linux 原生索引 + 内存映射(--mm) + 物理提前解压
# =================================================================

set -euo pipefail
shopt -s nullglob

# --- 路径定义 ---
# 索引路径：必须指向 Linux 内部目录，否则 --mm 会报错
INDEX="$HOME/Databases/GRCm39/GRCm39_hisat2"

# 数据与结果：依然坚守在 D 盘原位
INPUT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results"
OUT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/02_Alignment"
mkdir -p "${OUT_DIR}"

SAMPLE="SRR8581315"

echo "================================================="
echo "🧬 正在处理样本: ${SAMPLE}"
echo "================================================="

# 0. 系统级准备
# 尝试释放 Linux 页面缓存，确保有最充裕的物理内存起步
echo "🧹 正在清理 Linux 系统内存缓存..."
sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# 1. 物理提前解压 (防止 HISAT2 内部解压导致的内存泄漏)
echo "📦 步骤 1/3: 正在从 D 盘物理解压测序数据..."
rm -f "${INPUT_DIR}/${SAMPLE}_temp_*.fq" # 清理残留
gunzip -c "${INPUT_DIR}/${SAMPLE}_clean_1.fq.gz" > "${INPUT_DIR}/${SAMPLE}_temp_1.fq"
gunzip -c "${INPUT_DIR}/${SAMPLE}_clean_2.fq.gz" > "${INPUT_DIR}/${SAMPLE}_temp_2.fq"

# 2. 核心比对与排序
# -p 2: 使用 2 个线程，兼顾速度与稳定性
# --mm: 开启内存映射，将庞大的索引按需调入内存，这是 24GB 机器不崩溃的关键
# 🧬 步骤 2/3: 启动 HISAT2 (撕掉限制，32GB Swap 硬刚模式)
hisat2 -p 2 \
    -x "${INDEX}" \
    -1 "${INPUT_DIR}/${SAMPLE}_temp_1.fq" \
    -2 "${INPUT_DIR}/${SAMPLE}_temp_2.fq" \
    --summary-file "${OUT_DIR}/${SAMPLE}_summary.txt" \
    | samtools sort -@ 2 -m 1G \
      -T "${OUT_DIR}/${SAMPLE}_temp_sort" \
      -o "${OUT_DIR}/${SAMPLE}_sorted.bam"

# 3. 扫尾工作
echo "🧹 步骤 3/3: 清理临时文本，释放磁盘空间..."
rm -f "${INPUT_DIR}/${SAMPLE}_temp_1.fq"
rm -f "${INPUT_DIR}/${SAMPLE}_temp_2.fq"

echo "✅ [SUCCESS] 样本 ${SAMPLE} 比对任务圆满完成！"