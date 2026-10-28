local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for skins v2, second set: the window extras of Extras2.lua,
-- the surfaces of Surfaces2.lua, submenus and live re-runs.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local SK = ns.SK
local C = SK.Controls
local Y = SK.Extras2

-- stub(t, name, value): a global for one test, the original restored after.
local function stub(t, name, value)
  local old = rawget(_G, name)
  rawset(_G, name, value)
  t:cleanup(function() rawset(_G, name, old) end)
end
local function enable(t, ...)
  local keys = { "module.Skins", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module.Skins", true)
  CQ.Drain()
end

Tests:Add("Skins", "every listed extra has a schema key, selects carry their choices", function(t)
  local n = 0
  for id, names in pairs(SK.WINDOW_EXTRAS) do
    local pack = SK.packs[id]
    t:ok(pack ~= nil, id .. " is a catalog window")
    for _, name in ipairs(names) do
      local key = "skins." .. pack.group .. "." .. name
      local def = Schema:Def(key)
      t:ok(def ~= nil, key)
      if def and def.type == "select" then t:ok(#def.choices >= 2 and def.choiceLabels[def.default] ~= nil, key .. " choices") end
      n = n + 1
    end
  end
  t:ok(n >= 22, "22 or more new extras")
  for _, id in ipairs({ "petBattle", "barbershop", "textAlerts", "mirrorTimers", "widgets", "helpTips", "subtitles", "chatBubbles" }) do
    t:ok(SK.packs[id] ~= nil and Schema:Def("skins." .. id) ~= nil, id .. " registered with a switch")
  end
end)

Tests:Add("Skins", "spell and talent extras: cast text, talent state", function(t)
  stub(t, "C_Spell", { GetSpellInfo = function(id) return id == 1 and { castTime = 1500 } or { castTime = 0 } end })
  t:eq(Y.CastText(1), "1.5 sec cast")
  t:eq(Y.CastText(2), "Instant")
  t:eq(Y.TalentState({ activeRank = 1 }), "chosen")
  t:eq(Y.TalentState({ activeRank = 0, canPurchaseRank = true }), "open")
  t:eq(Y.TalentState({ activeRank = 0 }), nil)
  t:eq(Y.TalentState(nil), nil)
end)

Tests:Add("Skins", "collections, group finder and friends data", function(t)
  t:eq(Y.Collected({ elementData = { petID = "" } }), false)
  t:eq(Y.Collected({ elementData = { petID = "BattlePet-1" } }), true)
  t:eq(Y.Collected({ elementData = { isOwned = false } }), false)
  t:eq(Y.Collected({}), nil)
  stub(t, "LFG_LIST_APP_DECLINED", "Declined")
  local row, lbl = CreateFrame("Frame", nil, UIParent), CreateFrame("Frame", nil, UIParent)
  rawset(lbl, "GetText", function() return "Declined" end)
  rawset(row, "PendingLabel", lbl)
  lbl:Show(); t:eq(Y.Declined(row), true)
  lbl:Hide(); t:eq(Y.Declined(row), false)
  t:eq(Y.Declined(nil), false)
  stub(t, "LOCALIZED_CLASS_NAMES_MALE", { MAGE = "Mage" })
  stub(t, "LOCALIZED_CLASS_NAMES_FEMALE", { PRIEST = "Priestess" })
  t:eq(Y.ClassFile("Mage"), "MAGE"); t:eq(Y.ClassFile("Priestess"), "PRIEST"); t:eq(Y.ClassFile("Nope"), nil)
end)

Tests:Add("Skins", "loot upgrade hint compares worn item level", function(t)
  local lv = { new = 300, head = 290, r1 = 310, r2 = 280 }
  stub(t, "C_Item", { GetItemInfoInstant = function(l) return 1, nil, nil, l == "ring" and "INVTYPE_FINGER" or "INVTYPE_HEAD" end,
    GetDetailedItemLevelInfo = function(l) return lv[l] or (l == "ring" and 300) end })
  stub(t, "GetInventoryItemLink", function(_, slot) return ({ [1] = "head", [11] = "r1", [12] = "r2" })[slot] end)
  t:eq(Y.IsUpgrade("new"), true, "300 beats a 290 helm")
  lv.head = 310
  t:eq(Y.IsUpgrade("new"), false, "not over a 310 helm")
  t:eq(Y.IsUpgrade("ring"), true, "rings compare to the lower of the two")
  t:eq(Y.IsUpgrade(nil), false)
end)

Tests:Add("Skins", "bags, merchant, professions, guild, calendar, vault data", function(t)
  stub(t, "C_Container", { GetContainerItemInfo = function(_, slot) return ({ { quality = 0 }, { quality = 0, hasNoValue = true }, { quality = 3 } })[slot] end })
  t:eq(Y.IsJunk(0, 1), true); t:eq(Y.IsJunk(0, 2), false); t:eq(Y.IsJunk(0, 3), false); t:eq(Y.IsJunk(0, 4), false)
  t:eq(Y.Matches("Light Feather", "feather"), true); t:eq(Y.Matches("Bread", "feather"), false); t:eq(Y.Matches("Bread", ""), true)
  stub(t, "C_Item", { GetItemCount = function() return 3 end })
  local text, ok = Y.HaveNeed(5, 2); t:eq(text, "3/2"); t:eq(ok, true)
  text, ok = Y.HaveNeed(5, 4); t:eq(ok, false)
  t:eq(Y.LastOnline({ presence = 2, lastOnlineYear = 0, lastOnlineMonth = 0, lastOnlineDay = 3, lastOnlineHour = 1 }), "3d")
  t:eq(Y.LastOnline({ presence = 2, lastOnlineYear = 0, lastOnlineMonth = 0, lastOnlineDay = 0, lastOnlineHour = 0 }), "1h")
  t:eq(Y.LastOnline({ presence = 1 }), nil)
  stub(t, "C_Calendar", { GetNumDayEvents = function(_, d) return d == 5 and 2 or 0 end,
    GetDayEvent = function(_, _, i) return { calendarType = i == 1 and "SYSTEM" or "RAID_LOCKOUT" } end })
  t:eq(Y.DayToken(0, 5), "danger"); t:eq(Y.DayToken(0, 6), nil)
  t:eq(Y.Unlocked({ progress = 8, threshold = 8 }), true); t:eq(Y.Unlocked({ progress = 2, threshold = 4 }), false)
end)

Tests:Add("Skins", "extras overlays apply, follow the setting live and revert", function(t)
  if not H then return end
  enable(t, "skins.achievements", "skins.world.achievementsEarned")
  local frame = CreateFrame("Frame", "AchievementFrame", UIParent)
  local list = CreateFrame("Frame", "AchievementFrameAchievements", frame)
  local box = CreateFrame("Frame", nil, list)
  local row = CreateFrame("Frame", nil, box)
  rawset(row, "id", 42)
  rawset(list, "ScrollBox", box)
  rawset(box, "kids", { row })
  rawset(box, "ForEachFrame", function(_, fn) fn(row) end)
  stub(t, "GetAchievementInfo", function() return 42, "x", 10, true end)
  t:cleanup(function() SK.Revert("achievements"); rawset(_G, "AchievementFrame", nil); rawset(_G, "AchievementFrameAchievements", nil) end)
  SK.Refresh(); CQ.Drain()
  t:ok(SK.applied.achievements, "applied")
  t:ok(C.over[row] and C.over[row].earned and C.over[row].earned:IsShown(), "earned stripe")
  Schema:Set("skins.world.achievementsEarned", false); CQ.Drain()
  t:ok(not C.over[row].earned:IsShown(), "off live, no reopen")
  Schema:Set("skins.world.achievementsEarned", true); CQ.Drain()
  t:ok(C.over[row].earned:IsShown(), "on again live")
  SK.Revert("achievements")
  t:ok(not C.over[row].earned:IsShown(), "reverted")
end)

Tests:Add("Skins", "dim keeps and restores the row's own alpha", function(t)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetAlpha(0.8)
  SK.owned.dimtest = {}
  Y.Dim("dimtest", f, true, 0.3); t:eq(f:GetAlpha(), 0.3)
  Y.Dim("dimtest", f, false); t:eq(f:GetAlpha(), 0.8)
  Y.Dim("dimtest", f, true, 0.3)
  SK.Revert("dimtest")
  t:eq(f:GetAlpha(), 0.8, "revert restores")
end)

Tests:Add("Skins", "toast style, submenus, mirror bars and bubbles", function(t)
  if not H then return end
  enable(t, "skins.toasts", "skins.menus", "skins.social.toastStyle")
  Schema:Set("skins.social.toastStyle", "minimal"); CQ.Drain()
  SK.Refresh(); CQ.Drain()
  local toast = CreateFrame("Frame", nil, UIParent)
  SK.Surfaces.Toast(toast)
  t:ok(not C.over[toast].wash:IsShown(), "minimal style has no wash")
  t:ok(C.over[toast].edge:IsShown(), "edge stays")
  local root = CreateFrame("Frame", nil, UIParent)
  local sub = CreateFrame("Frame", nil, UIParent)
  rawset(root, "submenu", sub)
  SK.Menus.Skin(root)
  t:ok(SK.Menus.Sub(root) ~= false, "submenu skinned")
  t:ok(SK.Menus.menus[sub], "submenu tracked")
  SK.owned.bartest = {}
  local bar = CreateFrame("StatusBar", nil, UIParent)
  t:ok(SK.Surfaces2.Bar("bartest", bar), "bar skinned")
  t:ok(not SK.Surfaces2.Bar("bartest", bar), "once")
  SK.Revert("bartest")
  t:ok(SK.Surfaces2.bars[bar] == nil, "bar reverted")
  stub(t, "C_ChatBubbles", { GetAllChatBubbles = function() return {} end })
  t:eq(SK.Surfaces2.ScanBubbles("chatBubbles"), 0, "no bubbles, nothing done")
end)
