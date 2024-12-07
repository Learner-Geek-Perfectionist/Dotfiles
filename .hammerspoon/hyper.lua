local status, hyperModeAppMappings = pcall(require, 'hyper-apps')

-- 检查模块是否成功加载
if not status then
    hs.logger.new('hyper', 'error'):e('Failed to load hyper-apps module')
    return  -- 加载失败时提前退出
end

-- 遍历映射并绑定快捷键
for i, mapping in ipairs(hyperModeAppMappings) do
    local key = mapping[1]
    local app = mapping[2]
    hs.hotkey.bind({ 'cmd', 'shift' }, key, function()
        -- 根据 app 类型来执行不同操作
        if type(app) == 'string' then
            -- 如果是字符串，尝试打开应用
            hs.application.open(app)
        elseif type(app) == 'function' then
            -- 如果是函数，直接调用
            app()
        else
            -- 记录无效的映射
            hs.logger.new('hyper', 'error'):e('Invalid mapping for Hyper + ' .. key)
        end
    end)
end