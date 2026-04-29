#!/bin/bash
set -euo pipefail

SAMPLES=("SRR34942226" "SRR34942227" "SRR34942228" "SRR34942229" "SRR34942230" "SRR34942231" "SRR34942232" "SRR34942233")
RAW_DIR="../01_RawData"
QC_DIR="../03_Results"
mkdir -p "$QC_DIR"

for i in "${SAMPLES[@]}"; do
    echo "========================================"
    
    # 【第一重断点排查】：有没有原材料？
    if [[ ! -f "$RAW_DIR/${i}_1.fastq.gz" ]]; then
        echo "⏳ 样本 $i 的原始数据还未下载完，暂时跳过质控..."
        continue
    fi

    # 【第二重断点排查】：成品是不是已经做过了？
    if [[ -f "$QC_DIR/${i}_clean_1.fq.gz" && -f "$QC_DIR/${i}_clean_2.fq.gz" ]]; then
        echo "⏭️ 样本 $i 的质控成品已存在 (clean_fq)，跳过质控步骤！"
        continue
    fi

    # 通过双重排查后，才开始真正干活
    echo "🧼 正在对已下载好的样本 $i 进行 fastp 质控..."
    fastp \
        --in1 "$RAW_DIR/${i}_1.fastq.gz" \
        --in2 "$RAW_DIR/${i}_2.fastq.gz" \
        --out1 "$QC_DIR/${i}_clean_1.fq.gz" \
        --out2 "$QC_DIR/${i}_clean_2.fq.gz" \
        --json "$QC_DIR/${i}_fastp.json" \
        --html "$QC_DIR/${i}_fastp.html" \
        --thread 4 --detect_adapter_for_pe

    echo "✅ 样本 $i 质控圆满完成！"
done

echo "🎉 所有可用样本的质控均已处理完毕！"