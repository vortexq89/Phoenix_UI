local _, ns = ...
local Skin, Theme, Media = ns.Skin, ns.Theme, ns.Media
local Secret = ns.Secret
local M = ns:GetModule("CombatText")

--[[ Phoenix scrolling combat text: our own scroll areas for what the 12.x game still tells addons.
    Sources:
    * COMBAT_TEXT_UPDATE (the event Blizzard's own combat text uses; values from C_CombatText.GetCurrentEventInfo,
      documented SecretReturns): damage, heals, avoidance, auras, reactive spells, honour and reputation;
    * UNIT_COMBAT "target": damage and heals your target takes from everyone (12.x gives addons no source for
      "only your own outgoing damage", so the outgoing area is labelled for what it is).
    Every event type has its own switch, colour, size, area and sound; each area has its own animation
    (straight, parabola, angled, static), direction, width, alignment, duration and text size. Crits can grow,
    flash and go to their own area, with their own sound. Repeats within the merge window collapse to one line
    with a hit count; the throttle caps lines per second per area (the rest is dropped, never queued).
    Secret-safety: amounts only ever reach FontString:SetFormattedText (a sink); they are never compared, added
    or tested. The message type and UNIT_COMBAT's action/flag strings are checked with Secret.IsSecret first and
    a secret one is skipped. Merging counts hits instead of summing amounts, so it works on secret amounts too.
    Movement runs in each area's own OnUpdate, set only while a line is in flight (this branch has no Ticker
    registry; the handler is cleared when the area empties). ]]
local AREAS = { "incoming", "target", "notify", "crits" }

-- event key -> { message types }, a fixed word (avoidance) or which GetCurrentEventInfo value is the amount, prefix
local EVENTS = {
    { key = "damage", types = { "DAMAGE", "DAMAGE_CRIT" }, prefix = "-" },
    { key = "spell", types = { "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT" }, prefix = "-" },
    { key = "shield", types = { "DAMAGE_SHIELD" }, prefix = "-" },
    { key = "heal", types = { "HEAL", "HEAL_CRIT" }, value = 2, prefix = "+" },
    { key = "hot", types = { "PERIODIC_HEAL", "PERIODIC_HEAL_CRIT" }, value = 2, prefix = "+" },
    { key = "avoid", words = true },
    { key = "buff", types = { "SPELL_AURA_START" }, prefix = "+" },
    { key = "debuff", types = { "SPELL_AURA_START_HARMFUL" }, prefix = "+" },
    { key = "fade", types = { "SPELL_AURA_END", "SPELL_AURA_END_HARMFUL" }, prefix = "-" },
    { key = "reactive", types = { "SPELL_ACTIVE" }, prefix = "" },
    { key = "honor", types = { "HONOR_GAINED" }, prefix = "+" },
    { key = "rep", types = { "FACTION" }, value = 2, prefix = "+" },
    { key = "hit", unit = "WOUND", prefix = "" },
    { key = "theal", unit = "HEAL", prefix = "+" },
}
local WORDS = {
    MISS = "COMBAT_TEXT_MISS", SPELL_MISS = "COMBAT_TEXT_MISS", DODGE = "COMBAT_TEXT_DODGE", SPELL_DODGE = "COMBAT_TEXT_DODGE",
    PARRY = "COMBAT_TEXT_PARRY", SPELL_PARRY = "COMBAT_TEXT_PARRY", BLOCK = "COMBAT_TEXT_BLOCK",
    SPELL_BLOCK = "COMBAT_TEXT_BLOCK", ABSORB = "COMBAT_TEXT_ABSORB", SPELL_ABSORB = "COMBAT_TEXT_ABSORB",
    RESIST = "COMBAT_TEXT_RESIST", SPELL_RESIST = "COMBAT_TEXT_RESIST", IMMUNE = "COMBAT_TEXT_IMMUNE",
    SPELL_IMMUNE = "COMBAT_TEXT_IMMUNE", EVADE = "COMBAT_TEXT_EVADE", SPELL_EVADE = "COMBAT_TEXT_EVADE",
}
local BY_TYPE, BY_UNIT, CRIT_TYPES = {}, {}, {}
for _, e in ipairs(EVENTS) do
    for _, t in ipairs(e.types or {}) do BY_TYPE[t] = e; if t:find("_CRIT$") then CRIT_TYPES[t] = true end end
    if e.unit then BY_UNIT[e.unit] = e end
end
M.EVENTS, M.AREAS, M.WORDS = EVENTS, AREAS, WORDS

local frames = {}
local function areaDB(key) return M.db.scroll.areas[key] end

