local addonName = ...

local WorldMapDataProvider
local UpdateElapsedTicker
local RebuildMinimapIcons
local RefreshMinimapIconAppearance
local RefreshOptionsPanel

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

    if HerbTimerDB.timeMode == nil then
        HerbTimerDB.timeMode = "clock"
    end

    if HerbTimerDB.showMinimap == nil then
        HerbTimerDB.showMinimap = true
    end

    if HerbTimerDB.showBorder == nil then
        HerbTimerDB.showBorder = true
    end

    if HerbTimerDB.maxPointsPerItem == nil then
        HerbTimerDB.maxPointsPerItem = 2
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

    if RebuildMinimapIcons then
        RebuildMinimapIcons()
    end

    if UpdateElapsedTicker then
        UpdateElapsedTicker()
    end

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
    end

    if RebuildMinimapIcons then
        RebuildMinimapIcons()
    end
end)

local function FormatPointTime(pointTime)
    if not pointTime then
        return "Unknown"
    end

    if HerbTimerDB.timeMode == "elapsed" then
        local elapsed = time() - pointTime
        if elapsed < 0 then
            elapsed = 0
        end

        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)

        if hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        else
            return string.format("%dm", minutes)
        end
    end

    return date("%H:%M", pointTime)
end

-- Returns only the N most recent points per tracked item (HerbTimerDB.maxPointsPerItem),
-- used for what's actually drawn on the world map and minimap. /ht list still shows
-- everything -- this limit only affects the map display.
local function GetVisiblePoints()
    local byItem = {}

    for _, point in ipairs(HerbTimerDB.points) do
        byItem[point.itemID] = byItem[point.itemID] or {}
        table.insert(byItem[point.itemID], point)
    end

    local limit = HerbTimerDB.maxPointsPerItem or 2
    local visible = {}

    for _, points in pairs(byItem) do
        table.sort(points, function(a, b)
            return (a.time or 0) > (b.time or 0)
        end)

        for i = 1, math.min(limit, #points) do
            table.insert(visible, points[i])
        end
    end

    return visible
end

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
        print(string.format(
            "|cffaaaaaa%d.|r Map %d — %.2f, %.2f — %s (id: %s) — %s",
            i,
            point.mapID,
            point.x * 100,
            point.y * 100,
            point.itemName or "Unknown",
            tostring(point.itemID),
            FormatPointTime(point.time)
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
    print("  |cffffcc00/ht time|r — toggle time display: clock time vs. time elapsed")
    print("  |cffffcc00/ht minimap|r — toggle all HerbTimer icons on the minimap")
    print("  |cffffcc00/ht border|r — toggle showing off-range points on the minimap border")
    print("  |cffffcc00/ht options|r — open/close the settings window")
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

    if command == "" then
        if HerbTimerOptionsPanel then
            HerbTimerOptionsPanel:Show()
        end
    elseif command == "help" then
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

        if WorldMapFrame:IsShown() then
            WorldMapDataProvider:RefreshAllData()
        end

        if RebuildMinimapIcons then
            RebuildMinimapIcons()
        end

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
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

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
        end
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

        if RebuildMinimapIcons then
            RebuildMinimapIcons()
        end

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
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

        if RefreshMinimapIconAppearance then
            RefreshMinimapIconAppearance()
        end

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
        end
    elseif command == "time" then
        HerbTimerDB.timeMode = (HerbTimerDB.timeMode == "elapsed") and "clock" or "elapsed"

        print(string.format(
            "|cff00ff00HerbTimer:|r Time display set to %s.",
            HerbTimerDB.timeMode == "elapsed" and "elapsed (e.g. \"5m ago\")" or "clock (e.g. \"14:32\")"
        ))

        if WorldMapFrame:IsShown() then
            WorldMapDataProvider:RefreshAllData()
        end

        if RefreshMinimapIconAppearance then
            RefreshMinimapIconAppearance()
        end

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
        end

        UpdateElapsedTicker()
    elseif command == "minimap" then
        HerbTimerDB.showMinimap = not HerbTimerDB.showMinimap

        print(string.format(
            "|cff00ff00HerbTimer:|r Minimap icons %s.",
            HerbTimerDB.showMinimap and "enabled" or "disabled"
        ))

        if RebuildMinimapIcons then
            RebuildMinimapIcons()
        end

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
        end
    elseif command == "border" then
        HerbTimerDB.showBorder = not HerbTimerDB.showBorder

        print(string.format(
            "|cff00ff00HerbTimer:|r Off-range border markers %s.",
            HerbTimerDB.showBorder and "enabled" or "disabled (out-of-range points are just hidden)"
        ))

        if RebuildMinimapIcons then
            RebuildMinimapIcons()
        end

        if RefreshOptionsPanel then
            RefreshOptionsPanel()
        end
    elseif command == "items" then
        PrintTrackedItems()
    elseif command == "options" or command == "config" then
        if HerbTimerOptionsPanel then
            if HerbTimerOptionsPanel:IsShown() then
                HerbTimerOptionsPanel:Hide()
            else
                HerbTimerOptionsPanel:Show()
            end
        else
            print("|cffff0000HerbTimer:|r Could not open the options panel.")
        end
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

    for _, point in ipairs(GetVisiblePoints()) do
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

    self.timeText:SetText(point.time and FormatPointTime(point.time) or "")

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

local elapsedTicker

function UpdateElapsedTicker()
    local shouldRun = HerbTimerDB.timeMode == "elapsed"

    if shouldRun and not elapsedTicker then
        elapsedTicker = C_Timer.NewTicker(5, function()
            if WorldMapFrame:IsShown() then
                WorldMapDataProvider:RefreshAllData()
            end

            if RefreshMinimapIconAppearance then
                RefreshMinimapIconAppearance()
            end
        end)
    elseif not shouldRun and elapsedTicker then
        elapsedTicker:Cancel()
        elapsedTicker = nil
    end
end

WorldMapFrame:HookScript("OnShow", function()
    C_Timer.After(0.1, function()
        WorldMapDataProvider:RefreshAllData()
    end)

    UpdateElapsedTicker()
end)

WorldMapFrame:HookScript("OnHide", function()
    UpdateElapsedTicker()
end)

--------------------------------------------------
-- MINIMAP (via HereBeDragons)
--------------------------------------------------

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
local MINIMAP_REF = "HerbTimerMinimap"

local minimapIconPool = {}
local minimapIconsByPoint = {}

-- Each entry has two parts:
--   .anchor  - an invisible 1x1 frame that HereBeDragons owns entirely: it
--              moves it and shows/hides it however it wants. We never touch
--              its visibility ourselves.
--   .visible - our actual icon+text frame, parented separately. WE are the
--              only thing that ever shows or hides this one, based on the
--              anchor's current (already-resolved) position. This avoids
--              fighting HereBeDragons for Show()/Hide() every frame, which
--              is what caused every border icon to flash visible while
--              moving.
local function CreateMinimapIconEntry()
    local anchor = CreateFrame("Frame", nil, Minimap)
    anchor:SetSize(1, 1)

    local visible = CreateFrame("Frame", nil, Minimap)
    visible:SetSize(7, 7)
    visible:SetFrameStrata("TOOLTIP")
    visible:Hide()

    visible.texture = visible:CreateTexture(nil, "ARTWORK")
    visible.texture:SetAllPoints()
    visible.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    visible.timeText = visible:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visible.timeText:SetPoint("TOP", visible, "BOTTOM", 0, -1)

    return { anchor = anchor, visible = visible }
end

local function AcquireMinimapIcon()
    local entry = table.remove(minimapIconPool)

    if not entry then
        entry = CreateMinimapIconEntry()
    end

    return entry
end

local function ReleaseMinimapIcon(entry)
    entry.visible:Hide()
    entry.anchor:ClearAllPoints()
    entry.visible:ClearAllPoints()
    entry.point = nil
    table.insert(minimapIconPool, entry)
end

local function UpdateMinimapIconAppearance(entry, point)
    if HerbTimerDB.showIcons then
        local icon = GetIconForItemID(point.itemID)
        entry.visible.texture:SetTexture(icon or DEFAULT_ICON)
        entry.visible.texture:Show()
    else
        entry.visible.texture:Hide()
    end

    entry.visible.timeText:SetText(point.time and FormatPointTime(point.time) or "")
end

function RebuildMinimapIcons()
    HBDPins:RemoveAllMinimapIcons(MINIMAP_REF)

    for _, entry in pairs(minimapIconsByPoint) do
        ReleaseMinimapIcon(entry)
    end
    wipe(minimapIconsByPoint)

    if not HerbTimerDB or not HerbTimerDB.points or not HerbTimerDB.showMinimap then
        return
    end

    for _, point in ipairs(GetVisiblePoints()) do
        local entry = AcquireMinimapIcon()
        entry.point = point
        UpdateMinimapIconAppearance(entry, point)

        -- floatOnEdge: nodes outside the minimap radius slide the anchor onto
        -- its border instead of hiding it, like GatherMate2's minimap markers.
        -- Controlled by /ht border.
        local added = HBDPins:AddMinimapIconMap(MINIMAP_REF, entry.anchor, point.mapID, point.x, point.y, false, HerbTimerDB.showBorder)

        if added then
            minimapIconsByPoint[point] = entry
        else
            ReleaseMinimapIcon(entry)
        end
    end
end

function RefreshMinimapIconAppearance()
    for point, entry in pairs(minimapIconsByPoint) do
        UpdateMinimapIconAppearance(entry, point)
    end
end

-- Mirrors each anchor's HereBeDragons-computed position onto our own visible
-- icon, and limits border ("floating") icons to at most one per screen-relative
-- side (top/bottom/left/right), keeping only the nearest node in each
-- direction. Icons that are genuinely within minimap range are shown as-is.
local function UpdateMinimapEdgeGrouping()
    local px, py, pInstance = HBD:GetPlayerWorldPosition()
    if not px then
        for _, entry in pairs(minimapIconsByPoint) do
            entry.visible:Hide()
        end
        return
    end

    local bucket = {}

    for point, entry in pairs(minimapIconsByPoint) do
        if not entry.anchor:IsShown() then
            entry.visible:Hide()
        else
            entry.visible:ClearAllPoints()
            entry.visible:SetPoint("CENTER", entry.anchor, "CENTER", 0, 0)

            local onEdge = HBDPins:IsMinimapIconOnEdge(entry.anchor)

            if onEdge then
                entry.visible:Hide() -- tentative; re-shown below if it wins its direction bucket

                local wx, wy, winstance = HBD:GetWorldCoordinatesFromZone(point.x, point.y, point.mapID)
                local distance

                if wx and winstance == pInstance then
                    distance = (HBD:GetWorldDistance(pInstance, px, py, wx, wy))
                end

                if distance then
                    local _, _, _, offsetX, offsetY = entry.anchor:GetPoint(1)
                    offsetX, offsetY = offsetX or 0, offsetY or 0

                    local direction
                    if math.abs(offsetY) >= math.abs(offsetX) then
                        direction = offsetY > 0 and "top" or "bottom"
                    else
                        direction = offsetX > 0 and "right" or "left"
                    end

                    local current = bucket[direction]
                    if not current or distance < current.distance then
                        bucket[direction] = { entry = entry, distance = distance }
                    end
                end
            else
                entry.visible:Show()
            end
        end
    end

    for _, winner in pairs(bucket) do
        winner.entry.visible:Show()
    end
end

C_Timer.NewTicker(0.2, UpdateMinimapEdgeGrouping)

--------------------------------------------------
-- OPTIONS PANEL
--------------------------------------------------

local optionsPanel = CreateFrame("Frame", "HerbTimerOptionsPanel", UIParent, "BackdropTemplate")
optionsPanel:SetSize(400, 410)
optionsPanel:SetPoint("CENTER")
optionsPanel:SetFrameStrata("DIALOG")
optionsPanel:SetMovable(true)
optionsPanel:EnableMouse(true)
optionsPanel:RegisterForDrag("LeftButton")
optionsPanel:SetScript("OnDragStart", optionsPanel.StartMoving)
optionsPanel:SetScript("OnDragStop", optionsPanel.StopMovingOrSizing)
optionsPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
optionsPanel:Hide()

local closeButton = CreateFrame("Button", nil, optionsPanel, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)

local panelTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", 16, -16)
panelTitle:SetText("HerbTimer")

local function CreatePanelCheckbox(label, anchorTo, yOffset)
    local cb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)

    local text = cb.Text or cb.text
    if text then
        text:SetText(label)
    end

    return cb
end

local showIconsCheckbox = CreatePanelCheckbox("Show item icons on map & minimap", panelTitle, -16)
local showMinimapCheckbox = CreatePanelCheckbox("Show on the minimap", showIconsCheckbox, -4)
local showBorderCheckbox = CreatePanelCheckbox("Show off-range points on the minimap border", showMinimapCheckbox, -4)

local maxPointsLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
maxPointsLabel:SetPoint("TOPLEFT", showBorderCheckbox, "BOTTOMLEFT", 2, -20)
maxPointsLabel:SetText("Max points shown per item")

local maxPointsBox = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
maxPointsBox:SetSize(30, 20)
maxPointsBox:SetAutoFocus(false)
maxPointsBox:SetNumeric(true)
maxPointsBox:SetMaxLetters(2)
maxPointsBox:SetPoint("LEFT", maxPointsLabel, "RIGHT", 14, 0)
maxPointsBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
maxPointsBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)
maxPointsBox:SetScript("OnEditFocusLost", function(self)
    local value = tonumber(self:GetText())

    if value and value >= 1 then
        HerbTimerDB.maxPointsPerItem = math.floor(value)
    end

    self:SetText(tostring(HerbTimerDB.maxPointsPerItem))

    if WorldMapFrame:IsShown() then
        WorldMapDataProvider:RefreshAllData()
    end

    if RebuildMinimapIcons then
        RebuildMinimapIcons()
    end
end)

local timeLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
timeLabel:SetPoint("TOPLEFT", maxPointsLabel, "BOTTOMLEFT", -2, -20)
timeLabel:SetText("Time display")

local clockCheckbox = CreatePanelCheckbox("Clock time (14:32)", timeLabel, -8)
local elapsedCheckbox = CreatePanelCheckbox("Time elapsed (5m ago)", clockCheckbox, -4)

local itemsLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
itemsLabel:SetPoint("TOPLEFT", elapsedCheckbox, "BOTTOMLEFT", 0, -20)
itemsLabel:SetText("Tracked items")

local ITEM_ROW_COUNT = 8
local itemRows = {}

for i = 1, ITEM_ROW_COUNT do
    local row = CreateFrame("Frame", nil, optionsPanel)
    row:SetSize(360, 20)

    if i == 1 then
        row:SetPoint("TOPLEFT", itemsLabel, "BOTTOMLEFT", 4, -8)
    else
        row:SetPoint("TOPLEFT", itemRows[i - 1], "BOTTOMLEFT", 0, -4)
    end

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 0, 0)

    row.removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.removeButton:SetSize(20, 20)
    row.removeButton:SetPoint("LEFT", row.text, "RIGHT", 8, 0)
    row.removeButton:SetText("X")
    row.removeButton:SetScript("OnClick", function()
        local itemID = row.itemID
        if not itemID then
            return
        end

        HerbTimerDB.trackedItems[itemID] = nil

        for j = #HerbTimerDB.points, 1, -1 do
            if HerbTimerDB.points[j].itemID == itemID then
                table.remove(HerbTimerDB.points, j)
            end
        end

        if WorldMapFrame:IsShown() then
            WorldMapDataProvider:RefreshAllData()
        end

        if RebuildMinimapIcons then
            RebuildMinimapIcons()
        end

        RefreshOptionsPanel()
    end)

    row:Hide()
    itemRows[i] = row
