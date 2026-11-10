local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Config = ns.Config

--[[ Global search across every page's option schema: modules and built-in pages, with their sidebar group
    and tab in the path, so "unit frames portrait" or "tools profiles" both land. Results overlay the content
    area; clicking a result opens the page (expanding its sidebar group), switches to the row's tab, scrolls it
    into view and flashes it. ]]
local MAX_RESULTS, RESULT_H = 40, 44
local index

--[[ Words people type for what the options call something else. A query word matches a row when the word or
    any of its synonyms is in the row's text, so "hp", "cd" or "colour" land where they should. Kept in
    English on purpose: these are the abbreviations players use in every client language. ]]
local SYNONYMS = {
    hp = { "health" }, health = { "hp" }, mana = { "power" }, power = { "mana", "energy", "rage" },
    cd = { "cooldown" }, cds = { "cooldown" }, cooldown = { "cd" },
    colour = { "color" }, color = { "colour" }, grey = { "gray" }, gray = { "grey" },
    bg = { "background", "backdrop" }, background = { "backdrop" }, backdrop = { "background" },
    opacity = { "alpha", "transparency" }, alpha = { "opacity" }, transparency = { "opacity", "alpha" },
    scale = { "size" },
    keybind = { "hotkey", "binding" }, hotkey = { "keybind", "binding" }, bind = { "hotkey", "keybind" },
    np = { "nameplate" }, plates = { "nameplate" }, uf = { "unit frame" }, ab = { "action bar" },
    raid = { "group" }, party = { "group" }, mplus = { "mythic" }, ["m+"] = { "mythic" }, key = { "keystone" },
    dbm = { "encounter", "boss" }, bigwigs = { "encounter", "boss" }, timers = { "timer", "bar" },
    edge = { "border" }, typeface = { "font" }, ilvl = { "item level" },
    fps = { "frame rate" }, ping = { "latency" },
}

local function matches(haystack, word)
    if haystack:find(word, 1, true) then return true end
    for _, alt in ipairs(SYNONYMS[word] or {}) do
        if haystack:find(alt, 1, true) then return true end
    end
    return false
end

