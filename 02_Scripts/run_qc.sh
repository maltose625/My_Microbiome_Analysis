#!/bin/bash
# 迷你数据集的单端 fastp 质控测试

echo "开始给单端测序数据洗澡啦..."

fastp \
  -i ../01_RawData/SRR38247753.fastq.gz \
  -o ../03_Results/SRR38247753_clean.fastq.gz \
  -h ../03_Results/SRR38247753_QC_report.html

echo "质控彻底完成！快去 03_Results 文件夹里验收网页报告吧！"
