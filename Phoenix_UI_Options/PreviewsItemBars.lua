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
  if cat == "brez" or cat == "teleport" then return C_Spell.GetSpellTexture(D.SAMPLE[cat]) end
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

-- Party cooldowns: two sample party frames with icons on the chosen side,
-- or the standalone list, at the chosen size and spacing.
function Previews.PartyCD(card)
  local bag = PX.Bag(card)
  local size, gap = get("pcd.size", 22), get("pcd.spacing", 2)
  local side, attach, offset = get("pcd.side", "RIGHT"), get("pcd.attach", "frames"), get("pcd.offset", 2)
  local samples = PUI.IS_RETAIL and { { "Shaman", { 57994, 108271, 98008, 2825 } }, { "Druid", { 106839, 22812, 740, 20484 } } }
    or { { "Rogue", { 1766, 5277, 13750 } }, { "Druid", { 20484, 740, 29166 } } }
  local cats = PUI.PartyCooldownData.spells
  for i, smp in ipairs(samples) do
    local fk = "pcd.frame" .. i
    local f = bag[fk]
    if not f then
      f = CreateFrame("Frame", nil, card)
      f.bg = f:CreateTexture(nil, "BACKGROUND")
      f.bg:SetAllPoints()
      f.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
      f.label = f:CreateFontString(nil, "OVERLAY")
      f.label:SetFontObject(PUI.Media:FontObject("small"))
      f.label:SetPoint("CENTER")
      bag[fk] = f
    end
    f:SetSize(120, 36)
    f:ClearAllPoints()
    f:SetPoint("TOP", card, "TOP", -60, -70 - (i - 1) * 90)
    f.label:SetText(smp[1])
    f:SetShown(attach == "frames")
    local n = 0
    for j, id in ipairs(smp[2]) do
      local k = "pcd.icon" .. i .. "." .. j
      local b = bag[k]
      if not b then
        b = CreateFrame("Frame", nil, card)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        bag[k] = b
      end
      local info = cats[id]
      if info and get("pcd.cat." .. info.cat, true) and n < get("pcd.max", 8) then
        n = n + 1
        b:SetSize(size, size)
        b.tex:SetTexture(C_Spell.GetSpellTexture(id))
        b.tex:SetDesaturated(j == 2)
        b:ClearAllPoints()
        local step = (n - 1) * (size + gap)
        if attach ~= "frames" then b:SetPoint("TOPLEFT", card, "TOP", -40 + step, -70 - (i - 1) * (size + gap + 6))
        elseif side == "LEFT" then b:SetPoint("RIGHT", f, "LEFT", -offset - step, 0)
        elseif side == "TOP" then b:SetPoint("BOTTOMLEFT", f, "TOPLEFT", step, offset)
        elseif side == "BOTTOM" then b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", step, -offset)
        else b:SetPoint("LEFT", f, "RIGHT", offset + step, 0) end
        b:Show()
      else
        b:Hide()
      end
    end
  end
end
local basePreviewUpdate = Previews.Update
function Previews.Update(owner, card, key)
  if owner == "PartyCD" then
    for _, w in pairs(PX.Bag(card)) do w:Hide() end
    return Previews.PartyCD(card)
  end
  return basePreviewUpdate(owner, card, key)
end

-- Loot rolls: sample rows drawn at the chosen width and height.
function Previews.LootRoll(card)
  local bag = PX.Bag(card)
  local w, h = math.min(380, get("loot.width", 300)), get("loot.height", 24)
  local samples = { { "Sample Helm", 4, "639", "NGTP" }, { "Sample Trinket", 3, "626", "NGP" }, { "Sample Cloak", 2, "", "GP" } }
  for i, smp in ipairs(samples) do
    local k = "loot.row" .. i
    local r = bag[k]
    if not r then
      r = CreateFrame("Frame", nil, card)
      r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
      r.fill = r:CreateTexture(nil, "ARTWORK")
      r.text = r:CreateFontString(nil, "OVERLAY"); r.text:SetFontObject(PUI.Media:FontObject("small"))
      r.btns = r:CreateFontString(nil, "OVERLAY"); r.btns:SetFontObject(PUI.Media:FontObject("small"))
      bag[k] = r
    end
    r:SetSize(w, h)
    r:ClearAllPoints()
    r:SetPoint("TOP", card, "TOP", 0, -60 - (i - 1) * (h + 3))
    r.bg:SetColorTexture(0.1, 0.1, 0.12, 1)
    local cr, cg, cb = C_Item.GetItemQualityColor(smp[2])
    r.fill:SetColorTexture(cr, cg, cb, 0.55)
    r.fill:ClearAllPoints(); r.fill:SetPoint("TOPLEFT"); r.fill:SetPoint("BOTTOMLEFT"); r.fill:SetWidth(w * (1 - i * 0.25))
    r.text:ClearAllPoints(); r.text:SetPoint("LEFT", 6, 0); r.text:SetText(smp[3] .. "  " .. smp[1])
    r.btns:ClearAllPoints(); r.btns:SetPoint("RIGHT", -6, 0); r.btns:SetText(smp[4]:gsub(".", "%0 "))
    r:Show()
  end
end
local baseUpdateLoot = Previews.Update
function Previews.Update(owner, card, key)
  if owner == "LootRoll" then
    for _, w in pairs(PX.Bag(card)) do w:Hide() end
    return Previews.LootRoll(card)
  end
  return baseUpdateLoot(owner, card, key)
end
