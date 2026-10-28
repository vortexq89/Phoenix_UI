local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cast History strips (mockup 17): one strip per watched unit.
--  * "Moving strip": the newest icon slides in and pushes the others along;
--    when casts come faster than the strip moves, the catch-up speed hurries
--    the queue. Movement runs on one Ticker entry that exists only while a
--    strip is moving (and stops while you hover a paused strip).
--  * "Still and fade": icons sit still and fade out after a set time (one
--    0.25 s Ticker entry while any icon is shown).
-- Icons are pooled (no garbage); the newest can glow (PUI.Glow).
local _, ns = ...
local Ticker, Secret = PUI.Ticker, PUI.Secret
local T = ns.Tracker
local SR = { strips = {}, pool = {} }
ns.Strip = SR
local OWNER = "CastHistory"
SR.DIR = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local function newIcon()
  local b = CreateFrame("Button", nil, UIParent)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints()
  b.edge = b:CreateTexture(nil, "BORDER"); b.edge:SetPoint("TOPLEFT", -1, 1); b.edge:SetPoint("BOTTOMRIGHT", 1, -1); b.edge:SetColorTexture(0, 0, 0, 1)
  b.cross = b:CreateTexture(nil, "OVERLAY"); b.cross:SetAllPoints(); b.cross:SetAtlas("common-icon-redx")
  b.held = b:CreateFontString(nil, "OVERLAY"); b.held:SetPoint("BOTTOMRIGHT", -1, 1)
  b.held:SetFontObject(PUI.Media:FontObject("small"))
  return b
end

function SR.Get(unit, s)
  local st = SR.strips[unit]
  if st then return st end
  st = { unit = unit, icons = {}, frame = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER), queue = 0 }
  st.frame:SetSize(s.iconSize * s.count, s.iconSize)
  st.frame:SetScript("OnEnter", function() st.hover = true end)
  st.frame:SetScript("OnLeave", function() st.hover = false end)
  PUI.Layout:Place(st.frame, "casthistory." .. unit)
  SR.strips[unit] = st
  return st
end

function SR.Texture(spellID, s, unit)
  if T.Plain(spellID) and s.trinketArt and T.TRINKETS[spellID] then
    local faction = UnitFactionGroup(unit)
    local horde = faction ~= nil and not Secret.IsSecret(faction) and faction == "Horde"
    return horde and 1322720 or 1322721
  end
  return C_Spell.GetSpellTexture(spellID)
end

local function release(st, i)
  local b = table.remove(st.icons, i)
  PUI.Glow:Stop(b)
  b:Hide()
  b.spell = nil
  SR.pool[#SR.pool + 1] = b
end

-- Add(unit, spellID, kind, s) -> icon (newest first in st.icons).
function SR.Add(unit, spellID, kind, s)
  local st = SR.Get(unit, s)
  local b = table.remove(SR.pool) or newIcon()
  b:SetParent(st.frame)
  b:SetSize(s.iconSize, s.iconSize)
  b.tex:SetTexture(SR.Texture(spellID, s, unit))
  b.tex:SetTexCoord(s.zoom and 0.08 or 0, s.zoom and 0.92 or 1, s.zoom and 0.08 or 0, s.zoom and 0.92 or 1)
  b.edge:SetShown(s.border)
  b.cross:Hide()
  b.held:SetText(kind == "empower" and s.empowerHeld and "hold" or "")
  b.spell, b.kind, b.born, b.unit = spellID, kind, GetTime(), unit
  b:SetAlpha(1)
  b:SetScript("OnEnter", function(self) st.hover = true; SR.Tooltip(self, s) end)
  b:SetScript("OnLeave", function() st.hover = false; GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self) SR.Click(self) end)
  if s.glowNewest then
    if st.icons[1] then PUI.Glow:Stop(st.icons[1]) end
    PUI.Glow:Start(b, s.glowStyle, nil)
  end
  table.insert(st.icons, 1, b)
  while #st.icons > s.count + 1 do release(st, #st.icons) end
  b:Show()
  if s.mode == "move" then
    st.queue = st.queue + 1
    b.offset = -(s.iconSize + s.spacing) -- enters from outside the strip
    SR.ArmMove()
  else
    SR.Place(st, s)
    SR.ArmFade()
  end
  return b
end

function SR.Mark(b, state)
  if not b then return end
  b.state = state
  b.cross:SetShown(state == "interrupted" or state == "cancelled")
  b.cross:SetVertexColor(state == "cancelled" and 0.75 or 1, state == "cancelled" and 0.75 or 0.15, state == "cancelled" and 0.75 or 0.15, 1)
  b.held:SetText("")
