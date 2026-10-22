local _, ns = ...
local Config = ns.Config

--[[ The options layout: 13 sidebar groups (docs/REDESIGN.md §3). Entries are module keys or page keys
    registered with Config:RegisterPage. This is menu-only: it never touches saved settings, and a module that
    is missing here (a new one, or a third-party plug-in) falls into the group for its category, so every page
    stays reachable. ]]
Config.GROUPS = {
    { key = "home",       label = "HOME",             icon = "home",        entries = { "home" } },
    { key = "general",    label = "GENERAL",          icon = "general",     entries = { "General" } },
    { key = "appearance", label = "GROUP_APPEARANCE", icon = "theme",       entries = { "fonts", "textures", "sounds" } },
    { key = "unitframes", label = "UNITFRAMES",       icon = "unitframes",  entries = { "UnitFrames", "GroupFrames" } },
    { key = "nameplates", label = "NAMEPLATES",       icon = "nameplates",  entries = { "NamePlates" } },
    { key = "actionbars", label = "GROUP_ACTIONBARS", icon = "actionbars",  entries = { "ActionBars", "CooldownText" } },
    { key = "combat",     label = "CAT_COMBAT",       icon = "cat-combat",
      entries = { "CastBars", "Auras", "Tracker", "CombatText", "SpellHistory", "DamageMeter" } },
    { key = "group",      label = "GROUP_MYTHIC",     icon = "mythicplus",  entries = { "MythicPlus", "PvP" } },
    { key = "social",     label = "GROUP_SOCIAL",     icon = "chat",        entries = { "Chat", "AFK" } },
    { key = "maps",       label = "GROUP_MAPS",       icon = "maps",        entries = { "Minimap", "DataTexts" } },
    { key = "items",      label = "GROUP_TOOLTIPS",   icon = "items",       entries = { "Tooltip", "ItemLevel", "Bags" } },
    { key = "qol",        label = "GROUP_QOL",        icon = "quality",     entries = { "Quality", "Automation", "Skins" } },
    { key = "tools",      label = "GROUP_TOOLS",      icon = "cat-utility",
      entries = { "Movers", "profiles", "presets", "Bugs", "diagnostics", "about" } },
}

-- Where an unlisted module goes.
local FALLBACK = { system = "general", interface = "qol", combat = "combat", social = "social", utility = "tools" }

local groupOf = {}

-- A page or module that exists: built-in pages need a builder, modules must be visible.
function Config:EntryExists(key)
    if self.builders[key] then return true end
    local m = ns.modules[key]
    return m ~= nil and not m.hidden
end

-- The groups with their live entries (nonexistent ones dropped, unlisted modules appended).
function Config:Groups()
    local out, placed = {}, {}
    for _, g in ipairs(self.GROUPS) do
        for _, key in ipairs(g.entries) do placed[key] = true end
    end
    local extra = {}
    for _, m in ipairs(ns.moduleList) do
        if not m.hidden and not placed[m.key] then
            local gk = FALLBACK[m.category] or "tools"
            extra[gk] = extra[gk] or {}
            table.insert(extra[gk], m.key)
        end
    end
    wipe(groupOf)
    for _, g in ipairs(self.GROUPS) do
        local entries = {}
        for _, key in ipairs(g.entries) do
            if self:EntryExists(key) then entries[#entries + 1] = key end
        end
        for _, key in ipairs(extra[g.key] or {}) do entries[#entries + 1] = key end
        if #entries > 0 then
            out[#out + 1] = { key = g.key, label = g.label, icon = g.icon, entries = entries }
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
