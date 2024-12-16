---@diagnostic disable: lowercase-global


require('config.keyConfig')
require('config.KeyBinds')
require('modules.reload')
require('modules.systemInfo')
require('modules.AppToggler')
require('modules.windowManagement')
require('modules.inputMethod')

--  目前弃用了，使用微信输入法可以完全代替 --
----  启动 inputMethod 模块
--appWatcher = hs.application.watcher.new(applicationWatcher)
--appWatcher:start()


hs.notify.new({ title = 'Hammerspoon', informativeText = 'Ready to rock 🤘' }):send()