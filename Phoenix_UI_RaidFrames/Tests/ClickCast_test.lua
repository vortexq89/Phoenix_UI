local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for click-casting.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local CC = ns.CC

local function enable(t, ...)
  local keys = { "module.ClickCast", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.ClickCast", true)
end

local function frame(t, name)
  local registry = rawget(_G, "ClickCastFrames")
  if registry == nil then registry = {}; _G.ClickCastFrames = registry end
  local f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
  f:SetAttribute("type1", "target")
  f:SetAttribute("type2", "togglemenu")
  registry[f] = true
  t:cleanup(function() registry[f] = nil end)
  return f
end

Tests:Add("ClickCast", "off by default; every setting has apply", function(t)
  t:eq(Schema:Def("module.ClickCast").default, false, "module defaults off")
  for key, def in pairs(CC.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.ClickCast") then t:eq(next(CC.applied), nil, "no attributes written while off") end
end)

Tests:Add("ClickCast", "parser accepts actions and rejects malformed entries", function(t)
  local b, err = CC.Parse("shift-1:spell:Renew; ctrl-alt-2:macro:/cast X; 3:focus; F:spell:Flash Heal; 4:dance; 5:spell")
  t:eq(#b, 4, "four valid bindings")
  t:eq(#err, 2, "two errors")
  t:same(b[2].mods, { "alt", "ctrl" }, "modifiers sorted")
  t:eq(b[4].mouse, false, "keyboard key is hovercast")
  t:same(CC.Attributes(b[1], 1), { ["shift-type1"] = "spell", ["shift-spell1"] = "Renew" }, "mouse attributes")
  t:same(CC.Attributes(b[2], 2), { ["alt-ctrl-type2"] = "macro", ["alt-ctrl-macrotext2"] = "/cast X" }, "macro attributes")
  t:same(CC.Attributes(b[4], 4), { ["*type-phx4"] = "spell", ["*spell-phx4"] = "Flash Heal" }, "hovercast attributes")
  t:eq(CC.KeyList(b), "F=phx4", "hovercast key list")
end)

Tests:Add("ClickCast", "bindings apply to registered frames out of combat and are cleared on disable", function(t)
  if not H then return end
  local f = frame(t, "PhoenixUI_TestClickFrame")
  enable(t, "cc.bindings")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  Schema:Set("cc.bindings", "1:target; shift-1:spell:Renew; G:spell:Flash Heal")
  t:eq(f:GetAttribute("shift-spell1"), nil, "nothing written in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(f:GetAttribute("shift-spell1"), "Renew", "spell binding written")
  t:eq(f:GetAttribute("type2"), nil, "unbound default cleared")
  t:eq(CC.header:GetAttribute("phx-keys"), "G=phx3", "hovercast keys on the secure header")
  local wrapped = 0
  for _, w in ipairs(H.wrapped or {}) do if w.frame == f then wrapped = wrapped + 1 end end
  t:eq(wrapped, 2, "OnEnter and OnLeave wrapped")
  Schema:Set("module.ClickCast", false)
  t:eq(f:GetAttribute("shift-spell1"), nil, "binding removed")
  t:eq(f:GetAttribute("type1"), "target", "default left click restored")
  t:eq(f:GetAttribute("type2"), "togglemenu", "default right click restored")
end)
