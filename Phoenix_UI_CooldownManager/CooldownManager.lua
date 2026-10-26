local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cooldown Manager (PUI_V2 5.7): Phoenix never draws a cooldown icon itself.
-- The game's Cooldown Viewer item frames (Essential, Utility, Buff Icons, Buff
-- Bars) are re-anchored into Phoenix rows after Blizzard's own layout pass
-- (post-hooks on each viewer's Layout and RefreshLayout). Only positions and
-- sizes change; the frames keep their engine-fed cooldown and aura data, so
-- secret values never pass through Phoenix. A viewer Phoenix does not claim is
-- left to Blizzard. Presets (Minimal / Standard / Everything) and a
-- CDM-only share string (!PUI_CDM) cover Simple mode. Off by default.
local _, ns = ...
local Schema, Layout, Slash = PUI.Schema, PUI.Layout, PUI.Slash
local OWNER = "CooldownManager"

local CDM = { active = false, hooked = {}, anchors = {} }
ns.CDM = CDM
PUI.CooldownManager = CDM

local VIEWERS = {
  essential = { global = "EssentialCooldownViewer", label = "Essential cooldowns", size = 40, perRow = 8, pos = { "CENTER", 0, -120 } },
  utility = { global = "UtilityCooldownViewer", label = "Utility cooldowns", size = 32, perRow = 8, pos = { "CENTER", 0, -170 } },
  buffIcon = { global = "BuffIconCooldownViewer", label = "Buff icons", size = 32, perRow = 8, pos = { "CENTER", 0, -60 } },
  buffBar = { global = "BuffBarCooldownViewer", label = "Buff bars", size = 200, perRow = 1, pos = { "CENTER", 260, -60 }, bars = true },
}
local ORDER = { "essential", "utility", "buffIcon", "buffBar" }
CDM.VIEWERS, CDM.ORDER = VIEWERS, ORDER
local PRESETS = {
  minimal = { essential = true, utility = false, buffIcon = false, buffBar = false },
  standard = { essential = true, utility = true, buffIcon = true, buffBar = false },
  everything = { essential = true, utility = true, buffIcon = true, buffBar = true },
}
CDM.PRESETS = PRESETS
local BAR_HEIGHT = 20

local cfg = {}
CDM.cfg = cfg
for v, d in pairs(VIEWERS) do cfg[v] = { enabled = true, size = d.size, perRow = d.perRow, spacing = 2, growth = "right" } end

local function anchor(v)
  local a = CDM.anchors[v]
  if not a then
    a = PUI:CreateFrame("Frame", "PhoenixUI_CDM_" .. v, UIParent, nil, OWNER)
    a:SetSize(VIEWERS[v].size, VIEWERS[v].bars and BAR_HEIGHT or VIEWERS[v].size)
    CDM.anchors[v] = a
  end
  return a
end

-- Item frames of a viewer in Blizzard's order (layoutIndex is a plain number).
function CDM.Items(viewer)
  local items = viewer:GetItemFrames()
  if type(items) ~= "table" then return {} end
  local list = {}
  for _, f in ipairs(items) do list[#list + 1] = f end
  table.sort(list, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
  return list
end

-- Grid position of item i (1-based) for a viewer config.
function CDM.Offset(c, i, bars)
  local w = c.size
  local h = bars and BAR_HEIGHT or c.size
  local col, row = (i - 1) % c.perRow, math.floor((i - 1) / c.perRow)
  local x = col * (w + c.spacing)
  if c.growth == "left" then x = -x end
  return x, -(row * (h + c.spacing))
end

function CDM.Place(v)
  if not CDM.active or not cfg[v].enabled then return end
  local viewer = _G[VIEWERS[v].global]
  if not viewer then return end
  local c, bars, a = cfg[v], VIEWERS[v].bars, anchor(v)
  local point = c.growth == "left" and "TOPRIGHT" or "TOPLEFT"
  for i, f in ipairs(CDM.Items(viewer)) do
    local x, y = CDM.Offset(c, i, bars)
    f:ClearAllPoints()
    f:SetPoint(point, a, point, x, y)
    f:SetSize(c.size, bars and BAR_HEIGHT or c.size)
  end
  local cols = math.min(c.perRow, math.max(1, #CDM.Items(viewer)))
  a:SetSize(cols * (c.size + c.spacing), bars and BAR_HEIGHT or c.size)
end

local function hook(v)
  if CDM.hooked[v] then return end
  local viewer = _G[VIEWERS[v].global]
  if not viewer then return end
  local after = function() CDM.Place(v) end
  hooksecurefunc(viewer, "RefreshLayout", after)
  if viewer.Layout then hooksecurefunc(viewer, "Layout", after) end
  CDM.hooked[v] = true
end

function CDM.Refresh(v)
  if not CDM.active then return end
  for _, k in ipairs(v and { v } or ORDER) do
    Layout:Place(anchor(k), "cdm." .. k)
    if cfg[k].enabled then hook(k); CDM.Place(k) end
  end
end

-- Share string: "!PUI_CDM" + base64(compressed "key=value" lines of cdm.* keys).
CDM.PREFIX = "!PUI_CDM"
function CDM.Export()
  local lines = {}
  for _, key in ipairs(Schema.keys) do
    if key:find("^cdm%.") then lines[#lines + 1] = key .. "=" .. tostring(Schema:Get(key)) end
  end
  return CDM.PREFIX .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(table.concat(lines, "\n")))
end

-- Returns the number of settings applied, or nil and a reason. Unknown keys and
-- invalid values are skipped; nothing outside cdm.* is ever written.
function CDM.Import(text)
  if type(text) ~= "string" or text:sub(1, #CDM.PREFIX) ~= CDM.PREFIX then return nil, "not a !PUI_CDM string" end
  local raw = C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(text:sub(#CDM.PREFIX + 1)))
  if type(raw) ~= "string" then return nil, "unreadable string" end
  local n = 0
  for line in raw:gmatch("[^\n]+") do
    local key, value = line:match("^(cdm%.[%w%.]+)=(.*)$")
    local def = key and Schema:Def(key)
    if def then
      local v = value
      if def.type == "toggle" then v = value == "true"
      elseif def.type == "range" then v = tonumber(value) end
      if v ~= nil and Schema:Validate(def, v) then Schema:Set(key, v); n = n + 1 end
    end
  end
  return n
end

Slash:Register("cdm", function(rest)
  local cmd, arg = (rest or ""):match("^(%S*)%s*(.*)$")
  if cmd == "export" then
    Slash.Print(CDM.Export())
  elseif cmd == "import" then
    local n, why = CDM.Import(arg)
    Slash.Print(n and ("imported " .. n .. " cooldown manager settings") or ("not imported: " .. why))
  else
    Slash.Print("usage: /pui cdm export | /pui cdm import <!PUI_CDM string>")
  end
end, "export | import <string>: share cooldown manager settings")

-- Lifecycle ---------------------------------------------------------------------
local function onEnable()
  CDM.active = true
  CDM.Refresh()
end

local function onDisable()
  CDM.active = false
  -- Blizzard lays its frames out again on its next pass; ask for one now.
  for _, v in ipairs(ORDER) do
    local viewer = _G[VIEWERS[v].global]
    if viewer and viewer.RefreshLayout then viewer:RefreshLayout() end
  end
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
CDM.schema = schema
local function key(name, def, set, v)
  def.owner = OWNER
  def.apply = function(value) set(value); CDM.Refresh(v) end
  schema["cdm." .. name] = def
end

key("preset", { type = "select", default = "custom", choices = { "custom", "minimal", "standard", "everything" },
  label = "Cooldown manager preset", tooltip = "Minimal: essential cooldowns only. Standard: adds utility cooldowns and buff icons. Everything: adds buff bars. Custom keeps your own choices.",
  mode = "simple" }, function(value)
  local p = PRESETS[value]
  if not p then return end
  for v, on in pairs(p) do if Schema:Get("cdm." .. v .. ".enabled") ~= on then Schema:Set("cdm." .. v .. ".enabled", on) end end
end)
for _, v in ipairs(ORDER) do
  local d = VIEWERS[v]
  key(v .. ".enabled", { type = "toggle", default = true, label = d.label .. ": Phoenix layout",
    tooltip = "Phoenix positions the game's " .. d.label:lower() .. " in its own rows; off leaves them to the game.", mode = "simple" },
    function(value) cfg[v].enabled = value end, v)
  key(v .. ".size", { type = "range", default = d.size, min = d.bars and 80 or 16, max = d.bars and 400 or 80, step = 1,
    label = d.label .. (d.bars and ": width" or ": icon size"), tooltip = "Size of each " .. (d.bars and "bar" or "icon") .. ".", mode = "advanced" },
    function(value) cfg[v].size = value end, v)
  key(v .. ".perRow", { type = "range", default = d.perRow, min = 1, max = 20, step = 1, label = d.label .. ": per row",
    tooltip = "How many fit in one row before wrapping (overflow goes to the next row).", mode = "advanced" },
    function(value) cfg[v].perRow = value end, v)
  key(v .. ".spacing", { type = "range", default = 2, min = 0, max = 20, step = 1, label = d.label .. ": spacing",
    tooltip = "Gap between items.", mode = "advanced" }, function(value) cfg[v].spacing = value end, v)
  key(v .. ".growth", { type = "select", default = "right", choices = { "right", "left" }, label = d.label .. ": growth",
    tooltip = "Rows grow to the right or to the left of the anchor.", mode = "advanced" }, function(value) cfg[v].growth = value end, v)
  Layout:RegisterElement("cdm." .. v, { label = d.label, owner = OWNER, size = { d.size, d.bars and BAR_HEIGHT or d.size },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

CDM.module = PUI:RegisterModule(OWNER, {
  label = "Cooldown manager",
  tooltip = "Lays out the game's Cooldown Viewer icons and bars in Phoenix rows (the game still draws every cooldown).",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
for k, def in pairs(schema) do if k ~= "cdm.preset" then def.apply(Schema:Get(k)) end end
