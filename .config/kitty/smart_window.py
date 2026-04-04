# smart_window.py — Cmd+N 智能开新 os-window
# 普通情况：继承当前目录开新 os-window
# SSH 会话中：优先在 2 秒内复用远端主机与目录
# 若 SSH 失败或超时：自动回退到本地 zsh，window 保持可用

import sys
import traceback
import inspect
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

from kittens.tui.handler import result_handler


def main(args):
    pass


def current_script_path():
    for candidate in (
        globals().get('__file__'),
        inspect.getsourcefile(load_ssh_utils),
        inspect.getfile(load_ssh_utils),
        sys.argv[0] if sys.argv else None,
    ):
        if candidate:
            return Path(candidate).resolve()

    raise RuntimeError('Unable to determine smart_window.py path')


def load_ssh_utils():
    module_path = current_script_path().with_name('ssh_utils.py')
    spec = spec_from_file_location('kitty_smart_ssh_utils', module_path)
    if spec is None or spec.loader is None:
        raise ImportError(f'Unable to load ssh_utils from {module_path}')

    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    try:
        load_ssh_utils().smart_launch(boss, "os-window", target_window_id)
    except Exception:
        tb = traceback.format_exc()
        print(tb, file=sys.stderr, end='')

        show_error = getattr(boss, 'show_error', None)
        if callable(show_error):
            try:
                show_error('Kitty smart window failed', tb)
            except Exception:
                pass

        raise


if __name__ == '__main__':
    main(sys.argv)
