local _, ns = ...
local L, Skin, Theme, Secret = ns.L, ns.Skin, ns.Theme, ns.Secret
local M = ns.modules.Minimap

--[[ Minimap extras (review 29, EllesmereUI / ElvUI parity):
      info line    frame rate and latency on the map, refreshed every few seconds; its tooltip lists the Great
                   Vault progress and your saved lockouts (the same lines join the clock's tooltip)
      difficulty   the instance difficulty as short text (N, H, M, M+12, LFR, with the raid size) in place of
                   Blizzard's badge
      vault        a small button that opens the Great Vault, lit when a reward is waiting (retail)
      clicks       right click: Phoenix's own tracking menu (C_Minimap tracking list, so it works with the
                   tracking button hidden); middle click: the calendar
      fade         the whole minimap cluster fades in combat and / or while mounted, back on mouse-over
      mouse-over   zone text and coordinates only while the pointer is on the map
    Everything is our own frames and texts on the map's visible band; Blizzard frames are only faded (alpha) or
    left alone, the cluster is never moved or scaled (Edit Mode owns it). ]]

---------------------------------------------------------------- pure helpers
-- Short difficulty text for GetDifficultyInfo-style fields (pure; the smoke test calls it).
-- d = { isChallengeMode, isLFR, displayMythic, displayHeroic, isHeroic, raid, size, level }
function M.DifficultyText(d)
    if not d then return "" end
    local code
    if d.isChallengeMode then code = d.level and d.level > 0 and L.MINIMAP_DIFF_KEY:format(d.level) or L.MINIMAP_DIFF_M
    elseif d.isLFR then code = L.MINIMAP_DIFF_LFR
    elseif d.displayMythic then code = L.MINIMAP_DIFF_M
    elseif d.displayHeroic or d.isHeroic then code = L.MINIMAP_DIFF_H
    else code = L.MINIMAP_DIFF_N end
    if d.raid and d.size and d.size > 0 and not d.isLFR then return d.size .. " " .. code end
    return code
end

local function plainNum(v) return (not Secret.IsSecret(v) and type(v) == "number") and v or nil end

-- The current instance as DifficultyText fields, or nil outside an instance.
function M.CurrentDifficulty()
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid" and kind ~= "scenario") then return nil end
    local _, _, id, _, maxPlayers = GetInstanceInfo()
    id = plainNum(id)
    if not id or id == 0 then return nil end
    local _, _, isHeroic, isChallenge, displayHeroic, displayMythic, _, isLFR = GetDifficultyInfo(id)
    local level
    if isChallenge and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        level = plainNum((C_ChallengeMode.GetActiveKeystoneInfo()))
    end
    local size = kind == "raid" and (plainNum(GetNumGroupMembers()) or plainNum(maxPlayers)) or nil
    return { isChallengeMode = isChallenge, isLFR = isLFR, displayMythic = displayMythic, displayHeroic = displayHeroic,
        isHeroic = isHeroic, raid = kind == "raid", size = size, level = level }
end

-- "60 fps  32 ms" for the info line: world latency, home latency or both.
function M.InfoText(fps, home, world, mode)
    local parts = { L.MINIMAP_INFO_FPS:format(math.floor((fps or 0) + 0.5)) }
    if mode == "home" then parts[2] = L.MINIMAP_INFO_MS:format(home or 0)
    elseif mode == "both" then parts[2] = L.MINIMAP_INFO_MS2:format(home or 0, world or 0)
    elseif mode ~= "none" then parts[2] = L.MINIMAP_INFO_MS:format(world or 0) end
    return table.concat(parts, "  ")
end

-- Where the info line sits on the band for its text spec: anchor, x, y (4 px in from the edges it touches).
function M.InfoPlace(spec)
    local anchor = spec.anchor or "TOP"
    local dx = (anchor:find("LEFT") and 4) or (anchor:find("RIGHT") and -4) or 0
    local dy = (anchor:find("BOTTOM") and 4) or (anchor:find("TOP") and -4) or 0
    return anchor, (spec.x or 0) + dx, (spec.y or 0) + dy
end

