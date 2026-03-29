-- caffeinate.lua — 防休眠切换

local M = {}
local caffeinateMode = false

function M.toggle()
    caffeinateMode = not caffeinateMode

    if caffeinateMode then
        hs.caffeinate.set("displayIdle", true, true)
        hs.alert.show("Caffeinate Mode: ON ✅")
    else
        hs.caffeinate.set("displayIdle", false, true)
        hs.alert.show("Caffeinate Mode: OFF ❌")
    end
end

return M
