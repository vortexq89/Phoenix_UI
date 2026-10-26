local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault store: offline characters' items (bags, bank, warband bank shared
-- by the account) and the gold history Vault records into PUI.Wallet (the
-- owner of gold and currency data; Data Bars only read it). Saved outside
-- profiles in PhoenixUIDB.vault so a profile switch never loses it. Only
-- plain item IDs and counts are stored.
local _, ns = ...
local VA = ns.VA
local Wallet = PUI.Wallet
local s = VA.settings
local ST = {}
ns.Store = ST
VA.Store = ST

function ST.DB()
  local sv = PUI.DB and PUI.DB.sv
  if not sv then return nil end
  sv.vault = sv.vault or { chars = {}, warband = {} }
  return sv.vault
end

-- { [itemID] = count } for a list of bags.
function ST.Count(bags)
  local out = {}
  for _, bag in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then out[info.itemID] = (out[info.itemID] or 0) + (info.stackCount or 1) end
    end
  end
  return out
end

function ST.SnapshotBags()
  local db = ST.DB()
  if not db or not s.alts then return end
  local key = PUI.DB:CharKey()
  local _, class = UnitClass("player")
  local c = db.chars[key] or {}
  c.class, c.updated, c.bags = class, time(), ST.Count(VA.BAGS)
  db.chars[key] = c
end

function ST.SnapshotBank(charBags, warbandBags)
  local db = ST.DB()
  if not db or not s.alts then return end
  local key = PUI.DB:CharKey()
  db.chars[key] = db.chars[key] or {}
  if charBags then db.chars[key].bank = ST.Count(charBags) end
  if warbandBags then db.warband = ST.Count(warbandBags) end
end

-- Characters with stored items, newest first (this one excluded on request).
function ST.Alts(excludeSelf)
  local db, out = ST.DB(), {}
  if not db then return out end
  local me = PUI.DB:CharKey()
  for k, c in pairs(db.chars) do
    if not (excludeSelf and k == me) then out[#out + 1] = { key = k, class = c.class, updated = c.updated or 0, bags = c.bags or {}, bank = c.bank or {} } end
  end
  table.sort(out, function(a, b) return a.updated > b.updated end)
  return out
end

-- Where an item is across every character: { total, { key, bags, bank } }.
function ST.Where(itemID)
  local db = ST.DB()
  local rows, total = {}, 0
  if not db then return 0, rows end
  for k, c in pairs(db.chars) do
    local b, k2 = (c.bags or {})[itemID] or 0, (c.bank or {})[itemID] or 0
    if b + k2 > 0 then rows[#rows + 1] = { key = k, bags = b, bank = k2 }; total = total + b + k2 end
  end
  local w = (db.warband or {})[itemID] or 0
  if w > 0 then rows[#rows + 1] = { key = "Warband bank", bags = 0, bank = w }; total = total + w end
  table.sort(rows, function(a, b) return a.bags + a.bank > b.bags + b.bank end)
  return total, rows
end

function ST.Forget(key)
  local db = ST.DB()
  if db then db.chars[key] = nil end
  Wallet:Wipe(key)
end

-- Gold history: one entry per day per character through PUI.Wallet.
function ST.RecordGold()
  if not s.goldHistory then return end
  local _, class = UnitClass("player")
  Wallet:Record(nil, Wallet:Gold(), class)
end

function ST.FooterText()
  local parts = { "Gold " .. Wallet:Money(Wallet:Gold(), s.goldStyle) }
  if s.goldHistory then
    local d = Wallet:Today()
    if d ~= 0 then parts[1] = parts[1] .. string.format(" (today %s%s)", d > 0 and "+" or "", Wallet:Money(d, "gold")) end
  end
  if s.currencies then
    for i, c in ipairs(Wallet:Watched()) do
      if i > 3 then break end
      parts[#parts + 1] = "|T" .. tostring(c.icon) .. ":12|t " .. BreakUpLargeNumbers(c.quantity)
    end
  end
  return table.concat(parts, "   ")
end

function ST.GoldTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:SetText("Gold")
  for _, c in ipairs(Wallet:Characters()) do
    local col = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    GameTooltip:AddDoubleLine(c.key, Wallet:Money(c.gold, "gold"), col and col.r or 1, col and col.g or 1, col and col.b or 1, 1, 1, 1)
  end
  GameTooltip:AddDoubleLine("Total", Wallet:Money(Wallet:Total(), "gold"), 0.9, 0.64, 0.24, 0.9, 0.64, 0.24)
  local h = Wallet:History()
  if #h > 1 then
    GameTooltip:AddLine(" ")
    for i = math.max(1, #h - 6), #h do
      local e = h[i]
      GameTooltip:AddDoubleLine(tostring(e.day):gsub("^(%d%d%d%d)(%d%d)(%d%d)$", "%1-%2-%3"), Wallet:Money(e.gold, "gold"), 0.7, 0.7, 0.7, 1, 1, 1)
    end
  end
  GameTooltip:Show()
end

PUI.Slash:Register("vault", function(rest)
  rest = (rest or ""):lower()
  if rest == "gold wipe" then
    PUI.Dialogs:Confirm({ title = "Forget gold history", text = "Remove the gold history of every character? This cannot be undone.",
      accept = "Forget", cancel = "Keep", onAccept = function() Wallet:Wipe() end })
  elseif rest == "bank" then if ns.Bank then ns.Bank.Toggle() end
  else VA.Toggle() end
end, "vault: bank | gold wipe")
