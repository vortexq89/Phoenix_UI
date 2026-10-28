local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Blizzard elements in Studio (plan 4.14, 4.17, MoveAny parity done the Phoenix way).
-- About 130 Blizzard HUD elements appear in Studio as movers once the user
-- turns "Blizzard elements" on (off on first install). Frames that Blizzard's
-- Edit Mode owns are never moved by Phoenix: Studio shows an Edit Mode badge
-- and an "Open in Edit Mode" button (a user click; Edit Mode is never switched
-- on from code). Every other element is touched only after the user changes it,
-- through the FrameLedger (prior parent, points, scale, alpha, shown, mouse are
-- recorded and fully restored when the change is reset or the feature is off).
-- Nothing is reparented, no Blizzard method is replaced, no field is written on
-- a Blizzard frame; re-asserting after Blizzard moves a frame uses a secure
-- post-hook and the CombatQueue for protected frames.
local Movers = { hooked = {}, busy = {}, applied = {} }
PUI.Movers = Movers
local Schema, Layout, CQ, FL = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.FrameLedger
local OWNER = "Studio"

-- { frame global, label, category, editModeOwned, size }
-- categories: frames, bars, auras, hud, alerts, group, minimap, misc
local E, B = true, false
local CATALOG = {
  -- Unit frames and their parts
  { "PlayerFrame", "Player frame", "frames", E, { 232, 100 } },
  { "TargetFrame", "Target frame", "frames", E, { 232, 100 } },
  { "FocusFrame", "Focus frame", "frames", E, { 232, 100 } },
  { "PetFrame", "Pet frame", "frames", E, { 120, 50 } },
  { "TargetFrameToT", "Target of target", "frames", B, { 100, 40 } },
  { "FocusFrameToT", "Focus target of target", "frames", B, { 100, 40 } },
  { "PlayerCastingBarFrame", "Player cast bar", "frames", E, { 208, 22 } },
  { "TargetFrameSpellBar", "Target cast bar", "frames", B, { 150, 16 } },
  { "FocusFrameSpellBar", "Focus cast bar", "frames", B, { 150, 16 } },
  { "PetCastingBarFrame", "Pet cast bar", "frames", B, { 150, 16 } },
  { "BossTargetFrameContainer", "Boss frames", "frames", E, { 200, 300 } },
  { "ArenaEnemyFramesContainer", "Arena frames", "frames", E, { 200, 300 } },
  { "PersonalResourceDisplayFrame", "Personal resource display", "frames", E, { 200, 40 } },
  { "AlternatePowerBar", "Alternate power bar", "frames", B, { 120, 12 } },
  { "MonkStaggerBar", "Monk stagger bar", "frames", B, { 120, 12 } },
  { "TotemFrame", "Totems", "frames", B, { 140, 40 } },
  { "RuneFrame", "Death knight runes", "frames", B, { 140, 24 } },
  { "MageArcaneChargesFrame", "Arcane charges", "frames", B, { 140, 24 } },
  { "MonkHarmonyBarFrame", "Chi", "frames", B, { 140, 24 } },
  { "PaladinPowerBarFrame", "Holy power", "frames", B, { 140, 30 } },
  { "WarlockPowerFrame", "Soul shards", "frames", B, { 140, 24 } },
  { "RogueComboPointBarFrame", "Combo points (rogue)", "frames", B, { 140, 24 } },
  { "DruidComboPointBarFrame", "Combo points (druid)", "frames", B, { 140, 24 } },
  { "EssencePlayerFrame", "Essence", "frames", B, { 140, 24 } },
  { "EvokerEbonMightBar", "Ebon Might", "frames", B, { 140, 12 } },
  { "DemonHunterSoulFragmentsBar", "Soul fragments", "frames", B, { 140, 12 } },
  -- Action bars
  { "MainActionBar", "Action bar 1", "bars", E, { 500, 45 } },
  { "MultiBarBottomLeft", "Action bar 2", "bars", E, { 500, 45 } },
  { "MultiBarBottomRight", "Action bar 3", "bars", E, { 500, 45 } },
  { "MultiBarRight", "Action bar 4", "bars", E, { 45, 500 } },
  { "MultiBarLeft", "Action bar 5", "bars", E, { 45, 500 } },
  { "MultiBar5", "Action bar 6", "bars", E, { 500, 45 } },
  { "MultiBar6", "Action bar 7", "bars", E, { 500, 45 } },
  { "MultiBar7", "Action bar 8", "bars", E, { 500, 45 } },
  { "StanceBar", "Stance bar", "bars", E, { 300, 32 } },
  { "PetActionBar", "Pet bar", "bars", E, { 330, 32 } },
  { "PossessActionBar", "Possess bar", "bars", E, { 80, 32 } },
  { "MainMenuBarVehicleLeaveButton", "Vehicle exit", "bars", E, { 32, 32 } },
  { "OverrideActionBar", "Override bar", "bars", B, { 600, 80 } },
  { "ExtraAbilityContainer", "Extra action and zone ability", "bars", E, { 200, 80 } },
  { "ExtraActionBarFrame", "Extra action button", "bars", B, { 64, 64 } },
  { "ZoneAbilityFrame", "Zone ability", "bars", B, { 140, 64 } },
  { "MicroMenuContainer", "Micro menu", "bars", E, { 300, 40 } },
  { "BagsBar", "Bag bar", "bars", E, { 220, 40 } },
  { "MainStatusTrackingBarContainer", "Experience / reputation bar", "bars", E, { 600, 12 } },
  { "SecondaryStatusTrackingBarContainer", "Second tracking bar", "bars", E, { 600, 12 } },
  { "EssentialCooldownViewer", "Essential cooldowns", "bars", E, { 300, 50 } },
  { "UtilityCooldownViewer", "Utility cooldowns", "bars", E, { 300, 40 } },
  { "BuffIconCooldownViewer", "Tracked buff icons", "bars", E, { 300, 40 } },
  { "BuffBarCooldownViewer", "Tracked buff bars", "bars", E, { 220, 120 } },
  -- Auras
  { "BuffFrame", "Buffs", "auras", E, { 400, 100 } },
  { "DebuffFrame", "Debuffs", "auras", E, { 400, 60 } },
  { "TemporaryEnchantFrame", "Weapon enchants", "auras", B, { 80, 32 } },
  { "ExternalDefensivesFrame", "External defensives", "auras", E, { 200, 40 } },
  -- HUD and information
  { "ObjectiveTrackerFrame", "Objective tracker", "hud", E, { 260, 500 } },
  { "TalkingHeadFrame", "Talking head", "hud", E, { 570, 155 } },
  { "UIErrorsFrame", "UI errors", "hud", B, { 512, 60 } },
  { "ActionStatus", "Action status text", "hud", B, { 400, 30 } },
  { "RaidWarningFrame", "Raid warnings", "hud", B, { 512, 70 } },
  { "RaidBossEmoteFrame", "Boss emotes", "hud", B, { 512, 70 } },
  { "ZoneTextFrame", "Zone text", "hud", B, { 512, 60 } },
  { "SubZoneTextFrame", "Subzone text", "hud", B, { 512, 40 } },
  { "LossOfControlFrame", "Loss of control", "hud", B, { 256, 58 } },
  { "MirrorTimerContainer", "Breath and fatigue bars", "hud", E, { 206, 60 } },
  { "DurabilityFrame", "Durability figure", "hud", E, { 60, 75 } },
  { "VehicleSeatIndicator", "Vehicle seats", "hud", E, { 128, 128 } },
  { "EncounterBar", "Encounter bar", "hud", E, { 250, 40 } },
  { "PlayerPowerBarAlt", "Encounter power bar", "hud", B, { 250, 40 } },
  { "ArchaeologyDigsiteProgressBar", "Archaeology progress", "hud", E, { 250, 30 } },
  { "GameTooltipDefaultContainer", "Tooltip anchor", "hud", E, { 250, 100 } },
  { "UIWidgetTopCenterContainerFrame", "Top centre widgets", "hud", B, { 300, 40 } },
  { "UIWidgetBelowMinimapContainerFrame", "Widgets below the minimap", "hud", B, { 200, 60 } },
  { "UIWidgetPowerBarContainerFrame", "Widget power bar", "hud", B, { 300, 40 } },
  { "TopCenterContainer", "Top centre container", "hud", B, { 300, 40 } },
  { "GhostFrame", "Return to graveyard", "hud", B, { 130, 46 } },
  { "TicketStatusFrame", "Ticket status", "hud", B, { 208, 75 } },
  { "FramerateFrame", "Frame rate text", "hud", B, { 100, 20 } },
  { "SpellActivationOverlayFrame", "Spell alerts", "hud", B, { 256, 256 } },
  { "BossBanner", "Boss banner", "hud", B, { 400, 160 } },
  { "LevelUpDisplay", "Level up banner", "hud", B, { 418, 72 } },
  { "EventToastManagerFrame", "Event toasts", "hud", B, { 400, 100 } },
  { "ObjectiveTrackerBonusBannerFrame", "Bonus objective banner", "hud", B, { 400, 100 } },
  { "DamageMeter", "Blizzard damage meter", "hud", E, { 300, 200 } },
  { "StaticPopup1", "Pop-up dialog", "hud", B, { 320, 100 } },
  { "ReadyCheckFrame", "Ready check", "hud", B, { 323, 100 } },
  { "RolePollPopup", "Role poll", "hud", B, { 200, 120 } },
  { "LFGDungeonReadyPopup", "Dungeon ready pop-up", "hud", B, { 300, 200 } },
  { "PVPReadyDialog", "PvP ready pop-up", "hud", B, { 300, 200 } },
  { "ReadyStatus", "Ready status", "hud", B, { 200, 120 } },
  -- Alerts and loot
  { "AlertFrame", "Alerts and toasts", "alerts", B, { 300, 60 } },
  { "GroupLootContainer", "Group loot rolls", "alerts", B, { 300, 90 } },
  { "BonusRollFrame", "Bonus roll", "alerts", B, { 270, 80 } },
  { "LootFrame", "Loot window", "alerts", E, { 220, 300 } },
  { "BNToastFrame", "Battle.net toasts", "alerts", B, { 250, 50 } },
  { "QueueStatusButton", "Queue status eye", "alerts", B, { 45, 45 } },
  { "QueueStatusFrame", "Queue status details", "alerts", B, { 250, 80 } },
  { "QuickJoinToastButton", "Quick join", "alerts", B, { 32, 32 } },
  -- Group
  { "PartyFrame", "Party frames", "group", E, { 120, 300 } },
  { "CompactRaidFrameContainer", "Raid frames", "group", E, { 400, 300 } },
  { "CompactRaidFrameManager", "Raid manager", "group", B, { 200, 140 } },
  { "CompactArenaFrame", "Arena frames (raid style)", "group", E, { 200, 300 } },
  { "ArenaPrepFramesContainer", "Arena preparation", "group", B, { 200, 300 } },
  { "RaidUtilityPanel", "Raid utility", "group", B, { 200, 80 } },
  -- Minimap and chat
  { "MinimapCluster", "Minimap", "minimap", E, { 230, 230 } },
  { "GameTimeFrame", "Calendar button", "minimap", B, { 40, 40 } },
  { "TimeManagerClockButton", "Clock", "minimap", B, { 60, 28 } },
  { "AddonCompartmentFrame", "Addon compartment", "minimap", B, { 24, 24 } },
  { "ExpansionLandingPageMinimapButton", "Expansion summary button", "minimap", B, { 50, 50 } },
  { "MiniMapMailIcon", "Mail icon", "minimap", B, { 30, 30 } },
  { "MinimapZoneText", "Minimap zone text", "minimap", B, { 140, 12 } },
  { "ChatFrame1", "General chat", "minimap", E, { 430, 120 } },
  { "ChatFrame2", "Combat log", "minimap", B, { 430, 120 } },
  { "ChatFrameMenuButton", "Chat menu button", "minimap", B, { 32, 32 } },
  { "ChatFrameChannelButton", "Chat channel button", "minimap", B, { 32, 32 } },
  { "ChatFrameToggleVoiceDeafenButton", "Voice deafen button", "minimap", B, { 32, 32 } },
  { "ChatFrameToggleVoiceMuteButton", "Voice mute button", "minimap", B, { 32, 32 } },
  { "GeneralDockManager", "Chat tabs", "minimap", B, { 400, 22 } },
  -- Misc
  { "ContainerFrameCombinedBags", "Combined bags window", "misc", E, { 380, 400 } },
  { "ContainerFrame1", "Backpack", "misc", B, { 180, 200 } },
  { "ContainerFrame2", "Bag 1", "misc", B, { 180, 200 } },
  { "ContainerFrame3", "Bag 2", "misc", B, { 180, 200 } },
  { "ContainerFrame4", "Bag 3", "misc", B, { 180, 200 } },
  { "ContainerFrame5", "Bag 4", "misc", B, { 180, 200 } },
  { "ContainerFrame6", "Reagent bag", "misc", B, { 180, 200 } },
  { "ColorPickerFrame", "Colour picker", "misc", B, { 330, 220 } },
  { "PetBattleFrame", "Pet battle HUD", "misc", B, { 600, 100 } },
  { "CovenantRenownToast", "Renown toast", "misc", B, { 300, 100 } },
  { "MovieFrame", "Cinematic subtitles", "misc", B, { 600, 60 } },
  { "PlayerChoiceToggleButton", "Choice toggle", "misc", B, { 150, 40 } },
  { "HousingControlsFrame", "Housing controls", "misc", B, { 300, 60 } },
}
Movers.CATALOG = CATALOG
Movers.CATEGORY_LABELS = { frames = "Unit frames", bars = "Action bars", auras = "Auras", hud = "HUD", alerts = "Alerts & loot",
  group = "Group", minimap = "Minimap & chat", misc = "Other" }
