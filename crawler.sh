#!/bin/bash

# ============================================
# MediaCrawlerPro 自动爬取脚本
# 兼容 Ubuntu 系统，一键启动所有服务
# ============================================

set -e

# ---------- 核心配置（可自定义）----------
KEYWORDS="石家庄信息工程职业学院,信工,石家庄信息工程职业大学"       # 爬取关键词
MAX_COUNT=20                     # 爬取数量，默认10条
ENABLE_COMMENTS=true            # 是否爬取评论，false=不爬，true=爬（较慢）
MAX_COMMENTS_PER_NOTE=100        # 每个帖子最大评论数，0表示不限制
DY_PUBLISH_TIME=1              # 抖音时间筛选：0=不限，1=一天内，7=一周内，180=半年内
INTERVAL=300                     # 循环间隔（秒），2小时=7200
PLATFORMS=("xhs" "dy" "bili")    # 爬取平台顺序
CRAWLER_TYPE="search"             # 爬取类型

# ---------- 自动检测项目目录 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

LOG_DIR="$ROOT_DIR/logs"

# 项目目录
SIGNSRV_DIR="$ROOT_DIR/MediaCrawlerPro-SignSrv"
COOKIEBRIDGE_DIR="$ROOT_DIR/MediaCrawlerPro-CookieBridge"
CRAWLER_DIR="$ROOT_DIR/MediaCrawlerPro-Python"

# PID 文件（合并为一个文件）
PID_FILE="$ROOT_DIR/pid.txt"

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------- 日志函数 ----------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# ---------- 检查 uv ----------
check_uv() {
    if ! command -v uv &> /dev/null; then
        log_info "未检测到 uv，正在安装..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
        if command -v uv &> /dev/null; then
            log_info "uv 安装成功: $(uv --version)"
        else
            log_error "uv 安装失败，请手动安装"
            exit 1
        fi
    else
        log_info "uv 已安装: $(uv --version)"
    fi
}

# ---------- 检查项目目录 ----------
check_dirs() {
    local missing=0
    
    if [ ! -d "$SIGNSRV_DIR" ]; then
        log_error "缺少目录: MediaCrawlerPro-SignSrv"
        missing=1
    fi
    
    if [ ! -d "$COOKIEBRIDGE_DIR" ]; then
        log_error "缺少目录: MediaCrawlerPro-CookieBridge"
        missing=1
    fi
    
    if [ ! -d "$CRAWLER_DIR" ]; then
        log_error "缺少目录: MediaCrawlerPro-Python"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "项目目录检查失败，请确保3个项目都在 $ROOT_DIR 目录下"
        exit 1
    fi
    
    log_info "项目目录检查通过"
}

# ---------- 停止已有进程 ----------
stop_services() {
    log_info "检查已有进程..."
    
    if [ -f "$PID_FILE" ]; then
        while IFS=: read -r name pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_info "停止 $name (PID: $pid)"
                kill "$pid" 2>/dev/null || true
                sleep 1
                kill -9 "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # 清理残留的 python 进程
    pkill -f "uv run app.py" 2>/dev/null || true
    pkill -f "crawler_loop.sh" 2>/dev/null || true
    
    log_info "已有进程清理完成"
}

