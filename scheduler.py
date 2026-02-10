import subprocess
import time
import signal
import sys
import os
from pathlib import Path
from datetime import datetime

def run_glider(glider_path, config_path):
    """启动glider进程"""
    try:
        process = subprocess.Popen(
            [glider_path, "-config", config_path],
            stdout=None,
            stderr=None,
            universal_newlines=True
        )
        return process
    except Exception as e:
        print(f"Error starting glider: {e}")
        return None

def kill_glider(process):
    """终止glider进程"""
    if process:
        try:
            process.terminate()
            process.wait(timeout=5)  # 等待进程终止
        except subprocess.TimeoutExpired:
            process.kill()  # 如果进程没有及时终止，强制结束
        except Exception as e:
            print(f"Error killing glider: {e}")

def run_collector():
    """运行收集器脚本"""
    try:
        subprocess.run(["python", "run_collector.py"], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error running collector: {e}")
        return False

def main():
    # 获取当前脚本所在目录
    current_dir = Path(__file__).parent.absolute()
    glider_path = current_dir / "glider" / ('glider.exe' if os.name == 'nt' else 'glider')  # glider可执行文件路径
    config_path = current_dir / "glider" / "glider.conf"  # 配置文件路径
    # 检查必要文件是否存在
    if not glider_path.exists():
        print(f"Error: glider executable not found at {glider_path}")
        sys.exit(1)

    # 确保glider可执行
    glider_path.chmod(0o755)

    # 初始化glider进程为None
    glider_process = None

    def cleanup(signum, frame):
        """清理函数，用于处理终止信号"""
        print("\nReceived termination signal. Cleaning up...")
        if glider_process:
            kill_glider(glider_process)
        sys.exit(0)

    # 注册信号处理器
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    try:
        # 首先启动glider进程
        print(f"\n[{datetime.now()}] Starting initial glider process...")
        glider_process = run_glider(str(glider_path), str(config_path))
        if not glider_process:
            print("Failed to start initial glider process")
            sys.exit(1)
        print("Initial glider process started successfully")

        # 然后进入主循环
        while True:
            # 等待30分钟
            print(f"[{datetime.now()}] Waiting 30 minutes until next update...")
            time.sleep(1800)  # 30分钟 = 1800秒

            print(f"\n[{datetime.now()}] Starting update cycle...")

            # 运行收集器
            if run_collector():
                # 如果glider正在运行，先终止它
                if glider_process:
                    print("Stopping current glider process...")
                    kill_glider(glider_process)

                # 启动新的glider进程
                print("Starting new glider process...")
                glider_process = run_glider(str(glider_path), str(config_path))
                if not glider_process:
                    print("Failed to start glider")
                    continue

                print("Update completed successfully")
            else:
                print("Collector failed, keeping current glider process")

    except KeyboardInterrupt:
        print("\nReceived keyboard interrupt. Cleaning up...")
        if glider_process:
            kill_glider(glider_process)
        sys.exit(0)

if __name__ == "__main__":
    main()
