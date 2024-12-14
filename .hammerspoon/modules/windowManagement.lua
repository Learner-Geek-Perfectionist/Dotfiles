---@diagnostic disable: lowercase-global
-- 加载Hammerspoon的窗口管理模块
local window = require "hs.window"
-- 定义快捷键状态跟踪

-- 创建一个方便使用的函数来移动窗口
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
        win:setFrame({x = max.x, y = max.y + max.h / 2, w = max.w, h = max.h / 2})
    end
end

-- 创建一个方便使用的函数来移动窗口到不同位置
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

 
