-- getFrontApp 是指向函数的指针
getFrontApp = hs.application.frontmostApplication
_filter = hs.fnutils.filter

local mod = {}  -- 创建一个新的表来作为模块
-- 超级启动软件, 各种自动化让你高潮
function mod.superOpenApp(appID)
    local currApp = getFrontApp()
    if (appID ~= currApp:bundleID()) then
        -- 如果当前应用不是指定应用, 则启动或者激活指定应用
        local app = hs.application.get(appID)
        -- 如果没有启动, 先启动
        if not app then
            -- Chrome 使用 debug 模式启动
            --if (appID == qk.apps.chrome) then
            --    exec([[ open -a "Google Chrome" --args --remote-debugging-port=9222 ]])
            -- Tips: get browserWSEndpoint => http://localhost:9222/json/version
            --else
            app = hs.application.open(appID) -- 启动应用 (其实也会切换)
            --end
        end
        -- 然后, 切换应用
        app:activate()
        -- 有时候Finder会切换到桌面上, 需要切换到 Standard Window
        -- 不再使用了, 直接可以退出Finder
        if (appID == qk.apps.finder) then
            local wins = _filter(app:allWindows(), function(x) return x:title() ~= '' end)
            if (#wins > 0) then
                wins[1]:focus()
            else
                -- 等待窗口加载完成
                doAfter(0.1, function () selectMenuItem({'文件', '新建标签页'}) end)
            end
        end
    else
        -- 如果当前应用已经是指定应用 =>
        -- 如果有多个窗口, 则切换到当前应用的下一个窗口
        -- ⚠️ 这个无法获取到其他空间的窗口, 需要使用hs.window.filter才行
        -- ⚠️ 倒不如说没必要去处理, !!! 不推荐使用多空间 !!!
        local currWins = _filter(currApp:allWindows(), function(x) return x:isStandard() end)
        -- 如果没有标准窗口, 则什么都不做(
        if (#currWins == 0) then
            -- 如果是 Finder 则说明当前在桌面, 则新建一个窗口
            -- 不再使用了, 直接删除桌面
            if (appID == qk.apps.finder) then selectMenuItem({'文件', '新建标签页'}) end
            -- 结束
            return
        end
        -- 获取所有窗口的ID并排序
        local allWinIds = hs.fnutils.map(currWins, function(y) return y:id() end)
        table.sort(allWinIds)
        -- 获取当前窗口在所有窗口中的下标, 当前窗口如果不是标准窗口, 则设置为第一个标准窗口
        local currWinIdx = hs.fnutils.indexOf(allWinIds, currApp:focusedWindow():id())
        local nextWinIdx = currWinIdx and (currWinIdx % #allWinIds) + 1 or 1
        -- 激活下一个窗口
        --hs.alert.show('window #' .. nextWinIdx)
        hs.window.get(allWinIds[nextWinIdx]):focus()
    end
end


return mod  -- 返回这个表作为模块的输出