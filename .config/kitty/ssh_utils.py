# ssh_utils.py — smart_tab.py 和 smart_window.py 共享的 SSH 工具函数

import os
import socket
from urllib.parse import unquote, urlparse

from kitty.launch import launch as kitty_launch, parse_launch_args
from kittens.ssh.utils import get_connection_data, is_kitten_cmdline

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


def _extract_kitten_cmdline_destination(cmdline):
    """识别 kitty/kitten ssh 命令行中的目标主机。"""
    if not cmdline or not is_kitten_cmdline(cmdline):
        return None

    connection_data = get_connection_data(list(cmdline), extra_args=('--kitten',))
    if connection_data is None:
        return None

    return connection_data.hostname


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


def _extract_last_reported_cwd(window):
    parsed = _parse_last_reported_cwd(window)
    if parsed is None:
        return None

    if not parsed.path:
        return None

    return unquote(parsed.path)


def _parse_last_reported_cwd(window):
    try:
        reported_cwd = window.screen.last_reported_cwd
    except (AttributeError, OSError):
        return None

    if not reported_cwd:
        return None

    if isinstance(reported_cwd, (bytes, memoryview)):
        reported_cwd = bytes(reported_cwd).decode('utf-8', errors='replace')

    return urlparse(reported_cwd)


def _extract_ssh_kitten_cmdline(window):
    try:
        ssh_kitten_cmdline = window.ssh_kitten_cmdline
    except (AttributeError, OSError):
        return None

    if not callable(ssh_kitten_cmdline):
        return None

    try:
        cmdline = ssh_kitten_cmdline()
    except OSError:
        return None

    return list(cmdline) if cmdline else None


def _extract_cwd_of_child(window):
    try:
        cwd = window.cwd_of_child
    except (AttributeError, OSError):
        return None
    return cwd if cwd else None


def _window_looks_ssh_shaped(window, ssh_kitten_cmdline=None):
    if ssh_kitten_cmdline is not None:
        return True

    try:
        foreground_processes = window.child.foreground_processes
    except (AttributeError, OSError):
        return False

    for process in foreground_processes:
        cmdline = process.get('cmdline', []) or []
        if not cmdline:
            continue

        basename = cmdline[0].rsplit('/', 1)[-1]
        if basename == 'ssh' or is_kitten_cmdline(cmdline):
            return True

    return False


def _source_window_arg(window):
    return f'--source-window=id:{window.id}'


def _build_local_launch_args(launch_type, window, explicit_cwd=None):
    return [
        f'--type={launch_type}',
        _source_window_arg(window),
        f'--cwd={explicit_cwd}' if explicit_cwd else '--cwd=last_reported',
    ]


def _build_local_launch_args_without_cwd(launch_type, window):
    return [
        f'--type={launch_type}',
        _source_window_arg(window),
    ]


def _build_established_ssh_launch_args(launch_type, window):
    return [
        f'--type={launch_type}',
        _source_window_arg(window),
        '--cwd=last_reported',
        '--hold-after-ssh',
    ]


def _build_explicit_local_fallback_launch_args(launch_type, window, cwd, local_cwd, prefer_local_cwd=False):
    explicit_cwd = local_cwd if prefer_local_cwd else cwd
    if explicit_cwd is None:
        explicit_cwd = cwd if prefer_local_cwd else local_cwd

    if cwd is not None and local_cwd is not None and _paths_equivalent(cwd, local_cwd):
        explicit_cwd = cwd
    if explicit_cwd is None:
        return _build_local_launch_args_without_cwd(launch_type, window)

    return _build_local_launch_args(launch_type, window, explicit_cwd=explicit_cwd)


def _paths_equivalent(left, right):
    if not left or not right:
        return False

    return os.path.realpath(left) == os.path.realpath(right)


def _normalize_hostname(hostname):
    if not hostname:
        return None

    normalized = hostname.strip().rstrip('.').lower()
    return normalized or None


def _short_hostname(hostname):
    normalized = _normalize_hostname(hostname)
    if normalized is None:
        return None

    return normalized.partition('.')[0]


def _local_host_identity_sets():
    full_identities = {'localhost', '127.0.0.1', '::1'}
    short_identities = {'localhost'}

    normalized = _normalize_hostname(socket.gethostname())
    if normalized is None:
        return full_identities, short_identities

    full_identities.add(normalized)

    short = _short_hostname(normalized)
    if short is not None:
        short_identities.add(short)

    return full_identities, short_identities


def _hostname_matches_local_machine(hostname):
    normalized = _normalize_hostname(hostname)
    if normalized is None:
        return False

    full_identities, short_identities = _local_host_identity_sets()
    if normalized in full_identities:
        return True

    short = _short_hostname(normalized)
    if short is not None and short in short_identities:
        return True

    return False


def _window_reports_remote_cwd(window, cwd=None, local_cwd=None):
    parsed = _parse_last_reported_cwd(window)
    if parsed is None:
        return False

    url_host = _normalize_hostname(parsed.hostname)
    if url_host is not None:
        return not _hostname_matches_local_machine(url_host)

    return cwd is not None and local_cwd is not None and not _paths_equivalent(cwd, local_cwd)


def smart_launch(boss, launch_type, target_window_id=None):
    """智能启动新 tab 或 os-window。已建立 SSH 会话走 kitty 原生 launch，connecting 状态直接回本地。"""
    window = _resolve_source_window(boss, target_window_id)
    if window is None:
        return

    destination = extract_ssh_destination(window)
    ssh_kitten_cmdline = _extract_ssh_kitten_cmdline(window)
    if ssh_kitten_cmdline is not None:
        kitten_destination = _extract_kitten_cmdline_destination(ssh_kitten_cmdline)
        if kitten_destination is not None:
            destination = kitten_destination

    cwd = _extract_last_reported_cwd(window)
    local_cwd = _extract_cwd_of_child(window)
    ssh_shaped = _window_looks_ssh_shaped(window, ssh_kitten_cmdline=ssh_kitten_cmdline)

    if destination is None:
        if ssh_shaped:
            launch_args = _build_explicit_local_fallback_launch_args(
                launch_type,
                window,
                cwd,
                local_cwd,
                prefer_local_cwd=True,
            )
        else:
            launch_args = _build_explicit_local_fallback_launch_args(
                launch_type,
                window,
                cwd,
                local_cwd,
            )
    elif cwd is not None and _window_reports_remote_cwd(window, cwd, local_cwd):
        launch_args = _build_established_ssh_launch_args(launch_type, window)
    else:
        launch_args = _build_explicit_local_fallback_launch_args(
            launch_type,
            window,
            cwd,
            local_cwd,
            prefer_local_cwd=True,
        )

    opts, remaining = parse_launch_args(launch_args)
    kitty_launch(boss, opts, remaining)
