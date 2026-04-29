#!/bin/bash
set -euo pipefail

SAMPLES=(
    "SRR34942226" "SRR34942227" "SRR34942228" "SRR34942229"
    "SRR34942230" "SRR34942231" "SRR34942232" "SRR34942233"
)

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="$WORK_DIR/../01_RawData"
QC_DIR="$WORK_DIR/../03_Results"

# 确保文件夹存在
mkdir -p "$QC_DIR"
mkdir -p "$RAW_DIR"

# 直接进入 RawData 文件夹
cd "$RAW_DIR"

# 扫除刚才下载到一半的 aws 废弃临时文件
rm -f *.sra *.aria2 2>/dev/null || true

for i in "${SAMPLES[@]}"; do
    echo "========================================"
    echo "🚀 强制连接欧洲 ENA 数据库获取成品: $i ..."
    echo "========================================"

    # 核心修改点：去掉了 aws-http，强制锁死 ena-ftp，线程拉满到 16
    if [[ ! -f "${i}_1.fastq.gz" ]]; then
        kingfisher get -r "$i" -m ena-ftp -f fastq.gz --download-threads 16
    else
        echo "文件已存在，跳过下载..."
    fi

    # 确保文件真的下载成功才进行质控
    if [[ -f "${i}_1.fastq.gz" && -f "${i}_2.fastq.gz" ]]; then
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

        echo "✅ 样本 $i 质控彻底完成！"
    else
        echo "❌ 样本 $i 下载似乎失败了，跳过质控步骤。"
    fi
done

echo "🎉 所有样本下载与过滤全部结束！"