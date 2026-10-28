local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Wallet (plan 1.O "Gold ledger, currencies"): the minimal shared gold and
-- currency provider. Vault owns the feature (offline alts, gold history); this
-- file is the read API Data Bars and Vault both use, so neither keeps its own
-- copy. Event-driven; reads are cheap and pure.
--   Wallet:Gold() -> copper (number)
--   Wallet:Session() -> copper gained (+) or spent (-) since login
--   Wallet:Currency(id) -> { id, name, quantity, max, icon } or nil
--   Wallet:Watched() -> the backpack ("show on backpack") currencies, in order
--   Wallet:Money(copper, style) -> "12,345g 67s 89c" | "12,345g" | coin icons
local Wallet = { start = nil }
PUI.Wallet = Wallet

function Wallet:Gold() return GetMoney() or 0 end

function Wallet:Session()
  if not self.start then return 0 end
  return self:Gold() - self.start
end

function Wallet:Currency(id)
  if type(id) ~= "number" then return nil end
  local info = C_CurrencyInfo.GetCurrencyInfo(id)
  if type(info) ~= "table" or not info.name or info.name == "" then return nil end
  return { id = id, name = info.name, quantity = info.quantity or 0, max = info.maxQuantity or 0, icon = info.iconFileID }
end

function Wallet:Watched()
  local out = {}
  for i = 1, 10 do
    local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
    if type(info) ~= "table" then break end
    out[#out + 1] = { id = info.currencyTypesID, name = info.name, quantity = info.quantity or 0, icon = info.iconFileID }
  end
  return out
end

-- style: "full" (g s c), "gold" (gold only), "icons" (Blizzard coin string).
function Wallet:Money(copper, style)
  copper = math.floor(copper or 0)
  local neg = copper < 0
  copper = math.abs(copper)
  local text
  if style == "icons" then
    text = C_CurrencyInfo.GetCoinTextureString(copper)
  else
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local gold = BreakUpLargeNumbers(g) .. "g"
    if style == "gold" then text = gold else text = string.format("%s %ds %dc", gold, s, c) end
  end
  return (neg and "-" or "") .. text
end

-- Gold history and offline characters (Vault owns recording; anyone reads).
-- Stored outside profiles in PhoenixUIDB.wallet so profile switches never
-- touch it:  chars[key] = { gold, class, updated }, days[key][YYYYMMDD] = gold.
Wallet.KEEP_DAYS = 90
local function store()
  local sv = PUI.DB and PUI.DB.sv
  if not sv then return nil end
  sv.wallet = sv.wallet or { chars = {}, days = {} }
  return sv.wallet
end
Wallet.Store = store

function Wallet.DayKey(t) return tonumber(date("%Y%m%d", t or time())) end

-- Pure trim: keeps the newest `keep` day entries of one character's history.
function Wallet.Trim(days, keep)
  local list = {}
  for d in pairs(days) do list[#list + 1] = d end
  if #list <= keep then return 0 end
  table.sort(list)
  local n = #list - keep
  for i = 1, n do days[list[i]] = nil end
  return n
end

function Wallet:Record(charKey, copper, class, t)
  local w = store()
  if not w or type(copper) ~= "number" then return false end
  charKey = charKey or PUI.DB:CharKey()
  w.chars[charKey] = { gold = copper, class = class, updated = t or time() }
  w.days[charKey] = w.days[charKey] or {}
  w.days[charKey][self.DayKey(t)] = copper
  self.Trim(w.days[charKey], self.KEEP_DAYS)
  return true
end

-- { { key, gold, class, updated }, ... } richest first.
function Wallet:Characters()
  local w, out = store(), {}
  if not w then return out end
  for k, c in pairs(w.chars) do out[#out + 1] = { key = k, gold = c.gold, class = c.class, updated = c.updated } end
  table.sort(out, function(a, b) if a.gold ~= b.gold then return a.gold > b.gold end return a.key < b.key end)
  return out
end

function Wallet:Total()
  local n = 0
  for _, c in ipairs(self:Characters()) do n = n + (c.gold or 0) end
  return n
end

-- Ascending { { day, gold } } for one character (default: this one).
function Wallet:History(charKey)
  local w, out = store(), {}
  local days = w and w.days[charKey or PUI.DB:CharKey()]
  if not days then return out end
  for d, g in pairs(days) do out[#out + 1] = { day = d, gold = g } end
  table.sort(out, function(a, b) return a.day < b.day end)
  return out
end

-- Change since the previous recorded day (0 when there is none).
function Wallet:Today(charKey)
  local h = self:History(charKey)
  if #h < 2 then return 0 end
  return h[#h].gold - h[#h - 1].gold
end

-- Forget one character, or everything (the caller confirms first).
function Wallet:Wipe(charKey)
  local w = store()
  if not w then return end
  if charKey then w.chars[charKey] = nil; w.days[charKey] = nil else w.chars, w.days = {}, {} end
  PUI.Kernel:Fire("WALLET_MONEY")
end

local f = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
f:SetScript("OnEvent", function(_, event) PUI.Kernel:Fire(event == "PLAYER_MONEY" and "WALLET_MONEY" or "WALLET_CURRENCY") end)
PUI.Kernel:On("LOGIN", function() Wallet.start = Wallet:Gold() end)
