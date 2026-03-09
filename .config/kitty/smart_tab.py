# smart_tab.py — Cmd+E 智能开新 tab
# 普通情况：继承当前目录开新 tab（原有行为）
# SSH 会话中：新 tab 先启动本地 zsh，再自动 SSH 进去
# 这样 exit 退出 SSH 后，回落到本地 zsh，tab 不会消失

import sys
import shlex

from kittens.tui.handler import result_handler
# 在 handle_result 中使用（该函数运行在 kitty 主进程，kitty.launch 必定可用）
from kitty.launch import launch as kitty_launch, parse_launch_args


def main(args):
    pass


def _extract_ssh_destination(window):
    """从前台进程中提取 SSH 目标地址（user@host）。找到返回字符串，否则返回 None。"""
    try:
        fp = window.child.foreground_processes
    except (AttributeError, OSError):
        return None

    for p in fp:
        cmdline = p.get('cmdline', []) or []
        if not cmdline:
            continue
        basename = cmdline[0].rsplit('/', 1)[-1]
        if basename != 'ssh':
            continue

        # kitten ssh 生成的 cmdline 格式：
        # /usr/bin/ssh -t -o ... -- user@host exec sh -c '...'
        # 只需要 '--' 后面的第一个参数（目标地址）
        try:
            dash_idx = cmdline.index('--')
            return cmdline[dash_idx + 1]
        except (ValueError, IndexError):
            # 没有 '--'，尝试从参数中找 user@host 模式
            for arg in cmdline[1:]:
                if '@' in arg and not arg.startswith('-'):
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
        launch_args = ['--type=tab', 'zsh', '-c', ssh_cmd]
    else:
        launch_args = ['--type=tab', '--cwd=current']

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)


if __name__ == '__main__':
    main(sys.argv)
