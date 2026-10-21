local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Errors = ns.Errors
local M = ns:GetModule("Bugs")

--[[ Bug viewer: list (newest first) + detail, session filter, search, copy box, clear, prev/next.
    Built on first open; refreshed live (PUI_BUG) while shown. ]]
local WIDTH, HEIGHT, LIST_W, ROW_H, HEADER_H, FOOTER_H = 900, 560, 330, 46, 56, 52
local ROWS = math.floor((HEIGHT - HEADER_H - FOOTER_H - 16) / ROW_H)
local KIND = {
    error = { icon = "error", token = "state.danger", label = "BUGS_KIND_ERROR" },
    taint = { icon = "taint", token = "state.warning", label = "BUGS_KIND_TAINT" },
    warning = { icon = "warning", token = "state.info", label = "BUGS_KIND_WARNING" },
}
local SESSIONS = {
    { value = "current", label = L.BUGS_SESSION_CURRENT, icon = "clock" },
    { value = "previous", label = L.BUGS_SESSION_PREVIOUS, icon = "spellhistory" },
    { value = "all", label = L.BUGS_SESSION_ALL, icon = "filter" },
}

local V -- the window (M:GetViewer)
local view = { list = {}, index = 0, offset = 0, session = "current", query = "" }

local function kindOf(r) return KIND[r.kind] or KIND.error end
local function firstLine(s) return (s or ""):match("^[^\n]*") or "" end
local function stamp(t) return t and date("%Y-%m-%d %H:%M:%S", t) or "—" end

local function previousSession(reports, current)
    local best = 0
    for _, r in ipairs(reports) do
        if r.session < current and r.session > best then best = r.session end
    end
    return best
end

local function matches(r, q)
    if q == "" then return true end
    return (r.message:lower():find(q, 1, true) or r.source:lower():find(q, 1, true)
        or r.stack:lower():find(q, 1, true)) and true or false
end

