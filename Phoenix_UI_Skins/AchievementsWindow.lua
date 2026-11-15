local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns:GetModule("Skins")

--[[ The Phoenix achievements window: our own achievement browser fed by the achievement API. A category rail
    (top-level categories, the picked one opens its sub-categories), the category's achievements as Phoenix
    rows (the achievement's own icon, name, description, points, completion date or progress fill), a search
    over the shown category and your total points. Shift-click links an achievement in chat. Tabs: Summary
    (latest achievements and each category's completed / total; click one to open it), Achievements, Guild
    (the guild categories) and Statistics (the game's value text, shown as is).
    Skins > "Phoenix achievements window" off: Blizzard's window, reskinned, live. ]]

local RAIL_W, LIST_W, ROWS, ROW_H = 190, 470, 10, 44
local r, rail, list
local category, parentOpen, search, mode = nil, nil, "", "player"

local LISTS = { player = "GetCategoryList", guild = "GetGuildCategoryList", stats = "GetStatisticsCategoryList",
    summary = "GetCategoryList" }

-- Categories as { id, name, parent } (parent -1 = top level) for the tab (player / guild / stats).
function M.AchievementCategories(which)
    local out = {}
    local fn = _G[LISTS[which or mode] or "GetCategoryList"]
    local ids = type(fn) == "function" and fn() or {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local name, parent = GetCategoryInfo(id)
        if name then out[#out + 1] = { id = id, name = tostring(name), parent = tonumber(parent) or -1 } end
    end
    return out
end

-- Rail entries: every top-level category, with the open one's children right under it.
function M.AchievementRail(cats, open)
    local out = {}
    for _, c in ipairs(cats) do
        if c.parent == -1 then
            out[#out + 1] = c
            if c.id == open then
                for _, k in ipairs(cats) do
                    if k.parent == c.id then out[#out + 1] = { id = k.id, name = k.name, parent = c.id, child = true } end
                end
            end
        end
    end
    return out
end

-- One achievement as plain values with progress 0..1 from its first counted criterion.
function M.AchievementRecord(cat, i)
    local id, name, points, completed, month, day, year, desc, _, icon = GetAchievementInfo(cat, i)
    if not id then return nil end
    local rec = { id = id, name = tostring(name or ""), points = tonumber(points) or 0, completed = completed and true or false,
        desc = tostring(desc or ""), icon = icon, progress = 0 }
    if rec.completed and month then rec.date = ("%02d/%02d/%02d"):format(tonumber(day) or 0, tonumber(month) or 0, tonumber(year) or 0)
    elseif GetAchievementNumCriteria and (tonumber(GetAchievementNumCriteria(id)) or 0) > 0 then
        local _, _, _, have, need = GetAchievementCriteriaInfo(id, 1)
        have, need = tonumber(have) or 0, tonumber(need) or 0
        if need > 1 then rec.progress, rec.count = have / need, ("%d / %d"):format(have, need) end
    end
    return rec
end

-- One statistic row: name and the game's value text (shown as is).
function M.StatisticRecord(cat, i)
    local id, name = GetAchievementInfo(cat, i)
    if not id then return nil end
    local value = GetStatistic(id)
    return { id = id, name = tostring(name or ""), value = value ~= nil and tostring(value) or "--", stat = true }
end

-- Summary: your latest achievements, then each top-level category's completed / total.
function M.AchievementSummary()
    local out = {}
    local latest = { GetLatestCompletedAchievements() }
    for _, id in ipairs(latest) do
        local _, name, points, _, month, day, year, desc, _, icon = GetAchievementInfo(id)
        if name then
            out[#out + 1] = { id = id, name = tostring(name), desc = tostring(desc or ""), icon = icon, completed = true,
                points = tonumber(points) or 0, progress = 1,
                date = ("%02d/%02d/%02d"):format(tonumber(day) or 0, tonumber(month) or 0, tonumber(year) or 0) }
        end
    end
    for _, c in ipairs(M.AchievementCategories("player")) do
        if c.parent == -1 then
            local total, done = GetCategoryNumAchievements(c.id, true)
            total, done = tonumber(total) or 0, tonumber(done) or 0
            if total > 0 then
                out[#out + 1] = { category = c.id, name = c.name, desc = "", completed = done >= total, points = 0,
                    progress = done / total, count = ("%d / %d"):format(done, total) }
            end
        end
    end
    return out
end

local function achievements()
    local out = {}
    if mode == "summary" then return M.AchievementSummary() end
    if not category then return out end
    if mode == "stats" then
        for i = 1, (tonumber((GetCategoryNumAchievements(category))) or 0) do out[#out + 1] = M.StatisticRecord(category, i) end
        return out
    end
    local n = tonumber((GetCategoryNumAchievements(category, true))) or 0
    local needle = search:lower()
    for i = 1, n do
        local rec = M.AchievementRecord(category, i)
        if rec and (needle == "" or rec.name:lower():find(needle, 1, true)) then out[#out + 1] = rec end
    end
    return out
end

local function layout()
    r.tabs.Paint(mode)
    local cats = mode == "summary" and {} or M.AchievementCategories()
    local valid
    for _, c in ipairs(cats) do if c.id == category then valid = true end end
    if not valid then category = cats[1] and cats[1].id end
    rail.Set(M.AchievementRail(cats, parentOpen), function(b, c)
        b.title:SetText(c.child and ("   " .. c.name) or c.name)
        b.sub:SetText("")
        b.right:SetText("")
        if c.id == category then rail.Mark(b, "accent.primary", 0.25); rail.Bar(b, "accent.primary") end
    end)
    list.Set(achievements(), function(b, a)
        if a.stat then
            b.icon:SetTexture(nil)
            b.title:SetText(a.name); b.sub:SetText(""); b.right:SetText(a.value)
            return
        end
        b.icon:SetTexture(a.icon)
        b.icon:SetDesaturated(not a.completed)
        b.title:SetText(a.name)
        b.sub:SetText(a.desc)
        b.right:SetText(a.date or a.count or (a.points > 0 and tostring(a.points) or ""))
        if a.category then list.Progress(b, a.progress); return end
        if a.completed then list.Bar(b, "accent.primary") else list.Progress(b, a.progress) end
    end)
    r.points:SetText(L.ACHW_POINTS:format(tonumber(GetTotalAchievementPoints and GetTotalAchievementPoints()) or 0))
end

local function build(rr)
    r = rr
    rail = M.ReplaceList(r.body, ROWS + 4, 30, RAIL_W)
    rail:SetPoint("TOPLEFT", 0, -30)
    rail.onClick = function(c)
        category = c.id
        if not c.child then parentOpen = (parentOpen == c.id) and nil or c.id end
        list.offset = 0
        r:Layout()
    end
    list = M.ReplaceList(r.body, ROWS, ROW_H, LIST_W, 32)
    list:SetPoint("TOPLEFT", RAIL_W + 10, -30)
    list.onClick = function(a)
        if a.category then mode, category, parentOpen = "player", a.category, a.category; list.offset = 0; r:Layout(); return end
        if IsModifiedClick("CHATLINK") and GetAchievementLink then ChatFrameUtil.InsertLink(GetAchievementLink(a.id)) end
    end
    list.onEnter = function(a, b)
        if not a.id or a.stat then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(GetAchievementLink(a.id))
        GameTooltip:Show()
    end
    r.tabs = M.ReplaceTabs(r.body, { { key = "summary", label = L.ACHW_SUMMARY }, { key = "player", label = L.ACHW_TITLE },
        { key = "guild", label = L.ACHW_GUILD }, { key = "stats", label = L.ACHW_STATS } }, 100,
        function(key) mode, category, parentOpen, list.offset, rail.offset = key, nil, nil, 0, 0; r:Layout() end)
    r.search = W:Input(r.body, 180, SEARCH or "")
    r.search:SetPoint("TOPLEFT", 4 * 104 + 10, 0)
    r.search.onTextChanged = function(_, text) search = text or ""; list.offset = 0; r:Layout() end
    r.points = W.Text(r.body, "body", "accent.primary")
    r.points:SetPoint("TOPRIGHT", 0, -4)
end

local ach = M.Replacement({ key = "ownAchievements", frame = "AchievementFrame", title = L.ACHW_TITLE,
    width = RAIL_W + LIST_W + 30, height = 34 + 30 + ROWS * ROW_H + 30, build = build, layout = layout,
    close = function() if AchievementFrame then HideUIPanel(AchievementFrame) end end })
M.AchievementsReplacement = ach

function M:SetupAchievementsWindow()
    if not M.ReplacementHook(ach) then return end
    ns.Events:On("ACHIEVEMENT_EARNED", ach, function() ach:Soon() end)
    ns.Events:On("CRITERIA_UPDATE", ach, function() ach:Soon() end)
    ach:Sync()
end
function M:SyncAchievements() ach:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupAchievementsWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncAchievements"
