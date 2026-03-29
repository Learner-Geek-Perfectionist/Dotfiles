# smart_close.py
import sys

# Kitty 的 kittens 是内置的、不直接显现在文件系统中的工具。
from kittens.tui.handler import result_handler


def main(args):
    pass  # We do not need to process any arguments


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    tab = boss.active_tab
    if tab is None:
        return
    window = boss.active_window
    if window is None:
        return
    if len(tab.windows) == 1:
        # 最后一个窗口，直接关闭整个 OS window
        boss.close_os_window()
    else:
        window.close()


if __name__ == '__main__':
    main(sys.argv)