local function collect()
    local reports, out = Errors:GetReports(), {}
    local current = Errors:GetSession()
    local want = view.session == "current" and current or view.session == "previous" and previousSession(reports, current) or nil
    local q = view.query:lower()
    for i = #reports, 1, -1 do
        local r = reports[i]
        if (not want or r.session == want) and matches(r, q) then out[#out + 1] = r end
    end
    return out
end

-- Full plain-text report for the copy box.
local function reportText(r)
    return table.concat({
        L.BUGS_FIELD_ID:format(r.id),
        L.BUGS_FIELD_SUMMARY:format(L[kindOf(r).label], r.source, r.count),
        L.BUGS_FIELD_SEEN:format(stamp(r.firstSeen), stamp(r.lastSeen)),
        L.BUGS_FIELD_CLIENT:format(r.addonVersion, r.build, r.locale),
        "",
        L.BUGS_FIELD_MESSAGE, r.message, "",
        L.BUGS_FIELD_STACK, r.stack ~= "" and r.stack or L.BUGS_NONE, "",
        L.BUGS_FIELD_LOCALS, r.locals ~= "" and r.locals or L.BUGS_NONE,
    }, "\n")
end

---------------------------------------------------------------- list rows
local function buildRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", -8, -(i - 1) * ROW_H)
    row.bg = W.Texture(row, "BACKGROUND", 1)
    row.bg:SetAllPoints()
    row.bar = W.Texture(row, "ARTWORK", 1)
    row.bar:SetPoint("TOPLEFT"); row.bar:SetPoint("BOTTOMLEFT"); row.bar:SetWidth(2)
    row.icon = W.Icon(row, "error", 14, "state.danger")
    row.icon:SetPoint("TOPLEFT", 12, -9)
    row.title = W.Text(row, "body", "text.primary")
    row.title:SetPoint("TOPLEFT", 34, -8)
    row.title:SetPoint("RIGHT", -46, 0)
    row.title:SetWordWrap(false)
    row.meta = W.Text(row, "small", "text.muted")
    row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
    row.meta:SetPoint("RIGHT", -12, 0)
    row.meta:SetWordWrap(false)
    row.count = W:Badge(row, "1", "state.danger")
    row.count:SetPoint("TOPRIGHT", -10, -8)
    row.sep = W:Separator(row)
    row.sep:SetPoint("BOTTOMLEFT", 12, 0); row.sep:SetPoint("BOTTOMRIGHT", -12, 0)
    function row:Paint()
        local selected = self.report and view.list[view.index] == self.report
        W.Color(self.bg, selected and "accent.soft" or "bg.hover", selected and 1 or (self.hover and 0.6 or 0))
        W.Color(self.bar, "accent.primary", selected and 1 or 0)
        Skin:Text(self.title, "body", selected and "text.primary" or "text.secondary")
        Skin:Text(self.meta, "small", "text.muted")
    end
    Skin:Register(row, row.Paint)
    row:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    row:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    row:SetScript("OnClick", function(self)
        if self.listIndex then V:Select(self.listIndex) end
    end)
    return row
end

local function fillRow(row, r, listIndex)
    row.report, row.listIndex = r, listIndex
    if not r then row:Hide(); return end
    local k = kindOf(r)
    ns.Icons:Apply(row.icon, k.icon, 14)
    ns.Icons:Tint(row.icon, k.token)
    row.title:SetText(firstLine(r.message))
    row.meta:SetText(L.BUGS_ROW_META:format(r.source, date("%H:%M", r.lastSeen), r.session))
    row.count:Set("×" .. r.count, k.token)
    row:Paint()
    row:Show()
end

---------------------------------------------------------------- window
local function header(f)
    f.accent = W.Texture(f, "ARTWORK", 2)
    f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2)
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT"); h:SetPoint("TOPRIGHT"); h:SetHeight(HEADER_H)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    h.icon = W.Icon(h, "bugs", 20, "accent.primary")
    h.icon:SetPoint("LEFT", 20, 0)
    h.title = W.Text(h, "title", "text.primary")
    h.title:SetPoint("LEFT", h.icon, "RIGHT", 10, 0)
    h.title:SetText(L.BUGS_VIEWER)
    h.badge = W:Badge(h, "", "state.danger", "bugs")
    h.badge:SetPoint("LEFT", h.title, "RIGHT", 12, 0)
    h.close = W:IconButton(h, "close", 28, L.CLOSE)
    h.close.danger = true
    h.close:SetPoint("RIGHT", -12, 0)
    h.close.onClick = function() f:Hide() end
    h.session = W:Dropdown(h, SESSIONS, nil, 170)
    h.session:SetPoint("RIGHT", h.close, "LEFT", -10, 0)
    h.session:SetValue(view.session)
    h.session.onChange = function(_, v) view.session = v; view.index = 1; view.offset = 0; f:Refresh() end
    h.search = W:Input(h, 200, L.BUGS_SEARCH)
    h.search:SetPoint("RIGHT", h.session, "LEFT", -10, 0)
    h.search.onTextChanged = function(_, text) view.query = text; view.index = 1; view.offset = 0; f:Refresh() end
    h.searchIcon = W.Icon(h.search, "search", 12, "text.muted")
    h.searchIcon:SetPoint("RIGHT", -9, 0)
    Skin:Register(h, function(self)
        Skin:Text(self.title, "title", "text.primary")
        f.accent:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(f.accent, "HORIZONTAL", "accent.primary", "accent.secondary")
    end)
    f.header = h
end

