local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- AFK screen: when you go away (the game's AFK flag), a themed screen fades
-- in over the game: your character model turning slowly, name, level,
-- class, item level, gold, Mythic+ rating, guild and how long you have been
-- away. Any movement, combat or coming back removes it; a click does too.
-- Phoenix's own design. The model turn and the clock run on one Ticker
-- entry only while the screen is up. Never shown in combat.
local Schema = PUI.Schema
local OWNER = "AFKScreen"
local AFK = { active = false, shown = false }
PUI.AFKScreen = AFK
local s = { model = true, spin = true, stats = true, dim = 0.75 }
AFK.settings = s

local function build()
  local f = AFK.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_AFKScreen", UIParent, nil, OWNER)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function() AFK.Hide() end)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.band = f:CreateTexture(nil, "BORDER")
  f.band:SetPoint("BOTTOMLEFT"); f.band:SetPoint("BOTTOMRIGHT"); f.band:SetHeight(150)
  f.model = PUI:CreateFrame("PlayerModel", nil, f, nil, OWNER)
  f.model:SetSize(420, 560)
  f.model:SetPoint("BOTTOMRIGHT", -80, 40)
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(PUI.Media:FontObject("header"))
  f.title:SetPoint("BOTTOMLEFT", 60, 100)
  f.info = f:CreateFontString(nil, "OVERLAY")
  f.info:SetFontObject(PUI.Media:FontObject("body"))
  f.info:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
  f.info:SetJustifyH("LEFT")
  f.timer = f:CreateFontString(nil, "OVERLAY")
  f.timer:SetFontObject(PUI.Media:FontObject("number"))
  f.timer:SetPoint("BOTTOMLEFT", 60, 30)
  f:Hide()
  AFK.frame = f
  return f
end

-- Text lines for the stats block (plain values; a secret value would only
-- reach a font string through Secret.ToText).
function AFK.Lines()
  local Secret = PUI.Secret
  local name = Secret.ToText(UnitName("player"))
  local _, className = UnitClass("player")
  local level = Secret.ToText(UnitLevel("player"))
  local _, ilvl = GetAverageItemLevel()
  local gold = math.floor((GetMoney() or 0) / 10000)
  local lines = { string.format("Level %s %s", level, className or "") }
  lines[#lines + 1] = string.format("Item level %.1f   Gold %s", ilvl or 0, PUI.Format.Number(gold))
  local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
  if type(summary) == "table" and type(summary.currentSeasonScore) == "number" and summary.currentSeasonScore > 0 then
    lines[#lines + 1] = string.format("Mythic+ rating %d", summary.currentSeasonScore)
  end
  local guild = GetGuildInfo("player")
  if guild then lines[#lines + 1] = "<" .. Secret.ToText(guild) .. ">" end
  return name, table.concat(lines, "\n")
end

function AFK.Clock(sec)
  sec = math.max(0, math.floor(sec))
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function AFK.Tick()
  local f = AFK.frame
  if not (f and AFK.shown) then return end
  f.timer:SetText("Away " .. AFK.Clock(GetTime() - AFK.since))
  if s.spin and s.model then AFK.facing = (AFK.facing + 0.01) % (2 * math.pi); f.model:SetFacing(AFK.facing) end
end

function AFK.Look()
  local f = build()
  local r, g, b = PUI.Theme:Color("surface.0")
  f.bg:SetColorTexture(r or 0, g or 0, b or 0, s.dim)
  local ar, ag, ab = PUI.Theme:Color("accent")
  f.band:SetColorTexture(ar or 1, ag or 0.5, ab or 0, 0.12)
  f.model:SetShown(s.model)
  f.info:SetShown(s.stats)
end

function AFK.Show()
  if AFK.shown or InCombatLockdown() then return end
  local f = build()
  AFK.Look()
  local name, info = AFK.Lines()
  f.title:SetText(name)
  f.info:SetText(info)
  if s.model then f.model:SetUnit("player"); AFK.facing = 0 end
  AFK.since, AFK.shown = GetTime(), true
  f:Show()
  PUI.Ticker:Register("afk.screen", 0.05, AFK.Tick, OWNER)
  AFK.Tick()
end

function AFK.Hide()
  if not AFK.shown then return end
  AFK.shown = false
  if AFK.frame then AFK.frame:Hide() end
  if PUI.Ticker:IsRegistered("afk.screen") then PUI.Ticker:Unregister("afk.screen") end
end

function AFK.Check()
  if AFK.active and UnitIsAFK("player") == true then AFK.Show() else AFK.Hide() end
end

local function onEnable(mod)
  AFK.active = true
  mod:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", AFK.Check, "player")
  mod:RegisterEvent("PLAYER_STARTED_MOVING", AFK.Hide)
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", AFK.Hide)
end
local function onDisable() AFK.active = false; AFK.Hide() end

local schema = {}
AFK.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v; if AFK.frame then AFK.Look() end end
  schema["afk." .. name] = def
end
key("model", { type = "toggle", default = true, label = "Character model", tooltip = "Shows your character on the AFK screen.", mode = "simple" })
key("spin", { type = "toggle", default = true, label = "Turn the model", tooltip = "Your character turns slowly while you are away.", mode = "advanced" })
key("stats", { type = "toggle", default = true, label = "Character details", tooltip = "Level, class, item level, gold, Mythic+ rating and guild on the AFK screen.", mode = "simple" })
key("dim", { type = "range", default = 0.75, min = 0.3, max = 1, step = 0.05, label = "Screen darkness", tooltip = "How dark the AFK screen covers the game.", mode = "simple" })

AFK.module = PUI:RegisterModule(OWNER, {
  label = "AFK screen",
  tooltip = "A themed screen with your character, details and an away timer while you are AFK. Moving, combat or a click removes it.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
PUI.Slash:Register("afktest", function()
  if not AFK.active then PUI.Slash.Print("turn on the AFK screen first") return end
  if AFK.shown then AFK.Hide() else AFK.Show() end
end, "show or hide the AFK screen")
