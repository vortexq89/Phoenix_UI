local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Config = ns.Config

--[[ Global search across every module's option schema. Results overlay the content area;
    clicking a result opens the page, scrolls to the row and flashes it. ]]
local MAX_RESULTS, RESULT_H = 40, 44
local index

local function buildIndex()
    index = {}
    for _, m in ipairs(ns.moduleList) do
        if not m.hidden then
            local mLabel = L[m.label]
            local mDesc = L[m.desc] or ""
            index[#index + 1] = { module = m, label = mLabel, path = mDesc, haystack = (mLabel .. " " .. mDesc):lower() }
            local section = mLabel
            for _, item in ipairs(ns.options[m.key] or {}) do
                if item.type == "header" then
                    section = L[item.label]
                elseif item.label then
                    local label = L[item.label]
                    local hay = table.concat({ label, item.desc and L[item.desc] or "", item.keywords or "", section, mLabel }, " ")
                    index[#index + 1] = {
                        module = m, item = item, label = label, path = mLabel .. "  ›  " .. section, haystack = hay:lower(),
                    }
                end
            end
        end
    end
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
    r.go = W.Icon(r, "chevron", 12)
    r.go:SetPoint("RIGHT", -16, 0)
    local function paint(self)
        W.Color(self.bg, "bg.hover", self.hover and 0.7 or 0)
        W.Color(self.iconBg, "accent.soft", 0.9)
        W.Color(self.icon, "accent.primary")
        W.Color(self.go, self.hover and "accent.primary" or "text.muted")
        Skin:Text(self.label, "body", "text.primary")
        Skin:Text(self.path, "small", "text.muted")
    end
    r.Paint = paint
    Skin:Register(r, paint)
    r:SetScript("OnEnter", function(self) self.hover = true; paint(self) end)
    r:SetScript("OnLeave", function(self) self.hover = false; paint(self) end)
    r:SetScript("OnClick", function(self)
        local e = self.entry
        Config.frame.header.search:SetValue("")
        Config:Search("")
        local page = Config:Show(e.module.key)
        if e.item and page.Focus then C_Timer.After(0.05, function() page:Focus(e.item) end) end
    end)
    return r
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
    local f = getResults()
    local n = 0
    for _, e in ipairs(index) do
        if n >= MAX_RESULTS then break end
        if e.haystack:find(query, 1, true) then
            n = n + 1
            local row = f.rows[n] or resultRow(f.scroll.child, n)
            f.rows[n] = row
            row.entry = e
            row.label:SetText(e.label)
            row.path:SetText(e.path)
            row.icon:SetTexture(e.module.icon)
            row:Paint()
            row:Show()
        end
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    f.title:SetText(L.SEARCH_RESULTS:format(n):upper())
    Skin:Text(f.title, "heading", "text.muted")
    f.empty:SetText(n == 0 and L.SEARCH_NONE:format(query) or "")
    f.scroll.child:SetHeight(n * RESULT_H)
    f.scroll:SetVerticalScroll(0)
    f.scroll:UpdateBar()
    f:Show()
end
