-- kittyHotkeys.lua — rollback-only shim while native Kitty hotkeys are active; the map is
-- intentionally empty and manual rollback would require repopulating it.

local M = {}

local KITTY_BUNDLE_ID = 'net.kovidgoyal.kitty'
local KEY_CODE_TO_SCRIPT = {}
local KITTY_BIN_CANDIDATES = {
    '/Applications/kitty.app/Contents/MacOS/kitty',
    '/opt/homebrew/bin/kitty',
    '/usr/local/bin/kitty',
}

local runningTasks = {}
local interceptionTap = nil
local interceptionEnabled = nil
local resolvedKittyBin = nil

local function resolveKittyBin()
    if resolvedKittyBin and hs.fs.attributes(resolvedKittyBin) then
        return resolvedKittyBin
    end

    local app = hs.application.frontmostApplication()
    if app and app:bundleID() == KITTY_BUNDLE_ID then
        local appPath = app:path()
        if appPath then
            local bundleBinary = appPath .. '/Contents/MacOS/kitty'
            if hs.fs.attributes(bundleBinary) then
                resolvedKittyBin = bundleBinary
                return resolvedKittyBin
            end
        end
    end

    for _, candidate in ipairs(KITTY_BIN_CANDIDATES) do
        if hs.fs.attributes(candidate) then
            resolvedKittyBin = candidate
            return resolvedKittyBin
        end
    end

    return nil
end

local function getKittySocket()
    local app = hs.application.frontmostApplication()
    if app and app:bundleID() == KITTY_BUNDLE_ID then
        local directPath = string.format('/tmp/kitty-%d', app:pid())
        if hs.fs.attributes(directPath) then
            return 'unix:' .. directPath
        end
    end

    local fallbackPath = '/tmp/kitty-socket'
    if hs.fs.attributes(fallbackPath) then
        return 'unix:' .. fallbackPath
    end

    return nil
end

local function frontmostIsKitty()
    local app = hs.application.frontmostApplication()
    if not app then
        return false
    end

    return app:bundleID() == KITTY_BUNDLE_ID
end

local function hasOnlyCommandModifier(event)
    local flags = event:getFlags()
    if not flags.cmd then
        return false
    end

    return not flags.alt and not flags.ctrl and not flags.shift and not flags.fn
end

local function runKittyKitten(script)
    local kittyBin = resolveKittyBin()
    if not kittyBin then
        hs.printf('kittyHotkeys: no usable Kitty binary, skip %s', script)
        return
    end

    local socket = getKittySocket()
    if not socket then
        hs.printf('kittyHotkeys: no usable Kitty socket, skip %s', script)
        return
    end

    local task
    task = hs.task.new(kittyBin, function(exitCode, stdOut, stdErr)
        runningTasks[task] = nil

        if exitCode ~= 0 then
            hs.printf(
                'kittyHotkeys: %s exited with %d, stdout=%s stderr=%s',
                script,
                exitCode,
                stdOut or '',
                stdErr or ''
            )
        end
    end, { '@', '--to', socket, 'kitten', script })

    if not task then
        hs.printf('kittyHotkeys: failed to create task for %s', script)
        return
    end

    runningTasks[task] = true
    task:start()
end

local function triggerScript(script)
    if not script then
        return false
    end

    runKittyKitten(script)
    return true
end

local function setEnabled(enabled)
    if enabled == interceptionEnabled then
        return
    end

    interceptionEnabled = enabled

    if enabled then
        interceptionTap:start()
    else
        interceptionTap:stop()
    end
end

local function syncHotkeys()
    setEnabled(frontmostIsKitty())
end

interceptionTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if not frontmostIsKitty() or not hasOnlyCommandModifier(event) then
        return false
    end

    local script = KEY_CODE_TO_SCRIPT[event:getKeyCode()]
    if not script then
        return false
    end

    triggerScript(script)
    return true
end)

local watcher = hs.application.watcher.new(function(_, eventType, _)
    if eventType == hs.application.watcher.activated
        or eventType == hs.application.watcher.deactivated
        or eventType == hs.application.watcher.launched
        or eventType == hs.application.watcher.terminated then
        syncHotkeys()
    end
end)

watcher:start()
syncHotkeys()

function M.newWindow()
    return triggerScript(KEY_CODE_TO_SCRIPT[hs.keycodes.map.n])
end

function M.newTab()
    return triggerScript(KEY_CODE_TO_SCRIPT[hs.keycodes.map.e])
end

M._eventtap = interceptionTap
M._watcher = watcher
M._runningTasks = runningTasks
M._getKittySocket = getKittySocket
M._resolveKittyBin = resolveKittyBin

return M
