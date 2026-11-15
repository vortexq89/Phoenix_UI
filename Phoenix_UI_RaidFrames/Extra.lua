local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Extra frames (review gaps 2026-10-27):
--  * Pets: your pet and party pets as small frames (pet, partypet1..4), each
--    shown by a state driver while the pet exists.
--  * Party targets: what each party member targets (party1target..4), shown
--    while it exists; their content is refreshed by a 0.3 s Ticker job that
--    exists only while this is on (target-of units fire no unit events).
--  * Extra (role) frames: a third secure group header filtered by assigned
--    role (tanks or healers), so they also get a block of their own.
--  * Grid Mode lives in RaidFrames.lua (RF.Spacing).
-- Every frame is a secure unit button built and placed out of combat
-- (CombatQueue); Studio moves each block (rf.pets, rf.targets, rf.extra).
local _, ns = ...
local RF = ns.RF or PUI.RaidFrames
local Layout, CQ, Schema, Ticker = PUI.Layout, PUI.CombatQueue, PUI.Schema, PUI.Ticker
local OWNER = "RaidFrames"
local s = RF.settings
local X = { sets = { pets = {}, targets = {} }, header = nil }
RF.Extra = X
X.UNITS = { pets = { "pet", "partypet1", "partypet2", "partypet3", "partypet4" }, targets = { "party1target", "party2target", "party3target", "party4target" } }
X.SIZE = { pets = { 70, 24 }, targets = { 80, 26 }, extra = { 100, 40 } }

Layout:RegisterElement("rf.pets", { label = "Pet frames", owner = OWNER, size = { 70, 5 * 26 }, default = { point = "TOPLEFT", x = 140, y = -213 } })
Layout:RegisterElement("rf.targets", { label = "Party target frames", owner = OWNER, size = { 80, 4 * 28 }, default = { point = "TOPLEFT", x = 215, y = -213 } })
Layout:RegisterElement("rf.extra", { label = "Extra frames (tanks or healers)", owner = OWNER, size = { 100, 2 * 42 }, default = { point = "TOPLEFT", x = 27, y = -480 } })

function X.Visibility(unit) return "[@" .. unit .. ",exists] show; hide" end
function X.Wanted(kind)
  if not RF.active then return false end
  if kind == "pets" then return s.pets end
  if kind == "targets" then return s.partyTargets end
  return s.extraRole ~= "off"
end

local function anchorFor(kind)
  local a = rawget(X, "anchors") or {}
  X.anchors = a
  if not a[kind] then
    a[kind] = PUI:CreateFrame("Frame", "PhoenixUI_RF_" .. kind, UIParent, nil, OWNER)
    a[kind]:SetSize(X.SIZE[kind][1], X.SIZE[kind][2])
  end
  return a[kind]
end

local function build(kind, i)
  local list = X.sets[kind]
  if list[i] then return list[i] end
  local b = PUI:CreateFrame("Button", "PhoenixUI_RF_" .. kind .. i, anchorFor(kind), "SecureUnitButtonTemplate,PingableUnitFrameTemplate", OWNER)
  b:SetAttribute("*type1", "target")
  b:SetAttribute("*type2", "togglemenu")
  b:SetAttribute("unit", X.UNITS[kind][i])
  list[i] = b
  RF.InitButton(b)
  return b
end

function X.ApplySet(kind)
  local want = X.Wanted(kind)
  local w, h = X.SIZE[kind][1], X.SIZE[kind][2]
  local sp = RF.Spacing({ spacing = 2, groupSpacing = 6 })
  for i, unit in ipairs(X.UNITS[kind]) do
    if want then
      local b = build(kind, i)
      b:SetSize(w, h)
      local o = RF.byButton[b]
      if o then RF.Elements.Layout(o, s, w, h) end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", anchorFor(kind), "TOPLEFT", 0, -(i - 1) * (h + sp))
      RegisterStateDriver(b, "visibility", X.Visibility(unit))
    elseif X.sets[kind][i] then
      UnregisterStateDriver(X.sets[kind][i], "visibility")
      X.sets[kind][i]:Hide()
    end
  end
  if want then Layout:Place(anchorFor(kind), "rf." .. kind) end
