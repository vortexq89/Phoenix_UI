local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- The layer key (plan 1.9 "keybind" condition). One key, bound through the
-- Binding ledger to a Phoenix click button, turns the "keybind" override layer
-- on: held (on while the key is down) or toggled (each press flips it). Any
-- overridable setting can hold a "While my layer key is active" value, edited
-- with the same "Editing as" banner as the other conditions. Changes apply
-- live through Overrides:Recompose. Nothing is bound at first install.
local KeyLayer = { BUTTON = "PhoenixUIKeyLayerButton" }
PUI.KeyLayer = KeyLayer
local Schema, O = PUI.Schema, PUI.Overrides
local OWNER = "Overrides"

function KeyLayer:Set(on)
  on = on and true or false
  if O.keyLayer == on then return false end
  O.keyLayer = on
  O:Recompose()
  PUI.Kernel:Fire("KEYLAYER_CHANGED", on)
  if on and Schema:Get("core.keyLayer.announce") then PUI.Slash.Print("layer key: on") end
  return true
end

-- Press(down): the click handler's logic, kept pure for the tests.
function KeyLayer:Press(down)
  if Schema:Get("core.keyLayer.mode") == "hold" then return self:Set(down) end
  if down then return self:Set(not O.keyLayer) end
  return false
end

local button
local function ensureButton()
  if button then return button end
  button = PUI:CreateFrame("Button", KeyLayer.BUTTON, UIParent, nil, OWNER)
  button:Hide()
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:SetScript("OnClick", function(_, _, down) KeyLayer:Press(down) end)
  return button
end

function KeyLayer:Apply()
  local key = Schema:Get("core.keyLayer.key")
  PUI.Bindings:Release(OWNER)
  if key ~= "" then
    ensureButton()
    PUI.Bindings:Claim(OWNER, key, { click = KeyLayer.BUTTON, button = "LeftButton" })
  else
    self:Set(false)
  end
end

Schema:Register("core.keyLayer.key", {
  type = "keybind", default = "", owner = OWNER, mode = "advanced",
  label = "Layer key",
  tooltip = "A key that switches on your \"While my layer key is active\" overrides (for example bigger nameplates or a different action bar page look). Leave empty for no key.",
  searchTags = { "keybind", "condition", "override", "modifier" },
  apply = function() KeyLayer:Apply() end,
})
Schema:Register("core.keyLayer.mode", {
  type = "select", default = "hold", choices = { "hold", "toggle" },
  choiceLabels = { hold = "On while I hold the key", toggle = "Each press switches it on or off" },
  label = "Layer key works", tooltip = "Hold: the layer is on only while the key is down. Toggle: press once for on, again for off.",
  owner = OWNER, mode = "advanced", apply = function() KeyLayer:Set(false) end,
})
Schema:Register("core.keyLayer.announce", {
  type = "toggle", default = false, label = "Say it in chat when the layer turns on",
  tooltip = "Prints a short line each time the layer key turns the layer on.", owner = OWNER, mode = "advanced",
  apply = function() end,
})
PUI.Slash:Register("layer", function(rest)
  if rest == "on" or rest == "off" then KeyLayer:Set(rest == "on") else KeyLayer:Set(not O.keyLayer) end
  PUI.Slash.Print("layer key: " .. (O.keyLayer and "on" or "off"))
end, "[on|off]: switch the layer-key overrides")
