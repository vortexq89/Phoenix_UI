local _, ns = ...
local Style = ns.Style

--[[ CombatText: the combat-log driven scrolling text of 11.x cannot exist in 12.x (COMBAT_LOG_EVENT
    is unavailable to addons). Blizzard's floating combat text v2 is the native replacement; this
    page gathers its CVars in one place (account CVars, not profile data).
    S16 adds, as profile settings:
    * the floating damage font: the client reads the DAMAGE_TEXT_FONT global once, at login (only C reads
      it, no FrameXML Lua does), so it is set here at load and needs a relog;
    * Phoenix scroll areas (Scroll.lua): our own scrolling text for what the game still tells addons. ]]
local M = ns:NewModule("CombatText", {
    label = "COMBATTEXT", desc = "COMBATTEXT_DESC", category = "combat", order = 20, locked = true,
    defaults = {
        damageFont = "",
        scroll = {
            enabled = false, merge = true, crit = "grow", font = Style.Text(18, { outline = "OUTLINE" }),
            areas = {
                incoming = { show = true, x = -280, y = 40, height = 220, dir = "UP" },
                target = { show = false, x = 280, y = 40, height = 220, dir = "UP" },
                notify = { show = true, x = 0, y = 220, height = 110, dir = "UP" },
            },
        },
    },
})

function M:OnInitialize()
    if self.db.damageFont ~= "" then DAMAGE_TEXT_FONT = ns.Media:Font(self.db.damageFont) end -- luacheck: ignore 121 (read by C only)
end

function M:OnEnable() self:EnableScroll() end
function M:Refresh() self:EnableScroll() end
