local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Keybind mode (plan 1.20, 13.5 "Hover-bind with conflict warning"): point at
-- any Phoenix action button and press a key (with Shift/Ctrl/Alt) to bind it.
-- Delete or Backspace clears that button's Phoenix keys; Escape (or
-- /pui kb) leaves; /pui kb undo takes back the last change; "Discard" on leave
-- puts back what you had when the mode started.
-- Phoenix never edits your saved Blizzard bindings: these keys live in the
-- setting ab.binds ("ButtonName=KEY" lines) and are applied as override
-- bindings through the binding ledger (PUI.Bindings, owner "ActionBars.keys"),
-- so they show on the ledger page and in every conflict check. A key already
-- used elsewhere is reported (Phoenix owner or Blizzard command) when it is
-- bound; the newest binding wins, and undo restores the previous one.
local _, ns = ...
local Schema, Slash = PUI.Schema, PUI.Slash
local Btn = ns.Buttons
local OWNER, LEDGER = "ActionBars", "ActionBars.keys"

local KB = { on = false, undo = {}, map = {} }
ns.KB = KB

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }

-- "Btn=KEY" list <-> { [buttonName] = { KEY, ... } }
function KB.Decode(list)
  local map = {}
  for _, line in ipairs(list or {}) do
    local name, key = line:match("^([%w_]+)=([%u%d%-]+)$")
    if name then map[name] = map[name] or {}; table.insert(map[name], key) end
  end
  return map
end

function KB.Encode(map)
  local out, names = {}, {}
  for name in pairs(map) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do for _, key in ipairs(map[name]) do out[#out + 1] = name .. "=" .. key end end
  return out
end

-- Combo for a key press with the held modifiers, canonical (ALT-CTRL-SHIFT-X).
function KB.Combo(key)
  if type(key) ~= "string" or MODIFIER_KEYS[key] then return nil end
  local mods = ""
  if IsAltKeyDown() then mods = mods .. "ALT-" end
  if IsControlKeyDown() then mods = mods .. "CTRL-" end
  if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
  return PUI.Bindings.Normalise(mods .. key)
end

-- Applies the saved keys through the ledger (called by Action Bars after its redirects).
function KB.Apply()
  PUI.Bindings:Release(LEDGER)
  for _, b in ipairs(Btn.all) do b.extraKey = false end
  local AB = ns.AB
  if not (AB and AB.active) then return end
  for name, keys in pairs(KB.map) do
    local b = _G[name]
    if b and b.live then
      for _, key in ipairs(keys) do PUI.Bindings:Claim(LEDGER, key, { click = name, button = "LeftButton" }) end
      b.extraKey = keys[1]
    end
  end
end

local function save(map, noUndo)
  if not noUndo then KB.undo[#KB.undo + 1] = KB.Encode(KB.map) end
  Schema:Set("ab.binds", KB.Encode(map))
end

-- Binds key to the button named name. Returns the conflicts found (may be empty).
function KB.Bind(name, key)
  local combo = PUI.Bindings.Normalise(key)
  if not combo then return nil end
  local conflicts = PUI.Bindings:Conflicts(combo, LEDGER)
  local map = KB.Decode(KB.Encode(KB.map))
  for other, keys in pairs(map) do -- one button per key
    for i = #keys, 1, -1 do if keys[i] == combo then table.remove(keys, i) end end
    if #keys == 0 then map[other] = nil end
  end
  map[name] = map[name] or {}
  table.insert(map[name], 1, combo)
  save(map)
  return conflicts, combo
end

function KB.Clear(name)
  if not KB.map[name] then return end
  local map = KB.Decode(KB.Encode(KB.map))
  map[name] = nil
  save(map)
end

function KB.Undo()
  local last = table.remove(KB.undo)
  if not last then return false end
  save(KB.Decode(last), true)
  return true
end

local function describe(conflicts)
  local parts = {}
  for _, c in ipairs(conflicts or {}) do
    parts[#parts + 1] = c.kind == "blizzard" and ("Blizzard: " .. tostring(c.action)) or ("Phoenix " .. c.owner)
  end
  return table.concat(parts, ", ")
end

-- The capture overlay: a keyboard-only frame (no mouse, so buttons stay hoverable).
local function capture()
  if KB.frame then return KB.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_KeybindMode", UIParent, nil, OWNER)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(false)
  f:EnableKeyboard(true)
  f.label = f:CreateFontString(nil, "OVERLAY")
  f.label:SetFontObject(PUI.Media:FontObject("title"))
  f.label:SetPoint("TOP", 0, -120)
  f.label:SetText("Keybind mode: point at a button and press a key. Delete clears, Escape leaves.")
  f:SetScript("OnKeyDown", function(_, key) KB.OnKey(key) end)
  f:Hide()
  KB.frame = f
  return f
end

function KB.Hovered()
  for _, b in ipairs(Btn.all) do if b.live and b:IsMouseOver() then return b end end
  return nil
end

function KB.OnKey(key)
  if key == "ESCAPE" then KB.Stop() return end
  local b = KB.Hovered()
  if not b then return end
  if key == "DELETE" or key == "BACKSPACE" then KB.Clear(b:GetName()) return end
  local combo = KB.Combo(key)
  if not combo then return end
  local conflicts = KB.Bind(b:GetName(), combo)
  local note = describe(conflicts)
  Slash.Print(combo .. " -> " .. b:GetName() .. (note ~= "" and (" (was also: " .. note .. ")") or ""))
end

function KB.Start()
  if InCombatLockdown() then Slash.Print("keybind mode is not available in combat") return false end
  local AB = ns.AB
  if not (AB and AB.active) then Slash.Print("turn on Phoenix action bars first") return false end
  KB.on = true
  KB.startState = KB.Encode(KB.map)
  capture():Show()
  return true
end

-- Stop(silent): leaves the mode, keeping the changes.
function KB.Stop(silent)
  if not KB.on then return end
  KB.on = false
  if KB.frame then KB.frame:Hide() end
  if not silent then Slash.Print("keybind mode off (/pui kb discard puts back the keys you had before)") end
end

function KB.Discard()
  if not KB.startState then return false end
  save(KB.Decode(KB.startState))
  KB.startState = nil
  return true
end

Slash:Register("kb", function(rest)
  local cmd = (rest or ""):match("^(%S*)")
  if cmd == "undo" then Slash.Print(KB.Undo() and "undone" or "nothing to undo")
  elseif cmd == "discard" then Slash.Print(KB.Discard() and "keybinds put back" or "nothing to put back")
  elseif KB.on then KB.Stop()
  else KB.Start() end
end, "keybind mode: hover a button and press a key | undo | discard")

local schema = {}
KB.schema = schema
schema["ab.binds"] = { type = "list", default = {}, maxItems = 300, owner = OWNER, label = "Phoenix keybinds",
  tooltip = "Keys bound with keybind mode (/pui kb). They are Phoenix override bindings, so your saved Blizzard keybinds stay as they are.",
  mode = "advanced", searchTags = { "keybind", "hotkey", "bind" },
  itemValidate = function(v) return v:match("^[%w_]+=[%u%d%-]+$") ~= nil, "Button=KEY" end,
  apply = function(v)
    KB.map = KB.Decode(v)
    if ns.AB and ns.AB.active then
      KB.Apply()
      for _, b in ipairs(Btn.all) do Btn.UpdateHotkey(b) end
    end
  end }