local function listPane(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 12, -HEADER_H)
    p:SetPoint("BOTTOMLEFT", 12, FOOTER_H)
    p:SetWidth(LIST_W)
    p.rows = {}
    for i = 1, ROWS do p.rows[i] = buildRow(p, i) end
    p.track = W.Texture(p, "OVERLAY", 1)
    p.track:SetPoint("TOPRIGHT", -2, 0); p.track:SetPoint("BOTTOMRIGHT", -2, 0); p.track:SetWidth(3)
    p.thumb = W.Texture(p, "OVERLAY", 2)
    p.thumb:SetWidth(3)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, #view.list - ROWS)
        view.offset = math.max(0, math.min(maxOffset, view.offset - delta * 2))
        f:RenderList()
    end)
    p.empty = CreateFrame("Frame", nil, p)
    p.empty:SetAllPoints()
    p.empty.icon = W.Icon(p.empty, "success", 36, "state.success")
    p.empty.icon:SetPoint("CENTER", 0, 24)
    p.empty.text = W.Text(p.empty, "body", "text.secondary", "CENTER")
    p.empty.text:SetPoint("TOP", p.empty.icon, "BOTTOM", 0, -12)
    p.empty.text:SetWidth(LIST_W - 40)
    p.empty.text:SetText(L.BUGS_EMPTY)
    Skin:Register(p, function(self)
        Skin:Panel(self, "sunken", { border = "border.subtle" })
        W.Color(self.track, "border.subtle", 0.5)
        W.Color(self.thumb, "border.strong")
        Skin:Text(self.empty.text, "body", "text.secondary")
    end)
    f.listPane = p
end

local function detailPane(f)
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPLEFT", f.listPane, "TOPRIGHT", 12, 0)
    d:SetPoint("BOTTOMRIGHT", -12, FOOTER_H)
    d.kind = W:Badge(d, "", "state.danger", "error")
    d.kind:SetPoint("TOPLEFT", 4, -4)
    d.source = W:Badge(d, "", "accent.primary", "addon")
    d.source:SetPoint("LEFT", d.kind, "RIGHT", 8, 0)
    d.count = W:Badge(d, "", "text.secondary")
    d.count:SetPoint("LEFT", d.source, "RIGHT", 8, 0)
    d.seen = W.Text(d, "small", "text.muted", "RIGHT")
    d.seen:SetPoint("TOPRIGHT", -4, -6)
    d.message = W.Text(d, "body", "text.primary")
    d.message:SetPoint("TOPLEFT", 4, -30)
    d.message:SetPoint("RIGHT", -4, 0)
    d.message:SetWordWrap(true)
    d.message:SetMaxLines(4)
    d.area = W:TextArea(d, 400, 200)
    d.area:SetPoint("TOPLEFT", d.message, "BOTTOMLEFT", 0, -12)
    d.area:SetPoint("BOTTOMRIGHT")
    d.area.edit:HookScript("OnEscapePressed", function() f:Hide() end)
    Skin:Register(d, function(self)
        Skin:Text(self.message, "body", "text.primary")
        Skin:Text(self.seen, "small", "text.muted")
    end)
    f.detail = d
end

local function footer(f)
    local b = CreateFrame("Frame", nil, f)
    b:SetPoint("BOTTOMLEFT", 12, 10); b:SetPoint("BOTTOMRIGHT", -12, 10); b:SetHeight(30)
    b.prev = W:IconButton(b, "chevron-left", 28, L.BUGS_PREV)
    b.prev:SetPoint("LEFT")
    b.prev.onClick = function() f:Select(view.index - 1) end
    b.position = W.Text(b, "number", "text.secondary", "CENTER")
    b.position:SetPoint("LEFT", b.prev, "RIGHT", 4, 0)
    b.position:SetWidth(64)
    b.next = W:IconButton(b, "chevron-right", 28, L.BUGS_NEXT)
    b.next:SetPoint("LEFT", b.position, "RIGHT", 4, 0)
    b.next.onClick = function() f:Select(view.index + 1) end
    b.status = W.Text(b, "small", "text.muted")
    b.status:SetPoint("LEFT", b.next, "RIGHT", 14, 0)
    b.status:SetPoint("RIGHT", -380, 0)
    b.status:SetWordWrap(false)
    b.clear = W:Button(b, L.BUGS_CLEAR, "danger", "delete", 120)
    b.clear:SetPoint("RIGHT")
    b.clear.onClick = function()
        Errors:Clear(view.session == "all" and "all" or "session")
        view.index, view.offset = 1, 0
        M:Refresh()
    end
    b.copy = W:Button(b, L.BUGS_COPY, "primary", "copy", 120)
    b.copy:SetPoint("RIGHT", b.clear, "LEFT", -8, 0)
    b.copy.onClick = function()
        local e = f.detail.area.edit
        e:SetFocus()
        e:HighlightText()
        b.status:SetText(L.BUGS_COPY_HINT)
    end
    b.upload = W:Button(b, L.BUGS_UPLOAD, "ghost", "upload", 120)
    b.upload:SetPoint("RIGHT", b.copy, "LEFT", -8, 0)
    b.upload.onClick = function() f:Hide(); ns.Config:Show(M.key) end
    Skin:Register(b, function(self)
        Skin:Text(self.position, "number", "text.secondary")
        Skin:Text(self.status, "small", "text.muted")
    end)
    f.footer = b
