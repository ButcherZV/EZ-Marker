-- ============================================================
-- EZ-Marker  -  Settings UI
-- TurtleWoW / WoW 1.12 compatible
--
-- Creates:
--   • A draggable minimap button (left-click = settings panel,
--     right-click = reset all marks)
--   • A moveable settings panel with arrow-button reordering
--     for the eight raid mark slots
-- ============================================================

-- ============================================================
-- Helper: assign a raid-target-marker texture to a Texture object.
-- Uses the Blizzard built-in SetRaidTargetIconTexture() when it
-- exists (same function the default UI uses on unit frames, works
-- regardless of texture pack / client variant).  Falls back to the
-- direct file path for non-standard environments.
-- ============================================================

local RAID_ICON_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

-- Apply a raid-target-marker icon to a Texture object.
-- IMPORTANT: SetRaidTargetIconTexture() only sets the SetTexCoord crop;
-- the texture file (sprite sheet) MUST be set via SetTexture() first.
-- Pattern confirmed from ShaguTweaks-extras\mods\raid.lua.
local function ApplyMarkIcon(tex, markIdx)
    tex:SetTexture(RAID_ICON_SHEET)
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(tex, markIdx)
    end
end

-- ============================================================
-- Minimap button
-- ============================================================

local minimapBtn = CreateFrame("Button", "EZMarkerMinimapButton", Minimap)
minimapBtn:SetWidth(31)
minimapBtn:SetHeight(31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)

-- Icon texture.  To change it, replace the path below with any
-- Interface\Icons\* texture, e.g. "Interface\\Icons\\INV_Misc_QuestionMark"
local btnIcon = minimapBtn:CreateTexture(nil, "BACKGROUND")
btnIcon:SetWidth(20)
btnIcon:SetHeight(20)
btnIcon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 1)
-- Icon set after PLAYER_LOGIN via ApplyMarkIcon (see loginFrame below)
-- Pre-load the sprite sheet so the texture object is ready.
btnIcon:SetTexture(RAID_ICON_SHEET)

-- Round border overlay (standard WoW minimap-button look)
local btnBorder = minimapBtn:CreateTexture(nil, "OVERLAY")
btnBorder:SetWidth(53)
btnBorder:SetHeight(53)
btnBorder:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)
btnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

minimapBtn:SetHighlightTexture(
    "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Position the button at the saved angle around the minimap edge
local function UpdateMinimapPos()
    if not EZMarkerDB then return end
    local angle = math.rad(EZMarkerDB.minimapAngle or 220)
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * 80,
        math.sin(angle) * 80)
end

-- Use RegisterForDrag + RegisterForClicks together (same as PowerPally).
-- WoW's engine separates a true drag (fires OnDragStart) from a quick
-- click (fires OnClick) — no manual "did I move?" flag needed.
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

minimapBtn:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local cx, cy = Minimap:GetCenter()
        local mx, my = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        EZMarkerDB.minimapAngle =
            math.deg(math.atan2(my / scale - cy, mx / scale - cx))
        UpdateMinimapPos()
    end)
end)

minimapBtn:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
end)

minimapBtn:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        EZMarker:ResetAllMarks()
    else
        -- Left click: toggle settings panel
        if EZMarkerFrame:IsShown() then
            EZMarkerFrame:Hide()
        else
            EZMarkerFrame:Show()
        end
    end
end)

minimapBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("EZ-Marker", 1, 0.53, 0)
    GameTooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Left-drag: Move button",    0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Reset tracking", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ============================================================
-- Settings panel
-- ============================================================

local ICON_SIZE  = 28
local ICON_GAP   = 4
local NUM_MARKS  = 8
local PANEL_W    = 290
local STRIP_W    = NUM_MARKS * ICON_SIZE + (NUM_MARKS - 1) * ICON_GAP  -- 252
-- Centre the strip inside the panel (backdrop insets: left=11, right=12)
local STRIP_LEFT = 11 + math.floor(((PANEL_W - 23) - STRIP_W) / 2)    -- 18
local ICONS_Y    = -62   -- from panel TOP to top of icon row

local panel = CreateFrame("Frame", "EZMarkerFrame", UIParent)
panel:SetWidth(PANEL_W)
panel:SetHeight(242)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    tileSize = 32,
    edgeSize = 32,
    insets   = {left = 11, right = 12, top = 12, bottom = 11},
})
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetToplevel(true)
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
panel:Hide()

-- Title
local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOP", 0, -14)
titleText:SetText("EZ-Marker")

-- Sub-title instructions
local hintText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hintText:SetPoint("TOP", 0, -33)
hintText:SetTextColor(0.75, 0.75, 0.75)
hintText:SetText("Order of applied marks (drag to reorder)")

-- Close button (X)
local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)

-- Separator under header
local sep1 = panel:CreateTexture(nil, "ARTWORK")
sep1:SetHeight(1)
sep1:SetPoint("TOPLEFT",  15, -48)
sep1:SetPoint("TOPRIGHT", -15, -48)
sep1:SetTexture(0.35, 0.35, 0.35, 1)

