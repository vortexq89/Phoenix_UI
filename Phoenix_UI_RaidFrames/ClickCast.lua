local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Click-casting (PUI_V2 5.4, plan 5.2): bindings written as secure attributes
-- on every frame in ClickCastFrames (Phoenix unit, party and raid frames
-- register there), always out of combat through the CombatQueue. Bindings are
-- edited as a list (one binding per row, with a composer in the options:
-- modifier, mouse button or key, action, spell) and the list is overridable,
-- so each spec can have its own set. Keyboard (hovercast) keys are recorded in
-- the binding ledger (PUI.Bindings:Reserve) so conflicts with Blizzard and
-- other Phoenix bindings are shown next to each row. Mouse bindings set
-- "<mods>type<n>" attributes; keyboard bindings are hovercast: a secure
-- handler wraps OnEnter/OnLeave so the restricted environment binds the keys
-- to the hovered frame and clears them on leave. When Clique is loaded,
-- Phoenix only registers its frames with Clique and writes no bindings.
-- Off by default.
local _, ns = ...
local Schema, CQ, Kernel = PUI.Schema, PUI.CombatQueue, PUI.Kernel
local OWNER = "ClickCast"

local CC = { active = false, applied = {}, wrapped = {}, bindings = {}, errors = {} }
ns.CC = CC
PUI.ClickCast = CC

local s = { list = { "1:target", "2:menu" }, hovercast = true }
CC.settings = s

local ACTIONS = { target = "target", menu = "togglemenu", focus = "focus", spell = "spell", macro = "macro", item = "item", assist = "assist" }
local VALUE_ATTR = { spell = "spell", macro = "macrotext", item = "item" }
CC.ACTIONS = ACTIONS
local MODS = { alt = true, ctrl = true, shift = true }

