-- windowManagement.lua — 窗口位置管理 + 窗口切换

local M = {}

local PARALLELS_MACVM_BUNDLE_ID = "com.parallels.macvm"
local hyperArrowEventtap = nil
local hyperArrowPositions = nil

local function collectStandardWindows(app)
    if not app then
        return {}
    end

    local standardWindows = {}
    for _, window in ipairs(app:allWindows() or {}) do
        if window:isStandard() then
            table.insert(standardWindows, window)
        end
    end

    -- Use window ids to keep app-internal cycling stable across focus changes.
    table.sort(standardWindows, function(left, right)
        return (left:id() or 0) < (right:id() or 0)
    end)

    return standardWindows
end

local function nextIndex(items, currentId, idGetter)
    if not items or #items == 0 then
        return nil
    end

    idGetter = idGetter or function(item)
        return item
    end

    for index, item in ipairs(items) do
        if idGetter(item) == currentId then
            return (index % #items) + 1
        end
    end

    return 1
end

local function windowContainsPoint(window, point)
    if not window or not point then
        return false
    end

    local frame = window:frame()
    return point.x >= frame.x
        and point.x <= frame.x + frame.w
        and point.y >= frame.y
        and point.y <= frame.y + frame.h
end

local function firstVisibleStandardWindow(app)
    for _, window in ipairs(collectStandardWindows(app)) do
        if window:isVisible() then
            return window
        end
    end

    return nil
end

local function parallelsWindowUnderMouse()
    local app = hs.application.get(PARALLELS_MACVM_BUNDLE_ID)
    if not app then
        return nil
    end

    local point = hs.mouse.absolutePosition()
    for _, window in ipairs(collectStandardWindows(app)) do
        if window:isVisible() and windowContainsPoint(window, point) then
            return window
        end
    end

    if app:isFrontmost() then
        return firstVisibleStandardWindow(app)
    end

    return nil
end

local function hyperArrowPositionsByKeyCode()
    if hyperArrowPositions then
        return hyperArrowPositions
    end

    local map = hs.keycodes and hs.keycodes.map or {}
    local positions = {}
    if map.left then
        positions[map.left] = "left"
    end
    if map.right then
        positions[map.right] = "right"
    end
    if map.up then
        positions[map.up] = "up"
    end
    if map.down then
        positions[map.down] = "down"
    end
    hyperArrowPositions = positions
    return hyperArrowPositions
end

local function hasHyperFlagsOnly(flags)
    return flags
        and flags.ctrl
        and flags.alt
        and flags.cmd
        and not flags.shift
end

local function handleHyperArrowEvent(event)
    if not hasHyperFlagsOnly(event:getFlags()) then
        return false
    end

    local position = hyperArrowPositionsByKeyCode()[event:getKeyCode()]
    if not position then
        return false
    end

    M.moveToPositionFromShortcut(position)
    return true
end

function M.moveToPosition(position, win)
    win = win or hs.window.focusedWindow()
    if not win then
        return false
    end

    local screen = win:screen()
    local max = screen:frame()

    if position == "left" then
        win:setFrame({ x = max.x, y = max.y, w = max.w / 2, h = max.h })
    elseif position == "right" then
        win:setFrame({ x = max.x + max.w / 2, y = max.y, w = max.w / 2, h = max.h })
    elseif position == "up" then
        -- 最大化窗口
        win:setFrame({ x = max.x, y = max.y, w = max.w, h = max.h })
    elseif position == "down" then
        -- 窗口占屏幕的80%，居中
        local newWidth = max.w * 0.8
        local newHeight = max.h * 0.8
        local newX = max.x + (max.w - newWidth) / 2
        local newY = max.y + (max.h - newHeight) / 2
        win:setFrame({ x = newX, y = newY, w = newWidth, h = newHeight })
    end

    return true
end

function M.moveToPositionFromShortcut(position)
    return M.moveToPosition(
        position,
        parallelsWindowUnderMouse() or hs.window.focusedWindow()
    )
end

function M.startHyperArrowEventtap()
    if hyperArrowEventtap then
        return hyperArrowEventtap
    end

    hyperArrowEventtap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleHyperArrowEvent)
    hyperArrowEventtap:start()
    return hyperArrowEventtap
end

function M.switchFocusedAppWindow()
    local currApp = hs.application.frontmostApplication()
    if not currApp then
        return
    end

    local currWins = collectStandardWindows(currApp)
    if #currWins <= 1 then
        return
    end

    local focusedWin = currApp:focusedWindow()
    local nextWinIdx = nextIndex(currWins, focusedWin and focusedWin:id(), function(win)
        return win:id()
    end)
    local nextWin = nextWinIdx and currWins[nextWinIdx]
    if not nextWin then
        return
    end

    local targetScreen = focusedWin and focusedWin:screen()
        or hs.mouse.getCurrentScreen()
        or hs.screen.mainScreen()
    if targetScreen and nextWin:screen() ~= targetScreen then
        nextWin:moveToScreen(targetScreen, false, true)
    end

    nextWin:focus()
end

M._collectStandardWindows = collectStandardWindows
M._nextIndex = nextIndex
M._windowContainsPoint = windowContainsPoint

return M
