# smart_window.py — Cmd+N 智能开新 os-window
# 普通情况：复用当前源窗口的工作目录。
# SSH 会话中：只有“明确已建立”的远端上下文才复用远端工作目录。
# 正在连接 / 主机不可达 / 元数据不完整时，直接回退到本地 shell，不能等待。

import sys

from smart_launcher import make_handle_result, main


handle_result = make_handle_result("os-window", "Kitty smart window failed")


if __name__ == '__main__':
    main(sys.argv)