Movers.byId = {}

local function frameOf(name) return rawget(_G, name) end
Movers.FrameOf = frameOf

for _, c in ipairs(CATALOG) do
  local id = "bz." .. c[1]
  local e = { id = id, frame = c[1], label = c[2], cat = c[3], editMode = c[4], size = c[5] }
  Movers.byId[id] = e
  Layout:RegisterElement(id, { label = c[2], owner = "Blizzard", kind = "blizzard", category = c[3], editMode = c[4], size = c[5],
    blizzardFrame = c[1], default = { point = "CENTER", x = 0, y = 0 } })
end

function Movers:Count() return #CATALOG end
function Movers:Enabled() return Schema:Get("studio.blizzard.enabled") end
function Movers:IsEditMode(id) local e = self.byId[id]; return e ~= nil and e.editMode end

-- The Blizzard frame's own current anchor as a Layout record (the start point
-- of a Studio session for an element the user has not changed yet).
function Movers:Current(id)
  local e = self.byId[id]
  local f = e and frameOf(e.frame)
  if not (f and f.GetCenter) then return nil end
  local cx, cy = f:GetCenter()
  if not cx then return nil end
  local s = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  return { point = "CENTER", x = math.floor(cx * s - UIParent:GetWidth() / 2 + 0.5), y = math.floor(cy * s - UIParent:GetHeight() / 2 + 0.5) }
