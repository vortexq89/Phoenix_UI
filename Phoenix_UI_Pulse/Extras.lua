local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Pulse, deferred batch C:
--  * next-three HUD: a small list of the next abilities from the game's sorted
--    timeline (names and times go straight to widgets, so secret values are fine).
--  * per-boss options: lines "boss name or encounter ID: off | bars=N | hud=off".
--  * Blizzard timeline view: with Phoenix bars showing, the game's own timeline
--    can be set to its empty view (EncounterTimelineViewType.None, the mode the
--    API documents for addons that draw the timeline themselves); restored when off.
--  * BigWigs bar style: registers a "Phoenix" style through BigWigsAPI's public
--    RegisterBarStyle, so BigWigs bars can match Pulse's look.
-- Private-aura sounds: see Sounds.lua (C_UnitAuras.AddAuraSound, 12.1.0).
local _, ns = ...
local Schema, Kernel, Ticker = PUI.Schema, PUI.Kernel, PUI.Ticker
local PL = PUI.Pulse or ns.PL
local OWNER = "Pulse"
local s = { nextHud = false, nextCount = 3, bossRules = {}, hideBlizzard = false, bigwigsStyle = true }
local X = { boss = nil }
PL.Extras = X
X.settings = s

-- Per-boss rules -------------------------------------------------------------------------------
-- ParseRules(list) -> { [lower-case name or id string] = { off, bars, hud } } (pure)
function X.ParseRules(list)
  local out = {}
  for _, line in ipairs(list or {}) do
    local who, rest = tostring(line):match("^%s*([^:]+):%s*(.-)%s*$")
    if who then
      local r = {}
      for word in rest:gmatch("[^%s,]+") do
        local k, v = word:match("^(%a+)=(%S+)$")
        if word == "off" then r.off = true
        elseif k == "bars" and tonumber(v) then r.bars = math.max(1, math.min(16, tonumber(v)))
        elseif k == "hud" then r.hud = v ~= "off"
        end
      end
      out[(who:gsub("%s+$", "")):lower()] = r
    end
  end
  return out
end
function X.Rule()
  local b = X.boss
  if not b then return nil end
  local rules = X.ParseRules(s.bossRules)
  return rules[tostring(b.id)] or (b.name and rules[tostring(b.name):lower()])
end
function X.OnEncounterStart(_, _, id, name) X.boss = { id = id, name = name }; X.Apply() end
function X.OnEncounterEnd() X.boss = nil; X.Apply() end

local allowed = PL.TimelineAllowed
function PL.TimelineAllowed()
  local r = X.Rule()
  if r and r.off then return false end
  return allowed()
end

-- Next-three HUD -------------------------------------------------------------------------------
function X.HudWanted()
  local r = X.Rule()
  if r and r.hud ~= nil then return r.hud and PL.TimelineAllowed() end
  return s.nextHud and PL.TimelineAllowed()
end
function X.BuildHud()
  if X.hud then return X.hud end
  local f = PUI:CreateFrame("Frame", "PhoenixUIPulseNext", UIParent, nil, OWNER)
  f:SetSize(200, 64)
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.75)
  f.rows = {}
  for i = 1, 5 do
    local r = CreateFrame("Frame", nil, f); r:SetSize(192, 18); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 19)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT")
    r.name = r:CreateFontString(nil, "OVERLAY"); r.name:SetFontObject(PUI.Media:FontObject("small")); r.name:SetPoint("LEFT", 20, 0); r.name:SetWidth(130); r.name:SetJustifyH("LEFT")
    r.time = r:CreateFontString(nil, "OVERLAY"); r.time:SetFontObject(PUI.Media:FontObject("small")); r.time:SetPoint("RIGHT")
    f.rows[i] = r
  end
  X.hud = f
  PUI.Layout:Place(f, "pulse.next")
  return f