end

-- Static placement (fade mode and after movement settles).
function SR.Place(st, s)
  local d = SR.DIR[s.direction] or SR.DIR.RIGHT
  for i, b in ipairs(st.icons) do
    local off = (i - 1) * (s.iconSize + s.spacing)
    b.offset = off
    b:ClearAllPoints()
    b:SetPoint("CENTER", st.frame, "CENTER", d[1] * (off - (s.count - 1) * (s.iconSize + s.spacing) / 2), d[2] * (off - (s.count - 1) * (s.iconSize + s.spacing) / 2))
    b:SetShown(i <= s.count)
  end
  st.frame:SetSize(d[1] ~= 0 and (s.count * (s.iconSize + s.spacing)) or s.iconSize, d[2] ~= 0 and (s.count * (s.iconSize + s.spacing)) or s.iconSize)
end

-- Movement: every icon slides toward its slot at speed px/s; catch-up
-- multiplies the speed when more than one icon is queued.
function SR.Move(elapsed)
  local s = SR.s
  local moving = false
  local step = s.iconSize + s.spacing
  for _, st in pairs(SR.strips) do
    if not (st.hover and s.pauseOnHover) then
      local rate = step / math.max(0.05, s.speed)
      if st.queue > 1 then rate = rate * s.catchUp end
      local d = SR.DIR[s.direction] or SR.DIR.RIGHT
      local half = (s.count - 1) * step / 2
      for i, b in ipairs(st.icons) do
        local target = (i - 1) * step
        if (b.offset or target) < target then
          b.offset = math.min(target, (b.offset or target) + rate * (elapsed or 0.016))
          moving = true
        else
          b.offset = target
        end
        b:ClearAllPoints()
        b:SetPoint("CENTER", st.frame, "CENTER", d[1] * (b.offset - half), d[2] * (b.offset - half))
        b:SetShown(i <= s.count)
      end
      if not moving then st.queue = 0 end
    else
      moving = true
    end
  end
  if not moving then Ticker:Unregister("ch.move") end
end
function SR.ArmMove()
  if not Ticker:IsRegistered("ch.move") then Ticker:Register("ch.move", 0, function(elapsed) SR.Move(elapsed) end, OWNER) end
end

function SR.Fade()
  local s = SR.s
  local now, any = GetTime(), false
  for _, st in pairs(SR.strips) do
    if not (st.hover and s.pauseOnHover) then
      for i = #st.icons, 1, -1 do
        local b = st.icons[i]
        local age = now - b.born
        if age >= s.fadeAfter + 1 then release(st, i)
        elseif age >= s.fadeAfter then b:SetAlpha(1 - (age - s.fadeAfter)) end
      end
    end
    if #st.icons > 0 then any = true end
  end
  if not any then Ticker:Unregister("ch.fade") end
end
function SR.ArmFade()
  if not Ticker:IsRegistered("ch.fade") then Ticker:Register("ch.fade", 0.25, SR.Fade, OWNER) end
end

function SR.Tooltip(b, s)
  if not s.tooltip or not T.Plain(b.spell) then return end
  GameTooltip:SetOwner(b, "ANCHOR_TOP")
  GameTooltip:SetSpellByID(b.spell)
  GameTooltip:Show()
end
-- Ctrl+Alt+click adds the spell to your blocklist; Shift+click prints the
-- link and ID (opt-in). Plain IDs only.
function SR.Click(b)
  local s = SR.s
  if not T.Plain(b.spell) then return end
  if IsControlKeyDown() and IsAltKeyDown() and s.clickBlock then
    ns.AddBlock(b.spell)
  elseif IsShiftKeyDown() and s.printLink then
    PUI.Slash.Print(string.format("%s (ID %d)", C_Spell.GetSpellName(b.spell) or "?", b.spell))
  end
end

function SR.Restyle(s)
  for _, st in pairs(SR.strips) do
    for _, b in ipairs(st.icons) do b:SetSize(s.iconSize, s.iconSize); b.edge:SetShown(s.border) end
    SR.Place(st, s)
  end
end
function SR.ClearAll()
  for _, st in pairs(SR.strips) do for i = #st.icons, 1, -1 do release(st, i) end; st.queue = 0 end
  Ticker:Unregister("ch.move"); Ticker:Unregister("ch.fade")
end
