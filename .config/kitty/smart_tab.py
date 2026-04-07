# smart_tab.py — Cmd+E 智能开新 tab
# 普通情况：复用当前源窗口的工作目录。
# SSH 会话中：只有“明确已建立”的远端上下文才复用远端工作目录。
# 正在连接 / 主机不可达 / 元数据不完整时，直接回退到本地 shell，不能等待。

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from smart_launcher import make_handle_result, main


handle_result = make_handle_result("tab", "Kitty smart tab failed")


if __name__ == '__main__':
    main(sys.argv)
