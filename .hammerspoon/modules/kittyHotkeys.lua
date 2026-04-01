-- kittyHotkeys.lua — only enable Cmd+N / Cmd+E when Kitty is frontmost

local M = {}

local KITTY_BUNDLE_ID = 'net.kovidgoyal.kitty'
local KITTY_BIN = '/opt/homebrew/bin/kitty'

local hotkeys = {}
local runningTasks = {}

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

local function setEnabled(enabled)
    for _, hotkey in pairs(hotkeys) do
        if enabled then
            hotkey:enable()
        else
            hotkey:disable()
        end
    end
end

local function frontmostIsKitty()
    local app = hs.application.frontmostApplication()
    if not app then
        return false
    end

    return app:bundleID() == KITTY_BUNDLE_ID
end

local function runKittyKitten(script)
    local socket = getKittySocket()
    if not socket then
        hs.printf('kittyHotkeys: no usable Kitty socket, skip %s', script)
        return
    end

    local task
    task = hs.task.new(KITTY_BIN, function(exitCode, stdOut, stdErr)
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

local function syncHotkeys()
    setEnabled(frontmostIsKitty())
end

hotkeys.newWindow = hs.hotkey.new({ 'cmd' }, 'n', function()
    runKittyKitten('./smart_window.py')
end)

hotkeys.newTab = hs.hotkey.new({ 'cmd' }, 'e', function()
    runKittyKitten('./smart_tab.py')
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

M._hotkeys = hotkeys
M._watcher = watcher
M._runningTasks = runningTasks
M._getKittySocket = getKittySocket

return M
