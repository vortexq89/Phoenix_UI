local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Data Bars (PUI_V2 5.9): two user bars, each a comma-separated list of blocks
-- laid out by an equal-width solver. Blocks refresh on one 1 s Ticker entry
-- that exists only while the module is on and a bar has blocks. Off by default.
local _, ns = ...
local Schema, Layout, Ticker, Theme, Media = PUI.Schema, PUI.Layout, PUI.Ticker, PUI.Theme, PUI.Media
local OWNER = "DataBars"

local DB = { active = false, bars = {} }
ns.DataBars = DB
PUI.DataBars = DB

local function pct(a, b) if not b or b <= 0 then return 0 end return math.floor(a / b * 100 + 0.5) end

local BLOCKS = {
  clock = function() return date("%H:%M") end,
  fps = function() return string.format("%d fps", math.floor(GetFramerate())) end,
  latency = function() local _, _, home, world = GetNetStats(); return string.format("%d / %d ms", home, world) end,
  location = function() return GetMinimapZoneText() end,
  coords = function() return PUI.Minimap and PUI.Minimap.Coords() or "" end,
  gold = function() return string.format("%dg", math.floor(GetMoney() / 10000)) end,
  bags = function()
    local free = 0
    for bag = 0, 4 do free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return string.format("Bags %d", free)
  end,
  durability = function()
    local low
    for slot = 1, 18 do
      local cur, max = GetInventoryItemDurability(slot)
      if cur and max and max > 0 then local p = pct(cur, max); if not low or p < low then low = p end end
    end
    return string.format("Dur %d%%", low or 100)
  end,
  ilvl = function() local _, equipped = GetAverageItemLevel(); return string.format("ilvl %.1f", equipped or 0) end,
  xp = function()
    local max = UnitXPMax("player")
    if PUI.Secret.IsSecret(max) or not max or max <= 0 then return "" end
    return string.format("XP %d%%", pct(UnitXP("player"), max))
  end,
  spec = function()
    local spec = C_SpecializationInfo.GetSpecialization()
    local name = spec and select(2, C_SpecializationInfo.GetSpecializationInfo(spec))
    return name or ""
  end,
}
DB.BLOCKS = BLOCKS
local BLOCK_NAMES = {}
for k in pairs(BLOCKS) do BLOCK_NAMES[#BLOCK_NAMES + 1] = k end
table.sort(BLOCK_NAMES)
DB.BLOCK_NAMES = BLOCK_NAMES

local cfg = {
  { blocks = "clock,fps,latency,durability,gold", width = 480, height = 20, pos = { "BOTTOM", 0, 2 } },
  { blocks = "", width = 480, height = 20, pos = { "TOP", 0, -2 } },
}
DB.cfg = cfg

function DB.Parse(text)
  local list = {}
  for name in (text or ""):gmatch("[^,%s]+") do if BLOCKS[name] then list[#list + 1] = name end end
  return list
end

local function bar(i)
  local b = DB.bars[i]
  if b then return b end
  b = PUI:CreateFrame("Frame", "PhoenixUI_DataBar" .. i, UIParent, nil, OWNER)
  Theme:Backdrop(b, "surface.1")
  b.cells = {}
  DB.bars[i] = b
  return b
end

-- Equal-width solver: n blocks share the bar width.
function DB.Solve(width, n)
  if n <= 0 then return {} end
  local w = width / n
  local out = {}
  for i = 1, n do out[i] = { x = (i - 1) * w, w = w } end
  return out
end

function DB.Update()
  for i, b in pairs(DB.bars) do
    for j, cell in ipairs(b.cells) do
      local name = b.list[j]
      if name then cell:SetText(BLOCKS[name]()) end
    end
  end
end

function DB.Layout(i)
  local c = cfg[i]
  local list = DB.Parse(c.blocks)
  if not DB.active or #list == 0 then
    local old = DB.bars[i]
    if old then old.list = {}; old:Hide() end
    return
  end
  local b = bar(i)
  b.list = list
  b:SetSize(c.width, c.height)
  Layout:Place(b, "db.bar" .. i)
  local slots = DB.Solve(c.width, #list)
  for j, slot in ipairs(slots) do
    local cell = b.cells[j]
    if not cell then
      cell = b:CreateFontString(nil, "OVERLAY")
      cell:SetFontObject(Media:FontObject("number"))
      cell:SetJustifyH("CENTER")
      b.cells[j] = cell
    end
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", b, "LEFT", slot.x, 0)
    cell:SetWidth(slot.w)
    cell:Show()
  end
  for j = #slots + 1, #b.cells do b.cells[j]:Hide() end
  b:Show()
end

function DB.Refresh()
  local any = false
  for i = 1, #cfg do
    DB.Layout(i)
    if DB.bars[i] and #DB.bars[i].list > 0 and DB.bars[i]:IsShown() then any = true end
  end
  if any and not Ticker:IsRegistered("db.update") then Ticker:Register("db.update", 1, DB.Update, OWNER)
  elseif not any and Ticker:IsRegistered("db.update") then Ticker:Unregister("db.update") end
  if any then DB.Update() end
end

local schema = {}
DB.schema = schema
for i, c in ipairs(cfg) do
  local function key(name, def)
    def.owner = OWNER
    def.apply = function(value) c[name] = value; DB.Refresh() end
    schema["db.bar" .. i .. "." .. name] = def
  end
  key("blocks", { type = "text", default = c.blocks, label = "Data bar " .. i .. " blocks",
    tooltip = "Comma-separated blocks in order; empty hides the bar. Blocks: " .. table.concat(BLOCK_NAMES, ", ") .. ".", mode = "simple" })
  key("width", { type = "range", default = c.width, min = 100, max = 1920, step = 1, label = "Data bar " .. i .. " width",
    tooltip = "Width of the bar; blocks share it equally.", mode = "advanced" })
  key("height", { type = "range", default = c.height, min = 12, max = 40, step = 1, label = "Data bar " .. i .. " height",
    tooltip = "Height of the bar.", mode = "advanced" })
  Layout:RegisterElement("db.bar" .. i, { label = "Data bar " .. i, owner = OWNER, size = { c.width, c.height },
    default = { point = c.pos[1], x = c.pos[2], y = c.pos[3] } })
end

DB.module = PUI:RegisterModule(OWNER, {
  label = "Data bars", tooltip = "Information bars: clock, FPS, latency, gold, durability and more.", enabledByDefault = false,
  schema = schema,
  onEnable = function() DB.active = true; DB.Refresh() end,
  onDisable = function() DB.active = false; DB.Refresh() end,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
