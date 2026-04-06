# smart_close.py
# Kitty 对象层级：Boss → 系统窗口 → Tab → Window（分屏窗格）
# Cmd+W 按层级关闭：分屏 → Tab → 系统窗口 → 退出（不可跳级）
import sys

# Kitty 的 kittens 是内置的、不直接显现在文件系统中的工具。
from kittens.tui.handler import result_handler


def main(args):
    pass  # 这里不需要处理任何参数


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    tab = boss.active_tab
    if tab is None:
        return
    window = boss.active_window
    if window is None:
        return

    if len(tab.windows) > 1:
        # 当前 tab 有多个分屏窗格 → 关闭当前窗格
        window.close()
    else:
        # 当前 tab 只有一个窗口，检查是否有多个 tab
        tm = boss.active_tab_manager
        if tm is not None and len(tm.tabs) > 1:
            # 多个 tab → 只关闭当前 tab
            boss.close_tab()
        elif len(boss.os_window_map) > 1:
            # 多个 OS 窗口 → 关闭当前 OS 窗口
            boss.close_os_window()
        else:
            # 最后一个 OS 窗口的最后一个 tab → 彻底退出 Kitty
            boss.quit()


if __name__ == '__main__':
    main(sys.argv)
