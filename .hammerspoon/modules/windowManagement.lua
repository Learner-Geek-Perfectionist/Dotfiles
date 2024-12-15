---@diagnostic disable: lowercase-global

-- 加载Hammerspoon的窗口管理模块
local window = require "hs.window"
-- 定义快捷键状态跟踪

-- 创建一个函数来移动到 左、右、最大化、下。
function moveWindowToPosition(position)
    -- 获取当前活动窗口
    local win = window.focusedWindow()
    -- 确保窗口存在
    if not win then return end

    -- 获取屏幕及其frame
    local screen = win:screen()
    local max = screen:frame()

    -- 计算窗口应该移动到的位置
    if position == "left" then
        win:setFrame({x = max.x, y = max.y, w = max.w / 2, h = max.h})
    elseif position == "right" then
        win:setFrame({x = max.x + max.w / 2, y = max.y, w = max.w / 2, h = max.h})
    elseif position == "up" then
        -- 最大化窗口
        win:setFrame({x = max.x, y = max.y, w = max.w, h = max.h})
    elseif position == "down" then
        -- 窗口占屏幕的80%，居中
        local newWidth = max.w * 0.8
        local newHeight = max.h * 0.8
        local newX = max.x + (max.w - newWidth) / 2
        local newY = max.y + (max.h - newHeight) / 2
        win:setFrame({x = newX, y = newY, w = newWidth, h = newHeight})
    end
end

-- 创建一个函数来移动到 左上、右上、左下、右下。
-- 目前未使用
function moveWindowToCorner(corner)
    -- 获取当前活动窗口
    local win = window.focusedWindow()
    -- 确保窗口存在
    if not win then return end

    -- 获取屏幕及其frame
    local screen = win:screen()
    local max = screen:frame()

    -- 根据corner参数移动窗口
    if corner == "topLeft" then
        win:setFrame({x = max.x, y = max.y, w = max.w / 2, h = max.h / 2})
    elseif corner == "topRight" then
        win:setFrame({x = max.x + max.w / 2, y = max.y, w = max.w / 2, h = max.h / 2})
    elseif corner == "bottomLeft" then
        win:setFrame({x = max.x, y = max.y + max.h / 2, w = max.w / 2, h = max.h / 2})
    elseif corner == "bottomRight" then
        win:setFrame({x = max.x + max.w / 2, y = max.y + max.h / 2, w = max.w / 2, h = max.h / 2})
    end
end


-- 创建一个函数来切换 App 的窗口
--function switchFocusedAppWindow()
--    local currApp = hs.application.frontmostApplication()
--    -- hs.alert.show("Focused Application: " .. currApp:name())
--
--    -- 获取当前应用的所有标准窗口
--    local currWins = hs.fnutils.filter(currApp:allWindows(), function(x) return x:isStandard() end)
--    if #currWins > 0 then
--        -- 对窗口ID进行排序
--        local allWinIds = hs.fnutils.map(currWins, function(y) return y:id() end)
--        table.sort(allWinIds)
--
--        -- 找到当前焦点窗口的ID，计算下一个窗口的索引
--        local currWinIdx = hs.fnutils.indexOf(allWinIds, currApp:focusedWindow():id())
--        local nextWinIdx = currWinIdx and (currWinIdx % #allWinIds) + 1 or 1
--
--        -- 激活下一个窗口
--        hs.window.get(allWinIds[nextWinIdx]):focus()
--        -- hs.alert.show("Switched to Window #" .. nextWinIdx)
--    else
--        -- hs.alert.show("No standard windows available for switching.")
--    end
--end

 
