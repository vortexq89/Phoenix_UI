local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Presets for the first-install wizard (PUI_V2 5.16): data only.
local _, ns = ...
local P = {}
ns.P = P

-- Role presets: the modules each role turns on; every other module goes off.
P.ROLES = {
  healer = { "UnitFrames", "RaidFrames", "ClickCast", "ActionBars", "CooldownManager", "Tooltip", "Minimap", "DataBars", "Reminders", "Skins", "QuestTracker" },
  tank = { "UnitFrames", "Nameplates", "RaidFrames", "ActionBars", "CooldownManager", "ResourceBars", "Tooltip", "Minimap", "DataBars", "Reminders", "Skins", "QuestTracker" },
  dps = { "UnitFrames", "Nameplates", "RaidFrames", "ActionBars", "CooldownManager", "ResourceBars", "Tooltip", "Minimap", "DataBars", "Reminders", "Skins", "QuestTracker" },
  pvp = { "UnitFrames", "Nameplates", "RaidFrames", "ActionBars", "CooldownManager", "ResourceBars", "Tooltip", "Minimap", "Skins" },
  minimal = { "Tooltip", "Minimap", "Skins" },
}
P.ROLE_ORDER = { "healer", "tank", "dps", "pvp", "minimal" }
P.ROLE_LABELS = { healer = "Healer", tank = "Tank", dps = "Damage", pvp = "PvP", minimal = "Minimal" }
-- Modules a role preset may switch; Sentinel and anything unknown are left alone.
P.MANAGED = { "UnitFrames", "RaidFrames", "ClickCast", "Nameplates", "ActionBars", "CooldownManager", "ResourceBars", "Tooltip",
  "Minimap", "DataBars", "Chat", "Reminders", "Skins", "Vault", "Flow", "QuestTracker" }

-- Layout presets: Studio positions (relative to UIParent) for the main elements.
P.LAYOUTS = {
  phoenix = { label = "Phoenix", positions = {} },
  centered = { label = "Centered", positions = {
    ["uf.player"] = { point = "CENTER", x = -220, y = -160 },
    ["uf.target"] = { point = "CENTER", x = 220, y = -160 },
    ["rb.stack"] = { point = "CENTER", x = 0, y = -210 },
    ["cdm.essential"] = { point = "CENTER", x = 0, y = -250 },
    ["cdm.utility"] = { point = "CENTER", x = 0, y = -295 },
  } },
  healer = { label = "Healer", positions = {
    ["rf.party"] = { point = "CENTER", x = 0, y = -230 },
    ["rf.raid"] = { point = "CENTER", x = 0, y = -230 },
    ["uf.player"] = { point = "CENTER", x = -330, y = -120 },
    ["uf.target"] = { point = "CENTER", x = 330, y = -120 },
    ["cdm.essential"] = { point = "CENTER", x = 0, y = -140 },
  } },
}
P.LAYOUT_ORDER = { "phoenix", "centered", "healer" }

-- Looks: accent colour and whether Blizzard windows get Phoenix skins.
P.LOOKS = {
  phoenix = { label = "Phoenix", accent = "ember", skins = true },
  blizzard = { label = "Blizzard", accent = "ember", skins = false },
  classic = { label = "Classic", accent = "spark", skins = true },
  forever = { label = "Forever", accent = "void", skins = true },
}
P.LOOK_ORDER = { "phoenix", "blizzard", "classic", "forever" }

P.TOUR = {
  { title = "Studio", body = "Type /pui studio to move any Phoenix frame. Drag, snap and nudge; positions save per profile." },
  { title = "Options", body = "Type /pui to open the options. Every switch applies at once, no reload." },
  { title = "Simple or Advanced", body = "Simple shows the main switches. Advanced shows every setting of every module." },
}
