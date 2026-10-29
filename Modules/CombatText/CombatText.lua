local _, ns = ...
local Style = ns.Style

--[[ CombatText: the combat-log driven scrolling text of 11.x cannot exist in 12.x (COMBAT_LOG_EVENT
    is unavailable to addons). Blizzard's floating combat text v2 is the native replacement; this
    page gathers its CVars in one place (account CVars, not profile data).
    S16 adds, as profile settings:
    * the floating damage font: the client reads the DAMAGE_TEXT_FONT global once, at login (only C reads
      it, no FrameXML Lua does), so it is set here at load and needs a relog;
    * Phoenix scrolling combat text (Scroll.lua): four areas, four animations, per-event routing, colours, sizes
      and sounds, merging, throttling and crit handling, for what the game still tells addons. ]]
local M = ns:NewModule("CombatText", {
    label = "COMBATTEXT", desc = "COMBATTEXT_DESC", category = "combat", order = 20, locked = true,
    defaults = {
        damageFont = "",
        scroll = {
            enabled = false, merge = true, mergeWindow = 0.35, throttle = 0, onlyCombat = false,
            crit = "sticky", critScale = 1.5, critArea = "same", critSound = "",
            castIcons = true,
            -- the MSBT-style look: a bold condensed face, thick outline and a drop shadow
            font = Style.Text(20, { font = "InterBold", outline = "THICK", shadow = true }),
            areas = {
                incoming = { show = true, x = -320, y = 60, width = 260, height = 240, dir = "UP", anim = "parabola", align = "RIGHT",
                    duration = 2.4, scale = 1, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 1, g = 0.3, b = 0.25 } },
                heals = { show = true, x = -320, y = -180, width = 260, height = 180, dir = "UP", anim = "parabola", align = "RIGHT",
                    duration = 2.4, scale = 1, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 0.3, g = 1, b = 0.35 } },
                target = { show = true, x = 320, y = 60, width = 260, height = 240, dir = "UP", anim = "parabola", align = "LEFT",
                    duration = 2.4, scale = 1, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 1, g = 0.95, b = 0.85 } },
                outheal = { show = true, x = 320, y = -180, width = 260, height = 180, dir = "UP", anim = "parabola", align = "LEFT",
                    duration = 2.4, scale = 1, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 0.3, g = 1, b = 0.35 } },
                power = { show = true, x = 0, y = -240, width = 240, height = 120, dir = "UP", anim = "straight", align = "CENTER",
                    duration = 2.4, scale = 0.85, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 0.3, g = 0.6, b = 1 } },
                notify = { show = true, x = 0, y = 230, width = 340, height = 110, dir = "UP", anim = "straight", align = "CENTER",
                    duration = 2.4, scale = 0.9, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 1, g = 0.85, b = 0.4 } },
                crits = { show = false, x = 0, y = 90, width = 320, height = 110, dir = "UP", anim = "static", align = "CENTER",
                    duration = 2.4, scale = 1.2, iconSide = "LEFT", iconSize = 22, useColor = false, color = { r = 1, g = 0.82, b = 0 } },
            },
            events = {
                damage = { show = true, area = "incoming", color = { r = 1, g = 0.3, b = 0.25 }, scale = 1, sound = "" },
                spell = { show = true, area = "incoming", color = { r = 1, g = 0.45, b = 0.2 }, scale = 1, sound = "" },
                shield = { show = true, area = "incoming", color = { r = 0.9, g = 0.8, b = 0.3 }, scale = 0.85, sound = "" },
                heal = { show = true, area = "heals", color = { r = 0.3, g = 1, b = 0.35 }, scale = 1, sound = "" },
                hot = { show = true, area = "heals", color = { r = 0.45, g = 0.9, b = 0.45 }, scale = 0.8, sound = "" },
                avoid = { show = true, area = "incoming", color = { r = 1, g = 1, b = 1 }, scale = 0.9, sound = "" },
                buff = { show = true, area = "notify", color = { r = 1, g = 0.85, b = 0.4 }, scale = 1, sound = "" },
                debuff = { show = true, area = "notify", color = { r = 1, g = 0.4, b = 0.4 }, scale = 1, sound = "" },
                fade = { show = true, area = "notify", color = { r = 0.7, g = 0.7, b = 0.7 }, scale = 0.85, sound = "" },
                reactive = { show = true, area = "notify", color = { r = 1, g = 0.82, b = 0 }, scale = 1.2, sound = "" },
                honor = { show = true, area = "notify", color = { r = 0.85, g = 0.5, b = 1 }, scale = 1, sound = "" },
                rep = { show = true, area = "notify", color = { r = 0.5, g = 0.6, b = 1 }, scale = 1, sound = "" },
                hit = { show = true, area = "target", color = { r = 1, g = 0.95, b = 0.85 }, scale = 1, sound = "" },
                p_mana = { show = true, area = "power", color = { r = 0, g = 0.55, b = 1 }, scale = 1, sound = "" },
                p_rage = { show = true, area = "power", color = { r = 1, g = 0.2, b = 0.2 }, scale = 1, sound = "" },
                p_focus = { show = true, area = "power", color = { r = 1, g = 0.5, b = 0.25 }, scale = 1, sound = "" },
                p_energy = { show = true, area = "power", color = { r = 1, g = 0.9, b = 0.2 }, scale = 1, sound = "" },
                p_runic_power = { show = true, area = "power", color = { r = 0, g = 0.82, b = 1 }, scale = 1, sound = "" },
                p_insanity = { show = true, area = "power", color = { r = 0.6, g = 0.2, b = 1 }, scale = 1, sound = "" },
                p_fury = { show = true, area = "power", color = { r = 0.8, g = 0.25, b = 1 }, scale = 1, sound = "" },
                p_pain = { show = true, area = "power", color = { r = 1, g = 0.61, b = 0 }, scale = 1, sound = "" },
                p_maelstrom = { show = true, area = "power", color = { r = 0, g = 0.5, b = 1 }, scale = 1, sound = "" },
                p_lunar_power = { show = true, area = "power", color = { r = 0.3, g = 0.52, b = 0.9 }, scale = 1, sound = "" },
                p_combo_points = { show = true, area = "power", color = { r = 1, g = 0.96, b = 0.41 }, scale = 1, sound = "" },
                p_holy_power = { show = true, area = "power", color = { r = 0.95, g = 0.9, b = 0.6 }, scale = 1, sound = "" },
                p_soul_shards = { show = true, area = "power", color = { r = 0.58, g = 0.4, b = 0.75 }, scale = 1, sound = "" },
                p_chi = { show = true, area = "power", color = { r = 0.71, g = 1, b = 0.92 }, scale = 1, sound = "" },
                p_arcane_charges = { show = true, area = "power", color = { r = 0.45, g = 0.55, b = 1 }, scale = 1, sound = "" },
                p_essence = { show = true, area = "power", color = { r = 0.3, g = 0.9, b = 0.8 }, scale = 1, sound = "" },
                theal = { show = true, area = "outheal", color = { r = 0.3, g = 1, b = 0.35 }, scale = 0.9, sound = "" },
            },
        },
    },
})

function M:OnInitialize()
    if self.db.damageFont ~= "" then DAMAGE_TEXT_FONT = ns.Media:Font(self.db.damageFont) end -- luacheck: ignore 121 (read by C only)
end

function M:OnEnable() self:EnableScroll() end
function M:Refresh() self:EnableScroll() end
