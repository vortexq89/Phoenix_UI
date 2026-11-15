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
      mana       on a ready check, for a few seconds, when your mana is below the threshold
      class      rogue poisons, shaman elemental shield, holy paladin beacon on a group member (retail)
    Icons are secure buttons of ours (review 30): a left click casts the buff or uses the best matching item from
    your bags (oils with "/use 16" for the main hand), a right click hides that reminder until the next zone.
    They are drawn and changed out of combat only and hidden as combat starts (PLAYER_REGEN_DISABLED). ]]

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
local CREATE_HEALTHSTONE = 6201 -- spellIDs(retail): Create Healthstone
local POISON_LETHAL = { 315584, 2823, 8679, 381664 } -- spellIDs(retail): Instant Poison, Deadly Poison, Wound Poison, Amplifying Poison
local POISON_UTILITY = { 3408, 5761, 381637 } -- spellIDs(retail): Crippling Poison, Numbing Poison, Atrophic Poison
local SHIELDS = { 192106, 52127, 974 } -- spellIDs(retail): Lightning Shield, Water Shield, Earth Shield
local BEACONS = { 53563, 156910 } -- spellIDs(retail): Beacon of Light, Beacon of Faith
local BEACON_VIRTUE = 200025 -- spellIDs(retail): Beacon of Virtue
local PET_SPELL = { HUNTER = 883, DEATHKNIGHT = 46585, WARLOCK = 688 } -- spellIDs(retail): Call Pet 1, Raise Dead, Summon Imp
local FELGUARD = 30146 -- spellIDs(retail): Summon Felguard
-- pet classes: true = every spec, or the spec indices that use a pet
local PET = { WARLOCK = true, HUNTER = { [1] = true, [3] = true }, DEATHKNIGHT = { [3] = true } }

M.REMINDERS = { "flask", "food", "rune", "oil", "raidBuff", "classBuff", "pet", "healthstone", "readyMana" }
M.REMINDER_ICONS = {
    flask = "Interface\\Icons\\INV_Potion_97", food = "Interface\\Icons\\INV_Misc_Food_15",
    rune = "Interface\\Icons\\INV_Misc_Rune_01", oil = "Interface\\Icons\\INV_Potion_100",
    raidBuff = "Interface\\Icons\\Spell_Holy_MagicalSentry", pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
    healthstone = "Interface\\Icons\\INV_Stone_04", readyMana = "Interface\\Icons\\INV_Potion_76",
}
local SPELL_BASED = { flask = true, food = true, rune = true, raidBuff = true, classBuff = true }

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

local function known(id)
    local ok, k = pcall(C_SpellBook.IsSpellKnown, id)
    return ok and plain(k) and k and true or false
end

local function firstKnown(ids)
    for _, id in ipairs(ids) do if known(id) then return id end end
end

local function spec()
    local api = C_SpecializationInfo
    local s = api and api.GetSpecialization and api.GetSpecialization()
    return plain(s) and s or nil
end

