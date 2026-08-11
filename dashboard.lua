-- =========================================================
-- CC: Tweaked - Central Telemetry Dashboard (dashboard.lua)
-- Setup: Place on Advanced Computer with Wireless Modem.
-- Optional: Connect an Advanced Monitor on any side.
-- =========================================================

local modem = peripheral.find("modem")
if modem then
    rednet.open(peripheral.getName(modem))
else
    error("Error: No Wireless Modem found on this computer!")
end

-- Detect optional connected Monitor
local mon = peripheral.find("monitor")
local display = mon or term

if mon then
    mon.setTextScale(0.5)
end

local activeTurtles = {}

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
    
    -- Table Column Headers (Total width: 50 characters to fit 51-col displays)
    display.setCursorPos(1, 5)
    display.setTextColor(colors.cyan)
    display.write(string.format("%-10s %-8s %-15s %-14s\n", "TURTLE", "FUEL", "POS (X,Y,Z)", "STATUS"))
    display.setTextColor(colors.gray)
    display.write("--------------------------------------------------\n")
    
    local line = 7
    local count = 0
    for id, data in pairs(activeTurtles) do
        count = count + 1
        display.setCursorPos(1, line)
        
        -- Fuel color warning & formatting (supports integer and "unlimited")
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
        
        local labelStr = tostring(data.label):sub(1, 10)
        local posStr = string.format("%d,%d,%d", data.x, data.y, data.z):sub(1, 15)
        local statusStr = tostring(data.status):sub(1, 14)
        
        display.write(string.format("%-10s ", labelStr))
        display.write(string.format("%-8s ", fuelStr:sub(1, 8)))
        
        display.setTextColor(colors.white)
        display.write(string.format("%-15s ", posStr))
        
        display.setTextColor(colors.yellow)
        display.write(string.format("%-14s", statusStr))
        
        line = line + 1
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
        -- Prune turtles inactive for over 15 seconds
        local now = os.clock()
        local changed = false
        for id, data in pairs(activeTurtles) do
            if data.lastSeen and (now - data.lastSeen > 15) then
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
