-- FULL FILE: playlist.lua
-- CC:HQ Speakers Interactive MP3 Player with 1-Block Screen Touch UI
-- Target Environment: ATM10 (Minecraft 1.21.1 / NeoForge)
-- Repository Branch: TheTip47/cc-computer-scripts (music branch)

if not http then
    error("HTTP API is disabled on this server. Enable http_enable in computercraft-server.toml.")
end

local speaker = peripheral.find("speaker")
if not speaker then
    error("No CC:HQ Speaker peripheral found. Connect a speaker to this computer.")
end

if type(speaker.speakMp3) ~= "function" then
    error("Connected speaker does not support MP3 playback. Ensure CCHQ Speakers mod is installed.")
end

local monitor = peripheral.find("monitor")

local BASE_URL = "https://raw.githubusercontent.com/TheTip47/cc-computer-scripts/music/"

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
        title = "Oblivion - Day & Night",
        file = "Oblivion%20-%20Music%20%26%20Ambience%20-%20Day%20%26%20Night%20%281%29.mp3"
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
    running = true
}

local function centerText(text, width)
    if #text >= width then
        return string.sub(text, 1, width)
    end
    local pad = math.floor((width - #text) / 2)
    return string.rep(" ", pad) .. text .. string.rep(" ", width - #text - pad)
end

local function drawUIOnDevice(device)
    if not device then return end

    local w, h = device.getSize()
    device.setBackgroundColor(colors.black)
    device.clear()

    if w <= 16 then
        -- Compact UI layout optimized for 1-Block Screen (scale 0.5 ~ 14x10 grid)
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

        -- Track Title Display
        device.setCursorPos(1, 3)
        device.setBackgroundColor(colors.black)
        device.setTextColor(colors.cyan)
        local rawTitle = playlist[state.currentIndex].title
        if #rawTitle > w then
            rawTitle = string.sub(rawTitle, 1, w)
        end
        device.write(centerText(rawTitle, w))

        -- Touch Controls (Rows 5 to 6)
        -- Button 1: PREV [<<] (Cols 1-4)
        -- Button 2: PLAY/PAUSE [>||] (Cols 6-9)
        -- Button 3: NEXT [>>] (Cols 11-14)
        local btnY1, btnY2 = 5, 6

        -- PREV Button
        device.setBackgroundColor(colors.red)
        device.setTextColor(colors.white)
        device.setCursorPos(1, btnY1)
        device.write(" << ")
        device.setCursorPos(1, btnY2)
        device.write(" PREV")

        -- PLAY / PAUSE Button
        if state.isPaused or not state.isPlaying then
            device.setBackgroundColor(colors.green)
            device.setTextColor(colors.black)
            device.setCursorPos(6, btnY1)
            device.write(" >  ")
            device.setCursorPos(6, btnY2)
            device.write("PLAY")
        else
            device.setBackgroundColor(colors.orange)
            device.setTextColor(colors.black)
            device.setCursorPos(6, btnY1)
            device.write(" || ")
            device.setCursorPos(6, btnY2)
            device.write("PAUS")
        end

        -- NEXT Button
        device.setBackgroundColor(colors.lime)
        device.setTextColor(colors.black)
        device.setCursorPos(11, btnY1)
        device.write(" >> ")
        device.setCursorPos(11, btnY2)
        device.write(" NEXT")

        -- Track Counter Footer
        device.setCursorPos(1, 8)
        device.setBackgroundColor(colors.black)
        device.setTextColor(colors.lightGray)
        device.write(centerText("TRK: " .. state.currentIndex .. "/" .. #playlist, w))

        device.setCursorPos(1, 9)
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
        -- 1-Block Screen touch bounds (scale 0.5)
        if y >= 5 and y <= 6 then
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

    local timerID = os.startTimer(0.5)

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
            drawAllUI()
            timerID = os.startTimer(0.5)
        end
    end
end

local function audioPlaybackLoop()
    while state.running do
        local track = playlist[state.currentIndex]
        state.currentTrackTitle = track.title
        state.currentData = fetchMp3Data(track.file)

        if state.currentData then
            state.isPlaying = true
            state.isPaused = false
            state.statusText = "PLAYING"
            drawAllUI()

            local pcallSuccess, err = pcall(function()
                speaker.speakMp3(state.currentData, 1.0)
            end)

            if not pcallSuccess then
                state.statusText = "SPEAK ERR"
                drawAllUI()
                os.sleep(2)
            else
                -- Playback monitor loop
                while state.running do
                    os.sleep(0.2)

                    -- Check user action triggers
                    if state.actionRequested == "toggle_pause" then
                        state.actionRequested = nil
                        if state.isPaused then
                            state.isPaused = false
                            state.statusText = "PLAYING"
                            speaker.speakMp3(state.currentData, 1.0)
                        else
                            state.isPaused = true
                            state.statusText = "PAUSED"
                            speaker.stop()
                        end
                        drawAllUI()
                    elseif state.actionRequested == "next" then
                        state.actionRequested = nil
                        speaker.stop()
                        state.currentIndex = state.currentIndex + 1
                        if state.currentIndex > #playlist then
                            state.currentIndex = 1
                        end
                        break
                    elseif state.actionRequested == "prev" then
                        state.actionRequested = nil
                        speaker.stop()
                        state.currentIndex = state.currentIndex - 1
                        if state.currentIndex < 1 then
                            state.currentIndex = #playlist
                        end
                        break
                    end

                    -- Check natural end of track playback
                    if not state.isPaused and not speaker.speakIsPlaying() then
                        state.currentIndex = state.currentIndex + 1
                        if state.currentIndex > #playlist then
                            state.currentIndex = 1
                        end
                        break
                    end
                end
            end
        else
            -- Download failed: skip to next after short delay
            os.sleep(3)
            state.currentIndex = state.currentIndex + 1
            if state.currentIndex > #playlist then
                state.currentIndex = 1
            end
        end
    end
end

local function main()
    parallel.waitForAny(uiControlLoop, audioPlaybackLoop)
    speaker.stop()
    if monitor then
        monitor.clear()
    end
    term.clear()
    term.setCursorPos(1, 1)
end

main()
