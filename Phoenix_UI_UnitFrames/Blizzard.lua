local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Blizzard unit frames per group: parked under a hidden frame (reparent, out
-- of combat through the CombatQueue) when the group's source is Phoenix or
-- hidden, and returned to their original parent otherwise. No Blizzard method
-- is replaced and no Blizzard field is written.
local _, ns = ...
local CQ = PUI.CombatQueue

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
}
B.LOOKUP = LOOKUP

function B.Frame(group)
  local fn = LOOKUP[group]
  return fn and fn() or nil
end

function B.Park(group)
  CQ.Defer("uf.blizzard." .. group, function()
    local frame = B.Frame(group)
    if not frame or B.parked[group] then return end
    if not hider then
      hider = PUI:CreateFrame("Frame", nil, UIParent, nil, "UnitFrames")
      hider:Hide()
      B.hider = hider
    end
    B.parked[group] = frame:GetParent() or UIParent
    frame:SetParent(hider)
  end)
end

function B.Restore(group)
  CQ.Defer("uf.blizzard." .. group, function()
    local parent = B.parked[group]
    if not parent then return end
    B.parked[group] = nil
    local frame = B.Frame(group)
    if frame then frame:SetParent(parent) end
  end)
end

function B.IsParked(group) return B.parked[group] ~= nil end
