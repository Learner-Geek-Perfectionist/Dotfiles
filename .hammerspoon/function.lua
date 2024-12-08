local mod = {}  -- 创建一个新的表来作为模块
-- 定义一个函数，输入参数为 bundleID
function mod.launchAppByBundleID(bundleID)
    -- 使用 hs.application.launchOrFocusByBundleID 函数根据 bundleID 打开应用
    local success = hs.application.launchOrFocusByBundleID(bundleID)
    if success then
        print("Application launched successfully")
    else
        print("Failed to launch application")
    end
end
return mod  -- 返回这个表作为模块的输出