-- ============================================================
-- EZ-Marker  -  Core Logic
-- TurtleWoW / WoW 1.12 compatible
--
-- Tracks which raid marks are in use, frees them when their
-- target dies, and always applies the highest-priority free
-- mark when the hotkey is pressed.
--
-- NOTE: SetRaidTarget requires raid leader / assistant rank
--       in a raid group.  In a 5-man party any member can mark.
-- ============================================================

EZMarker         = {}
EZMarker.VERSION = "1.0"

-- Raid target icon names (index 1-8 matches WoW numbering)
EZMarker.MARK_NAMES = {
    [1] = "Star",
    [2] = "Circle",
    [3] = "Diamond",
    [4] = "Triangle",
    [5] = "Moon",
    [6] = "Square",
    [7] = "Cross",
    [8] = "Skull",
}

-- Default kill-priority order:  Skull -> Cross -> Square -> Moon
--                                     -> Triangle -> Diamond -> Circle -> Star
local DEFAULT_ORDER = {8, 7, 6, 5, 4, 3, 2, 1}

-- Runtime: markIndex (1-8) => unitName string
-- Intentionally NOT saved – always starts clean each session.
local usedMarks = {}

-- ============================================================
-- Unit token scan list used when reconciling mark state.
-- Covers the player's target/mouseover plus all party/raid
-- members and their current targets.
-- ============================================================
local SCAN_TOKENS = {}
do
    table.insert(SCAN_TOKENS, "target")
    table.insert(SCAN_TOKENS, "mouseover")
    for i = 1, 4 do
        table.insert(SCAN_TOKENS, "party" .. i)
        table.insert(SCAN_TOKENS, "party" .. i .. "target")
    end
    for i = 1, 40 do
        table.insert(SCAN_TOKENS, "raid" .. i)
        table.insert(SCAN_TOKENS, "raid" .. i .. "target")
    end
end

-- ============================================================
-- Internal helpers
-- ============================================================

-- Scan every accessible unit token; free any tracked slot whose mark
-- index is held by a dead unit.  Index-based, so same-name enemies
-- are handled correctly.
local function FreeDead()
    for _, token in ipairs(SCAN_TOKENS) do
        if UnitExists(token) and UnitIsDead(token) then
            local idx = GetRaidTargetIndex(token)
            if idx and idx ~= 0 and usedMarks[idx] then
                usedMarks[idx] = nil
            end
        end
    end
end

-- Walk the configured priority order and return the first index
-- not currently tracked in usedMarks.
local function GetNextAvailableMark()
    for _, idx in ipairs(EZMarkerDB.markOrder) do
        if not usedMarks[idx] then
            return idx
        end
    end
    return nil
end

-- Return the display priority position (1-8) for a mark index.
local function GetOrderPosition(markIdx)
    for pos, idx in ipairs(EZMarkerDB.markOrder) do
        if idx == markIdx then
            return pos
        end
    end
    return "?"
end

local function Print(msg)
    local text = "|cffFF8800EZ-Marker:|r " .. tostring(msg)
    for i = 1, 7 do
        local frame = getglobal("ChatFrame" .. i)
        if frame and frame:IsVisible() then
            frame:AddMessage(text)
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

-- Press the hotkey -> apply the next free mark to the current
-- hostile target.
function EZMarker:MarkNextTarget()
    -- --------------------------------------------------------
    -- Role / group check
    -- Must be in a party or raid AND be the group leader.
    -- In a raid, assistants are also permitted (WoW standard).
    -- Solo players cannot mark.
    -- --------------------------------------------------------
    local inParty = GetNumPartyMembers and GetNumPartyMembers() > 0
    local inRaid  = GetNumRaidMembers  and GetNumRaidMembers()  > 0

    if not inParty and not inRaid then
        Print("|cffFF4444Cannot mark:|r You must be in a |cffFFFF00party or raid|r to apply marks.")
        return
    end

    -- IsPartyLeader() is the correct 1.12 API; UnitIsGroupLeader was added later
    local isLeader  = (IsPartyLeader and IsPartyLeader()) or
                      (UnitIsGroupLeader and UnitIsGroupLeader("player"))
    local isOfficer = inRaid and IsRaidOfficer and IsRaidOfficer()
    if not isLeader and not isOfficer then
        Print("|cffFF4444Cannot mark:|r Only the |cffFFFF00party/raid leader|r" ..
              (inRaid and " or |cffFFFF00Raid Assistant|r" or "") ..
              " can apply marks.")
        return
    end

    if not UnitExists("target") then
        Print("No target selected.")
        return
    end
    if not UnitCanAttack("player", "target") then
        Print("Target is not attackable.")
        return
    end
    if UnitIsDead("target") then
        Print("Target is already dead.")
        return
    end

    -- Skip if any mark is already on this target
    local existing = GetRaidTargetIndex("target")
    if existing and existing ~= 0 then
        Print("Target already has a mark.")
        return
    end

    local markIdx = GetNextAvailableMark()
    if not markIdx then
        Print("All 8 marks are in use!  Kill a marked target or use |cffFFFF00/ezm reset|r.")
        return
    end

    local targetName = UnitName("target")
    SetRaidTarget("target", markIdx)
    usedMarks[markIdx] = targetName

    Print("Marked " .. targetName .. " with " ..
          EZMarker.MARK_NAMES[markIdx] ..
          " (priority #" .. tostring(GetOrderPosition(markIdx)) .. ").")
