local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Raid Tools, deferred batch C:
--  * notes window: your own lines per boss ("Boss name: text", "*: text" for
--    every boss). It shows the lines for your target or the boss you last
--    pulled, only out of combat (it hides itself when combat starts).
--  * boss tooltip line: kills, wipes and best time from encounter stats on
--    the tooltip of a boss you have stats for (matched by name and the
--    current difficulty; secret names are skipped, never compared).
--  * stats window: every boss with last pull, best, trend, CSV export and a
--    per-row reset (confirmed); /pui stats window or the module page.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local RT, ST = ns.RT, ns.Stats
local OWNER = "RaidTools"
local s = { notes = true, notesText = {}, notesScale = 1, bossTooltip = true, statsRows = 10 }
local X = { notesFor = nil }
RT.Extras = X
X.settings = s

local function font(fs, size) fs:SetFontObject(PUI.Media:FontObject(size or "small")) end
local function panel(name, w, h, title)
  local f = PUI:CreateFrame("Frame", name, UIParent, nil, OWNER)
  f:SetSize(w, h)
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.92)
  f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2); f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
  f.title = f:CreateFontString(nil, "OVERLAY"); font(f.title, "normal"); f.title:SetPoint("TOPLEFT", 8, -6); f.title:SetText(title)
  f.close = CreateFrame("Button", nil, f); f.close:SetSize(16, 16); f.close:SetPoint("TOPRIGHT", -4, -4)
  f.close.text = f.close:CreateFontString(nil, "OVERLAY"); font(f.close.text); f.close.text:SetAllPoints(); f.close.text:SetText("x")
  f.close:SetScript("OnClick", function() f:Hide() end)
  return f
end
local function plainName(unit)
  local n = UnitName(unit)
  if n == nil or Secret.IsSecret(n) then return nil end
  return n
end