end
function X.PaintHud()
  if not (PL.active and X.HudWanted()) then
    if X.hud then X.hud:Hide() end
    Ticker:Unregister("pulse.next")
    return 0
  end
  local f = X.BuildHud()
  local list = C_EncounterTimeline.GetSortedEventList(s.nextCount, 600, true, true) or {}
  local n = math.min(#list, s.nextCount)
  for i, r in ipairs(f.rows) do
    local id = list[i]
    local info = i <= n and id and C_EncounterTimeline.GetEventInfo(id)
    if info then
      r.icon:SetTexture(info.iconFileID)
      r.name:SetText(info.spellName)
      r.time:SetFormattedText("%.0f", C_EncounterTimeline.GetEventTimeRemaining(id))
      r:Show()
    else r:Hide() end
  end
  f:SetHeight(8 + math.max(1, n) * 19)
  f:SetShown(n > 0)
  return n
end
-- per-boss bar limit: Pulse's own style honours bars=N while the rule's boss is engaged
function X.ApplyLimit()
  local st, r = PL.style, X.Rule()
  if r and r.bars then
    if X.savedMax == nil then X.savedMax = st.max end
    st.max = r.bars
  elseif X.savedMax ~= nil then
    st.max = X.savedMax
    X.savedMax = nil
  end
  if PL.group then PL.group:Restyle() end
end
function X.Apply()
  X.ApplyLimit()
  if PL.active and X.HudWanted() and X.boss then Ticker:Register("pulse.next", 0.25, X.PaintHud, OWNER) else Ticker:Unregister("pulse.next") end
  X.PaintHud()
  X.ApplyView()
  if PL.active then PL.Resync() end
end

-- Blizzard timeline view ----------------------------------------------------------------------
local VIEW_NONE = (Enum.EncounterTimelineViewType and Enum.EncounterTimelineViewType.None) or 0
function X.ApplyView()
  local want = PL.active and s.hideBlizzard and PL.TimelineAllowed()
  if want then
    local cur = C_EncounterTimeline.GetViewType()
    if cur ~= VIEW_NONE then X.savedView = cur; C_EncounterTimeline.SetViewType(VIEW_NONE) end
  elseif X.savedView ~= nil then
    C_EncounterTimeline.SetViewType(X.savedView)
    X.savedView = nil
  end
end

-- BigWigs bar style (public BigWigsAPI) --------------------------------------------------------
X.STYLE_KEY = "PhoenixUI"
function X.BigWigsStyle()
  local st = PL.style or {}
  return {
    apiVersion = 1, version = 1,
    GetSpacing = function() return st.gap or 3 end,
    ApplyStyle = function(bar)
      bar:SetHeight(st.height or 20)
      local edge = rawget(bar, "phoenixEdge")
      if not edge then
        edge = bar:CreateTexture(nil, "OVERLAY")
        edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
        rawset(bar, "phoenixEdge", edge)
      end
      edge:SetColorTexture(0.91, 0.64, 0.24, 1)
      edge:Show()
    end,
    BarStopped = function(bar) local edge = rawget(bar, "phoenixEdge"); if edge then edge:Hide() end end,
    GetStyleName = function() return "Phoenix UI" end,
  }
end
function X.RegisterBigWigs()
  if X.bigwigsDone or not s.bigwigsStyle then return false end
  local api = rawget(_G, "BigWigsAPI")
  if type(api) ~= "table" or type(api.RegisterBarStyle) ~= "function" then return false end
  securecallfunction(api.RegisterBarStyle, api, X.STYLE_KEY, X.BigWigsStyle())
  X.bigwigsDone = true
  return true
end
Kernel:On("LOGIN", X.RegisterBigWigs)

Kernel:On("MODULE_ENABLED", function(name)
  if name ~= OWNER or not PL.module then return end
  PL.module:RegisterEvent("ENCOUNTER_START", X.OnEncounterStart)
  PL.module:RegisterEvent("ENCOUNTER_END", X.OnEncounterEnd)
  X.Apply()
end)
Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then X.boss = nil; X.Apply() end end)

PUI.Layout:RegisterElement("pulse.next", { label = "Pulse next abilities", owner = OWNER, size = { 200, 64 }, default = { point = "CENTER", x = 320, y = 220 } })
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; if name == "bigwigsStyle" then X.RegisterBigWigs() else X.Apply() end end
  PL.schema["pulse." .. name] = def
  Schema:Register("pulse." .. name, def)
  s[name] = Schema:Get("pulse." .. name)
end
key("nextHud", { type = "toggle", default = false, label = "Next abilities list", mode = "simple",
  tooltip = "A small list of the next boss abilities and their times during a boss fight. Move it in Studio." })
key("nextCount", { type = "range", default = 3, min = 1, max = 5, step = 1, label = "Abilities listed", tooltip = "How many upcoming abilities the list shows." })
key("bossRules", { type = "list", default = {}, label = "Per-boss options",
  tooltip = "One line per boss, by name or encounter ID: \"off\" hides Pulse bars, \"bars=4\" limits bars, \"hud=on\" or \"hud=off\" for the next-abilities list. Example: Dimensius: bars=4 hud=on" })
key("hideBlizzard", { type = "toggle", default = false, label = "Hide Blizzard's timeline",
  tooltip = "While Pulse shows boss bars, sets the game's own timeline to its empty view. Your previous view comes back when you turn this off." })
key("bigwigsStyle", { type = "toggle", default = true, label = "Phoenix style for BigWigs bars",
  tooltip = "With BigWigs loaded, adds a \"Phoenix UI\" bar style you can pick in BigWigs' bar options." })