end

local function place(f, r, id)
  local e = FL.entries[id]
  local was = e and e.state or {}
  f:ClearAllPoints()
  f:SetPoint(r.point, UIParent, r.point, r.x, r.y)
  if f.SetScale then f:SetScale(r.scale or was.scale or 1) end
  if f.SetFrameStrata and (r.strata or was.strata) then f:SetFrameStrata(r.strata or was.strata) end
  if f.SetFrameLevel and (r.level or was.level) then f:SetFrameLevel(r.level or was.level) end
  local a = r.hide and 0 or (r.fade and Layout.FadeAlpha(r.fade, PUI.Visibility and PUI.Visibility.state or {}, false)) or r.alpha or was.alpha or 1
  if f.SetAlpha then f:SetAlpha(a) end
  if f.EnableMouse and not (f.IsProtected and f:IsProtected() and CQ.InCombat()) then
    if r.hide or r.clickThrough then f:EnableMouse(false) elseif type(was.mouse) == "boolean" then f:EnableMouse(was.mouse) end
  end
end

-- Re-asserts after Blizzard re-anchors a frame we placed (layout managers).
local function hook(id, f)
  if Movers.hooked[id] or not hooksecurefunc then return end
  Movers.hooked[id] = true
  hooksecurefunc(f, "SetPoint", function()
    if Movers.busy[id] or not Movers.applied[id] then return end
    C_Timer.After(0, function() Movers:ApplyOne(id) end)
  end)
