local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Spark feed: turns game events into Spark messages (one owner per 1.O:
-- combat in/out, item ready, loot / money / currency / reputation / XP text).
--  * Incoming (you and your pet): UNIT_COMBAT. The amount may be secret; it is
--    passed through, never added or compared.
--  * Outgoing: there is no combat log in Midnight. Spark reads UNIT_COMBAT on
--    your target and works out whether the hit was yours from your own casts:
--    a hit right after your cast is "worked out" (confident) and named; with
--    the default mode only confident hits are shown, "all hits" shows the rest
--    without a name (mockup note 1).
--  * Combat leave is watched on a Ticker entry that lives only for the fight
--    (PLAYER_REGEN_ENABLED belongs to the CombatQueue), item cooldowns are watched on a Ticker entry only while one of
--    your watched items is cooling down.
local _, ns = ...
local Secret, Ticker = PUI.Secret, PUI.Ticker
local E = ns.Engine
local F = { lastCast = nil, items = {}, money = nil, xp = nil }
ns.Feed = F
local OWNER = "Spark"

F.ROWS = {
  { id = "inDamage", label = "Damage you take", area = "incoming", color = { r = 1, g = 0.33, b = 0.33 }, template = "-%a %t" },
  { id = "inHeal", label = "Heals you get", area = "incoming", color = { r = 0.35, g = 1, b = 0.45 }, template = "+%a %t" },
  { id = "inAvoid", label = "Hits you avoid (dodge, parry, absorb...)", area = "incoming", color = { r = 0.85, g = 0.85, b = 0.9 }, template = "%e" },
  { id = "petDamage", label = "Damage your pet takes", area = "incoming", color = { r = 0.9, g = 0.5, b = 0.3 }, template = "Pet -%a" },
  { id = "petHeal", label = "Heals your pet gets", area = "incoming", color = { r = 0.4, g = 0.85, b = 0.5 }, template = "Pet +%a" },
  { id = "outDamage", label = "Your damage", area = "outgoing", color = { r = 1, g = 0.95, b = 0.85 }, template = "%a %s %c" },
  { id = "outHeal", label = "Your heals", area = "outgoing", color = { r = 0.4, g = 1, b = 0.55 }, template = "+%a %s %c" },
  { id = "outAvoid", label = "Your misses", area = "outgoing", color = { r = 0.7, g = 0.7, b = 0.75 }, template = "%e" },
  { id = "combatIn", label = "Entering combat", area = "notification", color = { r = 1, g = 0.35, b = 0.3 }, template = "+Combat" },
  { id = "combatOut", label = "Leaving combat", area = "notification", color = { r = 0.4, g = 1, b = 0.5 }, template = "-Combat" },
  { id = "itemReady", label = "Item or potion ready", area = "notification", color = { r = 0.98, g = 0.82, b = 0.3 }, template = "%s ready" },
  { id = "loot", label = "Loot", area = "notification", color = { r = 1, g = 1, b = 1 }, template = "+%s %c" },
  { id = "money", label = "Money", area = "notification", color = { r = 1, g = 0.84, b = 0.2 }, template = "+%s" },
  { id = "currency", label = "Currency", area = "notification", color = { r = 0.6, g = 0.85, b = 1 }, template = "+%s %c" },
  { id = "reputation", label = "Reputation", area = "notification", color = { r = 0.55, g = 0.6, b = 1 }, template = "%s" },
  { id = "xp", label = "Experience", area = "notification", color = { r = 0.75, g = 0.45, b = 1 }, template = "+%a XP" },
  { id = "honor", label = "Honor", area = "notification", color = { r = 1, g = 0.5, b = 0.2 }, template = "%s" },
  { id = "skill", label = "Skill ups", area = "notification", color = { r = 0.5, g = 0.75, b = 1 }, template = "%s" },
}
F.BY_ID = {}
for _, r in ipairs(F.ROWS) do F.BY_ID[r.id] = r end

F.AVOID = { DODGE = "Dodge", PARRY = "Parry", MISS = "Miss", BLOCK = "Block", ABSORB = "Absorb", RESIST = "Resist", IMMUNE = "Immune",
  DEFLECT = "Deflect", REFLECT = "Reflect", EVADE = "Evade" }
F.SCHOOL = { [1] = { r = 1, g = 1, b = 0.85 }, [2] = { r = 1, g = 0.9, b = 0.5 }, [4] = { r = 1, g = 0.5, b = 0.1 }, [8] = { r = 0.3, g = 1, b = 0.3 },
  [16] = { r = 0.5, g = 1, b = 1 }, [32] = { r = 0.6, g = 0.45, b = 1 }, [64] = { r = 1, g = 0.5, b = 1 } }

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

