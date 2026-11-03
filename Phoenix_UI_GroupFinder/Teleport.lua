local _, ns = ...
local L = ns.L
local W, Secret = ns.Widgets, ns.Secret
local M = ns:GetModule("GroupFinder")

--[[ Teleport prompt (EllesmereUI reference: QoL teleport prompt). When you join a premade group for a dungeon whose
    teleport you know, a small Phoenix popup offers it: one secure spell button with the spell's own icon and
    cooldown. Nothing is shipped as data: the teleports are the known spells in your spellbook's flyouts, and a
    teleport belongs to a dungeon when its description names the dungeon (GetRealZoneText of the activity's
    map, so it works in every client language). The button is set up out of combat only and every cast is your
    click. It closes on its own after a minute, when you zone in, or when you leave the group. ]]

local OWNER = {} -- the module's own PLAYER_REGEN_ENABLED handler belongs to Helpers.lua
local TIMEOUT = 60
local popup, pending

-- Every known flyout spell: { id, name, desc } (descriptions are plain spell text).
function M.KnownFlyoutSpells()
    local out = {}
    if type(GetNumFlyouts) ~= "function" then return out end
    for i = 1, GetNumFlyouts() or 0 do
        local flyoutID = GetFlyoutID(i)
        local _, _, numSlots, known = GetFlyoutInfo(flyoutID)
        if known and type(numSlots) == "number" then
            for slot = 1, numSlots do
                local spellID, _, slotKnown, name = GetFlyoutSlotInfo(flyoutID, slot)
                if slotKnown and type(spellID) == "number" then
                    local desc = C_Spell.GetSpellDescription(spellID)
                    out[#out + 1] = { id = spellID, name = name, desc = type(desc) == "string" and desc or "" }
                end
            end
        end
    end
    return out
end

-- The teleport whose description names `place` (plain find, case-insensitive), or nil.
function M.TeleportFor(place, spells)
    if type(place) ~= "string" or #place < 3 then return nil end
    local want = place:lower()
    for _, s in ipairs(spells) do
        if s.desc:lower():find(want, 1, true) then return s end
    end
    return nil
end

-- The dungeon name of an activity: the instance map's own name, else the activity's short name.
local function placeOf(activityID)
    if type(activityID) ~= "number" then return nil end
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
    if not ok or type(info) ~= "table" then return nil end
    local zone = type(info.mapID) == "number" and info.mapID > 0 and GetRealZoneText(info.mapID)
    if type(zone) == "string" and zone ~= "" and not Secret.IsSecret(zone) then return zone end
    local short = info.shortName
    return type(short) == "string" and short ~= "" and not Secret.IsSecret(short) and short or nil
end

local function build()
    local p = W:Popup(L.LFG_TELEPORT, 260, 128, "maps")
    p:ClearAllPoints()
    p:SetPoint("TOP", 0, -180)
    p.place = W.Text(p, "body", "text.primary")
    p.place:SetPoint("TOPLEFT", 16, -40); p.place:SetPoint("RIGHT", -16, 0)
    p.button = CreateFrame("Button", "PhoenixUI_TeleportButton", p, "SecureActionButtonTemplate")
    p.button:SetSize(44, 44)
    p.button:SetPoint("BOTTOMLEFT", 16, 14)
    p.button:RegisterForClicks("AnyUp", "AnyDown")
    p.button:SetAttribute("type", "spell")
    p.icon = p.button:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.Skin:Border(p.button, "border.strong")
    p.cd = CreateFrame("Cooldown", nil, p.button, "CooldownFrameTemplate")
    p.cd:SetAllPoints()
    p.hint = W.Text(p, "small", "text.secondary")
    p.hint:SetPoint("LEFT", p.button, "RIGHT", 12, 0); p.hint:SetPoint("RIGHT", -16, 0)
    p.hint:SetText(L.LFG_TELEPORT_HINT)
    p.button:HookScript("OnEnter", function(self)
        if not p.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. p.spellID)
        GameTooltip:Show()
    end)
    p.button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- the popup holds a secure button: it is only hidden out of combat
    p.close.onClick = function() ns.Combat:Run("lfg.teleport.close", function() p:Hide() end) end
    return p
end

function M:HideTeleport()
    pending = nil
    if popup and popup:IsShown() then ns.Combat:Run("lfg.teleport.close", function() popup:Hide() end) end
end

function M:ShowTeleport(place, spell)
    if InCombatLockdown() then pending = { place, spell }; return end
    popup = popup or build()
    popup.spellID = spell.id
    popup.place:SetText(place)
    popup.icon:SetTexture(C_Spell.GetSpellTexture(spell.id))
    popup.button:SetAttribute("spell", spell.id)
    local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spell.id)
    if ok and dur and popup.cd.SetCooldownFromDurationObject then popup.cd:SetCooldownFromDurationObject(dur) else popup.cd:Clear() end
    popup:Show()
    local shown = popup.shownAt and popup.shownAt + 1 or 1
    popup.shownAt = shown
    C_Timer.After(TIMEOUT, function() if popup.shownAt == shown then M:HideTeleport() end end)
    return popup
end

-- searchResultID from LFG_LIST_JOINED_GROUP: the group you were invited into.
function M:OnJoinedGroup(searchResultID)
    if not (self:IsEnabled() and self.db.teleport) or Secret.IsSecret(searchResultID) then return end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, searchResultID)
    if not ok or type(info) ~= "table" or type(info.activityIDs) ~= "table" then return end
    local spells = M.KnownFlyoutSpells()
    for _, activityID in ipairs(info.activityIDs) do
        local place = placeOf(activityID)
        local spell = place and M.TeleportFor(place, spells)
        if spell then return self:ShowTeleport(place, spell) end
    end
end

function M:SetupTeleport()
    if self.teleportHooked then return end
    self.teleportHooked = true
    ns.Events:On("LFG_LIST_JOINED_GROUP", OWNER, function(_, _, id) M:OnJoinedGroup(id) end)
    ns.Events:On("PLAYER_REGEN_ENABLED", OWNER, function()
        if pending then local p = pending; pending = nil; M:ShowTeleport(p[1], p[2]) end
    end)
    ns.Events:On("GROUP_LEFT", OWNER, function() M:HideTeleport() end)
    ns.Events:On("PLAYER_ENTERING_WORLD", OWNER, function() if IsInInstance() then M:HideTeleport() end end)
end
