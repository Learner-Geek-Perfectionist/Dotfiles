-- 全局变量来保存防休眠的状态
caffeinateMode = false

-- 封装设置防休眠状态的函数
function toggleCaffeinateMode()
    caffeinateMode = not caffeinateMode  -- 切换防休眠状态

    if caffeinateMode then
        -- 启用防休眠
        hs.caffeinate.set("displayIdle", true, true)
        hs.alert.show("Caffeinate Mode: ON ✅")
    else
        -- 禁用防休眠
        hs.caffeinate.set("displayIdle", false, true)
        hs.alert.show("Caffeinate Mode: OFF ❌")
    end
end