end

local function build()
    local f = CreateFrame("Frame", "PhoenixUI_Bugs", UIParent) -- name required by UISpecialFrames (Esc to close)
    tinsert(UISpecialFrames, "PhoenixUI_Bugs")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    Skin:Register(f, function(self) Skin:Panel(self, "raised", { border = "border.strong", shadow = 18, sheen = 30 }) end)
    header(f)
    listPane(f)
    detailPane(f)
    footer(f)

    function f:RenderList()
        local p = self.listPane
        for i, row in ipairs(p.rows) do
            local li = view.offset + i
            fillRow(row, view.list[li], view.list[li] and li or nil)
        end
        p.empty:SetShown(#view.list == 0)
        local total = #view.list
        if total > ROWS then
            local h = p:GetHeight()
            local thumbH = math.max(24, h * ROWS / total)
            p.thumb:SetHeight(thumbH)
            p.thumb:ClearAllPoints()
            p.thumb:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -(h - thumbH) * view.offset / (total - ROWS))
            p.track:Show(); p.thumb:Show()
        else
            p.track:Hide(); p.thumb:Hide()
        end
    end

    function f:RenderDetail()
        local d, r = self.detail, view.list[view.index]
        d:SetShown(r ~= nil)
        local b = self.footer
        b.position:SetText(r and ("%d / %d"):format(view.index, #view.list) or "0 / 0")
        W.SetEnabledState(b.prev, r ~= nil and view.index > 1)
        W.SetEnabledState(b.next, r ~= nil and view.index < #view.list)
        W.SetEnabledState(b.copy, r ~= nil)
        W.SetEnabledState(b.clear, #view.list > 0)
        if not r then return end
        local k = kindOf(r)
        d.kind:Set(L[k.label], k.token)
        ns.Icons:Apply(d.kind.icon, k.icon, 10)
        ns.Icons:Tint(d.kind.icon, k.token)
        d.source:Set(r.source, r.source == "Blizzard" and "state.info" or "accent.primary")
        d.count:Set(L.BUGS_COUNT:format(r.count), "text.secondary")
        d.seen:SetText(L.BUGS_SEEN:format(stamp(r.firstSeen), stamp(r.lastSeen)))
        d.message:SetText(r.message)
        d.area:SetValue(reportText(r))
    end

    function f:Select(i)
        if #view.list == 0 then view.index = 0 else view.index = math.max(1, math.min(#view.list, i)) end
        if view.index > 0 then
            if view.index <= view.offset then view.offset = view.index - 1 end
            if view.index > view.offset + ROWS then view.offset = view.index - ROWS end
        end
        self.footer.status:SetText("")
        self:RenderList()
        self:RenderDetail()
    end

    function f:Refresh()
        local selected = view.list[view.index]
        view.list = collect()
        local index = 1
        for i, r in ipairs(view.list) do if r == selected then index = i end end
        local unique, total = M:Counts()
        self.header.badge:Set(L.BUGS_BADGE:format(unique, total), unique > 0 and "state.danger" or "state.success")
        self.footer.status:SetText(Errors.dropped > 0 and L.BUGS_DROPPED:format(Errors.dropped) or "")
        self:Select(index)
    end

    function f:Open()
        self:Show()
        self:Raise()
        self:Refresh()
    end

    ns.Events:Listen("PUI_BUG", f, function() if f:IsShown() then f:Refresh() end end)
    f:Hide()
    return f
end

-- The window is created on first use.
function M:GetViewer()
    if not V then
        V = build()
        self.viewerFrame = V
    end
    return V
end
