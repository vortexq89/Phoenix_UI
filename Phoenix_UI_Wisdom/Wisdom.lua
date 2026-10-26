local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Wisdom (PUI_V2 6.4): a gear score from stat weights (the user's own per
-- profile, imported community scales, or a dated pack set) shown in item
-- tooltips with an upgrade star against what is equipped, and as a badge on
-- Vault bag slots. With no weights set it compares item level only and says
-- so. Item stats are not secret; nothing here runs protected code. Off by default.
local _, ns = ...
local Schema = PUI.Schema
local OWNER = "Wisdom"

local WI = { active = false }
ns.WI = WI
PUI.Wisdom = WI
local s = { tooltip = true, star = true, bags = true, decimals = 1 }
WI.settings = s

local function weights() return Schema:Get("wisdom.weights") end
WI.Weights = weights

function WI.HasWeights()
  for _, v in pairs(weights()) do if type(v) == "number" and v ~= 0 then return true end end
  return false
end

-- Score = sum(weight * stat). Unknown or zero stats add nothing.
function WI.Score(link)
  if type(link) ~= "string" then return nil end
  local stats = C_Item.GetItemStats(link)
  if type(stats) ~= "table" then return nil end
  local total = 0
  for name, key in pairs(ns.PACK.stats) do
    local w, v = weights()[name], stats[key]
    if type(w) == "number" and type(v) == "number" then total = total + w * v end
  end
  return total
end

function WI.Slots(link)
  local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
  return equipLoc and ns.PACK.slots[equipLoc]
end

-- Compares an item with the weakest equipped item it could replace.
-- Returns delta, mode ("weights" | "ilvl"), or nil when not comparable.
function WI.Compare(link)
  local slots = WI.Slots(link)
  if not slots then return nil end
  local useWeights = WI.HasWeights()
  local function value(l)
    if useWeights then return WI.Score(l) end
    return (C_Item.GetDetailedItemLevelInfo(l))
  end
  local mine = value(link)
  if not mine then return nil end
  local worst
  for _, slot in ipairs(slots) do
    local eq = GetInventoryItemLink("player", slot)
    local v = eq and value(eq) or 0
    if not worst or v < worst then worst = v end
  end
  return mine - (worst or 0), useWeights and "weights" or "ilvl"
end

function WI.IsUpgrade(link)
  local d = WI.Compare(link)
  return d ~= nil and d > 0
end

-- Pawn-style scale strings: ( Pawn: v1: "Name": Stat=1.0, Stat2=0.5 )
function WI.Import(text)
  if type(text) ~= "string" then return nil, "nothing to import" end
  local body = text:match("^%s*%(%s*Pawn:%s*v1:%s*\"[^\"]*\":%s*(.-)%s*%)%s*$")
  if not body then return nil, "not a scale string" end
  local out, n = {}, 0
  for k, v in body:gmatch("(%w+)%s*=%s*([%-%d%.]+)") do
    if ns.PACK.stats[k] then out[k] = tonumber(v); n = n + 1 end
  end
  if n == 0 then return nil, "no known stats in the string" end
  Schema:Set("wisdom.weights", out)
  return n
end

function WI.Export()
  local parts = {}
  local names = {}
  for k in pairs(weights()) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. weights()[k] end
  return "( Pawn: v1: \"Phoenix\": " .. table.concat(parts, ", ") .. " )"
end

-- Tooltip line ---------------------------------------------------------------------
function WI.TooltipLine(link)
  local d, mode = WI.Compare(link)
  if not d then return nil end
  local fmt = "%." .. s.decimals .. "f"
  local star = (s.star and d > 0) and "|A:PetJournal-FavoritesIcon:12:12|a " or ""
  if mode == "ilvl" then
    return string.format("%sPhoenix: %+d item level vs equipped", star, math.floor(d + 0.5))
  end
  return string.format("%sPhoenix score " .. fmt .. " (" .. "%+" .. fmt:sub(2) .. " vs equipped)", star, WI.Score(link) or 0, d)
end

local hooked = false
local function hookTooltip()
  if hooked then return end
  hooked = true
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if not WI.active or not s.tooltip or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if PUI.Secret.IsSecret(link) then return end
    local line = WI.TooltipLine(link)
    if line then tooltip:AddLine(line, 1, 0.49, 0.04) end
  end)
end

local function onEnable()
  WI.active = true
  hookTooltip()
  if PUI.Vault and PUI.Vault.Refresh then PUI.Vault.Refresh() end
end
local function onDisable()
  WI.active = false
  if PUI.Vault and PUI.Vault.Refresh then PUI.Vault.Refresh() end
end

local schema = {}
WI.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; if PUI.Vault and PUI.Vault.Refresh and WI.active then PUI.Vault.Refresh() end end
  schema["wisdom." .. name] = def
end
key("tooltip", { type = "toggle", default = true, label = "Score in tooltips", tooltip = "Adds the Phoenix score or item-level difference to item tooltips.", mode = "simple" })
key("star", { type = "toggle", default = true, label = "Upgrade star", tooltip = "Marks items that beat what you wear with a star.", mode = "simple" })
key("bags", { type = "toggle", default = true, label = "Badges in bags", tooltip = "Marks upgrades in Phoenix bags (Vault).", mode = "advanced" })
key("decimals", { type = "range", default = 1, min = 0, max = 3, step = 1, label = "Score decimals", tooltip = "Decimal places in the score.", mode = "advanced" })
schema["wisdom.weights"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Stat weights",
  tooltip = "Your stat weights for this profile (/pui wisdom weight <stat> <value>, or import a scale string).", apply = function() if PUI.Vault and PUI.Vault.Refresh and WI.active then PUI.Vault.Refresh() end end }

PUI.Slash:Register("wisdom", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  local out = PUI.Slash.Print
  if word == "weight" then
    local stat, v = arg:match("^(%w+)%s+([%-%d%.]+)$")
    if not stat or not ns.PACK.stats[stat] then return out("stats: Strength Agility Intellect Stamina CritRating HasteRating MasteryRating Versatility Avoidance Leech MovementSpeed") end
    local w = weights()
    w[stat] = tonumber(v)
    Schema:Set("wisdom.weights", w)
    out(stat .. " = " .. v)
  elseif word == "import" then
    local n, why = WI.Import(arg)
    out(n and (n .. " weights imported") or ("not imported: " .. why))
  elseif word == "export" then
    out(WI.Export())
  elseif word == "clear" then
    Schema:Set("wisdom.weights", {})
    out("weights cleared; comparing item level")
  else
    out("/pui wisdom weight <stat> <value> | import <scale string> | export | clear")
  end
end, "gear advisor weights: set, import, export")

WI.module = PUI:RegisterModule(OWNER, {
  label = "Wisdom", tooltip = "Gear advisor: stat-weight score and upgrade star in tooltips and bags.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
