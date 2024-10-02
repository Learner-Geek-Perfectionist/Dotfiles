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
        return  # No active tab found
    if len(tab.windows) > 1:
        boss.active_window.close()
    else:
        # 检查标签页是否还有其他窗口，如果没有则关闭整个窗口（即应用程序窗口）
        window = boss.active_window
        window.close()
        if len(tab.windows) == 0:
            # 试图关闭整个应用程序窗口，如果是最后一个窗口
            boss.window.close()


if __name__ == '__main__':
    main(sys.argv)