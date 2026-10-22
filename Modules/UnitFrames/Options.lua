local _, ns = ...
local Opt = ns.Opt

local function noFonts(m) return not m.db.fonts end
local function isPet(_, unit) return unit == "pet" end
local function noAuras(m) return not m.db.auras.style end

local PORTRAIT = {
    { value = "game", label = "UF_PORTRAIT_GAME" }, { value = "class", label = "UF_PORTRAIT_CLASS" },
    { value = "hide", label = "UF_PORTRAIT_HIDE" },
}

local function toggleTest(m)
    if not m:IsEnabled() then return end
    if not m:ShowTest(not m.testShown) then ns.Config:SetStatus(ns.L.UF_TEST_COMBAT, "state.warning", "warning") end
end

ns:RegisterOptions("UnitFrames", {
    { type = "scope", key = "units", label = "UF_FRAME", values = {
        { value = "player", label = "UF_PLAYER" }, { value = "target", label = "UF_TARGET" },
        { value = "focus", label = "UF_FOCUS" }, { value = "pet", label = "UF_PET" },
        { value = "boss", label = "UF_BOSS" },
    } },
    { type = "preview", kind = "unitframe" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "UF_TESTING" },
    { type = "button", label = "UF_TEST", desc = "UF_TEST_DESC", button = "UF_TEST_BUTTON", icon = "test", func = toggleTest,
      keywords = "test mode fake frames boss" },
    { type = "header", label = "UF_BARS" },
    { type = "toggle", key = "texture", label = "UF_TEXTURE", desc = "UF_TEXTURE_DESC", reload = true },
    { type = "texture", key = "units.@.texture", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return not m.db.texture end, keywords = "statusbar texture" },
    Opt.Border("units.@.border", "UF_HEALTH_BORDER"),
    Opt.Background("units.@.background"),
    { type = "header", label = "UF_COLORS" },
    { type = "toggle", key = "classColor", label = "UF_CLASSCOLOR", desc = "UF_CLASSCOLOR_DESC", keywords = "class colour health" },
    { type = "toggle", key = "powerColor", label = "UF_POWERCOLOR", desc = "UF_POWERCOLOR_DESC" },
    { type = "header", label = "UF_PORTRAIT_ICONS" },
    { type = "select", key = "units.@.portrait", label = "UF_PORTRAIT", desc = "UF_PORTRAIT_DESC", values = PORTRAIT,
      keywords = "portrait class icon face" },
    { type = "toggle", key = "units.@.icons.leader", label = "UF_ICON_LEADER", hidden = isPet },
    { type = "toggle", key = "units.@.icons.marker", label = "UF_ICON_MARKER", hidden = isPet, keywords = "raid target skull" },
    { type = "toggle", key = "units.@.icons.pvp", label = "UF_ICON_PVP", hidden = isPet },
    { type = "header", label = "UF_RANGE" },
    { type = "toggle", key = "range.enabled", label = "UF_RANGE_FADE", desc = "UF_RANGE_FADE_DESC", keywords = "out of range alpha fade",
      cog = { { type = "range", key = "range.alpha", label = "UF_RANGE_ALPHA", min = 0.1, max = 0.9, step = 0.05, percent = true } } },
    { type = "header", label = "UF_AURAS" },
    { type = "toggle", key = "auras.style", label = "UF_AURAS_STYLE", desc = "UF_AURAS_STYLE_DESC",
      keywords = "buffs debuffs aura icons", reload = true,
      cog = { { type = "range", key = "auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } },
    Opt.With(Opt.Border("auras.border"), { disabled = noAuras }),
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "UF_TEXT", wide = true },
    { type = "toggle", key = "fonts", label = "UF_FONTS", desc = "UF_FONTS_DESC", reload = true },
    Opt.Text("units.@.name", "UF_NAME_FONT", { row = { disabled = noFonts } }),
    Opt.Text("units.@.health", "UF_HEALTH_FONT", { row = { disabled = noFonts } }),
    Opt.Text("units.@.power", "UF_POWER_FONT", { row = { disabled = noFonts } }),
    Opt.Text("auras.count", "UF_AURA_COUNT_FONT", { max = 20, row = { disabled = noAuras } }),
    { type = "description", text = "UF_EDITMODE_NOTE" },
    { type = "description", text = "UF_ARENA_NOTE" },
})
