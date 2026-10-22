local _, ns = ...
local L, Opt = ns.L, ns.Opt

local dmGet, dmSet = ns.Combat.CVarAccessors("damageMeterEnabled")
local function unskinned(m) return not m.db.skin end
local function noBg(m) return unskinned(m) or not m.db.bg.show end
local function skinned(row) return Opt.With(row, { disabled = row.disabled or unskinned }) end

-- Bar height and spacing, class colours, number format, spec icons, visibility and extra windows are the
-- meter's Edit Mode settings: one button opens them (the skin never calls the meter's own setters).
local function openEditMode() ns.Config.frame:Hide(); ns.EditMode:Open() end

ns:RegisterOptions("DamageMeter", {
    { type = "preview", kind = "damagemeter" },
    { type = "header", label = "BLIZZARD_FEATURES", icon = "general" },
    { type = "toggle", label = "DM_ENABLE", desc = "DM_ENABLE_DESC", get = dmGet, set = dmSet, combat = true, keywords = "dps meter" },
    { type = "header", label = "DM_STYLE", icon = "theme" },
    { type = "toggle", key = "skin", label = "DM_SKIN", desc = "DM_SKIN_DESC", reload = true },
    { type = "header", label = "DM_BARS", icon = "damagemeter" },
    skinned({ type = "texture", key = "bar.texture", label = "DM_BAR_TEXTURE", desc = "DM_BAR_TEXTURE_DESC", allowDefault = true,
      keywords = "bar texture statusbar" }),
    skinned({ type = "toggle", key = "bar.reverse", label = "CB_REVERSE", desc = "DM_REVERSE_DESC",
      keywords = "fill direction right left" }),
    skinned({ type = "range", key = "bar.shade", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.8, step = 0.05,
      keywords = "gradient shade depth" }),
    skinned(Opt.Text("name", "DM_NAME_FONT", { min = 8, max = 24 })),
    skinned(Opt.Text("value", "DM_VALUE_FONT", { min = 8, max = 24 })),
    { type = "header", label = "DM_WINDOW", icon = "skins" },
    skinned({ type = "toggle", gate = true, key = "bg.show", label = "DM_BG", desc = "DM_BG_DESC", keywords = "background window" }),
    Opt.With(Opt.Background("bg", "DM_BG_OPACITY", "bg.base"), { disabled = noBg }),
    skinned(Opt.Border("border", "DM_BORDER", "border.subtle")),
    { type = "header", label = "DM_EDIT_MODE", icon = "editmode" },
    { type = "description", text = "DM_EDIT_MODE_TEXT" },
    { type = "button", label = "DM_EDIT_MODE_OPEN", desc = "DM_EDIT_MODE_OPEN_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      combat = true, func = openEditMode,
      keywords = "bar height spacing class colours number format spec icons visibility combat group second window" },
    { type = "header", label = "DM_DETAILS", icon = "damagemeter" },
    { type = "description", text = "DM_DETAILS_TEXT" },
    { type = "button", label = "DM_DETAILS_APPLY", desc = "DM_DETAILS_APPLY_DESC", button = "APPLY", variant = "primary",
      disabled = function(m) return not m:DetailsLoaded() end,
      func = function(m)
          local ok, count = m:ApplyDetails()
          ns.Config:SetStatus(ok and L.DM_DETAILS_DONE:format(count) or L.DM_DETAILS_MISSING, ok and "state.success" or "state.danger")
      end },
})
