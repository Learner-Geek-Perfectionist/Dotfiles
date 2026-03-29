local base = require('modules.base')

local menubaritem = hs.menubar.new()
local menuData = {}

-- 每次 init() 时重新获取，网络切换后不会失效（H-007）
local interface = nil

-- 该对象用于存储全局变量，避免每次获取速度都创建新的局部变量
local obj = {}

-- menubar 文字样式（四处 styledtext 共用）
local MENUBAR_STYLE = {
    font = { size = 9 },
    color = { hex = "#FFFFFF" },
    paragraphStyle = { alignment = "left", maximumLineHeight = 18 }
}

local function formatPercent(percent)
    if percent <= 0 then
        return "  0%"
    elseif percent < 10 then
        return "  " .. string.format("%.f", percent) .. "%"
    elseif percent > 99 then
        return "100%"
    else
        return string.format("%.f", percent) .. "%"
    end
end

-- 定时器间隔（秒），format_speed 和 hs.timer.doEvery 共用
local INTERVAL = 3

local function format_speed(bytes)
    -- bytes 是 INTERVAL 秒内的累计字节数，需要除以间隔得到每秒速率
    local per_sec = bytes / INTERVAL
    if per_sec < 1024 then
        return string.format("%6.0f", per_sec) .. " B/s"
    elseif per_sec < 1048576 then
        return string.format("%6.1f", per_sec / 1024) .. " KB/s"
    else
        return string.format("%6.1f", per_sec / 1048576) .. " MB/s"
    end
end

local function getCpu()
    local data = hs.host.cpuUsage()
    local cpu = data["overall"]["active"]
    return formatPercent(cpu)
end

local function getVmStats()
    local vmStats = hs.host.vmStat()
    -- --1024^2
    local megDiv = 1048576
    local megMulti = vmStats.pageSize / megDiv

    local memUsed1 = vmStats.pagesWiredDown * megMulti-- 联动内存
    local memUsed2 = vmStats.pagesUsedByVMCompressor * megMulti-- 被压缩内存
    local memUsed3 = vmStats.pagesActive * megMulti -- APP内存
    local memUsed = memUsed1 + memUsed2 + memUsed3

    -- local megsCached = vmStats.fileBackedPages --缓存内存
    -- local freeMegs = vmStats.pagesFree --空闲内存

    local totalMegs = vmStats.memSize / megDiv

    local usedMem = memUsed / totalMegs * 100
    return formatPercent(usedMem)
end

local function getRootVolumes()
    local vols = hs.fs.volume.allVolumes()
    for _, vol in pairs(vols) do
        local totalSize = vol.NSURLVolumeTotalCapacityKey
        local freeSize = vol.NSURLVolumeAvailableCapacityKey
        local usedSSD = (1 - freeSize / totalSize) * 100
        return formatPercent(usedSSD)
    end
    return " 0%"
end

local function init()
    -- 每次 init 刷新网络接口（H-007: 网络切换后不失效）
    interface = hs.network.primaryInterfaces()

    menuData = {}

    -- system load    
    ---@diagnostic disable-next-line: unused-local
    local loadResult, okLoad, _type, rcLoad = hs.execute("uptime |awk '{print $(NF-2),$(NF-1),$NF}'")
    if loadResult and okLoad and rcLoad == 0 then
        local loadArr = base.split(loadResult, " ")
        if not loadArr then
            return
        end
        local load1m = loadArr[1]
        local load5m = loadArr[2]
        local load15m = loadArr[3]

        table.insert(menuData, {
            title = "Load: " .. string.format("1m: %s | 5m: %s | 15m: %s", load1m, load5m, load15m)
        })

    end

    -- == network interface
    if interface then
        local interface_detail = hs.network.interfaceDetails(interface)
        -- SSID
        if interface_detail.AirPort then
            local SSID = interface_detail.AirPort.SSID
            if not SSID then
                SSID = "断网啦😂"
            end
            table.insert(menuData, {
                title = "SSID: " .. SSID,
                tooltip = "Copy SSID to clipboard",
                fn = function()
                    hs.pasteboard.setContents(SSID)
                end,
            })
        end

        -- IPV4
        if interface_detail.IPv4 then
            local ipv4 = interface_detail.IPv4.Addresses[1]
            table.insert(menuData, {
                title = "IPv4: " .. ipv4,
                tooltip = "Copy Ipv4 to clipboard",
                fn = function()
                    hs.pasteboard.setContents(ipv4)
                end,
            })
        end

        -- DNS
        -- local dns = hs.execute("/usr/bin/dig baidu.com |awk -F'[: #]+' '/SERVER/{print $3}'")
        ---@diagnostic disable-next-line: unused-local
        local dns, ok, type, rc = hs.execute("/usr/bin/grep nameserver /etc/resolv.conf |cut -f2 -d' ' ")
        if ok and rc == 0 and dns then
            table.insert(menuData, {
                title = "DNS: " .. dns,
                tooltip = "Copy DNS to clipboard",
                fn = function()
                    hs.pasteboard.setContents(dns)
                end,
            })
        end

        -- MAC
        -- local mac = hs.execute("ifconfig " .. interface .. " | grep ether | awk '{print $2}'")
        local okMac, macAddress, _ = hs.osascript.applescript("primary Ethernet address of (system info)")
        if okMac then
            table.insert(menuData, {
                title = "MAC: " .. macAddress,
                tooltip = "Copy MAC to clipboard",
                fn = function()
                    hs.pasteboard.setContents(macAddress)
                end,
            })
        end

        if not obj.last_down and not obj.last_up then
            obj.last_down = hs.execute("netstat -ibn | grep -e " .. interface .. " -m 1 | awk '{print $7}'")
            obj.last_up = hs.execute("netstat -ibn | grep -e " .. interface .. " -m 1 | awk '{print $10}'")
        end
    else
        obj.last_down = 0
        obj.last_up = 0
    end

    -- DateTime
    local date = os.date("%Y-%m-%d %a")
    table.insert(menuData, {
        title = "Date: " .. date,
        tooltip = "Copy Now DateTime",
        fn = function()
            hs.pasteboard.setContents(os.date("%Y-%m-%d %H:%M:%S"))
        end,
    })

    -- battery
    -- local batteryAllInfo = hs.battery.getAll()
    local isCharged = hs.battery.isCharged()
    local isCharging = hs.battery.isCharging()
    local bpercentage = hs.battery.percentage()
    local batteryStatus = nil
    if isCharging then
        batteryStatus = "正在充电"
    elseif isCharged and isCharged ~= "n/a" then
        batteryStatus = "电池满电"
    else
        batteryStatus = "电池供电"
    end
    table.insert(menuData, {
        title = "🔋电池状态: " .. batteryStatus .. " " .. bpercentage .. "%"
    })

    menubaritem:setMenu(menuData)
