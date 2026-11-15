local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.FocusKey: a modifier + click on a Phoenix unit frame (and, as an
-- option, party/raid frames) sets focus, through the secure "focus" action
-- of SecureUnitButtonTemplate (e.g. shift-type1 = focus). Attributes change
-- only out of combat (CombatQueue). Nameplates are game-owned protected
-- frames Phoenix may not re-attribute, so they are left alone.
local Schema, CQ = PUI.Schema, PUI.CombatQueue
local FK = { cfg = { mod = "none", button = "1", groupFrames = false }, applied = setmetatable({}, { __mode = "k" }) }
PUI.FocusKey = FK

-- The attribute name for the current choice ("shift-type1"), or nil when off.
function FK.Attr(c)
  c = c or FK.cfg
  if c.mod == "none" then return nil end
  return c.mod .. "-type" .. c.button
end

-- Applies (or clears) the focus click on one secure unit button. group: a party/raid frame.
function FK.Apply(b, group)
  if not b then return end
  if InCombatLockdown() then FK.ApplyAll() return end -- queued until combat ends
  local prev = FK.applied[b]
  local want = FK.Attr()
  if group and not FK.cfg.groupFrames then want = nil end
  if prev == want then return end
  if prev then b:SetAttribute(prev, nil) end
  if want then b:SetAttribute(want, "focus") end
  FK.applied[b] = want or nil
end

function FK.ApplyAll()
  CQ.Defer("focuskey", function()
    local UF = PUI.UnitFrames
    for _, o in pairs(UF and UF.units or {}) do FK.Apply(o.button, false) end
    local RF = PUI.RaidFrames
    for _, o in ipairs(RF and RF.buttons or {}) do FK.Apply(o.button, true) end
  end)
end

local function key(name, def, field)
  def.owner, def.page = "Core", "UnitFrames"
  def.searchTags = { "focus", "modifier", "click" }
  def.apply = function(v) FK.cfg[field] = v; FK.ApplyAll() end
  Schema:Register("focuskey." .. name, def)
end
key("modifier", { type = "select", default = "none", choices = { "none", "shift", "ctrl", "alt" },
  choiceLabels = { none = "Off", shift = "Shift", ctrl = "Ctrl", alt = "Alt" }, label = "Focus key",
  tooltip = "Hold this key and click a Phoenix unit frame to make that unit your focus.", mode = "simple" }, "mod")
key("button", { type = "select", default = "1", choices = { "1", "2" }, choiceLabels = { ["1"] = "Left button", ["2"] = "Right button" },
  label = "Focus key mouse button", tooltip = "Which mouse button sets focus together with the focus key.", mode = "advanced" }, "button")
key("groupFrames", { type = "toggle", default = false, label = "Focus key on party and raid frames",
  tooltip = "Also use the focus key on Phoenix party and raid frames (leave off if click casting uses that key).", mode = "advanced" }, "groupFrames")
for _, k in ipairs({ "modifier", "button", "groupFrames" }) do Schema:Def("focuskey." .. k).apply(Schema:Get("focuskey." .. k)) end