end

function Movers:ApplyOne(id, r)
  local e = self.byId[id]
  if not e or e.editMode then return false end
  r = r or Schema:Get("studio.blizzard.positions")[id]
  local f = frameOf(e.frame)
  if not f then return false end
  if not (r and self:Enabled()) then
    if self.applied[id] then
      self.applied[id] = nil
      FL:Release(OWNER, id)
    end
    return false
  end
  local ok = FL:Take(OWNER, f, id)
  if not ok then return false end
  self.applied[id] = true
  hook(id, f)
  local function go() self.busy[id] = true; place(f, r, id); self.busy[id] = nil end
  if f.IsProtected and f:IsProtected() and CQ.InCombat() then CQ.Defer("movers." .. id, go) else go() end
  return true
end

function Movers:ApplyAll()
  local saved = Schema:Get("studio.blizzard.positions")
  for id in pairs(self.applied) do if not (saved[id] and self:Enabled()) then self:ApplyOne(id) end end
  if not self:Enabled() then return end
  for id, r in pairs(saved) do self:ApplyOne(id, r) end
end

function Movers:UsesFade()
  if not self:Enabled() then return false end
  for _, r in pairs(Schema:Get("studio.blizzard.positions")) do if r.fade then return true end end
  return false
end

-- Hand-off: a user click opens Blizzard's Edit Mode (never from code paths).
function Movers:OpenEditMode()
  local em = rawget(_G, "EditModeManagerFrame")
  local show = rawget(_G, "ShowUIPanel")
  if em and show and not CQ.InCombat() then show(em); return true end
  return false
