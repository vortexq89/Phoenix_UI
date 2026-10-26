local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Assets: every design texture the options window, wizard and Studio use
-- (Phoenix_UI_Media, design spec section 9). Full literal paths so the media
-- guardrail checks each one exists.
local Options = PUI.Options
local A = {
  panel = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Panel_R28",
  card = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Card_R24",
  control = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Control_R16",
  primary = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Button_Primary_R16",
  secondary = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Button_Secondary_R16",
  border1 = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Border_1px",
  borderSoft = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Border_Soft",
  shadow = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Shadow_Soft",
  shadowTight = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Shadow_Tight",
  glass = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Panel\\ObsidianGlass",
  hero = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Art\\Hero_Backdrop",
  logo = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Logo\\Logo_Full_512",
  glyph = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Logo\\Logo_Glyph_256",
  knob = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Knob",
  toggleTrack = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Toggle_Track",
  sliderTrack = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Slider_Track",
  thumbRing = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Thumb_Ring",
  chevron = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Chevron_Down",
  check = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Checkbox_Check",
  radial = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Glow\\Radial",
  hover = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Glow\\Hover",
  outline = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Glow\\TargetOutline",
  presets = {
    classic = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Art\\Preset_EmberClassic",
    healer = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Art\\Preset_HealerFocus",
    minimal = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Art\\Preset_MinimalAsh",
  },
  abilities = {
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_essence_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_renew_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_envelop_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_vivify_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_lotus_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_kick_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_tea_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_shield_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_cocoon_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_roll_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_fist_64",
    "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Abilities\\ab_chiji_64",
  },
}
Options.Assets = A

-- Module icons (64 colour + disabled grey), by design icon name.
local ICONS = {}
for _, n in ipairs({ "actionbars", "arena", "ascent", "chat", "clickcast", "cooldowns", "dashboard", "databars", "embers",
  "flow", "general", "groupfinder", "loadouts", "locales", "minimap", "nameplates", "oracle", "profiles", "pulse", "quests",
  "raid", "reminders", "resource", "sentinel", "setup", "skins", "spark", "studio", "theme", "tooltip", "unitframes",
  "vault", "wisdom" }) do
  ICONS[n] = true
end
A.ICON_NAMES = ICONS
-- guardrail anchors for the two icon folders the names below resolve into:
A.iconDir = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Modules\\64\\dashboard"
A.iconDirOff = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Modules\\Disabled\\dashboard_64"

function A.Icon(name, disabled)
  if not ICONS[name] then name = "general" end
  local path = (disabled and A.iconDirOff or A.iconDir):gsub("dashboard", name, 1)
  return path
end
