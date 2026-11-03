local _, ns = ...
local Skin = ns.Skin
local M = ns:GetModule("Skins")

--[[ PvP scoreboard and match results, skins plan window 25: both windows in the Phoenix dialog look, the score
    table on a sunken card, every column header on a sunken cell (the one you sorted by last in the accent), each
    player row as a dense Phoenix row with a team-coloured bar (the colour is read back from Blizzard's own row art,
    which is faded), your own row outlined in the accent once the match is over, and Leave / Requeue as Phoenix
    buttons. Sorting, clicks, class icons, names and rewards stay Blizzard's; nothing reads a unit or a GUID.
    Live with Skins > PvP scoreboard. ]]

local function on() return M:IsEnabled() and M.db.pvpMatch and true or false end

-- Blizzard's table chrome on the content panel (the corner and edge pieces of its inner border).
M.PVP_MATCH_ART = { "Background", "background", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft",
    "InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" }

-- Each window keeps its pieces under its own key case (scoreboard: Content.ScrollBox, results: content.scrollBox).
local LAYOUTS = {
    PVPMatchScoreboard = { content = "Content", box = "ScrollBox", headers = "ScrollCategories", tabs = "TabContainer",
        group = "TabGroup", tab = "Tab" },
    PVPMatchResults = { content = "content", box = "scrollBox", headers = "scrollCategories", tabs = "tabContainer",
        group = "tabGroup", tab = "tab" },
}

local function art(frame, isOn)
    for _, key in ipairs(M.PVP_MATCH_ART) do
        local r = type(frame) == "table" and rawget(frame, key)
        if type(r) == "table" and r.SetAlpha then
            if isOn then Skin:HideRegion(r) else Skin:Restore(r) end
        end
    end
end

-- The window's own full-size background art has no key; it is found by its atlas.
local function rootArt(frame, isOn)
    if not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        local atlas = r.GetAtlas and r:GetAtlas()
        if atlas == "groupfinder-background" then
            if isOn then Skin:HideRegion(r) else Skin:Restore(r) end
        end
    end
end

-- Your row: Blizzard gives it its own background colour once the match is over (PVPMatchUtil.UpdateDataProvider).
local function isYou(row)
    local mine = rawget(_G, "PVP_SCOREBOARD_ALLIANCE_ALT_ROW_COLOR")
    return mine ~= nil and rawget(row, "backgroundColor") == mine
end

local function teamColor(row)
    local left = rawget(row, "backgroundLeft")
    if type(left) ~= "table" or not left.GetVertexColor then return nil end
    local r, g, b = left:GetVertexColor()
    if type(r) ~= "number" then return nil end
    return { r = r, g = g, b = b }
end

local function dressRow(row, isOn)
    local bgs = rawget(row, "Backgrounds")
    if type(bgs) == "table" then
        for _, t in pairs(bgs) do
            if type(t) == "table" and t.SetAlpha then
                if isOn then Skin:HideRegion(t) else Skin:Restore(t) end
            end
        end
    end
    M.KitRow(row, isOn, { alpha = 0.4, bar = true, barColor = teamColor(row), selected = isYou(row) })
end

local sortedBy = setmetatable({}, { __mode = "k" }) -- [header container] = header button
local hookedHeaders = setmetatable({}, { __mode = "k" })
local function headers(frame, hc, isOn)
    if type(hc) ~= "table" or not hc.GetChildren then return end
    for _, h in ipairs({ hc:GetChildren() }) do
        local card = M.KitCard(h, isOn, "sunken", false)
        if card and isOn then Skin:SetBorderColor(card, sortedBy[hc] == h and "accent.primary" or "border.subtle") end
        if not hookedHeaders[h] and h.HookScript and h.GetObjectType and h:GetObjectType() == "Button" then
            hookedHeaders[h] = true
            h:HookScript("OnClick", function(self) sortedBy[hc] = self; headers(frame, hc, on()) end)
        end
    end
end

function M:SkinPvPMatch()
    local isOn = on()
    for name, k in pairs(LAYOUTS) do
        local frame = rawget(_G, name)
        if frame then
            rootArt(frame, isOn)
            local content = M.FramePath(frame, { k.content })
            if content then
                art(content, isOn)
                M.KitCard(content, isOn, "sunken", false)
                local tc = rawget(content, k.tabs)
                if tc then art(tc, isOn) end
                local group = tc and rawget(tc, k.group)
                if group then
                    M.SkinTabList({ rawget(group, k.tab .. "1"), rawget(group, k.tab .. "2"), rawget(group, k.tab .. "3") }, isOn)
                end
                headers(frame, rawget(content, k.headers), isOn)
                M.KitScrollBox(M.FramePath(content, { k.box }), on, dressRow)
            end
        end
    end
    local res = rawget(_G, "PVPMatchResults")
    local bc = res and rawget(res, "buttonContainer")
    if bc then
        M.SkinPopupButton(rawget(bc, "leaveButton"), "primary", isOn)
        M.SkinPopupButton(rawget(bc, "requeueButton"), "secondary", isOn)
    end
end

local hooked = setmetatable({}, { __mode = "k" })
function M:SetupPvPMatch()
    self:SkinPvPMatch()
    for name in pairs(LAYOUTS) do
        local frame = rawget(_G, name)
        if frame and not hooked[frame] then
            hooked[frame] = true
            frame:HookScript("OnShow", function() M:SkinPvPMatch() end)
            -- the table builder makes the column headers in Init (each new match), after OnShow has run
            if type(frame.Init) == "function" then hooksecurefunc(frame, "Init", function() M:SkinPvPMatch() end) end
        end
    end
end
M.SETUPS[#M.SETUPS + 1] = "SetupPvPMatch"
M.RESKINS[#M.RESKINS + 1] = "SkinPvPMatch"
