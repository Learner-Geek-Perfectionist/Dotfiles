local repoRoot = (... and debug.getinfo(1, "S").source:sub(2):match("^(.*)/scripts/")) or "."

package.path = table.concat({
    repoRoot .. "/.hammerspoon/?.lua",
    repoRoot .. "/.hammerspoon/?/init.lua",
    package.path,
}, ";")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
    end
end

local function assertNil(actual, message)
    if actual ~= nil then
        error(string.format("%s: expected nil, got %s", message, tostring(actual)))
    end
end

local function assertTrue(actual, message)
    if not actual then
        error(message)
    end
end

local function readFile(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local keyConfig = require("config.keyConfig")
local windowManagement = require("modules.windowManagement")

assertNil(keyConfig.enableCustomCmdBacktick, "cmd+` no longer needs a config flag")
assertTrue(not io.open(repoRoot .. "/.hammerspoon/modules/windowManagementHelpers.lua", "r"), "windowManagement helper file has been removed")
assertTrue(not io.open(repoRoot .. "/.hammerspoon/modules/systemInfoHelpers.lua", "r"), "systemInfo helper file has been removed")
assertTrue(not readFile(repoRoot .. "/.hammerspoon/config/KeyBinds.lua"):find("enableCustomCmdBacktick", 1, true), "KeyBinds no longer branches on cmd+` config")

local fakeApp = {
    allWindows = function()
        return {
            { id = function() return 30 end, isStandard = function() return true end },
            { id = function() return 10 end, isStandard = function() return false end },
            { id = function() return 20 end, isStandard = function() return true end },
        }
    end,
    visibleWindows = function()
        return {
            { id = function() return 30 end, isStandard = function() return true end },
        }
    end,
}
assertEqual(type(windowManagement._collectStandardWindows), "function", "windowManagement exposes its collection helper for regression tests")
assertEqual(type(windowManagement._nextIndex), "function", "windowManagement exposes its index helper for regression tests")

local collected = windowManagement._collectStandardWindows(fakeApp)
assertEqual(#collected, 2, "window collection uses all app windows, not only visible ones")
assertEqual(collected[1]:id(), 20, "window collection sorts windows by id")
assertEqual(collected[2]:id(), 30, "window collection preserves the remaining standard window")

assertEqual(windowManagement._nextIndex({ 101, 202, 303 }, 101), 2, "cycles to the next window")
assertEqual(windowManagement._nextIndex({ 101, 202, 303 }, 303), 1, "wraps to the first window")
assertEqual(windowManagement._nextIndex({ 101, 202, 303 }, 999), 1, "falls back to the first window when focus is missing")
assertEqual(windowManagement._nextIndex({}, 999), nil, "returns nil for an empty window list")

print("test_hammerspoon_helpers.lua: ok")
