-- Repository Auto-Updater Manifest for cc-computer-scripts
-- Host: TheTip47/cc-computer-scripts

local baseUrl = "https://raw.githubusercontent.com/TheTip47/cc-computer-scripts/main/"

local files = {
    "playlist.lua",
    "playmp3.lua",
    "update.lua"
}

print("=== Synchronizing cc-computer-scripts Repository ===")

for _, filename in ipairs(files) do
    local targetUrl = baseUrl .. filename
    print("Downloading: " .. filename)
    
    local response = http.get(targetUrl, nil, true)
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(filename, "wb")
        if file then
            file.write(content)
            file.close()
            print("  [OK] " .. filename .. " updated successfully.")
        else
            print("  [ERROR] Could not open " .. filename .. " for writing.")
        end
    else
        print("  [ERROR] Failed to fetch " .. targetUrl)
    end
end

print("=== Repository Update Complete ===")
