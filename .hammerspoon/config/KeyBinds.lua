---@diagnostic disable: lowercase-global

-- 遍历映射并绑定 App 快捷键
for _, appMapping in ipairs(keyConfig) do
    local key, appID = appMapping[1], appMapping[2]
    hs.hotkey.bind(HyperKey, key, function()
        AppToggler(appID)
    end)
end

-- 遍历映射并绑定 windows-position 快捷键
for _, key in ipairs(windowsConfig) do
    hs.hotkey.bind(HyperKey, key, function()
        moveWindowToPosition(key)
    end)
end

-- cmd + . 切换活动管理器 APP。
hs.hotkey.bind("cmd", ".", function() AppToggler("com.apple.ActivityMonitor") end)

-- 绑定切换 App 窗口的快捷键
--hs.hotkey.bind(HyperKey, '`', function()
--    switchFocusedAppWindow()
--end)

-- 初始化提示
hs.alert.show("Window management keybindings with corners enabled")