-- ============================================================
-- Drag-to-reorder state
-- ============================================================

local dragSrcPos = nil   -- slot index (1-8) being dragged, or nil
local slots      = {}    -- the 8 icon slot frames

-- Ghost icon: follows the cursor while dragging so the user
-- can see what they are carrying.
local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetWidth(ICON_SIZE + 6)
ghost:SetHeight(ICON_SIZE + 6)
ghost:SetFrameStrata("TOOLTIP")
ghost:SetAlpha(0.80)
ghost:EnableMouse(false)   -- let clicks pass through to slots below
ghost:Hide()
local ghostTex = ghost:CreateTexture(nil, "ARTWORK")
ghostTex:SetAllPoints()
ghostTex:SetTexture(RAID_ICON_SHEET)   -- sprite sheet pre-loaded; ApplyMarkIcon sets the crop
ghost.tex = ghostTex

local function CancelDrag()
    dragSrcPos = nil
    ghost:SetScript("OnUpdate", nil)
    ghost:Hide()
    for _, s in ipairs(slots) do
        if s.srcHL then s.srcHL:Hide() end
    end
end

local function CommitDrop(destPos)
    if dragSrcPos and destPos and dragSrcPos ~= destPos then
        local order = EZMarkerDB.markOrder
        order[dragSrcPos], order[destPos] = order[destPos], order[dragSrcPos]
    end
    CancelDrag()
    EZMarkerFrame:RefreshDisplay()
end

-- Return which slot (1-8) the cursor is currently hovering over, or nil.
-- Used inside OnMouseUp because WoW fires that on the source frame, not
-- the frame currently under the cursor.
local function SlotUnderCursor()
    local mx, my  = GetCursorPosition()
    local scale   = UIParent:GetEffectiveScale()
    local ux, uy  = mx / scale, my / scale
    local half    = ICON_SIZE / 2
    for j, s in ipairs(slots) do
        local sx, sy = s:GetCenter()
        if sx and sy and
           ux >= sx - half and ux <= sx + half and
           uy >= sy - half and uy <= sy + half then
            return j
        end
    end
    return nil
end

-- ============================================================
-- Icon strip
-- ============================================================

local function MakeSlot(pos)
    local xOff = STRIP_LEFT + (pos - 1) * (ICON_SIZE + ICON_GAP)

    local slot = CreateFrame("Frame", nil, panel)
    slot:SetWidth(ICON_SIZE)
    slot:SetHeight(ICON_SIZE)
    slot:SetPoint("TOPLEFT", xOff, ICONS_Y)
    slot:EnableMouse(true)
    slot.slotPos = pos

    -- Marker icon
    local iconTex = slot:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexture(RAID_ICON_SHEET)   -- sprite sheet; ApplyMarkIcon sets the crop per icon
    slot.iconTex = iconTex

    -- Red tint: shown when this mark is currently assigned to an enemy
    local inUseTex = slot:CreateTexture(nil, "OVERLAY")
    inUseTex:SetAllPoints()
    inUseTex:SetTexture(1, 0, 0, 0.38)
    inUseTex:Hide()
    slot.inUseTex = inUseTex

    -- Yellow tint: shown on the slot being dragged FROM
    local srcHL = slot:CreateTexture(nil, "OVERLAY")
    srcHL:SetAllPoints()
    srcHL:SetTexture(1, 1, 0, 0.45)
    srcHL:Hide()
    slot.srcHL = srcHL

    -- Built-in highlight on cursor hover
    local hl = slot:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

    -- Priority number below icon (parented to panel so it isn't clipped
    -- by the slot frame boundary)
    local numLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numLabel:SetWidth(ICON_SIZE)
    numLabel:SetPoint("TOP", slot, "BOTTOM", 0, -2)
    numLabel:SetJustifyH("CENTER")
    numLabel:SetTextColor(0.65, 0.65, 0.65)
    slot.numLabel = numLabel

    -- ----------------------------------------------------------
    -- Mouse events
    -- ----------------------------------------------------------

    slot:SetScript("OnMouseDown", function()
        if arg1 ~= "LeftButton" then return end
        dragSrcPos = this.slotPos
        this.srcHL:Show()
        -- Load ghost texture and start tracking cursor
        local markIdx = EZMarkerDB.markOrder[dragSrcPos]
        ApplyMarkIcon(ghostTex, markIdx)
        ghost:Show()
        ghost:SetScript("OnUpdate", function()
            local mx, my = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            ghost:ClearAllPoints()
            ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                mx / scale, my / scale)
        end)
    end)

    -- WoW fires OnMouseUp on the frame that captured OnMouseDown (the source
    -- slot), not on whatever is under the cursor at release time.  We therefore
    -- compute the drop target ourselves from the current cursor position.
    slot:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and dragSrcPos then
            CommitDrop(SlotUnderCursor())   -- nil = dropped outside → cancel
        end
    end)

    slot:SetScript("OnEnter", function()
        if not (EZMarkerDB and EZMarkerDB.markOrder) then return end
        local markIdx = EZMarkerDB.markOrder[this.slotPos]
        local used    = EZMarker:GetUsedMarks()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        if dragSrcPos and dragSrcPos ~= this.slotPos then
            GameTooltip:SetText(
                "Release to swap with " ..
                (EZMarker.MARK_NAMES[markIdx] or "?"), 1, 1, 0)
        else
            GameTooltip:SetText(
                "Priority #" .. this.slotPos .. ":  " ..
                (EZMarker.MARK_NAMES[markIdx] or "?"), 1, 1, 1)
            if used[markIdx] then
                GameTooltip:AddLine("In use: " .. used[markIdx], 1, 0.4, 0.4)
            else
                GameTooltip:AddLine("Available", 0.4, 1, 0.4)
            end
        end
        GameTooltip:Show()
    end)

    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return slot