-- Parses "shift-1:spell:Renew; 2:menu; F:spell:Flash Heal" into binding
-- records; returns the records and a list of error strings (nothing applies a
-- malformed entry).
function CC.Parse(text)
  local out, errors = {}, {}
  for entry in string.gmatch(text or "", "[^;]+") do
    entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
    if entry ~= "" then
      local trigger, action, value = entry:match("^([^:]+):([^:]+):?(.*)$")
      local mods, button = {}, nil
      if trigger then
        for part in string.gmatch(trigger:lower(), "[^-]+") do
          if MODS[part] then mods[#mods + 1] = part else button = part end
        end
      end
      action = action and action:lower()
      if not button or not ACTIONS[action] then
        errors[#errors + 1] = entry
      elseif VALUE_ATTR[action] and (value == nil or value == "") then
        errors[#errors + 1] = entry
      else
        table.sort(mods)
        local mouse = button:match("^[1-5]$")
        out[#out + 1] = { mods = mods, button = button, mouse = mouse ~= nil, action = action, value = value ~= "" and value or nil }
      end
    end
  end
  return out, errors
end

-- One list row -> its binding record, or nil + why (the list's item check).
function CC.ParseOne(text)
  local list, errors = CC.Parse(text)
  if #errors > 0 or #list ~= 1 then return nil, "use [mods-]button:action[:value], e.g. shift-1:spell:Renew" end
  return list[1]
end
function CC.ValidateOne(text)
  local b, why = CC.ParseOne(text)
  if not b then return false, why end
  return true
end

-- Builds a list row from composer parts.
function CC.Compose(mods, button, action, value)
  local m = {}
  for _, k in ipairs({ "alt", "ctrl", "shift" }) do if mods and mods[k] then m[#m + 1] = k end end
  local trigger = (#m > 0 and (table.concat(m, "-") .. "-") or "") .. tostring(button):lower()
  if VALUE_ATTR[action] then return trigger .. ":" .. action .. ":" .. (value or "") end
  return trigger .. ":" .. action
end

CC.BUTTON_LABELS = { ["1"] = "Left click", ["2"] = "Right click", ["3"] = "Middle click", ["4"] = "Mouse button 4", ["5"] = "Mouse button 5" }
CC.ACTION_LABELS = { target = "Target", menu = "Open menu", focus = "Set focus", assist = "Assist", spell = "Cast", macro = "Run macro",
  item = "Use item" }

-- Ledger key for a hovercast binding ("SHIFT-F").
function CC.KeyName(b)
  local parts = {}
  for _, m in ipairs(b.mods) do parts[#parts + 1] = m:upper() end
  parts[#parts + 1] = b.button:upper()
  return table.concat(parts, "-")
end

-- "Shift + Left click -> Cast Renew", plus a conflict note when needed.
function CC.Label(text)
  local b = CC.ParseOne(text)
  if not b then return text end
  local parts = {}
  for _, m in ipairs(b.mods) do parts[#parts + 1] = m:sub(1, 1):upper() .. m:sub(2) end
  parts[#parts + 1] = b.mouse and CC.BUTTON_LABELS[b.button] or ("Key " .. b.button:upper() .. " (on hover)")
  local label = table.concat(parts, " + ") .. "  ->  " .. CC.ACTION_LABELS[b.action] .. (b.value and (" " .. b.value) or "")
  local note = CC.ConflictText(b)
  if note then label = label .. "   (" .. note .. ")" end
  return label
end

-- Conflicts for one binding: duplicates in the list, and for keys other
-- Phoenix owners or the user's Blizzard binding (shown, never changed).
function CC.ConflictText(b)
  local same = 0
  for _, other in ipairs(CC.bindings) do
    if other.button == b.button and table.concat(other.mods, "-") == table.concat(b.mods, "-") then same = same + 1 end
  end
  if same > 1 then return "used twice" end
  if b.mouse then return nil end
  local out = {}
  for _, c in ipairs(PUI.Bindings:Conflicts(CC.KeyName(b), "ClickCast")) do
    out[#out + 1] = c.kind == "blizzard" and ("also " .. c.action .. " while not hovering") or ("also used by " .. c.owner)
  end
  if #out == 0 then return nil end
  return table.concat(out, "; ")
end

-- Attribute prefix for modifiers ("alt-ctrl-shift-" order is what the secure
-- button code builds).
local function prefix(mods)
  if #mods == 0 then return "" end
  return table.concat(mods, "-") .. "-"
end

-- Attribute pairs for one binding; hovercast keys use virtual button phx<i>.
function CC.Attributes(b, i)
  local attrs = {}
  if b.mouse then
    local p, n = prefix(b.mods), b.button
    attrs[p .. "type" .. n] = ACTIONS[b.action]
    if VALUE_ATTR[b.action] then attrs[p .. VALUE_ATTR[b.action] .. n] = b.value end
  else
    local v = "phx" .. i
    attrs["*type-" .. v] = ACTIONS[b.action]
    if VALUE_ATTR[b.action] then attrs["*" .. VALUE_ATTR[b.action] .. "-" .. v] = b.value end
  end
  return attrs
end

-- "SHIFT-F=phx3,G=phx4" for the restricted OnEnter snippet.
function CC.KeyList(bindings)
  local keys = {}
  for i, b in ipairs(bindings) do
    if not b.mouse then
      local mods = {}
      for _, m in ipairs(b.mods) do mods[#mods + 1] = m:upper() end
      mods[#mods + 1] = b.button:upper()
      keys[#keys + 1] = table.concat(mods, "-") .. "=phx" .. i
    end
  end
  return table.concat(keys, ",")
end

local ENTER = [[
  local keys = owner:GetAttribute("phx-keys")
  if keys and keys ~= "" then
    for key, button in gmatch(keys, "([^=,]+)=([^,]+)") do self:SetBindingClick(true, key, self, button) end
  end
]]
local LEAVE = [[ self:ClearBindings() ]]
CC.ENTER, CC.LEAVE = ENTER, LEAVE

local header
local function getHeader()
  if not header then
    header = PUI:CreateFrame("Frame", "PhoenixUI_ClickCastHeader", UIParent, "SecureHandlerBaseTemplate", OWNER)
    CC.header = header
  end
  return header
end

local function clear(frame)
  local names = CC.applied[frame]
  if not names then return end
  for name in pairs(names) do frame:SetAttribute(name, nil) end
  CC.applied[frame] = nil
  -- Phoenix frames fall back to their own defaults.
  frame:SetAttribute("type1", "target")
  frame:SetAttribute("type2", "togglemenu")
end

local function applyTo(frame)
  clear(frame)
  if not CC.active then return end
  local names = {}
  frame:SetAttribute("type1", nil)
  frame:SetAttribute("type2", nil)
  for i, b in ipairs(CC.bindings) do
    for name, value in pairs(CC.Attributes(b, i)) do
      frame:SetAttribute(name, value)
      names[name] = true
    end
  end
  CC.applied[frame] = names
  if s.hovercast and not CC.wrapped[frame] and frame:GetName() then
    local h = getHeader()
    h:WrapScript(frame, "OnEnter", ENTER)
    h:WrapScript(frame, "OnLeave", LEAVE)
    CC.wrapped[frame] = true
  end
end

local function frames()
  local list = {}
  local registry = rawget(_G, "ClickCastFrames")
  if type(registry) == "table" then
    for frame, on in pairs(registry) do if on then list[#list + 1] = frame end end
  end
  return list
end

function CC.CliqueLoaded() return C_AddOns.IsAddOnLoaded("Clique") == true end

local function reserveKeys()
  PUI.Bindings:Unreserve(OWNER)
  if not (CC.active and s.hovercast and not CC.CliqueLoaded()) then return end
  for _, b in ipairs(CC.bindings) do
    if not b.mouse then PUI.Bindings:Reserve(OWNER, CC.KeyName(b), "Click-cast on hover: " .. CC.ACTION_LABELS[b.action] .. (b.value and (" " .. b.value) or "")) end
  end
end
CC.ReserveKeys = reserveKeys

function CC.Apply()
  reserveKeys()
  CQ.Defer("cc.apply", function()
    if CC.active and not CC.CliqueLoaded() then
      local h = getHeader()
      h:SetAttribute("phx-keys", s.hovercast and CC.KeyList(CC.bindings) or "")
    end
    for _, frame in ipairs(frames()) do
      if CC.active and not CC.CliqueLoaded() then applyTo(frame) else clear(frame) end
    end
  end)
end

local function parseSetting()
  CC.bindings, CC.errors = CC.Parse(table.concat(s.list or {}, "; "))
  if #CC.errors > 0 then PUI:Log("clickcast", "unparsed", table.concat(CC.errors, " | ")) end
end

Kernel:On("CLICKCAST_FRAME", function(frame)
  if CC.active and not CC.CliqueLoaded() then
    CQ.Defer("cc.frame." .. tostring(frame), function() if CC.active then applyTo(frame) end end)
  end
end)

local function onEnable()
  CC.active = true
  CC.Apply()
end

local function onDisable()
  CC.active = false
  PUI.Bindings:Unreserve(OWNER)
  CQ.Defer("cc.off", function()
    if CC.active then return end
    if header then header:SetAttribute("phx-keys", "") end
    for frame in pairs(CC.applied) do clear(frame) end
  end)
end

local schema = {
  ["cc.list"] = { type = "list", default = { "1:target", "2:menu" }, maxItems = 40, label = "Click-cast bindings",
    tooltip = "One binding per row. Pick a modifier, a mouse button or a key, and what it does: target, menu, focus, assist, cast a spell, run a macro or use an item. Keys work while the mouse is over a frame. Each spec can keep its own list (Editing as). Changes made in combat apply as soon as combat ends.",
    mode = "simple", owner = OWNER, overridable = true, itemValidate = CC.ValidateOne, itemLabel = function(v) return CC.Label(v) end,
    composer = "clickcast", searchTags = { "clique", "click cast", "hover", "bindings", "heal" },
    apply = function(v) s.list = v; parseSetting(); if CC.active then CC.Apply() end end },
  -- Pre-list text form; kept so older profiles move into the list (never reset).
  ["cc.bindings"] = { type = "text", default = "", label = "Click-cast bindings (old text form)", hidden = true,
    tooltip = "Older text form of the bindings; moved into the list automatically.", mode = "advanced", owner = OWNER,
    apply = function() end },
  ["cc.hovercast"] = { type = "toggle", default = true, label = "Hovercast keys",
    tooltip = "Keyboard bindings cast on the frame under the mouse.", mode = "advanced", owner = OWNER,
    apply = function(v) s.hovercast = v; if CC.active then CC.Apply() end end },
}
CC.schema = schema

CC.module = PUI:RegisterModule(OWNER, {
  label = "Click-casting",
  tooltip = "Cast, target or open menus by clicking Phoenix unit, party and raid frames (Clique takes over when installed).",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
-- One-time move of the old text form into the list (this profile only).
function CC.MigrateText()
  local DB = PUI.DB
  local text = DB.profile and DB.profile["cc.bindings"]
  if type(text) ~= "string" or text == "" then return false end
  if DB.profile["cc.list"] == nil then
    local list = {}
    for entry in string.gmatch(text, "[^;]+") do
      entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
      if entry ~= "" then list[#list + 1] = entry end
    end
    DB.profile["cc.list"] = list
  end
  DB.profile["cc.bindings"] = nil
  return true
end
CC.MigrateText()
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
PUI.Kernel:On("PROFILES_CHANGED", function()
  if CC.MigrateText() then for k, def in pairs(schema) do def.apply(Schema:Get(k)) end end
end)
