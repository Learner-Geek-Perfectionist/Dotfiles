-- AppToggler.lua — 应用切换（已聚焦则隐藏，否则启动/聚焦）

local M = {}

function M.toggle(bundleID)
    local app = hs.application.get(bundleID)
    if app and app:isFrontmost() then
        app:hide()
    else
        hs.application.launchOrFocusByBundleID(bundleID)
    end
end

return M
