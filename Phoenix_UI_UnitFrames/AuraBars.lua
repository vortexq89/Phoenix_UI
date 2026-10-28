local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Player Aura Bars (plan 5.1, 15.3, mockup 01): Phoenix's replacement for
-- Blizzard's BuffFrame and DebuffFrame, drawn by the one aura engine
-- (PUI.Auras). Two movable rows (Studio elements uf.auraBars.buffs/debuffs)
-- with size, icons per row, growth, count, sort and a plain-choice filter.
-- Blizzard's frames are parked through the FrameLedger only while Phoenix
-- draws the rows. Dedupe (plan 1.O "Buff bars"): optionally leave auras the
-- Cooldown Manager's tracked buff bars already show to those bars.
local _, ns = ...
local Schema, Layout, Auras, CQ = PUI.Schema, PUI.Layout, PUI.Auras, PUI.CombatQueue
local OWNER = "UnitFrames"

local AB = { handles = {}, frames = {} }
ns.AuraBars = AB
local cfg = {
  source = "phoenix", dedupeCDM = false,
  buffs = { size = 30, perRow = 12, max = 32, growX = "LEFT", growY = "DOWN", sort = "expiration", reverse = false, filter = "all", spacing = 4 },
  debuffs = { size = 36, perRow = 8, max = 16, growX = "LEFT", growY = "DOWN", sort = "expiration", reverse = false, filter = "all", spacing = 4 },
}
AB.cfg = cfg
local DEFAULT_POS = { buffs = { "TOPRIGHT", -220, -12 }, debuffs = { "TOPRIGHT", -220, -150 } }

local function frame(kind)
  local f = AB.frames[kind]
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_AuraBar_" .. kind, UIParent, nil, OWNER)
  AB.frames[kind] = f
  return f
end

-- CDM tracked buff bars, when that module offers its list (never guessed).
function AB.CDMSpells()
  local cdm = PUI.CooldownManager
  if cdm and type(cdm.TrackedBuffSpellIDs) == "function" then return cdm.TrackedBuffSpellIDs() or {} end
  return {}
end

local function layoutOf(k)
  local anchor = (k.growY == "UP" and "BOTTOM" or "TOP") .. (k.growX == "LEFT" and "RIGHT" or "LEFT")
  return { anchor = anchor, growX = k.growX, growY = k.growY, padding = k.spacing, lineSize = k.perRow, size = k.size }
end

function AB.Apply()
  local UF = ns.UF
  local on = UF and UF.active and cfg.source == "phoenix"
  for _, kind in ipairs({ "buffs", "debuffs" }) do
    local k = cfg[kind]
    local h = AB.handles[kind]
    if on then
      local f = frame(kind)
      local rows = math.max(1, math.ceil(k.max / math.max(1, k.perRow)))
      local w = k.perRow * (k.size + k.spacing) - k.spacing
      local ht = rows * (k.size + k.spacing) - k.spacing
      f:SetSize(w, ht)
      Layout:Place(f, "uf.auraBars." .. kind)
      local el = Layout:Element("uf.auraBars." .. kind)
      if el then el.size = { w, ht } end
      f:Show()
      local layout = layoutOf(k)
      if not h then
        h = Auras:Create(OWNER, f, "player", layout)
        AB.handles[kind] = h
      else
        h:SetLayout(layout)
      end
      if h.container then h.container:ClearAllPoints(); h.container:SetPoint(layout.anchor, f, layout.anchor); h.container:Show() end
      h:Configure({ { key = kind, filter = ns.UFAuras.FilterFor(kind, k.filter), max = k.max, sort = k.sort, reverse = k.reverse, size = k.size } })
      if kind == "buffs" then h:SetExclusions(cfg.dedupeCDM and AB.CDMSpells() or {}) end
      ns.Blizzard.Park(kind)
    else
      if h then
        h:Configure({ { key = kind, filter = ns.UFAuras.FilterFor(kind, k.filter), enabled = false } })
        if h.container then h.container:Hide() end
      end
      if AB.frames[kind] then AB.frames[kind]:Hide() end
      ns.Blizzard.Restore(kind)
    end
  end
end

-- Schema --------------------------------------------------------------------------
local schema = {}
AB.schema = schema
local function key(name, def, set)
  def.owner = OWNER
  def.apply = function(v) set(v); AB.Apply() end
  schema[name] = def
end

