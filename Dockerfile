# ---- Stage 1: Builder ----
# 此阶段用于构建 aggregator 和安装所有 Python 依赖
FROM python:3.12.3-slim as builder

# 设置中国大陆镜像源以加速 apt-get
# 永久移除 --mount=type=cache 来解决 apt 锁问题
RUN sh -c "sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && apt-get update && apt-get install -y --no-install-recommends git"

# 设置工作目录
WORKDIR /app

# 设置中国大陆 PyPI 镜像源以加速 pip
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# --- 修正子模块处理逻辑 (增加浅克隆优化) ---
# 使用浅克隆 --depth=1 来减少下载量，提高在不稳定网络下的成功率
RUN git clone --depth=1 https://github.com/wzdnzd/aggregator.git aggregator

# 拷贝主项目的依赖文件
COPY requirements.txt ./

# 现在 aggregator/requirements.txt 已经存在于容器内，可以直接安装所有依赖
# pip 的缓存仍然是稳定可用的
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r aggregator/requirements.txt

# ---- Stage 2: Final Image ----
# 此阶段构建最终的、轻量化的运行镜像
FROM python:3.12.3-slim

# 作者信息 (可选)
LABEL maintainer="Gemini"

# 设置环境变量
ENV TZ=Asia/Shanghai \
    DEBIAN_FRONTEND=noninteractive \
    RUNMODE=BOTH \
    PROXY_PORT_AGG=10707 \
    PROXY_PORT_SUB=10710

# 设置中国大陆镜像源并安装 glider 等运行时依赖（最终健壮版本）
RUN sh -c "set -ex && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    cd /tmp && \
    curl -L -o glider.tar.gz https://github.com/nadoo/glider/releases/download/v0.16.4/glider_0.16.4_linux_amd64.tar.gz && \
    tar -xzf glider.tar.gz && \
    # 使用 find 命令查找可执行文件并移动，避免依赖硬编码的文件名
    find . -type f -executable -exec mv {} /usr/local/bin/glider \; && \
    chmod +x /usr/local/bin/glider && \
    cd / && \
    apt-get purge -y --auto-remove curl && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*"

# 设置工作目录
WORKDIR /app

# 从 builder 阶段拷贝已安装的 Python 包
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/

# 拷贝应用程序代码
# 从 builder 阶段拷贝已包含子模块内容的 app 目录
COPY --from=builder /app /app

# 拷贝主项目的 Python 脚本和配置文件
COPY parse.py ./
COPY run_collector.py ./
COPY scheduler.py ./
COPY subscription_scheduler.py ./
COPY subscriptions.txt ./
COPY requirements.txt ./

# 拷贝并设置启动脚本的执行权限
# entrypoint.sh 不在 builder 阶段，所以从构建上下文拷贝
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 声明容器对外暴露的端口
EXPOSE ${PROXY_PORT_AGG} ${PROXY_PORT_SUB}

# 容器启动命令
ENTRYPOINT ["./entrypoint.sh"]