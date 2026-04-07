-- inputMethodState.lua — pure Lua state machine for Shift/Caps IME toggling

local M = {}

local VALID_SIDES = {
    left = true,
    right = true,
}

local function makeLookup(values)
    local lookup = {}
    for _, value in ipairs(values or {}) do
        lookup[value] = true
    end
    return lookup
end

local function pickPreferredSource(availableValues, preferredValues)
    local availableLookup = makeLookup(availableValues)
    for _, value in ipairs(preferredValues or {}) do
        if availableLookup[value] then
            return value
        end
    end
    return nil
end

local function resetSession(state)
    state.usedWithKeyboard = false
    state.activeShiftCount = 0
end

function M.new()
    return {
        pressed = {
            left = false,
            right = false,
        },
        usedWithKeyboard = false,
        activeShiftCount = 0,
    }
end

function M.handleShift(state, side, isDown, options)
    assert(type(state) == 'table', 'state must be a table')
    assert(VALID_SIDES[side], 'side must be left or right')
    options = options or {}

    local wasPressed = state.pressed[side]

    if isDown then
        if not wasPressed then
            state.pressed[side] = true
            state.activeShiftCount = state.activeShiftCount + 1

            if options.hasOtherModifiers then
                state.usedWithKeyboard = true
            end
        end

        return { shouldToggle = false }
    end

    if not wasPressed then
        return { shouldToggle = false }
    end

    state.pressed[side] = false
    state.activeShiftCount = math.max(0, state.activeShiftCount - 1)

    if state.activeShiftCount > 0 then
        return { shouldToggle = false }
    end

    local shouldToggle = not state.usedWithKeyboard
    resetSession(state)

    return { shouldToggle = shouldToggle }
end

function M.handleKeyDown(state, _keyCode)
    assert(type(state) == 'table', 'state must be a table')

    if state.activeShiftCount > 0 then
        state.usedWithKeyboard = true
    end
end

function M.handleModifierChange(state, _modifier, _isDown)
    assert(type(state) == 'table', 'state must be a table')

    if state.activeShiftCount > 0 then
        state.usedWithKeyboard = true
    end
end

function M.resolveNextSourceID(currentSourceID, config)
    assert(type(config) == 'table', 'config must be a table')
    assert(type(config.englishSourceID) == 'string' and config.englishSourceID ~= '', 'englishSourceID is required')
    assert(type(config.chineseSourceID) == 'string' and config.chineseSourceID ~= '', 'chineseSourceID is required')

    local fallbackSourceID = config.fallbackSourceID or config.englishSourceID

    if currentSourceID == config.englishSourceID then
        return config.chineseSourceID
    end

    if currentSourceID == config.chineseSourceID then
        return config.englishSourceID
    end

    return fallbackSourceID
end

function M.needsSyntheticShiftFallback(beforeSourceID, targetSourceID, afterSourceID)
    if not beforeSourceID or not targetSourceID or not afterSourceID then
        return false
    end

    if beforeSourceID == targetSourceID then
        return false
    end

    return afterSourceID == beforeSourceID
end

function M.selectInputStrategy(availableLayouts, availableMethods, config)
    assert(type(config) == 'table', 'config must be a table')

    local englishSourceID = pickPreferredSource(availableLayouts, config.englishSourceIDs)
    local chineseSourceID = pickPreferredSource(availableMethods, config.chineseSourceIDs)

    if englishSourceID and chineseSourceID then
        return {
            mode = 'source_pair',
            englishSourceID = englishSourceID,
            chineseSourceID = chineseSourceID,
            fallbackSourceID = englishSourceID,
        }
    end

    local syntheticMethodSourceID = pickPreferredSource(
        availableMethods,
        config.syntheticShiftMethodSourceIDs or config.chineseSourceIDs
    )

    if syntheticMethodSourceID then
        return {
            mode = 'synthetic_shift',
            methodSourceID = syntheticMethodSourceID,
            syntheticShiftKey = config.syntheticShiftKey or 'shift',
        }
    end

    return {
        mode = 'disabled',
    }
end

return M