key("uf.auraBars.source", { type = "select", default = "phoenix", choices = { "phoenix", "blizzard" },
  choiceLabels = { phoenix = "Phoenix", blizzard = "Blizzard" }, label = "Player aura bars",
  tooltip = "Phoenix draws your buffs and debuffs in two movable rows, or Blizzard's default buff frame stays.",
  mode = "simple", searchTags = { "buffs", "debuffs", "buff frame", "auras" } }, function(v) cfg.source = v end)
key("uf.auraBars.dedupeCDM", { type = "toggle", default = false, label = "Leave Cooldown Manager buffs to its bars",
  tooltip = "Hides a buff here when the Cooldown Manager's tracked buff bars already show it, so nothing appears twice.",
  mode = "advanced", searchTags = { "duplicate", "dedupe", "cdm" } }, function(v) cfg.dedupeCDM = v end)

local LABEL = { buffs = "Buffs", debuffs = "Debuffs" }
for _, kind in ipairs({ "buffs", "debuffs" }) do
  local k, L = cfg[kind], LABEL[kind]
  local p = "uf.auraBars." .. kind .. "."
  key(p .. "size", { type = "range", default = k.size, min = 16, max = 64, step = 1, label = L .. " icon size",
    tooltip = "Size of each " .. L:lower() .. " icon in pixels.", mode = "simple", overridable = true }, function(v) k.size = v end)
  key(p .. "perRow", { type = "range", default = k.perRow, min = 1, max = 40, step = 1, label = L .. " per row",
    tooltip = "How many icons fit on one row before a new row starts.", mode = "advanced", overridable = true }, function(v) k.perRow = v end)
  key(p .. "max", { type = "range", default = k.max, min = 1, max = 40, step = 1, label = L .. " shown at most",
    tooltip = "Largest number of " .. L:lower() .. " shown.", mode = "advanced", overridable = true }, function(v) k.max = v end)
  key(p .. "spacing", { type = "range", default = k.spacing, min = 0, max = 16, step = 1, label = L .. " spacing",
    tooltip = "Gap between icons.", mode = "advanced" }, function(v) k.spacing = v end)
  key(p .. "growX", { type = "select", default = k.growX, choices = { "LEFT", "RIGHT" }, choiceLabels = { LEFT = "Leftwards", RIGHT = "Rightwards" },
    label = L .. " grow", tooltip = "Which way new icons are added on a row.", mode = "advanced" }, function(v) k.growX = v end)
  key(p .. "growY", { type = "select", default = k.growY, choices = { "DOWN", "UP" }, choiceLabels = { DOWN = "Downwards", UP = "Upwards" },
    label = L .. " new rows", tooltip = "Which way extra rows are added.", mode = "advanced" }, function(v) k.growY = v end)
  key(p .. "sort", { type = "select", default = k.sort, choices = Auras.SORTS,
    choiceLabels = { default = "Blizzard order", expiration = "Time left", name = "Name", bigDefensive = "Defensives first",
      unitFrameDebuff = "Debuff priority", important = "Important first" },
    label = L .. " order", tooltip = "How icons are ordered.", mode = "advanced" }, function(v) k.sort = v end)
  key(p .. "reverse", { type = "toggle", default = false, label = L .. " reverse order",
    tooltip = "Reverses the chosen order.", mode = "advanced" }, function(v) k.reverse = v end)
  key(p .. "filter", { type = "select", default = "all", choices = ns.UFAuras.FILTERS[kind], choiceLabels = ns.UFAuras.FILTER_LABELS,
    label = L .. " shown", tooltip = "Which " .. L:lower() .. " are shown.", mode = "advanced", overridable = true }, function(v) k.filter = v end)
  Layout:RegisterElement("uf.auraBars." .. kind, { label = "Player " .. L:lower(), owner = OWNER, size = { 300, 40 },
    default = { point = DEFAULT_POS[kind][1], x = DEFAULT_POS[kind][2], y = DEFAULT_POS[kind][3] } })
end

function AB.Off()
  local UF = ns.UF
  for kind, h in pairs(AB.handles) do
    h:Configure({ { key = kind, filter = ns.UFAuras.FilterFor(kind, cfg[kind].filter), enabled = false } })
    if h.container then h.container:Hide() end
    if AB.frames[kind] then AB.frames[kind]:Hide() end
  end
  if not (UF and UF.active) then
    ns.Blizzard.Restore("buffs")
    ns.Blizzard.Restore("debuffs")
  end
end