-- Group units (not the player), for the beacon look-up.
local function groupUnits()
    local out, n = {}, tonumber(GetNumGroupMembers and GetNumGroupMembers()) or 0
    if n == 0 then return out end
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and n or n - 1 do out[#out + 1] = (raid and "raid" or "party") .. i end
    return out
end

local function beaconOut()
    local names = {}
    for _, id in ipairs(BEACONS) do names[#names + 1] = C_Spell.GetSpellName(id) end
    if #names == 0 or not C_UnitAuras.GetAuraDataBySpellName then return true end
    for _, unit in ipairs(groupUnits()) do
        local isMe = UnitIsUnit(unit, "player")
        if not (plain(isMe) and isMe) then
            for _, nm in ipairs(names) do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nm, "HELPFUL|PLAYER")
                if not ok or not plain(aura) or aura then return true end
            end
        end
    end
    return false
end

-- Class self buffs: "class:poison", "class:shield" or "class:beacon" when missing, else false.
local function classBuffMissing()
    local _, class = UnitClass("player")
    if class == "ROGUE" then
        if firstKnown(POISON_LETHAL) and not hasAny(POISON_LETHAL) then return "class:poison" end
        if firstKnown(POISON_UTILITY) and not hasAny(POISON_UTILITY) then return "class:poison2" end
    elseif class == "SHAMAN" then
        if firstKnown(SHIELDS) and not hasAny(SHIELDS) then return "class:shield" end
    elseif class == "PALADIN" and spec() == 1 and not known(BEACON_VIRTUE) and firstKnown(BEACONS) then
        if #groupUnits() > 0 and not beaconOut() then return "class:beacon" end
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
        if not (ids and known(ids[1])) then return false end
        return not hasAny(ids)
    end,
    classBuff = classBuffMissing,
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
    local s = spec()
    local role = type(s) == "number" and GetSpecializationRole and GetSpecializationRole(s)
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

M.dismissed = {} -- reminder key -> true until the next zone (right click on an icon)

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
            if ok and missing then
                local key = type(missing) == "string" and missing or name
                if not M.dismissed[key] then out[#out + 1] = key end
            end
        end
    end
    if ns:Supports("cdmReminders") then
        if r.groupBuffs then
            local ok, list = pcall(self.GroupBuffsMissing, self)
            if ok then for _, n in ipairs(list) do if not M.dismissed[n] then out[#out + 1] = n end end end
        end
        local ok, list = pcall(self.CustomMissing, self, r)
        if ok then for _, n in ipairs(list) do if not M.dismissed[n] then out[#out + 1] = n end end end
    end
    return out
end

---------------------------------------------------------------- click actions (review 30)
local function asSet(ids) local t = {} for _, id in ipairs(ids) do t[id] = true end return t end
local FLASK_SET, RUNE_SET = asSet(FLASKS), asSet(RUNES)
local CONSUMABLE = 0
local SUB = { flask = 3, food = 5, oil = 6 } -- Enum.ItemConsumableSubclass: Flasksphials, Fooddrink, Itemenhancement

-- Best bag item for a reminder from { id, class, sub, spell, level } rows (pure, smoke-tested): an item whose
-- use spell is one of the known buffs first, then the matching consumable kind, the highest level first.
function M.PickReminderItem(kind, rows)
    local best, bestScore
    for _, it in ipairs(rows or {}) do
        local score
        if kind == "flask" and FLASK_SET[it.spell] then score = 1000
        elseif kind == "rune" and RUNE_SET[it.spell] then score = 1000
        elseif SUB[kind] and it.class == CONSUMABLE and it.sub == SUB[kind] and it.spell then score = 0 end
        if score then
            score = score + (tonumber(it.level) or 0)
            if not bestScore or score > bestScore or (score == bestScore and it.id > best.id) then
                best, bestScore = it, score
            end
        end
    end
    return best and best.id or nil
end

local BAGS = { 0, 1, 2, 3, 4, 5 }
local function bagRows()
    local rows, seen = {}, {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return rows end
    for _, bag in ipairs(BAGS) do
        for slot = 1, tonumber(C_Container.GetContainerNumSlots(bag)) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] then
                seen[id] = true
                local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
                local _, spellID = C_Item.GetItemSpell(id)
                local level = select(5, C_Item.GetItemInfo(id))
                rows[#rows + 1] = { id = id, class = classID, sub = subID, spell = spellID, level = level }
            end
        end
    end
    return rows
end

local function tankUnit()
    for _, unit in ipairs(groupUnits()) do
        local role = UnitGroupRolesAssigned(unit)
        if plain(role) and role == "TANK" then return unit end
    end
end

local ITEM_KIND = { flask = true, food = true, rune = true, oil = true }

-- What a left click on a reminder does: { type = "spell" | "item" | "macro", spell, item, unit, macrotext } or nil.
function M:ReminderAction(name)
    local _, class = UnitClass("player")
    if ITEM_KIND[name] then
        local id = M.PickReminderItem(name, bagRows())
        if not id then return nil end
        if name == "oil" then return { type = "macro", item = id, macrotext = "/use item:" .. id .. "\n/use 16" } end
        return { type = "item", item = id }
    end
    local spell
    if name == "raidBuff" or name == "group:" .. tostring(class) then
        spell = RAID_BUFF[class] and RAID_BUFF[class][1]
    elseif name == "class:poison" then spell = firstKnown(POISON_LETHAL)
    elseif name == "class:poison2" then spell = firstKnown(POISON_UTILITY)
    elseif name == "class:shield" then
        spell = (spec() == 3 and known(SHIELDS[2])) and SHIELDS[2] or firstKnown(SHIELDS)
    elseif name == "class:beacon" then
        spell = firstKnown(BEACONS)
        if spell then return { type = "spell", spell = spell, unit = tankUnit() } end
    elseif name == "pet" then
        spell = (class == "WARLOCK" and spec() == 2 and known(FELGUARD)) and FELGUARD or PET_SPELL[class]
    elseif name == "healthstone" then
        spell = class == "WARLOCK" and CREATE_HEALTHSTONE or nil
    else
        local id = tonumber(name:match("^custom:(%d+)$") or "")
        spell = id and known(id) and id or nil
    end
    if spell and known(spell) then return { type = "spell", spell = spell } end
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

local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(self.labelText or "", 1, 1, 1)
    local act = self.action
    if act and act.item then
        local nm = C_Item.GetItemNameByID(act.item)
        GameTooltip:AddLine(L.TRACKER_R_CLICK_USE:format(nm or ("item:" .. act.item)), 0.6, 1, 0.6)
    elseif act and act.spell then
        local nm = C_Spell.GetSpellName(act.spell) or tostring(act.spell)
        local who = act.unit and UnitName(act.unit)
        if who and plain(who) then nm = nm .. " > " .. who end
        GameTooltip:AddLine(L.TRACKER_R_CLICK_CAST:format(nm), 0.6, 1, 0.6)
    elseif self.reminder and ITEM_KIND[self.reminder] then
        GameTooltip:AddLine(L.TRACKER_R_NONE_BAGS, 1, 0.5, 0.4)
    end
    if M.db.reminders.dismiss and not M.reminderTest then GameTooltip:AddLine(L.TRACKER_R_DISMISS_HINT, 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end

local function postClick(self, button)
    if button ~= "RightButton" or not M.db.reminders.dismiss or M.reminderTest or not self.reminder then return end
    M.dismissed[self.reminder] = true
    GameTooltip:Hide()
    if not InCombatLockdown() then M:RefreshReminders() end
end

local function iconFor(i)
    local f = icons[i]
    if f then return f end
    f = CreateFrame("Button", "PhoenixUI_Reminder" .. i, holder, "SecureActionButtonTemplate")
    f:RegisterForClicks("AnyUp")
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    f.holder = CreateFrame("Frame", nil, f)
    f.holder:SetAllPoints()
    f.Label = f.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Label:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.Count = f.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 2)
    f:SetScript("OnEnter", onEnter)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("PostClick", postClick)
    icons[i] = f
    return f
end

local ATTRS = { "type1", "spell", "item", "unit", "macrotext" }
-- Secure attributes for one icon (out of combat only; the caller checks).
local function arm(f, act)
    for _, k in ipairs(ATTRS) do f:SetAttribute(k, nil) end
    if not act then return end
    f:SetAttribute("type1", act.type)
    if act.type == "spell" then f:SetAttribute("spell", act.spell) end
    if act.type == "item" then f:SetAttribute("item", "item:" .. act.item) end
    if act.type == "macro" then f:SetAttribute("macrotext", act.macrotext) end
    if act.unit then f:SetAttribute("unit", act.unit) end
end
M.ArmReminder = arm

local LABELS = { flask = "TRACKER_R_FLASK", food = "TRACKER_R_FOOD", rune = "TRACKER_R_RUNE", oil = "TRACKER_R_OIL",
    raidBuff = "TRACKER_R_RAIDBUFF", pet = "TRACKER_R_PET", healthstone = "TRACKER_R_HEALTHSTONE",
    readyMana = "TRACKER_R_MANA", classBuff = "TRACKER_R_CLASSBUFF" }
local CLASS_ICON = { poison = POISON_LETHAL[2], poison2 = POISON_UTILITY[1], shield = SHIELDS[1], beacon = BEACONS[1] }
M.REMINDER_LABELS = LABELS

local function iconAndLabel(name)
    local id = tonumber(name:match("^custom:(%d+)$") or "")
    if id then
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        local nm = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        return tex or 134400, nm or tostring(id)
    end
    local cb = name:match("^class:(%w+)$")
    if cb then
        local sid = CLASS_ICON[cb]
        local tex = sid and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)
        local nm = sid and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)
        return tex or 134400, nm or L.TRACKER_R_CLASSBUFF
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
        local act = (r.click and not M.reminderTest) and M:ReminderAction(name) or nil
        if act and act.item then tex = C_Item.GetItemIconByID(act.item) or tex end
        f.reminder, f.action, f.labelText = name, act, label
        arm(f, act)
        f.Icon:SetTexture(tex)
        f.Icon:SetDesaturated(r.click and not M.reminderTest and ITEM_KIND[name] and not act or false)
        local n = act and act.item and tonumber(C_Item.GetItemCount(act.item)) or 0
        Skin:TextSpec(f.Count, { size = 10, outline = "OUTLINE" }, "number", "text.primary")
        f.Count:SetText(n > 1 and n or "")
        M:StyleIcon("essential", f.Icon, f.holder)
        if r.glow ~= "none" then
            local gr, gg, gb = Skin:SpecColor(nil, "accent.glow")
            ns.Glow:Show(f, r.glow, gr, gg, gb, 1, "reminder")
        else
            ns.Glow:Hide(f, "reminder")
        end
        local A = ns.Art
        if A and A.DressSlot then
            if r.style == "banner" then A:DressSlot(f.holder, "Reminders.icon") elseif A.Undress then A:Undress(f.holder) end
        end
        Skin:TextSpec(f.Label, { size = 10, outline = "OUTLINE" }, "small", "text.primary")
        f.Label:SetText(label or "")
        f.Label:SetShown(r.labels ~= false)
        f:Show()
    end
    for i = #list + 1, #icons do
        icons[i]:Hide()
        arm(icons[i], nil)
        icons[i].reminder, icons[i].action = nil, nil
    end
    dressBanner(r, #list * (size + gap), size)
    holder:SetShown(#list > 0)
end

local shown = {}
function M:RefreshReminders()
    if self.reminderTest or InCombatLockdown() then return end -- secure icons change out of combat only
    local list = self:MissingReminders()
    local new = false
    for _, name in ipairs(list) do if not shown[name] then new = true end end
    wipe(shown)
    for _, name in ipairs(list) do shown[name] = true end
    if #list > 0 or holder then draw(list) end
    if new and self.db.reminders.sound ~= "" then ns.Media:PlaySound(self.db.reminders.sound) end
end

function M:DrawReminderTest()
    if InCombatLockdown() then return end
    self.reminderTest = true
    draw({ "flask", "food", "oil", "raidBuff", "group:MAGE", "custom:1459" })
end

function M:HideReminderTest()
    self.reminderTest = nil
    if holder and not InCombatLockdown() then holder:Hide() end
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
    for _, ev in ipairs({ "PLAYER_REGEN_ENABLED", "UNIT_PET", "GROUP_ROSTER_UPDATE",
        "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "PLAYER_MOUNT_DISPLAY_CHANGED", "SPELLS_CHANGED",
        "PLAYER_ROLES_ASSIGNED" }) do
        self:On(ev, queue)
    end
    for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        self:On(ev, function() wipe(M.dismissed); queue() end)
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
    if holder and not InCombatLockdown() then holder:Hide() end
    wipe(shown)
end
