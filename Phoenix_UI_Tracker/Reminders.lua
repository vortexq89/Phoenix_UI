local _, ns = ...
local L, Skin, Secret = ns.L, ns.Skin, ns.Secret
local M = ns.modules.Tracker

--[[ Reminders: a row of icons for what is missing before a pull, shown out of combat only (auras are often
    secret in combat, and a reminder then is too late anyway). Each check answers "missing" only on plain data;
    anything secret or unknown counts as fine, so a reminder never nags by mistake.
      flask / food / rune / raid buff   aura look-ups by spell ID (retail IDs only; WoW Forever keeps oil, pet,
                                        healthstone and the ready-check mana warning)
      oil        C_PaperDollInfo.GetTemporaryEnchantmentInfo on the main hand
      pet        pet classes and specs without a pet out (not while mounted or in a vehicle)
      healthstone  when a warlock is in your group (or you are one) and you carry none
      mana       on a ready check, for a few seconds, when your mana is below the threshold ]]

local FLASKS = {
    1230875, 1235057, -- spellIDs(retail): Flask of Thalassian Resistance, Flask of Thalassian Resistance
    1230876, 1235108, 1248845, -- spellIDs(retail): Flask of the Magisters, Flask of the Magisters, Flask of the Magisters
    1230877, 1235110, 1248842, -- spellIDs(retail): Flask of the Blood Knights, Flask of the Blood Knights, Flask of the Blood Knights
    1230878, 1235111, 1248840, -- spellIDs(retail): Flask of the Shattered Sun, Flask of the Shattered Sun, Flask of the Shattered Sun
    431971, 431972, -- spellIDs(retail): Flask of Tempered Aggression, Flask of Tempered Swiftness
    431973, 431974, 432021, -- spellIDs(retail): Flask of Tempered Versatility, Flask of Tempered Mastery, Flask of Alchemical Chaos
}
local RUNES = {
    1234969, 1242347, -- spellIDs(retail): Ethereal Augmentation, Soulgorged Augmentation
    393438, 1295329, -- spellIDs(retail): Draconic Augmentation, Tidesworn Augment Rune
}
local WELL_FED = 19705 -- spellIDs(retail): Well Fed
local RAID_BUFF = {
    MAGE = { 1459 }, PRIEST = { 21562 }, -- spellIDs(retail): Arcane Intellect, Power Word: Fortitude
    WARRIOR = { 6673 }, DRUID = { 1126 }, -- spellIDs(retail): Battle Shout, Mark of the Wild
    EVOKER = { 364342, 381748 }, SHAMAN = { 462854 }, -- spellIDs(retail): Blessing of the Bronze, Blessing of the Bronze, Skyfury
}
local HEALTHSTONES = { 5512, 224464 }
-- pet classes: true = every spec, or the spec indices that use a pet
local PET = { WARLOCK = true, HUNTER = { [1] = true, [3] = true }, DEATHKNIGHT = { [3] = true } }

M.REMINDERS = { "flask", "food", "rune", "oil", "raidBuff", "pet", "healthstone", "readyMana" }
M.REMINDER_ICONS = {
    flask = "Interface\\Icons\\INV_Potion_97", food = "Interface\\Icons\\INV_Misc_Food_15",
    rune = "Interface\\Icons\\INV_Misc_Rune_01", oil = "Interface\\Icons\\INV_Potion_100",
    raidBuff = "Interface\\Icons\\Spell_Holy_MagicalSentry", pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
    healthstone = "Interface\\Icons\\INV_Stone_04", readyMana = "Interface\\Icons\\INV_Potion_76",
}
local SPELL_BASED = { flask = true, food = true, rune = true, raidBuff = true }

local holder, icons = nil, {}
local readyUntil = 0

local function plain(v) return not Secret.IsSecret(v) end

local function hasAura(id)
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if not ok or not plain(aura) then return true end -- unknown counts as present
    return aura ~= nil
end

