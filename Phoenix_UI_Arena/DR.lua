local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- DR tray (plan 1.O "DR display", D-ARENA-DR revised by 19): Phoenix does no
-- DR maths (the combat log is closed). The opt-in switch (off at first
-- install) turns on the game's own enemy DR tracking, CVar
-- spellDiminishPVPEnemiesEnabled, through the CVar ledger (your old value is
-- restored when the switch goes off). Phoenix then draws the game's DR data in
-- its own tray, right of the trinket by default and movable:
--   UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED(unit, trackerInfo)
--   trackerInfo = { category, startTime, duration, showCountdown, isImmune }
-- Times go straight to a Cooldown widget and isImmune to SetAlphaFromBoolean.
-- When the values are plain, a stage label (1/2, 1/4, immune) is shown from the
-- number of updates the game sent in the current DR window, labelled as the
-- game's own state; when they are secret only the icon and swipe are shown.
local _, ns = ...
local Secret = PUI.Secret
local ST = ns.State
local DR = { CVAR = "spellDiminishPVPEnemiesEnabled" }
ns.DR = DR
local OWNER = "Arena"

function DR.Supported()
  return C_SpellDiminish and C_SpellDiminish.IsSystemSupported and C_SpellDiminish.IsSystemSupported() == true
end

-- Apply(on): the opt-in. Writes or restores the CVar through the ledger.
function DR.Apply(on)
  if on then return PUI.CVars:Set(OWNER, DR.CVAR, "1") end
  PUI.CVars:Restore(OWNER, DR.CVAR)
  return true
end

local iconCache = {}
function DR.CategoryIcon(category)
  if category == nil or Secret.IsSecret(category) then return 134400 end
  if iconCache[category] == nil then
    local info = C_SpellDiminish.GetSpellDiminishCategoryInfo(category)
    iconCache[category] = (info and info.icon) or 134400
  end
  return iconCache[category]
end
function DR.CategoryName(category)
  if category == nil or Secret.IsSecret(category) then return nil end
  local info = C_SpellDiminish.GetSpellDiminishCategoryInfo(category)
  return info and info.name
end

DR.STAGE_TEXT = { "1/2", "1/4" }
-- Update(unit, info, now) -> entry. Keyed by category when plain, else by
-- arrival slot (the newest replaces the oldest beyond the tray size).
function DR.Update(unit, info, now)
  if type(info) ~= "table" then return nil end
  local u = ST.Unit(unit)
  local cat = info.category
  local plain = cat ~= nil and not Secret.IsSecret(cat) and not Secret.IsSecret(info.startTime) and not Secret.IsSecret(info.duration)
    and not Secret.IsSecret(info.isImmune)
  local key = plain and ("c" .. tostring(cat)) or ("s" .. tostring((#u.dr % 6) + 1))
  local e
  for _, x in ipairs(u.dr) do if x.key == key then e = x end end
  if not e then e = { key = key, stage = 0 }; u.dr[#u.dr + 1] = e end
  e.info, e.plain, e.category, e.seen = info, plain, cat, now
  if plain then
    if (e.ends or 0) <= now then e.stage = 0 end
    e.stage = e.stage + 1
    e.ends = info.startTime + info.duration
    if info.isImmune then e.stage = 3 end
    u.drHistory[#u.drHistory + 1] = { cat = cat, stage = e.stage, t = now }
  end
  return e
end
function DR.StageText(e)
  if not (e and e.plain) then return "" end
  if e.stage >= 3 then return "immune" end
  return DR.STAGE_TEXT[e.stage] or ""
end
-- Expire(unit, now): drops plain entries whose window ended (secret ones are
-- dropped by the game sending a new state, or on match reset).
function DR.Expire(unit, now)
  local u = ST.Unit(unit)
  for i = #u.dr, 1, -1 do
    local e = u.dr[i]
    if e.plain and (e.ends or 0) <= now then table.remove(u.dr, i) end
  end
  return #u.dr
end

-- Tray widget ----------------------------------------------------------------
function DR.BuildTray(parent)
  local tray = CreateFrame("Frame", nil, parent)
  tray.icons = {}
  return tray
end
local function icon(tray, i)
  local b = tray.icons[i]
  if b then return b end
  b = CreateFrame("Frame", nil, tray)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.edge = b:CreateTexture(nil, "BORDER"); b.edge:SetPoint("TOPLEFT", -1, 1); b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); b.cd:SetAllPoints(); b.cd:SetReverse(true)
  b.immune = b:CreateTexture(nil, "OVERLAY"); b.immune:SetAllPoints(); b.immune:SetColorTexture(0.9, 0.2, 0.2, 0.35)
  b.stage = b:CreateFontString(nil, "OVERLAY"); b.stage:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
  tray.icons[i] = b
  return b
end
DR.STAGE_COLOR = { { 0.24, 0.86, 0.59 }, { 1, 0.76, 0.29 }, { 0.95, 0.3, 0.32 } }
-- Paint(tray, entries, style): style = { size, spacing, grow, text, colorBorder, font }
function DR.Paint(tray, entries, style)
  local n = 0
  for i, e in ipairs(entries or {}) do
    n = i
    local b = icon(tray, i)
    b:SetSize(style.size, style.size)
    b:ClearAllPoints()
    local off = (i - 1) * (style.size + style.spacing)
    if style.grow == "LEFT" then b:SetPoint("RIGHT", tray, "RIGHT", -off, 0)
    elseif style.grow == "UP" then b:SetPoint("BOTTOM", tray, "BOTTOM", 0, off)
    elseif style.grow == "DOWN" then b:SetPoint("TOP", tray, "TOP", 0, -off)
    else b:SetPoint("LEFT", tray, "LEFT", off, 0) end
    b.tex:SetTexture(DR.CategoryIcon(e.category))
    local info = e.info
    b.cd:SetCooldown(info.startTime, info.duration)
    b.cd:SetHideCountdownNumbers(not style.text)
    b.immune:SetAlphaFromBoolean(info.isImmune, 1, 0)
    local c = style.colorBorder and e.plain and DR.STAGE_COLOR[math.min(3, math.max(1, e.stage))] or { 0, 0, 0 }
    b.edge:SetColorTexture(c[1], c[2], c[3], 1)
    b.stage:SetFontObject(PUI.Media:FontObject("small"))
    b.stage:SetText(style.stageText and DR.StageText(e) or "")
    b:Show()
  end
  for i = n + 1, #tray.icons do tray.icons[i]:Hide() end
  local w = math.max(1, n) * (style.size + style.spacing)
  if style.grow == "UP" or style.grow == "DOWN" then tray:SetSize(style.size, w) else tray:SetSize(w, style.size) end
  return n
end