end

-- Extra header: the party header's own secure init, filtered by role.
function X.ApplyHeader()
  local want = X.Wanted("extra")
  local h = X.header
  if want and not h then
    h = PUI:CreateFrame("Frame", "PhoenixUI_RF_extra", UIParent, "SecureGroupHeaderTemplate", OWNER)
    h.PhoenixInit = function(_, childName) RF.InitButton(_G[childName]) end
    h:SetAttribute("template", "SecureUnitButtonTemplate,PingableUnitFrameTemplate")
    h:SetAttribute("initialConfigFunction", RF.INIT)
    X.header = h
  end
  if not h then return end
  if want then
    local sp = RF.Spacing({ spacing = 2, groupSpacing = 6 })
    h:SetAttribute("phx-width", X.SIZE.extra[1]); h:SetAttribute("phx-height", X.SIZE.extra[2])
    h:SetAttribute("showRaid", true); h:SetAttribute("showParty", true); h:SetAttribute("showPlayer", true)
    h:SetAttribute("groupFilter", s.extraRole == "healer" and "HEALER" or "TANK")
    h:SetAttribute("point", "TOP"); h:SetAttribute("yOffset", -sp)
    h:SetAttribute("unitsPerColumn", 5); h:SetAttribute("maxColumns", 1)
    Layout:Place(h, "rf.extra")
    RegisterStateDriver(h, "visibility", "[group] show; hide")
  else
    UnregisterStateDriver(h, "visibility")
    h:Hide()
  end
end

-- Party targets: refresh their content while on.
function X.PollTargets()
  for _, b in ipairs(X.sets.targets) do
    local o = RF.byButton[b]
    if o and o.unit and b:IsShown() then RF.SetUnit(o, o.unit) end
  end
end

function X.Apply()
  CQ.Defer("rf.extra", function()
    X.ApplySet("pets"); X.ApplySet("targets"); X.ApplyHeader()
  end)
  if X.Wanted("targets") then Ticker:Register("rf.partyTargets", 0.3, X.PollTargets, OWNER) else Ticker:Unregister("rf.partyTargets") end
end

local applyLayout = RF.ApplyLayout
function RF.ApplyLayout()
  applyLayout()
  X.Apply()
end
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then X.Apply() end end)

local function reg(name, def, set)
  RF.key(name, def, set, "layout")
  Schema:Register("rf." .. name, RF.schema["rf." .. name])
  set(Schema:Get("rf." .. name))
end
reg("pets", { type = "toggle", default = false, mode = "simple", label = "Pet frames", searchTags = { "pets", "extra frames" },
  tooltip = "Small frames for your pet and your party's pets, in their own block you can move in Studio." }, function(v) s.pets = v end)
reg("partyTargets", { type = "toggle", default = false, mode = "simple", label = "Party target frames", searchTags = { "targets", "extra frames" },
  tooltip = "What each party member is targeting, as small frames beside the party." }, function(v) s.partyTargets = v end)
reg("extraRole", { type = "select", default = "off", choices = { "off", "tank", "healer" }, mode = "advanced", label = "Extra frames",
  choiceLabels = { off = "Off", tank = "Tanks", healer = "Healers" }, searchTags = { "tanks", "main tank", "extra frames" },
  tooltip = "A block of extra frames for every tank (or healer) in the group, in addition to the normal frames." }, function(v) s.extraRole = v end)
reg("gridMode", { type = "toggle", default = false, mode = "advanced", label = "Grid Mode", searchTags = { "grid", "compact", "outline" },
  tooltip = "Frames touch and share one thin outline (no gaps), like a compact grid." }, function(v) s.gridMode = v end)
