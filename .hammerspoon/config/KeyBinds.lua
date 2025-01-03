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

-- HyperKey + ` 切换 App 窗口
hs.hotkey.bind(HyperKey, '`', function()
    switchFocusedAppWindow()
end)


--  HyperKey + L，用于锁屏
hs.hotkey.bind(HyperKey, "L", function()
    hs.caffeinate.lockScreen()
end)


-- HyperKey + O，用于切换防休眠状态
hs.hotkey.bind(HyperKey, "O", toggleCaffeinateMode)

-- 初始化提示
hs.alert.show("Window management keybindings with corners enabled")
