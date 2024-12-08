local status, hyperModeAppMappings = pcall(require, 'key-mapping')

-- 检查模块是否成功加载
if not status then
    hs.logger.new('hyper', 'error'):e('Failed to load key-mapping module')
    return -- 加载失败时提前退出
end

-- 加载 function 模块
local mod = require("function")

-- 遍历映射并绑定快捷键
for _, appMapping in ipairs(hyperModeAppMappings) do
    local key, appID = appMapping[1], appMapping[2]
    hs.hotkey.bind({ 'ctrl', 'alt', 'cmd', 'shift' }, key, function()
        mod.launchAppByBundleID(appID)
    end)
end