-- Every page (module or built-in) with its schema: modules first in sidebar order, then built-in pages.
local function sources()
    local out = {}
    for _, g in ipairs(Config:Groups()) do
        for _, sec in ipairs(g.sections) do
            local heading = sec.heading and L[sec.heading] or ""
            for _, key in ipairs(sec.entries) do
                local m = ns.modules[key]
                if m then
                    out[#out + 1] = { key = key, object = m, schema = ns.options[key] or {}, group = g, heading = heading }
                else
                    local info = Config.pageInfo[key]
                    if info then
                        out[#out + 1] = { key = key, object = info.object or info, schema = Config:SchemaOf(key) or {},
                            group = g, heading = heading }
                    end
                end
            end
        end
    end
    return out
end

-- Rebuilt on the first query after the window opens, so pages and modules added later are found too.
local function buildIndex()
    index = {}
    for _, src in ipairs(sources()) do
        local m = src.object
        local mLabel = L[m.label] or m.label
        local gLabel = (L[src.group.label] or "") .. " " .. src.heading
        local rail = L[src.group.label] or ""
        local root = (src.group.entries[2] and rail ~= mLabel) and (rail .. "  ›  " .. mLabel) or mLabel
        local mDesc = m.desc and L[m.desc] or ""
        index[#index + 1] = { key = src.key, icon = m.icon, label = mLabel, path = root,
            haystack = (mLabel .. " " .. mDesc .. " " .. gLabel):lower() }
        local section = mLabel
        local tab
        local function add(item, where)
            local label = L[item.label] or item.label
            local hay = table.concat({ label, item.desc and L[item.desc] or "", item.keywords or "", where, mLabel, gLabel }, " ")
            index[#index + 1] = {
                key = src.key, icon = m.icon, item = item, label = label, path = root .. "  ›  " .. where,
                haystack = hay:lower(),
            }
        end
        for _, item in ipairs(src.schema) do
            if item.type == "tab" then
                tab = L[item.label] or item.label
                section = tab
            elseif item.type == "header" then
                section = tab and (tab .. "  ›  " .. (L[item.label] or item.label)) or (L[item.label] or item.label)
            elseif item.label and item.type ~= "scope" and item.type ~= "preview" then
                add(item, section)
                -- sub-options behind a cog are found too; the result flashes their row
                for _, sub in ipairs(item.cog or {}) do
                    if sub.label then add(sub, section .. "  ›  " .. (L[item.label] or item.label)) end
                end
            end
        end
    end
end

function Config:InvalidateSearch() index = nil end

-- Settings the search reaches (rows, not pages), for the placeholder: "Search 455 settings…".
function Config:SearchCount()
    if not index then buildIndex() end
    local n = 0
    for _, e in ipairs(index) do if e.item then n = n + 1 end end
    return n
end

function Config:UpdateSearchHint()
    local box = self.frame and self.frame.header.search
    if box and box.placeholder then box.placeholder:SetText(L.SEARCH_PLACEHOLDER_N:format(self:SearchCount())) end
end

local function resultRow(parent, i)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(RESULT_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * RESULT_H)
    r:SetPoint("TOPRIGHT", 0, -(i - 1) * RESULT_H)
    r.bg = W.Texture(r, "BACKGROUND")
    r.bg:SetAllPoints()
    r.iconBg = W.Texture(r, "ARTWORK", 0, ns.Media.textures.ROUNDED)
    r.iconBg:SetSize(28, 28)
    r.iconBg:SetPoint("LEFT", 14, 0)
    r.icon = W.Icon(r, "search", 14)
    r.icon:SetPoint("CENTER", r.iconBg)
    r.label = W.Text(r, "body", "text.primary")
    r.label:SetPoint("TOPLEFT", r.iconBg, "TOPRIGHT", 12, -1)
    r.path = W.Text(r, "small", "text.muted")
    r.path:SetPoint("BOTTOMLEFT", r.iconBg, "BOTTOMRIGHT", 12, 1)
    r.go = W.Icon(r, "chevron-right", 12)
    r.go:SetPoint("RIGHT", -16, 0)
    local function paint(self)
        W.Color(self.bg, "bg.hover", (self.hover or self.selected) and 0.7 or 0)
        W.TileColor(self.iconBg, self.icon, "accent.soft")
        W.Color(self.icon, "accent.primary")
        W.Color(self.go, self.hover and "accent.primary" or "text.muted")
        Skin:Text(self.label, "body", "text.primary")
        Skin:Text(self.path, "small", "text.muted")
    end
    r.Paint = paint
    Skin:Register(r, paint)
    r:SetScript("OnEnter", function(self) self.hover = true; paint(self) end)
    r:SetScript("OnLeave", function(self) self.hover = false; paint(self) end)
    r:SetScript("OnClick", function(self) Config:OpenResult(self.entry) end)
    return r
end

function Config:OpenResult(e)
    if not e then return end
    self.frame.header.search:SetValue("")
    self:Search("")
    local page = self:Show(e.key)
    if e.item and page.Focus then C_Timer.After(0.05, function() page:Focus(e.item) end) end
end

-- The words typed, shown in the accent colour inside a result's label (plain, case-blind match).
local function highlight(label, words)
    local lower, marks = label:lower(), {}
    for _, w in ipairs(words) do
        local from = 1
        while true do
            local a, b = lower:find(w, from, true)
            if not a then break end
            marks[#marks + 1] = { a, b }
            from = b + 1
        end
    end
    if #marks == 0 then return label end
    table.sort(marks, function(x, y) return x[1] < y[1] end)
    local r, g, b = ns.Theme:Color("accent.text")
    local open = ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
    local out, at = {}, 1
    for _, m in ipairs(marks) do
        if m[1] >= at then
            out[#out + 1] = label:sub(at, m[1] - 1) .. open .. label:sub(m[1], m[2]) .. "|r"
            at = m[2] + 1
        end
    end
    out[#out + 1] = label:sub(at)
    return table.concat(out)
end
Config.SearchHighlight = highlight

-- Arrow keys move through the results, Enter opens the picked one (the first when none was picked).
function Config:SearchMove(step)
    local f = self.results
    if not (f and f:IsShown()) or (f.count or 0) == 0 then return end
    f.sel = math.max(1, math.min(f.count, (f.sel or 0) + step))
    for i = 1, f.count do
        local row = f.rows[i]
        row.selected = i == f.sel
        row:Paint()
    end
    -- keep the picked row in view
    local top, h = (f.sel - 1) * RESULT_H, f.scroll:GetHeight() or 0
    local at = f.scroll:GetVerticalScroll()
    if top < at then f.scroll:SetVerticalScroll(top)
    elseif h > 0 and top + RESULT_H > at + h then f.scroll:SetVerticalScroll(top + RESULT_H - h) end
    f.scroll:UpdateBar()
end
function Config:SearchEnter()
    local f = self.results
    if not (f and f:IsShown()) or (f.count or 0) == 0 then return false end
    self:OpenResult(f.rows[f.sel or 1].entry)
    return true
end

local function getResults()
    if Config.results then return Config.results end
    local f = CreateFrame("Frame", nil, Config.frame.content)
    f:SetAllPoints()
    f:SetFrameLevel(Config.frame.content:GetFrameLevel() + 20)
    f:EnableMouse(true)
    Skin:Register(f, function(self) Skin:Panel(self, "base", { border = false }) end)
    f.title = W.Text(f, "heading", "text.muted")
    f.title:SetPoint("TOPLEFT", 24, -20)
    f.scroll = W:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", 16, -44)
    f.scroll:SetPoint("BOTTOMRIGHT", -16, 12)
    f.rows = {}
    f.empty = W.Text(f, "desc", "text.muted", "CENTER")
    f.empty:SetPoint("CENTER")
    Config.results = f
    return f
end

function Config:Search(query)
    query = strtrim(query or ""):lower()
    if #query < 2 then
        if self.results then self.results:Hide() end
        return
    end
    if not index then buildIndex() end
    local words = {}
    for w in query:gmatch("%S+") do words[#words + 1] = w end
    local f = getResults()
    local n = 0
    -- Pages first, then settings rows, so a group name still lists its pages when its rows alone fill the cap.
    local ordered = {}
    for _, e in ipairs(index) do if not e.item then ordered[#ordered + 1] = e end end
    for _, e in ipairs(index) do if e.item then ordered[#ordered + 1] = e end end
    for _, e in ipairs(ordered) do
        if n >= MAX_RESULTS then break end
        local hit = true
        for _, w in ipairs(words) do
            if not matches(e.haystack, w) then hit = false; break end
        end
        if hit then
            n = n + 1
            local row = f.rows[n] or resultRow(f.scroll.child, n)
            f.rows[n] = row
            row.entry = e
            ns.Icons:Apply(row.icon, e.icon or "search", 14)
            row.label:SetText(highlight(e.label, words))
            row.path:SetText(e.path)
            row.selected = false
            row:Paint()
            row:Show()
        end
    end
    f.count, f.sel = n, nil
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    f.title:SetText((n == 1 and L.SEARCH_RESULT or L.SEARCH_RESULTS:format(n)):upper())
    Skin:Text(f.title, "heading", "text.muted")
    f.empty:SetText(n == 0 and L.SEARCH_NONE:format(query) or "")
    f.scroll.child:SetHeight(n * RESULT_H)
    f.scroll:SetVerticalScroll(0)
    f.scroll:UpdateBar()
    f:Show()
end
