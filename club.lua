-- FULL FILE: club.lua
-- CC:HQ Speakers Interactive Single/Multi-Track Club Player with Touch UI & Auto-Cleanup
-- Target Environment: ATM10 (Minecraft 1.21.1 / NeoForge)
-- Repository Host: TheTip47/cc-computer-scripts (Branch: main)

if not http then
    error("HTTP API is disabled on this server. Enable http_enable in computercraft-server.toml.")
end

-- Auto-cleanup any old leftover cache directory to free virtual disk space
if fs.exists("music_cache") then
    fs.delete("music_cache")
end

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
end

local BASE_URL = "https://raw.githubusercontent.com/TheTip47/cc-computer-scripts/main/"

local playlist = {
    {
        title = "Ty Dolla $ign - Or Nah (feat. The Weeknd, Wiz)",
        file = "Ty%20Dolla%20%24ign%20-%20Or%20Nah%20%28feat.%20The%20Weeknd%2C%20Wiz%29%20%20Lyrics.mp3",
        rawFile = "Ty Dolla $ign - Or Nah (feat. The Weeknd, Wiz)  Lyrics.mp3"
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

    -- Direct, synchronous single-tick execution loop to eliminate inter-speaker desync
    local playedAny = false
    for i = 1, #activeSpeakers do
        local ok = pcall(activeSpeakers[i].speakMp3, audioBytes, 1.0)
        if ok then
            playedAny = true
        end
    end
    return playedAny
end

local function stopAllSpeakers()
    local activeSpeakers = getConnectedSpeakers()
    for i = 1, #activeSpeakers do
        if type(activeSpeakers[i].stop) == "function" then
            pcall(activeSpeakers[i].stop)
        end
    end
end

local function isAnySpeakerPlaying()
    local activeSpeakers = getConnectedSpeakers()
    for i = 1, #activeSpeakers do
        if type(activeSpeakers[i].speakIsPlaying) == "function" then
            local ok, playing = pcall(activeSpeakers[i].speakIsPlaying)
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
        device.setBackgroundColor(colors.purple)
        device.setTextColor(colors.white)
        device.write(centerText("CLUB PLAYER", w))

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

        -- Touch Controls (Rows 5 to 7 - Expanded touch bounds)
        local btnY1, btnY2, btnY3 = 5, 6, 7

        -- PREV / RESTART Button (Cols 1-4)
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

        -- NEXT / REPEAT Button (Cols 11-14)
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
        device.setTextColor(colors.magenta)
        device.write(centerText("CLUB AUDIO", w))
    else
        -- Standard Terminal Display Layout
        device.setCursorPos(1, 1)
        device.setBackgroundColor(colors.purple)
        device.setTextColor(colors.white)
        device.write(centerText("CC:HQ SPEAKERS CLUB PLAYER", w))

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
        if y >= 4 and y <= 8 then
            if x >= 1 and x <= 5 then
                state.actionRequested = "prev"
            elseif x >= 6 and x <= 10 then
                state.actionRequested = "toggle_pause"
            elseif x >= 11 and x <= 14 then
                state.actionRequested = "next"
            end
        end
    else
        if y >= 9 and y <= 11 then
            if x >= 1 and x <= 16 then
                state.actionRequested = "prev"
            elseif x >= 17 and x <= 36 then
                state.actionRequested = "toggle_pause"
            elseif x >= 37 and x <= 51 then
                state.actionRequested = "next"
            end
        end
    end
end

local function fetchMp3Data(track)
    state.isFetching = true
    state.statusText = "BUFFERING..."
    state.scrollOffset = 1
    drawAllUI()

    local fullUrl = BASE_URL .. track.file
    local response, err = http.get(fullUrl, nil, true)

    if not response and track.rawFile then
        local fallbackUrl = BASE_URL .. track.rawFile
        response, err = http.get(fallbackUrl, nil, true)
    end

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
            state.currentData = fetchMp3Data(track)

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
                os.sleep(2)
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

main()
