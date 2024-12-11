local mod = {}
mod.lastChange = hs.pasteboard.changeCount()  -- 初始化剪贴板更改计数

function mod.checkPasteboard()
    local currentChange = hs.pasteboard.changeCount()
    if currentChange ~= mod.lastChange then
        mod.lastChange = currentChange
        local content = hs.pasteboard.getContents()  -- 获取剪贴板内容
        if content then
            hs.notify.new({
                title = "Clipboard Updated",
                informativeText = content,
                withdrawAfter = 5  -- 设置通知持续时间（秒）
            }):send()
        end
    end
end

-- 设置定时器，每隔1秒检查一次剪贴板
mod.timer = hs.timer.new(1, mod.checkPasteboard)
mod.timer:start()

return mod