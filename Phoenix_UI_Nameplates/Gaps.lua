local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplates, review gaps (2026-10-27):
--  (Class power on the target plate and enemy range fade were already built:
--  np.resource.* and np.range.*; the review probe missed them.)
--  * Line of sight (workaround: there is no line-of-sight API): when the game
--    says "Target not in line of sight" (UI_ERROR_MESSAGE), the target's plate
--    flashes in the accent colour with an "Out of sight" tag for 2 s. Labelled
--    as what it is: the result of a failed cast, not a live check.
local _, ns = ...
local NP = ns.NP
local Schema, Secret, Kernel, Theme = PUI.Schema, PUI.Secret, PUI.Kernel, PUI.Theme
local OWNER = "Nameplates"
local s = NP.settings
local X = { }
NP.Gaps = X
s.los = { enabled = true, seconds = 2 }

-- Line of sight flash -------------------------------------------------------------------------------------
local function flash(f)
  local o = rawget(f, "phxLos")
  if not o then
    o = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
    o:SetAllPoints(f.health)
    o.fill = o:CreateTexture(nil, "OVERLAY")
    o.fill:SetAllPoints()
    o.tag = o:CreateFontString(nil, "OVERLAY")
    o.tag:SetFontObject(PUI.Media:FontObject("small"))
    o.tag:SetPoint("BOTTOM", o, "TOP", 0, 14)
    o.anim = o:CreateAnimationGroup()
    o.fade = o.anim:CreateAnimation("Alpha")
    o.fade:SetFromAlpha(1); o.fade:SetToAlpha(0)
    o.anim:SetScript("OnFinished", function() o:Hide() end)
    rawset(f, "phxLos", o)
  end
  local r, g, b = Theme:Color("accent")
  o.fill:SetColorTexture(r, g, b, 0.45)
  o.tag:SetText("Out of sight"); o.tag:SetTextColor(r, g, b)
  o.fade:SetDuration(s.los.seconds)
  o:SetAlpha(1); o:Show()
  o.anim:Stop(); o.anim:Play()
  return o
end
X.Flash = flash
function X.OnError(_, _, message)
  if not (NP.active and s.los.enabled) then return end
  local los = rawget(_G, "SPELL_FAILED_LINE_OF_SIGHT")
  if type(message) ~= "string" or Secret.IsSecret(message) or not los or message ~= los then return end
  NP.ForTarget(function(f) flash(f) end)
end

X.events = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
X.events:SetScript("OnEvent", function(_, _, a, b) X.OnError(nil, a, b) end)
function X.Track()
  local e = X.events
  e:UnregisterAllEvents()
  if NP.active and s.los.enabled then e:RegisterEvent("UI_ERROR_MESSAGE") end
end
Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then X.Track() end end)
Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then X.Track() end end)

local function key(name, def, set)
  NP.key(name, def, set)
  local d = NP.schema["np." .. name]
  local apply = d.apply
  d.apply = function(v) apply(v); X.Track() end
  Schema:Register("np." .. name, d)
  set(Schema:Get("np." .. name))
end
key("los.enabled", { type = "toggle", default = true, mode = "simple", label = "Flash when out of sight",
  tooltip = "When a cast fails because the target is out of line of sight, its plate flashes with an 'Out of sight' tag (the game has no live line-of-sight check for addons).",
  searchTags = { "line of sight", "los" } }, function(v) s.los.enabled = v end)
key("los.seconds", { type = "range", default = 2, min = 0.5, max = 5, step = 0.5, mode = "advanced", label = "Out of sight flash time",
  tooltip = "How long the flash and tag stay." }, function(v) s.los.seconds = v end)
