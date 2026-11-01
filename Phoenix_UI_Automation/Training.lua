-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L, W, Skin, Secret, U = ns.L, ns.Widgets, ns.Skin, ns.Secret, ns.Util
local M = ns.modules.Automation

--[[ Training planner (NaowhForever's training planner): what your class trainer teaches, read from the trainer's
    own list each time you visit one (TRAINER_SHOW / TRAINER_UPDATE) and kept per character. The planner window
    (Automation > Training planner) shows what you can learn now with the total cost, then what comes next by
    level. Only the trainer API's plain values are kept; nothing is bought for you. Profession trainers are kept
    apart, for the recipe list. No timer: it updates on the trainer events. ]]

local OWNER = {}
local ROWS, ROW_H, WIDTH = 16, 20, 360
local win, offset = nil, 0

local function store(kind)
    local g = M.global
    g.training = type(g.training) == "table" and g.training or {}
    local key = U.PlayerKey()
    g.training[key] = type(g.training[key]) == "table" and g.training[key] or {}
    local c = g.training[key]
    c[kind] = type(c[kind]) == "table" and c[kind] or {}
    return c[kind]
end
M.TrainingStore = store

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

-- The trainer's services as plain records { name, rank, level, cost, state } (headers left out).
function M.TrainingRead(count, info, levelOf, costOf, skillOf)
    local out = {}
    for i = 1, count do
        local name, rank, state = info(i)
        if plain(name) and plain(state) and state ~= "header" then
            local level, cost = levelOf and levelOf(i), costOf and costOf(i)
            out[#out + 1] = { name = tostring(name), rank = plain(rank) and rank ~= "" and tostring(rank) or nil,
                level = plain(level) and tonumber(level) or 0, cost = plain(cost) and tonumber(cost) or 0,
                state = tostring(state), skill = skillOf and plain(skillOf(i)) and tostring(skillOf(i)) or nil }
        end
    end
    return out
end

-- Now (learnable at your level) with its cost, later (by level). Learned ones ("used") are left out.
function M.TrainingPlan(list, myLevel)
    local now, later, cost = {}, {}, 0
    for _, s in ipairs(list or {}) do
        if s.state == "available" and (s.level or 0) <= myLevel then
            now[#now + 1] = s
            cost = cost + (s.cost or 0)
        elseif s.state ~= "used" then
            later[#later + 1] = s
        end
    end
    table.sort(later, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end)
    return now, later, cost
end

local function money(v)
    local s = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(v or 0)
    return type(s) == "string" and s or tostring(v or 0)
end

local function scan()
    if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
    local n = tonumber((GetNumTrainerServices())) or 0
    local list = M.TrainingRead(n, GetTrainerServiceInfo, GetTrainerServiceLevelReq,
        function(i) return (GetTrainerServiceCost(i)) end, GetTrainerServiceSkillLine)
    if #list == 0 then return end
    local tradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
    if tradeskill then
        local skill = list[1].skill or "?"
        store("recipes")[skill] = list
    else
        local s = store("class")
        s.list, s.at = list, time()
    end
    if win and win:IsShown() then M:LayoutTraining() end
end
M.TrainingScan = scan

local function row(i)
    local r = CreateFrame("Frame", nil, win)
    r:SetHeight(ROW_H - 2)
    r:SetPoint("TOPLEFT", 10, -40 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", -10, 0)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = W.Text(r, "small", "text.primary", "LEFT")
    r.name:SetPoint("LEFT", 4, 0)
    r.value = W.Text(r, "small", "text.secondary", "RIGHT")
    r.value:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    win.rows[i] = r
    return r
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_TrainingPlanner", UIParent)
    win:SetSize(WIDTH, 50 + ROWS * ROW_H + 12)
    win:SetPoint("CENTER")
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", function(_, d) offset = math.max(0, offset - d); M:LayoutTraining() end)
    win.rows = {}
    win.title = W.Text(win, "heading", "accent.primary", "LEFT")
    win.title:SetPoint("TOPLEFT", 10, -10)
    win.sub = W.Text(win, "small", "text.secondary", "LEFT")
    win.sub:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -2)
    win.close = W:IconButton(win, "close", 22, CLOSE)
    win.close:SetPoint("TOPRIGHT", -6, -6)
    win.close.onClick = function() win:Hide() end
    for i = 1, ROWS do row(i) end
    Skin:Register(win, function(self) Skin:Panel(self, "base", { border = "border.strong" }); M:LayoutTraining() end)
    tinsert(UISpecialFrames, "PhoenixUI_TrainingPlanner")
end

-- The rows: what you can learn now (accent), then later by level; recipes of one profession when kind is a skill.
function M:TrainingLines(kind)
    local list
    if kind then list = store("recipes")[kind] else list = store("class").list end
    local now, later, cost = M.TrainingPlan(list, tonumber((UnitLevel("player"))) or 1)
    local lines = {}
    for _, s in ipairs(now) do lines[#lines + 1] = { s = s, now = true } end
    for _, s in ipairs(later) do lines[#lines + 1] = { s = s } end
    return lines, cost, list ~= nil and #list > 0
end

function M:LayoutTraining()
    if not (win and win:IsShown()) then return end
    local kind = win.kind
    local lines, cost, seen = self:TrainingLines(kind)
    win.title:SetText(kind and L.TRAIN_RECIPES_TITLE:format(kind) or L.TRAIN_TITLE)
    win.sub:SetText(seen and L.TRAIN_NOW:format(money(cost)) or L.TRAIN_VISIT)
    offset = math.max(0, math.min(offset, #lines - ROWS))
    for i = 1, ROWS do
        local r, e = win.rows[i], lines[i + offset]
        r:SetShown(e and true or false)
        if e then
            local s = e.s
            r.bg:SetColorTexture(0, 0, 0, e.now and 0.45 or 0.25)
            r.name:SetText(s.rank and (s.name .. " (" .. s.rank .. ")") or s.name)
            if e.now then W.Color(r.name, "accent.primary") else W.Color(r.name, "text.primary") end
            local lvl = s.level > 0 and L.TRAIN_LEVEL:format(s.level) or ""
            r.value:SetText(lvl .. (s.cost > 0 and ("  " .. money(s.cost)) or ""))
        end
    end
end

-- Open the planner (kind nil: your class trainer; a profession name: that profession's recipes).
function M:OpenTraining(kind)
    if not win then build() end
    win.kind, offset = kind, 0
    win:Show()
    self:LayoutTraining()
end
function M:TrainingWindow() return win end

function M:SetupTraining()
    if self.trainingHooked then return end
    self.trainingHooked = true
    for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do
        ns.Events:On(e, OWNER, function() ns.SafeCall(scan) end)
    end
end
