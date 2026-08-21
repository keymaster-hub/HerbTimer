local addonName, HT = ...

local function PrintTrackedItems()
    print("|cff00ff00HerbTimer tracked items:|r")

    local any = false
    for itemID in pairs(HerbTimerDB.trackedItems) do
        any = true
        print(string.format("  |cffaaaaaa%d|r — %s", itemID, HT.GetItemDisplayName(itemID)))
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
            HT.FormatPointTime(point.time)
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

        HT.BumpPointsVersion()

        if WorldMapFrame:IsShown() then
            HT.WorldMapDataProvider:RefreshAllData()
        end

        if HT.RebuildMinimapIcons then
            HT.RebuildMinimapIcons()
        end

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
        end

        print("|cffffcc00HerbTimer:|r Database cleared.")
    elseif command == "add" then
        local itemID = tonumber(rest)

        if not itemID then
            print("|cffff0000HerbTimer:|r Usage: /ht add <itemID>")
            return
        end

        HerbTimerDB.trackedItems[itemID] = true
        print(string.format("|cff00ff00HerbTimer:|r Now tracking %s (id: %d).", HT.GetItemDisplayName(itemID), itemID))

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
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

        HT.BumpPointsVersion()

        if WorldMapFrame:IsShown() then
            HT.WorldMapDataProvider:RefreshAllData()
        end

        if HT.RebuildMinimapIcons then
            HT.RebuildMinimapIcons()
        end

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
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
            HT.WorldMapDataProvider:RefreshAllData()
        end

        if HT.RefreshMinimapIconAppearance then
            HT.RefreshMinimapIconAppearance()
        end

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
        end
    elseif command == "time" then
        HerbTimerDB.timeMode = (HerbTimerDB.timeMode == "elapsed") and "clock" or "elapsed"

        print(string.format(
            "|cff00ff00HerbTimer:|r Time display set to %s.",
            HerbTimerDB.timeMode == "elapsed" and "elapsed (e.g. \"5m ago\")" or "clock (e.g. \"14:32\")"
        ))

        if WorldMapFrame:IsShown() then
            HT.WorldMapDataProvider:RefreshAllData()
        end

        if HT.RefreshMinimapIconAppearance then
            HT.RefreshMinimapIconAppearance()
        end

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
        end

        HT.UpdateElapsedTicker()
    elseif command == "minimap" then
        HerbTimerDB.showMinimap = not HerbTimerDB.showMinimap

        print(string.format(
            "|cff00ff00HerbTimer:|r Minimap icons %s.",
            HerbTimerDB.showMinimap and "enabled" or "disabled"
        ))

        if HT.RebuildMinimapIcons then
            HT.RebuildMinimapIcons()
        end

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
        end
    elseif command == "border" then
        HerbTimerDB.showBorder = not HerbTimerDB.showBorder

        print(string.format(
            "|cff00ff00HerbTimer:|r Off-range border markers %s.",
            HerbTimerDB.showBorder and "enabled" or "disabled (out-of-range points are just hidden)"
        ))

        if HT.RebuildMinimapIcons then
            HT.RebuildMinimapIcons()
        end

        if HT.RefreshOptionsPanel then
            HT.RefreshOptionsPanel()
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
