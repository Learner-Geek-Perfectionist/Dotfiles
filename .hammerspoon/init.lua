---@diagnostic disable: lowercase-global

-- 加载 hyper.lua
require('config.keyConfig')
require('config.KeyBinds')
require('modules.reload')
require('modules.AppToggler')
require('modules.windowManagement')

hs.notify.new({ title = 'Hammerspoon', informativeText = 'Ready to rock 🤘' }):send()