end

local addItemBox = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
addItemBox:SetSize(90, 20)
addItemBox:SetAutoFocus(false)
addItemBox:SetNumeric(true)
addItemBox:SetPoint("TOPLEFT", itemsLabel, "BOTTOMLEFT", 6, -12)

local addItemButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
addItemButton:SetSize(90, 22)
addItemButton:SetPoint("LEFT", addItemBox, "RIGHT", 8, 0)
addItemButton:SetText("Add item")
addItemButton:SetScript("OnClick", function()
    local itemID = tonumber(addItemBox:GetText())

    if not itemID then
        return
    end

    HerbTimerDB.trackedItems[itemID] = true
    addItemBox:SetText("")
    addItemBox:ClearFocus()

    RefreshOptionsPanel()
end)

addItemBox:SetScript("OnEnterPressed", function()
    addItemButton:Click()
end)

local clearButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
clearButton:SetSize(140, 22)
clearButton:SetPoint("TOPLEFT", addItemBox, "BOTTOMLEFT", -6, -20)
clearButton:SetText("Clear all points")
clearButton:SetScript("OnClick", function()
    if wipe then
        wipe(HerbTimerDB.points)
    else
        for i = #HerbTimerDB.points, 1, -1 do
            HerbTimerDB.points[i] = nil
        end
    end

    if WorldMapFrame:IsShown() then
        WorldMapDataProvider:RefreshAllData()
    end

    if RebuildMinimapIcons then
        RebuildMinimapIcons()
    end
end)

