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
local AREAS = { "incoming", "heals", "target", "outheal", "power", "notify", "crits" }
-- power types the game reports through ENERGIZE / PERIODIC_ENERGIZE (arg3 is the power token)
local POWERS = { "MANA", "RAGE", "FOCUS", "ENERGY", "RUNIC_POWER", "INSANITY", "FURY", "PAIN", "MAELSTROM",
    "LUNAR_POWER", "COMBO_POINTS", "HOLY_POWER", "SOUL_SHARDS", "CHI", "ARCANE_CHARGES", "ESSENCE" }

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
    { key = "hit", unit = "WOUND", prefix = "", castIcon = true },
    { key = "theal", unit = "HEAL", prefix = "+", castIcon = true },
}
for _, token in ipairs(POWERS) do
    EVENTS[#EVENTS + 1] = { key = "p_" .. token:lower(), power = token, prefix = "+", castIcon = true }
end
local BY_POWER = {}
for _, e in ipairs(EVENTS) do if e.power then BY_POWER[e.power] = e end end
-- spell-name events whose name can give an icon
local NAME_ICON = { buff = true, debuff = true, fade = true, reactive = true }
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
M.EVENTS, M.AREAS, M.WORDS, M.POWERS = EVENTS, AREAS, WORDS, POWERS

-- Every area key: the seven fixed ones, then the user's own (db.scroll.custom, in the order they were added).
function M.AreaKeys()
    local out = {}
    for i, k in ipairs(AREAS) do out[i] = k end
    local custom = M.db and M.db.scroll.custom
    if type(custom) == "table" then
        for _, k in ipairs(custom) do if M.db.scroll.areas[k] then out[#out + 1] = k end end
    end
    return out
end
function M.IsCustomArea(key) return type(key) == "string" and key:find("^custom%d+$") ~= nil end

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
    local pt = a.point or "CENTER"
    f:ClearAllPoints()
    f:SetPoint(pt, UIParent, pt, a.x, a.y)
    f:SetSize(a.width, a.height)
end

local function newLine(f)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetWordWrap(false)
    fs.icon = f:CreateTexture(nil, "OVERLAY")
    fs.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fs.icon:Hide()
    return fs
end

-- The icon beside a line: left or right of the text, sized by the area; hidden without a texture or when off.
local function placeIcon(fs, a, tex)
    local ic = fs.icon
    if not (tex and a.iconSide ~= "OFF") then ic:Hide(); return end
    ic:SetTexture(tex)
    ic:SetSize(a.iconSize or 20, a.iconSize or 20)
    ic:ClearAllPoints()
    if a.iconSide == "RIGHT" then ic:SetPoint("LEFT", fs, "RIGHT", 4, 0) else ic:SetPoint("RIGHT", fs, "LEFT", -4, 0) end
    ic:Show()
end

-- Paint one line: the shared font, scaled by the area, the event and the crit style.
function M:StyleLine(fs, crit, areaKey, scale)
    local db = self.db.scroll
    local spec = db.font
    Skin:TextSpec(fs, spec, "combat")
    local a = areaKey and db.areas[areaKey]
    local mult = (a and a.scale or 1) * (scale or 1)
    if crit and (db.crit == "grow" or db.crit == "sticky") then mult = mult * (db.critScale or 1.5) end
    if mult ~= 1 then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path, math.max(6, math.floor(spec.size * mult + 0.5)), flags)
    end
    if a then fs:SetJustifyH(a.align or "CENTER") end
end

local function move(self, dt)
    local a = areaDB(self.key)
    local dur = math.max(0.5, a.duration or 2.4)
    local fadeAt = dur * 0.66
    for i = #self.active, 1, -1 do
        local line = self.active[i]
        line.t = line.t + dt
        if line.t >= dur then
            line.fs:Hide(); line.fs.icon:Hide()
            table.remove(self.active, i)
            self.free[#self.free + 1] = line.fs
        else
            local x, y
            if line.sticky then
                -- sticky crit: pops in larger, eases to size and holds still at the area's centre, stacked
                x, y = 0, a.height / 2 - line.h / 2 + (line.slot % 3) * line.h * (a.dir == "DOWN" and 1 or -1)
                local pop = line.t < 0.18 and (1 + 0.7 * (1 - line.t / 0.18)) or 1
                line.fs:SetScale(pop)
                x, y = x / pop, y / pop
            else
                x, y = M.Path(a.anim, line.t / dur, a.height, a.width, line.side, line.slot, line.h)
            end
            if a.align == "LEFT" then x = math.abs(x) elseif a.align == "RIGHT" then x = -math.abs(x) end
            local side = a.align == "LEFT" and "LEFT" or (a.align == "RIGHT" and "RIGHT" or "")
            local inset = (side == "LEFT" and (a.iconSize or 20) + 6) or (side == "RIGHT" and -((a.iconSize or 20) + 6)) or 0
            line.fs:ClearAllPoints()
            if a.dir == "DOWN" then line.fs:SetPoint("TOP" .. side, self, "TOP" .. side, x + inset, -y)
            else line.fs:SetPoint("BOTTOM" .. side, self, "BOTTOM" .. side, x + inset, y) end
            local alpha = line.t > fadeAt and math.max(0, 1 - (line.t - fadeAt) / (dur - fadeAt)) or 1
            line.fs:SetAlpha(alpha); line.fs.icon:SetAlpha(alpha)
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
            line.fs:SetFormattedText("%s%s%s ×%d", prefix, amount, line.suffix or "", line.n)
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
local function add(key, color, prefix, amount, crit, mergeKey, scale, sound, icon, suffix)
    local db = M.db.scroll
    local a
    key, a = route(db, key, crit)
    if not key then return end
    local f = area(key)
    local now = GetTime()
    if merge(db, f, mergeKey, now, prefix, amount) or not allow(f, db.throttle, now) then return end
    local fs = table.remove(f.free) or newLine(f)
    M:StyleLine(fs, crit, key, scale)
    local r, g, b = colorOf(a.useColor and a.color or color)
    if crit and db.crit == "flash" then r, g, b = Theme:Color("accent.primary") end
    fs:SetTextColor(r, g, b)
    if amount == nil then fs:SetText(prefix) else fs:SetFormattedText("%s%s%s", prefix, amount, suffix or "") end
    fs:SetAlpha(1)
    fs:Show()
    placeIcon(fs, a, icon)
    local snd = crit and db.critSound ~= "" and db.critSound or sound
    if snd and snd ~= "" and not M.testing then Media:PlaySound(snd) end
    local sticky = crit and db.crit == "sticky"
    local slot = (a.anim == "static" or sticky) and freeSlot(f) or 0
    fs:SetScale(1)
    f.flip = not f.flip
    local _, h = fs:GetFont()
    f.active[#f.active + 1] = { fs = fs, t = 0, side = f.flip and -1 or 1, slot = slot, h = (h or 18) + 4,
        key = mergeKey, n = 1, born = now, suffix = suffix, sticky = sticky }
    f:SetScript("OnUpdate", move)
    f:Show()
end
M.AddLine = add

-- Your last cast's icon, for outgoing and power lines: UNIT_SPELLCAST_SUCCEEDED "player", only a spell ID that is not
-- secret, kept for CAST_WINDOW seconds. 12.x gives these lines no spell of their own, so it is labelled "your last
-- cast" on the page and can be switched off.
local CAST_WINDOW = 1.2
local lastIcon, lastAt = nil, 0
local function onCast(_, _, unit, _, spellID)
    if unit ~= "player" or spellID == nil or Secret.IsSecret(spellID) then return end
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if tex and not Secret.IsSecret(tex) then lastIcon, lastAt = tex, GetTime() end
end

local function iconFor(e, name)
    local db = M.db.scroll
    if NAME_ICON[e.key] and type(name) == "string" and not Secret.IsSecret(name) and C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(name)
        if tex and not Secret.IsSecret(tex) then return tex end
    end
    if e.castIcon and db.castIcons and lastIcon and GetTime() - lastAt < CAST_WINDOW then return lastIcon end
end

local function fire(e, amount, crit, mergeKey, word, name, suffix)
    local s = M.db.scroll.events[e.key]
    if not (s and s.show) then return end
    add(s.area, s.color, word or e.prefix, amount, crit, mergeKey, s.scale, s.sound, iconFor(e, name), suffix)
end
M.Fire = fire

local function onCombatText(_, _, messageType)
    if Secret.IsSecret(messageType) or type(messageType) ~= "string" then return end
    local word = WORDS[messageType]
    if word then return fire(EVENTS[6], nil, false, messageType, _G[word] or messageType) end
    if messageType == "ENERGIZE" or messageType == "PERIODIC_ENERGIZE" then
        local amount, token = C_CombatText.GetCurrentEventInfo()
        if amount == nil or Secret.IsSecret(token) or type(token) ~= "string" then return end
        local e = BY_POWER[token]
        if not e then return end
        local label = _G[token]
        return fire(e, amount, false, token, nil, nil, type(label) == "string" and (" " .. label) or nil)
    end
    local e = BY_TYPE[messageType]
    if not e then return end
    local data, arg3 = C_CombatText.GetCurrentEventInfo()
    local amount = e.value == 2 and arg3 or data
    if amount == nil then return end
    fire(e, amount, CRIT_TYPES[messageType] or false, messageType, nil, data)
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
    self:RegisterAreaMovers() -- idempotent; picks up user areas after a profile change
    ns.Events:OffAll(owner)
    for _, key in ipairs(M.AreaKeys()) do
        if frames[key] then
            placeArea(key)
            local on = db.enabled and areaDB(key).show
            if not on then
                for _, line in ipairs(frames[key].active) do
                    line.fs:Hide(); line.fs.icon:Hide(); frames[key].free[#frames[key].free + 1] = line.fs
                end
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
    if db.castIcons then ns.Events:OnUnit("UNIT_SPELLCAST_SUCCEEDED", owner, onCast, "player") end
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
        elseif e.power then
            if e.power == "MANA" or e.power == "RAGE" or e.power == "ENERGY" or e.power == "RUNIC_POWER" then
                fire(e, "240", false, nil, nil, nil, " " .. (_G[e.power] or e.power))
            end
        else fire(e, v, i == 1 or e.key == "hit", nil, nil, e.key == "reactive" and "Fireball" or nil) end
    end
    self.testing = false
    return true
end

---------------------------------------------------------------- Phoenix movers: every area is a mover
-- Each area joins Movers with its own store (point / x / y in the profile, so positions are per profile), the
-- same drag, grid and edge snap, arrow-key nudge and popup as action bars and frames. Its box draws the area's
-- scroll path (dots along CombatText.Path), so you see where lines will travel while placing it.
local function store(key)
    return {
        -- always in Layout mode while the module is on (t196), even when the area or scrolling is switched off
        active = function() return M:IsEnabled() and areaDB(key) ~= nil end,
        get = function() local a = areaDB(key); return { point = a.point or "CENTER", x = a.x, y = a.y } end,
        set = function(v)
            local a = areaDB(key)
            a.point, a.x, a.y = v.point or a.point or "CENTER", v.x or a.x, v.y or a.y
        end,
        apply = function() placeArea(key) end,
        reset = function()
            local d, a = M.defaults.scroll.areas[key] or M.CUSTOM_TEMPLATE, areaDB(key)
            a.point, a.x, a.y = d.point or "CENTER", d.x, d.y
            placeArea(key)
        end,
        decorate = function(o, w, h)
            local a = areaDB(key)
            o.pathDots = o.pathDots or {}
            local n = 14
            for i = 1, n do
                local dot = o.pathDots[i]
                if not dot then
                    dot = o:CreateTexture(nil, "ARTWORK")
                    dot:SetColorTexture(1, 1, 1, 1)
                    o.pathDots[i] = dot
                end
                local t = (i - 1) / (n - 1)
                local x, y = M.Path(a.anim, t, h, w, i % 2 == 0 and 1 or -1, i - 1, 18)
                dot:SetSize(4, 4)
                dot:ClearAllPoints()
                if a.dir == "DOWN" then dot:SetPoint("TOP", o, "TOP", x, -y) else dot:SetPoint("BOTTOM", o, "BOTTOM", x, y) end
                dot:SetVertexColor(1, 0.55, 0.2, 0.35 + 0.6 * (1 - t))
                dot:Show()
            end
        end,
    }
end

function M:RegisterAreaMover(key)
    local movers = ns:GetModule("Movers")
    if not movers or not areaDB(key) then return end
    local f = area(key)
    local a = areaDB(key)
    local label = M.IsCustomArea(key) and (a.name ~= "" and a.name or key) or ns.L["FCT_AREA_" .. key:upper()]
    movers:Register("fct." .. key, f, ns.L.COMBATTEXT .. " – " .. label, store(key))
end

function M:RegisterAreaMovers()
    for _, key in ipairs(M.AreaKeys()) do self:RegisterAreaMover(key) end
end

-- User areas (t196): a copy of the template, named, placed at the screen centre; events can be routed to it.
M.CUSTOM_TEMPLATE = { show = true, x = 0, y = 0, width = 260, height = 200, dir = "UP", anim = "straight", align = "CENTER",
    duration = 2.4, scale = 1, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 1, g = 1, b = 1 }, name = "" }
local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and copy(v) or v end
    return o
end

function M:AddArea(name)
    local db = self.db.scroll
    db.custom = type(db.custom) == "table" and db.custom or {}
    local n = 1
    while db.areas["custom" .. n] do n = n + 1 end
    local key = "custom" .. n
    local a = copy(M.CUSTOM_TEMPLATE)
    a.name = type(name) == "string" and name or ""
    a.y = -40 * (#db.custom % 6)
    db.areas[key] = a
    db.custom[#db.custom + 1] = key
    self:RegisterAreaMover(key)
    self:EnableScroll()
    return key
end

function M:RemoveArea(key)
    local db = self.db.scroll
    if not (M.IsCustomArea(key) and db.areas[key]) then return false end
    for i = #(db.custom or {}), 1, -1 do if db.custom[i] == key then table.remove(db.custom, i) end end
    for _, e in pairs(db.events) do if e.area == key then e.area = "notify" end end
    if db.critArea == key then db.critArea = "same" end
    db.areas[key] = nil
    local f = frames[key]
    if f then f:SetScript("OnUpdate", nil); f:Hide() end
    self:EnableScroll()
    return true
end
