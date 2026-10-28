local _, ns = ...
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Skins")

--[[ Shared kit for the dedicated window skins (plan "shared kit"): list rows as Phoenix rows (a subtle stripe,
    the soft accent on hover, a 1 px accent outline on the selected row, optional accent bar), cards behind
    a Blizzard region, and ScrollBox lists dressed after every Update (post-hook). Every piece is a frame or
    texture of ours on a weak side table; Blizzard rows, scripts and data stay untouched, so secure clicks
    inside lists keep working. `on` is passed in by each window from its own switch, so everything here can
    be taken off and put back live. ]]

local rows = setmetatable({}, { __mode = "k" })
local cards = setmetatable({}, { __mode = "k" })
local hookedBoxes = setmetatable({}, { __mode = "k" })

-- Is a Blizzard list row the selected one? Reads only shown-state of the row's own selection art.
function M.RowSelected(row)
    if not row then return false end
    for _, k in ipairs({ "Selected", "SelectedTexture", "SelectedHighlight", "selectedTexture", "Selection" }) do
        local r = row[k]
        if type(r) == "table" and r.IsShown and r:IsShown() then return true end
    end
    if row.IsSelected and type(row.IsSelected) == "function" then
        local ok, v = pcall(row.IsSelected, row)
        if ok and v == true then return true end
    end
    return false
end

local function paintRow(row)
    local d = rows[row]
    if not d then return end
    local sel = M.RowSelected(row)
    W.Color(d.stripe, (d.hover or sel) and "accent.primary" or "bg.raised", (d.hover or sel) and 0.14 or d.alpha)
    Skin:SetBorderColor(d, sel and "accent.primary" or "border.subtle")
    d.edge:SetShown(sel or d.bar or false)
    if d.barColor then d.edge:SetVertexColor(d.barColor.r, d.barColor.g, d.barColor.b, 1) else W.Color(d.edge, "accent.primary", 1) end
end
M.PaintKitRow = paintRow

-- opts: alpha (stripe strength), bar = true (always show the left bar), barColor = { r, g, b } (e.g. quality)
function M.KitRow(row, on, opts)
    if type(row) ~= "table" or not row.CreateTexture then return end
    local d = rows[row]
    if not on then if d then d:Hide(); d.stripe:Hide() end; return end
    opts = opts or {}
    if not d then
        d = CreateFrame("Frame", nil, row)
        d:SetAllPoints()
        d:SetFrameLevel(math.max(0, row:GetFrameLevel() - 1))
        d.stripe = row:CreateTexture(nil, "BACKGROUND", nil, -7)
        d.stripe:SetTexture(ns.Media.textures.WHITE)
        d.stripe:SetPoint("TOPLEFT", 1, -1); d.stripe:SetPoint("BOTTOMRIGHT", -1, 1)
        d.edge = d:CreateTexture(nil, "ARTWORK", nil, 3)
        d.edge:SetTexture(ns.Media.textures.WHITE)
        d.edge:SetPoint("TOPLEFT", 1, -1); d.edge:SetPoint("BOTTOMLEFT", 1, 1); d.edge:SetWidth(2)
        Skin:Border(d, "border.subtle")
        rows[row] = d
        if row.HookScript then
            row:HookScript("OnEnter", function(self) if rows[self] then rows[self].hover = true; paintRow(self) end end)
            row:HookScript("OnLeave", function(self) if rows[self] then rows[self].hover = false; paintRow(self) end end)
        end
    end
    d.alpha, d.bar, d.barColor = opts.alpha or 0.5, opts.bar, opts.barColor
    d:Show(); d.stripe:Show()
    paintRow(row)
end

-- A Phoenix card behind `frame` (style "raised" | "sunken", accent = outline in the accent).
function M.KitCard(frame, on, style, accent)
    if type(frame) ~= "table" or not frame.GetFrameLevel then return end
    local c = cards[frame]
    if not on then if c then c:Hide() end; return end
    if not c then
        c = CreateFrame("Frame", nil, frame)
        c:SetAllPoints()
        c:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        cards[frame] = c
    end
    Skin:Panel(c, style or "sunken", { border = accent and "accent.primary" or "border.subtle" })
    c:Show()
    return c
end

-- Dress every visible row of a ScrollBox now and after each of its updates. fn(row, on).
function M.KitScrollBox(box, isOn, fn)
    if type(box) ~= "table" or type(box.ForEachFrame) ~= "function" then return end
    local function run(b) local on = isOn(); b:ForEachFrame(function(row) fn(row, on) end) end
    if not hookedBoxes[box] and box.Update then
        hookedBoxes[box] = true
        hooksecurefunc(box, "Update", run)
    end
    run(box)
end

-- Walk `path` from `root`. When the root exists but a step is missing, the full path is remembered in
-- M.missingFrames (the dev self-test reports it: a list that stays unstyled after a client rename).
M.missingFrames = {}
local function rootName(root)
    if root == _G then return "_G" end
    local ok, n = pcall(function() return root.GetName and root:GetName() end)
    return ok and n or "?"
end
function M.FramePath(root, path)
    local f = root
    for i, k in ipairs(path) do
        if type(f) ~= "table" then
            if type(root) == "table" then M.missingFrames[rootName(root) .. "." .. table.concat(path, ".")] = i end
            return nil
        end
        f = f[k]
    end
    if f == nil and type(root) == "table" then
        M.missingFrames[rootName(root) .. "." .. table.concat(path, ".")] = #path
    elseif f ~= nil and type(root) == "table" then
        M.missingFrames[rootName(root) .. "." .. table.concat(path, ".")] = nil
    end
    return f
end

-- Sorted list of the frame paths a skin looked for and did not find (dev self-test).
function M.MissingSkinFrames()
    local out = {}
    for k in pairs(M.missingFrames) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Repaint every kit row on theme change (one listener for the kit).
ns.Events:Listen("PUI_THEME_CHANGED", rows, function()
    for row in pairs(rows) do if rows[row]:IsShown() then paintRow(row) end end
end)
