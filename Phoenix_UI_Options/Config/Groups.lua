local _, ns = ...
local Config = ns.Config

--[[ The options layout v2 (docs/plan_v2/PLAN_V2.md §4): seven groups on the icon rail, each a list of pages
    (module keys or page keys registered with Config:RegisterPage), optionally split by sub-headings
    (heading entries naming a locale key). Every module and page sits in exactly one group. This is menu-only: it
    never touches saved settings, and a module that is missing here (a new one, or a third-party plug-in)
    falls into the group for its category, so every page stays reachable. Pages a client lacks (Mythic+ and
    Sim on WoW Forever) simply drop out of their group. ]]
Config.GROUPS = {
    { key = "home", label = "HOME", icon = "home", entries = { "home" } },
    { key = "frames", label = "RAIL_FRAMES", icon = "unitframes",
      entries = { "UnitFrames", "GroupFrames", "NamePlates", "CastBars", "Auras" } },
    { key = "bars", label = "RAIL_BARS", icon = "actionbars", entries = { "ActionBars", "Tracker", "CooldownText" } },
    { key = "combat", label = "CAT_COMBAT", icon = "cat-combat", entries = { "CombatText", "DamageMeter", "SpellHistory" } },
    { key = "interface", label = "RAIL_INTERFACE", icon = "interface",
      entries = { { heading = "SUB_CHAT_MAPS" }, "Chat", "Minimap", "DataTexts",
                  { heading = "SUB_ITEMS" }, "Tooltip", "Bags", "ItemLevel",
                  { heading = "SUB_WINDOWS" }, "Skins" } },
    { key = "content", label = "RAIL_CONTENT", icon = "content", entries = { "Quests", "MythicPlus", "Encounters", "PvP", "Sim" } },
    { key = "phoenix", label = "RAIL_PHOENIX", icon = "cat-phoenix",
      entries = { { heading = "SUB_LOOK" }, "General", "fonts", "textures", "sounds", "presets",
                  { heading = "SUB_SETUP" }, "profiles", "Movers",
                  { heading = "SUB_UTILITY" }, "Quality", "Automation", "AFK",
                  { heading = "SUB_SUPPORT" }, "Bugs", "diagnostics", "about" } },
}

--[[ How deep each page is planned to go (plan v2 target rows, GAP_MATRIX.md). The module list and Home show
    the settings a page has now against this, so the depth still to build is visible, never hidden. ]]
Config.DEPTH = {
    ActionBars = 114, CooldownText = 12, Tracker = 59, UnitFrames = 150, GroupFrames = 68, NamePlates = 100,
    CastBars = 55, Auras = 41, CombatText = 26, DamageMeter = 31, SpellHistory = 12, Chat = 51, Minimap = 41,
    Tooltip = 45, Bags = 47, ItemLevel = 19, DataTexts = 47, Skins = 28, General = 23, profiles = 8, Movers = 11,
    Quality = 11, Automation = 14, AFK = 4, Bugs = 12, MythicPlus = 32, Encounters = 65, PvP = 8, Sim = 8, Quests = 27,
    diagnostics = 3,
}

-- Where an unlisted module goes.
local FALLBACK = { system = "phoenix", interface = "interface", combat = "combat", social = "interface", utility = "phoenix" }

local groupOf = {}

-- A page or module that exists: built-in pages need a builder, modules must be visible.
function Config:EntryExists(key)
    if self.builders[key] then return true end
    local m = ns.modules[key]
    return m ~= nil and not m.hidden
end

--[[ The groups with their live entries: { key, label, icon, entries = { key, ... },
    sections = { { heading = L key|nil, entries = { key, ... } }, ... } }. Missing pages are dropped, a
    heading with nothing under it goes too, and unlisted modules are appended to their category's group. ]]
function Config:Groups()
    local out, placed = {}, {}
    for _, g in ipairs(self.GROUPS) do
        for _, key in ipairs(g.entries) do if type(key) == "string" then placed[key] = true end end
    end
    local extra = {}
    for _, m in ipairs(ns.moduleList) do
        if not m.hidden and not placed[m.key] then
            local gk = FALLBACK[m.category] or "phoenix"
            extra[gk] = extra[gk] or {}
            table.insert(extra[gk], m.key)
        end
    end
    wipe(groupOf)
    for _, g in ipairs(self.GROUPS) do
        local entries, sections = {}, {}
        local section = { entries = {} }
        local function push()
            if #section.entries > 0 then sections[#sections + 1] = section end
        end
        for _, e in ipairs(g.entries) do
            if type(e) == "table" then
                push()
                section = { heading = e.heading, entries = {} }
            elseif self:EntryExists(e) then
                entries[#entries + 1] = e
                section.entries[#section.entries + 1] = e
            end
        end
        for _, key in ipairs(extra[g.key] or {}) do
            entries[#entries + 1] = key
            section.entries[#section.entries + 1] = key
        end
        push()
        if #entries > 0 then
            out[#out + 1] = { key = g.key, label = g.label, icon = g.icon, entries = entries, sections = sections }
            for _, key in ipairs(entries) do groupOf[key] = out[#out] end
        end
    end
    return out
end

function Config:GroupOf(key)
    if not next(groupOf) then self:Groups() end
    return groupOf[key]
end

-- Label and icon of any entry (module or page).
function Config:EntryInfo(key)
    local m = ns.modules[key]
    if m then return ns.L[m.label] or m.label, m.icon end
    local p = self.pageInfo[key]
    if p then return ns.L[p.label] or p.label, p.icon end
    return key, "question"
end

-- The schema behind a page (a module's options or a built-in page's), for counts and search.
function Config:SchemaOf(key)
    if ns.modules[key] then return ns.options[key] end
    local info = self.pageInfo[key]
    local schema = info and info.schema
    if type(schema) == "function" then schema = schema() end
    return schema
end

-- now, target: settings a page has, and how many plan v2 gives it (nil when it has no target).
function Config:Depth(key)
    local now = self.CountSettings and self.CountSettings(self:SchemaOf(key) or {}) or 0
    return now, self.DEPTH[key]
end
