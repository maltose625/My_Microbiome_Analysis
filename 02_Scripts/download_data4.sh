#!/bin/bash
set -euo pipefail

SAMPLES=("SRR34942226" "SRR34942227" "SRR34942228" "SRR34942229" "SRR34942230" "SRR34942231" "SRR34942232" "SRR34942233")
RAW_DIR="../01_RawData"
mkdir -p "$RAW_DIR"
cd "$RAW_DIR"

# 清理可能导致卡死的下载残骸（不会删除正常数据）
rm -f *.aria2 2>/dev/null || true

for i in "${SAMPLES[@]}"; do
    echo "========================================"
    echo "🔍 正在排查样本: $i ..."
    
    # 【核心断点排查】：检查最终的 fastq.gz 成品是否已经存在
    if [[ -f "${i}_1.fastq.gz" && -f "${i}_2.fastq.gz" ]]; then
        echo "✅ 成品文件 ${i}_1.fastq.gz 已存在，完美跳过下载！"
        continue # 直接跳过当前循环，检查下一个样本
    fi

    # 如果只有 .sra 文件但没有 .fastq.gz，说明上次解压失败了，提醒并重新处理
    if [[ -f "${i}.sra" && ! -f "${i}_1.fastq.gz" ]]; then
        echo "⚠️ 发现未解压的 ${i}.sra，Kingfisher 将自动恢复解压流程..."
    else
        echo "🚀 缺失原始数据，开始全速下载: $i"
    fi

    # 执行下载与解压命令
    kingfisher get -r "$i" -m ena-ftp aws-http prefetch -f fastq.gz --download-threads 16
done

echo "🎉 所有的下载和断点排查已全部完成！"