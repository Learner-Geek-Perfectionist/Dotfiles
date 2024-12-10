local mod = {}  -- 创建一个新的表来作为模块

function mod.launchOrToggleAppByBundleID(bundleID)
    local app = hs.application.get(bundleID)  -- 获取应用对象

    -- 检查应用是否存在且有打开的窗口
    if app and #app:allWindows() > 0 then
        if app:isFrontmost() then
            -- 如果应用已经是最前端，而且不是Finder或特定应用，尝试重新激活而不是隐藏
            if bundleID ~= "com.apple.finder" and bundleID ~= "party.mihomo.app" then
                hs.execute("open -b '" .. bundleID .. "'")  -- 强制激活应用
            else
                app:hide()  -- 如果是Finder等，可以选择隐藏
            end
        else
            -- 应用不是最前端，尝试激活
            hs.execute("open -b '" .. bundleID .. "'")
        end
    else
        -- 应用未运行或无窗口
        if bundleID == "com.apple.finder" or bundleID == "party.mihomo.app" then
            hs.execute("open -a '" .. (bundleID == "com.apple.finder" and "Finder" or "Mihomo Party") .. "'")
        else
            hs.execute("open -b '" .. bundleID .. "'")  -- 启动并激活应用
        end
    end
end

return mod  -- 返回这个表作为模块的输出