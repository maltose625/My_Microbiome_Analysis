#!/usr/bin/env bash
# =============================================================================
# 脚本名称：alignment.sh
# 功能描述：进行转录组全基因组比对
# =============================================================================

set -euo pipefail
shopt -s nullglob

echo "================================================="
echo "🚀 启动 HISAT2 转录组全基因组比对流水线"
echo "================================================="

# 1. 定义绝对路径
# 数据库索引前缀 (注意：只要写到 GRCm39_hisat2 即可，绝对不能加 .ht2 后缀！)
INDEX="/mnt/d/A/WSL_Microbiome_Project/Databases/Mus_musculus/GRCm39/GRCm39_hisat2"

# 输入：质控后的干净数据目录
INPUT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results"

# 输出：在结果目录下新建一个专门存放比对文件的子文件夹
OUT_DIR="/mnt/d/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/02_Alignment"
mkdir -p ${OUT_DIR}


# 2. 我们先拿其中一个样本 (SRR8581315) 来进行单机实战测试
# 铁律：在跑通之前，永远不要直接写大循环，避免批量报错！
SAMPLE="SRR8581315"
echo "正在处理测试样本: ${SAMPLE} ..."


# 3. 核心比对命令
# -p 6 : 给你留 2 个核心保命，坚决防止 Windows 白屏假死！
# --summary-file : 输出极其重要的比对率报告（后面写文章要用）
hisat2 -p 6 \
    -x ${INDEX} \
    -1 ${INPUT_DIR}/${SAMPLE}_clean_1.fq.gz \
    -2 ${INPUT_DIR}/${SAMPLE}_clean_2.fq.gz \
    -S ${OUT_DIR}/${SAMPLE}.sam \
    --summary-file ${OUT_DIR}/${SAMPLE}_summary.txt

echo "✅ 样本 ${SAMPLE} 比对完成！快去看看结果吧！"