end

for i = 1, NUM_MARKS do
    slots[i] = MakeSlot(i)
end

-- ============================================================
-- Below-strip layout
-- Y positions are relative to panel TOP (negative = downward)
-- ============================================================

-- icons bottom: ICONS_Y - ICON_SIZE = -90
-- numLabels bottom: ~-90 - 2 - 14 = -106
local BELOW_Y = ICONS_Y - ICON_SIZE - 26   -- -116, just below the num labels

local sep2 = panel:CreateTexture(nil, "ARTWORK")
sep2:SetHeight(1)
sep2:SetPoint("TOPLEFT",  15, BELOW_Y)
sep2:SetPoint("TOPRIGHT", -15, BELOW_Y)
sep2:SetTexture(0.35, 0.35, 0.35, 1)

-- Keybind hint (two lines)
local kbTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
kbTitle:SetPoint("TOPLEFT",  18, BELOW_Y - 7)
kbTitle:SetPoint("TOPRIGHT", -18, BELOW_Y - 7)
kbTitle:SetHeight(28)
kbTitle:SetJustifyH("CENTER")
kbTitle:SetTextColor(1, 0.82, 0)
kbTitle:SetText("Keybindings for Applying/Removing marks are in Key Bindings  >  EZ-Marker")

local kbSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
kbSub:SetPoint("TOPLEFT",  18, BELOW_Y - 43)
kbSub:SetPoint("TOPRIGHT", -18, BELOW_Y - 43)
kbSub:SetHeight(28)
kbSub:SetJustifyH("CENTER")
kbSub:SetTextColor(0.75, 0.75, 0.75)
kbSub:SetText("https://github.com/ButcherZV/EZ-Marker")

-- Separator above bottom buttons  (BELOW_Y - 76)
local sep3 = panel:CreateTexture(nil, "ARTWORK")
sep3:SetHeight(1)
sep3:SetPoint("TOPLEFT",  15, BELOW_Y - 76)
sep3:SetPoint("TOPRIGHT", -15, BELOW_Y - 76)
sep3:SetTexture(0.35, 0.35, 0.35, 1)

-- "Reset All Marks"
local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetWidth(130)
resetBtn:SetHeight(22)
resetBtn:SetPoint("BOTTOMLEFT", 15, 14)
resetBtn:SetText("Reset Tracking")
resetBtn:SetScript("OnClick", function()
    EZMarker:ResetAllMarks()
end)

-- "Default Order"
local defaultBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
defaultBtn:SetWidth(110)
defaultBtn:SetHeight(22)
defaultBtn:SetPoint("BOTTOMRIGHT", -15, 14)
defaultBtn:SetText("Default Order")
defaultBtn:SetScript("OnClick", function()
    EZMarkerDB.markOrder = {8, 7, 6, 5, 4, 3, 2, 1}
    EZMarkerFrame:RefreshDisplay()
end)

-- ============================================================
-- RefreshDisplay: sync icons and number labels to current state
-- ============================================================

function EZMarkerFrame:RefreshDisplay()
    if not EZMarkerDB or not EZMarkerDB.markOrder then return end
    local order     = EZMarkerDB.markOrder
    local usedMarks = EZMarker:GetUsedMarks()
    for i = 1, NUM_MARKS do
        local markIdx  = order[i]
        local occupant = usedMarks[markIdx]
        ApplyMarkIcon(slots[i].iconTex, markIdx)
        slots[i].numLabel:SetText(tostring(i))
        if occupant then
            slots[i].inUseTex:Show()
        else
            slots[i].inUseTex:Hide()
        end
    end
end

panel:SetScript("OnShow", function()
    this:RefreshDisplay()
end)

-- Keep the panel live while open (enemy dies, mark freed, etc.)
local uiEventFrame = CreateFrame("Frame")
uiEventFrame:RegisterEvent("RAID_TARGET_UPDATE")
uiEventFrame:SetScript("OnEvent", function()
    if EZMarkerFrame:IsShown() then
        EZMarkerFrame:RefreshDisplay()
    end
end)

-- ============================================================
-- Post-login: position minimap button once DB is ready
-- ============================================================

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    UpdateMinimapPos()
    -- Set minimap button to skull icon (mark #8) using the same
    -- helper that drives the settings panel icons.
    ApplyMarkIcon(btnIcon, 8)
end)

