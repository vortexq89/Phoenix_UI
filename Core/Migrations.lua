local _, ns = ...

--[[ ns.Migrations — ordered schema upgrades of PhoenixUIDB (ARCHITECTURE §5.4).
    Each step runs at most once, inside SafeCall, and must tolerate any shape of old data. ]]
local Mg = {}
ns.Migrations = Mg

-- legacy (Phoenix_UI 11.x AceDB profile) path -> { module, key, transform? }
local THEMES = { PhoenixFlame = "ember", Dark = "ember", Blizzard = "ember", Class = "class", Custom = "custom" }
local function bool(v) if type(v) == "boolean" then return v end end

local LEGACY_MAP = {
    { "general.theme", "General", "theme.preset", function(v) return THEMES[v] end },
    { "general.automation.delete", "Automation", "fillDelete", bool },
    { "general.automation.decline", "Automation", "declineDuels", bool },
    { "general.automation.repair", "Automation", "repair", function(v)
        if v == false then return "off" elseif v == "Guild" then return "guild" elseif v ~= nil then return "player" end
    end },
    { "general.automation.sell", "Automation", "sellJunk", bool },
    { "general.automation.invite", "Automation", "acceptInvites", bool },
    { "general.automation.release", "Automation", "autoRelease", bool },
    { "general.automation.resurrect", "Automation", "acceptResurrect", bool },
    { "general.automation.cinematic", "Automation", "skipCinematics", bool },
    { "general.cosmetic.afkscreen", "AFK", "enabled", bool },
    { "general.cosmetic.talkhead", "Quality", "hideTalkingHead", bool },
    { "general.cosmetic.errors", "Quality", "filterErrors", bool },
    { "general.display.ilvl", "ItemLevel", "enabled", bool },
    { "general.display.fps", "DataTexts", "fps", bool },
    { "general.display.ms", "DataTexts", "latency", bool },
    { "general.display.movementSpeed", "DataTexts", "speed", bool },
    { "unitframes.classcolor", "UnitFrames", "classColor", bool },
    { "nameplates.healthtext", "NamePlates", "healthText", bool },
    { "actionbar.buttons.key", "ActionBars", "hotkeys", bool },
    { "actionbar.buttons.macro", "ActionBars", "macroText", bool },
    { "actionbar.buttons.range", "ActionBars", "rangeTint", bool },
    { "castbars.icon", "CastBars", "icon", bool },
    { "castbars.timer", "CastBars", "timer", bool },
    { "castbars.showLatency", "CastBars", "latency", bool },
    { "tooltip.mouseanchor", "Tooltip", "anchor", function(v) if v == true then return "CURSOR" end end },
    { "tooltip.hideincombat", "Tooltip", "hideInCombat", bool },
    { "tooltip.targetOfTarget", "Tooltip", "target", bool },
    { "tooltip.roleIcons", "Tooltip", "role", bool },
    { "chat.link", "Chat", "urls", bool },
    { "chat.copy", "Chat", "copyButton", bool },
    { "maps.coords", "Minimap", "coords", bool },
    { "maps.clock", "DataTexts", "clock", bool },
    { "misc.safequeue", "PvP", "safeQueue", bool },
    { "misc.tabbinder", "PvP", "tabBinder", bool },
    { "misc.surrender", "PvP", "surrender", bool },
}

local function importLegacy(sv)
    local legacy = Phoenix_UIDB
    if type(legacy) ~= "table" or type(legacy.profiles) ~= "table" then return end
    local U = ns.Util
    local imported, skipped = 0, 0
    for name, old in pairs(legacy.profiles) do
        if type(name) == "string" and type(old) == "table" and not sv.profiles[name] then
            local profile = { modules = {} }
            for _, row in ipairs(LEGACY_MAP) do
                local ok, value = pcall(U.GetPath, old, row[1]) -- tolerate non-table intermediates
                if ok and value ~= nil then
                    local v = row[4] and row[4](value)
                    if v ~= nil then
                        profile.modules[row[2]] = profile.modules[row[2]] or {}
                        U.SetPath(profile.modules[row[2]], row[3], v)
                        imported = imported + 1
                    else
                        skipped = skipped + 1
                    end
                end
            end
            sv.profiles[name] = profile
        end
    end
    if type(legacy.profileKeys) == "table" then
        for char, name in pairs(legacy.profileKeys) do
            if type(char) == "string" and type(name) == "string" and sv.profiles[name] and not sv.profileKeys[char] then
                sv.profileKeys[char] = name
            end
        end
    end
    Mg.legacyReport = { imported = imported, skipped = skipped }
end

Mg.steps = {
    { version = 1, run = importLegacy },
}

function Mg:Run(sv)
    for _, step in ipairs(self.steps) do
        if sv.schema < step.version then
            ns.SafeCall(step.run, sv)
            sv.schema = step.version
        end
    end
    -- Legacy tables are dropped from disk once read (they stay listed in the TOC for one release).
    Phoenix_UIDB, Phoenix_UIPerCharDB = nil, nil
end
