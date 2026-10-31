local _, ns = ...
local L = ns.L
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Skins")

--[[ Reputation and currency tabs of the character sheet (plan window 6): reputation rows as progress rows
    (the bar in the theme's texture over a sunken track with a 1 px border; the standing colour stays the
    game's), header rows in the accent, and currency rows on a subtle stripe with a search field above the
    list that dims the rows that do not match (an overlay of ours; the list, its data and currency transfer
    stay Blizzard's). Rows are dressed after each ScrollBox update (post-hook), live with Skins > Character. ]]

local rowDeco = setmetatable({}, { __mode = "k" })
local search

-- Does a currency / faction row name match the search text? (plain, case-insensitive; empty = all)
function M.ListMatches(name, text)
    text = tostring(text or ""):lower()
    if text == "" then return true end
    return tostring(name or ""):lower():find(text, 1, true) ~= nil
end

local function textOf(fs)
    return fs and fs.GetText and fs:GetText() or nil
end

local function decoFor(row)
    local d = rowDeco[row]
    if d then return d end
    d = CreateFrame("Frame", nil, row)
    d:SetAllPoints()
    d:SetFrameLevel(row:GetFrameLevel() + 3)
    d.dim = d:CreateTexture(nil, "OVERLAY", nil, 7)
    d.dim:SetTexture(ns.Media.textures.WHITE)
    d.dim:SetAllPoints()
    d.stripe = row:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.stripe:SetTexture(ns.Media.textures.WHITE)
    d.stripe:SetPoint("TOPLEFT", 2, -1); d.stripe:SetPoint("BOTTOMRIGHT", -2, 1)
    rowDeco[row] = d
    return d
end

function M.StyleListRow(row, kind, on)
    if not row then return end
    local d = rowDeco[row]
    if not on then
        if d then
            d:Hide(); d.stripe:Hide()
            local c = row.Content or row
            local bar = c.ReputationBar or row.ReputationBar
            if bar then Skin:Restore(bar) end
            if c.Name then Skin:Restore(c.Name) end
        end
        return
    end
    d = decoFor(row)
    d:Show()
    local c = row.Content or row
    local bar = c.ReputationBar or row.ReputationBar
    local name = c.Name or row.Name or (row.Right and row.Name)
    local header = row.Header or (row.IsCollapsed ~= nil and not bar and kind == "rep")
    if bar and bar.SetStatusBarTexture then Skin:StatusBar(bar, { border = "border.subtle" }) end
    W.Color(d.stripe, "bg.raised", header and 0 or 0.55)
    d.stripe:SetShown(not header)
    if name and name.SetTextColor then
        if header then Skin:Text(name, "heading", "accent.primary") else Skin:Text(name, "body", "text.primary") end
    end
    local match = kind ~= "currency" or M.ListMatches(textOf(name), search and search:GetText())
    W.Color(d.dim, "bg.base", 0.7)
    d.dim:SetShown(not match)
end

local function dressList(scrollBox, kind)
    if not (scrollBox and scrollBox.ForEachFrame) then return end
    local on = M:IsEnabled() and M.db.character and true or false
    scrollBox:ForEachFrame(function(row) M.StyleListRow(row, kind, on) end)
end

function M:SkinCharacterLists()
    local rep, tok = _G.ReputationFrame, _G.TokenFrame
    if rep then dressList(rep.ScrollBox, "rep") end
    if tok then
        local on = self:IsEnabled() and self.db.character and true or false
        if on and not search then
            search = W:Input(tok, 180, L.SEARCH_PLACEHOLDER)
            search:SetPoint("TOPRIGHT", tok, "TOPRIGHT", -12, -32)
            search.onTextChanged = function() dressList(tok.ScrollBox, "currency") end
        end
        if search then search:SetShown(on) end
        if search and not on then search:SetValue("") end
        dressList(tok.ScrollBox, "currency")
    end
end

local listsHooked
function M:SetupCharacterLists()
    self:SkinCharacterLists()
    if listsHooked then return end
    local rep, tok = _G.ReputationFrame, _G.TokenFrame
    if not (rep or tok) then return end
    listsHooked = true
    for _, pair in ipairs({ { rep, "rep" }, { tok, "currency" } }) do
        local frame, kind = pair[1], pair[2]
        local box = frame and frame.ScrollBox
        if box and box.Update then hooksecurefunc(box, "Update", function(b) dressList(b, kind) end) end
        if frame then frame:HookScript("OnShow", function() M:SkinCharacterLists() end) end
    end
    ns.Events:Listen("PUI_THEME_CHANGED", rowDeco, function() M:SkinCharacterLists() end)
end