---------------------------------------------------------------- vault and lockout lines (tooltips)
local function addWeeklyLines(tt)
    if ns:Supports("vault") then
        tt:AddLine(L.MINIMAP_TIP_VAULT, Theme:Color("accent.primary"))
        for _, track in ipairs(ns.Weekly.TRACKS) do
            local t = ns.Weekly:Track(track)
            local total = #t.slots
            if total > 0 then
                local r, g, b = Theme:Color(t.done >= total and "state.success" or (t.done > 0 and "text.primary" or "text.muted"))
                tt:AddDoubleLine(L[track.label], L.MINIMAP_TIP_SLOTS:format(t.done, total), 0.8, 0.8, 0.8, r, g, b)
            end
        end
    end
    local list = ns.Weekly:Lockouts()
    tt:AddLine(" ")
    tt:AddLine(L.MINIMAP_TIP_LOCKOUTS, Theme:Color("accent.primary"))
    if #list == 0 then tt:AddLine(L.MINIMAP_TIP_NONE, Theme:Color("text.muted")) end
    for _, e in ipairs(list) do
        local r, g, b = Theme:Color(e.down >= e.total and e.total > 0 and "state.success" or "text.primary")
        tt:AddDoubleLine(("%s (%s)"):format(e.name, e.difficulty), ("%d/%d"):format(e.down, e.total), 0.8, 0.8, 0.8, r, g, b)
    end
end
M.AddWeeklyLines = addWeeklyLines

---------------------------------------------------------------- info line
local info, infoTicker
local function updateInfo()
    if not info then return end
    local _, _, home, world = GetNetStats()
    info.text:SetText(M.InfoText(GetFramerate(), home, world, M.db.infoLatency))
    info:SetSize(math.max(40, info.text:GetStringWidth() + 4), math.max(12, info.text:GetStringHeight() + 2))
end

local function setupInfo(self)
    local on = self:IsEnabled() and self.db.info
    if infoTicker then infoTicker:Cancel(); infoTicker = nil end
    if not on then if info then info:Hide() end; return end
    local band = M.Holder()
    if not band then return end
    if not info then
        info = CreateFrame("Frame", nil, band)
        info:SetFrameLevel(band:GetFrameLevel() + 6)
        info.text = info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        info.text:SetPoint("CENTER")
        info:EnableMouse(true)
        info:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine(L.MINIMAP_INFO)
            addWeeklyLines(GameTooltip)
            GameTooltip:Show()
        end)
        info:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local spec = self.db.infoText
    Skin:TextSpec(info.text, spec, "number", "text.secondary")
    info:ClearAllPoints()
    local anchor, x, y = M.InfoPlace(spec)
    info:SetPoint(anchor, band, anchor, x, y)
    info:SetShown(spec.show ~= false)
    updateInfo()
    infoTicker = C_Timer.NewTicker(math.max(1, tonumber(self.db.infoInterval) or 2), function()
        if info:IsVisible() then updateInfo() end
    end)
end

---------------------------------------------------------------- difficulty text
local diff
local function updateDifficulty()
    local on = M:IsEnabled() and M.db.difficultyText
    local band = M.Holder()
    if not (on and band) then if diff then diff:Hide() end; return end
    if not diff then diff = band:CreateFontString(nil, "OVERLAY", "GameFontHighlight") end
    local spec = M.db.difficultyFont
    Skin:TextSpec(diff, spec, "heading", "accent.primary")
    Skin:Place(diff, band, spec)
    local text = M.DifficultyText(M.CurrentDifficulty())
    diff:SetText(text)
    diff:SetShown(text ~= "")
end
M.UpdateDifficultyText = updateDifficulty

---------------------------------------------------------------- vault button
local vault
local function vaultReady()
    return C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() == true
end

local function updateVault()
    local on = M:IsEnabled() and M.db.vaultButton and ns:Supports("vault")
    local band = M.Holder()
    if not (on and band) then if vault then vault:Hide() end; return end
    if not vault then
        vault = ns.Widgets:IconButton(band, "items", 20)
        vault:SetFrameLevel(band:GetFrameLevel() + 8)
        vault.onClick = function()
            if InCombatLockdown() then ns:Print(L.DM_AFTER_COMBAT); return end
            if WeeklyRewards_ShowUI then WeeklyRewards_ShowUI() end
        end
        vault:HookScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine(L.MINIMAP_VAULT)
            if vaultReady() then GameTooltip:AddLine(L.MINIMAP_VAULT_READY, Theme:Color("state.success")) end
            addWeeklyLines(GameTooltip)
            GameTooltip:AddLine(L.MINIMAP_VAULT_CLICK, Theme:Color("text.muted"))
            GameTooltip:Show()
        end)
        vault:HookScript("OnLeave", function() GameTooltip:Hide() end)
        Skin:Register(vault, function(self) Skin:Panel(self, "raised", { border = "border.default" }) end)
    end
    vault:ClearAllPoints()
    vault:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -4, 4)
    vault.active = vaultReady()
    ns.Icons:SetState(vault.icon, vault.active and "active" or nil)
    vault:Show()
end
M.UpdateVaultButton = updateVault

