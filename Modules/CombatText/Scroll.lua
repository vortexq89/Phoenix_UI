local _, ns = ...
local Skin, Theme = ns.Skin, ns.Theme
local Secret = ns.Secret
local M = ns:GetModule("CombatText")

--[[ Phoenix scroll areas: our own scrolling combat text in three areas.
    * incoming: what the game reports to the player's combat text (COMBAT_TEXT_UPDATE, the event Blizzard's own
      combat text uses; its values come from C_CombatText.GetCurrentEventInfo, documented SecretReturns):
      damage, heals, misses, dodges, parries, blocks, absorbs;
    * target: damage and heals your current target takes, from everyone (UNIT_COMBAT "target"); the game gives
      addons no "your own outgoing damage" source in 12.x, so this is labelled for what it is;
    * notify: auras gained and lost, reactive spells, honour and reputation (COMBAT_TEXT_UPDATE).
    Amounts may be secret: they only ever reach FontString:SetFormattedText (a sink) and are never compared,
    added or tested. The message type and UNIT_COMBAT's action/flag strings are checked with Secret.IsSecret
    first; a secret one is skipped (no crit styling, no merge key). Merging repeats the newest amount with a
    hit count ("×3") instead of summing, so it works on secret amounts too. ]]
local AREAS = { "incoming", "target", "notify" }
local DURATION, FADE_AT, WIDTH, MERGE_WINDOW = 2.4, 1.6, 240, 0.35

-- message type -> area, colour token or rgb, which GetCurrentEventInfo value is the amount, prefix, crit
local KINDS = {
    DAMAGE = { "incoming", { 1, 0.3, 0.25 }, 1, "-" }, SPELL_DAMAGE = { "incoming", { 1, 0.45, 0.2 }, 1, "-" },
    DAMAGE_CRIT = { "incoming", { 1, 0.3, 0.25 }, 1, "-", true },
    SPELL_DAMAGE_CRIT = { "incoming", { 1, 0.45, 0.2 }, 1, "-", true },
    DAMAGE_SHIELD = { "incoming", { 0.9, 0.8, 0.3 }, 1, "-" },
    HEAL = { "incoming", { 0.3, 1, 0.35 }, 2, "+" }, PERIODIC_HEAL = { "incoming", { 0.3, 1, 0.35 }, 2, "+" },
    HEAL_CRIT = { "incoming", { 0.3, 1, 0.35 }, 2, "+", true },
    PERIODIC_HEAL_CRIT = { "incoming", { 0.3, 1, 0.35 }, 2, "+", true },
    SPELL_AURA_START = { "notify", { 1, 0.85, 0.4 }, 1, "+" }, SPELL_AURA_END = { "notify", { 0.7, 0.7, 0.7 }, 1, "-" },
    SPELL_AURA_START_HARMFUL = { "notify", { 1, 0.4, 0.4 }, 1, "+" },
    SPELL_AURA_END_HARMFUL = { "notify", { 0.7, 0.7, 0.7 }, 1, "-" },
    SPELL_ACTIVE = { "notify", { 1, 0.82, 0 }, 1, "", true },
    HONOR_GAINED = { "notify", { 0.85, 0.5, 1 }, 1, "+" }, FACTION = { "notify", { 0.5, 0.6, 1 }, 2, "+" },
}
-- avoidance messages: a fixed word, no amount
local WORDS = {
    MISS = "COMBAT_TEXT_MISS", SPELL_MISS = "COMBAT_TEXT_MISS", DODGE = "COMBAT_TEXT_DODGE", SPELL_DODGE = "COMBAT_TEXT_DODGE",
    PARRY = "COMBAT_TEXT_PARRY", SPELL_PARRY = "COMBAT_TEXT_PARRY", BLOCK = "COMBAT_TEXT_BLOCK",
    SPELL_BLOCK = "COMBAT_TEXT_BLOCK", ABSORB = "COMBAT_TEXT_ABSORB", SPELL_ABSORB = "COMBAT_TEXT_ABSORB",
    RESIST = "COMBAT_TEXT_RESIST", SPELL_RESIST = "COMBAT_TEXT_RESIST", IMMUNE = "COMBAT_TEXT_IMMUNE",
    SPELL_IMMUNE = "COMBAT_TEXT_IMMUNE", EVADE = "COMBAT_TEXT_EVADE", SPELL_EVADE = "COMBAT_TEXT_EVADE",
}
-- UNIT_COMBAT actions on the target
local TARGET = { WOUND = { { 1, 0.95, 0.85 }, "" }, HEAL = { { 0.3, 1, 0.35 }, "+" } }
M.KINDS, M.AREAS = KINDS, AREAS

local frames = {}

local function areaDB(key) return M.db.scroll.areas[key] end

local function placeArea(key)
    local f, a = frames[key], areaDB(key)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)
    f:SetSize(WIDTH, a.height)
end

local function newLine(f)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetWidth(WIDTH)
    fs:SetWordWrap(false)
    return fs
end

