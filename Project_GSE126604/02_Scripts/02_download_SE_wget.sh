#!/bin/bash
echo "开始单端测序数据质控..."

# 建议加上 -j 参数，并使用变量
SAMPLE="SRR38247753"

fastp \
  -i ../01_RawData/${SAMPLE}.fastq.gz \
  -o ../03_Results/${SAMPLE}_clean.fastq.gz \
  -j ../03_Results/${SAMPLE}_fastp.json \
  -h ../03_Results/${SAMPLE}_QC_report.html \
  --thread 4
echo "质控彻底完成！ 在03_Results 文件夹里查看网页报告！"