end

Schema:Register("studio.blizzard.enabled", {
  type = "toggle", default = false,
  label = "Blizzard elements in Studio", tooltip = "Lists about 130 Blizzard HUD elements in Studio so you can move, scale, layer, fade or hide them. Edit Mode frames stay with Edit Mode. Off restores every Blizzard element Phoenix changed.",
  mode = "simple", owner = "Studio", searchTags = { "moveany", "blizzard", "move", "edit mode" },
  apply = function() Movers:ApplyAll() end,
})
Schema:Register("studio.blizzard.showAll", {
  type = "toggle", default = false,
  label = "Show every Blizzard element under All", tooltip = "Off: the All filter lists only Blizzard elements you changed; the Blizzard filter always lists them all.",
  mode = "advanced", owner = "Studio", searchTags = { "blizzard", "filter" },
  apply = function() if PUI.Studio and PUI.Studio.OnSettingsChanged then PUI.Studio:OnSettingsChanged() end end,
})
Schema:Register("studio.blizzard.positions", {
  type = "layout", default = {}, overridable = true,
  label = "Blizzard element positions", tooltip = "Blizzard elements Studio changed.",
  mode = "advanced", owner = "Studio",
  apply = function() Movers:ApplyAll() end,
})

-- LoD Blizzard UIs and frames created late: try again when an addon loads.
local ev = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if PUI.Kernel.dbReady and Movers:Enabled() then Movers:ApplyAll() end
  if PUI.Windows and PUI.Kernel.dbReady then PUI.Windows:Scan() end
end)

