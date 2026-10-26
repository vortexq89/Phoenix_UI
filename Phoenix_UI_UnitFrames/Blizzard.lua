local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Blizzard unit frames per group: parked under a hidden frame when the group's
-- source is Phoenix or hidden, and returned otherwise. Every park is an
-- approved takeover recorded in PUI.FrameLedger (parent, points, shown, alpha,
-- scale), so turning the module off, or "Uninstall Phoenix", restores exactly
-- what was there (G4, G6). Out of combat only (CombatQueue). No Blizzard method
-- is replaced and no field is written on a Blizzard frame.
local _, ns = ...
local CQ, FrameLedger = PUI.CombatQueue, PUI.FrameLedger
local OWNER = "UnitFrames"

local B = { parked = {} }
ns.Blizzard = B

local hider -- created on first park, never before (zero cost while unused)

local LOOKUP = {
  player = function() return _G.PlayerFrame end,
  target = function() return _G.TargetFrame end,
  focus = function() return _G.FocusFrame end,
  pet = function() return _G.PetFrame end,
  targettarget = function() return _G.TargetFrame and _G.TargetFrame.totFrame end,
  focustarget = function() return _G.FocusFrame and _G.FocusFrame.totFrame end,
  boss = function() return _G.BossTargetFrameContainer end,
  buffs = function() return rawget(_G, "BuffFrame") end,
  debuffs = function() return rawget(_G, "DebuffFrame") end,
}
B.LOOKUP = LOOKUP

function B.Frame(group)
  local fn = LOOKUP[group]
  return fn and fn() or nil
end

local function id(group) return "uf.blizzard." .. group end

function B.Park(group)
  CQ.Defer(id(group), function()
    local frame = B.Frame(group)
    if not frame or B.parked[group] then return end
    if not hider then
      hider = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
      hider:Hide()
      B.hider = hider
    end
    local ok = FrameLedger:Take(OWNER, frame, id(group))
    if not ok then return end -- another owner holds it; never fight over a frame
    B.parked[group] = true
    frame:SetParent(hider)
  end)
end

function B.Restore(group)
  CQ.Defer(id(group), function()
    if not B.parked[group] then return end
    B.parked[group] = nil
    FrameLedger:Release(OWNER, id(group))
  end)
end

function B.IsParked(group) return B.parked[group] ~= nil end

-- The ledger may restore everything at once (module off, Uninstall).
PUI.Kernel:On("LEDGER_UNINSTALLED", function() B.parked = {} end)
