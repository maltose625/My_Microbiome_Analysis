#!/usr/bin/env bash
# =============================================================================
# 脚本名称：run_pipeline.sh
# 功能描述：统一测序数据处理流水线 (数据下载 -> fastp质控)
# 使用示例：
#   全流程: bash run_pipeline.sh -s all -t PE -m kingfisher -l srr_list.txt
#   仅下载: bash run_pipeline.sh -s fetch -t PE -m kingfisher -l srr_list.txt
#   仅质控: bash run_pipeline.sh -s qc
# =============================================================================

set -euo pipefail
shopt -s nullglob

# --- 1. 全局绝对路径与环境初始化 (去重合并) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RAW_DIR="${PROJECT_ROOT}/01_RawData"
QC_DIR="${PROJECT_ROOT}/03_Results"

# 提前创建所有工作目录
mkdir -p "${RAW_DIR}" "${QC_DIR}"

# --- 2. 默认参数初始化 ---
STEP="all"          # 默认执行步骤：all (全部), fetch (仅下载), qc (仅质控)
SEQ_TYPE="PE"       
METHOD="direct"     
LIST_FILE=""        

# --- 3. 命令行参数解析 ---
usage() {
    echo "用法: bash $0 -s <all|fetch|qc> [-t <SE|PE>] [-m <direct|kingfisher>] [-l <list_file>]"
    echo "  -s : 执行步骤 [all|fetch|qc] (必填)"
    echo "  -l : 列表文件 (当 -s 为 all 或 fetch 时必填)"
    exit 1
}

while getopts "s:t:m:l:h" opt; do
    case $opt in
        s) STEP="$OPTARG" ;;
        t) SEQ_TYPE="$OPTARG" ;;
        m) METHOD="$OPTARG" ;;
        l) LIST_FILE="$OPTARG" ;;
        h) usage ;;
        ?) usage ;;
    esac
done

echo "=================================================="
echo "🚀 启动生信自动化流水线 | 当前执行阶段: [ $STEP ]"
echo "=================================================="

# =============================================================================
# 模块一：数据获取 (Fetch)
# =============================================================================
if [[ "$STEP" == "all" || "$STEP" == "fetch" ]]; then
    # 针对下载模块的特定健壮性检查
    if [[ -z "$LIST_FILE" || ! -f "$LIST_FILE" ]]; then
        echo "❌ 错误：执行下载任务必须使用 -l 提供有效的列表文件！"
        exit 1
    fi

    LIST_ABS_PATH=$(realpath "$LIST_FILE")
    cd "${RAW_DIR}"

    if [[ "$METHOD" == "direct" ]]; then
        echo "🌐 [wget 直下模式] 启动..."
        wget -i "$LIST_ABS_PATH" -c -q --show-progress
    elif [[ "$METHOD" == "kingfisher" ]]; then
        echo "🦅 [Kingfisher 级联爬取模式] 启动..."
        while IFS= read -r id || [[ -n "$id" ]]; do
            [[ -z "$id" || "$id" =~ ^# ]] && continue
            if [[ -f "${id}_1.fastq.gz" || -f "${id}.fastq.gz" ]]; then
                 echo "⏭️ [跳过] $id 原始数据已存在。"
                 continue
            fi
            echo "⬇️ 获取: $id ..."
            kingfisher get -r "$id" -m ena-ftp aws-http prefetch -f fastq.gz --download-threads 16
        done < "$LIST_ABS_PATH"
    else
        echo "❌ 未知下载模式：$METHOD"
        exit 1
    fi
    echo "✅ 数据获取阶段完成！"
fi

# =============================================================================
# 模块二：数据质控 (QC)
# =============================================================================
if [[ "$STEP" == "all" || "$STEP" == "qc" ]]; then
    cd "${RAW_DIR}"
    echo "🧪 [自动化 QC 流水线] 启动..."

    # 检查是否有文件可以质控
    files=(*_1.fastq.gz)
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "⚠️ 警告：${RAW_DIR} 中没有找到任何 _1.fastq.gz 结尾的文件，跳过质控。"
    else
        for r1 in "${files[@]}"; do
            sample_name="${r1%_1.fastq.gz}"
            r2="${sample_name}_2.fastq.gz"
            clean_r1="${QC_DIR}/${sample_name}_clean_1.fq.gz"
            clean_r2="${QC_DIR}/${sample_name}_clean_2.fq.gz"

            if [[ -f "${r2}" ]]; then
                if [[ -f "${clean_r1}" && -f "${clean_r2}" ]]; then
                    echo "⏭️ [跳过] ${sample_name} 干净数据已存在。"
                else
                    echo "📊 质控中: ${sample_name} ..."
                    fastp -i "${r1}" -I "${r2}" \
                          -o "${clean_r1}" -O "${clean_r2}" \
                          -j "${QC_DIR}/${sample_name}_fastp.json" \
                          -h "${QC_DIR}/${sample_name}_fastp.html" \
                          --thread 4 --detect_adapter_for_pe --cut_right \
                          --length_required 50 --qualified_quality_phred 15
                fi
            else
                echo "⚠️ 警告: 找不到 ${sample_name} 的 R2 配对文件！"
            fi
        done

        if command -v multiqc &> /dev/null; then
            echo "📈 生成 MultiQC 全局报告..."
            multiqc "${QC_DIR}" -o "${QC_DIR}/MultiQC_Report"
        fi
    fi
    echo "✅ 质控阶段完成！"
fi

echo "🎉 全流水线任务圆满结束！"