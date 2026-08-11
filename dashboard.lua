-- =========================================================
-- CC: Tweaked - Central Telemetry Dashboard (dashboard.lua)
-- Setup: Place on Advanced Computer with Wireless/Ender Modem.
-- Optional: Connect an Advanced Monitor on any side.
-- =========================================================

-- Explicitly find and open Wireless/Ender Modem (ignoring Wired Modems)
local function openWirelessModem()
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" then
            local m = peripheral.wrap(side)
            if m and m.isWireless() then
                rednet.open(side)
                return side
            end
        end
    end
    return nil
end

local activeModemSide = openWirelessModem()
if not activeModemSide then
    error("Error: No Wireless or Ender Modem found on this computer!")
end

-- Detect optional connected Monitor
local mon = peripheral.find("monitor")
local display = mon or term

if mon then
    mon.setTextScale(0.5)
end

local activeTurtles = {}

-----------------------------------------------------------
-- Item Table Formatter
-----------------------------------------------------------
local function formatItemTable(tbl, maxLen)
    if not tbl or type(tbl) ~= "table" then return "(none)" end
    local parts = {}
    for name, count in pairs(tbl) do
        if count and count > 0 then
            table.insert(parts, string.format("%s x%d", tostring(name), count))
        end
    end
    if #parts == 0 then return "(empty)" end
    table.sort(parts)
    local str = table.concat(parts, ", ")
    if #str > maxLen then
        return str:sub(1, maxLen - 3) .. "..."
    end
    return str
end

-----------------------------------------------------------
-- Dashboard Renderer
-----------------------------------------------------------
local function renderDashboard()
    display.setBackgroundColor(colors.black)
    display.clear()
    display.setCursorPos(1, 1)
    
    -- Header
    display.setTextColor(colors.yellow)
    display.write("==================================================\n")
    display.write("         HIGH TORQUE TELEMETRY DASHBOARD          \n")
    display.write("==================================================\n")
    display.setTextColor(colors.white)
    
    -- Table Column Headers (Total width: 50 characters)
    display.setCursorPos(1, 5)
    display.setTextColor(colors.cyan)
    display.write(string.format("%-8s %-7s %-11s %-7s %-13s\n", "TURTLE", "FUEL", "POS(X,Y,Z)", "ITEMS", "STATUS"))
    display.setTextColor(colors.gray)
    display.write("--------------------------------------------------\n")
    
    local line = 7
    local count = 0
    for id, data in pairs(activeTurtles) do
        count = count + 1
        display.setCursorPos(1, line)
        
        -- Fuel color warning & formatting
        local fuelStr = ""
        if type(data.fuel) == "number" then
            fuelStr = string.format("%d", data.fuel)
            if data.fuel < 500 then
                display.setTextColor(colors.red)
            else
                display.setTextColor(colors.green)
            end
        else
            fuelStr = tostring(data.fuel)
            display.setTextColor(colors.green)
        end
        
        -- Items formatting (Format integers or abbreviate thousands above 10k)
        local itemsCount = data.items or 0
        local itemsStr = ""
        if itemsCount >= 100000 then
            itemsStr = string.format("%dk", math.floor(itemsCount / 1000))
        elseif itemsCount >= 10000 then
            itemsStr = string.format("%.1fk", itemsCount / 1000)
        else
            itemsStr = string.format("%d", itemsCount)
        end

        local labelStr = tostring(data.label):sub(1, 8)
        local posStr = string.format("%d,%d,%d", data.x, data.y, data.z):sub(1, 11)
        local statusStr = tostring(data.status):sub(1, 13)
        
        display.write(string.format("%-8s ", labelStr))
        display.write(string.format("%-7s ", fuelStr:sub(1, 7)))
        
        display.setTextColor(colors.white)
        display.write(string.format("%-11s ", posStr))
        
        display.setTextColor(colors.lightBlue)
        display.write(string.format("%-7s ", itemsStr:sub(1, 7)))
        
        display.setTextColor(colors.yellow)
        display.write(string.format("%-13s", statusStr))
        
        -- Live Inventory breakdown line
        display.setCursorPos(1, line + 1)
        display.setTextColor(colors.cyan)
        display.write("  Inv: ")
        display.setTextColor(colors.white)
        display.write(formatItemTable(data.inventory, 43))
        
        -- Total Deposited Chest breakdown line
        display.setCursorPos(1, line + 2)
        display.setTextColor(colors.lightBlue)
        display.write("  Chest: ")
        display.setTextColor(colors.gray)
        display.write(formatItemTable(data.deposited, 41))
        
        line = line + 3
    end
    
    if count == 0 then
        display.setCursorPos(1, 7)
        display.setTextColor(colors.gray)
        display.write("No active turtles broadcasting on rednet...")
    end
end

-- Initial render and event loop
renderDashboard()

local timerId = os.startTimer(1)

while true do
    local event, p1, p2, p3 = os.pullEvent()
    
    if event == "rednet_message" and p3 == "TURTLE_TELEMETRY" then
        if type(p2) == "table" and p2.id then
            p2.lastSeen = os.clock()
            activeTurtles[p2.id] = p2
            renderDashboard()
        end
    elseif event == "timer" and p1 == timerId then
        -- Prune turtles inactive for over 60 seconds
        local now = os.clock()
        local changed = false
        for id, data in pairs(activeTurtles) do
            if data.lastSeen and (now - data.lastSeen > 60) then
                activeTurtles[id] = nil
                changed = true
            end
        end
        if changed then
            renderDashboard()
        end
        timerId = os.startTimer(1)
    end
end
