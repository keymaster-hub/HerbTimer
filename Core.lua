local addonName, HT = ...

--------------------------------------------------
-- SAVED VARIABLES
--------------------------------------------------

local DEFAULT_TRACKED_ITEMS = {
    [22792] = true, -- Nightmare Vine
}

HT.ITEM_NAMES = {
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

    if HerbTimerDB.maxStoredPointsPerItem == nil then
        HerbTimerDB.maxStoredPointsPerItem = 10
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
    HT.BumpPointsVersion()

    if HT.RebuildMinimapIcons then
        HT.RebuildMinimapIcons()
    end

    if HT.UpdateElapsedTicker then
        HT.UpdateElapsedTicker()
    end

    self:UnregisterEvent("ADDON_LOADED")
end)

--------------------------------------------------
-- LOOT TRACKING
--------------------------------------------------

local POINT_DISTANCE = 0.01

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

-- Keeps HerbTimerDB.points from growing forever: once an item has more than
-- HerbTimerDB.maxStoredPointsPerItem saved points, the oldest ones beyond the
-- cap are dropped. This is independent of (and normally larger than)
-- HerbTimerDB.maxPointsPerItem, which only limits what's *displayed*.
-- Configurable in the settings window (default: 10).
function HT.EnforcePointCap(itemID)
    local cap = HerbTimerDB.maxStoredPointsPerItem or 10
    local indices = {}

    for i, point in ipairs(HerbTimerDB.points) do
        if point.itemID == itemID then
            table.insert(indices, i)
        end
    end

    if #indices <= cap then
        return
    end

    table.sort(indices, function(a, b)
        return (HerbTimerDB.points[a].time or 0) < (HerbTimerDB.points[b].time or 0)
    end)

    -- Remove the oldest entries beyond the cap. Removing from the array in
    -- descending index order keeps the remaining indices valid mid-loop.
    local toRemove = #indices - cap
    local removeIndices = {}
    for i = 1, toRemove do
        table.insert(removeIndices, indices[i])
    end
    table.sort(removeIndices, function(a, b) return a > b end)

    for _, idx in ipairs(removeIndices) do
        table.remove(HerbTimerDB.points, idx)
    end
end

-- Re-applies the cap to every item currently in the database. Used when the
-- max-stored setting is lowered in the options window, so existing excess
-- points are trimmed immediately instead of waiting for the next loot.
function HT.EnforceAllStoredPointCaps()
    local itemIDs = {}

    for _, point in ipairs(HerbTimerDB.points) do
        itemIDs[point.itemID] = true
    end

    for itemID in pairs(itemIDs) do
        HT.EnforcePointCap(itemID)
    end

    HT.BumpPointsVersion()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_LOOT")
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
        HT.EnforcePointCap(itemID)
    end

    HT.BumpPointsVersion()

    if HT.RebuildMinimapIcons then
        HT.RebuildMinimapIcons()
    end
end)

--------------------------------------------------
-- SHARED HELPERS
--------------------------------------------------

function HT.FormatPointTime(pointTime)
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
--
-- The result is cached and reused until the underlying points change (tracked
-- via HT.BumpPointsVersion) or maxPointsPerItem changes, since both the world
-- map and minimap recompute this on most of the same trigger points (loot,
-- add/remove/clear, settings toggles) and would otherwise redo the same
-- sort/filter work twice back-to-back.
local pointsVersion = 0
local visiblePointsCache
local visiblePointsCacheKey

function HT.BumpPointsVersion()
    pointsVersion = pointsVersion + 1
end

function HT.GetVisiblePoints()
    local cacheKey = pointsVersion .. ":" .. tostring(HerbTimerDB.maxPointsPerItem)

    if visiblePointsCache and visiblePointsCacheKey == cacheKey then
        return visiblePointsCache
    end

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

    visiblePointsCache = visible
    visiblePointsCacheKey = cacheKey

    return visible
end

function HT.GetItemDisplayName(itemID)
    local name = HT.ITEM_NAMES[itemID]

    if name then
        return name
    end

    local infoName = GetItemInfo(itemID)
    return infoName or ("item " .. itemID)
end

HT.DEFAULT_ICON = "Interface\\ICONS\\INV_Misc_QuestionMark"

function HT.GetIconForItemID(itemID)
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

-- Refreshes the "Xm"/"Xh Xm" elapsed-time text on both the world map (when
-- shown) and the minimap, on a short repeating timer -- but only while
-- elapsed-time display is actually turned on, since clock-time display is
-- static and never needs re-rendering on its own.
local elapsedTicker

function HT.UpdateElapsedTicker()
    local shouldRun = HerbTimerDB.timeMode == "elapsed"

    if shouldRun and not elapsedTicker then
        elapsedTicker = C_Timer.NewTicker(5, function()
            if WorldMapFrame:IsShown() and HT.WorldMapDataProvider then
                HT.WorldMapDataProvider:RefreshAllData()
            end

            if HT.RefreshMinimapIconAppearance then
                HT.RefreshMinimapIconAppearance()
            end
        end)
    elseif not shouldRun and elapsedTicker then
        elapsedTicker:Cancel()
        elapsedTicker = nil
    end
end
