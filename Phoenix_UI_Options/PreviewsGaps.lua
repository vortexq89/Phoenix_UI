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

-- Gaps 2 previews --------------------------------------------------------------------------------------------
-- add(owner, fn): extends the page's own preview, or becomes it when the page has none.
local function add(owner, fn)
  if type(Previews[owner]) == "function" then return PX.extend(owner, fn) end
  Previews[owner] = function(card, tab) hide(card); fn(card, tab) end
end
G.Add = add
local function get(k) return Schema:Get(k) end

add("Core", function(card)
  G.Lines(card, "cq", { "Combat notices", "Say when a change waits: " .. on(get("core.combatToast")),
    "Sample: \"Bar layout: waits until combat ends\"", "Shown for " .. get("core.combatToastSeconds") .. " s" })
  local t = tex(card, "cqBar")
  t:SetSize(3, 18); t:SetPoint("TOPRIGHT", card, "TOPRIGHT", -190, -42); t:SetColorTexture(Theme:Color("warn"))
end)

add("Cursor", function(card)
  local g = PUI.Gaps and PUI.Gaps.s
  if not g then return end
  G.Lines(card, "cu", { "Cursor ring", "Ring: " .. on(g.ring) .. (g.ringCombat and " (in combat)" or ""), "Style " .. g.ringStyle .. ", colour " .. g.ringColor .. ", dot " .. on(g.ringDot) }, true)
  local t = tex(card, "cuRing")
  t:SetSize(g.ringSize, g.ringSize); t:SetPoint("CENTER", card, "CENTER", 0, -20)
  t:SetTexture(MEDIA .. "Textures\\" .. (PUI.Gaps.Ring.STYLES[g.ringStyle] or PUI.Gaps.Ring.STYLES.ring))
  t:SetVertexColor(PUI.Gaps.Ring.Color()); t:SetAlpha(g.ring and 1 or 0.35)
  local d = tex(card, "cuDot")
  d:SetSize(g.ringSize / 4, g.ringSize / 4); d:SetPoint("CENTER", t, "CENTER"); d:SetTexture(MEDIA .. "Textures\\Cursor\\dot")
  d:SetVertexColor(PUI.Gaps.Ring.Color()); d:SetShown(g.ringDot)
end)

add("Celebrations", function(card)
  local g = PUI.Gaps and PUI.Gaps.s
  if not g then return end
  local reduced = PUI.Gaps.Celebrate.Reduced()
  G.Lines(card, "ce", { "Celebrations", "On: " .. on(g.celebrate) .. "   sound " .. on(g.celebrateSound),
    "Achievements " .. on(g.celebrateAchievements) .. ", keys " .. on(g.celebrateKeys) .. ", levels " .. on(g.celebrateLevels),
    reduced and "Reduced motion: banner only" or "Embers rise behind the banner" }, true)
  local band = tex(card, "ceBand")
  band:SetSize(260, 44); band:SetPoint("TOP", card, "TOP", 0, -100); band:SetColorTexture(0.05, 0.04, 0.04, 0.85)
  local line = tex(card, "ceLine")
  line:SetSize(260, 2); line:SetPoint("BOTTOM", band, "BOTTOM"); line:SetColorTexture(Theme:Color("accent"))
  local r, gg, b = Theme:Color("accent")
  for i = 1, 8 do
    local e = tex(card, "ceE" .. i)
    e:SetSize(8 + (i * 5) % 10, 8 + (i * 5) % 10)
    e:SetPoint("BOTTOM", band, "BOTTOM", -110 + i * 26, 10 + (i * 13) % 30)
    e:SetTexture(MEDIA .. "Textures\\Celebrate\\" .. (i % 3 == 0 and "spark" or "ember")); e:SetVertexColor(r, gg, b); e:SetShown(not reduced)
  end
end)

add("Nameplates", function(card)
  local s = PUI.Nameplates and PUI.Nameplates.settings
  if not (s and s.los) then return end
  G.Lines(card, "los", { "Out of sight", "Flash on a failed cast: " .. on(s.los.enabled), "Lasts " .. s.los.seconds .. " s, with an \"Out of sight\" tag" })
end)

add("GroupFinder", function(card)
  local s = PUI.GroupFinder and PUI.GroupFinder.settings
  if not s then return end
  local X = PUI.GroupFinder.Gaps
  G.Lines(card, "gfx", { "Raid rows and queues", "Sample: Liberation of Undermine" .. (s.bossesDown and " 3 down" or "") .. (s.ownLockout and "  you 5/8" or ""),
    "Oldest application age: " .. on(s.oldestAge) .. (X and X.CanCancel() and "   [Cancel oldest]" or ""),
    "Queue pop reminder: " .. on(s.popAlert) .. (s.popSound and " with sound" or "") })
end)

add("Tooltip", function(card)
  local X = PUI.Tooltip and PUI.Tooltip.Extras
  if not X then return end
  G.Lines(card, "cr", { "Crest calculator", "Track: Hero 3/6", X.CrestLine(3, 6, "Hero") or "(off)" })
end)

add("Studio", function(card)
  local g = PUI.Gaps and PUI.Gaps.s
  if not g then return end
  local saved = get("studio.editModeLayout")
  G.Lines(card, "em", { "Edit Mode layout", "Keep a copy in the profile: " .. on(g.editModeAutoSave),
    "Saved: " .. ((type(saved) == "table" and saved.name) or "nothing yet"), "Restore switches to it: " .. on(g.editModeActivate) }, true)
end)

