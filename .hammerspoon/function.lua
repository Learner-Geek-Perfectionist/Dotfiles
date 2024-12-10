local mod = {}  -- 创建一个新的表作为模块

function mod.launchOrToggleAppByBundleID(bundleID)
    local app = hs.application.get(bundleID)  -- 获取应用对象

    if app and #app:allWindows() > 0 then
        local windows = app:visibleWindows()  -- 获取可见窗口列表
        if app:isFrontmost() and #windows > 0 then
            app:hide()  -- 如果应用是最前端并且有可见窗口，则隐藏它
        else
            -- 应用不是最前端或没有可见窗口，激活应用
            hs.execute("open -b '" .. bundleID .. "'")
        end
    else
        -- 应用未运行或无窗口，启动并激活应用
        hs.execute("open -b '" .. bundleID .. "'")
    end
end

return mod  -- 返回这个表作为模块的输出