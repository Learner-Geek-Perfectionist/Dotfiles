-- inputMethodToggle.lua — Shift/Caps driven IME toggling wired into Hammerspoon

local config = require('config.inputMethodConfig')
local stateMachine = require('modules.inputMethodState')

local M = {}

local eventTypes = hs.eventtap.event.types
local rawFlagMasks = hs.eventtap.event.rawFlagMasks
local syntheticResetTimer = nil
local suppressSyntheticEvents = false

local SHIFT_KEY_CODES = {
    [hs.keycodes.map.shift] = 'left',
    [hs.keycodes.map.rightshift] = 'right',
}

local rawShiftMasks = {
    left = rawFlagMasks.deviceLeftShift,
    right = rawFlagMasks.deviceRightShift,
}

local state = stateMachine.new()
local runtimeStrategy = nil

local function debugLog(message, ...)
    if not config.debugLogging then
        return
    end

    hs.printf('inputMethodToggle: ' .. message, ...)
end

local function hasActiveExcludedBundle()
    local app = hs.application.frontmostApplication()
    if not app then
        return false, nil
    end

    local bundleID = app:bundleID()
    for _, excludedBundleID in ipairs(config.excludedBundleIDs or {}) do
        if bundleID == excludedBundleID then
            return true, bundleID
        end
    end

    return false, bundleID
end

local function hasOtherModifiers(flags)
    return flags.cmd or flags.alt or flags.ctrl or flags.fn or flags.capslock
end

local function resolveStrategy()
    local availableLayouts = hs.keycodes.layouts(true) or {}
    local availableMethods = hs.keycodes.methods(true) or {}

    runtimeStrategy = stateMachine.selectInputStrategy(availableLayouts, availableMethods, config)
    M._runtimeStrategy = runtimeStrategy
    debugLog(
        'strategy=%s english=%s chinese=%s synthetic=%s',
        tostring(runtimeStrategy.mode),
        tostring(runtimeStrategy.englishSourceID),
        tostring(runtimeStrategy.chineseSourceID),
        tostring(runtimeStrategy.methodSourceID)
    )

    return runtimeStrategy
end

local function isShiftDownForSide(event, side)
    return (event:rawFlags() & rawShiftMasks[side]) ~= 0
end

local function clearSyntheticSuppression()
    suppressSyntheticEvents = false
    syntheticResetTimer = nil
end

local function emitSyntheticShift()
    local shiftKey = (runtimeStrategy and runtimeStrategy.syntheticShiftKey) or config.syntheticShiftKey or 'shift'
    local keyCode = hs.keycodes.map[shiftKey] or hs.keycodes.map.shift

    suppressSyntheticEvents = true
    hs.eventtap.event.newKeyEvent(keyCode, true):post()
    hs.eventtap.event.newKeyEvent(keyCode, false):post()

    if syntheticResetTimer then
        syntheticResetTimer:stop()
    end
    syntheticResetTimer = hs.timer.doAfter(0.05, clearSyntheticSuppression)
end

local function toggleInputSource()
    local strategy = runtimeStrategy or resolveStrategy()
    if strategy.mode == 'disabled' then
        debugLog('skip toggle because no usable strategy is available')
        return
    end

    if strategy.mode == 'synthetic_shift' then
        debugLog('using synthetic shift compatibility mode for %s', tostring(strategy.methodSourceID))
        emitSyntheticShift()
        return
    end

    local currentSourceID = hs.keycodes.currentSourceID()
    local targetSourceID = stateMachine.resolveNextSourceID(currentSourceID, strategy)
    hs.keycodes.currentSourceID(targetSourceID)
    local afterSourceID = hs.keycodes.currentSourceID()

    if stateMachine.needsSyntheticShiftFallback(currentSourceID, targetSourceID, afterSourceID) then
        debugLog('source switch %s -> %s did not stick, falling back to synthetic shift', tostring(currentSourceID), tostring(targetSourceID))
        emitSyntheticShift()
        return
    end

    debugLog('source switched %s -> %s', tostring(currentSourceID), tostring(afterSourceID))
end

local function handleFlagsChanged(event)
    if suppressSyntheticEvents then
        return false
    end

    local keyCode = event:getKeyCode()
    local side = SHIFT_KEY_CODES[keyCode]

    if side then
        local result = stateMachine.handleShift(state, side, isShiftDownForSide(event, side), {
            hasOtherModifiers = hasOtherModifiers(event:getFlags()),
        })
        if result.shouldToggle then
            local isExcluded, bundleID = hasActiveExcludedBundle()
            if isExcluded then
                debugLog('skip toggle for excluded bundle %s', tostring(bundleID))
                return false
            end

            toggleInputSource()
        end

        return false
    end

    stateMachine.handleModifierChange(state, keyCode, true)
    debugLog('modifier change marked keyboard participation for keyCode=%s', tostring(keyCode))

    return false
end

local function handleKeyDown(event)
    if suppressSyntheticEvents then
        return false
    end

    stateMachine.handleKeyDown(state, event:getKeyCode())
    return false
end

local eventtap = hs.eventtap.new({ eventTypes.flagsChanged, eventTypes.keyDown }, function(event)
    local eventType = event:getType()

    if eventType == eventTypes.flagsChanged then
        return handleFlagsChanged(event)
    end

    if eventType == eventTypes.keyDown then
        return handleKeyDown(event)
    end

    return false
end)

resolveStrategy()
eventtap:start()

M._eventtap = eventtap
M._state = state
M._runtimeStrategy = runtimeStrategy
M._handleFlagsChanged = handleFlagsChanged
M._handleKeyDown = handleKeyDown
M._toggleInputSource = toggleInputSource
M._resolveStrategy = resolveStrategy

return M
