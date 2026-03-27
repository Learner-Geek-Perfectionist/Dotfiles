# smart_tab.py — 智能开新 tab / os-window
# 用法：kitten ./smart_tab.py [--type=tab|os-window]（默认 tab）
# 普通情况：继承当前目录（原有行为）
# SSH 会话中：先启动本地 zsh，再自动 SSH 进去
# 这样 exit 退出 SSH 后，回落到本地 zsh，tab/window 不会消失

import sys
import shlex

from kittens.tui.handler import result_handler
# 在 handle_result 中使用（该函数运行在 kitty 主进程，kitty.launch 必定可用）
from kitty.launch import launch as kitty_launch, parse_launch_args


def main(args):
    pass


def _extract_ssh_destination(window):
    """从前台进程中提取 SSH 目标地址（user@host 或 hostname）。找到返回字符串，否则返回 None。"""
    try:
        fp = window.child.foreground_processes
    except (AttributeError, OSError):
        return None

    # ssh 中需要跟参数值的选项字母（如 -p 22、-i keyfile、-o Option=val）
    _SSH_OPTS_WITH_ARG = set('bcDEeFIiJLlmOopQRSWw')

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
            pass

        # 没有 '--'，按 SSH 参数语法解析，找第一个非选项参数（即目标主机）
        # 支持 user@host 和纯 hostname（如 ssh yumi）两种格式
        skip_next = False
        for arg in cmdline[1:]:
            if skip_next:
                skip_next = False
                continue
            if arg.startswith('-'):
                # -p 22 这类选项，下一个参数是值，需要跳过
                if len(arg) == 2 and arg[1] in _SSH_OPTS_WITH_ARG:
                    skip_next = True
                continue
            # 第一个非选项参数就是目标主机
            return arg

    return None


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.active_window
    if window is None:
        return

    launch_type = 'tab'
    for arg in args[1:]:
        if arg.startswith('--type='):
            launch_type = arg.split('=', 1)[1]

    destination = _extract_ssh_destination(window)

    if destination is not None:
        ssh_cmd = f'kitten ssh {shlex.quote(destination)}; exec zsh -i'
        launch_args = [f'--type={launch_type}', 'zsh', '-c', ssh_cmd]
    else:
        launch_args = [f'--type={launch_type}', '--cwd=current']

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)


if __name__ == '__main__':
    main(sys.argv)
