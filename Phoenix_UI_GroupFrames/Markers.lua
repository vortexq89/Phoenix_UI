local _, ns = ...
local L, Skin = ns.L, ns.Skin
local M = ns:GetModule("GroupFrames")

--[[ Raid marker bar (EllesmereUI WindTools "Raid Markers" and Blizzard's raid manager studied; original code).
    Row 1, target markers: click puts raid icon 1-8 on your target (SetRaidTarget, not protected), right click
    removes it; the last button clears every target marker. Row 2, world markers: SecureActionButtons with the game's
    own "worldmarker" action (PlaceRaidMarker is protected): left click places that marker at the cursor, right
    click clears it, the last button clears them all. Extras: ready check and a 10 s pull countdown (the game's own;
    leader or assist only). Icons are the game's raid icon sheet. Secure parts are made and moved out of combat only
    (ns.Combat:Run); showing "in a group only" is a state driver, so it also works in combat. Off by default. ]]

local SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
-- raid icon (1 star … 8 skull) -> world marker index (1 blue square … 8 white skull), as Blizzard's raid manager
-- maps them (WORLD_RAID_MARKER_ORDER over its reversed button order)
local WORLD_OF = { 5, 6, 3, 2, 7, 1, 4, 8 }
M.WORLD_OF = WORLD_OF

local bar
local targetButtons, worldButtons, extraButtons = {}, {}, {}

local function iconCoords(tex, i)
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    tex:SetTexture(SHEET)
    tex:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

-- Secure attributes for world-marker button i (1-8 raid icon order) or the clear-all button (i = nil). Pure.
function M.WorldMarkerAttributes(i)
    if i == nil then
        return { type1 = "worldmarker", action1 = "clear", type2 = "worldmarker", action2 = "clear" }
    end
    local w = WORLD_OF[i]
    if not w then return nil end
    return { type1 = "worldmarker", marker1 = w, action1 = "set", type2 = "worldmarker", marker2 = w, action2 = "clear" }
end

-- The visibility state driver text for a "where" setting.
function M.MarkerVisibility(show, where)
    if not show then return "hide" end
    if where == "always" then return "show" end
    if where == "raid" then return "[group:raid] show; hide" end
    return "[group] show; hide"
end

local function tip(b, text)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function newButton(secure)
    local b = CreateFrame("Button", nil, bar, secure and "SecureActionButtonTemplate" or nil)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2)
    b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    return b
end

local function build()
    bar = CreateFrame("Frame", "PhoenixUI_Markers", UIParent, "SecureHandlerStateTemplate")
    M.markerBar = bar
    for i = 1, 9 do
        local b = newButton(false)
        b:RegisterForClicks("AnyUp")
        if i <= 8 then
            iconCoords(b.tex, i)
            b:SetScript("OnClick", function(_, button) SetRaidTarget("target", button == "RightButton" and 0 or i) end)
            tip(b, L.GF_MARK_TARGET_TIP)
        else
            ns.Icons:Apply(b.tex, "close")
            b:SetScript("OnClick", function() RemoveRaidTargets() end)
            tip(b, L.GF_MARK_CLEAR_TARGETS)
        end
        targetButtons[i] = b
    end
    for i = 1, 9 do
        local b = newButton(true)
        for k, v in pairs(M.WorldMarkerAttributes(i <= 8 and i or nil)) do b:SetAttribute(k, v) end
        if i <= 8 then iconCoords(b.tex, i) else ns.Icons:Apply(b.tex, "close") end
        tip(b, i <= 8 and L.GF_MARK_WORLD_TIP or L.GF_MARK_CLEAR_WORLD)
        worldButtons[i] = b
    end
    local ready = newButton(false)
    ready:RegisterForClicks("AnyUp")
    ns.Icons:Apply(ready.tex, "check")
    ready:SetScript("OnClick", function() if C_PartyInfo and C_PartyInfo.DoReadyCheck then C_PartyInfo.DoReadyCheck() end end)
    tip(ready, L.GF_MARK_READY)
    local pull = newButton(false)
    pull:RegisterForClicks("AnyUp")
    pull.text = pull:CreateFontString(nil, "OVERLAY")
    pull.text:SetPoint("CENTER")
    pull:SetScript("OnClick", function(_, button)
        if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(button == "RightButton" and 0 or 10) end
    end)
    tip(pull, L.GF_MARK_PULL)
    extraButtons[1], extraButtons[2] = ready, pull
