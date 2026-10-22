local _, ns = ...

local Opt = ns.Opt
local function unskinned(m) return not m.db.skin end
local function noFonts(m) return not m.db.fonts end

ns:RegisterOptions("Tooltip", {
    { type = "preview", kind = "tooltip" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "TOOLTIP_STYLE", icon = "theme" },
    { type = "toggle", gate = true, key = "skin", label = "TOOLTIP_SKIN", desc = "TOOLTIP_SKIN_DESC", reload = true },
    Opt.With(Opt.Background("backdrop", nil, "bg.raised"), { disabled = unskinned }),
    Opt.With(Opt.Border("border", nil, "border.strong"), { disabled = unskinned }),
    { type = "toggle", key = "healthBar", label = "TOOLTIP_HEALTHBAR", desc = "TOOLTIP_HEALTHBAR_DESC", reload = true,
      cog = {
          { type = "texture", key = "barTexture", label = "BAR_TEXTURE", allowDefault = true },
          { type = "range", key = "barHeight", label = "TOOLTIP_BAR_HEIGHT", min = 2, max = 12, step = 1 },
      } },
    { type = "toggle", key = "classBorder", label = "TOOLTIP_CLASS_BORDER", desc = "TOOLTIP_CLASS_BORDER_DESC" },
    { type = "toggle", key = "qualityBorder", label = "TOOLTIP_QUALITY_BORDER", desc = "TOOLTIP_QUALITY_BORDER_DESC" },
    { type = "header", label = "TOOLTIP_TEXT", icon = "fonts" },
    { type = "toggle", key = "fonts", label = "TOOLTIP_FONTS", desc = "TOOLTIP_FONTS_DESC", reload = true },
    Opt.Text("header", "TOOLTIP_HEADER_FONT", { max = 24, row = { disabled = noFonts } }),
    Opt.Text("body", "TOOLTIP_BODY_FONT", { max = 20, row = { disabled = noFonts } }),
    { type = "tab", label = "TAB_CONTENT" },
    { type = "header", label = "TOOLTIP_BEHAVIOUR", icon = "cog" },
    { type = "select", key = "anchor", label = "TOOLTIP_ANCHOR", desc = "TOOLTIP_ANCHOR_DESC", values = {
        { value = "DEFAULT", label = "TOOLTIP_ANCHOR_DEFAULT" }, { value = "CURSOR", label = "TOOLTIP_ANCHOR_CURSOR" },
    }, keywords = "mouse" },
    { type = "toggle", key = "hideInCombat", label = "TOOLTIP_HIDE_COMBAT", desc = "TOOLTIP_HIDE_COMBAT_DESC" },
    { type = "header", label = "TOOLTIP_LINES", icon = "tooltip" },
    { type = "toggle", key = "target", label = "TOOLTIP_TARGET", desc = "TOOLTIP_TARGET_DESC" },
    { type = "toggle", key = "role", label = "TOOLTIP_ROLE", desc = "TOOLTIP_ROLE_DESC" },
    { type = "toggle", key = "mplusRating", label = "TOOLTIP_MPLUS", desc = "TOOLTIP_MPLUS_DESC", feature = "mythicplus",
      keywords = "mythic plus score rating io keystone" },
    { type = "toggle", key = "simLine", label = "TOOLTIP_SIM", desc = "TOOLTIP_SIM_DESC", feature = "sim",
      keywords = "simulationcraft simc dps upgrade sim" },
    { type = "toggle", key = "ids", label = "TOOLTIP_IDS", desc = "TOOLTIP_IDS_DESC", keywords = "spellid itemid idtip" },
})
