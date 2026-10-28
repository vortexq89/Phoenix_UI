local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Arabic shaping layer (Core/Shaper.lua) and the
-- language font switch (Core/Locale.lua).
local Tests, S, Locale, Schema = PUI.Tests, PUI.Shaper, PUI.Locale, PUI.Schema

local function codes(s)
  local t = {}
  for _, c in ipairs(S.decode(s)) do t[#t + 1] = string.format("%04X", c) end
  return table.concat(t, " ")
end

Tests:Add("Shaper", "joining forms: isolated, initial, medial, final", function(t)
  t:eq(codes(S.Shape("\216\168")), "FE8F", "isolated beh")
  t:eq(codes(S.Shape("\216\168\216\168")), "FE91 FE90", "initial + final")
  t:eq(codes(S.Shape("\216\168\216\168\216\168")), "FE91 FE92 FE90", "medial in the middle")
  t:eq(codes(S.Shape("\216\175\216\168")), "FEA9 FE8F", "dal never joins forward")
  t:eq(codes(S.Shape("\216\168\217\142\216\168")), "FE91 064E FE90", "harakat are transparent")
end)

Tests:Add("Shaper", "lam-alef ligatures", function(t)
  t:eq(codes(S.Shape("\217\132\216\167")), "FEFB", "isolated lam-alef")
  t:eq(codes(S.Shape("\216\179\217\132\216\167\217\133")), "FEB3 FEFC FEE1", "final lam-alef after a joining letter")
  t:eq(codes(S.Shape("\217\132\216\163")), "FEF7", "lam + alef with hamza above")
end)

Tests:Add("Shaper", "visual order: Arabic reversed, Latin and numbers kept", function(t)
  t:eq(codes(S.Visual("\216\179\217\132\216\167\217\133")), "FEE1 FEFC FEB3", "reversed for right-to-left")
  local v = S.Visual("\216\167\216\179\216\170\216\174\216\175\217\133 /pui test \216\167\217\132\216\162\217\134")
  t:ok(v:find("/pui test", 1, true) ~= nil, "Latin run keeps its order")
  t:ok(S.Visual("\216\167\217\132\217\130\217\138\217\133\216\169 12.5"):find("12.5", 1, true) ~= nil, "decimal number intact")
  t:eq(S.Visual("plain English"), "plain English", "text without Arabic is unchanged")
  t:ok(S.Visual("\216\167\217\132\217\130\217\138\217\133\216\169 (5)"):find("(5)", 1, true) ~= nil, "brackets mirror")
end)

Tests:Add("Shaper", "format tokens and escapes survive", function(t)
  local v = S.Visual("\216\167\217\132\216\173\216\172\217\133 %d \216\168\217\131\216\179\217\132 \217\136 %.1f \217\136 %s")
  t:ok(v:find("%1$d", 1, true) and v:find("%2$.1f", 1, true) and v:find("%3$s", 1, true), "format specs intact, numbered for right-to-left")
  t:ok(S.Visual("\216\167\217\132\217\130\217\138\217\133\216\169 %d"):find("%d", 1, true) ~= nil, "a single spec stays as it is")
  local out = string.format(v, 3, 1.5, "x")
  local _, n = out:gsub("x", "")
  t:ok(out:find("1.5", 1, true) and out:find("3", 1, true), "positional specs keep each value in its place")
  t:eq(n, 1, "still formats")
  local c = S.Visual("|cffff0000\216\170\216\173\216\176\217\138\216\177|r: \217\134\216\181")
  t:ok(c:find("|cffff0000", 1, true) and c:find("|r", 1, true) and c:find("|cffff0000", 1, true) < c:find("|r", 1, true), "colour span stays balanced")
  local tex = S.Visual("\216\177\217\133\216\178 |TInterface\\Icons\\INV_Misc_QuestionMark:16|t \217\135\217\134\216\167")
  t:ok(tex:find("|TInterface\\Icons\\INV_Misc_QuestionMark:16|t", 1, true) ~= nil, "texture escape intact")
  local nl = S.Visual("\216\179\216\183\216\177\n\216\171\216\167\217\134\217\138", 0)
  t:ok(nl:find("\n", 1, true) ~= nil, "line breaks kept, lines stay top to bottom")
  t:eq(codes(nl:match("^(.-)\n")), codes(S.Visual("\216\179\216\183\216\177", 0)), "first line first")
end)

Tests:Add("Shaper", "long lines are broken before reversal", function(t)
  local long = string.rep("\217\131\217\132\217\133\216\169 ", 30)
  local v = S.Visual(long)
  local lines = 0
  for _ in (v .. "\n"):gmatch("(.-)\n") do lines = lines + 1 end
  t:ok(lines >= 2, "wrapped into lines")
end)

Tests:Add("Shaper", "Arabic strings are shaped through PUI.L, language font follows live", function(t)
  Tests.Keep(t, "core.locale", "core.localeFont")
  Locale:Add("arSA", { ["PUITest shaper key"] = "\216\179\217\132\216\167\217\133" })
  t:cleanup(function() Locale.strings.arSA["PUITest shaper key"] = nil end)
  Schema:Set("core.locale", "arSA")
  t:eq(codes(PUI.L["PUITest shaper key"]), "FEE1 FEFC FEB3", "PUI.L returns visual text")
  local path = PUI.Media:Path("font", "Noto Sans Arabic")
  if path then
    Schema:Set("core.localeFont", true)
    t:eq(PUI.Media:Font("Friz Quadrata"), path, "Arabic font used")
    Schema:Set("core.localeFont", false)
    t:ok(PUI.Media:Font("Friz Quadrata") ~= path, "switch off applies live")
  end
  Schema:Set("core.locale", "enUS")
  t:eq(PUI.L["PUITest shaper key"], "PUITest shaper key", "English again")
end)
