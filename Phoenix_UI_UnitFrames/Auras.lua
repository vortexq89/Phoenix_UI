local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Unit-frame auras (plan 5.1, 15.3, 1.O "Aura display"): buffs and debuffs on
-- each frame through the one aura engine (PUI.Auras on Blizzard's
-- CustomAuraContainer). This file only describes what to show: a filter
-- picked from plain choices (no code), a count, icon size, icons per row,
-- side of the frame and sort. The engine renders the auras, so secret auras
-- in restricted content need no Lua reads at all.
local _, ns = ...
local Auras = PUI.Auras
local OWNER = "UnitFrames"

local A = {}
ns.UFAuras = A

A.KINDS = { "buffs", "debuffs" }
A.POSITIONS = { "below", "above", "left", "right" }
-- Filter choices -> engine tokens (canonicalised by PUI.Auras.Filter).
A.FILTERS = {
  buffs = { "all", "mine", "raid", "defensive", "important", "cancelable" },
  debuffs = { "all", "mine", "dispellable", "important", "cc" },
}
A.FILTER_LABELS = { all = "All", mine = "Mine only", raid = "Raid buffs", defensive = "Big defensives",
  important = "Important", cancelable = "Cancelable", dispellable = "I can dispel", cc = "Crowd control" }
local TOKENS = { all = nil, mine = "PLAYER", raid = "RAID", defensive = "BIG_DEFENSIVE", important = "IMPORTANT",
  cancelable = "CANCELABLE", dispellable = "RAID_PLAYER_DISPELLABLE", cc = "CROWD_CONTROL" }

function A.FilterFor(kind, choice)
  local base = kind == "buffs" and "HELPFUL" or "HARMFUL"
  local extra = TOKENS[choice]
  if extra then return Auras.Filter(base, extra) end
  return Auras.Filter(base)
end

local function holder(o, kind)
  local h = o.auraHolders[kind]
  if h then return h end
  -- A fixed-size frame we own: the frame anchors to it, never to the
  -- auto-sizing engine container (G36).
  h = PUI:CreateFrame("Frame", nil, o.body, nil, OWNER)
  o.auraHolders[kind] = h
  return h
end

-- Places the holder on the chosen side of the frame (whole pixels, G23).
function A.Place(o, kind, a, group, c)
  local h = holder(o, kind)
  local size, per = a.size, math.max(1, a.perRow)
  local rows = math.max(1, math.ceil(a.max / per))
  local w, ht = per * (size + 2) - 2, rows * (size + 2) - 2
  h:SetSize(w, ht)
  h:ClearAllPoints()
  local b = o.button
  local below = ns.Elements.CastSpace(group, c) + 3
  local other = o.auraHolders[kind == "buffs" and "debuffs" or "buffs"]
  o.auraPos = o.auraPos or {}
  local stacked = kind == "buffs" and other ~= nil and o.auraPos.debuffs == a.position and other:IsShown()
  if a.position == "above" then
    if stacked then h:SetPoint("BOTTOMLEFT", other, "TOPLEFT", 0, 3)
    else h:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 3) end
  elseif a.position == "left" then
    h:SetPoint("TOPRIGHT", b, "TOPLEFT", -(3 + (c.portraitSide ~= "right" and o.portrait:IsShown() and (c.height + 3) or 0)), 0)
  elseif a.position == "right" then
    h:SetPoint("TOPLEFT", b, "TOPRIGHT", 3 + (c.portraitSide == "right" and o.portrait:IsShown() and (c.height + 3) or 0), 0)
  else
    if stacked then h:SetPoint("TOPLEFT", other, "BOTTOMLEFT", 0, -3)
    else h:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -below) end
  end
  o.auraPos[kind] = a.position
  return h
end

