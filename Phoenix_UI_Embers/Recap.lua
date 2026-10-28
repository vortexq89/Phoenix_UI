local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers death recap (1.O owner; Ascent's death log opens it) and the spell
-- breakdown flyout. Both read Blizzard's own data: C_DeathRecap for the events
-- before a death and C_DamageMeter for one source's spells. Amounts, health
-- and names may be secret: they are handed to SetFormattedText / SetText /
-- AbbreviateNumbers and never compared or added. Lines are pooled.
local _, ns = ...
local EM, Theme, Media, Secret = ns.EM, PUI.Theme, PUI.Media, PUI.Secret
local Recap = { lines = {}, spells = {} }
ns.Recap = Recap
EM.Recap = Recap

local function panel(name, w)
  local f = PUI:CreateFrame("Frame", name, UIParent, nil, EM.OWNER)
  f:SetSize(w, 60)
  f:SetFrameStrata("DIALOG")
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.6)
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(Media:FontObject("header"))
  f.title:SetPoint("TOPLEFT", 8, -6)
  f.title:SetPoint("RIGHT", -24, 0)
  f.title:SetJustifyH("LEFT")
  f:Hide()
  return f
end

-- Text-safe values without touching a secret (no comparison, no "or").
local function str(v) if Secret.IsSecret(v) or type(v) == "string" then return v end return "" end
Recap.Str = str

local function line(f, pool, i)
  local fs = pool[i]
  if not fs then
    fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Media:FontObject("small"))
    fs:SetJustifyH("LEFT")
    pool[i] = fs
  end
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", 8, -26 - (i - 1) * 14)
  fs:SetPoint("RIGHT", -8, 0)
  fs:Show()
  return fs
end

-- Events for a recap ID, newest last, trimmed to the setting. Each event:
-- { spell, amount, hp, source, heal, overkill, at } as the API gives them.
function Recap.Events(recapID)
  if type(recapID) ~= "number" or Secret.IsSecret(recapID) then return {} end
  if not C_DeathRecap.HasRecapEvents(recapID) then return {} end
  local events = C_DeathRecap.GetRecapEvents(recapID) or {}
  local out, n = {}, EM.settings.recapEvents
  for i = math.max(1, #events - n + 1), #events do
    local e = events[i]
    out[#out + 1] = { spell = e.spellName, spellID = e.spellId, amount = e.amount, hp = e.currentHP, source = e.sourceName,
      overkill = e.overkill, at = e.timestamp, school = e.school }
  end
  return out
end

function Recap.Open(recapID, name, class)
  local f = Recap.frame
  if not f then
    f = panel("PhoenixUI_EmbersRecap", 300)
    f:SetPoint("CENTER", 0, 120)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local close = PUI:CreateFrame("Button", nil, f, nil, EM.OWNER)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    close.text = close:CreateFontString(nil, "OVERLAY")
    close.text:SetFontObject(Media:FontObject("body"))
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    close:SetScript("OnClick", function() Recap.Close() end)
    Recap.frame = f
  end
  local r, g, b = EM.ClassColor(class)
  f.title:SetTextColor(r, g, b)
  f.title:SetText(Secret.IsSecret(name) and name or (type(name) == "string" and name or "Death recap"))
  local events = Recap.Events(recapID)
  local n = 0
  for i, e in ipairs(events) do
    n = i
    local fs = line(f, Recap.lines, i)
    -- "-412K  Poison Bolt  (Kyveza)   HP 18%"; every value goes to the formatter as is.
    fs:SetFormattedText("-%s  %s  |cff9a9a9a%s|r", PUI.Format.Number(e.amount), str(e.spell), str(e.source))
    fs:SetTextColor(i == #events and 1 or 0.9, i == #events and 0.35 or 0.9, i == #events and 0.35 or 0.9)
  end
  if n == 0 then
    n = 1
    line(f, Recap.lines, 1):SetText("No recap for this death (the game keeps the last few only).")
  end
  for i = n + 1, #Recap.lines do Recap.lines[i]:Hide() end
  f:SetHeight(34 + n * 14)
  f:Show()
  Recap.shown = recapID
  return #events
end

function Recap.Close()
  if Recap.frame then Recap.frame:Hide() end
  Recap.shown = nil
end

-- Breakdown flyout beside a window; opens on the side with more screen room.
function Recap.Side(w)
  local left = w.frame:GetLeft() or 0
  local width = (UIParent.GetWidth and UIParent:GetWidth()) or 1920
  return (left + (w.frame:GetWidth() or 0) / 2) > width / 2 and "left" or "right"
end

function Recap.ShowBreakdown(w, d)
  local f = Recap.flyout
  if not f then f = panel("PhoenixUI_EmbersBreakdown", 230); Recap.flyout = f end
  local spells = {}
  if w.source ~= "Saved" then spells = EM.SourceSpells(w.source, w.meter, d.guid) end
  f:ClearAllPoints()
  if Recap.Side(w) == "left" then f:SetPoint("TOPRIGHT", w.frame, "TOPLEFT", -4, 0) else f:SetPoint("TOPLEFT", w.frame, "TOPRIGHT", 4, 0) end
  f.title:SetText(d.name)
  local r, g, b = EM.ClassColor(d.class)
  f.title:SetTextColor(r, g, b)
  local n = 0
  for i, sp in ipairs(spells) do
    n = i
    local fs = line(f, Recap.spells, i)
    fs:SetFormattedText("%s  |cffd0d0d0%s|r", str(C_Spell.GetSpellName(sp.spellID)), EM.FormatNumber(sp.amount))
  end
  if n == 0 then
    n = 1
    line(f, Recap.spells, 1):SetText(w.source == "Saved" and "Saved segments keep totals only." or "No spell data yet.")
  end
  for i = n + 1, #Recap.spells do Recap.spells[i]:Hide() end
  f:SetHeight(34 + n * 14)
  f:Show()
  Recap.side = Recap.Side(w)
end

function Recap.HideBreakdown() if Recap.flyout then Recap.flyout:Hide() end end
