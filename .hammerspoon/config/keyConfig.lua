---@diagnostic disable: lowercase-global
-- 定义快捷键配置表
keyConfig = {
  { 'w', 'com.tencent.xinWeChat' },    -- "W" for "WeChat"
  { 'f', 'com.apple.finder' },         -- "F" for "Finder"
  { 'g', 'com.openai.chat' },          -- "G" for "ChatGPT"
  { 's', 'com.apple.Safari' },         -- "S" for "Safari"
  { 't', 'net.kovidgoyal.kitty' },     -- "T" for "kitty"
  { 'v', 'com.microsoft.VSCode' },     -- "V" for "VSCode"
  { 'q', 'com.tencent.qq' },           -- "Q" for "QQ"
  { 'd', 'com.hnc.Discord' },          -- "D" for "Discord"
  { 'm', 'party.mihomo.app' },         -- "M" for "Mihomo Party"
  { 'c', 'com.jetbrains.CLion' },      -- "C" for "Clion"
  { 'i', 'com.jetbrains.intellij' },   -- "I" for "IntelliJ IDEA"
  { 'a', 'com.google.android.studio' }, -- "A" for "Android Studio"
  { 'p', 'com.jetbrains.pycharm' },      -- "P" for "Pycharm"
  { 'u', 'com.mac.utility.clipboard.paste' },      -- "U" for "upaste"
  { '.', 'com.apple.ActivityMonitor' },      -- "." for "ActivityMonitor"
}
-- 区分大小写
HyperKey = { "ctrl", "alt", "cmd", "shift" }

windowsConfig = {
  'left',
  'right',
  'up',
  'down',
}

--  目前弃用了，使用微信输入法可以完全代替 --
-- inputMethodMap = {
--   ["com.google.android.studio"] = "com.apple.keylayout.ABC",
--   ["com.jetbrains.intellij"] = "com.apple.keylayout.ABC",
--   ["com.jetbrains.CLion"] = "com.apple.keylayout.ABC",
--   ["com.jetbrains.pycharm"] = "com.apple.keylayout.ABC",
--   ["com.microsoft.VSCode"] = "com.apple.keylayout.ABC",
--   ["net.kovidgoyal.kitty"] = "com.apple.keylayout.ABC",
--   ["com.apple.finder"] = "com.apple.keylayout.ABC",

--   ["com.openai.chat"] = "im.rime.inputmethod.Squirrel.Hans",
--   ["com.tencent.xinWeChat"] = "im.rime.inputmethod.Squirrel.Hans",
--   ["com.hnc.Discord"] = "im.rime.inputmethod.Squirrel.Hans",
--   ["com.tencent.qq"] = "im.rime.inputmethod.Squirrel.Hans",
--   ["com.apple.Safari"] = "im.rime.inputmethod.Squirrel.Hans",
--   ["com.mac.utility.clipboard.paste"] = "im.rime.inputmethod.Squirrel.Hans",
--   -- 在这里添加更多的应用程序和输入法映射
-- }

--  目前弃用了，使用微信输入法可以完全代替 --