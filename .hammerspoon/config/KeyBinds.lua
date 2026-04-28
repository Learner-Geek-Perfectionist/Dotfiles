-- KeyBinds.lua — 快捷键绑定（显式 require 所有依赖）

local cfg = require('config.keyConfig')
local appToggler = require('modules.AppToggler')
local winMgmt = require('modules.windowManagement')
local caffeinate = require('modules.caffeinate')

-- 遍历映射并绑定 App 快捷键
for _, appMapping in ipairs(cfg.keyConfig) do
    local key, appID = appMapping[1], appMapping[2]
    hs.hotkey.bind(cfg.HyperKey, key, function()
        appToggler.toggle(appID)
    end)
end

-- Hyper + arrows need eventtap so Ctrl-Up/Down cannot be stolen by Mission Control.
winMgmt.startHyperArrowEventtap()

-- HyperKey + ` / Cmd + ` 都走自定义切窗；Cmd + ` 仍保留跨屏搬窗语义。
hs.hotkey.bind(cfg.HyperKey, '`', function()
    winMgmt.switchFocusedAppWindow()
end)
hs.hotkey.bind({ "cmd" }, '`', function()
    winMgmt.switchFocusedAppWindow()
end)

-- HyperKey + L，用于锁屏
hs.hotkey.bind(cfg.HyperKey, "L", function()
    hs.caffeinate.lockScreen()
end)

-- HyperKey + 1，用于切换防休眠状态
hs.hotkey.bind(cfg.HyperKey, '1', function()
    caffeinate.toggle()
end)

return {}
