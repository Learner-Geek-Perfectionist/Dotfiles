---@diagnostic disable: lowercase-global

-- 设置一个路径监视器，监视 Hammerspoon 配置目录中的文件变化
function reloadConfig(files)
    doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

-- 获取 Hammerspoon 配置文件的路径
configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

-- 显示一个通知，表明 Hammerspoon 已经启动并加载了配置
hs.notify.new({ title = "Hammerspoon", informativeText = "Config loaded" }):send()