end

-- Clear every mark that this addon is tracking and attempt to
-- remove their in-world icons.
-- Wipe the addon's internal mark tracking so it starts assigning
-- from priority #1 again on the next hotkey press.
-- Does NOT touch the visual icons already on enemies.
function EZMarker:ResetAllMarks()
    usedMarks = {}
    Print("Mark tracking reset — counting starts from #1 again.")
end

-- Remove the raid mark from the currently targeted enemy and free
-- that slot so it can be reused immediately.
function EZMarker:RemoveCurrentMark()
    if not UnitExists("target") then
        Print("No target selected.")
        return
    end
    local markIdx = GetRaidTargetIndex("target")
    if not markIdx or markIdx == 0 then
        Print("Target has no mark.")
        return
    end
    local targetName = UnitName("target")
    SetRaidTarget("target", 0)
    usedMarks[markIdx] = nil
    Print("Removed mark from " .. tostring(targetName) .. ".")
end

-- Read-only accessor for the UI module.
function EZMarker:GetUsedMarks()
    return usedMarks
end

-- ============================================================
-- Saved-variable initialisation
-- ============================================================

local function IsValidMarkOrder(order)
    if type(order) ~= "table" then return false end
    if table.getn(order) ~= 8  then return false end
    local seen = {}
    for i = 1, 8 do
        local v = order[i]
        if type(v) ~= "number" or v < 1 or v > 8 or seen[v] then
            return false
        end
        seen[v] = true
    end
    return true
end

local function InitDB()
    if type(EZMarkerDB) ~= "table" then
        EZMarkerDB = {}
    end
    if not IsValidMarkOrder(EZMarkerDB.markOrder) then
        EZMarkerDB.markOrder = {}
        for i = 1, table.getn(DEFAULT_ORDER) do
            EZMarkerDB.markOrder[i] = DEFAULT_ORDER[i]
        end
    end
    if type(EZMarkerDB.minimapAngle) ~= "number" then
        EZMarkerDB.minimapAngle = 220
    end
end

-- ============================================================
-- Event handling
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_DIED")
eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function()

    if event == "PLAYER_LOGIN" then
        InitDB()
        Print("v" .. EZMarker.VERSION ..
              " loaded.  Bind a key under |cffFFFF00Key Bindings > EZ-Marker|r." ..
              "  Type |cffFFFF00/ezm|r for settings.")

    elseif event == "UNIT_DIED"
        or event == "RAID_TARGET_UPDATE"
        or event == "PLAYER_TARGET_CHANGED" then
        -- All three events are opportunities to catch a marked
        -- enemy dying.  UNIT_DIED may not fire for all mob types
        -- in this client, so RAID_TARGET_UPDATE and target-change
        -- act as fallbacks.
        FreeDead()
    end
end)

-- ============================================================
-- Periodic death check (catch-all)
-- ============================================================
-- Scans once per second in case none of the events above fired
-- at the right moment (e.g. mob died while not targeted by anyone).

local deadCheckElapsed = 0
local deadCheckFrame = CreateFrame("Frame")
deadCheckFrame:SetScript("OnUpdate", function()
    deadCheckElapsed = deadCheckElapsed + arg1
    if deadCheckElapsed < 1.0 then return end
    deadCheckElapsed = 0
    FreeDead()
end)

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_EZMARKER1 = "/ezmarker"
SLASH_EZMARKER2 = "/ezm"
SlashCmdList["EZMARKER"] = function(msg)
    local cmd = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
    if cmd == "reset" then
        EZMarker:ResetAllMarks()
    elseif cmd == "help" then
        Print("Commands:")
        Print("  |cffFFFF00/ezm|r          - Toggle settings window")
        Print("  |cffFFFF00/ezm reset|r    - Clear all tracked marks")
        Print("  |cffFFFF00/ezm help|r     - This message")
        Print("Bind the marking key under Key Bindings > EZ-Marker.")
    else
        -- Toggle the config UI (defined in EZ-Marker_UI.lua)
        if EZMarkerFrame then
            if EZMarkerFrame:IsShown() then
                EZMarkerFrame:Hide()
            else
                EZMarkerFrame:Show()
            end
        end
    end
end

-- ============================================================
-- Keybinding display text
--
-- Bindings.xml registers the actual binding entry.
-- These globals provide the localised strings shown in the
-- Key Bindings UI (Esc > Key Bindings > scroll to "EZ-Marker").
-- ============================================================

BINDING_HEADER_EZMARKER       = "EZ-Marker"
BINDING_NAME_EZMARKERMARK     = "Mark Target"
BINDING_NAME_EZMARKERREMOVE   = "Remove Mark (current target)"
