# ssh_utils.py — smart_tab.py 和 smart_window.py 共享的 SSH 工具函数

import shlex

from kitty.launch import launch as kitty_launch, parse_launch_args

# ssh 中需要跟参数值的选项字母（如 -p 22、-i keyfile、-o Option=val）
_SSH_OPTS_WITH_ARG = frozenset('bcDEeFIiJLlmOopQRSWw')


def extract_ssh_destination(window):
    """从前台进程中提取 SSH 目标地址（user@host 或 hostname）。找到返回字符串，否则返回 None。"""
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
            pass

        # 没有 '--'，按 SSH 参数语法解析，找第一个非选项参数（即目标主机）
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


def smart_launch(boss, launch_type):
    """智能启动新 tab 或 os-window。SSH 中先连远程，exit 后回落本地 zsh。

    Args:
        boss: kitty.boss.Boss 实例
        launch_type: "tab" 或 "os-window"
    """
    window = boss.active_window
    if window is None:
        return

    destination = extract_ssh_destination(window)

    if destination is not None:
        ssh_cmd = f'kitten ssh {shlex.quote(destination)}; exec zsh -i'
        launch_args = [f'--type={launch_type}', 'zsh', '-c', ssh_cmd]
    else:
        launch_args = [f'--type={launch_type}', '--cwd=current']

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)