---------------------------------------------------------------- animation paths
-- t runs 0..1 over the line's life; side is -1 or 1 (alternating lines); slot is the line's place for static.
-- Returns the offset from the area's anchor edge. Pure maths, shared with the options preview.
function M.Path(anim, t, height, width, side, slot, lineH)
    local span = math.max(20, height - (lineH or 20))
    if anim == "static" then
        return 0, math.min(span, (slot or 0) * (lineH or 20))
    elseif anim == "parabola" then
        -- rises at a steady pace and bends outward: x grows with the square of the climb
        return side * width * 0.35 * t * t, span * t
    elseif anim == "angled" then
        return side * width * 0.3 * t, span * t
    end
    return side * 14, span * t
end

local function placeArea(key)
    local f, a = frames[key], areaDB(key)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)
    f:SetSize(a.width, a.height)
end

local function newLine(f)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetWordWrap(false)
    return fs
end

-- Paint one line: the shared font, scaled by the area, the event and the crit style.
function M:StyleLine(fs, crit, areaKey, scale)
    local db = self.db.scroll
    local spec = db.font
    Skin:TextSpec(fs, spec, "combat")
    local a = areaKey and db.areas[areaKey]
    local mult = (a and a.scale or 1) * (scale or 1)
    if crit and db.crit == "grow" then mult = mult * (db.critScale or 1.5) end
    if mult ~= 1 then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path, math.max(6, math.floor(spec.size * mult + 0.5)), flags)
    end
    if a then fs:SetWidth(a.width); fs:SetJustifyH(a.align or "CENTER") end
end

