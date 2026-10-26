local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Media, Schema = PUI.Tests, PUI.Media, PUI.Schema

Tests:Add("Media", "library registers every kind with pickers and previews", function(t)
  for _, kind in ipairs({ "font", "statusbar", "background", "border", "glow", "icon", "sound" }) do
    t:ok(Media:Count(kind) > 3, kind .. " entries: " .. Media:Count(kind))
  end
  t:ok(Media:Path("font", "Noto Sans Arabic"), "Arabic font")
  t:ok(Media:Path("font", "Noto Sans SC") and Media:Path("font", "Noto Sans KR") and Media:Path("font", "Noto Sans JP"), "CJK fonts")
  t:eq(Media:Meta("font", "Cairo").licence, "SIL OFL 1.1", "licence carried to pickers")
  t:eq(Schema:Def("bars.texture").preview, "statusbar", "bar picker previews")
  local choices = Schema:Def("bars.texture").choices()
  t:ok(#choices > 20, "bar choices include the library")
  local saved = Schema:Get("bars.texture")
  t:cleanup(function() Schema:Set("bars.texture", saved) end)
  Schema:Set("bars.texture", "Gloss")
  t:ok(PUI.Bars:TexturePath():find("Phoenix_UI_Media", 1, true), "bars use the library texture live")
end)

Tests:Add("Media", "alert sound and LibSharedMedia bridge", function(t)
  local played = {}
  local savedFile, savedKit = PlaySoundFile, PlaySound
  t:cleanup(function() PlaySoundFile, PlaySound = savedFile, savedKit; Schema:Set("media.alertSound", "None") end)
  PlaySoundFile = function(p) played[#played + 1] = p end
  PlaySound = function(k) played[#played + 1] = k end
  Media:Alert(42)
  t:eq(played[1], 42, "None keeps the module sound")
  Schema:Set("media.alertSound", "Interface Sounds: Confirmation 1")
  Media:Alert(42)
  t:ok(type(played[2]) == "string" and played[2]:find("KIS_confirmation_001", 1, true), "picked sound plays")
  local got = {}
  local fake = { Register = function(_, kind, name, path) got[#got + 1] = kind .. "|" .. name end, LOCALE_BIT_western = 1, LOCALE_BIT_ruRU = 2 }
  local savedStub = rawget(_G, "LibStub")
  rawset(_G, "LibStub", function() return fake end)
  t:cleanup(function() rawset(_G, "LibStub", savedStub) end)
  t:ok(Media:ShareAll(), "shared when the library exists")
  local fonts, icons = 0, 0
  for i = 1, #got do
    if got[i]:find("^font|Phoenix: ") then fonts = fonts + 1 end
    if got[i]:find("^icon|") then icons = icons + 1 end
  end
  t:ok(fonts >= Media:Count("font"), "fonts registered with LibSharedMedia")
  t:eq(icons, 0, "Phoenix-only kinds stay private")
end)
