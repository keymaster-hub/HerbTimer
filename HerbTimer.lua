local addonName = ...

local WorldMapDataProvider

local DEFAULT_TRACKED_ITEMS = {
    [22792] = true, -- Nightmare Vine
}

local ITEM_NAMES = {
    [22792] = "Nightmare Vine",
    [22793] = "Mana Thistle",
}

local function CopyDefaultTrackedItems()
    local t = {}
    for id in pairs(DEFAULT_TRACKED_ITEMS) do
        t[id] = true
    end
    return t
end

local function MigrateDB()
    if HerbTimerDB == nil then
        HerbTimerDB = {}
    end

    -- Old format: HerbTimerDB used to be a flat array of points.
    if HerbTimerDB[1] and type(HerbTimerDB[1]) == "table" and HerbTimerDB[1].mapID then
        HerbTimerDB = { points = HerbTimerDB }
    end

    HerbTimerDB.points = HerbTimerDB.points or {}
    HerbTimerDB.trackedItems = HerbTimerDB.trackedItems or CopyDefaultTrackedItems()

    if HerbTimerDB.showIcons == nil then
        HerbTimerDB.showIcons = false
    end
end

MigrateDB()

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    -- SavedVariables are only restored right before ADDON_LOADED fires,
    -- which happens AFTER this file's top-level code already ran and
    -- overwrites whatever MigrateDB() set up above. So migrate again
    -- here, once the real saved data is actually in place.
    MigrateDB()

    self:UnregisterEvent("ADDON_LOADED")
end)

local POINT_DISTANCE = 0.01

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_LOOT")

local function FindNearbyPoint(mapID, x, y, itemID)
    for _, point in ipairs(HerbTimerDB.points) do
        if point.mapID == mapID and point.itemID == itemID then
            local dx = point.x - x
            local dy = point.y - y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= POINT_DISTANCE then
                return point
            end
        end
    end

    return nil
end

frame:SetScript("OnEvent", function(self, event, msg)
    if not msg:find("^You receive loot:") then
        return
    end

    local itemLink = msg:match("(|c%x+|Hitem:%d+.-|h%[.-%]|h|r)")
    if not itemLink then
        return
    end

    local itemName = itemLink:match("%[(.-)%]")
    local itemID = tonumber(itemLink:match("item:(%d+)"))

    if not itemID or not HerbTimerDB.trackedItems[itemID] then
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")

    if not mapID then
        print("|cffff0000HerbTimer: Cannot determine map.|r")
        return
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")

    if not position then
        print("|cffff0000HerbTimer: Cannot determine position.|r")
        return
    end

    local x, y = position:GetXY()
    local point = FindNearbyPoint(mapID, x, y, itemID)

    if point then
        point.x = x
        point.y = y
        point.itemName = itemName
        point.itemID = itemID
        point.time = time()

        print("|cff00ff00HerbTimer: Updated existing point.|r")
    else
        point = {
            mapID = mapID,
            x = x,
            y = y,
            itemName = itemName,
            itemID = itemID,
            time = time(),
        }

        table.insert(HerbTimerDB.points, point)

        print("|cff00ff00HerbTimer: New point saved!|r")
    end

    print(string.format(
        "  %s - %.2f, %.2f",
        itemName,
        x * 100,
        y * 100
    ))
end)

local function GetItemDisplayName(itemID)
    local name = ITEM_NAMES[itemID]

    if name then
        return name
    end

    local infoName = GetItemInfo(itemID)
    return infoName or ("item " .. itemID)
end

local function PrintTrackedItems()
    print("|cff00ff00HerbTimer tracked items:|r")

    local any = false
    for itemID in pairs(HerbTimerDB.trackedItems) do
        any = true
        print(string.format("  |cffaaaaaa%d|r — %s", itemID, GetItemDisplayName(itemID)))
    end

    if not any then
        print("  (none)")
    end
end

