local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nav: sidebar groups (design spec 6: Interface, Combat, Group, Social &
-- Chat, Tools, System), the icon, label and one-line description of each
-- settings owner, and the breadcrumb group of a page.
local Options = PUI.Options
local Nav = {}
Options.Nav = Nav

-- owner = { icon, label, description, module setting name (or nil) }
local INFO = {
  Core = { "general", "General", "Scale, entry points and behaviour shared by every module." },
  Theme = { "theme", "Theme & Media", "Accent, fonts, bar textures and sounds used across every module." },
  Studio = { "studio", "Studio", "Move, snap and size every Phoenix frame." },
  Minimap = { "minimap", "Minimap", "Square, clock, zone and coordinates.", "HUD" },
  Tooltip = { "tooltip", "Tooltip", "Item level, spec, Mythic+ and anchor.", "HUD" },
  DataBars = { "databars", "Data Bars", "Clock, FPS, gold, durability and more.", "HUD" },
  QuestTracker = { "quests", "Quests", "Compact objective tracker.", "QuestTracker" },
  Skins = { "skins", "Skins", "Blizzard and addon windows in Phoenix style.", "Skins" },
  UnitFrames = { "unitframes", "Unit Frames", "Health, power, cast bars and auras for every unit.", "UnitFrames" },
  ActionBars = { "actionbars", "Action Bars", "Nine bars with paging, fading and per-bar visibility.", "ActionBars" },
  ResourceBars = { "resource", "Resource Bars", "Class resources, mana and combo points.", "ResourceBars" },
  CooldownManager = { "cooldowns", "Cooldown Manager", "Blizzard cooldown layouts, restyled.", "CooldownManager" },
  Nameplates = { "nameplates", "Nameplates", "Enemy and friendly plates, threat colours.", "Nameplates" },
  Reminders = { "reminders", "Reminders", "Missing buffs and class auras.", "Reminders" },
  ClickCast = { "clickcast", "Click Casting", "Bindings on unit and raid frames." },
  RaidFrames = { "raid", "Raid & Party", "Party and raid up to 40.", "RaidFrames" },
  GroupFinder = { "groupfinder", "Group Finder", "Score colours, roles and filters.", "GroupFinder" },
  Ascent = { "ascent", "Ascent M+", "Mythic+ timer, forces and splits.", "Ascent" },
  Embers = { "embers", "Embers Meter", "Damage and healing meter.", "Embers" },
  Loadouts = { "loadouts", "Loadouts", "Spec, talents and gear per content.", "Loadouts" },
  Chat = { "chat", "Chat", "Tabs, links, copy.", "Chat" },
  Flow = { "flow", "Flow", "Quality-of-life automation.", "Flow" },
  Vault = { "vault", "Vault", "Unified bags and bank.", "Vault" },
  Oracle = { "oracle", "Oracle", "Ctrl K command palette.", "Oracle" },
  Wisdom = { "wisdom", "Wisdom", "Stat weights and upgrade stars.", "Wisdom" },
  Setup = { "setup", "Setup", "First-time wizard and presets." },
  Profiles = { "profiles", "Profiles", "Your profiles, content switching, import and export." },
  Options = { "dashboard", "Window", "Scale, tint, open key and pinned pages of this window." },
  Sentinel = { "sentinel", "Sentinel", "Errors, taint and performance health." },
  Overrides = { "loadouts", "Overrides", "Values set only for one specialization or one kind of content." },
  -- Review 2026-10-27: pages added after the sidebar was written (they fell into Interface with a generic label).
  Arena = { "arena", "Arena", "Enemy arena frames, trinkets, DR tray and match tools.", "Arena" },
  Pulse = { "pulse", "Pulse", "Boss timeline bars, next abilities and timers.", "Pulse" },
  Spark = { "spark", "Spark", "Scrolling combat text and notifications.", "Spark" },
  CastHistory = { "spark", "Cast History", "Your recent casts as a strip of icons.", "CastHistory" },
  PvP = { "arena", "PvP", "Rated card, scoreboard and battleground tools.", "PvP" },
  RaidTools = { "raid", "Raid Tools", "Markers, ready check, pull timer, notes and stats.", "RaidTools" },
  Friends = { "chat", "Friends", "Friends list look, notes and search.", "Friends" },
  Forever = { "general", "Forever", "Flight timer and pet happiness (Forever client).", "Forever" },
  QoL = { "chat", "Announcements", "One router for quest, key, reset and interrupt messages." },
  Ledger = { "general", "Changes & uninstall", "Every game setting, key binding and frame Phoenix changed, with one-click restore." },
}
Nav.INFO = INFO

Nav.GROUPS = {
  { "Interface", { "Core", "Theme", "Studio", "Minimap", "Tooltip", "DataBars", "QuestTracker", "Skins" } },
  { "Combat", { "UnitFrames", "ActionBars", "ResourceBars", "CooldownManager", "Nameplates", "Reminders", "ClickCast", "Arena", "Pulse", "Spark", "CastHistory", "PvP" } },
  { "Group", { "RaidFrames", "GroupFinder", "Ascent", "Embers", "Loadouts", "RaidTools" } },
  { "Social & Chat", { "Chat", "Flow", "Friends", "QoL" } },
  { "Tools", { "Vault", "Oracle", "Wisdom", "Setup", "Forever" } },
  { "System", { "Profiles", "Overrides", "Options", "Sentinel", "Ledger" } },
}

function Nav.Info(owner)
  local i = INFO[owner]
  if i then return i[1], i[2], i[3], i[4] end
  return "general", owner, ""
end

function Nav.GroupOf(owner)
  for _, g in ipairs(Nav.GROUPS) do
    for _, o in ipairs(g[2]) do if o == owner then return g[1] end end
  end
  return "Interface"
end

-- Module enabled? (true/false) or nil when the page is not a module.
function Nav.ModuleOn(owner)
  local key = "module." .. owner
  if PUI.Schema:Def(key) then return PUI.Schema:Get(key) and true or false, key end
  return nil
end

-- Groups with only the owners that have a page in this mode, in order;
-- owners not in any group are appended to Interface.
function Nav.Layout(mode)
  local pages, seen, out = Options.Model.Pages(mode), {}, {}
  local byName = {}
  for _, p in ipairs(pages) do byName[p.name] = p end
  for _, g in ipairs(Nav.GROUPS) do
    local items = {}
    for _, owner in ipairs(g[2]) do
      if byName[owner] then items[#items + 1] = byName[owner]; seen[owner] = true end
    end
    out[#out + 1] = { label = g[1], pages = items }
  end
  for _, p in ipairs(pages) do
    if not seen[p.name] then table.insert(out[1].pages, p) end
  end
  return out
end
