-- =========================================================
-- CC: Tweaked - Computer Repository Auto-Updater (update.lua)
-- Repository: TheTip47/cc-computer-scripts
-- =========================================================

local baseUrl = "https://raw.githubusercontent.com/TheTip47/cc-computer-scripts/main/"

local manifest = {
    "dashboard.lua",
    "playlist.lua",
    "playmp3.lua",
    "update.lua"
}

if not http then
    error("Error: HTTP API is disabled on this server!")
end

print("========================================")
print(" Checking for Computer Script Updates...")
print("========================================")

for _, filename in ipairs(manifest) do
    local url = baseUrl .. filename
    print("Fetching: " .. filename .. "...")
    
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        print(" -> Updated successfully.")
    else
        print(" -> FAILED to download " .. filename)
    end
end

print("========================================")
print(" Update Complete!")
print("========================================")
