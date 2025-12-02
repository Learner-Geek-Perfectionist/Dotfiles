---@diagnostic disable: lowercase-global

-- 禁用窗口动画（让窗口立即到位）
hs.window.animationDuration = 0
hs.application.enableSpotlightForNameSearches(true)

require('config.keyConfig')
require('config.KeyBinds')
require('modules.reload')
require('modules.systemInfo')
require('modules.AppToggler')
require('modules.windowManagement')
require('modules.inputMethod')
require('modules.caffeinate')

--  目前弃用了，使用微信输入法可以完全代替 --
----  启动 inputMethod 模块
--appWatcher = hs.application.watcher.new(applicationWatcher)
--appWatcher:start()


hs.notify.new({ title = 'Hammerspoon', informativeText = 'Ready to rock 🤘' }):send()
