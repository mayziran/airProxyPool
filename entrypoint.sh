#!/bin/bash
set -e

# 定义应用目录
APP_DIR="/app"

# --- 1. 确保目录结构符合 README ---
mkdir -p "${APP_DIR}/glider"
mkdir -p "${APP_DIR}/aggregator/data"

# --- 2. 初始化配置文件 ---
# 检查 glider.conf 是否存在，不存在则由脚本生成默认的（在 run_collector.py 或 scheduler.py 中会处理，但这里先确保目录在）

# 检查 subscriptions.txt 是否存在，不存在则创建一个空的
if [ ! -f "${APP_DIR}/subscriptions.txt" ]; then
    touch "${APP_DIR}/subscriptions.txt"
fi

# --- 3. 根据 RUNMODE 环境变量启动服务 ---
echo "Starting container in [${RUNMODE}] mode..."

if [ "$RUNMODE" = "AGG" ]; then
    # 仅启动 aggregator 代理池
    echo "Starting AGG mode..."
    python scheduler.py
elif [ "$RUNMODE" = "SUB" ]; then
    # 仅启动自定义订阅代理池
    echo "Starting SUB mode..."
    python subscription_scheduler.py
elif [ "$RUNMODE" = "BOTH" ]; then
    # 同时启动两种模式
    echo "Starting BOTH mode (AGG and SUB)..."
    
    # 启动 aggregator 模式，并将其置于后台
    echo "Launching AGG process in background..."
    python scheduler.py &
    
    # 等待几秒钟，避免日志混乱
    sleep 5
    
    # 启动 subscription 模式，在前台运行
    echo "Launching SUB process in foreground..."
    python subscription_scheduler.py
else
    echo "Error: Invalid RUNMODE specified: '${RUNMODE}'. Please use 'AGG', 'SUB', or 'BOTH'."
    exit 1
fi

# 如果所有进程都在后台，使用 wait 保持容器运行
wait
