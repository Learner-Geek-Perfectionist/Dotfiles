# smart_launcher.py — smart_tab.py 和 smart_window.py 共享的 kitten 入口逻辑

from functools import lru_cache
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import traceback
import sys

from kittens.tui.handler import result_handler


def main(args):
    pass


@lru_cache(maxsize=1)
def load_ssh_utils():
    module_path = Path(__file__).resolve().with_name('ssh_utils.py')
    spec = spec_from_file_location('kitty_smart_ssh_utils', module_path)
    if spec is None or spec.loader is None:
        raise ImportError(f'Unable to load ssh_utils from {module_path}')

    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_handle_result(launch_type, error_title):
    @result_handler(no_ui=True)
    def handle_result(args, result, target_window_id, boss):
        try:
            load_ssh_utils().smart_launch(boss, launch_type, target_window_id)
        except Exception:
            tb = traceback.format_exc()
            print(tb, file=sys.stderr, end='')

            show_error = getattr(boss, 'show_error', None)
            if callable(show_error):
                try:
                    show_error(error_title, tb)
                except Exception:
                    pass

            raise

    return handle_result
