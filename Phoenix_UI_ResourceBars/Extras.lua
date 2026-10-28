local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Resource bars, deferred batch A (docs/DEFERRED.md): a latency zone and
-- channel tick marks on the cast bar, empower stage marks, global cooldown
-- bar modes (always / in instances / hide while casting), an aura stack bar
-- for spec helpers whose resource lives in a hidden aura, power colour by
-- threshold through an engine colour curve, and bars that close up when a
-- resource is missing. The swing timer is blocked: it needs the combat log,
-- which addons no longer receive (see docs/DEFERRED.md).
-- Secret values (power, stacks) only go to widgets; nothing is compared.
local _, ns = ...
local RB = ns.RB
local Schema, Secret, Theme, Bars = PUI.Schema, PUI.Secret, PUI.Theme, PUI.Bars
local OWNER = "ResourceBars"
local cfg = RB.cfg
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

local X = { KEYS = {} }
RB.Extras = X
local E = {
  latency = false, latencyColor = { r = 1, g = 0.2, b = 0.2, a = 0.45 },
  ticks = {}, stages = true, gcdMode = "always",
  auraSpell = 0, auraMax = 5, collapse = true,
  thresholds = false, lowPct = 25, highPct = 80,
  lowColor = { r = 0.9, g = 0.2, b = 0.2 }, midColor = { r = 1, g = 0.82, b = 0.25 }, highColor = { r = 0.2, g = 0.85, b = 0.35 },
}
X.settings = E

-- Aura stack bar: a new slot in the stack (after the class resource) -----------
table.insert(RB.ORDER, 4, "aura")
cfg.aura = { on = false, height = 6 }

-- "12345=5, 6789=3" -> { [12345] = 5, [6789] = 3 } (ticks per channel).
function X.ParseTicks(text)
  local out = {}
  for id, n in tostring(text or ""):gmatch("(%d+)%s*=%s*(%d+)") do
    id, n = tonumber(id), tonumber(n)
    if n >= 2 and n <= 20 then out[id] = n end
  end
  return out
end

-- Cast bar marks ------------------------------------------------------------------
local function marks(bar)
  local list = rawget(bar, "puiMarks")
  if not list then list = {}; bar.puiMarks = list end
  return list
end
local function hideMarks(bar)
  for _, m in ipairs(marks(bar)) do m:Hide() end
  if rawget(bar, "puiLatency") then bar.puiLatency:Hide() end
end
-- Thin lines at fractions 0-1 of the bar width.
function X.DrawMarks(bar, fractions)
  local list, w, h = marks(bar), bar.status:GetWidth(), bar.status:GetHeight()
  for i, f in ipairs(fractions) do
    local m = list[i]
    if not m then
      m = bar.status:CreateTexture(nil, "OVERLAY")
      Theme:Paint(m, "text.primary", 0.85)
      list[i] = m
    end
    m:ClearAllPoints()
    m:SetSize(1, h)
    m:SetPoint("LEFT", bar.status, "LEFT", math.floor(w * f + 0.5), 0)
    m:Show()
  end
  for i = #fractions + 1, #list do list[i]:Hide() end
end

-- The player's own cast times are plain numbers; anything secret is skipped.
local function castWindow(kind)
  local s, e
  if kind == "cast" then s, e = select(4, UnitCastingInfo("player"))
  else s, e = select(4, UnitChannelInfo("player")) end
  if plain(s) and plain(e) and e > s then return (e - s) / 1000 end
end
X.CastWindow = castWindow