-- Emit(rowId, tok, extra): builds the message from the row's settings and queues it.
function F.Emit(rowId, tok, extra)
  local S = F.S
  if not S then return nil end
  local row = F.BY_ID[rowId]
  local rs = S.rows[rowId]
  if not (row and rs and rs.on) then return nil end
  extra = extra or {}
  local short = S.master.shortNumbers
  tok.amount = tok.amount ~= nil and E.AmountText(tok.amount, short) or tok.amountText
  local template = rs.template ~= "" and rs.template or row.template
  local fmt, args = E.Compose(template, tok)
  local msg = { fmt = fmt, args = args, color = extra.color or rs.color, crit = extra.crit, icon = tok.icon,
    mergeKey = extra.mergeKey, plainAmount = extra.plainAmount, amountText = tok.amount, short = short, row = rowId }
  msg.build = function(amount, count)
    local t = {}
    for k, v in pairs(tok) do t[k] = v end
    t.amount, t.count = amount, count
    return E.Compose(template, t)
  end
  return E.Queue(rs.area, msg, S.areas[rs.area], S.master)
end

-- Own casts: the attribution source for outgoing text.
function F.OnCast(unit, _, spellID)
  if unit ~= "player" or not plain(spellID) then return end
  F.lastCast = { id = spellID, t = GetTime() }
end
-- Confidence: "high" when the hit lands within the window after your cast;
-- nil when ambiguous (another player may have done it).
function F.Attribute(now)
  local c = F.lastCast
  if c and now - c.t <= F.S.master.attributionWindow then return "high", c.id end
  return nil
end

function F.OnUnitCombat(unit, event, flag, amount, school)
  local S = F.S
  if not S then return end
  local crit = plain(flag) and flag == "CRITICAL"
  local trailer = plain(flag) and (flag == "CRUSHING" and "(crushing)" or (flag == "GLANCING" and "(glancing)")) or nil
  local ev = plain(event) and event or nil
  local color
  if S.master.schoolColors and plain(school) then color = F.SCHOOL[school] end
  local plainAmount = plain(amount) and amount or nil
  if unit == "player" or unit == "pet" then
    local pet = unit == "pet"
    if ev and F.AVOID[ev] then
      if not pet then F.Emit("inAvoid", { event = F.AVOID[ev] }) end
    elseif ev == "HEAL" then
      F.Emit(pet and "petHeal" or "inHeal", { amount = amount, trailer = trailer }, { crit = crit, plainAmount = plainAmount })
    elseif ev == "WOUND" or ev == nil then
      F.Emit(pet and "petDamage" or "inDamage", { amount = amount, trailer = trailer }, { crit = crit, color = color, plainAmount = plainAmount })
    end
    return
  end
  if unit ~= "target" then return end
  local conf, spellID = F.Attribute(GetTime())
  if not conf and S.master.outgoingMode ~= "all" then return end
  local spell = spellID and C_Spell.GetSpellName(spellID) or nil
  local icon = spellID and C_Spell.GetSpellTexture(spellID) or nil
  local key = spellID and ("out" .. spellID) or nil
  if ev and F.AVOID[ev] then
    if conf then F.Emit("outAvoid", { event = F.AVOID[ev], spell = spell, icon = icon }) end
  elseif ev == "HEAL" then
    F.Emit("outHeal", { amount = amount, spell = spell, icon = icon }, { crit = crit, mergeKey = key and (key .. "h"), plainAmount = plainAmount })
  elseif ev == "WOUND" or ev == nil then
    F.Emit("outDamage", { amount = amount, spell = spell, icon = icon }, { crit = crit, color = color, mergeKey = key, plainAmount = plainAmount })
  end
  F.lastConfidence = conf
end

-- Combat in / out -----------------------------------------------------------------
-- PLAYER_REGEN_DISABLED fires just before lockdown starts, so the leave
-- check is a 0.5 s Ticker entry that lives only for the fight: it waits until
-- lockdown has been seen (or a second passed) and then for it to end.
function F.OnCombatStart()
  F.Emit("combatIn", {})
  F.combatAt, F.lockSeen = GetTime(), false
  Ticker:Register("spark.combat", 0.5, F.WatchCombat, OWNER)
end
function F.WatchCombat()
  if InCombatLockdown() then F.lockSeen = true return end
  if F.lockSeen or GetTime() - F.combatAt > 1 then
    Ticker:Unregister("spark.combat")
    F.Emit("combatOut", {})
  end
end