-- Paint one line in the area's font; crit lines grow (or flash) when the style asks for it.
function M:StyleLine(fs, crit)
    local db = self.db.scroll
    local spec = db.font
    Skin:TextSpec(fs, spec, "combat")
    if crit and db.crit == "grow" then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path, math.floor(spec.size * 1.5 + 0.5), flags)
    end
end

local function area(key)
    local f = frames[key]
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f.active, f.free = {}, {}
    f:SetScript("OnUpdate", function(self, dt)
        local a = areaDB(key)
        local span = math.max(20, a.height - 20)
        for i = #self.active, 1, -1 do
            local line = self.active[i]
            line.t = line.t + dt
            if line.t >= DURATION then
                line.fs:Hide()
                table.remove(self.active, i)
                self.free[#self.free + 1] = line.fs
            else
                local y = span * line.t / DURATION
                line.fs:ClearAllPoints()
                if a.dir == "DOWN" then
                    line.fs:SetPoint("TOP", self, "TOP", line.x, -y)
                else
                    line.fs:SetPoint("BOTTOM", self, "BOTTOM", line.x, y)
                end
                line.fs:SetAlpha(line.t > FADE_AT and math.max(0, 1 - (line.t - FADE_AT) / (DURATION - FADE_AT)) or 1)
            end
        end
    end)
    frames[key] = f
    placeArea(key)
    return f
end

local function colorOf(c)
    if type(c) == "string" then return Theme:Color(c) end
    return c[1], c[2], c[3]
end

-- Add (or merge into) a line. amount may be secret: it only goes to SetFormattedText.
local function add(key, color, prefix, amount, crit, mergeKey)
    local db = M.db.scroll
    local a = areaDB(key)
    if not (db.enabled and a and a.show) then return end
    local f = area(key)
    local now = GetTime()
    if db.merge and mergeKey then
        for _, line in ipairs(f.active) do
            if line.key == mergeKey and now - line.born < MERGE_WINDOW then
                line.n, line.born, line.t = line.n + 1, now, 0
                line.fs:SetFormattedText("%s%s ×%d", prefix, amount, line.n)
                return
            end
        end
    end
    local fs = table.remove(f.free) or newLine(f)
    M:StyleLine(fs, crit)
    local r, g, b = colorOf(color)
    if crit and db.crit == "flash" then r, g, b = Theme:Color("accent.primary") end
    fs:SetTextColor(r, g, b)
    if amount == nil then fs:SetText(prefix) else fs:SetFormattedText("%s%s", prefix, amount) end
    fs:SetAlpha(1)
    fs:Show()
    -- alternate a little left and right so bursts stay readable
    local x = (#f.active % 2 == 0) and -18 or 18
    f.active[#f.active + 1] = { fs = fs, t = 0, x = x, key = mergeKey, n = 1, born = now }
end
M.AddLine = add

local function onCombatText(_, _, messageType)
    if Secret.IsSecret(messageType) or type(messageType) ~= "string" then return end
    local word = WORDS[messageType]
    if word then return add("incoming", { 1, 1, 1 }, _G[word] or messageType, nil, false, messageType) end
    local kind = KINDS[messageType]
    if not kind then return end
    local data, arg3 = C_CombatText.GetCurrentEventInfo()
    local amount = kind[3] == 2 and arg3 or data
    if amount == nil then return end
    add(kind[1], kind[2], kind[4], amount, kind[5], messageType)
end

local function onUnitCombat(_, _, unit, action, flags, amount)
    if unit ~= "target" or Secret.IsSecret(action) or type(action) ~= "string" then return end
    local kind = TARGET[action]
    if not kind or amount == nil then return end
    local crit = not Secret.IsSecret(flags) and (flags == "CRITICAL" or flags == "CRUSHING")
    add("target", kind[1], kind[2], amount, crit, action)
end

local owner = {}
function M:EnableScroll()
    local db = self.db.scroll
    ns.Events:OffAll(owner)
    for _, key in ipairs(AREAS) do
        if frames[key] then
            placeArea(key)
            frames[key]:SetShown(db.enabled and areaDB(key).show)
            for _, line in ipairs(frames[key].active) do self:StyleLine(line.fs) end
        end
    end
    if not db.enabled then return end
    if C_CombatText and C_CombatText.GetCurrentEventInfo then ns.Events:On("COMBAT_TEXT_UPDATE", owner, onCombatText) end
    if db.areas.target.show then ns.Events:On("UNIT_COMBAT", owner, onUnitCombat) end
end

-- Test lines in every area (the page's test button): plain sample numbers.
function M:TestScroll()
    if not self.db.scroll.enabled then return false end
    add("incoming", KINDS.DAMAGE[2], "-", "12 846", false)
    add("incoming", KINDS.HEAL_CRIT[2], "+", "8 230", true)
    add("target", TARGET.WOUND[1], "", "31 044", true)
    add("notify", KINDS.SPELL_AURA_START[2], "+", ns.L.FCT_SAMPLE_AURA, false)
    return true
end
