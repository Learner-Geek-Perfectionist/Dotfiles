local status, hyperModeAppMappings = pcall(require, 'hyper-apps')

-- 检查模块是否成功加载
if not status then
    hs.logger.new('hyper', 'error'):e('Failed to load hyper-apps module')
    return  -- 加载失败时提前退出
end

-- 加载 function 模块
local ModsuperOpenApp = require("function")

-- 遍历映射并绑定快捷键
for key, appID in ipairs(hyperModeAppMappings) do
    hs.hotkey.bind({ 'cmd', 'shift' }, key, ModsuperOpenApp.superOpenApp(appID))
end