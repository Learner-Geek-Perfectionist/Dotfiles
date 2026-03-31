-- keyConfig.lua — 快捷键配置数据

local M = {}

M.keyConfig = {
    { 'w', 'com.tencent.xinWeChat' },           -- "W" for "WeChat"
    { 'f', 'com.apple.finder' },                -- "F" for "Finder"
    { 'g', 'com.google.Chrome' },                -- "G" for "Google Chrome"
    { 's', 'com.apple.Safari' },                -- "S" for "Safari"
    { 't', 'net.kovidgoyal.kitty' },            -- "T" for "kitty"
    { 'v', 'com.microsoft.VSCode' },            -- "V" for "VSCode"
    { 'q', 'com.tencent.qq' },                  -- "Q" for "QQ"
    { 'd', 'com.hnc.Discord' },                 -- "D" for "Discord"
    { 'm', 'party.mihomo.app' },                -- "M" for "Mihomo Party"
    { 'c', 'com.anthropic.claudefordesktop' },  -- "C" for "Claude"
    { 'i', 'com.jetbrains.intellij' },          -- "I" for "IntelliJ IDEA"
    { 'a', 'com.google.android.studio' },       -- "A" for "Android Studio"
    { 'p', 'com.jetbrains.pycharm' },           -- "P" for "Pycharm"
    { 'u', 'com.mac.utility.clipboard.paste' }, -- "U" for "upaste"
    { 'o', 'dev.kdrag0n.MacVirt' },             -- "O" for "orbstack"
    { '.', 'com.apple.ActivityMonitor' },       -- "." for "ActivityMonitor"
}

M.HyperKey = { "ctrl", "alt", "cmd" }

M.windowsConfig = {
    'left',
    'right',
    'up',
    'down',
}

return M
