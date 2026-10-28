local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local M = ns:GetModule("Movers")

--[[ Settings popup on a mover box (the cog on each box in Layout mode): the selected frame's most-used size and
    layout settings, edited live through ns.DB:Set (the same path the options window takes), plus "All settings"
    to open the full options page. Frames without a known set get scale, opacity and the full-page button. ]]
local SETS = {
    ab = { module = "ActionBars", root = "bars", rows = {
        { "buttons", "AB_BUTTONS", 1, 12, 1 }, { "rows", "AB_ROWS", 1, 12, 1 }, { "width", "AB_WIDTH", 16, 120, 1 },
        { "spacingX", "AB_SPACING_X", 0, 20, 1 }, { "spacingY", "AB_SPACING_Y", 0, 20, 1 } } },
    uf = { module = "UnitFrames", root = "units", rows = {
        { "width", "UF_WIDTH", 60, 400, 1 }, { "height", "UF_HEIGHT", 10, 120, 1 } } },
    cb = { module = "CastBars", root = "bars", rows = {
        { "width", "UF_WIDTH", 60, 600, 1 }, { "height", "UF_HEIGHT", 6, 60, 1 } } },
}
M.POPUP_SETS = SETS

-- For a mover key ("ab.bar2"): module, db path prefix ("bars.bar2") and the rows that exist in the saved data.
function M.PopupSpec(e)
    local prefix, element = (e and e.key or ""):match("^(%a+)%.(.+)$")
    local set = prefix and SETS[prefix]
    local m = set and ns.modules[set.module]
    local data = m and m.db and m.db[set.root] and m.db[set.root][element]
    if type(data) ~= "table" then return nil end
    local rows = {}
    for _, r in ipairs(set.rows) do if type(data[r[1]]) == "number" then rows[#rows + 1] = r end end
    return { module = m, path = set.root .. "." .. element, rows = rows, data = data }
end

local POINTS = {}
for _, pt in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
    POINTS[#POINTS + 1] = { value = pt, label = L["ANCHOR_" .. pt] }
end

local popup, row
local function build()
    local p = CreateFrame("Frame", "PhoenixUI_MoverPopup", UIParent)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetWidth(280)
    p.title = W.Text(p, "heading", "text.primary")
    p.title:SetPoint("TOPLEFT", 12, -10)
    p.close = W:IconButton(p, "close", 18, L.CLOSE)
    p.close:SetPoint("TOPRIGHT", -6, -6)
    p.close.onClick = function() p:Hide() end
    p.rows = {}
    -- exact position: anchor point and X / Y offsets (UIParent units), applied live
    p.anchor = W:Dropdown(p, POINTS, nil, 256)
    p.anchorLabel = W.Text(p, "body", "text.secondary")
    p.anchorLabel:SetText(L.AB_ANCHOR)
    p.x, p.y = row(p, "x"), row(p, "y")
    p.x.label:SetText(L.OFFSET_X); p.y.label:SetText(L.OFFSET_Y)
    p.all = W:Button(p, L.MOVERS_SETTINGS, "secondary", "cog", 256)
    Skin:Register(p, function(self) Skin:Panel(self, "raised", { border = "border.strong", shadow = 12 }) end)
    p:Hide()
    return p
end

function row(p, i)
    local r = p.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, p)
    r:SetSize(256, 40)
    r.label = W.Text(r, "body", "text.secondary")
    r.label:SetPoint("TOPLEFT", 0, 0)
    r.slider = W:Slider(r, 0, 1, 1)
    r.slider:SetWidth(256)
    r.slider:SetPoint("TOPLEFT", 0, -16)
    p.rows[i] = r
    return r
end

function M:OpenPopup(e, anchor)
    popup = popup or build()
    local spec = M.PopupSpec(e)
    popup.title:SetText(M:LabelOf(e) or e.key)
    local y = -34
    for _, r in ipairs(popup.rows) do r:Hide() end
    for i, def in ipairs(spec and spec.rows or {}) do
        local r = row(popup, i)
        local key, label, lo, hi, step = def[1], def[2], def[3], def[4], def[5]
        r.label:SetText(L[label])
        r.slider.min, r.slider.max, r.slider.step = lo, hi, step
        r.slider:SetValue(spec.data[key])
        r.slider.onChange = function(_, v)
            if InCombatLockdown() then return end
            ns.DB:Set(spec.module, spec.path .. "." .. key, v)
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 12, y)
        r:Show()
        y = y - 44
    end
    y = M.PlacePositionRows(popup, e, y)
    popup.all:ClearAllPoints()
    popup.all:SetPoint("TOPLEFT", 12, y - 4)
    popup.all.onClick = function()
        local page = M.SettingsPageOf and M.SettingsPageOf(e)
        popup:Hide()
        if page and ns.Config and ns.Config.Show then ns.Config:Show(page) end
    end
    popup:SetHeight(-y + 44)
    popup:ClearAllPoints()
    if anchor then popup:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0) else popup:SetPoint("CENTER") end
    popup.entry, popup.spec = e, spec
    popup:Show()
    return popup
end

-- Anchor + X / Y rows under the size rows; returns the next y. Hidden for frames that cannot be placed (combat).
function M.PlacePositionRows(p, e, y)
    local pos = M.PositionOf(e)
    p.anchor:SetShown(pos ~= nil); p.anchorLabel:SetShown(pos ~= nil); p.x:SetShown(pos ~= nil); p.y:SetShown(pos ~= nil)
    if not pos then return y end
    local sw, sh = math.floor(UIParent:GetWidth()), math.floor(UIParent:GetHeight())
    p.anchorLabel:ClearAllPoints(); p.anchorLabel:SetPoint("TOPLEFT", 12, y)
    p.anchor:ClearAllPoints(); p.anchor:SetPoint("TOPLEFT", 12, y - 16)
    p.anchor:SetValue(pos.point)
    p.anchor.onChange = function(_, v)
        if InCombatLockdown() then return end
        M.SetPosition(e, v, 0, 0) -- a new anchor starts on that edge; the offsets read 0, 0
        p.x.slider:SetValue(0); p.y.slider:SetValue(0)
    end
    y = y - 50
    for _, it in ipairs({ { p.x, "x", sw }, { p.y, "y", sh } }) do
        local r, key, span = it[1], it[2], it[3]
        r.slider.min, r.slider.max, r.slider.step = -span, span, 1
        r.slider:SetValue(pos[key])
        r.slider.onChange = function(_, v)
            if InCombatLockdown() then return end
            if key == "x" then M.SetPosition(e, nil, v, nil) else M.SetPosition(e, nil, nil, v) end
        end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 12, y); r:Show()
        y = y - 44
    end
    return y
end

function M:ClosePopup() if popup then popup:Hide() end end
