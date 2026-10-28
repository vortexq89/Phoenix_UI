local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the skins v2 window catalog: toasts, tooltips and
-- the Phoenix extras on Character, Mail, Map, Popups and Edit Mode.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local SK = ns.SK
local C = SK.Controls

local function enable(t, ...)
  local keys = { "module.Skins", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module.Skins", true)
  CQ.Drain()
end

local function region(parent, otype)
  local r = CreateFrame("Frame", nil, parent)
  rawset(r, "otype", otype)
  return r
end
Tests:Add("Skins", "gear flyout lists a window's extras and sets them live", function(t)
  if not H then return end
  enable(t, "skins.character", "skins.player.charIlvl")
  t:ok(SK.Gear.Fill("character") >= 5, "window switch and its extras listed")
  SK.Gear.Step("skins.player.charIlvl")
  t:eq(Schema:Get("skins.player.charIlvl"), false, "toggled live from the flyout")
  t:eq(SK.Extras.s.charIlvl, false, "extra follows")
end)

Tests:Add("Skins", "toasts and other tooltips", function(t)
  if not H then return end
  local toast = CreateFrame("Frame", nil, UIParent)
  local back, icon = region(toast, "Texture"), region(toast, "Texture")
  rawset(back, "GetDrawLayer", function() return "BACKGROUND" end)
  rawset(icon, "GetDrawLayer", function() return "ARTWORK" end)
  rawset(toast, "GetRegions", function() return back, icon end)
  local af = CreateFrame("Frame", "AlertFrame", UIParent)
  rawset(af, "AddAlertFrame", function() end)
  rawset(_G, "AlertFrame", af)
  local tip = CreateFrame("GameTooltip", "ItemRefTooltip", UIParent)
  tip.NineSlice = CreateFrame("Frame", nil, tip)
  rawset(_G, "ItemRefTooltip", tip)
  t:cleanup(function() rawset(_G, "AlertFrame", nil); rawset(_G, "ItemRefTooltip", nil); SK.Surfaces.hooked = false; SK.Revert("toasts"); SK.Revert("tooltips") end)
  SK.Surfaces.hooked = false
  enable(t, "skins.toasts", "skins.tooltips")
  SK.Revert("toasts"); SK.Apply("toasts"); SK.Apply("tooltips")
  af:AddAlertFrame(toast)
  t:eq(back:GetAlpha(), 0, "toast background faded")
  t:eq(icon:GetAlpha(), 1, "toast icon untouched")
  t:eq(tip.NineSlice:GetAlpha(), 0, "item ref tooltip border faded")
end)

Tests:Add("Skins", "extras: enchant flags, danger popups, collect gold queue, coords", function(t)
  local X = SK.Extras
  t:eq(X.EnchantID("|cffa335ee|Hitem:212401::::::"), "", "no enchant")
  t:eq(X.EnchantID("|Hitem:212401:7534:::"), "7534", "enchant id")
  t:ok(X.IsDanger("DELETE_ITEM"), "delete is destructive")
  t:ok(X.IsDanger("ABANDON_QUEST"), "abandon is destructive")
  t:ok(not X.IsDanger("CONFIRM_BINDER"), "ordinary popup")
  t:ok(not X.IsDanger(nil), "no name")
  if not H then return end
  local saved = { rawget(_G, "GetInboxNumItems"), rawget(_G, "GetInboxHeaderInfo"), rawget(_G, "TakeInboxMoney") }
  rawset(_G, "GetInboxNumItems", function() return 3 end)
  rawset(_G, "GetInboxHeaderInfo", function(i)
    if i == 1 then return nil, nil, "A", "s", 500, 0, 3, false end
    if i == 2 then return nil, nil, "B", "s", 0, 0, 3, true end
    return nil, nil, "C", "s", 900, 100, 3, false
  end)
  local taken = {}
  rawset(_G, "TakeInboxMoney", function(i) taken[#taken + 1] = i end)
  t:cleanup(function() rawset(_G, "GetInboxNumItems", saved[1]); rawset(_G, "GetInboxHeaderInfo", saved[2]); rawset(_G, "TakeInboxMoney", saved[3]) end)
  t:same(X.GoldMails(), { 1 }, "only gold, no items, no COD")
  t:eq(X.CollectGold(), 1, "one mail queued")
  t:ok(PUI.Ticker:IsRegistered("skins.mailGold"), "queued on the Ticker")
  PUI.Ticker.entries["skins.mailGold"].fn()
  t:same(taken, { 1 }, "money taken")
  t:ok(not PUI.Ticker:IsRegistered("skins.mailGold"), "queue done")
  t:ok(X.MapText():find("^Player"), "coords text")
end)

Tests:Add("Skins", "character slots show item level and missing enchant", function(t)
  if not H then return end
  local btn = CreateFrame("Button", "CharacterChestSlot", CharacterFrame)
  btn:SetID(5)
  rawset(_G, "CharacterChestSlot", btn)
  local link = rawget(_G, "GetInventoryItemLink")
  rawset(_G, "GetInventoryItemLink", function() return "|Hitem:1234::::::" end)
  local api = rawget(_G, "C_Item")
  rawset(_G, "C_Item", { GetDetailedItemLevelInfo = function() return 639 end })
  t:cleanup(function() rawset(_G, "CharacterChestSlot", nil); rawset(_G, "GetInventoryItemLink", link); rawset(_G, "C_Item", api) end)
  enable(t, "skins.character")
  SK.Extras.s.charIlvl, SK.Extras.s.charEnchants = true, true
  SK.Extras.SlotUpdate(btn, "player")
  local L = SK.Extras.labels[btn]
  t:eq(L.ilvl:GetText(), 639, "item level")
  t:ok(L.ench:IsShown(), "missing enchant flagged")
  SK.Extras.HideSlot(btn)
  t:eq(L.ilvl:IsShown(), false, "hidden on revert")
end)