local function hasAny(ids)
    for _, id in ipairs(ids) do if hasAura(id) then return true end end
    return false
end

local function hasFood()
    local name = C_Spell.GetSpellName(WELL_FED)
    if not (name and C_UnitAuras.GetAuraDataBySpellName) then return hasAura(WELL_FED) end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
    if not ok or not plain(aura) then return true end
    return aura ~= nil
end

local function hasOil()
    if not GetInventoryItemID("player", 16) then return true end
    local api = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
    if not api then return true end
    local ok, mainHand = pcall(api)
    if not ok or not plain(mainHand) then return true end
    return mainHand and true or false
end

local function needsPet()
    local _, class = UnitClass("player")
    local rule = PET[class]
    if not rule or IsMounted() or UnitInVehicle("player") then return false end
    if rule ~= true then
        local spec = C_SpecializationInfo.GetSpecialization()
        if not (plain(spec) and rule[spec]) then return false end
    end
    local exists = UnitExists("pet")
    return plain(exists) and not exists
end

local function warlockNear()
    local _, class = UnitClass("player")
    if class == "WARLOCK" then return true end
    local prefix, n = IsInRaid() and "raid" or "party", GetNumGroupMembers()
    for i = 1, n do
        local _, c = UnitClass(prefix .. i)
        if c == "WARLOCK" then return true end
    end
    return false
end

local function needsHealthstone()
    if not warlockNear() then return false end
    for _, id in ipairs(HEALTHSTONES) do
        local ok, count = pcall(C_Item.GetItemCount, id)
        if not ok or not plain(count) or (count or 0) > 0 then return false end
    end
    return true
end

local function lowMana(r)
    if GetTime() > readyUntil then return false end
    local ok, pct = pcall(UnitPowerPercent, "player", Enum.PowerType.Mana, false, CurveConstants and CurveConstants.ScaleTo100)
    if not ok or not plain(pct) or not pct then return false end
    local max = UnitPowerMax("player", Enum.PowerType.Mana)
    return plain(max) and (max or 0) > 0 and pct < r.manaPercent
end

local CHECKS = {
    flask = function() return not hasAny(FLASKS) end,
    food = function() return not hasFood() end,
    rune = function() return not hasAny(RUNES) end,
    oil = function() return not hasOil() end,
    raidBuff = function()
        local _, class = UnitClass("player")
        local ids = RAID_BUFF[class]
        if not ids then return false end
        local ok, known = pcall(C_SpellBook.IsSpellKnown, ids[1])
        if not ok or not plain(known) or not known then return false end
        return not hasAny(ids)
    end,
    pet = needsPet,
    healthstone = needsHealthstone,
    readyMana = lowMana,
}

---------------------------------------------------------------- custom rules and group buffs
-- "ID[:CLASS|ROLE], ..." -> { { id, class, role } }. Class tokens are upper case (MAGE), roles TANK/HEALER/DAMAGER.
local ROLES = { TANK = true, HEALER = true, DAMAGER = true }
function M.ParseCustomReminders(text)
    local out = {}
    for part in tostring(text or ""):gmatch("[^,;%s]+") do
        local id, rule = part:match("^(%d+):?(%a*)$")
        id = tonumber(id)
        if id then
            rule = rule:upper()
            out[#out + 1] = { id = id, class = rule ~= "" and not ROLES[rule] and rule or nil,
                role = ROLES[rule] and rule or nil }
        end
    end
    return out
end

local function playerRole()
    local api = C_SpecializationInfo
    local spec = api and api.GetSpecialization and api.GetSpecialization()
    local role = type(spec) == "number" and GetSpecializationRole and GetSpecializationRole(spec)
    return plain(role) and role or nil
end

local function ruleApplies(e, class, role)
    if e.class and e.class ~= class then return false end
    if e.role and e.role ~= role then return false end
    return true
end

