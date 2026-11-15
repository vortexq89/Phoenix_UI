local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Loot rolls: a compact, movable list of group loot rolls that replaces the
-- game's roll frames. Phoenix's own design. One row per roll: icon, item
-- level, name in quality colour, a draining timer bar and Need / Greed /
-- Transmog / Pass buttons (only the choices the game allows). RollOnLoot is
-- an open API, so the buttons are plain buttons (no secure template needed,
-- nothing protected touched). The game's roll container is parked under a
-- hidden frame while this is on (option to keep it). The timer drains on one
-- Ticker entry that exists only while a roll is open.
local Schema, Layout = PUI.Schema, PUI.Layout
local OWNER = "LootRoll"

local LR = { active = false, rolls = {}, rows = {}, order = {} }
PUI.LootRoll = LR
local s = { keepBlizzard = false, width = 300, height = 24, growUp = false }
LR.settings = s
LR.CHOICES = { { id = "need", type = 1, label = "N", tip = "Need", flag = 6 }, { id = "greed", type = 2, label = "G", tip = "Greed", flag = 7 },
  { id = "transmog", type = 4, label = "T", tip = "Transmog", flag = 14 }, { id = "pass", type = 0, label = "P", tip = "Pass" } }

-- Plain data for one roll from the game (nil when the roll is gone).
function LR.Read(rollID)
  if not GetLootRollItemInfo then return nil end
  local texture, name, count, quality, _, canNeed, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)
  if not texture then return nil end
  local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
  local ilvl = link and C_Item.GetDetailedItemLevelInfo(link)
  return { id = rollID, texture = texture, name = name, count = count, quality = quality or 1, link = link, ilvl = ilvl,
    can = { need = canNeed == true, greed = canGreed == true, transmog = canTransmog == true, pass = true } }
end

local function anchor()
  local a = LR.anchor
  if not a then
    a = PUI:CreateFrame("Frame", "PhoenixUI_LootRolls", UIParent, nil, OWNER)
    LR.anchor = a
  end
  a:SetSize(s.width, s.height)
  Layout:Place(a, "loot.rolls")
  return a
end

local function row(i)
  local r = LR.rows[i]
  if r then return r end
  r = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
  r.bg = PUI.Theme:Backdrop(r, "surface.1")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.bar = PUI:CreateFrame("StatusBar", nil, r, nil, OWNER)
  r.bar:SetStatusBarTexture(PUI.Bars:TexturePath())
  r.bar:SetMinMaxValues(0, 1)
  r.name = r.bar:CreateFontString(nil, "OVERLAY")
  r.name:SetFontObject(PUI.Media:FontObject("small"))
  r.name:SetPoint("LEFT", 4, 0)
  r.name:SetJustifyH("LEFT")
  r.ilvl = r:CreateFontString(nil, "OVERLAY")
  r.ilvl:SetFontObject(PUI.Media:FontObject("number"))
  r.btn = {}
  for k, c in ipairs(LR.CHOICES) do
    local b = PUI:CreateFrame("Button", nil, r, nil, OWNER)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFontObject(PUI.Media:FontObject("small"))
    b.text:SetPoint("CENTER")
    b.text:SetText(c.label)
    b.bg = PUI.Theme:Backdrop(b, "surface.2")
    b.choice = c
    b:SetScript("OnClick", function() LR.Choose(r.rollID, c.type) end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(c.tip); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.btn[k] = b
  end
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  LR.rows[i] = r
  return r
end

function LR.Choose(rollID, rollType)
  if rollID and RollOnLoot then RollOnLoot(rollID, rollType) end
end

-- Lays out every open roll.
function LR.Draw()
  local a = anchor()
  local h, w = s.height, s.width
  for i, id in ipairs(LR.order) do
    local d, r = LR.rolls[id], row(i)
    r.rollID, r.link = id, d.link
    r:SetSize(w, h)
    r:ClearAllPoints()
    r:SetPoint(s.growUp and "BOTTOM" or "TOP", a, s.growUp and "BOTTOM" or "TOP", 0, (s.growUp and 1 or -1) * (i - 1) * (h + 3))
    r.icon:SetSize(h, h)
    r.icon:ClearAllPoints()
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.icon:SetTexture(d.texture)
    r.ilvl:ClearAllPoints()
    r.ilvl:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", -1, 1)
    r.ilvl:SetText(d.ilvl and tostring(d.ilvl) or "")
    local x = w
    for k = #r.btn, 1, -1 do
      local b = r.btn[k]
      local allowed = d.can[b.choice.id]
      b:SetSize(h, h)
      b:ClearAllPoints()
      if allowed then x = x - h; b:SetPoint("LEFT", r, "LEFT", x, 0); x = x - 2 end
      b:SetShown(allowed)
    end
    r.bar:ClearAllPoints()
    r.bar:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 3, 0)
    r.bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT", x, 0)
    local cr, cg, cb = C_Item.GetItemQualityColor(d.quality)
    r.bar:SetStatusBarColor(cr, cg, cb, 0.55)
    r.name:SetText((d.count and d.count > 1) and (d.name .. " x" .. d.count) or d.name)
    r:Show()
  end
  for i = #LR.order + 1, #LR.rows do LR.rows[i]:Hide(); LR.rows[i].rollID = nil end
  LR.Tick()
  LR.Arm()
