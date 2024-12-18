-- Initialize the database if it doesn't exist
if not CharacterTrackerDB then
    CharacterTrackerDB = {}
end

-- Create a basic frame for the UI
local CharacterTrackerFrame = CreateFrame("Frame", "CharacterTrackerFrame", UIParent)
CharacterTrackerFrame:SetSize(910, 400)  -- Width, Height
CharacterTrackerFrame:SetPoint("CENTER") -- Centered on the screen

-- Create a background texture
local bg = CharacterTrackerFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(CharacterTrackerFrame)
bg:SetColorTexture(0, 0, 0, 0.8) -- Black with 80% opacity

-- Add a border
local border = CreateFrame("Frame", nil, CharacterTrackerFrame, "BackdropTemplate")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
})
border:SetBackdropBorderColor(1, 1, 1, 1) -- White border
CharacterTrackerFrame:Hide() -- Start hidden

-- Add the frame to UISpecialFrames to close it with the Escape key
table.insert(UISpecialFrames, "CharacterTrackerFrame")

-- Add a title to the frame
local title = CharacterTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("Character Tracker")

-- Create a scrollable area
local scrollFrame = CreateFrame("ScrollFrame", nil, CharacterTrackerFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(890, 300) -- Match width, set height for visible rows
scrollFrame:SetPoint("TOP", 0, -40)

-- Create the scrollable content frame
local scrollContent = CreateFrame("Frame", nil, scrollFrame)
scrollContent:SetSize(890, 300) -- Initial size; will expand based on rows
scrollFrame:SetScrollChild(scrollContent)

-- Table to hold rows for character data
scrollContent.rows = {}

-- Start hidden
CharacterTrackerFrame:Hide()

-- Make the frame movable
CharacterTrackerFrame:SetMovable(true)
CharacterTrackerFrame:EnableMouse(true)
CharacterTrackerFrame:RegisterForDrag("LeftButton")
CharacterTrackerFrame:SetScript("OnDragStart", CharacterTrackerFrame.StartMoving)
CharacterTrackerFrame:SetScript("OnDragStop", CharacterTrackerFrame.StopMovingOrSizing)

-- Slash command to toggle the frame
SLASH_CT1 = "/ct"
function SlashCmdList.CT(msg, editbox)
    if CharacterTrackerFrame:IsShown() then
        CharacterTrackerFrame:Hide()
    else
        CharacterTrackerFrame:Show()
    end
end

-- Function to refresh the table with sorted data
local function RefreshCharacterTable()
    -- Clear existing rows
    for _, row in ipairs(scrollContent.rows) do
        row:Hide()
    end
    wipe(scrollContent.rows)

    -- Get the current character's name
    local currentCharacter = UnitName("player")

    -- Create a sorted list of characters by item level
    local sortedCharacters = {}
    for name, data in pairs(CharacterTrackerDB) do
        table.insert(sortedCharacters, {
            name = name,
            class = data.class or "Unknown",
            race = data.race or "Unknown",
            spec = data.spec or "None",
            itemLevel = tonumber(data.itemLevel) or 0, -- Ensure itemLevel is numeric
            profession1 = data.profession1 or "None",
            profession2 = data.profession2 or "None"
        })
    end

    -- Sort the table by item level in descending order
    table.sort(sortedCharacters, function(a, b)
        return a.itemLevel > b.itemLevel
    end)

    -- Add table headers
    local header = CreateFrame("Frame", nil, scrollContent)
    header:SetSize(870, 20)
    header:SetPoint("TOP", 0, 0)

    local headers = { "Name", "Class", "Race", "Spec", "Item Level", "Profession1", "Profession2" }
    local columnWidths = { 120, 120, 150, 120, 100, 150, 120 }
    local xOffset = 10
    for i, text in ipairs(headers) do
        local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        headerText:SetPoint("LEFT", header, "LEFT", xOffset, 0)
        headerText:SetText(text)
        xOffset = xOffset + columnWidths[i]
    end

    table.insert(scrollContent.rows, header)

    -- Add sorted rows to the table
    local yOffset = -30 -- Starting offset below the header
    local rowHeight = 25
    for _, character in ipairs(sortedCharacters) do
        -- Create a new row
        local row = CreateFrame("Frame", nil, scrollContent)
        row:SetSize(880, 20)
        row:SetPoint("TOP", 0, yOffset)

        -- Highlight the current character's row
        if character.name == currentCharacter then
            local highlight = row:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints(row)
            highlight:SetColorTexture(0.2, 0.8, 0.2, 0.4) -- Greenish background with transparency
        end

        -- Add columns
        local values = {
            character.name,
            character.class,
            character.race,
            character.spec,
            string.format("%.1f", character.itemLevel), -- Format itemLevel as a number
            character.profession1,
            character.profession2
        }

        xOffset = 10
        for i, value in ipairs(values) do
            local cellText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cellText:SetPoint("LEFT", row, "LEFT", xOffset, 0)
            cellText:SetText(value)
            xOffset = xOffset + columnWidths[i]
        end

        -- Store the row for cleanup
        table.insert(scrollContent.rows, row)

        -- Update the offset for the next row
        yOffset = yOffset - rowHeight
    end

    -- Adjust the scrollable content height based on rows
    scrollContent:SetHeight(math.abs(yOffset))
end

-- Refresh the table when the frame is shown
CharacterTrackerFrame:SetScript("OnShow", function()
    RefreshCharacterTable()
end)

-- Save character data when the player logs in or updates occur
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE") -- Update item level dynamically
frame:RegisterEvent("SKILL_LINES_CHANGED") -- Update professions dynamically

local function UpdateCharacterData(event)
    local name = UnitName("player")
    local itemLevel = string.format("%.1f", select(2, GetAverageItemLevel()))
    local professions = { GetProfessions() }
    local profession1, profession2 = "None", "None"

    if professions[1] then
        local profName, _, skillLevel = GetProfessionInfo(professions[1])
        profession1 = profName .. " (" .. skillLevel .. ")"
    end
    if professions[2] then
        local profName, _, skillLevel = GetProfessionInfo(professions[2])
        profession2 = profName .. " (" .. skillLevel .. ")"
    end

    if not CharacterTrackerDB[name] then
        CharacterTrackerDB[name] = {}
    end

    -- Update data in the database
    CharacterTrackerDB[name].itemLevel = itemLevel
    CharacterTrackerDB[name].profession1 = profession1
    CharacterTrackerDB[name].profession2 = profession2

    --- print("Updated character data for", name, "via event:", event)

    -- Refresh table if visible
    if CharacterTrackerFrame:IsShown() then
        RefreshCharacterTable()
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        UpdateCharacterData("PLAYER_LOGIN")
    elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
        UpdateCharacterData("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    elseif event == "SKILL_LINES_CHANGED" then
        UpdateCharacterData("SKILL_LINES_CHANGED")
    end
end)
