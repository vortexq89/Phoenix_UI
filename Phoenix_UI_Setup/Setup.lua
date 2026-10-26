local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- First install (PUI_V2 5.16). Login 1 opens a five-step wizard: language,
-- UI scale (pixel-perfect suggestion), role preset, layout preset and look;
-- Apply writes the choices and reloads once. Login 2 shows a three-card tour.
-- /pui uninstall restores the CVars Phoenix changed and disables every
-- Phoenix addon. The wizard never opens in combat.
local _, ns = ...
local Schema, Slash, Theme, Media, CQ = PUI.Schema, PUI.Slash, PUI.Theme, PUI.Media, PUI.CombatQueue
local P = ns.P
local OWNER = "Setup"

local SU = { step = 1, choices = {} }
ns.SU = SU
PUI.Setup = SU
SU.STEPS = { "language", "scale", "role", "layout", "look" }

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
  return { language = Schema:Get("core.locale"), scale = "keep", role = "dps", layout = "phoenix", look = "phoenix" }
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

-- CVars Phoenix changes are saved once so uninstall can put them back.
function SU.SetCVar(name, value)
  local st = SU.State()
  local saved = {}
  for k, v in pairs(st.cvars or {}) do saved[k] = v end
  if saved[name] == nil then saved[name] = C_CVar.GetCVar(name) or "" end
  saveState({ cvars = saved })
  C_CVar.SetCVar(name, value)
end

function SU.ApplyScale(choice)
  if choice ~= "pixel" then return false end
  SU.SetCVar("useUiScale", "1")
  SU.SetCVar("uiScale", tostring(SU.PixelScale()))
  return true
end

function SU.ApplyChoices(c)
  if c.language then Schema:Set("core.locale", c.language) end
  SU.ApplyScale(c.scale)
  SU.ApplyRole(c.role)
  SU.ApplyLayout(c.layout)
  SU.ApplyLook(c.look)
  saveState({ wizardDone = true })
end

-- Wizard UI ------------------------------------------------------------------------
local OPTIONS = {
  language = function() return PUI.Locale.CHOICES end,
  scale = function() return { "keep", "pixel" } end,
  role = function() return P.ROLE_ORDER end,
  layout = function() return P.LAYOUT_ORDER end,
  look = function() return P.LOOK_ORDER end,
}
SU.OPTIONS = OPTIONS
local TITLES = { language = "Language", scale = "UI scale", role = "Role", layout = "Layout", look = "Look" }

function SU.Label(step, value)
  if step == "scale" then return value == "pixel" and ("Pixel perfect (" .. SU.PixelScale() .. ")") or "Keep my scale" end
  if step == "role" then return P.ROLE_LABELS[value] end
  if step == "layout" then return P.LAYOUTS[value].label end
  if step == "look" then return P.LOOKS[value].label end
  return value == "auto" and "Same as the game" or value
end

function SU.Cycle(step, dir)
  local list = OPTIONS[step]()
  local cur = SU.choices[step]
  local idx = 1
  for i, v in ipairs(list) do if v == cur then idx = i end end
  idx = (idx - 1 + (dir or 1)) % #list + 1
  SU.choices[step] = list[idx]
  SU.Render()
end

local function button(parent, text, w)
  local b = PUI:CreateFrame("Button", nil, parent, "UIPanelButtonTemplate", OWNER)
  b:SetSize(w or 90, 22)
  b:SetText(text)
  return b
end

local function wizard()
  local f = SU.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_SetupWizard", UIParent, nil, OWNER)
  f:SetSize(420, 220)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent")
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(Media:FontObject("header"))
  f.title:SetPoint("TOP", 0, -14)
  f.value = f:CreateFontString(nil, "OVERLAY")
  f.value:SetFontObject(Media:FontObject("body"))
  f.value:SetPoint("CENTER", 0, 10)
  f.prev = button(f, "<", 30); f.prev:SetPoint("RIGHT", f.value, "LEFT", -20, 0)
  f.prev:SetScript("OnClick", function() SU.Cycle(SU.STEPS[SU.step], -1) end)
  f.nextOpt = button(f, ">", 30); f.nextOpt:SetPoint("LEFT", f.value, "RIGHT", 20, 0)
  f.nextOpt:SetScript("OnClick", function() SU.Cycle(SU.STEPS[SU.step], 1) end)
  f.back = button(f, "Back"); f.back:SetPoint("BOTTOMLEFT", 14, 14)
  f.back:SetScript("OnClick", function() SU.Go(-1) end)
  f.go = button(f, "Next"); f.go:SetPoint("BOTTOMRIGHT", -14, 14)
  f.go:SetScript("OnClick", function() SU.Go(1) end)
  f.skip = button(f, "Skip"); f.skip:SetPoint("BOTTOM", 0, 14)
  f.skip:SetScript("OnClick", function() saveState({ wizardDone = true }); f:Hide() end)
  SU.frame = f
  return f
end

function SU.Render()
  local f = SU.frame
  if not f then return end
  local step = SU.STEPS[SU.step]
  f.title:SetText(string.format("Phoenix UI setup  %d/%d  %s", SU.step, #SU.STEPS, TITLES[step]))
  f.value:SetText(SU.Label(step, SU.choices[step]))
  f.back:SetEnabled(SU.step > 1)
  f.go:SetText(SU.step == #SU.STEPS and "Apply" or "Next")
end

function SU.Go(dir)
  if dir > 0 and SU.step == #SU.STEPS then
    SU.ApplyChoices(SU.choices)
    if SU.frame then SU.frame:Hide() end
    ReloadUI()
    return
  end
  SU.step = math.max(1, math.min(#SU.STEPS, SU.step + dir))
  SU.Render()
end

function SU.OpenWizard()
  CQ.Defer("setup.wizard", function()
    SU.step = 1
    SU.choices = SU.Defaults()
    wizard():Show()
    SU.Render()
  end)
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
