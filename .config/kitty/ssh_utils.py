# ssh_utils.py — smart_tab.py 和 smart_window.py 共享的 SSH 工具函数

import shlex

from kitty.launch import launch as kitty_launch, parse_launch_args

# ssh 中需要跟参数值的选项字母（如 -p 22、-i keyfile、-o Option=val）
_SSH_OPTS_WITH_ARG = frozenset('bcDEeFIiJLlmOopQRSWw')
_AUTO_SSH_CONNECT_TIMEOUT_SECONDS = 2
_AUTO_SSH_OPTIONS = (
    '-oBatchMode=yes',
    f'-oConnectTimeout={_AUTO_SSH_CONNECT_TIMEOUT_SECONDS}',
    '-oConnectionAttempts=1',
    '-oStrictHostKeyChecking=yes',
)
_AUTO_SSH_FALLBACK_NOTICE = 'kitty: SSH clone failed or timed out; fell back to local shell.'


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
        foreground_processes = window.child.foreground_processes
    except (AttributeError, OSError):
        return None

    for process in foreground_processes:
        cmdline = process.get('cmdline', []) or []
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


def _resolve_source_window(boss, target_window_id=None):
    if target_window_id is not None:
        window = boss.window_id_map.get(target_window_id)
        if window is not None:
            return window
    return boss.active_window


def _extract_window_cwd(window):
    try:
        cwd = window.cwd_of_child
    except (AttributeError, OSError):
        return None

    return cwd or None


def _source_window_arg(window):
    return f'--source-window=id:{window.id}'


def _build_local_launch_args(launch_type, window):
    return [
        f'--type={launch_type}',
        _source_window_arg(window),
        '--cwd=last_reported',
    ]


def _build_auto_ssh_shell_command(destination, cwd):
    ssh_cmd = shlex.join(
        [
            'kitten',
            'ssh',
            '--kitten',
            f'cwd={cwd}',
            *_AUTO_SSH_OPTIONS,
            destination,
        ]
    )
    fallback_notice = shlex.join(['printf', '%s\n', _AUTO_SSH_FALLBACK_NOTICE])
    return f'if {ssh_cmd}; then exec zsh -i; else {fallback_notice}; exec zsh -i; fi'


def _build_remote_launch_args(launch_type, window, destination, cwd):
    return [
        f'--type={launch_type}',
        _source_window_arg(window),
        'zsh',
        '-c',
        _build_auto_ssh_shell_command(destination, cwd),
    ]


def smart_launch(boss, launch_type, target_window_id=None):
    """智能启动新 tab 或 os-window。SSH 可复用时尝试继承远端 cwd，失败后回落本地 zsh。"""
    window = _resolve_source_window(boss, target_window_id)
    if window is None:
        return

    destination = extract_ssh_destination(window)
    cwd = _extract_window_cwd(window)

    if destination is not None and cwd is not None:
        launch_args = _build_remote_launch_args(launch_type, window, destination, cwd)
    else:
        launch_args = _build_local_launch_args(launch_type, window)

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)
