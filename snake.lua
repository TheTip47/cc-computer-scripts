-- Snake Game for 3x3 Advanced Monitor
-- Target Platform: CC: Tweaked 1.21.1 / CraftOS
-- Supports Keyboard Controls (WASD/Arrows) and On-Screen Touch Arrow Buttons

local mon = peripheral.find("monitor")
if not mon then
    error("No monitor found! Attach an Advanced Monitor to run this script.")
end

if not mon.isColor() then
    error("Advanced (Gold) Monitor required for color display.")
end

-- Monitor Initialization
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Dynamic Control Bar Boundaries
local ctrlYStart = h - 3
local playfieldH = ctrlYStart - 1

-- Button X-ranges
local btnLeft = { x1 = 2, x2 = math.floor(w * 0.24) }
local btnUp   = { x1 = math.floor(w * 0.26), x2 = math.floor(w * 0.49) }
local btnDown = { x1 = math.floor(w * 0.51), x2 = math.floor(w * 0.74) }
local btnRight= { x1 = math.floor(w * 0.76), x2 = w - 1 }

-- Game State Variables
local snake = {}
local dir = "RIGHT"
local nextDir = "RIGHT"
local food = { x = 0, y = 0 }
local score = 0
local highScore = 0
local gameState = "MENU" -- "MENU", "PLAYING", "GAMEOVER"
local gameTimer = nil
local tickRate = 0.10