-- Configures (or turns off) both aura kinds of one frame. Live: any setting
-- change calls this; unchanged groups make no engine calls (PUI.Auras diffs).
function A.Setup(o, group, c)
  o.auras = o.auras or {}
  for _, kind in ipairs({ "debuffs", "buffs" }) do -- debuffs first: buffs may stack on them
    local a = c.auras[kind]
    local on = a.enabled and a.max > 0 and o.live
    local h = o.auras[kind]
    if on then
      local frame = A.Place(o, kind, a, group, c)
      frame:Show()
      local growX = (a.position == "left") and "LEFT" or "RIGHT"
      local growY = (a.position == "above") and "UP" or "DOWN"
      local layout = { anchor = (growY == "UP" and "BOTTOM" or "TOP") .. (growX == "LEFT" and "RIGHT" or "LEFT"),
        growX = growX, growY = growY, padding = 2, lineSize = a.perRow, size = a.size }
      if not h then
        h = Auras:Create(OWNER, frame, o.unit, layout)
        o.auras[kind] = h
        if h.container then h.container:SetPoint(layout.anchor, frame, layout.anchor) end
      else
        h:SetLayout(layout)
        if h.container then h.container:ClearAllPoints(); h.container:SetPoint(layout.anchor, frame, layout.anchor) end
      end
      h:Configure({ { key = kind, filter = A.FilterFor(kind, a.filter), max = a.max, sort = a.sort, size = a.size } })
      -- Lockout preset (Sated, Forbearance...): only where the client has the setter.
      if kind == "debuffs" and h.SetExclusions then h:SetExclusions(a.hideLockouts and Auras.LOCKOUTS or {}) end
      if h.container then h.container:Show() end
    elseif h then
      h:Configure({ { key = kind, filter = A.FilterFor(kind, a.filter), enabled = false } })
      if h.container then h.container:Hide() end
      if o.auraHolders[kind] then o.auraHolders[kind]:Hide() end
    elseif o.auraHolders[kind] then
      o.auraHolders[kind]:Hide()
    end
  end
end

function A.Off(o)
  if o.dispelHandle then
    o.dispelHandle:Configure({ { key = "dispel", filter = Auras.Filter("HARMFUL", "RAID_PLAYER_DISPELLABLE"), enabled = false } })
    if o.dispelHandle.container then o.dispelHandle.container:Hide() end
  end
  for kind, h in pairs(o.auras or {}) do
    h:Configure({ { key = kind, filter = A.FilterFor(kind, "all"), enabled = false } })
    if h.container then h.container:Hide() end
  end
end

-- Dispel slots: a third aura group with only debuffs the player can dispel,
-- big and apart from the debuff row. The engine filters (no Lua reads).
A.DISPEL_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"
function A.SetupDispel(o, group, c)
  local d = c.dispel
  local h = o.dispelHandle
  local on = d and d.enabled and o.live
  if not on then
    if h then
      h:Configure({ { key = "dispel", filter = Auras.Filter("HARMFUL", "RAID_PLAYER_DISPELLABLE"), enabled = false } })
      if h.container then h.container:Hide() end
    end
    if o.dispelHolder then o.dispelHolder:Hide() end
    return
  end
  local f = o.dispelHolder
  if not f then
    f = PUI:CreateFrame("Frame", nil, o.body, nil, OWNER)
    o.dispelHolder = f
  end
  local w = d.max * (d.size + 2) - 2
  f:SetSize(w, d.size)
  f:SetFrameLevel(o.button:GetFrameLevel() + 8)
  f:ClearAllPoints()
  local b = o.button
  if d.position == "left" then f:SetPoint("RIGHT", b, "LEFT", -3, 0)
  elseif d.position == "right" then f:SetPoint("LEFT", b, "RIGHT", 3, 0)
  elseif d.position == "above" then f:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 3)
  else f:SetPoint("CENTER", b, "CENTER") end
  f:Show()
  local growX = d.position == "left" and "LEFT" or "RIGHT"
  local layout = { anchor = growX == "LEFT" and "TOPRIGHT" or "TOPLEFT", growX = growX, growY = "DOWN", padding = 2,
    lineSize = d.max, size = d.size }
  if not h then
    h = Auras:Create(OWNER, f, o.unit, layout)
    o.dispelHandle = h
  else
    h:SetLayout(layout)
  end
  if h.container then h.container:ClearAllPoints(); h.container:SetPoint(layout.anchor, f, layout.anchor); h.container:Show() end
  h:Configure({ { key = "dispel", filter = Auras.Filter("HARMFUL", "RAID_PLAYER_DISPELLABLE"), max = d.max, sort = "expiration",
    size = d.size } })
end
