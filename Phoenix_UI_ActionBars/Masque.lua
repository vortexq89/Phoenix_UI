local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Masque groups for Action Bars buttons (PUI.Masque, no-op without Masque):
-- "Action bar N", the special bars by name, "Auto item bar N". Buttons join
-- after each bar's own (out-of-combat) rebuild.
local _, ns = ...
local AB, SP, IB, Btn, CQ = ns.AB, ns.Special, ns.ItemBars, ns.Buttons, PUI.CombatQueue
local M = PUI.Masque

local function sync(area, name, buttons)
  for _, b in ipairs(buttons or {}) do
    local was = b.puiMasque
    M.Add(area, name, b)
    if was ~= b.puiMasque then Btn.ApplyLook(b) end
  end
end

function AB.MasqueBar(i) local bar = AB.bars[i]; if bar then sync("ab", "Action bar " .. i, bar.buttons) end end
function SP.MasqueBar(kind) local bar = SP.bars[kind]; if bar then sync("special", SP.KINDS[kind].label, bar.buttons) end end
function IB.MasqueBar(i) local bar = IB.bars[i]; if bar then sync("items", "Auto item bar " .. i, bar.buttons) end end

local applyBar = AB.ApplyBar
function AB.ApplyBar(i) applyBar(i); CQ.Defer("ab.masque" .. i, function() AB.MasqueBar(i) end) end
local spApply = SP.Apply
function SP.Apply(kind) spApply(kind); CQ.Defer("ab.masque." .. kind, function() SP.MasqueBar(kind) end) end
local ibApply = IB.Apply
function IB.Apply(i) ibApply(i); CQ.Defer("ab.masqueIb" .. i, function() IB.MasqueBar(i) end) end

M.OnArea("ab", function() CQ.Defer("ab.masqueAll", function() for i in pairs(AB.bars) do AB.MasqueBar(i) end end) end)
M.OnArea("special", function() CQ.Defer("ab.masqueSp", function() for k in pairs(SP.bars) do SP.MasqueBar(k) end end) end)
M.OnArea("items", function() CQ.Defer("ab.masqueIbAll", function() for i in pairs(IB.bars) do IB.MasqueBar(i) end end) end)
