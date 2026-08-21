local addonName, HT = ...

--------------------------------------------------
-- WORLD MAP
--------------------------------------------------

HT.WorldMapDataProvider = CreateFromMixins(MapCanvasDataProviderMixin)
local WorldMapDataProvider = HT.WorldMapDataProvider

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

    for _, point in ipairs(HT.GetVisiblePoints()) do
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

-- Must stay a real global: HerbTimer.xml references it by name via
-- mixin="HerbTimerWorldMapPinMixin" when the virtual pin template is
-- instantiated.
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

function HerbTimerWorldMapPinMixin:OnAcquired(point)
    self.point = point

    self:SetPosition(point.x, point.y)

    if HerbTimerDB.showIcons then
        local icon = HT.GetIconForItemID(point.itemID)
        self.texture:SetTexture(icon or HT.DEFAULT_ICON)
        self.texture:SetVertexColor(1, 1, 1, 1)
        self.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        self.texture:Show()
    else
        self.texture:Hide()
    end

    self.timeText:SetText(point.time and HT.FormatPointTime(point.time) or "")

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

    HT.UpdateElapsedTicker()
end)

WorldMapFrame:HookScript("OnHide", function()
    HT.UpdateElapsedTicker()
end)
