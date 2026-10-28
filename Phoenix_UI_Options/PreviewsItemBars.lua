local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live preview for the auto item bars (Action Bars > Auto bar tabs): sample
-- buttons painted by the Action Bars button painter, one per ticked category,
-- with the bar's size, spacing, per-row, grow direction, counts, cooldowns
-- and fade. Display only: no bag reads, no protected frames.
local Options = PUI.Options
local PX = Options.PreviewsExtras
local Previews = Options.Previews
local Schema = PUI.Schema
local D = PUI.ItemBarData
local SAMPLE_COUNT = { flask = "3", food = "20", combat = "5", healing = "2", rune = "8", oil = "4", quest = "1", custom = "1", brez = "1" }

local function get(key, fallback)
  local d = Schema:Def(key)
  if not d then return fallback end
  local v = Schema:Get(key)
  if v == nil then return fallback end
  return v
end

local function sampleIcon(cat)
  if cat == "brez" then return C_Spell.GetSpellTexture(D.SAMPLE.brez) end
  return C_Item.GetItemIconByID(D.SAMPLE[cat])
end

-- Draws bar i's sample at y; returns the height used.
local function drawBar(card, i, y, compact)
  local AB = PUI.ActionBars
  local Btn = AB and AB.Buttons
  local IB = AB and AB.ItemBars
  if not (Btn and IB) then return 0 end
  local bag = PX.Bag(card)
  local p = "ab.ibar" .. i .. "."
  local grid = get("ab.ibars.categories", IB.DEFAULT_GRID())
  local cats = {}
  for _, c in ipairs(IB.Categories()) do
    if grid[c.id] and grid[c.id]["bar" .. i] then cats[#cats + 1] = c.id end
  end
  local size = math.min(compact and 28 or 44, get(p .. "size", 32))
  local gap, perRow, grow = get(p .. "spacing", 2), get(p .. "perRow", 12), get(p .. "grow", "RIGHT")
  local on = get(p .. "enabled", false)
  local n = #cats
  perRow = math.max(1, math.min(perRow, math.max(n, 1)))
  local lines = math.max(1, math.ceil(n / perRow))
  local w, h = perRow * size + (perRow - 1) * gap, lines * size + (lines - 1) * gap
  if grow == "UP" or grow == "DOWN" then w, h = h, w end
  local holderKey = "ib.holder" .. i
  local holder = bag[holderKey]
  if not holder then holder = CreateFrame("Frame", nil, card); bag[holderKey] = holder end
  holder:ClearAllPoints()
  holder:SetSize(math.max(w, 1), math.max(h, 1))
  holder:SetPoint("TOP", card, "TOP", 0, y - 18)
  holder:SetAlpha(not on and 0.35 or (get(p .. "mouseover", false) and get(p .. "fadeAlpha", 0.3)) or 1)
  holder:Show()
  local title = PX.Line(card, "ib.title" .. i)
  title:ClearAllPoints()
  title:SetPoint("TOP", card, "TOP", 0, y)
  title:SetText(("Auto item bar %d"):format(i) .. (on and "" or " (off)") .. (n == 0 and " - nothing ticked" or ""))
  for j = 1, math.max(n, 12) do
    local k = "ib.b" .. i .. "." .. j
    local b = bag[k]
    if j <= n then
      if not b then b = CreateFrame("Frame", nil, holder); Btn.Skin(b); bag[k] = b end
      b:SetParent(holder)
      b:SetSize(size, size)
      b:ClearAllPoints()
      local point, x, yy = IB.Offset(j, perRow, size, gap, grow)
      b:SetPoint(point, holder, point, x, yy)
      Btn.ApplyLook(b)
      b.icon:SetTexture(sampleIcon(cats[j]))
      b.count:SetText(get(p .. "count", true) and (SAMPLE_COUNT[cats[j]] or "") or "")
      b.hotkey:SetText("")
      b.dim:SetAlpha((j == 2 and get(p .. "cooldown", true)) and 0.5 or 0)
      b:Show()
    elseif b then
      b:Hide()
    end
  end
  return h + 30
end

function Previews.AutoItemBarSample(card, tab)
  local i = tonumber((tab or ""):match("^ibar(%d)$"))
  if i then drawBar(card, i, -56, false) return end
  local y = -56
  for k = 1, 3 do y = y - drawBar(card, k, y, true) - 8 end
end
