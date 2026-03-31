-- windowManagement.lua — 窗口位置管理 + 窗口切换

local M = {}

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

    local currWins = hs.fnutils.filter(currApp:allWindows(), function(x)
        return x:isStandard()
    end)
    if #currWins > 0 then
        local allWinIds = hs.fnutils.map(currWins, function(y)
            return y:id()
        end)
        table.sort(allWinIds)

        local focusedWin = currApp:focusedWindow()
        local targetScreen = focusedWin and focusedWin:screen()
            or hs.mouse.getCurrentScreen()
            or hs.screen.mainScreen()

        local currWinIdx = hs.fnutils.indexOf(allWinIds, focusedWin and focusedWin:id())
        local nextWinIdx = currWinIdx and (currWinIdx % #allWinIds) + 1 or 1

        local nextWin = hs.window.get(allWinIds[nextWinIdx])
        if targetScreen and nextWin:screen() ~= targetScreen then
            nextWin:moveToScreen(targetScreen, false, true)
        end
        nextWin:focus()
    end
end

return M
