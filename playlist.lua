-- FULL FILE: playlist.lua
-- CC:HQ Speakers Interactive MP3 Player with Synchronized Multi-Speaker & Touch UI
-- Target Environment: ATM10 (Minecraft 1.21.1 / NeoForge)
-- Repository Host: TheTip47/cc-computer-scripts (Branch: main)

if not http then
    error("HTTP API is disabled on this server. Enable http_enable in computercraft-server.toml.")
end

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
end

local BASE_URL = "https://raw.githubusercontent.com/TheTip47/cc-computer-scripts/main/"

local playlist = {
    {
        title = "$UICIDEBOY$ - MSY",
        file = "%24UICIDEBOY%24%20-%20MSY%20%28Lyric%20Video%29.mp3"
    },
    {
        title = "Larry June - Black Man",
        file = "Larry%20June%20%26%20Cardo%20Got%20Wings%20-%20Black%20Man%20%28Official%20Video%29.mp3"
    },
    {
        title = "Papa Roach - HELP",
        file = "Papa%20Roach%20-%20HELP%20%28Official%20Audio%29.mp3"
    }
}

local state = {
    currentIndex = 1,
    isPlaying = false,
    isPaused = false,
    isFetching = false,
    currentData = nil,
    currentTrackTitle = "",
    statusText = "STOPPED",
    actionRequested = nil, -- "next", "prev", "toggle_pause"
    scrollOffset = 1,
    running = true
}

local function getConnectedSpeakers()
    local found = { peripheral.find("speaker") }
    local valid = {}
    for _, spk in ipairs(found) do
        if type(spk.speakMp3) == "function" then
            table.insert(valid, spk)
        end
    end
    return valid
end

local function broadcastMp3(audioBytes)
    if not audioBytes or type(audioBytes) ~= "string" or #audioBytes == 0 then
        return false
    end

    local activeSpeakers = getConnectedSpeakers()
    if #activeSpeakers == 0 then
        return false
    end

    if #activeSpeakers == 1 then
        local ok = pcall(function() activeSpeakers[1].speakMp3(audioBytes, 1.0) end)
        return ok
    end

    -- Synchronized parallel execution to eliminate audio latency drift across wired network
    local calls = {}
    local playedAny = false
    for _, spk in ipairs(activeSpeakers) do
        local currentSpeaker = spk
        table.insert(calls, function()
            local ok = pcall(function()
                currentSpeaker.speakMp3(audioBytes, 1.0)
            end)
            if ok then playedAny = true end
        end)
    end

    parallel.waitForAll(table.unpack(calls))
    return playedAny
end

local function stopAllSpeakers()
    local activeSpeakers = getConnectedSpeakers()
    if #activeSpeakers == 0 then return end

    if #activeSpeakers == 1 then
        if type(activeSpeakers[1].stop) == "function" then
            pcall(function() activeSpeakers[1].stop() end)
        end
        return
    end

    local calls = {}
    for _, spk in ipairs(activeSpeakers) do
        local currentSpeaker = spk
        table.insert(calls, function()
            if type(currentSpeaker.stop) == "function" then
                pcall(function() currentSpeaker.stop() end)
            end
        end)
    end

    parallel.waitForAll(table.unpack(calls))
end

local function isAnySpeakerPlaying()
    local activeSpeakers = getConnectedSpeakers()
    for _, spk in ipairs(activeSpeakers) do
        if type(spk.speakIsPlaying) == "function" then
            local ok, playing = pcall(function() return spk.speakIsPlaying() end)
            if ok and playing then
                return true
            end
        end
    end
    return false
end

