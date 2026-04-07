-- init.lua — Hammerspoon 入口

-- 禁用窗口动画（让窗口立即到位）
hs.window.animationDuration = 0
hs.application.enableSpotlightForNameSearches(true)
require('hs.ipc')

-- 加载模块（KeyBinds 内部已显式 require 所有依赖）
local inputMethodToggle = require('modules.inputMethodToggle')
require('modules.reload')
require('modules.systemInfo')
local keyBinds = require('config.KeyBinds')

hs.notify.new({ title = 'Hammerspoon', informativeText = 'Ready to rock 🤘' }):send()

_G.dotfilesRuntime = _G.dotfilesRuntime or {}
_G.dotfilesRuntime.inputMethodToggle = inputMethodToggle
_G.dotfilesRuntime.keyBinds = keyBinds
