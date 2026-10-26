local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Click-casting (PUI_V2 5.4): bindings written as secure attributes on every
-- frame in ClickCastFrames (Phoenix unit, party and raid frames register
-- there), always out of combat through the CombatQueue. Mouse bindings set
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

local s = { text = "1:target; 2:menu", hovercast = true }
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

function CC.Apply()
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
  CC.bindings, CC.errors = CC.Parse(s.text)
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
  CQ.Defer("cc.off", function()
    if CC.active then return end
    if header then header:SetAttribute("phx-keys", "") end
    for frame in pairs(CC.applied) do clear(frame) end
  end)
end

local schema = {
  ["cc.bindings"] = { type = "text", default = "1:target; 2:menu", label = "Click-cast bindings",
    tooltip = "Entries separated by ';' as [mods-]button:action[:value]. Buttons 1-5 are mouse buttons, any other key is hovercast. Actions: target, menu, focus, assist, spell:<name>, macro:<text>, item:<name>. Example: shift-1:spell:Renew; F:spell:Flash Heal.",
    mode = "simple", owner = OWNER,
    apply = function(v) s.text = v; parseSetting(); if CC.active then CC.Apply() end end },
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
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
