local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Forever spellbook and talent skin (Forever.lua).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests = PUI.Tests
local SK = ns.SK
local Z = SK.Forever

local function stub(t, name, value)
  local old = rawget(_G, name)
  rawset(_G, name, value)
  t:cleanup(function() rawset(_G, name, old) end)
end

Tests:Add("Skins", "Forever talents: state from rank, max rank and availability", function(t)
  t:eq(Z.TalentState(5, 5, false), "max", "maxed")
  t:eq(Z.TalentState(2, 5, false), "chosen", "partly chosen")
  t:eq(Z.TalentState(0, 5, false), "open", "can be picked")
  t:eq(Z.TalentState(0, 5, true), nil, "locked")
  t:eq(Z.TalentState(nil, 5, false), nil, "no data")
  t:eq(Z.RankText("Rank 3"), "Rank 3", "rank text")
  t:eq(Z.RankText(nil), "", "no rank")
end)

Tests:Add("Skins", "Forever spellbook extra is chained and listed; retail never runs it", function(t)
  local found = false
  for _, n in ipairs(SK.WINDOW_EXTRAS.spellbook) do if n == "foreverRanks" then found = true end end
  t:ok(found, "foreverRanks is a spellbook extra")
  t:ok(PUI.Schema:Def("skins.player.foreverRanks") ~= nil, "schema key")
  if not PUI.IS_FOREVER then t:eq(Z.Wanted(UIParent), false, "off on retail") end
end)

Tests:Add("Skins", "Forever spell button and talent button: Phoenix parts, rank colour reverts", function(t)
  if not H then return end
  local id = "spellbook"
  SK.owned[id] = SK.owned[id] or {}
  local wasActive = SK.active
  SK.active = true
  t:cleanup(function() SK.active = wasActive end)
  local btn = CreateFrame("Button", "SpellButton1", UIParent)
  local sub = btn:CreateFontString()
  stub(t, "SpellButton1SubSpellName", sub)
  t:cleanup(function() rawset(_G, "SpellButton1", nil) end)
  sub:SetTextColor(1, 0.82, 0, 1)
  Z.SpellButton(id, btn)
  t:ok(SK.Controls.over[btn].slot ~= nil, "slot frame added")
  local r = sub:GetTextColor()
  t:ok(r ~= 1, "rank line in the muted colour")
  Z.RankColour(id, sub, false)
  t:eq((sub:GetTextColor()), 1, "Blizzard colour back")
  Z.SpellButton(id, btn); Z.SpellButton(id, btn)
  Z.RankColour(id, sub, false)
  t:eq((sub:GetTextColor()), 1, "re-running never loses the original colour")

  local tb = CreateFrame("Button", "PlayerTalentFrameTalent1", UIParent)
  t:cleanup(function() rawset(_G, "PlayerTalentFrameTalent1", nil) end)
  stub(t, "GetTalentInfo", function() return "Talent", 1, 1, 1, 3, 5 end)
  Z.TalentButton(id, tb, 1, 1)
  t:ok(SK.Controls.over[tb].ring:IsShown(), "ring on a chosen talent")
  stub(t, "GetTalentInfo", function() return "Talent", 1, 1, 1, nil, nil end)
  Z.TalentButton(id, tb, 1, 1)
  t:eq(SK.Controls.over[tb].ring:IsShown(), false, "no ring without data")
end)