-- Items ------------------------------------------------------------------------------
function F.Watched()
  local out = {}
  for _, v in ipairs(F.S and F.S.master.items or {}) do local id = tonumber(v); if id then out[#out + 1] = id end end
  return out
end
function F.ScanItems()
  local now = GetTime()
  for _, id in ipairs(F.Watched()) do
    local start, dur = C_Container.GetItemCooldown(id)
    if plain(start) and plain(dur) and start > 0 and dur >= F.S.master.itemThreshold then
      F.items[id] = start + dur
    end
  end
  F.ArmItems(now)
end
function F.ArmItems()
  if next(F.items) and not Ticker:IsRegistered("spark.items") then Ticker:Register("spark.items", 0.5, F.TickItems, OWNER)
  elseif not next(F.items) then Ticker:Unregister("spark.items") end
end
function F.TickItems()
  local now = GetTime()
  for id, at in pairs(F.items) do
    if now >= at then
      F.items[id] = nil
      F.Emit("itemReady", { spell = C_Item.GetItemNameByID(id) or ("Item " .. id), icon = C_Item.GetItemIconByID(id) })
    end
  end
  F.ArmItems()
end

-- Loot and progress ---------------------------------------------------------------------
local LINK = "(|c%x+|H[^|]+|h.-|h|r)"
function F.ParseLoot(text)
  if not plain(text) then return nil end
  local link = text:match(LINK)
  if not link then return nil end
  local count = tonumber(text:match("|rx(%d+)") or text:match("x(%d+)%.?$") or "1") or 1
  return link, count
end
local function mine(guid)
  if not plain(guid) then return false end
  local me = UnitGUID("player")
  return plain(me) and guid == me
end
function F.OnLoot(text, _, _, _, _, _, _, _, _, _, _, guid)
  if not mine(guid) then return end
  local link, count = F.ParseLoot(text)
  if not link then return end
  local q = C_Item.GetItemQualityByID(link)
  if plain(q) and q < F.S.master.lootQuality then return end
  F.Emit("loot", { spell = link, count = count, icon = select(5, C_Item.GetItemInfoInstant(link)) })
end
function F.OnCurrency(text)
  local link, count = F.ParseLoot(text)
  if link then F.Emit("currency", { spell = link, count = count }) end
end
function F.OnMoney()
  local now = GetMoney()
  if F.money and now > F.money then F.Emit("money", { spell = C_CurrencyInfo.GetCoinTextureString(now - F.money) }) end
  F.money = now
end
function F.OnXP(unit)
  if unit ~= nil and unit ~= "player" then return end
  local now = UnitXP("player")
  if plain(now) and F.xp and now > F.xp then F.Emit("xp", { amount = now - F.xp }, { plainAmount = now - F.xp, mergeKey = "xp" }) end
  F.xp = plain(now) and now or nil
end
local function textRow(row) return function(text) if plain(text) then F.Emit(row, { spell = text }) end end end
F.OnRep, F.OnHonor, F.OnSkill = textRow("reputation"), textRow("honor"), textRow("skill")

function F.Enable(mod, S)
  F.S = S
  F.money, F.xp = GetMoney(), UnitXP("player")
  if not plain(F.xp) then F.xp = nil end
  local function on(ev, fn) mod:RegisterEvent(ev, function(_, _, ...) fn(...) end) end
  mod:RegisterUnitEvent("UNIT_COMBAT", function(_, _, ...) F.OnUnitCombat(...) end, "player", "pet")
  F.targetFrame = F.targetFrame or PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  F.targetFrame:SetScript("OnEvent", function(_, _, ...) F.OnUnitCombat(...) end)
  F.targetFrame:RegisterUnitEvent("UNIT_COMBAT", "target")
  on("UNIT_SPELLCAST_SUCCEEDED", F.OnCast)
  on("PLAYER_REGEN_DISABLED", F.OnCombatStart)
  on("BAG_UPDATE_COOLDOWN", F.ScanItems)
  on("CHAT_MSG_LOOT", F.OnLoot)
  on("CHAT_MSG_CURRENCY", F.OnCurrency)
  on("PLAYER_MONEY", F.OnMoney)
  on("PLAYER_XP_UPDATE", F.OnXP)
  on("CHAT_MSG_COMBAT_FACTION_CHANGE", F.OnRep)
  on("CHAT_MSG_COMBAT_HONOR_GAIN", F.OnHonor)
  on("CHAT_MSG_SKILL", F.OnSkill)
end
function F.Disable()
  if F.targetFrame then F.targetFrame:UnregisterEvent("UNIT_COMBAT") end
  wipe(F.items)
  Ticker:Unregister("spark.items")
  Ticker:Unregister("spark.combat")
end
