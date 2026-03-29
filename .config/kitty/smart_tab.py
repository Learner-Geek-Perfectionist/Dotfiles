# smart_tab.py — Cmd+E 智能开新 tab
# 普通情况：继承当前目录开新 tab（原有行为）
# SSH 会话中：新 tab 先启动本地 zsh，再自动 SSH 进去
# 这样 exit 退出 SSH 后，回落到本地 zsh，tab 不会消失

import sys

from kittens.tui.handler import result_handler
from ssh_utils import smart_launch


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    smart_launch(boss, "tab")


if __name__ == '__main__':
    main(sys.argv)