end

-- Places every button for the settings (out of combat).
local function layout()
    local s = M.db.markers
    local size, gap = s.size, s.spacing
    local rows = {}
    if s.target then rows[#rows + 1] = targetButtons end
    if s.world then rows[#rows + 1] = worldButtons end
    local longest = 0
    for _, b in ipairs(targetButtons) do b:Hide() end
    for _, b in ipairs(worldButtons) do b:Hide() end
    for _, b in ipairs(extraButtons) do b:Hide() end
    for r, list in ipairs(rows) do
        for i, b in ipairs(list) do
            b:SetSize(size, size)
            b:ClearAllPoints()
            local along, across = (i - 1) * (size + gap), (r - 1) * (size + gap)
            if s.vertical then b:SetPoint("TOPLEFT", bar, "TOPLEFT", across, -along)
            else b:SetPoint("TOPLEFT", bar, "TOPLEFT", along, -across) end
            Skin:Border(b, "border.strong")
            b:Show()
        end
        longest = math.max(longest, #list)
    end
    local n = #rows
    if s.extras then
        for i, b in ipairs(extraButtons) do
            b:SetSize(size, size)
            b:ClearAllPoints()
            local along, across = (longest + i - 1) * (size + gap), 0
            if n == 0 then along = (i - 1) * (size + gap) end
            if s.vertical then b:SetPoint("TOPLEFT", bar, "TOPLEFT", across, -along)
            else b:SetPoint("TOPLEFT", bar, "TOPLEFT", along, -across) end
            Skin:Border(b, "border.strong")
            b:Show()
        end
        if extraButtons[2].text then
            Skin:Text(extraButtons[2].text, "number", "text.primary", math.max(9, math.floor(size * 0.45)))
            extraButtons[2].text:SetText("10")
        end
        longest = (n == 0 and 0 or longest) + #extraButtons
    end
    local along = math.max(1, longest) * (size + gap) - gap
    local across = math.max(1, n) * (size + gap) - gap
    if s.vertical then bar:SetSize(across, along) else bar:SetSize(along, across) end
    bar:ClearAllPoints()
    bar:SetPoint(s.point, UIParent, s.point, s.x, s.y)
    RegisterStateDriver(bar, "visibility", M.MarkerVisibility(M:IsEnabled() and s.show, s.where))
end

function M:UpdateMarkers()
    if not self.db.markers.show and not bar then return end
    ns.Combat:Run("groupframes.markers", function()
        if not bar then build() end
        layout()
    end)
end

local function store()
    return {
        active = function() return M:IsEnabled() and M.db.markers.show end,
        get = function() local t = M.db.markers; return { point = t.point, x = t.x, y = t.y } end,
        set = function(v) local t = M.db.markers; t.point, t.x, t.y = v.point or t.point, v.x or t.x, v.y or t.y end,
        apply = function() M:UpdateMarkers() end,
        reset = function()
            local d, t = M.defaults.markers, M.db.markers
            t.point, t.x, t.y = d.point, d.x, d.y
            M:UpdateMarkers()
        end,
    }
end

function M:EnableMarkers()
    self:UpdateMarkers()
    if bar and not self.markersRegistered then
        self.markersRegistered = true
        local movers = ns:GetModule("Movers")
        if movers then movers:Register("gf.markers", bar, L.GF_MARKERS, store()) end
    end
end