------------------------------------------------------------------------------
-- One-time MoveAny importer: read-only, user-triggered. Reads MoveAny's saved
-- profile (MATAB) and turns the points, scales and alphas of the elements
-- Phoenix knows into a preview; nothing is written until the user applies it.
local Import = {}
Movers.Import = Import

local function rec(p)
  if type(p) ~= "table" then return nil end
  local point, x, y = p[1] or p.point or p.POINT, p[4] or p.x or p.X, p[5] or p.y or p.Y
  if type(x) ~= "number" then x, y = p[2], p[3] end
  if not (Schema.POINTS[point] and type(x) == "number" and type(y) == "number") then return nil end
  return { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

-- Returns a plan { profile, phoenix = {[id]=rec}, blizzard = {[id]=rec}, skipped = {names}, editMode = {names} }.
function Import.MoveAny(db, profileName)
  db = db or rawget(_G, "MATAB")
  if type(db) ~= "table" or type(db.PROFILES) ~= "table" then return nil, "MoveAny settings were not found (is MoveAny enabled?)" end
  local name = profileName
  if not name then
    local pc = rawget(_G, "MATABPC")
    name = type(pc) == "table" and type(pc.CURRENTPROFILE) == "string" and pc.CURRENTPROFILE or "DEFAULT"
  end
  local prof = db.PROFILES[name]
  if type(prof) ~= "table" then return nil, "MoveAny profile '" .. tostring(name) .. "' was not found" end
  local eles = type(prof.ELES) == "table" and prof.ELES or {}
  local points = type(eles.POINTS) == "table" and eles.POINTS or {}
  local options = type(eles.OPTIONS) == "table" and eles.OPTIONS or {}
  local plan = { profile = name, blizzard = {}, skipped = {}, editMode = {}, count = 0 }
  local names = {}
  for k in pairs(points) do if type(k) == "string" then names[#names + 1] = k end end
  table.sort(names)
  for _, frameName in ipairs(names) do
    local id = "bz." .. frameName
    local e = Movers.byId[id]
    local r = rec(points[frameName])
    if not (e and r) then plan.skipped[#plan.skipped + 1] = frameName
    elseif e.editMode then plan.editMode[#plan.editMode + 1] = e.label
    else
      local o = type(options[frameName]) == "table" and options[frameName] or {}
      if type(o.SCALE) == "number" and o.SCALE >= 0.25 and o.SCALE <= 4 then r.scale = o.SCALE end
      if type(o.ALPHAINCOMBAT) == "number" and o.ALPHAINCOMBAT >= 0 and o.ALPHAINCOMBAT <= 1 then r.fade = r.fade or {}; r.fade.combat = o.ALPHAINCOMBAT end
      if type(o.ALPHANOTINCOMBAT) == "number" and o.ALPHANOTINCOMBAT >= 0 and o.ALPHANOTINCOMBAT <= 1 then r.fade = r.fade or {}; r.fade.ooc = o.ALPHANOTINCOMBAT end
      if o.HIDE == true then r.hide = true end
      if o.CLICKTHROUGH == true then r.clickThrough = true end
      plan.blizzard[id] = r
      plan.count = plan.count + 1
    end
  end
  return plan
end

-- Applies an import plan over the current Blizzard positions (merge).
function Import.Apply(plan)
  local saved = Schema:Get("studio.blizzard.positions")
  for id, r in pairs(plan.blizzard) do saved[id] = r end
  Schema:Set("studio.blizzard.positions", saved)
  PUI.DB.sv.moveAnyImported = true
  return plan.count
end

PUI.Slash:Register("import", function(rest)
  if rest ~= "moveany" then return PUI.Slash.Print("usage: /pui import moveany") end
  local plan, why = Import.MoveAny()
  if not plan then return PUI.Slash.Print(why) end
  PUI.Slash.Print(string.format("MoveAny profile %s: %d elements to import, %d stay with Edit Mode, %d not known. Open Studio > Import to review and apply.",
    plan.profile, plan.count, #plan.editMode, #plan.skipped))
end, "moveany: preview MoveAny positions to import into Studio")