local function PrintPoints()
    if #HerbTimerDB.points == 0 then
        print("|cffffcc00HerbTimer:|r Database is empty.")
        return
    end

    print("|cff00ff00HerbTimer points: " .. #HerbTimerDB.points .. "|r")

    for i, point in ipairs(HerbTimerDB.points) do
        local timeText = point.time and date("%H:%M:%S", point.time) or "Unknown"

        print(string.format(
            "|cffaaaaaa%d.|r Map %d — %.2f, %.2f — %s (id: %s) — %s",
            i,
            point.mapID,
            point.x * 100,
            point.y * 100,
            point.itemName or "Unknown",
            tostring(point.itemID),
            timeText
        ))
    end
end

local function PrintHelp()
    print("|cff00ff00HerbTimer commands:|r")
    print("  |cffffcc00/ht list|r — show saved points")
    print("  |cffffcc00/ht add <itemID>|r — track an item")
    print("  |cffffcc00/ht remove <itemID>|r — stop tracking an item")
    print("  |cffffcc00/ht items|r — show tracked item IDs")
    print("  |cffffcc00/ht icons|r — toggle item icons on the map (time-only when off)")
    print("  |cffffcc00/ht clear|r — clear all saved points")
    print("  |cffffcc00/ht help|r — show this list")
end

local function HandleSlashCommand(msg)
    msg = strtrim(msg or "")

    local command, rest
    local spacePos = msg:find(" ")

    if spacePos then
        command = msg:sub(1, spacePos - 1)
        rest = strtrim(msg:sub(spacePos + 1))
    else
        command = msg
        rest = ""
    end

    command = command:lower()

    if command == "" or command == "help" then
        PrintHelp()
    elseif command == "list" then
        PrintPoints()
    elseif command == "clear" then
        if wipe then
            wipe(HerbTimerDB.points)
        else
            for i = #HerbTimerDB.points, 1, -1 do
                HerbTimerDB.points[i] = nil
            end
        end
        print("|cffffcc00HerbTimer:|r Database cleared.")
    elseif command == "add" then
        local itemID = tonumber(rest)

        if not itemID then
            print("|cffff0000HerbTimer:|r Usage: /ht add <itemID>")
            return
        end

        HerbTimerDB.trackedItems[itemID] = true
        print(string.format("|cff00ff00HerbTimer:|r Now tracking %s (id: %d).", GetItemDisplayName(itemID), itemID))
    elseif command == "remove" then
        local itemID = tonumber(rest)

        if not itemID then
            print("|cffff0000HerbTimer:|r Usage: /ht remove <itemID>")
            return
        end

        HerbTimerDB.trackedItems[itemID] = nil

        local removedCount = 0
        for i = #HerbTimerDB.points, 1, -1 do
            if HerbTimerDB.points[i].itemID == itemID then
                table.remove(HerbTimerDB.points, i)
                removedCount = removedCount + 1
            end
        end

        if WorldMapFrame:IsShown() then
            WorldMapDataProvider:RefreshAllData()
        end

        print(string.format(
            "|cff00ff00HerbTimer:|r Stopped tracking id %d and removed %d saved point(s).",
            itemID,
            removedCount
        ))
    elseif command == "icons" then
        HerbTimerDB.showIcons = not HerbTimerDB.showIcons

        print(string.format(
            "|cff00ff00HerbTimer:|r Item icons %s.",
            HerbTimerDB.showIcons and "enabled" or "disabled (time-only)"
        ))

        if WorldMapFrame:IsShown() then
            WorldMapDataProvider:RefreshAllData()
        end
    elseif command == "items" then
        PrintTrackedItems()
    else
        print(string.format("|cffff0000HerbTimer:|r Unknown command '%s'.", command))
        PrintHelp()
    end
end

SLASH_HERBTIMER1 = "/herbtimer"
SLASH_HERBTIMER2 = "/ht"

SlashCmdList["HERBTIMER"] = HandleSlashCommand

--------------------------------------------------
-- WORLD MAP
--------------------------------------------------

WorldMapDataProvider = CreateFromMixins(MapCanvasDataProviderMixin)
local worldMapPins = {}

function WorldMapDataProvider:RemoveAllData()
    local map = self:GetMap()

    if map then
        map:RemoveAllPinsByTemplate("HerbTimerWorldMapPinTemplate")
    end

    wipe(worldMapPins)
end

function WorldMapDataProvider:RefreshAllData()
    self:RemoveAllData()

    if not HerbTimerDB or not HerbTimerDB.points then
        return
    end

    local map = self:GetMap()
    if not map then
        return
    end

    local mapID = map:GetMapID()
    if not mapID then
        return
    end

    for _, point in ipairs(HerbTimerDB.points) do
        if point.mapID == mapID then
            local pin = map:AcquirePin(
                "HerbTimerWorldMapPinTemplate",
                point
            )

            table.insert(worldMapPins, pin)
        end
    end
end

--------------------------------------------------
-- WORLD MAP PIN
--------------------------------------------------

HerbTimerWorldMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function HerbTimerWorldMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)

    self.texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")

    self.timeText = self:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )

    self.timeText:SetPoint(
        "BOTTOM",
        self,
        "TOP",
        0,
        2
    )
end

local DEFAULT_ICON = "Interface\\ICONS\\INV_Misc_QuestionMark"

local function GetIconForItemID(itemID)
    if not itemID then
        return nil
    end

    local icon = GetItemIcon(itemID)

    if not icon and C_Item and C_Item.GetItemIconByID then
        icon = C_Item.GetItemIconByID(itemID)
    end

    if not icon then
        local _, _, _, _, _, _, _, _, _, iconFromInfo = GetItemInfo(itemID)
        icon = iconFromInfo
    end

    return icon
end

function HerbTimerWorldMapPinMixin:OnAcquired(point)
    self.point = point

    self:SetPosition(point.x, point.y)

    if HerbTimerDB.showIcons then
        local icon = GetIconForItemID(point.itemID)
        self.texture:SetTexture(icon or DEFAULT_ICON)
        self.texture:SetVertexColor(1, 1, 1, 1)
        self.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        self.texture:Show()
    else
        self.texture:Hide()
    end

    if point.time then
        self.timeText:SetText(date("%H:%M", point.time))
    else
        self.timeText:SetText("")
    end

    self:Show()
end

WorldMapFrame:AddDataProvider(WorldMapDataProvider)

local refreshFrame = CreateFrame("Frame")

refreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
refreshFrame:RegisterEvent("ZONE_CHANGED")
refreshFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

refreshFrame:SetScript("OnEvent", function()
    C_Timer.After(0.2, function()
        if WorldMapFrame:IsShown() then
            WorldMapDataProvider:RefreshAllData()
        end
    end)
end)

WorldMapFrame:HookScript("OnShow", function()
    C_Timer.After(0.1, function()
        WorldMapDataProvider:RefreshAllData()
    end)
end)

print("|cff00ff00HerbTimer|r loaded!")
print("|cffaaaaaaType /ht for the command list.|r")