-- Notes ----------------------------------------------------------------------------------------
-- NotesFor(boss) -> lines for that boss plus the "*" lines (pure)
function X.NotesFor(boss, list)
  local out = {}
  for _, line in ipairs(list or s.notesText or {}) do
    local who, text = tostring(line):match("^%s*([^:]+):%s*(.-)%s*$")
    if who and text ~= "" then
      who = who:gsub("%s+$", "")
      if who == "*" or (boss and who:lower() == boss:lower()) then out[#out + 1] = text end
    end
  end
  return out
end
function X.NotesBoss()
  local n = UnitExists("target") and plainName("target")
  if n and #X.NotesFor(n) > #X.NotesFor(nil) then return n end
  return X.lastBoss
end
function X.PaintNotes()
  local want = RT.active and s.notes and not InCombatLockdown()
  local lines = want and X.NotesFor(X.NotesBoss()) or {}
  if #lines == 0 then if X.notes then X.notes:Hide() end return end
  local f = X.notes
  if not f then
    f = panel("PhoenixUIRaidNotes", 260, 60, "Notes")
    f.body = f:CreateFontString(nil, "OVERLAY"); font(f.body); f.body:SetPoint("TOPLEFT", 8, -24); f.body:SetWidth(244); f.body:SetJustifyH("LEFT")
    X.notes = f
    PUI.Layout:Place(f, "raidtools.notes")
  end
  f:SetScale(s.notesScale)
  f.title:SetText("Notes" .. (X.NotesBoss() and ("  |cffb0b0b0" .. X.NotesBoss() .. "|r") or ""))
  f.body:SetText(table.concat(lines, "\n"))
  f:SetHeight(32 + #lines * 14)
  f:Show()
end
function X.OnEncounterStart(_, _, _, name) X.lastBoss = name; if X.notes then X.notes:Hide() end end
-- combat start hides the notes; the combat queue brings them back when it ends
function X.OnCombat()
  if X.notes then X.notes:Hide() end
  PUI.CombatQueue.Defer("rt.notes", X.PaintNotes)
end

-- Boss tooltip line --------------------------------------------------------------------------
function X.StatsFor(name, difficulty)
  if not name then return nil end
  for _, e in pairs(ST.Store()) do
    if e.name == name and (difficulty == nil or e.difficulty == difficulty) then return e end
  end
end
function X.TooltipLine(e)
  if not e then return nil end
  local clock = PUI.CombatTimer and PUI.CombatTimer.Format or function(sec) return string.format("%d:%02d", math.floor(sec / 60), sec % 60) end
  return string.format("Phoenix: %d kills, %d wipes%s", e.kills, e.wipes, e.best and (", best " .. clock(e.best)) or "")
end
function X.OnTooltip(tooltip)
  if not (RT.active and s.bossTooltip and tooltip.GetUnit) then return end
  local _, unit = tooltip:GetUnit()
  if not unit or Secret.IsSecret(unit) then return end
  local _, _, difficulty = GetInstanceInfo()
  local line = X.TooltipLine(X.StatsFor(plainName(unit), difficulty))
  if line then tooltip:AddLine(line, 0.91, 0.64, 0.24) end
end
local hooked = false
function X.HookTooltip()
  if hooked then return end
  hooked = true
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, X.OnTooltip)
end

-- Stats window --------------------------------------------------------------------------------
function X.StatsLines()
  local out = {}
  for _, e in ipairs(ST.Rows()) do out[#out + 1] = { e = e, text = ST.LastLine(e), trend = ST.TrendText(e) } end
  return out
end
function X.ShowStats()
  local f = X.stats
  if not f then
    f = panel("PhoenixUIEncounterStats", 420, 60, "Encounter stats")
    f.export = CreateFrame("Button", nil, f); f.export:SetSize(60, 16); f.export:SetPoint("TOPRIGHT", -24, -4)
    f.export.text = f.export:CreateFontString(nil, "OVERLAY"); font(f.export.text); f.export.text:SetAllPoints(); f.export.text:SetText("|cffe8a33dExport|r")
    f.export:SetScript("OnClick", function() ST.Export() end)
    f.rows = {}
    f.empty = f:CreateFontString(nil, "OVERLAY"); font(f.empty); f.empty:SetPoint("TOPLEFT", 8, -24)
    X.stats = f
    PUI.Layout:Place(f, "raidtools.stats")
  end
  local lines = X.StatsLines()
  local n = math.min(#lines, s.statsRows)
  for i = 1, n do
    local r = f.rows[i]
    if not r then
      r = CreateFrame("Frame", nil, f); r:SetSize(404, 30)
      r:SetPoint("TOPLEFT", 8, -24 - (i - 1) * 32)
      r.top = r:CreateFontString(nil, "OVERLAY"); font(r.top); r.top:SetPoint("TOPLEFT"); r.top:SetWidth(360); r.top:SetJustifyH("LEFT")
      r.sub = r:CreateFontString(nil, "OVERLAY"); font(r.sub); r.sub:SetPoint("TOPLEFT", 0, -14); r.sub:SetWidth(360); r.sub:SetJustifyH("LEFT"); r.sub:SetTextColor(0.7, 0.7, 0.7)
      r.reset = CreateFrame("Button", nil, r); r.reset:SetSize(40, 14); r.reset:SetPoint("TOPRIGHT")
      r.reset.text = r.reset:CreateFontString(nil, "OVERLAY"); font(r.reset.text); r.reset.text:SetAllPoints(); r.reset.text:SetText("|cffff6060reset|r")
      r.reset:SetScript("OnClick", function(self) X.ConfirmReset(self:GetParent().entry) end)
      f.rows[i] = r
    end
    r.entry = lines[i].e
    r.top:SetText(lines[i].text); r.sub:SetText(lines[i].trend)
    r:Show()
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end
  f.empty:SetText(n == 0 and ("no encounter stats yet" .. (ST.Yields() and " (a boss mod keeps them)" or "")) or "")
  f:SetHeight(32 + math.max(1, n) * 32)
  f:Show()
  return f
end
function X.ConfirmReset(e)
  if not e then return end
  PUI.Dialogs:Confirm({ title = "Reset encounter stats", text = "Delete the stats for " .. tostring(e.name or e.id) .. "? This cannot be undone.",
    accept = "Reset", cancel = "Keep", onAccept = function() ST.Reset(e.id, e.difficulty); X.ShowStats() end })
end
PUI.Slash:Register("statswin", function() X.ShowStats() end, "encounter stats window (Raid Tools)")
PUI.Slash:Register("notes", function() X.PaintNotes() end, "show raid notes for your target (Raid Tools, out of combat)")

local enable = ST.Enable
function ST.Enable(mod)
  enable(mod)
  mod:RegisterEvent("ENCOUNTER_START", function(...) ST.OnStart(...); X.OnEncounterStart(...) end)
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", X.OnCombat)
  mod:RegisterEvent("PLAYER_TARGET_CHANGED", X.PaintNotes)
  X.HookTooltip()
  X.PaintNotes()
end

PUI.Layout:RegisterElement("raidtools.notes", { label = "Raid notes", owner = OWNER, size = { 260, 120 }, default = { point = "RIGHT", x = -40, y = 120 } })
PUI.Layout:RegisterElement("raidtools.stats", { label = "Encounter stats window", owner = OWNER, size = { 420, 340 }, default = { point = "CENTER", x = 0, y = 60 } })
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; X.PaintNotes(); if X.stats and X.stats:IsShown() then X.ShowStats() end end
  RT.schema["rt." .. name] = def
  Schema:Register("rt." .. name, def)
  s[name] = Schema:Get("rt." .. name)
end
key("notes", { type = "toggle", default = true, label = "Notes window", tooltip = "Shows your notes for your target or the last boss, only out of combat. Move it in Studio.", mode = "simple" })
key("notesText", { type = "list", default = {}, label = "Notes",
  tooltip = "One line each: \"Boss name: text\". Lines starting with \"*:\" show for every boss.", mode = "simple" })
key("notesScale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Notes scale", tooltip = "Size of the notes window." })
key("bossTooltip", { type = "toggle", default = true, label = "Stats on boss tooltips", tooltip = "Adds kills, wipes and your best time to the tooltip of a boss you have stats for." })
key("statsRows", { type = "range", default = 10, min = 4, max = 20, step = 1, label = "Stats window rows", tooltip = "How many bosses the stats window lists (most recent first)." })