-- Helper: Render centered text on monitor
local function drawCenteredText(y, text, textColor, bgColor)
    mon.setTextColor(textColor)
    mon.setBackgroundColor(bgColor)
    local x = math.floor((w - #text) / 2) + 1
    mon.setCursorPos(x, y)
    mon.write(text)
end

-- Helper: Render text aligned in bounding box
local function drawBoxText(x1, x2, y, text, textColor, bgColor)
    mon.setTextColor(textColor)
    mon.setBackgroundColor(bgColor)
    local width = x2 - x1 + 1
    local pad = math.floor((width - #text) / 2)
    if pad < 0 then pad = 0 end
    mon.setCursorPos(x1, y)
    local str = string.rep(" ", pad) .. text
    if #str < width then
        str = str .. string.rep(" ", width - #str)
    else
        str = string.sub(str, 1, width)
    end
    mon.write(str)
end

-- Helper: Spawn food away from snake body
local function spawnFood()
    while true do
        local fx = math.random(2, w - 1)
        local fy = math.random(3, playfieldH - 1)
        local occupied = false
        for _, seg in ipairs(snake) do
            if seg.x == fx and seg.y == fy then
                occupied = true
                break
            end
        end
        if not occupied then
            food = { x = fx, y = fy }
            break
        end
    end
end

-- Render Header/Score Bar
local function drawHeader()
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
    
    -- Clear top 2 lines
    for line = 1, 2 do
        mon.setCursorPos(1, line)
        mon.write(string.rep(" ", w))
    end
    
    mon.setCursorPos(2, 1)
    mon.write("SCORE: " .. tostring(score))
    
    local hsStr = "HIGH: " .. tostring(highScore)
    mon.setCursorPos(w - #hsStr - 1, 1)
    mon.write(hsStr)
    
    mon.setBackgroundColor(colors.lightGray)
    mon.setCursorPos(1, 2)
    mon.write(string.rep(" ", w))
end

-- Render On-Screen Touch Control Buttons at Bottom
local function drawTouchControls()
    -- Control Bar Background Separator
    mon.setBackgroundColor(colors.gray)
    mon.setCursorPos(1, ctrlYStart - 1)
    mon.write(string.rep(" ", w))

    -- Clear control bar rows
    mon.setBackgroundColor(colors.black)
    for row = ctrlYStart, h do
        mon.setCursorPos(1, row)
        mon.write(string.rep(" ", w))
    end

    local midRow = ctrlYStart + 1

    -- Render 4 Touch Arrow Key Buttons
    drawBoxText(btnLeft.x1, btnLeft.x2, midRow - 1, "┌───────┐", colors.cyan, colors.black)
    drawBoxText(btnLeft.x1, btnLeft.x2, midRow,     "│ ◄ LEFT│", colors.white, colors.blue)
    drawBoxText(btnLeft.x1, btnLeft.x2, midRow + 1, "└───────┘", colors.cyan, colors.black)

    drawBoxText(btnUp.x1, btnUp.x2, midRow - 1,     "┌───────┐", colors.lime, colors.black)
    drawBoxText(btnUp.x1, btnUp.x2, midRow,         "│  ▲ UP │", colors.white, colors.green)
    drawBoxText(btnUp.x1, btnUp.x2, midRow + 1,     "└───────┘", colors.lime, colors.black)

    drawBoxText(btnDown.x1, btnDown.x2, midRow - 1, "┌───────┐", colors.yellow, colors.black)
    drawBoxText(btnDown.x1, btnDown.x2, midRow,     "│ ▼ DOWN│", colors.black, colors.yellow)
    drawBoxText(btnDown.x1, btnDown.x2, midRow + 1, "└───────┘", colors.yellow, colors.black)

    drawBoxText(btnRight.x1, btnRight.x2, midRow - 1, "┌───────┐", colors.magenta, colors.black)
    drawBoxText(btnRight.x1, btnRight.x2, midRow,     "│ ► RIGHT│", colors.white, colors.purple)
    drawBoxText(btnRight.x1, btnRight.x2, midRow + 1, "└───────┘", colors.magenta, colors.black)
end

-- Render Border Walls
local function drawBorders()
    mon.setBackgroundColor(colors.gray)
    
    -- Bottom playfield wall
    mon.setCursorPos(1, playfieldH)
    mon.write(string.rep(" ", w))
    
    -- Side walls
    for y = 3, playfieldH - 1 do
        mon.setCursorPos(1, y)
        mon.write(" ")
        mon.setCursorPos(w, y)
        mon.write(" ")
    end
end

-- Render Menu Screen
local function drawMenu()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    drawCenteredText(math.floor(h / 3), "=== SNAKE ===", colors.yellow, colors.black)
    drawCenteredText(math.floor(h / 3) + 2, "3x3 Monitor Touch Edition", colors.lightGray, colors.black)
    
    -- Start Button Graphic
    local btnY = math.floor(h / 2) + 2
    drawCenteredText(btnY - 1, " +--------------+ ", colors.green, colors.black)
    drawCenteredText(btnY,     " |  TAP TO START | ", colors.white, colors.green)
    drawCenteredText(btnY + 1, " +--------------+ ", colors.green, colors.black)
    
    drawCenteredText(h - 2, "Use WASD / Arrows or On-Screen Touch Buttons", colors.gray, colors.black)
end

-- Render Game Over Screen
local function drawGameOver()
    local midY = math.floor(h / 2) - 2
    drawCenteredText(midY - 2, " GAMEOVER ", colors.white, colors.red)
    drawCenteredText(midY, "Final Score: " .. tostring(score), colors.yellow, colors.black)
    
    local btnY = midY + 3
    drawCenteredText(btnY - 1, " +---------------+ ", colors.cyan, colors.black)
    drawCenteredText(btnY,     " | PLAY AGAIN    | ", colors.black, colors.cyan)
    drawCenteredText(btnY + 1, " +---------------+ ", colors.cyan, colors.black)
end

-- Initialize New Game
local function resetGame()
    local startX = math.floor(w / 2)
    local startY = math.floor(playfieldH / 2)
    
    snake = {
        { x = startX, y = startY },
        { x = startX - 1, y = startY },
        { x = startX - 2, y = startY }
    }
    
    dir = "RIGHT"
    nextDir = "RIGHT"
    score = 0
    tickRate = 0.10
    
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    drawHeader()
    drawBorders()
    drawTouchControls()
    spawnFood()
    
    -- Initial Food Render
    mon.setBackgroundColor(colors.red)
    mon.setCursorPos(food.x, food.y)
    mon.write(" ")
    
    -- Initial Snake Render
    for i, seg in ipairs(snake) do
        mon.setBackgroundColor(i == 1 and colors.lime or colors.green)
        mon.setCursorPos(seg.x, seg.y)
        mon.write(" ")
    end
    
    gameState = "PLAYING"
    gameTimer = os.startTimer(tickRate)
end

-- Process Movement & Game Rules
local function updateGame()
    dir = nextDir
    local head = snake[1]
    local newHead = { x = head.x, y = head.y }
    
    if dir == "UP" then
        newHead.y = newHead.y - 1
    elseif dir == "DOWN" then
        newHead.y = newHead.y + 1
    elseif dir == "LEFT" then
        newHead.x = newHead.x - 1
    elseif dir == "RIGHT" then
        newHead.x = newHead.x + 1
    end
    
    -- Wall Collision (Y < 3 is Header, Y >= playfieldH is Bottom Playfield Wall, X <= 1 or X >= w are Side Walls)
    if newHead.x <= 1 or newHead.x >= w or newHead.y <= 2 or newHead.y >= playfieldH then
        if score > highScore then highScore = score end
        gameState = "GAMEOVER"
        drawGameOver()
        return
    end
    
    -- Self Collision
    for i = 1, #snake - 1 do
        if snake[i].x == newHead.x and snake[i].y == newHead.y then
            if score > highScore then highScore = score end
            gameState = "GAMEOVER"
            drawGameOver()
            return
        end
    end
    
    table.insert(snake, 1, newHead)
    
    -- Check Food Eaten
    if newHead.x == food.x and newHead.y == food.y then
        score = score + 10
        if score > highScore then highScore = score end
        drawHeader()
        spawnFood()
        
        -- Speed up slightly every 50 points
        if score % 50 == 0 and tickRate > 0.04 then
            tickRate = tickRate - 0.01
        end
        
        -- Render New Food
        mon.setBackgroundColor(colors.red)
        mon.setCursorPos(food.x, food.y)
        mon.write(" ")
    else
        -- Remove Tail Block
        local tail = table.remove(snake)
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(tail.x, tail.y)
        mon.write(" ")
    end
    
    -- Render Former Head as Body
    if #snake > 1 then
        mon.setBackgroundColor(colors.green)
        mon.setCursorPos(snake[2].x, snake[2].y)
        mon.write(" ")
    end
    
    -- Render New Head
    mon.setBackgroundColor(colors.lime)
    mon.setCursorPos(newHead.x, newHead.y)
    mon.write(" ")
    
    gameTimer = os.startTimer(tickRate)
end

-- Handle Touch Inputs
local function handleTouch(tx, ty)
    if gameState == "MENU" or gameState == "GAMEOVER" then
        resetGame()
        return
    end
    
    if gameState == "PLAYING" then
        -- Check if tap was in the Bottom Control Bar
        if ty >= ctrlYStart - 1 then
            if tx >= btnLeft.x1 and tx <= btnLeft.x2 and dir ~= "RIGHT" then
                nextDir = "LEFT"
            elseif tx >= btnUp.x1 and tx <= btnUp.x2 and dir ~= "DOWN" then
                nextDir = "UP"
            elseif tx >= btnDown.x1 and tx <= btnDown.x2 and dir ~= "UP" then
                nextDir = "DOWN"
            elseif tx >= btnRight.x1 and tx <= btnRight.x2 and dir ~= "LEFT" then
                nextDir = "RIGHT"
            end
            return
        end
        
        -- Fallback: Tap direction relative to head if tapped on game field
        local head = snake[1]
        local dx = tx - head.x
        local dy = ty - head.y
        
        if math.abs(dx) > math.abs(dy) then
            if dx > 0 and dir ~= "LEFT" then
                nextDir = "RIGHT"
            elseif dx < 0 and dir ~= "RIGHT" then
                nextDir = "LEFT"
            end
        else
            if dy > 0 and dir ~= "UP" then
                nextDir = "DOWN"
            elseif dy < 0 and dir ~= "UP" then
                nextDir = "UP"
            end
        end
    end
end

-- Handle Keyboard Inputs
local function handleKey(key)
    if gameState == "MENU" or gameState == "GAMEOVER" then
        if key == keys.space or key == keys.enter then
            resetGame()
        end
        return
    end
    
    if gameState == "PLAYING" then
        if (key == keys.up or key == keys.w) and dir ~= "DOWN" then
            nextDir = "UP"
        elseif (key == keys.down or key == keys.s) and dir ~= "UP" then
            nextDir = "DOWN"
        elseif (key == keys.left or key == keys.a) and dir ~= "RIGHT" then
            nextDir = "LEFT"
        elseif (key == keys.right or key == keys.d) and dir ~= "LEFT" then
            nextDir = "RIGHT"
        end
    end
end

-- Main Event Loop
drawMenu()

while true do
    local event, param1, param2, param3 = os.pullEvent()
    
    if event == "timer" and param1 == gameTimer then
        if gameState == "PLAYING" then
            updateGame()
        end
    elseif event == "monitor_touch" then
        handleTouch(param2, param3)
    elseif event == "key" then
        handleKey(param1)
    elseif event == "char" and (param1 == "q" or param1 == "Q") then
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.white)
        mon.clear()
        mon.setCursorPos(1, 1)
        print("Game exited.")
        break
    end
end

