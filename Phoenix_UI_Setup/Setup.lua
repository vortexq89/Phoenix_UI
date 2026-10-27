local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- First install (PUI_V2 5.16). Login 1 opens a six-step wizard (Wizard.lua,
-- mockups 05-11): language, UI scale, role preset, layout preset, look and
-- Blizzard window skins (on or off, with a preview);
-- Finish writes the choices live (no reload). Login 2 shows a three-card tour.
-- /pui uninstall restores the CVars Phoenix changed and disables every
-- Phoenix addon. The wizard never opens in combat.
local _, ns = ...
local Schema, Slash, Theme, Media, CQ = PUI.Schema, PUI.Slash, PUI.Theme, PUI.Media, PUI.CombatQueue
local P = ns.P
local OWNER = "Setup"

local SU = { step = 1, choices = {} }
ns.SU = SU
PUI.Setup = SU
SU.STEPS = { "language", "scale", "role", "layout", "look", "skins" }

-- State ------------------------------------------------------------------------
function SU.State() return Schema:Get("setup.state") end
local function saveState(patch)
  local st = {}
  for k, v in pairs(SU.State()) do st[k] = v end
  for k, v in pairs(patch) do st[k] = v end
  Schema:Set("setup.state", st)
end

-- 768 / physical height is the scale where one UI pixel is one screen pixel.
function SU.PixelScale()
  local _, h = GetPhysicalScreenSize()
  if not h or h <= 0 then return 1 end
  local v = 768 / h
  if v < 0.64 then v = 0.64 elseif v > 1 then v = 1 end
  return math.floor(v * 10000 + 0.5) / 10000
end

function SU.Defaults()
  return { language = Schema:Get("core.locale"), scale = "keep", role = SU.DetectRole(), layout = "classic",
    accent = Schema:Get("theme.accent"), panel = Schema:Get("theme.panel"), skins = true }
end

-- Role of the current spec ("HEALER"/"TANK"/"DAMAGER") -> preset id.
function SU.DetectRole()
  local api = C_SpecializationInfo
  local spec = api and api.GetSpecialization and api.GetSpecialization()
  if not (spec and api.GetSpecializationInfo) then return "dps" end
  local _, _, _, _, role = api.GetSpecializationInfo(spec)
  if role == "HEALER" then return "healer" elseif role == "TANK" then return "tank" end
  return "dps"
end

-- Apply ----------------------------------------------------------------------------
local function setIfKnown(key, value)
  if Schema:Def(key) then Schema:Set(key, value) return true end
  return false
end

function SU.ApplyRole(role)
  local on = {}
  for _, m in ipairs(P.ROLES[role] or {}) do on[m] = true end
  local changed = 0
  for _, m in ipairs(P.MANAGED) do
    if setIfKnown("module." .. m, on[m] == true) then changed = changed + 1 end
  end
  return changed
end

function SU.ApplyLayout(id)
  local preset = P.LAYOUTS[id]
  if not preset then return false end
  local positions = {}
  for k, v in pairs(preset.positions) do positions[k] = { point = v.point, x = v.x, y = v.y } end
  Schema:Set("layout.positions", positions)
  return true
end

function SU.ApplyLook(id)
  local look = P.LOOKS[id]
  if not look then return false end
  Schema:Set("theme.accent", look.accent)
  if look.skins == false then setIfKnown("module.Skins", false) end
  return true
end

-- Skins step: the player chooses Phoenix skins for Blizzard windows or the
-- stock Blizzard look; live through the module switch, no reload.
function SU.ApplySkins(on)
  return setIfKnown("module.Skins", on and true or false)
end

-- CVars Phoenix changes are saved once so uninstall can put them back.
function SU.SetCVar(name, value)
  local st = SU.State()
  local saved = {}
  for k, v in pairs(st.cvars or {}) do saved[k] = v end
  if saved[name] == nil then saved[name] = C_CVar.GetCVar(name) or "" end
  saveState({ cvars = saved })
  C_CVar.SetCVar(name, value)
end