function RefreshOptionsPanel()
    showIconsCheckbox:SetChecked(HerbTimerDB.showIcons)
    showMinimapCheckbox:SetChecked(HerbTimerDB.showMinimap)
    showBorderCheckbox:SetChecked(HerbTimerDB.showBorder)
    clockCheckbox:SetChecked(HerbTimerDB.timeMode ~= "elapsed")
    elapsedCheckbox:SetChecked(HerbTimerDB.timeMode == "elapsed")

    if not maxPointsBox:HasFocus() then
        maxPointsBox:SetText(tostring(HerbTimerDB.maxPointsPerItem or 2))
    end

    local ids = {}
    for itemID in pairs(HerbTimerDB.trackedItems) do
        table.insert(ids, itemID)
    end
    table.sort(ids)

    local visibleCount = 0

    for i, row in ipairs(itemRows) do
        local itemID = ids[i]

        if itemID then
            visibleCount = visibleCount + 1
            row.itemID = itemID
            row.text:SetText(string.format("%s (%d)", GetItemDisplayName(itemID), itemID))
            row:Show()
        else
            row.itemID = nil
            row:Hide()
        end
    end

    -- Reposition the "Add item" row right under the last visible tracked-item
    -- row (or the label itself if none), instead of always reserving space
    -- for all 8 possible slots, and resize the window to fit.
    addItemBox:ClearAllPoints()
    if visibleCount > 0 then
        addItemBox:SetPoint("TOPLEFT", itemRows[visibleCount], "BOTTOMLEFT", 6, -12)
    else
        addItemBox:SetPoint("TOPLEFT", itemsLabel, "BOTTOMLEFT", 6, -12)
    end

    local baseHeight = 384 -- everything above the tracked-items rows, plus the add/clear controls and padding
    local rowHeight = 26
    optionsPanel:SetHeight(math.max(baseHeight + visibleCount * rowHeight, 380))
