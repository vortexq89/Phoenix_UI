local _, ns = ...
local L = ns.L
local W, Skin, Theme = ns.Widgets, ns.Skin, ns.Theme
local M = ns:GetModule("GroupFinder")

--[[ The Phoenix filter panel: our own frame beside the group finder while its search list is open. Quick
    controls (difficulty, free places, score, best key, age, needs), the filter expression with a live match
    count, the sort and the best matches. Every control writes the same settings as the options page
    (ns.DB:Set), so both stay in step. The panel is anchored to PVEFrame but is never its child. ]]
local PAD, WIDTH, ROWS = 12, 270, 7
local panel

local function set(key, value) ns.DB:Set(M, key, value) end

local function label(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Skin:Text(fs, "small", "text.secondary", 11)
    fs:SetText(text)
    return fs
end

local DIFFS = { { value = "diffNormal", label = L.LFG_NORMAL }, { value = "diffHeroic", label = L.LFG_HEROIC },
    { value = "diffMythic", label = L.LFG_MYTHIC }, { value = "diffMythicPlus", label = L.LFG_MYTHICPLUS } }
local ROLES = { { value = "freeTank", label = L.LFG_TANK }, { value = "freeHealer", label = L.LFG_HEALER },
    { value = "freeDamage", label = L.LFG_DAMAGE } }
local NEEDS = { { value = "hasLust", label = L.LFG_LUST }, { value = "hasBrez", label = L.LFG_BREZ },
    { value = "friends", label = L.LFG_FRIENDS }, { value = "noLeavers", label = L.LFG_NO_LEAVERS } }

function M.SortItems()
    local out = {}
    for _, item in ipairs(M.SORT_LIST) do out[#out + 1] = { value = item.value, label = L[item.label] } end
    return out
end

function M.PresetItems()
    local out = {}
    for _, p in ipairs(M.PRESETS) do out[#out + 1] = { value = p.value, label = L[p.label] } end
    return out
end

-- A set of chips bound to boolean settings.
local function boolChips(parent, items)
    local c = W:Chips(parent, items, true)
    c.keys = items
    c:SetItems(items)
    c.onChange = function(self, value)
        for _, item in ipairs(self.keys) do
            local on = value[item.value] == true
            if (M.db[item.value] and true or false) ~= on then set(item.value, on) end
        end
    end
    function c:Sync()
        local v = {}
        for _, item in ipairs(self.keys) do v[item.value] = M.db[item.value] and true or nil end
        self:SetValue(v)
    end
    return c
end

local function slider(parent, key, min, max, step)
    local s = W:Slider(parent, min, max, step)
    s:SetWidth(WIDTH - 2 * PAD)
    s.onCommit = function(_, v) set(key, v) end
    s.onChange = function(self, v) if not self.dragging then set(key, v) end end
    s.key = key
    return s
end

local function matchRow(parent, i)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("LEFT", 6, 0)
    b.name:SetPoint("RIGHT", -96, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.score = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.score:SetPoint("RIGHT", -52, 0)
    b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.info:SetPoint("RIGHT", -6, 0)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:SetTexture(ns.Media.textures.WHITE)
    -- theme fonts on the result rows, like the rest of the panel (follow font / theme changes live)
    ns.Skin:Register(b, function(self)
        ns.Skin:Text(self.name, "body", "text.primary", 12)
        ns.Skin:Text(self.score, "number", "text.primary", 12)
        if self.scoreRGB then self.score:SetTextColor(unpack(self.scoreRGB)) end -- the rating colour outlives a restyle
        ns.Skin:Text(self.info, "small", "text.secondary", 11)
    end)
    b:SetScript("OnEnter", function(self)
        W.Color(self.fill, "bg.hover", 1)
        if not self.record then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.title or "", 1, 1, 1)
        M:AddTooltipLines(GameTooltip, self.record.id)
        GameTooltip:AddLine(L.LFG_MATCH_HINT, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) W.Color(self.fill, "bg.hover", i % 2 == 0 and 0.35 or 0); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self) if self.record then M:FlashEntry(self.record.id) end end)
    return b
end

local function build()
    panel = CreateFrame("Frame", "PhoenixUI_GroupFinderPanel", UIParent)
    panel:SetSize(WIDTH, 560)
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    panel:Hide()
    local y = -PAD
    local function place(region, h, gap)
        region:SetPoint("TOPLEFT", PAD, y)
        y = y - h - (gap or 6)
    end
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.title:SetText(L.LFG_PANEL_TITLE)
    place(panel.title, 16, 2)
    panel.count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.count:SetPoint("TOPRIGHT", -PAD - 26, -PAD - 2)
    panel.reset = W:IconButton(panel, "reset", 20, L.LFG_RESET)
    panel.reset:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 2)
    panel.reset.onClick = function() set("preset", "none"); M:ResetFilters() end
    panel.preset = W:Dropdown(panel, M.PresetItems, nil, WIDTH - 2 * PAD)
    panel.preset.onChange = function(_, v) set("preset", v) end
    place(panel.preset, 26)
    panel.diffLabel = label(panel, L.LFG_GAME_FILTERS)
    place(panel.diffLabel, 12, 4)
    panel.diffs = boolChips(panel, DIFFS)
    panel.diffs:SetWidth(WIDTH - 2 * PAD)
    place(panel.diffs, 22)
    panel.roleLabel = label(panel, L.LFG_FREE_FOR)
    place(panel.roleLabel, 12, 4)
    panel.roles = boolChips(panel, ROLES)
    panel.roles:SetWidth(WIDTH - 2 * PAD)
    place(panel.roles, 22)
    panel.needs = boolChips(panel, NEEDS)
    panel.needs:SetWidth(WIDTH - 2 * PAD)
    place(panel.needs, 22 * 2 + 6)
    panel.sliders = {}
    for _, s in ipairs({ { "minScore", "LFG_MIN_SCORE", 0, 4000, 50 }, { "keyMin", "LFG_KEY_MIN", 0, 30, 1 },
        { "keyMax", "LFG_KEY_MAX", 0, 30, 1 }, { "maxAge", "LFG_MAX_AGE", 0, 180, 5 } }) do
        local lab = label(panel, L[s[2]])
        place(lab, 12, 2)
        local sl = slider(panel, s[1], s[3], s[4], s[5])
        place(sl, 22)
        panel.sliders[#panel.sliders + 1] = sl
    end
    panel.exprLabel = label(panel, L.LFG_EXPRESSION)
    place(panel.exprLabel, 12, 2)
    panel.expr = W:Input(panel, WIDTH - 2 * PAD, L.LFG_EXPRESSION_HINT)
    panel.expr.onChange = function(_, text) set("expression", text) end
    panel.expr.onTextChanged = function(_, text) M:PreviewExpression(text) end
    place(panel.expr, 26, 2)
    panel.err = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.err:SetWidth(WIDTH - 2 * PAD)
    panel.err:SetJustifyH("LEFT")
    place(panel.err, 12, 6)
    panel.sort = W:Dropdown(panel, M.SortItems, nil, WIDTH - 2 * PAD - 34)
    panel.sort.onChange = function(_, v) set("sort", v) end
    place(panel.sort, 26)
    panel.desc = W:IconButton(panel, "arrow-down", 26, L.LFG_SORT_DESC)
    panel.desc:SetPoint("LEFT", panel.sort, "RIGHT", 8, 0)
    panel.desc.onClick = function() set("sortDesc", not M.db.sortDesc) end
    panel.listLabel = label(panel, L.LFG_BEST_MATCHES)
    place(panel.listLabel, 12, 4)
    panel.rows = {}
    for i = 1, ROWS do
        local row = matchRow(panel, i)
        row:SetWidth(WIDTH - 2 * PAD)
        place(row, 22, 0)
        panel.rows[i] = row
    end
    panel.empty = label(panel, L.LFG_NO_MATCHES)
    panel.empty:SetPoint("TOPLEFT", panel.rows[1], "TOPLEFT", 6, -4)
    panel:SetHeight(-y + PAD)
    Skin:Register(panel, function() M:StylePanel() end)
end

function M:StylePanel()
    if not panel then return end
    local db = self.db
    Skin:Backdrop(panel, db.panelBackground, "bg.base")
    Skin:BorderSpec(panel, db.panelBorder, "border.strong")
    Skin:Text(panel.title, "heading", "accent.primary", 13)
    Skin:Text(panel.count, "number", "text.secondary", 11)
    Skin:Text(panel.err, "small", "state.danger", 10)
    Skin:Text(panel.empty, "small", "text.muted", 11)
    for i, row in ipairs(panel.rows) do
        Skin:Text(row.name, "body", "text.primary", 11)
        Skin:Text(row.score, "number", nil, 11)
        Skin:Text(row.info, "small", "text.secondary", 10)
        W.Color(row.fill, "bg.hover", i % 2 == 0 and 0.35 or 0)
    end
end

function M:ResetFilters()
    for _, c in ipairs(self.CHECKS) do ns.DB:Set(self, c[1], self.defaults[c[1]]) end
    ns.DB:Set(self, "expression", "")
    ns.DB:Set(self, "preset", "none")
end

-- Live count while typing (the setting is only saved on Enter).
function M:PreviewExpression(text)
    if not panel then return end
    local fn, err = ns.GroupFinderExpression.Compile(text, self.WORDS)
    if text ~= "" and not fn then
        panel.err:SetText(self:ErrorText(err))
        return
    end
    local n = 0
    for _, id in ipairs(self.Results()) do
        local r = self:Record(id)
        if r and not r.delisted and (not fn or fn(r)) then n = n + 1 end
    end
    panel.err:SetText(L.LFG_EXPRESSION_COUNT:format(n))
end

-- One best-match row: activity, leader score (or PvP rating), best key and size.
local function fillRow(row, r)
    local info = C_LFGList.GetSearchResultInfo(r.id)
    local a = M.Activity(r.activityID)
    row.title = type(info) == "table" and info.name or nil
    -- t146: every keystone row read "Mythic+" (the activity's shortName); for keystones the full name without
    -- its "(Mythic Keystone)" suffix is the dungeon, which is what tells two rows apart
    local full = a and type(a.fullName) == "string" and a.fullName or ""
    local short = a and type(a.shortName) == "string" and a.shortName or ""
    if r.mythicplus then
        full = full:gsub("%s*%b()%s*$", "")
        row.name:SetText(full ~= "" and full or short)
    else
        row.name:SetText(short ~= "" and short or full) -- raids keep their difficulty, e.g. "The Voidspire (Heroic)"
    end
    if r.pvpactivity and r.pvp > 0 then
        row.score:SetText(r.pvp)
        row.scoreRGB = nil
        row.score:SetTextColor(Theme:Color("text.primary"))
    else
        row.score:SetText(r.score > 0 and r.score or "")
        row.scoreRGB = { M.ScoreColor(r.score) }
        row.score:SetTextColor(unpack(row.scoreRGB))
    end
    local bits = {}
    if r.mythicplus and r.bestkey and r.bestkey > 0 then bits[#bits + 1] = L.LFG_BEST_KEY:format(r.bestkey) end
    if r.members and r.max then bits[#bits + 1] = r.members .. "/" .. r.max end
    row.info:SetText(table.concat(bits, " "))
end

function M:RefreshPanel()
    if not panel or not panel:IsShown() then return end
    local db = self.db
    panel.preset:SetValue(db.preset)
    panel.diffs:Sync()
    panel.roles:Sync()
    panel.needs:Sync()
    for _, s in ipairs(panel.sliders) do if not s.dragging then s:SetValue(db[s.key]) end end
    if not panel.expr:HasFocus() then panel.expr:SetValue(db.expression) end
    panel.err:SetText(self.filterError and self:ErrorText() or "")
    panel.sort:SetValue(db.sort)
    ns.Icons:Apply(panel.desc.icon, db.sortDesc and "arrow-down" or "arrow-up", 13)
    local n, total = #(self.matches or {}), self.total or 0
    panel.count:SetText(db.matchCount and L.LFG_COUNT:format(n, total) or "")
    local list = db.matchList and self.matches or {}
    for i, row in ipairs(panel.rows) do
        local r = list[i]
        row.record = r
        if r then
            fillRow(row, r)
            row:Show()
        else
            row:Hide()
        end
    end
    panel.empty:SetShown(db.matchList and #list == 0)
end

local function anchor()
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 6, 0)
end

-- t146: Blizzard's cross-faction tutorial (a gold HelpTip arrow at the search panel's right edge) sat under the
-- Phoenix panel, its chevron poking out and its text showing through. While the panel is up it is hidden,
-- not acknowledged, so the player's tutorial flags stay as they were.
local function hideTip()
    local search = LFGListFrame and LFGListFrame.SearchPanel
    if not (panel and panel:IsShown() and search and HelpTip and HelpTip.Hide) then return end
    local text = rawget(_G, "CROSS_FACTION_GROUP_FINDER_HELPTIP")
    if text then HelpTip:Hide(search, text) end
end
M._HideTip = hideTip

function M:ShowPanel(show)
    if show and not self.db.panel then show = false end
    if show then
        if not panel then build(); self:StylePanel() end
        anchor()
        panel:Show()
        hideTip()
        self:Evaluate()
        self:RefreshPanel()
    elseif panel then
        panel:Hide()
    end
end

local hooked
function M:EnablePanel()
    local function attach()
        local search = LFGListFrame and LFGListFrame.SearchPanel
        if hooked or not search then return end
        hooked = true
        search:HookScript("OnShow", function() if M:IsEnabled() then M:ShowPanel(true) end end)
        search:HookScript("OnHide", function() M:ShowPanel(false) end)
        if LFGListSearchPanel_EvaluateTutorial then hooksecurefunc("LFGListSearchPanel_EvaluateTutorial", hideTip) end
        if search:IsVisible() then M:ShowPanel(true) end
    end
    attach()
    if not hooked then
        ns.Events:On("ADDON_LOADED", self, function(_, _, name) if name == "Blizzard_GroupFinder" then attach() end end)
    end
end

function M:DisablePanel()
    self:ShowPanel(false)
end

-- The panel's frame (previews, tests).
function M:Panel() return panel end