add("Wisdom", function(card)
  G.Lines(card, "sc", { "SimC export (/pui simc)", "On: " .. on(get("wisdom.simc")) .. "   bag gear: " .. on(get("wisdom.simcBags")),
    'mage="Vorte"', "head=,id=212081,bonus_id=10356/1540", get("wisdom.simcBags") and "# trinket1=,id=219314" or "" }, true)
end)

add("RaidTools", function(card)
  local C = PUI.RaidTools and PUI.RaidTools.Council
  if not C then return end
  G.Lines(card, "co", { "Council", "On: " .. on(C.s.council) .. "   answers close after " .. C.s.councilSeconds .. " s",
    "Vorte  Need  642", "Ash  Minor  655", "Kael  Pass  660" })
end)

add("Pulse", function(card)
  local A = PUI.Pulse and PUI.Pulse.Sounds
  if not A then return end
  local list = A.s.auraSounds or {}
  local first = list[1] and A.Parse(list[1])
  G.Lines(card, "as", { "Aura sounds (" .. #list .. ")", first and (first.spellID .. " -> " .. first.sound .. " (" .. first.trigger .. ")") or "Example: 1234567: Alarm",
    "Channel " .. A.s.auraSoundChannel .. ", gap " .. A.s.auraSoundThrottle .. " s, watching " .. A.s.auraSoundUnit })
end)

add("Friends", function(card)
  G.Lines(card, "ig", { "In game only: " .. on(get("friends.wowOnly")), get("friends.sameGame") and "This game version only" or "Any World of Warcraft" })
end)

add("CooldownManager", function(card)
  G.Lines(card, "so", { "Skin only: " .. on(get("cdm.skinOnly")), get("cdm.skinOnly") and "Blizzard places the icons" or "Phoenix places the icons" })
end)

add("Embers", function(card)
  local D = PUI.Embers and PUI.Embers.Dock
  if not D then return end
  local s = D.s
  G.Lines(card, "dk", { "Windows: " .. s.dock .. (s.dock ~= "free" and (" (gap " .. s.dockGap .. ")") or ""),
    "Header fade: " .. on(s.fade) .. (s.fade and (" to " .. math.floor(s.fadeAlpha * 100) .. "%") or ""),
    "Wheel scroll: " .. on(s.wheel) .. (s.scrollLine and ", marker" or ", no bar"),
    "Header click: " .. (s.typeMenu and "type list" or "cycle"), "Blocked reports: " .. (get("embers.queueReport") and "posted later" or "refused") })
  if s.dock ~= "free" then
    for i = 1, 2 do
      local t = tex(card, "dkW" .. i)
      t:SetSize(60, 40)
      if s.dock == "row" then t:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14 - (2 - i) * (60 + s.dockGap), 40)
      else t:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 40 + (2 - i) * (40 + s.dockGap)) end
      t:SetColorTexture(Theme:Color("bg2"))
    end
  end
end)

add("UnitFrames", function(card)
  local list = get("uf.player.textSlots") or {}
  G.Lines(card, "ts", { "Extra texts (player): " .. #list, list[1] or "Add one: health:percent @ TOPRIGHT 0 10 14" })
end)

PX.extend("Colors", function(card)
  local s = Look.s
  G.Lines(card, "hg", { "Health by percent: " .. s.gradient .. ", middle " .. math.floor(s.gradientMid * 100) .. "%" })
  local cols = s.gradient == "theme" and { { Theme:Color("err") }, { Theme:Color("warn") }, { Theme:Color("ok") } } or { { 1, 0.1, 0.1 }, { 1, 0.85, 0.1 }, { 0.1, 0.9, 0.2 } }
  for i, c in ipairs(cols) do
    local t = tex(card, "hgC" .. i)
    t:SetSize(40, 8); t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 44, -170); t:SetColorTexture(c[1], c[2], c[3])
  end
end)

PX.extend("Theme", function(card)
  local s = Look.s
  G.Lines(card, "bd", { "Borders: " .. s.borderStyle .. (s.borderStyle == "pixel" and (" " .. s.borderSize .. " px") or "") })
end)

-- Blizzard's own meter in the Phoenix look: a sample window (bottom-left).
add("Embers", function(card)
  local B = PUI.Embers and PUI.Embers.BlizzSkin
  if not B then return end
  local s = B.s
  local x, y, w = 14, 40, 150
  local head = tex(card, "bmH")
  head:SetSize(w, 16); head:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", x, y + 3 * 14)
  local ar, ag, ab = Theme:Color("accent")
  local alpha = s.fade and s.fadeAlpha or 1
  head:SetColorTexture(ar * 0.22, ag * 0.22, ab * 0.22, 0.95 * alpha); head:SetShown(s.enabled)
  local fs = PX.Line(card, "bmT")
  fs:ClearAllPoints(); fs:SetPoint("LEFT", head, "LEFT", 4, 0)
  fs:SetText(s.enabled and ("Blizzard meter" .. (s.dock ~= "off" and (" - docked " .. s.dock) or "")) or "Blizzard meter: Blizzard look")
  fs:SetTextColor(0.95, 0.95, 0.95); fs:SetAlpha(alpha); fs:Show()
  local rows = { { "WARRIOR", 1 }, { "MAGE", 0.8 }, { "PRIEST", 0.55 } }
  for i, r in ipairs(rows) do
    local t = tex(card, "bmB" .. i)
    t:SetSize(w * r[2], 13); t:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", x, y + (3 - i) * 14)
    local cr, cg, cb = 0.8, 0.2, 0.2
    if s.classColors then cr, cg, cb = Look.ClassRGB(r[1]) end
    t:SetColorTexture(cr or 0.8, cg or 0.2, cb or 0.2, 0.9); t:SetShown(true)
  end
end)
