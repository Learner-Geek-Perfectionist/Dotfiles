# ssh_utils.py — smart_tab.py 和 smart_window.py 共享的 SSH 工具函数

import shlex

from kitty.launch import launch as kitty_launch, parse_launch_args

# ssh 中需要跟参数值的选项字母（如 -p 22、-i keyfile、-o Option=val）
_SSH_OPTS_WITH_ARG = frozenset('bcDEeFIiJLlmOopQRSWw')


def _extract_kitty_ssh_destination(cmdline):
    """只识别 kitty kitten ssh 启动的交互式远程 shell。"""
    try:
        dash_idx = cmdline.index('--')
        destination = cmdline[dash_idx + 1]
    except (ValueError, IndexError):
        return None

    remote_cmd = cmdline[dash_idx + 2:]
    if remote_cmd[:3] == ['exec', 'sh', '-c']:
        return destination
    return None


def _extract_plain_ssh_destination(cmdline):
    """只把 `ssh host` 视为交互式 SSH，会忽略 git-over-ssh 等远程命令。"""
    args = cmdline[1:]
    skip_next = False

    for idx, arg in enumerate(args):
        if skip_next:
            skip_next = False
            continue

        if arg == '--':
            if idx + 1 < len(args):
                destination = args[idx + 1]
                remote_cmd = args[idx + 2:]
                return destination if not remote_cmd else None
            return None

        if arg.startswith('-'):
            if len(arg) == 2 and arg[1] in _SSH_OPTS_WITH_ARG:
                skip_next = True
            continue

        destination = arg
        remote_cmd = args[idx + 1:]
        return destination if not remote_cmd else None

    return None


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

        destination = _extract_kitty_ssh_destination(cmdline)
        if destination is not None:
            return destination

        destination = _extract_plain_ssh_destination(cmdline)
        if destination is not None:
            return destination

    return None


def smart_launch(boss, launch_type, target_window_id=None):
    """智能启动新 tab 或 os-window。SSH 中先连远程，exit 后回落本地 zsh。

    Args:
        boss: kitty.boss.Boss 实例
        launch_type: "tab" 或 "os-window"
        target_window_id: 触发当前 kitten 的源窗口 id
    """
    window = None
    if target_window_id is not None:
        window = boss.window_id_map.get(target_window_id)
    if window is None:
        window = boss.active_window
    if window is None:
        return

    destination = extract_ssh_destination(window)
    source_window_arg = f'--source-window=id:{window.id}'

    if destination is not None:
        ssh_cmd = f'kitten ssh {shlex.quote(destination)}; exec zsh -i'
        launch_args = [f'--type={launch_type}', source_window_arg, 'zsh', '-c', ssh_cmd]
    else:
        launch_args = [f'--type={launch_type}', source_window_arg, '--cwd=last_reported']

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)