end

showIconsCheckbox:SetScript("OnClick", function(self)
    HerbTimerDB.showIcons = self:GetChecked() and true or false

    if WorldMapFrame:IsShown() then
        WorldMapDataProvider:RefreshAllData()
    end

    if RefreshMinimapIconAppearance then
        RefreshMinimapIconAppearance()
    end
end)

showMinimapCheckbox:SetScript("OnClick", function(self)
    HerbTimerDB.showMinimap = self:GetChecked() and true or false

    if RebuildMinimapIcons then
        RebuildMinimapIcons()
    end
end)

showBorderCheckbox:SetScript("OnClick", function(self)
    HerbTimerDB.showBorder = self:GetChecked() and true or false

    if RebuildMinimapIcons then
        RebuildMinimapIcons()
    end
end)

local function SetTimeMode(mode)
    HerbTimerDB.timeMode = mode
    RefreshOptionsPanel()

    if WorldMapFrame:IsShown() then
        WorldMapDataProvider:RefreshAllData()
    end

    if RefreshMinimapIconAppearance then
        RefreshMinimapIconAppearance()
    end

    UpdateElapsedTicker()
end

clockCheckbox:SetScript("OnClick", function() SetTimeMode("clock") end)
elapsedCheckbox:SetScript("OnClick", function() SetTimeMode("elapsed") end)

