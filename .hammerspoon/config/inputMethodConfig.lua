-- inputMethodConfig.lua — source IDs and exclusions for Shift/Caps IME toggling

local M = {}

-- Hammerspoon first tries to build a stable EN/ZH source pair from these candidates.
M.englishSourceIDs = {
    'com.apple.keylayout.ABC',
    'com.apple.keylayout.US',
}

M.chineseSourceIDs = {
    'com.tencent.inputmethod.wetype.pinyin',
    'com.apple.inputmethod.SCIM.ITABC',
}

-- Compatibility mode for single-method setups.
-- This remains IME-specific by definition and is less reliable than source-pair switching.
M.syntheticShiftMethodSourceIDs = {
    'com.tencent.inputmethod.wetype.pinyin',
}

M.syntheticShiftKey = 'shift'

-- Bundle IDs listed here will keep normal Shift behavior without IME toggling.
M.excludedBundleIDs = {}

M.debugLogging = false

return M