local function move(self, dt)
    local a = areaDB(self.key)
    local dur = math.max(0.5, a.duration or 2.4)
    local fadeAt = dur * 0.66
    for i = #self.active, 1, -1 do
        local line = self.active[i]
        line.t = line.t + dt
        if line.t >= dur then
            line.fs:Hide()
            table.remove(self.active, i)
            self.free[#self.free + 1] = line.fs
        else
            local x, y = M.Path(a.anim, line.t / dur, a.height, a.width, line.side, line.slot, line.h)
            if a.align == "LEFT" then x = math.abs(x) elseif a.align == "RIGHT" then x = -math.abs(x) end
            line.fs:ClearAllPoints()
            if a.dir == "DOWN" then line.fs:SetPoint("TOP", self, "TOP", x, -y)
            else line.fs:SetPoint("BOTTOM", self, "BOTTOM", x, y) end
            line.fs:SetAlpha(line.t > fadeAt and math.max(0, 1 - (line.t - fadeAt) / (dur - fadeAt)) or 1)
        end
    end
    if #self.active == 0 then self:SetScript("OnUpdate", nil); self:Hide() end
end

local function area(key)
    local f = frames[key]
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f.key, f.active, f.free, f.stamps = key, {}, {}, {}
    frames[key] = f
    placeArea(key)
    return f
end

local function colorOf(c)
    if type(c) == "string" then return Theme:Color(c) end
    if c.r then return c.r, c.g, c.b end
    return c[1], c[2], c[3]
end

-- Throttle: at most n lines a second in one area. Returns false when this line should be dropped.
local function allow(f, n, now)
    if not n or n <= 0 then return true end
    local s, keep = f.stamps, 0
    for i = 1, #s do if now - s[i] < 1 then keep = keep + 1; s[keep] = s[i] end end
    for i = #s, keep + 1, -1 do s[i] = nil end
    if keep >= n then return false end
    s[keep + 1] = now
    return true
end

-- Where a line goes: crits may have their own area; nil when that area or scrolling is off.
local function route(db, key, crit)
    local ca = db.critArea
    if crit and ca and ca ~= "same" and db.areas[ca] and db.areas[ca].show then key = ca end
    local a = areaDB(key)
    if not (db.enabled and a and a.show) then return end
    if db.onlyCombat and not InCombatLockdown() and not M.testing then return end
    return key, a
end

-- Bump a line of the same kind inside the merge window; true when merged.
local function merge(db, f, mergeKey, now, prefix, amount)
    if not (db.merge and mergeKey) then return false end
    for _, line in ipairs(f.active) do
        if line.key == mergeKey and now - line.born < (db.mergeWindow or 0.35) then
            line.n, line.born, line.t = line.n + 1, now, 0
            line.fs:SetFormattedText("%s%s ×%d", prefix, amount, line.n)
            return true
        end
    end
    return false
end

local function freeSlot(f)
    local used, slot = {}, 0
    for _, l in ipairs(f.active) do used[l.slot] = true end
    while used[slot] do slot = slot + 1 end
    return slot
end

-- Add (or merge into) a line. amount may be secret: it only goes to SetFormattedText.
local function add(key, color, prefix, amount, crit, mergeKey, scale, sound)
    local db = M.db.scroll
    local a
    key, a = route(db, key, crit)
    if not key then return end
    local f = area(key)
    local now = GetTime()
    if merge(db, f, mergeKey, now, prefix, amount) or not allow(f, db.throttle, now) then return end
    local fs = table.remove(f.free) or newLine(f)
    M:StyleLine(fs, crit, key, scale)
    local r, g, b = colorOf(color)
    if crit and db.crit == "flash" then r, g, b = Theme:Color("accent.primary") end
    fs:SetTextColor(r, g, b)
    if amount == nil then fs:SetText(prefix) else fs:SetFormattedText("%s%s", prefix, amount) end
    fs:SetAlpha(1)
    fs:Show()
    local snd = crit and db.critSound ~= "" and db.critSound or sound
    if snd and snd ~= "" and not M.testing then Media:PlaySound(snd) end
    local slot = a.anim == "static" and freeSlot(f) or 0
    f.flip = not f.flip
    local _, h = fs:GetFont()
    f.active[#f.active + 1] = { fs = fs, t = 0, side = f.flip and -1 or 1, slot = slot, h = (h or 18) + 4,
        key = mergeKey, n = 1, born = now }
    f:SetScript("OnUpdate", move)
    f:Show()
end
M.AddLine = add

local function fire(e, amount, crit, mergeKey, word)
    local s = M.db.scroll.events[e.key]
    if not (s and s.show) then return end
    add(s.area, s.color, word or e.prefix, amount, crit, mergeKey, s.scale, s.sound)
end
M.Fire = fire

local function onCombatText(_, _, messageType)
    if Secret.IsSecret(messageType) or type(messageType) ~= "string" then return end
    local word = WORDS[messageType]
    if word then return fire(EVENTS[6], nil, false, messageType, _G[word] or messageType) end
    local e = BY_TYPE[messageType]
    if not e then return end
    local data, arg3 = C_CombatText.GetCurrentEventInfo()
    local amount = e.value == 2 and arg3 or data
    if amount == nil then return end
    fire(e, amount, CRIT_TYPES[messageType] or false, messageType)
end

local function onUnitCombat(_, _, unit, action, flags, amount)
    if unit ~= "target" or Secret.IsSecret(action) or type(action) ~= "string" then return end
    local e = BY_UNIT[action]
    if not e or amount == nil then return end
    local crit = not Secret.IsSecret(flags) and (flags == "CRITICAL" or flags == "CRUSHING")
    fire(e, amount, crit, action)
end

local owner = {}
function M:EnableScroll()
    local db = self.db.scroll
    ns.Events:OffAll(owner)
    for _, key in ipairs(AREAS) do
        if frames[key] then
            placeArea(key)
            local on = db.enabled and areaDB(key).show
            if not on then
                for _, line in ipairs(frames[key].active) do line.fs:Hide(); frames[key].free[#frames[key].free + 1] = line.fs end
                wipe(frames[key].active)
                frames[key]:SetScript("OnUpdate", nil)
                frames[key]:Hide()
            end
            for _, line in ipairs(frames[key].active) do self:StyleLine(line.fs, false, key) end
        end
    end
    if not db.enabled then return end
    if C_CombatText and C_CombatText.GetCurrentEventInfo then ns.Events:On("COMBAT_TEXT_UPDATE", owner, onCombatText) end
    local ev = db.events
    if ev.hit.show or ev.theal.show then ns.Events:On("UNIT_COMBAT", owner, onUnitCombat) end
end

-- Test lines through every event's real route (colour, size, area): plain sample numbers.
local SAMPLE = { damage = "12 846", spell = "9 310", shield = "640", heal = "8 230", hot = "1 904", buff = "FCT_SAMPLE_AURA",
    debuff = "FCT_SAMPLE_AURA", fade = "FCT_SAMPLE_AURA", reactive = "FCT_SAMPLE_AURA", honor = "48", rep = "250",
    hit = "31 044", theal = "4 112" }
M.SAMPLE = SAMPLE
function M:TestScroll()
    if not self.db.scroll.enabled then return false end
    self.testing = true
    for i, e in ipairs(EVENTS) do
        local v = SAMPLE[e.key]
        if v == "FCT_SAMPLE_AURA" then v = ns.L.FCT_SAMPLE_AURA end
        if e.words then fire(e, nil, false, nil, _G.COMBAT_TEXT_DODGE or "Dodge")
        else fire(e, v, i == 1 or e.key == "hit", nil) end
    end
    self.testing = false
    return true
end
