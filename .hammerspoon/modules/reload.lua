-- reload.lua — 配置文件变化时自动重载

local function reloadConfig(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

local configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

-- 保持 configWatcher 引用防止 GC（通过 require 缓存机制）
return { _watcher = configWatcher }