-- choice: "keep", "pixel" or a number (the wizard's cards and fine tune).
function SU.ClampScale(v)
  v = math.max(0.64, math.min(1.15, v))
  return math.floor(v * 100 + 0.5) / 100
end

function SU.ApplyScale(choice)
  local value
  if choice == "pixel" then value = SU.PixelScale()
  elseif type(choice) == "number" then value = SU.ClampScale(choice)
  else return false end
  SU.SetCVar("useUiScale", "1")
  SU.SetCVar("uiScale", tostring(value))
  return true
end

function SU.ApplyChoices(c)
  if c.language then Schema:Set("core.locale", c.language) end
  SU.ApplyScale(c.scale)
  SU.ApplyRole(c.role)
  SU.ApplyLayout(c.layout)
  if c.look then SU.ApplyLook(c.look) end
  if c.accent then Schema:Set("theme.accent", c.accent) end
  if c.panel then Schema:Set("theme.panel", c.panel) end
  if c.specProfile ~= nil then SU.ApplySpecProfiles(c.specProfile) end
  if c.skins ~= nil then SU.ApplySkins(c.skins) end
  saveState({ wizardDone = true })
end

-- Spec auto-switch from the wizard: each specialization gets a copy of the
-- current profile named after it (existing profiles are reused, never
-- overwritten) and the switch turns on. Off leaves the map and turns it off.
function SU.ApplySpecProfiles(on)
  local SP, Profiles, DB = PUI.SpecProfiles, PUI.Profiles, PUI.DB
  if on then
    local current = DB.sv.chars[DB:CharKey()]
    local classID = select(3, UnitClass("player"))
    local n = classID and C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    for i = 1, math.min(n, SP.MAX_SPECS) do
      local specName = select(2, C_SpecializationInfo.GetSpecializationInfo(i))
      local name = current .. " - " .. (type(specName) == "string" and specName or ("Spec " .. i))
      if not Profiles:Exists(name) then Profiles:Create(name, current) end
      if not SP:Map(i) then SP.CharRec(true)[i] = name end
    end
  end
  Schema:Set("core.specProfile", on and true or false)
end

-- Wizard UI lives in Wizard.lua (SU.OpenWizard, SU.Render, SU.Go, SU.Cycle).
SU.saveState = saveState

local function button(parent, text, w)
  local b = PUI:CreateFrame("Button", nil, parent, "UIPanelButtonTemplate", OWNER)
  b:SetSize(w or 90, 22)
  b:SetText(text)
  return b
end

-- Tour (login 2) ----------------------------------------------------------------------
function SU.OpenTour()
  CQ.Defer("setup.tour", function()
    local f = SU.tour
    if not f then
      f = PUI:CreateFrame("Frame", "PhoenixUI_SetupTour", UIParent, nil, OWNER)
      f:SetSize(3 * 200 + 40, 150)
      f:SetPoint("CENTER", 0, 120)
      f:SetFrameStrata("DIALOG")
      f:EnableMouse(true)
      Theme:Backdrop(f, "surface.1")
      Theme:Outline(f, "accent")
      for i, card in ipairs(P.TOUR) do
        local t = f:CreateFontString(nil, "OVERLAY")
        t:SetFontObject(Media:FontObject("header"))
        t:SetPoint("TOPLEFT", 20 + (i - 1) * 200, -14)
        t:SetText(card.title)
        local b = f:CreateFontString(nil, "OVERLAY")
        b:SetFontObject(Media:FontObject("small"))
        b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
        b:SetWidth(180)
        b:SetJustifyH("LEFT")
        b:SetText(card.body)
      end
      local ok = button(f, "Got it"); ok:SetPoint("BOTTOM", 0, 12)
      ok:SetScript("OnClick", function() f:Hide() end)
      SU.tour = f
    end
    saveState({ tourDone = true })
    f:Show()
  end)
end

-- Uninstall --------------------------------------------------------------------------
function SU.PhoenixAddOns()
  local list = {}
  for i = 1, C_AddOns.GetNumAddOns() do
    local name = C_AddOns.GetAddOnInfo(i)
    if type(name) == "string" and name:find("^Phoenix_UI") then list[#list + 1] = name end
  end
  return list
end

function SU.Uninstall(confirm)
  if confirm ~= "confirm" then
    Slash.Print("This restores the game settings Phoenix changed and disables every Phoenix addon. Type /pui uninstall confirm")
    return false
  end
  -- Modules that changed game settings put them back when they turn off.
  if Schema:Def("module.Flow") then Schema:Set("module.Flow", false) end
  for name, value in pairs(SU.State().cvars or {}) do C_CVar.SetCVar(name, value) end
  saveState({ cvars = {} })
  for _, name in ipairs(SU.PhoenixAddOns()) do C_AddOns.DisableAddOn(name) end
  ReloadUI()
  return true
end

Slash:Register("setup", function() SU.OpenWizard() end, "open the first-install wizard")
Slash:Register("tour", function() SU.OpenTour() end, "show the three-card tour")
Slash:Register("uninstall", function(rest) SU.Uninstall(rest) end, "restore game settings and disable Phoenix")

Schema:Register("setup.state", {
  type = "layout", default = { wizardDone = false, tourDone = false, cvars = {} }, owner = OWNER, mode = "advanced",
  label = "Setup state", tooltip = "First-install progress and the game settings to restore on uninstall.",
  apply = function() end,
})

-- Login 1 -> wizard, login 2 -> tour.
PUI.Kernel:On("LOGIN", function()
  local st = SU.State()
  if not st.wizardDone then SU.OpenWizard()
  elseif not st.tourDone then SU.OpenTour() end
end)
