-- windowManagement.lua — 窗口位置管理 + 窗口切换

local M = {}

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

function M.moveToPosition(position)
    local win = hs.window.focusedWindow()
    if not win then
        return
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

return M
