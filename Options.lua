local addonName, HT = ...

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
        HT.WorldMapDataProvider:RefreshAllData()
    end

    if HT.RebuildMinimapIcons then
        HT.RebuildMinimapIcons()
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

        HT.BumpPointsVersion()

        if WorldMapFrame:IsShown() then
            HT.WorldMapDataProvider:RefreshAllData()
        end

        if HT.RebuildMinimapIcons then
            HT.RebuildMinimapIcons()
        end

        HT.RefreshOptionsPanel()
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

    HT.RefreshOptionsPanel()
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

    HT.BumpPointsVersion()

    if WorldMapFrame:IsShown() then
        HT.WorldMapDataProvider:RefreshAllData()
    end

    if HT.RebuildMinimapIcons then
        HT.RebuildMinimapIcons()
    end
end)

function HT.RefreshOptionsPanel()
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
            row.text:SetText(string.format("%s (%d)", HT.GetItemDisplayName(itemID), itemID))
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
        HT.WorldMapDataProvider:RefreshAllData()
    end

    if HT.RefreshMinimapIconAppearance then
        HT.RefreshMinimapIconAppearance()
    end
end)

showMinimapCheckbox:SetScript("OnClick", function(self)
    HerbTimerDB.showMinimap = self:GetChecked() and true or false

    if HT.RebuildMinimapIcons then
        HT.RebuildMinimapIcons()
    end
end)

showBorderCheckbox:SetScript("OnClick", function(self)
    HerbTimerDB.showBorder = self:GetChecked() and true or false

    if HT.RebuildMinimapIcons then
        HT.RebuildMinimapIcons()
    end
end)

local function SetTimeMode(mode)
    HerbTimerDB.timeMode = mode
    HT.RefreshOptionsPanel()

    if WorldMapFrame:IsShown() then
        HT.WorldMapDataProvider:RefreshAllData()
    end

    if HT.RefreshMinimapIconAppearance then
        HT.RefreshMinimapIconAppearance()
    end

    HT.UpdateElapsedTicker()
end

clockCheckbox:SetScript("OnClick", function() SetTimeMode("clock") end)
elapsedCheckbox:SetScript("OnClick", function() SetTimeMode("elapsed") end)

optionsPanel:SetScript("OnShow", HT.RefreshOptionsPanel)

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
