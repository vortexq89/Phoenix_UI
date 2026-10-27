local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for the review-gap settings (2026-10-27): the new Fonts,
-- Colours and Glows pages, the Theme page (themes, icon shapes, Phoenix
-- class/role icons and emoji), and sample lines on module pages that gained
-- settings. Display only: sample values, no unit reads, no protected frames.
local Options = PUI.Options
local PX, Previews = Options.PreviewsExtras, Options.Previews
local Theme, Look, Media, Schema = PUI.Theme, PUI.Look, PUI.Media, PUI.Schema
local G = {}
PX.Gaps = G

local function hide(card) for _, w in pairs(PX.Bag(card)) do w:Hide() end end
-- Lines at the card's top-right (module pages) or top-left (own pages).
function G.Lines(card, id, rows, left)
  local ar, ag, ab = Theme:Color("accent")
  for i = 1, 10 do
    local fs = PX.Line(card, id .. "G" .. i)
    fs:ClearAllPoints()
    local r = rows[i]
    if r then
      if left then fs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12 - (i - 1) * 16); fs:SetJustifyH("LEFT")
      else fs:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -12 - (i - 1) * 15); fs:SetJustifyH("RIGHT") end
      fs:SetText(r)
      if i == 1 then fs:SetTextColor(ar, ag, ab) else fs:SetTextColor(0.85, 0.85, 0.85) end
      fs:Show()
    else fs:Hide() end
  end
  return #rows
end
local function tex(card, id)
  local b = PX.Bag(card)
  if not b[id] then b[id] = card:CreateTexture(nil, "ARTWORK") end
  b[id]:ClearAllPoints(); b[id]:Show()
  return b[id]
end
G.Tex = tex
local function on(v) return v and "on" or "off" end

-- Fonts: specimens in the chosen fonts.
Previews.Fonts = function(card)
  hide(card)
  local s = Look.s
  G.Lines(card, "fo", { "Fonts", "", "", "", "Outline: " .. s.outline .. "   shadow " .. on(s.shadow), "Sizes: heading " .. s.headerSize .. ", body " .. s.bodySize .. ", small " .. s.smallSize }, true)
  local samples = {
    { "Phoenix UI heading", Media:Font(Schema:Get("media.uiFont")), s.headerSize },
    { "Window text 1,234,567", Media:Font(Schema:Get("media.uiFont")), s.bodySize },
    { "Quest: Embers of the Phoenix (3/5)", Look.FontFor("quests"), 12 },
    { "Meter: 1. Vorte  412.3K", Look.FontFor("meter"), 12 },
  }
  for i, sm in ipairs(samples) do
    local fs = PX.Line(card, "foS" .. i)
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -34 - (i - 1) * 22)
    if fs.SetFont then fs:SetFont(sm[2], sm[3], Look.Flags()) end
    fs:SetText(sm[1]); fs:SetTextColor(1, 1, 1)
  end
end

-- Colours: class and power swatches, palette state chips.
Previews.Colors = function(card)
  hide(card)
  local s = Look.s
  G.Lines(card, "co", { "Colours", "Class colours" .. (s.classOverride and " (yours)" or " (game)"), "", "", "Power bars", "", "", "Palette: " .. s.palette .. "  good / warning / bad / hostile / friendly" }, true)
  for i, c in ipairs(Look.CLASSES) do
    local t = tex(card, "coC" .. i)
    t:SetSize(18, 18); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 22, -50)
    t:SetColorTexture(Look.ClassRGB(c))
  end
  for i, p in ipairs(Look.POWERS) do
    local t = tex(card, "coP" .. i)
    t:SetSize(18, 8); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 22, -98)
    local r, g, b = Look.PowerRGB(p)
    if r then t:SetColorTexture(r, g, b) else local d = Look.POWER_DEFAULTS[p]; t:SetColorTexture(d[1], d[2], d[3]) end
  end
  local chips = { { Theme:Color("ok") }, { Theme:Color("warn") }, { Theme:Color("err") }, { Look.ReactionRGB("hostile") }, { Look.ReactionRGB("friendly") } }
  for i, c in ipairs(chips) do
    local t = tex(card, "coS" .. i)
    t:SetSize(30, 12); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 36, -140)
    t:SetColorTexture(c[1], c[2], c[3])
  end
end

-- Glows: a live sample button glowing with the global settings.
Previews.Glows = function(card)
  hide(card)
  local s = Look.s
  G.Lines(card, "gl", { "Glows", "Thickness " .. s.thickness .. " px, speed x" .. s.speed, "Colour: " .. (s.accentGlow and "theme accent" or "each glow's own"),
    "Motion: " .. (s.reducedMotion and "reduced (solid)" or "pulsing") }, true)
  local b = PX.Bag(card)
  local f = b.glSample
  if not f then
    f = CreateFrame("Frame", nil, card); b.glSample = f
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(); f.icon:SetColorTexture(0.2, 0.22, 0.28, 1)
  end
  f:ClearAllPoints(); f:SetSize(40, 40); f:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -90); f:Show()
  PUI.Glow:Start(f, "pulse", { r = 1, g = 0.78, b = 0.25, a = 1 })
end

-- Theme: surfaces, icon shape, Phoenix class/role icons and emoji.
local MEDIA = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\"
Previews.Theme = function(card)
  hide(card)
  local s = Look.s
  G.Lines(card, "th", { "Theme: " .. s.theme, "", "", "Icon shape: " .. s.shape, "", "", "Class " .. s.classIcons .. ", role " .. s.roleIcons .. " icons", "", "", "Emoji (chat :name:)" }, true)
  for i, tk in ipairs({ "bg0", "bg1", "bg2", "bg3", "line", "accent" }) do
    local t = tex(card, "thS" .. i)
    t:SetSize(26, 18); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 30, -32)
    t:SetColorTexture(Theme:Color(tk))
  end
  for i = 1, 4 do
    local t = tex(card, "thI" .. i)
    t:SetSize(28, 28); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 34, -78)
    t:SetTexture(MEDIA .. "Icons\\Abilities\\" .. ({ "ab_kick_64", "ab_shield_64", "ab_renew_64", "ab_lotus_64" })[i])
    Look.Shape(t, card)
  end
  local icons = { "Classes\\mage", "Classes\\druid", "Classes\\warrior", "Roles\\tank", "Roles\\healer", "Roles\\damager" }
  for i, p in ipairs(icons) do
    local t = tex(card, "thC" .. i)
    t:SetSize(22, 22); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 26, -128)
    t:SetTexture(MEDIA .. "Icons\\" .. p)
  end
  for i, n in ipairs(Look.EMOJI) do
    local t = tex(card, "thE" .. i)
    t:SetSize(18, 18); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + ((i - 1) % 8) * 22, -176 - math.floor((i - 1) / 8) * 22)
    t:SetTexture(Look.EmojiPath(n))
  end
end

PX.extend("RaidFrames", function(card)
  local s = PUI.RaidFrames and PUI.RaidFrames.settings
  if not s then return end
  G.Lines(card, "rf", { "Extra frames", "Pets: " .. on(s.pets) .. "   Party targets: " .. on(s.partyTargets),
    "Extra block: " .. (s.extraRole == "off" and "off" or (s.extraRole .. "s")), "Grid Mode: " .. on(s.gridMode) .. (s.gridMode and " (shared outline)" or "") })
end)