function M:CustomMissing(r)
    local out = {}
    local _, class = UnitClass("player")
    local role = playerRole()
    for _, e in ipairs(M.ParseCustomReminders(r.custom)) do
        if ruleApplies(e, class, role) and not hasAura(e.id) then out[#out + 1] = "custom:" .. e.id end
    end
    return out
end

-- Classes in the group (class tokens are plain); the player is always included.
local function groupClasses()
    local seen = {}
    local _, me = UnitClass("player")
    if me then seen[me] = true end
    local n = tonumber(GetNumGroupMembers and GetNumGroupMembers()) or 0
    local prefix = IsInRaid and IsInRaid() and "raid" or "party"
    for i = 1, n do
        local _, c = UnitClass(prefix .. i)
        if plain(c) and c then seen[c] = true end
    end
    return seen
end
M.GroupClasses = groupClasses

-- Buffs a group member's class brings that you do not have (one entry per providing class).
function M:GroupBuffsMissing()
    local out = {}
    for class in pairs(groupClasses()) do
        local ids = RAID_BUFF[class]
        if ids and not hasAny(ids) then out[#out + 1] = "group:" .. class end
    end
    table.sort(out)
    return out
end

-- Which reminders apply right now (pure of frames: the smoke test calls it).
function M:MissingReminders()
    local r, out = self.db.reminders, {}
    if not (self:IsEnabled() and r.enabled) or InCombatLockdown() then return out end
    if r.instancesOnly then
        local _, kind = IsInInstance()
        if kind ~= "party" and kind ~= "raid" and kind ~= "scenario" then return out end
    end
    for _, name in ipairs(M.REMINDERS) do
        if r[name] and (not SPELL_BASED[name] or ns:Supports("cdmReminders")) then
            local ok, missing = pcall(CHECKS[name], r)
            if ok and missing then out[#out + 1] = name end
        end
    end
    if ns:Supports("cdmReminders") then
        if r.groupBuffs then
            local ok, list = pcall(self.GroupBuffsMissing, self)
            if ok then for _, n in ipairs(list) do out[#out + 1] = n end end
        end
        local ok, list = pcall(self.CustomMissing, self, r)
        if ok then for _, n in ipairs(list) do out[#out + 1] = n end end
    end
    return out
end

---------------------------------------------------------------- frames
local function store()
    local r = function() return M.db.reminders end
    return {
        active = function() return M:IsEnabled() and r().enabled end,
        get = function() local p = r(); return { point = p.point, x = p.x, y = p.y } end,
        set = function(val)
            local p = r()
            p.point, p.x, p.y = val.point or p.point, val.x or p.x, val.y or p.y
        end,
        apply = function() M:RefreshReminders() end,
        reset = function()
            local p, d = r(), M.defaults.reminders
            p.point, p.x, p.y = d.point, d.x, d.y
            M:RefreshReminders()
        end,
    }
end

local function ensureHolder()
    if holder then return holder end
    holder = CreateFrame("Frame", "PhoenixUI_CDM_reminders", UIParent)
    holder:SetSize(36, 36)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cdm.reminders", holder, L.TRACKER_REMINDERS, store()) end
    return holder
end

local function iconFor(i)
    local f = icons[i]
    if f then return f end
    f = CreateFrame("Frame", nil, holder)
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    f.holder = CreateFrame("Frame", nil, f)
    f.holder:SetAllPoints()
    f.Label = f.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Label:SetPoint("TOP", f, "BOTTOM", 0, -2)
    icons[i] = f
    return f
end

local LABELS = { flask = "TRACKER_R_FLASK", food = "TRACKER_R_FOOD", rune = "TRACKER_R_RUNE", oil = "TRACKER_R_OIL",
    raidBuff = "TRACKER_R_RAIDBUFF", pet = "TRACKER_R_PET", healthstone = "TRACKER_R_HEALTHSTONE",
    readyMana = "TRACKER_R_MANA" }
M.REMINDER_LABELS = LABELS

local function iconAndLabel(name)
    local id = tonumber(name:match("^custom:(%d+)$") or "")
    if id then
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        local nm = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        return tex or 134400, nm or tostring(id)
    end
    local class = name:match("^group:(%u+)$")
    if class then
        local sid = RAID_BUFF[class] and RAID_BUFF[class][1]
        local tex = sid and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)
        local nm = sid and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)
        return tex or M.REMINDER_ICONS.raidBuff, nm or L.TRACKER_R_GROUPBUFF
    end
    return M.REMINDER_ICONS[name], L[LABELS[name]]
end
M.ReminderIconAndLabel = iconAndLabel

-- Banner style: the v9 reminder banner behind the row, each icon in the reminder_icon frame.
local function dressBanner(r, w, size)
    local A = ns.Art
    if not (A and A.DressSlot) then return end
    if r.style == "banner" then
        holder.banner = holder.banner or CreateFrame("Frame", nil, holder)
        holder.banner:ClearAllPoints()
        holder.banner:SetPoint("CENTER")
        holder.banner:SetSize(w + size * 1.5, size * 1.6)
        holder.banner:SetFrameLevel(math.max(0, holder:GetFrameLevel() - 1))
        A:DressSlot(holder.banner, "Reminders.banner")
        holder.banner:Show()
    elseif holder.banner then
        if A.Undress then A:Undress(holder.banner) end
        holder.banner:Hide()
    end
end

local function draw(list)
    ensureHolder()
    local r = M.db.reminders
    local size, gap = r.size, 6
    holder:SetSize(math.max(1, #list * (size + gap) - gap), size)
    holder:ClearAllPoints()
    holder:SetPoint(r.point, UIParent, r.point, r.x, r.y)
    for i, name in ipairs(list) do
        local f = iconFor(i)
        f:SetSize(size, size)
        f:ClearAllPoints()
        f:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + gap), 0)
        local tex, label = iconAndLabel(name)
        f.Icon:SetTexture(tex)
        M:StyleIcon("essential", f.Icon, f.holder)
        local A = ns.Art
        if A and A.DressSlot then
            if r.style == "banner" then A:DressSlot(f.holder, "Reminders.icon") elseif A.Undress then A:Undress(f.holder) end
        end
        Skin:TextSpec(f.Label, { size = 10, outline = "OUTLINE" }, "small", "text.primary")
        f.Label:SetText(label or "")
        f:Show()
    end
    for i = #list + 1, #icons do icons[i]:Hide() end
    dressBanner(r, #list * (size + gap), size)
    holder:SetShown(#list > 0)
end

local shown = {}
function M:RefreshReminders()
    if self.reminderTest then return end
    local list = self:MissingReminders()
    local new = false
    for _, name in ipairs(list) do if not shown[name] then new = true end end
    wipe(shown)
    for _, name in ipairs(list) do shown[name] = true end
    if #list > 0 or holder then draw(list) end
    if new and self.db.reminders.sound ~= "" then ns.Media:PlaySound(self.db.reminders.sound) end
end

function M:DrawReminderTest()
    self.reminderTest = true
    draw({ "flask", "food", "oil", "raidBuff", "group:MAGE", "custom:1459" })
end

function M:HideReminderTest()
    self.reminderTest = nil
    if holder then holder:Hide() end
    if self:IsEnabled() then self:RefreshReminders() end
end

local pending = false
local function queue()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        if M:IsEnabled() then ns.SafeCall(M.RefreshReminders, M) end
    end)
end

function M:EnableReminders()
    ensureHolder()
    for _, ev in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UNIT_PET", "GROUP_ROSTER_UPDATE",
        "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
        self:On(ev, queue)
    end
    self:On("UNIT_AURA", function(_, _, unit) if unit == "player" then queue() end end)
    self:On("PLAYER_REGEN_DISABLED", function() if holder and not M.reminderTest then holder:Hide() end end)
    self:On("READY_CHECK", function()
        readyUntil = GetTime() + 15
        queue()
        C_Timer.After(15.5, queue)
    end)
end

function M:DisableReminders()
    if holder then holder:Hide() end
    wipe(shown)
end
