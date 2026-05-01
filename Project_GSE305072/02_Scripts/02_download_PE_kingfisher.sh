#!/bin/bash
set -euo pipefail

SAMPLES=(
    "SRR34942226" "SRR34942227" "SRR34942228" "SRR34942229"
    "SRR34942230" "SRR34942231" "SRR34942232" "SRR34942233"
)

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="$WORK_DIR/../01_RawData"
QC_DIR="$WORK_DIR/../03_Results"

mkdir -p "$QC_DIR"
mkdir -p "$RAW_DIR"
cd "$RAW_DIR"

# 清理刚才失败的残骸
rm -f *.sra *.aria2 2>/dev/null || true

for i in "${SAMPLES[@]}"; do
    echo "========================================"
    echo "🚀 启动智能级联下载模式 (GCP -> AWS -> NCBI): $i ..."
    echo "========================================"

    # 1. 下载阶段的断点检查
    if [[ ! -f "${i}_1.fastq.gz" ]]; then
        kingfisher get -r "$i" -m ena-ftp aws-http prefetch -f fastq.gz --download-threads 16
    else
        echo "✅ 原始文件已存在，跳过下载..."
    fi

    # 2. 质控阶段的断点检查
    if [[ -f "${i}_1.fastq.gz" && -f "${i}_2.fastq.gz" ]]; then
        
        # 核心修改点：去 Results 文件夹看一眼成品在不在
        if [[ -f "$QC_DIR/${i}_clean_1.fq.gz" && -f "$QC_DIR/${i}_clean_2.fq.gz" ]]; then
            echo "⏭️ 样本 $i 的质控结果已存在，直接跳过 fastp！"
        else
            echo "开始对 $i 进行数据质控..."
            fastp \
                --in1 "${i}_1.fastq.gz" \
                --in2 "${i}_2.fastq.gz" \
                --out1 "$QC_DIR/${i}_clean_1.fq.gz" \
                --out2 "$QC_DIR/${i}_clean_2.fq.gz" \
                --json "$QC_DIR/${i}_fastp.json" \
                --html "$QC_DIR/${i}_fastp.html" \
                --thread 4 \
                --detect_adapter_for_pe
            echo "✅ 样本 $i 质控完成！"
        fi
        
    else
        echo "❌ 警告：$i 的 fastq.gz 文件未生成，请检查下载日志！"
    fi
done

echo "🎉 恭喜！流水线全部执行完毕！"