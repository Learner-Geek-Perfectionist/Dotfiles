local mod = {}  -- 创建一个新的表来作为模块

-- 定义一个函数，输入参数为 bundleID
function mod.launchOrToggleAppByBundleID(bundleID)
    local app = hs.application.get(bundleID)  -- 获取应用对象

    -- 检查应用是否存在且有打开的窗口
    if app and #app:allWindows() > 0 then
        if app:isFrontmost() then
            app:hide()  -- 如果应用已经是最前端，则隐藏它
        else
            app:activate()  -- 否则，激活应用
        end
    else
        hs.application.launchOrFocusByBundleID(bundleID)  -- 如果应用没有运行或没有窗口，启动它
    end
end

return mod  -- 返回这个表作为模块的输出