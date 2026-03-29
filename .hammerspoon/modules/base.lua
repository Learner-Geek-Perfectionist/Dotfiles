-- base.lua — 基础工具函数
-- 仅保留被其他模块实际使用的函数（split, trim）

local M = {}

function M.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter == '') then
        return false
    end
    local pos, arr = 0, {}
    for st, sp in function()
        return string.find(input, delimiter, pos, true)
    end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

function M.trim(s)
    if not s then
        return ''
    end
    local res = string.gsub(s, "\r\n", "")
    return (res:gsub("^%s+", ""):gsub("%s+$", ""))
end

return M