end

local function scan()
    if interface then
        obj.current_down = hs.execute("netstat -ibn | grep -e " .. interface .. " -m 1 | awk '{print $7}'")
        obj.current_up = hs.execute("netstat -ibn | grep -e " .. interface .. " -m 1 | awk '{print $10}'")
    else
        obj.current_down = 0
        obj.current_up = 0
    end

    obj.cpu_used = getCpu()
    obj.disk_used = getRootVolumes()
    obj.mem_used = getVmStats()
    obj.down_bytes = obj.current_down - obj.last_down
    obj.up_bytes = obj.current_up - obj.last_up

    obj.down_speed = format_speed(obj.down_bytes)
    obj.up_speed = format_speed(obj.up_bytes)

    obj.display_text = hs.styledtext.new(
            "▲ " .. obj.up_speed .. "\n" .. "▼ " .. obj.down_speed,
            MENUBAR_STYLE
    )
    obj.display_disk_text = hs.styledtext.new(
            obj.disk_used .. "\n" .. "SSD ",
            MENUBAR_STYLE
    )
    obj.display_mem_text = hs.styledtext.new(
            obj.mem_used .. "\n" .. "MEM ",
            MENUBAR_STYLE
    )
    obj.display_cpu_text = hs.styledtext.new(
            obj.cpu_used .. "\n" .. "CPU ",
            MENUBAR_STYLE
    )

    obj.last_down = obj.current_down
    obj.last_up = obj.current_up

    local canvas = hs.canvas.new({ x = 0, y = 0, h = 24, w = 30 + 30 + 30 + 60 })
    -- canvas[1] = {type = 'text', text = obj.display_text}
    canvas:appendElements({
        type = "text",
        text = obj.display_cpu_text,
        -- withShadow = true,
        trackMouseEnterExit = true,
    }, {
        type = "text",
        text = obj.display_disk_text,
        -- withShadow = true,
        trackMouseEnterExit = true,
        frame = { x = 30, y = "0", h = "1", w = "1" },
    }, {
        type = "text",
        text = obj.display_mem_text,
        -- withShadow = true,
        trackMouseEnterExit = true,
        frame = { x = 60, y = "0", h = "1", w = "1" },
    }, {
        type = "text",
        text = obj.display_text,
        -- withShadow = true,
        trackMouseEnterExit = true,
        frame = { x = 90, y = "0", h = "1", w = "1" },
    })
    menubaritem:setIcon(canvas:imageFromCanvas())
    canvas:delete()
    canvas = nil
end

local setSysInfo = function()
    -- if menuBarItem and not menuBarItem:isInMenuBar() then return end

    init()
    scan()

    if obj.timer then obj.timer:stop(); obj.timer = nil end
    if obj.timer1 then obj.timer1:stop(); obj.timer1 = nil end

    obj.timer = hs.timer.doEvery(INTERVAL, scan)
    obj.timer:start()
    obj.timer1 = hs.timer.doEvery(120, init)
    obj.timer1:start()

end

local function initData()
    setSysInfo()
    --监听系统信息开关的状态,判断是否要重置
end

-- 初始化
initData()