# ---------- 启动服务 ----------
start() {
    log_info "=========================================="
    log_info "  MediaCrawlerPro 自动爬取系统启动"
    log_info "=========================================="
    
    # 检查环境和目录
    check_uv
    check_dirs
    
    # 停止已有进程
    stop_services
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 清空各平台日志文件（每次启动时新建）
    rm -f "$LOG_DIR"/xhs_*.log
    rm -f "$LOG_DIR"/dy_*.log
    rm -f "$LOG_DIR"/bili_*.log
    
    # 生成爬虫循环脚本
    generate_crawler_loop
    
    # 初始化 PID 文件
    > "$PID_FILE"
    
    # 1. 启动 SignSrv
    log_info "[1/3] 启动 SignSrv..."
    cd "$SIGNSRV_DIR"
    nohup uv run app.py >> "$LOG_DIR/signsrv.log" 2>&1 &
    local signsrv_pid=$!
    echo "SignSrv:$signsrv_pid" >> "$PID_FILE"
    sleep 2
    
    # 检查是否启动成功
    if kill -0 "$signsrv_pid" 2>/dev/null; then
        log_info "[1/3] SignSrv 已启动 (PID: $signsrv_pid)"
    else
        log_error "[1/3] SignSrv 启动失败，请检查日志: $LOG_DIR/signsrv.log"
        exit 1
    fi
    
    sleep 3
    
    # 2. 启动 CookieBridge
    log_info "[2/3] 启动 CookieBridge..."
    cd "$COOKIEBRIDGE_DIR/server"
    nohup uv run app.py >> "$LOG_DIR/cookiebridge.log" 2>&1 &
    local cookiebridge_pid=$!
    echo "CookieBridge:$cookiebridge_pid" >> "$PID_FILE"
    sleep 2
    
    if kill -0 "$cookiebridge_pid" 2>/dev/null; then
        log_info "[2/3] CookieBridge 已启动 (PID: $cookiebridge_pid)"
    else
        log_error "[2/3] CookieBridge 启动失败，请检查日志: $LOG_DIR/cookiebridge.log"
        exit 1
    fi
    
    sleep 3
    
    # 3. 启动爬虫循环
    log_info "[3/3] 启动爬虫循环..."
    cd "$ROOT_DIR"
    nohup bash "$ROOT_DIR/crawler_loop.sh" >> "$LOG_DIR/crawler循环.log" 2>&1 &
    local crawler_pid=$!
    echo "CrawlerLoop:$crawler_pid" >> "$PID_FILE"
    sleep 2
    
    if kill -0 "$crawler_pid" 2>/dev/null; then
        log_info "[3/3] 爬虫循环已启动 (PID: $crawler_pid)"
    else
        log_error "[3/3] 爬虫循环启动失败，请检查日志: $LOG_DIR/crawler循环.log"
        exit 1
    fi
    
    log_info "=========================================="
    log_info "  所有服务已启动完成！"
    log_info "  日志目录: $LOG_DIR"
    log_info "  PID文件: $PID_FILE"
    log_info "=========================================="
}

# ---------- 停止服务 ----------
stop() {
    log_info "正在停止所有服务..."
    
    if [ -f "$PID_FILE" ]; then
        while IFS=: read -r name pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_info "停止 $name (PID: $pid)"
                kill "$pid" 2>/dev/null || true
                sleep 1
                kill -9 "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    log_info "所有服务已停止"
}

# ---------- 查看状态 ----------
status() {
    echo "=========================================="
    echo "  MediaCrawlerPro 服务状态"
    echo "=========================================="
    
    local running=0
    
    if [ -f "$PID_FILE" ]; then
        while IFS=: read -r name pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}●${NC} $name (PID: $pid)"
                running=$((running + 1))
            else
                echo -e "${RED}●${NC} $name (已停止)"
            fi
        done < "$PID_FILE"
    else
        echo -e "${RED}●${NC} SignSrv (未启动)"
        echo -e "${RED}●${NC} CookieBridge (未启动)"
        echo -e "${RED}●${NC} CrawlerLoop (未启动)"
    fi
    
    echo "=========================================="
    if [ $running -eq 3 ]; then
        echo -e "${GREEN}状态: 全部运行中${NC}"
    else
        echo -e "${YELLOW}状态: 部分运行中${NC}"
    fi
    echo "=========================================="
}

# ---------- 查看日志 ----------
show_logs() {
    if [ -d "$LOG_DIR" ]; then
        echo "日志文件列表:"
        ls -lh "$LOG_DIR"
        echo ""
        echo "最新日志内容 (最后20行):"
        echo ""
        tail -20 "$LOG_DIR/crawler循环.log" 2>/dev/null || echo "暂无日志"
    else
        log_error "日志目录不存在: $LOG_DIR"
    fi
}

# ---------- 查看实时日志 ----------
tail_logs() {
    tail -f "$LOG_DIR/crawler循环.log" 2>/dev/null || {
        log_error "日志文件不存在"
    }
}

