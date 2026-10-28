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

local f = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
f:SetScript("OnEvent", function(_, event) PUI.Kernel:Fire(event == "PLAYER_MONEY" and "WALLET_MONEY" or "WALLET_CURRENCY") end)
PUI.Kernel:On("LOGIN", function() Wallet.start = Wallet:Gold() end)