optionsPanel:SetScript("OnShow", RefreshOptionsPanel)

tinsert(UISpecialFrames, "HerbTimerOptionsPanel") -- lets Escape close the window too

--------------------------------------------------
-- BLIZZARD ADDONS LIST STUB PANEL
--------------------------------------------------

-- A minimal panel registered with Blizzard's Options > AddOns list, purely so
-- HerbTimer shows up there for people who go looking for settings in the
-- game's menu instead of reading the chat help. It doesn't hold any actual
-- settings itself (those live in our own /ht options window) -- it just
-- points people to that window, Leatrix Plus-style.
local stubPanel = CreateFrame("Frame", "HerbTimerStubPanel", UIParent)
stubPanel.name = "HerbTimer"

local stubTitle = stubPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
stubTitle:SetPoint("TOP", 0, -80)
stubTitle:SetText("HerbTimer")

local stubSubtitle = stubPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
stubSubtitle:SetPoint("TOP", stubTitle, "BOTTOM", 0, -10)
stubSubtitle:SetText("Herb Respawn Tracker")

local stubCommand = stubPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
stubCommand:SetPoint("TOP", stubSubtitle, "BOTTOM", 0, -60)
stubCommand:SetText("/ht")

local stubOpenButton = CreateFrame("Button", nil, stubPanel, "UIPanelButtonTemplate")
stubOpenButton:SetSize(160, 30)
stubOpenButton:SetPoint("TOP", stubCommand, "BOTTOM", 0, -20)
stubOpenButton:SetText("Open Settings")
stubOpenButton:SetScript("OnClick", function()
    if HerbTimerOptionsPanel then
        HerbTimerOptionsPanel:Show()
    end
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(stubPanel, "HerbTimer")
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(stubPanel)
end

print("|cff00ff00HerbTimer|r loaded!")
print("|cffaaaaaaType /ht for the command list.|r")