# ---------- 生成爬虫循环脚本 ----------
generate_crawler_loop() {
    cat > "$ROOT_DIR/crawler_loop.sh" << 'LOOP_EOF'
#!/bin/bash

# ============================================
# 爬虫循环脚本 - 自动生成
# ============================================

KEYWORDS="KEYWORDS_PLACEHOLDER"
MAX_COUNT=MAX_COUNT_PLACEHOLDER
ENABLE_COMMENTS=ENABLE_COMMENTS_PLACEHOLDER
MAX_COMMENTS_PER_NOTE=MAX_COMMENTS_PER_NOTE_PLACEHOLDER
DY_PUBLISH_TIME=DY_PUBLISH_TIME_PLACEHOLDER
INTERVAL=INTERVAL_PLACEHOLDER
PLATFORMS=("xhs" "dy" "bili")
CRAWLER_TYPE="search"

ROOT_DIR="ROOT_DIR_PLACEHOLDER"
LOG_DIR="$ROOT_DIR/logs"

mkdir -p "$LOG_DIR"

# 爬取单个平台
run_platform() {
    local platform=$1
    local today=$(date '+%Y%m%d')
    local log_file="$LOG_DIR/${platform}_${today}.log"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始爬取 $platform" | tee -a "$log_file"
    
    cd "$ROOT_DIR/MediaCrawlerPro-Python"
    
    # 动态修改爬取数量配置
    sed -i "s/CRAWLER_MAX_NOTES_COUNT = [0-9]\+/CRAWLER_MAX_NOTES_COUNT = $MAX_COUNT/" config/base_config.py
    
    # 动态修改每个帖子最大评论数
    sed -i "s/PER_NOTE_MAX_COMMENTS_COUNT = [0-9]\+/PER_NOTE_MAX_COMMENTS_COUNT = $MAX_COMMENTS_PER_NOTE/" config/base_config.py
    
    # 动态修改抖音发布时间筛选
    sed -i "s/PUBLISH_TIME_TYPE = [0-9]\+/PUBLISH_TIME_TYPE = $DY_PUBLISH_TIME/" config/base_config.py
    
    # 根据配置决定是否爬取评论
    local comment_flag=""
    if [ "$ENABLE_COMMENTS" = "false" ]; then
        comment_flag="--no-enable_comments"
    fi
    
    uv run main.py --platform "$platform" --type "$CRAWLER_TYPE" --keywords "$KEYWORDS" $comment_flag >> "$log_file" 2>&1
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $platform 爬取完成" | tee -a "$log_file"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $platform 爬取失败，exit code: $exit_code" | tee -a "$log_file"
    fi
    
    return $exit_code
}

# 主循环
while true; do
    for platform in "${PLATFORMS[@]}"; do
        run_platform "$platform" || echo "$platform 失败，跳过继续"
        sleep 10  # 平台间缓冲时间
    done
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 全部完成，休眠 ${INTERVAL} 秒"
    sleep $INTERVAL
done
LOOP_EOF

    # 替换占位符
    sed -i "s|KEYWORDS_PLACEHOLDER|$KEYWORDS|g" "$ROOT_DIR/crawler_loop.sh"
    sed -i "s|MAX_COUNT_PLACEHOLDER|$MAX_COUNT|g" "$ROOT_DIR/crawler_loop.sh"
    sed -i "s|ENABLE_COMMENTS_PLACEHOLDER|$ENABLE_COMMENTS|g" "$ROOT_DIR/crawler_loop.sh"
    sed -i "s|MAX_COMMENTS_PER_NOTE_PLACEHOLDER|$MAX_COMMENTS_PER_NOTE|g" "$ROOT_DIR/crawler_loop.sh"
    sed -i "s|DY_PUBLISH_TIME_PLACEHOLDER|$DY_PUBLISH_TIME|g" "$ROOT_DIR/crawler_loop.sh"
    sed -i "s|INTERVAL_PLACEHOLDER|$INTERVAL|g" "$ROOT_DIR/crawler_loop.sh"
    sed -i "s|ROOT_DIR_PLACEHOLDER|$ROOT_DIR|g" "$ROOT_DIR/crawler_loop.sh"
    
    chmod +x "$ROOT_DIR/crawler_loop.sh"
    log_info "爬虫循环脚本已生成"
}

# ---------- 主入口 ----------
case "${1:-start}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    logs)
        show_logs
        ;;
    tail)
        tail_logs
        ;;
    restart)
        stop
        sleep 2
        start
        ;;
    *)
        echo "用法: $0 {start|stop|status|logs|tail|restart}"
        echo ""
        echo "  start   - 启动所有服务"
        echo "  stop   - 停止所有服务"
        echo "  status - 查看服务状态"
        echo "  logs   - 查看日志列表"
        echo "  tail   - 实时查看日志"
        echo "  restart - 重启所有服务"
        exit 1
        ;;
esac