function X.OnStart(bar, kind)
  hideMarks(bar)
  if bar.unit ~= "player" then return end
  local total = castWindow(kind)
  if not total then return end
  if kind == "cast" and E.latency then
    local _, _, home, world = GetNetStats()
    local ms = math.max(plain(home) and home or 0, plain(world) and world or 0)
    local lat = rawget(bar, "puiLatency")
    if not lat then
      lat = bar.status:CreateTexture(nil, "OVERLAY")
      bar.puiLatency = lat
    end
    local c = E.latencyColor
    lat:SetColorTexture(c.r, c.g, c.b, c.a or 0.45)
    lat:ClearAllPoints()
    lat:SetPoint("TOPRIGHT", bar.status, "TOPRIGHT", 0, 0)
    lat:SetSize(math.max(1, math.min(1, ms / 1000 / total) * bar.status:GetWidth()), bar.status:GetHeight())
    lat:Show()
  elseif kind ~= "cast" then
    local _, _, _, _, _, _, _, spellID, empowered, stages = UnitChannelInfo("player")
    if empowered == true and E.stages and plain(stages) and stages > 0 then
      local fr, at = {}, 0
      for i = 0, stages - 1 do
        local d = GetUnitEmpowerStageDuration("player", i)
        if not plain(d) then return end
        at = at + d / 1000
        if at < total then fr[#fr + 1] = at / total end
      end
      X.DrawMarks(bar, fr)
    elseif plain(spellID) and E.ticks[spellID] then
      local n, fr = E.ticks[spellID], {}
      for i = 1, n - 1 do fr[i] = i / n end
      X.DrawMarks(bar, fr)
    end
  end
end

function X.HookCastBar()
  local bar = RB.castBar
  if not bar or rawget(bar, "puiExtras") then return end
  bar.puiExtras = true
  local start, stop = bar.Start, bar.Stop
  bar.Start = function(self, kind, ...)
    local r = start(self, kind, ...)
    if self.casting then X.OnStart(self, kind) end
    if cfg.gcd.on and E.gcdMode == "instant" then RB.UpdateGCD() end
    return r
  end
  bar.Stop = function(self, ...)
    hideMarks(self)
    local r = stop(self, ...)
    if cfg.gcd.on and E.gcdMode == "instant" then RB.UpdateGCD() end
    return r
  end
end
local layoutCast = RB.LayoutCast
function RB.LayoutCast(width)
  layoutCast(width)
  X.HookCastBar()
end

-- GCD bar modes --------------------------------------------------------------------
local updateGCD = RB.UpdateGCD
function X.GcdAllowed()
  if E.gcdMode == "instance" then return IsInInstance() == true end
  if E.gcdMode == "instant" then return UnitCastingDuration("player") == nil and UnitChannelDuration("player") == nil end
  return true
end
function RB.UpdateGCD()
  if not X.GcdAllowed() then RB.bars.gcd:SetAlpha(0) return end
  updateGCD()
end

-- Power colour by threshold (engine colour curve; the percent never reaches Lua) ---
function X.PowerCurve()
  if X.curve then return X.curve end
  local c = C_CurveUtil.CreateColorCurve()
  c:SetType(Enum.LuaCurveType.Step)
  local function col(t) return CreateColor(t.r, t.g, t.b, 1) end
  c:AddPoint(0, col(E.lowColor))
  c:AddPoint(E.lowPct / 100, col(E.midColor))
  c:AddPoint(E.highPct / 100, col(E.highColor))
  X.curve = c
  return c
end
local paintPower = RB.PaintPower
function RB.PaintPower()
  if not E.thresholds then return paintPower() end
  local color = UnitPowerPercent("player", nil, false, X.PowerCurve())
  if color then RB.bars.power:SetStatusBarColor(color:GetRGB()) end
end
local updatePower = RB.UpdatePower
function RB.UpdatePower()
  updatePower()
  if E.thresholds and cfg.power.on then RB.PaintPower() end
end

-- Aura stack bar -------------------------------------------------------------------
function X.AuraBar()
  if X.auraBar or not RB.slots then return X.auraBar end
  local b = Bars:Create(RB.slots.aura, OWNER)
  b:SetAllPoints(RB.slots.aura)
  Bars.TokenColor(b, "accent")
  X.auraBar = b
  return b
end
function X.UpdateAura()
  local b = X.AuraBar()
  if not (b and cfg.aura.on) then return end
  local id = E.auraSpell
  local a = id > 0 and C_UnitAuras.GetPlayerAuraBySpellID(id) or nil
  b:SetMinMaxValues(0, E.auraMax)
  b:SetValue(a and a.applications or 0) -- may be secret: straight to the widget
  if E.collapse and (a == nil) ~= (X.auraMissing == true) then RB.Reconfigure() end
end

-- Collapse: slots whose resource is missing close up so the bars below move up.
local layout = RB.Layout
function RB.Layout()
  local saved = {}
  if E.collapse then
    if cfg.aura.on and (E.auraSpell <= 0 or C_UnitAuras.GetPlayerAuraBySpellID(E.auraSpell) == nil) then
      saved.aura = true; cfg.aura.on = false
    end
    if cfg.totem.on and GetNumTotemSlots() == 0 then saved.totem = true; cfg.totem.on = false end
  end
  X.auraMissing = saved.aura == true
  layout()
  for k in pairs(saved) do cfg[k].on = true end
end

local wire = RB.Wire
RB.ALL_EVENTS[#RB.ALL_EVENTS + 1] = "UNIT_AURA"
function RB.Wire()
  wire()
  local mod = RB.mod
  if not (mod and RB.active) then return end
  if cfg.aura.on then mod:RegisterUnitEvent("UNIT_AURA", X.UpdateAura, "player") end
end
local updateAll = RB.UpdateAll
function RB.UpdateAll()
  updateAll()
  if RB.active and cfg.aura.on then X.UpdateAura() end
end

-- Schema -----------------------------------------------------------------------------
local function key(name, def, set)
  def.owner = OWNER
  def.apply = function(v)
    set(v)
    X.curve = nil
    RB.Reconfigure()
  end
  RB.schema[name] = def
  X.KEYS[#X.KEYS + 1] = name
end
key("rb.cast.latency", { type = "toggle", default = false, label = "Latency zone on the cast bar",
  tooltip = "Shades the end of your cast that falls inside your network latency, so you can queue the next spell there.",
  mode = "simple" }, function(v) E.latency = v end)
key("rb.cast.latencyColor", { type = "color", default = { r = 1, g = 0.2, b = 0.2, a = 0.45 }, label = "Latency zone colour",
  tooltip = "Colour of the latency zone.", mode = "advanced" }, function(v) E.latencyColor = v end)
key("rb.cast.channelTicks", { type = "text", default = "", label = "Channel ticks",
  tooltip = "Tick marks for your channels: spell ID = number of ticks, comma-separated, e.g. 15407=6, 5143=5.",
  mode = "advanced" }, function(v) E.ticks = X.ParseTicks(v) end)
key("rb.cast.empowerStages", { type = "toggle", default = true, label = "Empower stage marks",
  tooltip = "Marks each stage on empowered casts, from the game's own stage timings.", mode = "simple" }, function(v) E.stages = v end)
key("rb.gcd.mode", { type = "select", default = "always", choices = { "always", "instance", "instant" },
  choiceLabels = { always = "Always", instance = "Only in dungeons, raids and arenas", instant = "Hide while casting (instants only)" },
  label = "Global cooldown bar shows", tooltip = "When the global cooldown bar is drawn.", mode = "advanced" }, function(v) E.gcdMode = v end)
key("rb.aura.enabled", { type = "toggle", default = false, label = "Aura stack bar",
  tooltip = "A bar for spec resources that live in an aura (for example a stacking buff). Set the spell below.",
  mode = "simple" }, function(v) cfg.aura.on = v end)
key("rb.aura.spell", { type = "range", default = 0, min = 0, max = 9999999, step = 1, label = "Aura spell ID",
  tooltip = "Spell ID of your aura; its stacks fill the bar.", mode = "simple" }, function(v) E.auraSpell = tonumber(v) or 0 end)
key("rb.aura.max", { type = "range", default = 5, min = 1, max = 30, step = 1, label = "Aura stack bar maximum",
  tooltip = "Stacks for a full bar.", mode = "advanced" }, function(v) E.auraMax = v end)
key("rb.aura.height", { type = "range", default = 6, min = 2, max = 40, step = 1, label = "Aura stack bar height",
  tooltip = "Height of the aura stack bar.", mode = "advanced" }, function(v) cfg.aura.height = v end)
key("rb.collapse", { type = "toggle", default = true, label = "Close up missing bars",
  tooltip = "Bars with nothing to show (no aura, no totem slots, no class resource) take no room; the bars below move up.",
  mode = "advanced" }, function(v) E.collapse = v end)
key("rb.power.thresholds", { type = "toggle", default = false, label = "Colour power by amount",
  tooltip = "Colours the power bar low / middle / high at the points below (done by the game, works in combat).",
  mode = "simple" }, function(v) E.thresholds = v end)
key("rb.power.lowPct", { type = "range", default = 25, min = 1, max = 98, step = 1, label = "Low power below (%)",
  tooltip = "Below this the bar uses the low colour.", mode = "advanced" }, function(v) E.lowPct = v end)
key("rb.power.highPct", { type = "range", default = 80, min = 2, max = 99, step = 1, label = "High power from (%)",
  tooltip = "From this the bar uses the high colour.", mode = "advanced" }, function(v) E.highPct = v end)
for _, c in ipairs({ { "low", "Low power colour" }, { "mid", "Middle power colour" }, { "high", "High power colour" } }) do
  local d = E[c[1] .. "Color"]
  key("rb.power." .. c[1] .. "Color", { type = "color", default = { r = d.r, g = d.g, b = d.b, a = 1 }, label = c[2],
    tooltip = c[2] .. " for the threshold colouring.", mode = "advanced" }, function(v) E[c[1] .. "Color"] = v end)
end
for _, k in ipairs(X.KEYS) do Schema:Register(k, RB.schema[k]) end
for _, k in ipairs(X.KEYS) do RB.schema[k].apply(Schema:Get(k)) end
