# smart_window.py — Cmd+N 智能开新 os-window
# 普通情况：继承当前目录开新 os-window（原有行为）
# SSH 会话中：新 window 先启动本地 zsh，再自动 SSH 进去
# 这样 exit 退出 SSH 后，回落到本地 zsh，window 不会消失

import sys
import shlex

from kittens.tui.handler import result_handler
from kitty.launch import launch as kitty_launch, parse_launch_args


def main(args):
    pass


def _extract_ssh_destination(window):
    """从前台进程中提取 SSH 目标地址（user@host 或 hostname）。找到返回字符串，否则返回 None。"""
    try:
        fp = window.child.foreground_processes
    except (AttributeError, OSError):
        return None

    _SSH_OPTS_WITH_ARG = set('bcDEeFIiJLlmOopQRSWw')

    for p in fp:
        cmdline = p.get('cmdline', []) or []
        if not cmdline:
            continue
        basename = cmdline[0].rsplit('/', 1)[-1]
        if basename != 'ssh':
            continue

        try:
            dash_idx = cmdline.index('--')
            return cmdline[dash_idx + 1]
        except (ValueError, IndexError):
            pass

        skip_next = False
        for arg in cmdline[1:]:
            if skip_next:
                skip_next = False
                continue
            if arg.startswith('-'):
                if len(arg) == 2 and arg[1] in _SSH_OPTS_WITH_ARG:
                    skip_next = True
                continue
            return arg

    return None


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.active_window
    if window is None:
        return

    destination = _extract_ssh_destination(window)

    if destination is not None:
        ssh_cmd = f'kitten ssh {shlex.quote(destination)}; exec zsh -i'
        launch_args = ['--type=os-window', 'zsh', '-c', ssh_cmd]
    else:
        launch_args = ['--type=os-window', '--cwd=current']

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)


if __name__ == '__main__':
    main(sys.argv)
