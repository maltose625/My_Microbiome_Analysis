#!/bin/bash

# 设置环境变量，确保脚本在遇到错误时立即停止
set -euo pipefail

# 确保 SRA 工具使用正确的 CA 包路径（有些环境默认找不到/不匹配）
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"

# 1.定义样本列表
SAMPLES=(
    "SRR34942226" "SRR34942227" "SRR34942228" "SRR34942229"
    "SRR34942230" "SRR34942231" "SRR34942232" "SRR34942233"
)

# 2.获取动态路径
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="$WORK_DIR/../01_RawData"
QC_DIR="$WORK_DIR/../03_Results"
SRA_DIR="$WORK_DIR/../01_RawData/sra_temp"

# 3 确保输出结果的文件夹存在，如果没有就自动新建一个
mkdir -p "$QC_DIR"
mkdir -p "$SRA_DIR"

# 4.循环下载
for i in "${SAMPLES[@]}"; do
    echo "========================================"
    echo "正在对样本进行质控: $i ..."
    echo "========================================"

    fastq1_gz="$RAW_DIR/${i}_1.fastq.gz"
    fastq2_gz="$RAW_DIR/${i}_2.fastq.gz"

    # 如果 fastq.gz 不存在，则先下载/转码到本地再跑 fastp
    if [[ ! -f "$fastq1_gz" || ! -f "$fastq2_gz" ]]; then
        echo "未找到 $i 的 fastq.gz，开始 prefetch + fasterq-dump ..."

        # 1) 下载到临时目录（避免污染工作目录）
        if ! prefetch "$i" -O "$SRA_DIR"; then
            echo "WARN: prefetch(https) 失败：$i，尝试使用 http transport ..."
            if ! prefetch -t http "$i" -O "$SRA_DIR"; then
                echo "ERROR: prefetch 失败：$i（https 与 http 都失败）"
                exit 1
            fi
        fi

        # 2) 定位 prefetch 生成的 .sra 文件（不同版本/参数可能有不同目录结构）
        sra_file=""
        if [[ -f "$SRA_DIR/${i}.sra" ]]; then
            sra_file="$SRA_DIR/${i}.sra"
        elif [[ -f "$SRA_DIR/$i/${i}.sra" ]]; then
            sra_file="$SRA_DIR/$i/${i}.sra"
        fi

        if [[ -z "$sra_file" ]]; then
            echo "ERROR: 未找到 prefetch 生成的 .sra 文件：$i"
            exit 1
        fi

        # 3) 转成 fastq
        if ! fasterq-dump "$sra_file" --split-files --progress --outdir "$RAW_DIR"; then
            echo "ERROR: fasterq-dump 失败：$i"
            exit 1
        fi

        # 4) 压缩 fastq（fastp 输入统一用 .fastq.gz）
        gzip -f "$RAW_DIR/${i}"_*.fastq

        # 5) 清理临时 sra（可按需注释掉）
        rm -f "$SRA_DIR/${i}.sra" 2>/dev/null || true
        rm -rf "$SRA_DIR/$i" 2>/dev/null || true
    fi

    # 注意：下载下来的文件名是 SRRXXXX_1.fastq.gz 的格式
    # 如果你的文件名没有 .gz 后缀，请把下面代码里的 .gz 删掉
    fastp_in1="$fastq1_gz"
    fastp_in2="$fastq2_gz"
    # 兜底：若仍未 gzip，则改用未压缩 fastq
    if [[ ! -f "$fastp_in1" ]]; then fastp_in1="$RAW_DIR/${i}_1.fastq"; fi
    if [[ ! -f "$fastp_in2" ]]; then fastp_in2="$RAW_DIR/${i}_2.fastq"; fi

    fastp \
        --in1 "$fastp_in1" \
        --in2 "$fastp_in2" \
        --out1 "$QC_DIR/${i}_clean_1.fq.gz" \
        --out2 "$QC_DIR/${i}_clean_2.fq.gz" \
        --json "$QC_DIR/${i}_fastp.json" \
        --html "$QC_DIR/${i}_fastp.html" \
        --thread 4 \
        --detect_adapter_for_pe

    echo "样本 $i 质控顺利完成！"
done

echo "所有样本的质控与过滤全部结束，可以准备比对了！"