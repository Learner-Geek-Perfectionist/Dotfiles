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

local windowManagement = require("modules.windowManagement")
local keyConfig = require("config.keyConfig")

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
assertTrue(not readFile(repoRoot .. "/.hammerspoon/config/KeyBinds.lua"):find("moveToFocusedScreen", 1, true), "KeyBinds uses the default cross-screen switch behavior without redundant args")
assertTrue(readFile(repoRoot .. "/.hammerspoon/modules/systemInfo.lua"):find("math.max(0, obj.current_down - obj.last_down)", 1, true), "systemInfo clamps negative download deltas")
assertTrue(readFile(repoRoot .. "/.hammerspoon/modules/systemInfo.lua"):find("math.max(0, obj.current_up - obj.last_up)", 1, true), "systemInfo clamps negative upload deltas")

local appMappingByKey = {}
for _, appMapping in ipairs(keyConfig.keyConfig) do
    appMappingByKey[appMapping[1]] = appMapping[2]
end
assertEqual(appMappingByKey["c"], "com.openai.codex", "Hyper/right_command+c opens Codex")

local collected = windowManagement._collectStandardWindows(fakeApp)
assertEqual(#collected, 2, "window collection uses all app windows, not only visible ones")
assertEqual(collected[1]:id(), 20, "window collection sorts windows by id")
assertEqual(collected[2]:id(), 30, "window collection preserves the remaining standard window")

local collectedWithNilId = windowManagement._collectStandardWindows({
    allWindows = function()
        return {
            { id = function() return nil end, isStandard = function() return true end },
            { id = function() return 20 end, isStandard = function() return true end },
        }
    end,
})
assertEqual(#collectedWithNilId, 2, "window collection keeps standard windows even when one id is missing")
assertEqual(collectedWithNilId[1]:id(), nil, "missing ids sort safely to the front")
assertEqual(collectedWithNilId[2]:id(), 20, "non-nil ids remain available after safe sort")

assertEqual(windowManagement._nextIndex({ 101, 202, 303 }, 101), 2, "cycles to the next window")
assertEqual(windowManagement._nextIndex({ 101, 202, 303 }, 303), 1, "wraps to the first window")
assertEqual(windowManagement._nextIndex({ 101, 202, 303 }, 999), 1, "falls back to the first window when focus is missing")
assertEqual(windowManagement._nextIndex({}, 999), nil, "returns nil for an empty window list")

local function createHeadlessAppTogglerFixture()
    local reopenedCommand = nil
    local activated = false
    local fakeScreen = {}
    local fakeApp = {
        focusedWindow = function()
            return nil
        end,
        mainWindow = function()
            return nil
        end,
        allWindows = function()
            return {}
        end,
        isHidden = function()
            return false
        end,
        isFrontmost = function()
            return false
        end,
        pid = function()
            return 123
        end,
        activate = function()
            activated = true
        end,
    }

    hs = {
        application = {
            get = function(bundleID)
                return bundleID == "com.example.Headless" and fakeApp or nil
            end,
            launchOrFocusByBundleID = function() end,
        },
        execute = function(command)
            reopenedCommand = command
        end,
        fnutils = {
            find = function(items, predicate)
                for _, item in ipairs(items) do
                    if predicate(item) then
                        return item
                    end
                end
                return nil
            end,
        },
        mouse = {
            getCurrentScreen = function()
                return fakeScreen
            end,
        },
        screen = {
            mainScreen = function()
                return fakeScreen
            end,
        },
        timer = {
            doAfter = function() end,
        },
        window = {
            focusedWindow = function()
                return nil
            end,
            list = function()
                return {
                    { pid = 123 },
                }
            end,
        },
    }

    package.loaded["modules.AppToggler"] = nil
    return require("modules.AppToggler"), function()
        return reopenedCommand, activated
    end
end

local appToggler, getHeadlessAppTogglerResult = createHeadlessAppTogglerFixture()
appToggler.toggle("com.example.Headless")
local reopenedCommand, activated = getHeadlessAppTogglerResult()
assertTrue(activated, "headless running app is activated before reopening")
assertEqual(reopenedCommand, "/usr/bin/open -b com.example.Headless", "running app with only system windows is reopened")

local function createAgentAppAlertFixture()
    local alertMessage = nil
    local fakeScreen = {}
    local fakeApp = {
        focusedWindow = function()
            return nil
        end,
        mainWindow = function()
            return nil
        end,
        allWindows = function()
            return {}
        end,
        isHidden = function()
            return false
        end,
        isFrontmost = function()
            return false
        end,
        activate = function() end,
    }

    hs = {
        alert = {
            show = function(message)
                alertMessage = message
            end,
        },
        application = {
            get = function(bundleID)
                return bundleID == "com.mac.utility.clipboard.paste" and fakeApp or nil
            end,
            launchOrFocusByBundleID = function() end,
        },
        execute = function() end,
        fnutils = {
            find = function(items, predicate)
                for _, item in ipairs(items) do
                    if predicate(item) then
                        return item
                    end
                end
                return nil
            end,
        },
        mouse = {
            getCurrentScreen = function()
                return fakeScreen
            end,
        },
        screen = {
            mainScreen = function()
                return fakeScreen
            end,
        },
        timer = {
            doAfter = function() end,
        },
        window = {
            focusedWindow = function()
                return nil
            end,
        },
    }

    package.loaded["modules.AppToggler"] = nil
    return require("modules.AppToggler"), function()
        return alertMessage
    end
end

local agentAppToggler, getAgentAppAlert = createAgentAppAlertFixture()
agentAppToggler.toggle("com.mac.utility.clipboard.paste")
assertEqual(getAgentAppAlert(), "uPaste", "agent app toggle shows a visible hint")

print("test_hammerspoon_helpers.lua: ok")
