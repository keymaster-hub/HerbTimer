local addonName, HT = ...

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
        local icon = HT.GetIconForItemID(point.itemID)
        entry.visible.texture:SetTexture(icon or HT.DEFAULT_ICON)
        entry.visible.texture:Show()
    else
        entry.visible.texture:Hide()
    end

    entry.visible.timeText:SetText(point.time and HT.FormatPointTime(point.time) or "")
end

function HT.RebuildMinimapIcons()
    HBDPins:RemoveAllMinimapIcons(MINIMAP_REF)

    for _, entry in pairs(minimapIconsByPoint) do
        ReleaseMinimapIcon(entry)
    end
    wipe(minimapIconsByPoint)

    if not HerbTimerDB or not HerbTimerDB.points or not HerbTimerDB.showMinimap then
        return
    end

    for _, point in ipairs(HT.GetVisiblePoints()) do
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

function HT.RefreshMinimapIconAppearance()
    for point, entry in pairs(minimapIconsByPoint) do
        UpdateMinimapIconAppearance(entry, point)
    end
end

-- Mirrors each anchor's HereBeDragons-computed position onto our own visible
-- icon, and limits border ("floating") icons to at most one per screen-relative
-- side (top/bottom/left/right), keeping only the nearest node in each
-- direction. Icons that are genuinely within minimap range are shown as-is.
local function UpdateMinimapEdgeGrouping()
    -- Nothing to do if the minimap display is off or there's simply nothing
    -- tracked right now -- skip the HBD position lookup and the loop below
    -- entirely rather than running it on a 0.2s cadence for no reason.
    if not HerbTimerDB or not HerbTimerDB.showMinimap or not next(minimapIconsByPoint) then
        return
    end

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
