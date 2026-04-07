package.path = table.concat({
    './.hammerspoon/?.lua',
    './.hammerspoon/?/init.lua',
    package.path,
}, ';')

local stateModule = require('modules.inputMethodState')

local function assertEqual(label, expected, actual)
    if expected ~= actual then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)))
    end
end

local function assertSequence(label, expected, actual)
    assertEqual(label .. ' length', #expected, #actual)
    for index = 1, #expected do
        assertEqual(string.format('%s[%d]', label, index), expected[index], actual[index])
    end
end

local function runEvents(events)
    local state = stateModule.new()
    local outputs = {}

    for _, event in ipairs(events) do
        if event.type == 'shift' then
            local result = stateModule.handleShift(state, event.side, event.down, {
                hasOtherModifiers = event.hasOtherModifiers,
            })
            if result.shouldToggle then
                outputs[#outputs + 1] = 'toggle'
            end
        elseif event.type == 'modifierChanged' then
            stateModule.handleModifierChange(state, event.modifier, event.down)
        elseif event.type == 'keyDown' then
            stateModule.handleKeyDown(state, event.key)
        elseif event.type == 'mouseDown' or event.type == 'mouseUp' then
            -- Mouse activity must not affect independent-use detection.
        else
            error('unsupported event type: ' .. tostring(event.type))
        end
    end

    return outputs
end

local function assertToggle(label, events, expected)
    assertSequence(label, expected, runEvents(events))
end

assertToggle(
    'left shift alone toggles on release',
    {
        { type = 'shift', side = 'left', down = true },
        { type = 'shift', side = 'left', down = false },
    },
    { 'toggle' }
)

assertToggle(
    'right shift alone toggles on release',
    {
        { type = 'shift', side = 'right', down = true },
        { type = 'shift', side = 'right', down = false },
    },
    { 'toggle' }
)

assertToggle(
    'shift with keyboard key does not toggle',
    {
        { type = 'shift', side = 'left', down = true },
        { type = 'keyDown', key = 'a' },
        { type = 'shift', side = 'left', down = false },
    },
    {}
)

assertToggle(
    'shift pressed while command already held does not toggle',
    {
        { type = 'shift', side = 'left', down = true, hasOtherModifiers = true },
        { type = 'shift', side = 'left', down = false },
    },
    {}
)

assertToggle(
    'shift with command modifier does not toggle',
    {
        { type = 'shift', side = 'left', down = true },
        { type = 'modifierChanged', modifier = 'cmd', down = true },
        { type = 'modifierChanged', modifier = 'cmd', down = false },
        { type = 'shift', side = 'left', down = false },
    },
    {}
)

assertToggle(
    'mouse-only activity still counts as alone',
    {
        { type = 'shift', side = 'left', down = true },
        { type = 'mouseDown' },
        { type = 'mouseUp' },
        { type = 'shift', side = 'left', down = false },
    },
    { 'toggle' }
)

assertToggle(
    'overlapped double shift toggles once',
    {
        { type = 'shift', side = 'left', down = true },
        { type = 'shift', side = 'right', down = true },
        { type = 'shift', side = 'left', down = false },
        { type = 'shift', side = 'right', down = false },
    },
    { 'toggle' }
)

assertToggle(
    'double shift with keyboard activity does not toggle',
    {
        { type = 'shift', side = 'left', down = true },
        { type = 'shift', side = 'right', down = true },
        { type = 'keyDown', key = 'tab' },
        { type = 'shift', side = 'left', down = false },
        { type = 'shift', side = 'right', down = false },
    },
    {}
)

assertEqual(
    'english source switches to chinese',
    'zh',
    stateModule.resolveNextSourceID('en', {
        englishSourceID = 'en',
        chineseSourceID = 'zh',
        fallbackSourceID = 'en',
    })
)

assertEqual(
    'chinese source switches to english',
    'en',
    stateModule.resolveNextSourceID('zh', {
        englishSourceID = 'en',
        chineseSourceID = 'zh',
        fallbackSourceID = 'en',
    })
)

assertEqual(
    'unknown source falls back to english',
    'en',
    stateModule.resolveNextSourceID('jp', {
        englishSourceID = 'en',
        chineseSourceID = 'zh',
        fallbackSourceID = 'en',
    })
)

assertEqual(
    'unchanged source after explicit switch requires synthetic fallback',
    true,
    stateModule.needsSyntheticShiftFallback('com.tencent.inputmethod.wetype.pinyin', 'com.apple.keylayout.US', 'com.tencent.inputmethod.wetype.pinyin')
)

assertEqual(
    'successful source switch does not require synthetic fallback',
    false,
    stateModule.needsSyntheticShiftFallback('com.tencent.inputmethod.wetype.pinyin', 'com.apple.keylayout.US', 'com.apple.keylayout.US')
)

assertEqual(
    'no-op target does not require synthetic fallback',
    false,
    stateModule.needsSyntheticShiftFallback('com.tencent.inputmethod.wetype.pinyin', 'com.tencent.inputmethod.wetype.pinyin', 'com.tencent.inputmethod.wetype.pinyin')
)

local onlyWeChatStrategy = stateModule.selectInputStrategy(
    {},
    { 'com.tencent.inputmethod.wetype.pinyin' },
    {
        englishSourceIDs = { 'com.apple.keylayout.ABC', 'com.apple.keylayout.US' },
        chineseSourceIDs = { 'com.tencent.inputmethod.wetype.pinyin', 'com.apple.inputmethod.SCIM.ITABC' },
        syntheticShiftMethodSourceIDs = { 'com.tencent.inputmethod.wetype.pinyin' },
        syntheticShiftKey = 'shift',
    }
)
assertEqual('only wechat chooses synthetic mode', 'synthetic_shift', onlyWeChatStrategy.mode)
assertEqual('only wechat synthetic target is wechat', 'com.tencent.inputmethod.wetype.pinyin', onlyWeChatStrategy.methodSourceID)

local systemPairStrategy = stateModule.selectInputStrategy(
    { 'com.apple.keylayout.ABC' },
    { 'com.apple.inputmethod.SCIM.ITABC' },
    {
        englishSourceIDs = { 'com.apple.keylayout.ABC', 'com.apple.keylayout.US' },
        chineseSourceIDs = { 'com.tencent.inputmethod.wetype.pinyin', 'com.apple.inputmethod.SCIM.ITABC' },
        syntheticShiftMethodSourceIDs = { 'com.tencent.inputmethod.wetype.pinyin' },
        syntheticShiftKey = 'shift',
    }
)
assertEqual('system pair chooses source pair mode', 'source_pair', systemPairStrategy.mode)
assertEqual('system pair chooses english source', 'com.apple.keylayout.ABC', systemPairStrategy.englishSourceID)
assertEqual('system pair chooses chinese source', 'com.apple.inputmethod.SCIM.ITABC', systemPairStrategy.chineseSourceID)

local mixedStrategy = stateModule.selectInputStrategy(
    { 'com.apple.keylayout.ABC' },
    { 'com.apple.inputmethod.SCIM.ITABC', 'com.tencent.inputmethod.wetype.pinyin' },
    {
        englishSourceIDs = { 'com.apple.keylayout.ABC', 'com.apple.keylayout.US' },
        chineseSourceIDs = { 'com.tencent.inputmethod.wetype.pinyin', 'com.apple.inputmethod.SCIM.ITABC' },
        syntheticShiftMethodSourceIDs = { 'com.tencent.inputmethod.wetype.pinyin' },
        syntheticShiftKey = 'shift',
    }
)
assertEqual('mixed strategy still uses source pair mode', 'source_pair', mixedStrategy.mode)
assertEqual('mixed strategy prefers wechat for chinese', 'com.tencent.inputmethod.wetype.pinyin', mixedStrategy.chineseSourceID)

print('ok - Hammerspoon input method logic')