---------------------------------------------------------------- tracking menu and clicks
-- Phoenix's own tracking menu: every tracking type the game lists, ticked when on (works with the button hidden).
function M.TrackingList()
    local out = {}
    local n = tonumber(C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetNumTrackingTypes()) or 0
    for i = 1, n do
        local t = C_Minimap.GetTrackingInfo(i)
        if type(t) == "table" and type(t.name) == "string" then
            out[#out + 1] = { index = i, name = t.name, texture = t.texture, active = t.active and true or false }
        end
    end
    return out
end

function M:OpenTrackingMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner or Minimap, function(_, root)
        root:CreateTitle(L.MINIMAP_TRACKING)
        for _, t in ipairs(M.TrackingList()) do
            local label = t.texture and ("|T%s:14:14:0:0|t %s"):format(tostring(t.texture), t.name) or t.name
            root:CreateCheckbox(label, function()
                local now = C_Minimap.GetTrackingInfo(t.index)
                return type(now) == "table" and now.active and true or false
            end, function()
                local now = C_Minimap.GetTrackingInfo(t.index)
                C_Minimap.SetTracking(t.index, not (type(now) == "table" and now.active))
            end)
        end
    end)
end

local function onMouseUp(_, button)
    if not M:IsEnabled() then return end
    if button == "RightButton" and M.db.rightTracking then M:OpenTrackingMenu(Minimap)
    elseif button == "MiddleButton" and M.db.middleCalendar and ToggleCalendar then ToggleCalendar() end
end

---------------------------------------------------------------- fade and mouse-over texts
local function hovering()
    return Minimap:IsMouseOver() or (MinimapCluster and MinimapCluster:IsMouseOver())
end

-- Alpha the cluster should have now (pure of frames apart from the state reads).
function M.FadeAlpha(db, combat, mounted, hover)
    if hover then return 1 end
    if (db.fadeCombat and combat) or (db.fadeMounted and mounted) then return db.fadeAlpha or 0.25 end
    return 1
end

local function applyFade()
    if not MinimapCluster then return end
    local on = M:IsEnabled()
    local hover = hovering()
    local a = on and M.FadeAlpha(M.db, InCombatLockdown() or UnitAffectingCombat("player") == true, IsMounted(), hover) or 1
    MinimapCluster:SetAlpha(a)
    -- zone text and coordinates on mouse-over only
    local zoneA = (on and M.db.zoneMouseover and not hover) and 0 or 1
    local zb = MinimapCluster.ZoneTextButton
    if zb then zb:SetAlpha(zoneA) end
    if MinimapCluster.BorderTop then MinimapCluster.BorderTop:SetAlpha(zoneA) end
    local c = M.CoordsText and M.CoordsText()
    if c then c:SetAlpha((on and M.db.coordsMouseover and not hover) and 0 or 1) end
end
M.ApplyFade = applyFade

local hooked = false
function M:SetupExtras()
    if not hooked then
        hooked = true
        Minimap:HookScript("OnMouseUp", onMouseUp)
        Minimap:HookScript("OnEnter", applyFade)
        Minimap:HookScript("OnLeave", function() C_Timer.After(0.1, applyFade) end)
        if TimeManagerClockButton then self:HookClockTip() end
    end
    setupInfo(self)
    updateDifficulty()
    updateVault()
    applyFade()
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
        "CHALLENGE_MODE_START", "GROUP_ROSTER_UPDATE" }) do
        ns.Events:On(ev, M.Extras, updateDifficulty)
    end
    ns.Events:On("WEEKLY_REWARDS_UPDATE", M.Extras, updateVault)
    for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
        ns.Events:On(ev, M.Extras, function() C_Timer.After(0, applyFade) end)
    end
end
M.Extras = M.Extras or {}

-- The clock's own tooltip gets the vault and lockout lines (Blizzard's OnEnter runs first; a post-hook adds).
local clockHooked = false
function M:HookClockTip()
    if clockHooked or not TimeManagerClockButton then return end
    clockHooked = true
    TimeManagerClockButton:HookScript("OnEnter", function()
        if not (M:IsEnabled() and M.db.clockTip) or GameTooltip:GetOwner() ~= TimeManagerClockButton then return end
        GameTooltip:AddLine(" ")
        addWeeklyLines(GameTooltip)
        GameTooltip:Show()
    end)
end

function M:HideExtras()
    ns.Events:OffAll(M.Extras)
    if infoTicker then infoTicker:Cancel(); infoTicker = nil end
    if info then info:Hide() end
    if diff then diff:Hide() end
    if vault then vault:Hide() end
    applyFade()
end