local function centerText(text, width)
    if #text >= width then
        return string.sub(text, 1, width)
    end
    local pad = math.floor((width - #text) / 2)
    return string.rep(" ", pad) .. text .. string.rep(" ", width - #text - pad)
end

local function getFormattedTitle(fullTitle, width)
    if #fullTitle <= width then
        return centerText(fullTitle, width)
    end
    local padded = fullTitle .. "   ---   "
    local loopLen = #padded
    local startPos = ((state.scrollOffset - 1) % loopLen) + 1
    local extended = padded .. padded
    return string.sub(extended, startPos, startPos + width - 1)
end

local function drawUIOnDevice(device)
    if not device then return end

    local w, h = device.getSize()
    device.setBackgroundColor(colors.black)
    device.clear()

    if w <= 16 then
        -- Compact UI layout optimized for 1-Block Screen (scale 0.5 = 14x10 grid)
        device.setCursorPos(1, 1)
        device.setBackgroundColor(colors.blue)
        device.setTextColor(colors.white)
        device.write(centerText("HQ PLAYER", w))

        -- Status Indicator
        device.setCursorPos(1, 2)
        device.setBackgroundColor(colors.gray)
        device.setTextColor(colors.yellow)
        local stat = state.statusText
        if #stat > w then stat = string.sub(stat, 1, w) end
        device.write(centerText(stat, w))

        -- Track Title Display (Scrolling Marquee)
        device.setCursorPos(1, 3)
        device.setBackgroundColor(colors.black)
        device.setTextColor(colors.cyan)
        local rawTitle = playlist[state.currentIndex].title
        device.write(getFormattedTitle(rawTitle, w))

        -- Touch Controls (Rows 5 to 7 - Expanded 3-row touch bounds)
        local btnY1, btnY2, btnY3 = 5, 6, 7

        -- PREV Button (Cols 1-4)
        device.setBackgroundColor(colors.red)
        device.setTextColor(colors.white)
        device.setCursorPos(1, btnY1)
        device.write(" << ")
        device.setCursorPos(1, btnY2)
        device.write("PREV")
        device.setCursorPos(1, btnY3)
        device.write(" << ")

        -- PLAY / PAUSE Button (Cols 6-9)
        if state.isPaused or not state.isPlaying then
            device.setBackgroundColor(colors.green)
            device.setTextColor(colors.black)
            device.setCursorPos(6, btnY1)
            device.write(" >  ")
            device.setCursorPos(6, btnY2)
            device.write("PLAY")
            device.setCursorPos(6, btnY3)
            device.write(" >  ")
        else
            device.setBackgroundColor(colors.orange)
            device.setTextColor(colors.black)
            device.setCursorPos(6, btnY1)
            device.write(" || ")
            device.setCursorPos(6, btnY2)
            device.write("PAUS")
            device.setCursorPos(6, btnY3)
            device.write(" || ")
        end

        -- NEXT Button (Cols 11-14)
        device.setBackgroundColor(colors.lime)
        device.setTextColor(colors.black)
        device.setCursorPos(11, btnY1)
        device.write(" >> ")
        device.setCursorPos(11, btnY2)
        device.write("NEXT")
        device.setCursorPos(11, btnY3)
        device.write(" >> ")

        -- Track Counter Footer
        device.setCursorPos(1, 9)
        device.setBackgroundColor(colors.black)
        device.setTextColor(colors.lightGray)
        device.write(centerText("TRK " .. state.currentIndex .. " OF " .. #playlist, w))

        device.setCursorPos(1, 10)
        device.setTextColor(colors.gray)
        device.write(centerText("ATM10 MP3", w))
    else
        -- Standard Terminal Display Layout
        device.setCursorPos(1, 1)
        device.setBackgroundColor(colors.blue)
        device.setTextColor(colors.white)
        device.write(centerText("CC:HQ SPEAKERS GITHUB MUSIC PLAYER", w))

        device.setCursorPos(1, 3)
        device.setBackgroundColor(colors.black)
        device.setTextColor(colors.white)
        device.write("Status: ")
        device.setTextColor(colors.yellow)
        device.write(state.statusText)

        device.setCursorPos(1, 5)
        device.setTextColor(colors.white)
        device.write("Current Track [" .. state.currentIndex .. "/" .. #playlist .. "]: ")
        device.setTextColor(colors.cyan)
        device.write(playlist[state.currentIndex].title)

        device.setCursorPos(1, 8)
        device.setTextColor(colors.lightGray)
        device.write("Controls (Click Monitor or Press Key):")

        -- Interactive Buttons on Terminal
        device.setCursorPos(2, 10)
        device.setBackgroundColor(colors.red)
        device.setTextColor(colors.white)
        device.write(" [ PREV (P) ] ")

        device.setCursorPos(18, 10)
        if state.isPaused or not state.isPlaying then
            device.setBackgroundColor(colors.green)
            device.setTextColor(colors.black)
            device.write(" [ PLAY (SPACE) ] ")
        else
            device.setBackgroundColor(colors.orange)
            device.setTextColor(colors.black)
            device.write(" [ PAUSE (SPACE) ] ")
        end

        device.setCursorPos(38, 10)
        device.setBackgroundColor(colors.lime)
        device.setTextColor(colors.black)
        device.write(" [ NEXT (N) ] ")

        device.setCursorPos(1, 13)
        device.setBackgroundColor(colors.black)
        device.setTextColor(colors.gray)
        device.write("Press Ctrl+T in terminal to exit.")
    end
end

local function drawAllUI()
    if monitor then
        drawUIOnDevice(monitor)
    end
    drawUIOnDevice(term)
end

local function handleTouchInput(x, y, isCompact)
    if isCompact then
        -- 1-Block Screen touch bounds (Rows 5 to 7, Scale 0.5)
        if y >= 5 and y <= 7 then
            if x >= 1 and x <= 4 then
                state.actionRequested = "prev"
            elseif x >= 6 and x <= 9 then
                state.actionRequested = "toggle_pause"
            elseif x >= 11 and x <= 14 then
                state.actionRequested = "next"
            end
        end
    else
        -- Terminal touch bounds
        if y == 10 then
            if x >= 2 and x <= 15 then
                state.actionRequested = "prev"
            elseif x >= 18 and x <= 35 then
                state.actionRequested = "toggle_pause"
            elseif x >= 38 and x <= 50 then
                state.actionRequested = "next"
            end
        end
    end
end

local function fetchMp3Data(encodedFilename)
    local fullUrl = BASE_URL .. encodedFilename
    state.isFetching = true
    state.statusText = "BUFFERING..."
    state.scrollOffset = 1
    drawAllUI()

    local response, err = http.get(fullUrl, nil, true)
    if not response then
        state.isFetching = false
        state.statusText = "DOWNLOAD ERR"
        drawAllUI()
        return nil
    end

    local data = response.readAll()
    response.close()

    state.isFetching = false
    if not data or #data == 0 then
        state.statusText = "EMPTY MP3 DATA"
        drawAllUI()
        return nil
    end

    return data
end

local function uiControlLoop()
    if monitor then
        monitor.setTextScale(0.5)
    end
    drawAllUI()

    local timerID = os.startTimer(0.3)

    while state.running do
        local eventData = { os.pullEvent() }
        local eventType = eventData[1]

        if eventType == "monitor_touch" then
            local side, x, y = eventData[2], eventData[3], eventData[4]
            local mw, mh = monitor.getSize()
            handleTouchInput(x, y, mw <= 16)
            drawAllUI()
        elseif eventType == "mouse_click" then
            local button, x, y = eventData[2], eventData[3], eventData[4]
            local tw, th = term.getSize()
            handleTouchInput(x, y, tw <= 16)
            drawAllUI()
        elseif eventType == "key" then
            local key = eventData[2]
            if key == keys.space then
                state.actionRequested = "toggle_pause"
            elseif key == keys.n or key == keys.right then
                state.actionRequested = "next"
            elseif key == keys.p or key == keys.left then
                state.actionRequested = "prev"
            end
            drawAllUI()
        elseif eventType == "timer" and eventData[2] == timerID then
            if state.isPlaying and not state.isPaused then
                state.scrollOffset = state.scrollOffset + 1
            end
            drawAllUI()
            timerID = os.startTimer(0.3)
        end
    end
end

local function audioPlaybackLoop()
    while state.running do
        local activeSpeakers = getConnectedSpeakers()
        if #activeSpeakers == 0 then
            state.statusText = "NO SPEAKER"
            drawAllUI()
            os.sleep(2)
        else
            local track = playlist[state.currentIndex]
            state.currentTrackTitle = track.title
            state.currentData = fetchMp3Data(track.file)

            if state.currentData then
                state.isPlaying = true
                state.isPaused = false
                state.statusText = "PLAYING"
                drawAllUI()

                local played = broadcastMp3(state.currentData)

                if not played then
                    state.statusText = "SPEAK ERR"
                    drawAllUI()
                    os.sleep(2)
                else
                    while state.running do
                        os.sleep(0.1)

                        if state.actionRequested == "toggle_pause" then
                            state.actionRequested = nil
                            if state.isPaused then
                                state.isPaused = false
                                state.statusText = "PLAYING"
                                broadcastMp3(state.currentData)
                            else
                                state.isPaused = true
                                state.statusText = "PAUSED"
                                stopAllSpeakers()
                            end
                            drawAllUI()
                        elseif state.actionRequested == "next" then
                            state.actionRequested = nil
                            stopAllSpeakers()
                            state.currentIndex = state.currentIndex + 1
                            if state.currentIndex > #playlist then
                                state.currentIndex = 1
                            end
                            break
                        elseif state.actionRequested == "prev" then
                            state.actionRequested = nil
                            stopAllSpeakers()
                            state.currentIndex = state.currentIndex - 1
                            if state.currentIndex < 1 then
                                state.currentIndex = #playlist
                            end
                            break
                        end

                        if not state.isPaused and not isAnySpeakerPlaying() then
                            state.currentIndex = state.currentIndex + 1
                            if state.currentIndex > #playlist then
                                state.currentIndex = 1
                            end
                            break
                        end
                    end
                end
            else
                os.sleep(3)
                state.currentIndex = state.currentIndex + 1
                if state.currentIndex > #playlist then
                    state.currentIndex = 1
                end
            end
        end
    end
end

local function main()
    parallel.waitForAny(uiControlLoop, audioPlaybackLoop)
    stopAllSpeakers()
    if monitor then
        monitor.clear()
    end
    term.clear()
    term.setCursorPos(1, 1)
end

main()
