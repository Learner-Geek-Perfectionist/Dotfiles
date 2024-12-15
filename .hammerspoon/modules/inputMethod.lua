---@diagnostic disable: lowercase-global

appWatcher = nil

function applicationWatcher(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        if inputMethodMap[appObject:bundleID()] then
            local inputSourceId = inputMethodMap[appObject:bundleID()]
            hs.keycodes.currentSourceID(inputSourceId)
        end
    end
end