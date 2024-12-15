---@diagnostic disable: lowercase-global

-- 加载 hyper.lua
require('config.keyConfig')
require('config.KeyBinds')
require('modules.reload')
require('modules.AppToggler')
require('modules.windowManagement')
require('modules.inputMethod')

--  启动 inputMethod 模块
appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

hs.notify.new({ title = 'Hammerspoon', informativeText = 'Ready to rock 🤘' }):send()