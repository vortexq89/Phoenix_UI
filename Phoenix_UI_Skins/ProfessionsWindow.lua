local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns:GetModule("Skins")

--[[ The Phoenix recipe list: our own list in place of the recipe list on Blizzard's professions window, fed by the
    trade skill API. Categories as collapsible headers, each recipe with its own icon, difficulty colour (skill-up
    chance), how many you can craft now, first-craft and favourite marks, unlearned recipes dimmed; a search box
    and a "learned only" switch. Left-click shows the recipe on Blizzard's crafting page (crafting, reagents,
    quality and orders stay Blizzard's), right-click toggles the favourite, shift-click links it.
    Skins > "Phoenix recipe list" off (or the arrow): Blizzard's list, live. ]]

local ROW_H = 26
local list
local search, learnedOnly, closed = "", false, {}
local DIFF = { [0] = "state.danger", [1] = "state.warning", [2] = "state.success", [3] = "text.muted" } -- optimal..trivial

local function page() local f = _G.ProfessionsFrame; return f and f.CraftingPage end

-- Recipes grouped under their category headers, filtered by search / learned and the open headers.
function M.RecipeRows()
    local out = {}
    local T = _G.C_TradeSkillUI
    if not (T and T.GetFilteredRecipeIDs) then return out end
    local needle = search:lower()
    local byCat, order = {}, {}
    for _, id in ipairs(T.GetFilteredRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(id)
        if type(info) == "table" and info.name and (not learnedOnly or info.learned)
            and (needle == "" or tostring(info.name):lower():find(needle, 1, true)) then
            local cat = info.categoryID or 0
            if not byCat[cat] then byCat[cat] = {}; order[#order + 1] = cat end
            local list_ = byCat[cat]
            list_[#list_ + 1] = { id = id, name = tostring(info.name), icon = info.icon, learned = info.learned and true or false,
                favorite = info.favorite and true or false, count = tonumber(info.numAvailable) or 0,
                first = info.firstCraft and true or false, difficulty = tonumber(info.relativeDifficulty) }
        end
    end
    for _, cat in ipairs(order) do
        local c = T.GetCategoryInfo and T.GetCategoryInfo(cat)
        out[#out + 1] = { header = true, cat = cat, name = tostring(type(c) == "table" and c.name or ""), n = #byCat[cat] }
        if not closed[cat] then for _, rec in ipairs(byCat[cat]) do out[#out + 1] = rec end end
    end
    return out
end

local function selectRecipe(rec)
    local T = _G.C_TradeSkillUI
    local info = T.GetRecipeInfo(rec.id)
    local cp = page()
    if not (info and cp) then return end
    if cp.RecipeList and cp.RecipeList.SelectRecipe then cp.RecipeList:SelectRecipe(info, false)
    elseif cp.SelectRecipe then cp:SelectRecipe(info) end
    M.RecipeSelected = rec.id
end

local function rows(o)
    local p = o.panel
    local h = (tonumber(p:GetHeight()) or 0) > 0 and p:GetHeight() or 520
    return math.max(4, math.floor((h - 70) / ROW_H))
end

local function layout(o)
    local p = o.panel
    if not list or #list.rows ~= rows(o) then
        if list then list:Hide() end
        list = M.ReplaceList(p, rows(o), ROW_H, math.max(160, (tonumber(p:GetWidth()) or 280) - 16), 20)
        list:SetPoint("TOPLEFT", 8, -64)
        list.onClick = function(rec, button)
            if rec.header then closed[rec.cat] = not closed[rec.cat] or nil; o:Layout(); return end
            local T = _G.C_TradeSkillUI
            if IsModifiedClick("CHATLINK") and T.GetRecipeLink then ChatFrameUtil.InsertLink(T.GetRecipeLink(rec.id)); return end
            if button == "RightButton" then T.SetRecipeFavorite(rec.id, not rec.favorite); o:Soon(); return end
            selectRecipe(rec)
            o:Layout()
        end
        list.onEnter = function(rec, b)
            local T = _G.C_TradeSkillUI
            if rec.header or not T.GetRecipeLink then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(T.GetRecipeLink(rec.id))
            GameTooltip:Show()
        end
    end
    p.learned.variant = learnedOnly and "primary" or "secondary"
    p.learned:GetScript("OnLeave")(p.learned)
    list.Set(M.RecipeRows(), function(b, rec)
        if rec.header then
            b.icon:SetTexture(nil)
            b.title:SetText((closed[rec.cat] and "+ " or "- ") .. rec.name)
            b.sub:SetText(""); b.right:SetText(tostring(rec.n))
            list.Mark(b, "bg.hover", 0.8)
            return
        end
        b.icon:SetTexture(rec.icon)
        b.icon:SetDesaturated(not rec.learned)
        b.title:SetText((rec.favorite and "|cffffd100*|r " or "") .. rec.name)
        b.sub:SetText(rec.first and L.PROFW_FIRST or "")
        b.right:SetText(rec.count > 0 and ("[" .. rec.count .. "]") or "")
        if rec.id == M.RecipeSelected then list.Mark(b, "accent.primary", 0.25) end
        if rec.learned and rec.difficulty and DIFF[rec.difficulty] then list.Bar(b, DIFF[rec.difficulty]) end
    end)
end

local function build(o)
    local p = o.panel
    p.search = W:Input(p, 160, SEARCH or "")
    p.search:SetPoint("TOPLEFT", 8, -8)
    p.search.onTextChanged = function(_, text) search = text or ""; if list then list.offset = 0 end; o:Layout() end
    p.learned = W:Button(p, L.PROFW_LEARNED, "secondary", nil, 110)
    p.learned:SetHeight(22)
    p.learned:SetPoint("TOPLEFT", 8, -36)
    p.learned.onClick = function() learnedOnly = not learnedOnly; o:Layout() end
end

local prof = M.Overlay({ key = "ownProfessions", build = build, layout = layout,
    host = function() local cp = page(); return cp and cp.RecipeList end })
M.ProfessionsOverlay = prof
function M.RecipeState(key, value)
    if key == "search" then search = value elseif key == "learned" then learnedOnly = value
    elseif key == "close" then closed[value] = true elseif key == "reset" then search, learnedOnly, closed = "", false, {} end
end

function M:SetupProfessionsWindow()
    if not prof:Hook() then return end
    for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_FAVORITES_CHANGED" }) do
        ns.Events:On(event, prof, function() prof:Soon() end)
    end
    prof:Sync()
end
function M:SyncProfessionsWindow() prof:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupProfessionsWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncProfessionsWindow"