end

-- Timer fill (plain numbers from the game's roll clock).
function LR.Tick()
  for i, id in ipairs(LR.order) do
    local d = LR.rolls[id]
    local left = d.test and math.max(0, d.endsAt - GetTime()) * 1000 or (GetLootRollTimeLeft and GetLootRollTimeLeft(id) or 0)
    LR.rows[i].bar:SetValue(d.total > 0 and math.min(1, left / d.total) or 0)
  end
end

function LR.Arm()
  local want = LR.active and #LR.order > 0
  local on = PUI.Ticker:IsRegistered("loot.timer")
  if want and not on then PUI.Ticker:Register("loot.timer", 0.1, LR.Tick, OWNER)
  elseif not want and on then PUI.Ticker:Unregister("loot.timer") end
end

function LR.Start(rollID, rollTime)
  local d = LR.Read(rollID)
  if not d then return end
  d.total = rollTime or 60000
  if not LR.rolls[rollID] then LR.order[#LR.order + 1] = rollID end
  LR.rolls[rollID] = d
  LR.Draw()
end

function LR.Cancel(rollID)
  if not LR.rolls[rollID] then return end
  LR.rolls[rollID] = nil
  for i, id in ipairs(LR.order) do if id == rollID then table.remove(LR.order, i) break end end
  LR.Draw()
end

-- Sample rolls for /pui loottest and the preview (no game rolls touched).
function LR.Test()
  local now = GetTime()
  local samples = { { "Sample Helm", 4, 639, 133071 }, { "Sample Trinket", 3, 626, 133434 }, { "Sample Cloak", 2, nil, 133762 } }
  for i, smp in ipairs(samples) do
    local id = -i
    if not LR.rolls[id] then LR.order[#LR.order + 1] = id end
    LR.rolls[id] = { id = id, test = true, texture = smp[4], name = smp[1], quality = smp[2], ilvl = smp[3], count = 1,
      can = { need = i ~= 3, greed = true, transmog = i == 1, pass = true }, total = 60000, endsAt = now + 60 - i * 10 }
  end
  LR.Draw()
end
function LR.ClearTest()
  for i = #LR.order, 1, -1 do local id = LR.order[i]; if LR.rolls[id].test then LR.Cancel(id) end end
end

-- The game's roll frames: parked while Phoenix rolls are on (unless kept).
function LR.ApplyBlizzard()
  local c = rawget(_G, "GroupLootContainer")
  if not c then return end
  local want = LR.active and not s.keepBlizzard
  if want and not LR.parked then
    LR.hider = LR.hider or PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
    LR.hider:Hide()
    LR.parked = c:GetParent() or UIParent
    c:SetParent(LR.hider)
  elseif not want and LR.parked then
    c:SetParent(LR.parked)
    LR.parked = nil
  end
end

local function onEnable(mod)
  LR.active = true
  mod:RegisterEvent("START_LOOT_ROLL", function(_, _, id, t) LR.Start(id, t) end)
  mod:RegisterEvent("CANCEL_LOOT_ROLL", function(_, _, id) LR.Cancel(id) end)
  mod:RegisterEvent("CANCEL_ALL_LOOT_ROLLS", function() wipe(LR.rolls); wipe(LR.order); LR.Draw() end)
  LR.ApplyBlizzard()
  LR.Draw()
end
local function onDisable()
  LR.active = false
  wipe(LR.rolls); wipe(LR.order)
  LR.Draw()
  LR.ApplyBlizzard()
end

local schema = {}
LR.schema = schema
local function key(name, def, set)
  def.owner = OWNER
  def.apply = function(v) set(v); if name == "keepBlizzard" then LR.ApplyBlizzard() end; if LR.active then LR.Draw() end end
  schema["loot." .. name] = def
end
key("keepBlizzard", { type = "toggle", default = false, label = "Keep Blizzard's roll frames",
  tooltip = "Show the game's own loot roll frames as well (Phoenix rolls stay).", mode = "simple" }, function(v) s.keepBlizzard = v end)
key("width", { type = "range", default = 300, min = 180, max = 500, step = 10, label = "Roll width",
  tooltip = "Width of each loot roll row.", mode = "simple" }, function(v) s.width = v end)
key("height", { type = "range", default = 24, min = 16, max = 40, step = 1, label = "Roll height",
  tooltip = "Height of each loot roll row (the icon and buttons follow).", mode = "simple" }, function(v) s.height = v end)
key("growUp", { type = "toggle", default = false, label = "New rolls grow upwards",
  tooltip = "Stack rolls upwards from the anchor instead of downwards.", mode = "advanced" }, function(v) s.growUp = v end)
Layout:RegisterElement("loot.rolls", { label = "Loot rolls", owner = OWNER, size = { 300, 80 },
  default = { point = "TOP", x = 0, y = -220 } })

LR.module = PUI:RegisterModule(OWNER, {
  label = "Loot rolls",
  tooltip = "A compact, movable list of group loot rolls with item level, a timer bar and Need / Greed / Transmog / Pass buttons, in place of the game's roll frames.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
PUI.Slash:Register("loottest", function()
  if not LR.active then PUI.Slash.Print("turn on Loot rolls first") return end
  if LR.rolls[-1] then LR.ClearTest() else LR.Test() end
end, "show or hide three sample loot rolls")
