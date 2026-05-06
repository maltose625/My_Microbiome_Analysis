# 代码解析
```bash
if wget --spider -q "$FASTQ1_URL" && wget --spider -q "$FASTQ2_URL"; then    
    # 如果两个 URL 都有效，则执行这里的代码
fi
# wget: 这是一个常用的命令行下载工具; --spider: 意为“爬虫模式”,不会真正下载文件，而是去访问指定的 URL;-q (quiet): “安静模式”,闭所有输出（不显示连接过程、不显示错误信息）.
# && 是逻辑“与”运算符,脚本会先执行第一个命令,只有当第一个命令成功（返回状态码 0）**时，才会继续执行第二个命令,如果第一个 URL 探测失败，整个判断直接结束，不会再去试第二个。
```
```bash
usage() {
    echo "用法: bash $0 -s <all|fetch|qc> [-t <SE|PE>] [-m <direct|kingfisher>] [-l <list_file>]"
    echo "  -s : 执行步骤 [all|fetch|qc] (必填)"
    echo "  -l : 列表文件 (当 -s 为 all 或 fetch 时必填)"
    exit 1
}
# 该段代码的作用为：
```

```bash
mkdir -p /mnt/d/A/WSL_Microbiome_Project/04_Databases/Mus_musculus/GRCm39
# -p 的作用是两点：
# 自动创建缺失的父目录（例如前面的 04_Databases、Mus_musculus 如果不存在，也会一起创建）
# 目录已存在时不报错（不会因为 GRCm39 已经存在而失败）。所以 -p 很适合写脚本，能让命令更“稳”，重复执行也通常没问题。
```

```bash
awk
核心功能：按列处理文本、进行计算、格式化输出、统计分析。被誉为“命令行中的Excel”。
核心思想：把每一行自动拆分成字段（默认以空格或制表符分隔），用 $1、$2 表示第1列、第2列。
# 打印第1列和第3列
awk '{print $1, $3}' data.txt

# 打印行号和内容
awk '{print NR, $0}' file.log

# 统计行数
awk 'END{print NR}' file.txt

# 按条件过滤 + 计算
awk '$3 > 100 {sum += $3} END {print sum}' data.txt

# 指定分隔符（以逗号分隔）
awk -F ',' '{print $1, $2}' data.csv
```

```bash
sed —— 流编辑器（Stream Editor）
核心功能：对文本进行查找、替换、删除、插入等编辑操作，支持正则表达式。
特点：适合替换和简单编辑，处理速度快。
# 替换文本（第一次出现）
sed 's/old/new/' file.txt

# 全局替换
sed 's/old/new/g' file.txt

# 替换并保存到原文件（-i）
sed -i 's/old/new/g' file.txt

# 删除匹配行
sed '/pattern/d' file.txt

# 在指定行插入内容
sed '2i\插入的新行' file.txt

# 只处理特定行
sed '1,10s/old/new/g' file.txt
```

```bash
grep —— 搜索与过滤（Global Regular Expression Print）
核心功能：在文本中搜索符合条件的行，并打印出来。
常用场景：查找包含某个关键词的行、过滤日志、结合正则表达式进行复杂匹配
# 基础搜索
grep "error" app.log

# 忽略大小写
grep -i "error" app.log

# 显示行号
grep -n "error" app.log

# 显示上下文（前3行 + 后3行）
grep -C 3 "error" app.log

# 正则表达式搜索
grep -E "^[0-9]{4}" data.txt          # 以4位数字开头的行

# 排除（反向匹配）
grep -v "success" app.log
```
