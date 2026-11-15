local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Phoenix extras, second set (skins v2): spellbook, talents, collections,
-- transmog, Group Finder, Friends, loot, bags, merchant, Auction House,
-- professions, achievements, guild, calendar and Great Vault. Same rules as
-- Extras.lua: Phoenix-owned font strings and textures only, Blizzard methods
-- are post-hooked on the instance (hooksecurefunc), alpha and font changes
-- are recorded and reverted, nothing is written into a Blizzard table, and
-- any value that may be secret goes to a widget as is (never compared).
local _, ns = ...
local SK = ns.SK
local C, X = SK.Controls, SK.Extras
local Theme, Media, Secret, CQ = PUI.Theme, PUI.Media, PUI.Secret, PUI.CombatQueue
local s = X.s
local Y = { hooked = setmetatable({}, { __mode = "k" }), dimmed = setmetatable({}, { __mode = "k" }) }
SK.Extras2 = Y

local function toggle(label, tooltip, default, mode)
  return { type = "toggle", default = default ~= false, label = label, tooltip = tooltip, mode = mode or "advanced" }
end
local function choose(label, tooltip, default, choices, labels)
  return { type = "select", default = default, label = label, tooltip = tooltip, mode = "advanced", choices = choices, choiceLabels = labels }
end
local DEFS = {
  spellCastLines = toggle("Cast time lines", "Cast time under every spell in the spellbook.", true, "simple"),
  spellCardSize = choose("Spell name size", "Font size of spell names in the spellbook.", "normal", { "small", "normal", "large" }, { small = "Small", normal = "Normal", large = "Large" }),
  talentRings = toggle("Talent rings", "An accent ring on chosen talents, a dim ring on talents you can still pick.", true, "simple"),
  collectDim = toggle("Dim uncollected", "Mounts, pets and toys you do not own are dimmed in the lists.", true, "simple"),
  collectModelLight = toggle("Model backdrop", "Phoenix ember backdrop behind mount and pet models.", true),
  transmogPending = toggle("Pending change highlight", "An accent frame on transmog slots with an unsaved change.", true),
  lfgHideDeclined = toggle("Fade declined groups", "Group Finder results that declined you fade almost out (Blizzard keeps the row).", true, "simple"),
  friendsClassIcons = toggle("Class icons", "Class icon on every friend playing World of Warcraft.", true, "simple"),
  lootUpgradeHint = toggle("Upgrade hint", "A green arrow on loot and rolls with a higher item level than what you wear.", true, "simple"),
  toastStyle = choose("Toast style", "Look of alert toasts (from the next toast).", "glass", { "glass", "solid", "minimal" }, { glass = "Ember glass", solid = "Solid", minimal = "Minimal" }),
  bagsJunk = toggle("Junk overlay", "Grey items with a coin mark so junk is easy to spot.", true, "simple"),
  bagsView = choose("Bag view", "Blizzard's own bag layout setting: one combined bag or separate bags.", "keep", { "keep", "combined", "separate" }, { keep = "Leave as set", combined = "Combined", separate = "Separate" }),
  merchantDim = toggle("Dim unusable items", "Merchant items you cannot use are dimmed.", true, "simple"),
  merchantSearch = toggle("Search box", "A Phoenix search box: items on the page that do not match fade.", true),
  ahPriceFont = choose("Price font", "Font of prices in the Auction House lists.", "body", { "small", "body", "large" }, { small = "Small", body = "Normal", large = "Large" }),
  profHaveNeed = toggle("Have / need counts", "Have/need on every reagent, green when you have enough, red when not.", true, "simple"),
  achievementsEarned = toggle("Earned colour", "Earned achievements get an accent stripe.", true),
  guildUnread = toggle("Unread badges", "An accent dot on communities with unread messages.", true, "simple"),
  guildRosterCols = toggle("Last online column", "Last online time on offline roster members.", true),
  calendarColors = toggle("Event colours", "Colour stripes on calendar days: guild, player, holiday and lockout events.", true, "simple"),
  vaultGlow = toggle("Unlocked glow", "An accent glow on Great Vault slots you have unlocked.", true, "simple"),
}
DEFS.bagsView.onSet = function() Y.ApplyBagView() end
for name, def in pairs(DEFS) do SK.EXTRA_DEFS[name] = def; s[name] = def.default end
Y.DEFS = DEFS
local On = X.On
local label = X.Label

-- Helpers ----------------------------------------------------------------------------------
local function path(root, ...)
  local o = root
  for i = 1, select("#", ...) do o = o and C.K(o, (select(i, ...))) end
  return o
end
Y.Path = path
-- each(container, fn): every frame of a ScrollBox (or every child).
local function each(box, fn)
  if not box then return end
  if box.ForEachFrame then box:ForEachFrame(fn) return end
  for _, c in ipairs({ box:GetChildren() }) do fn(c) end
end
Y.Each = each
-- hook(obj, method, id, fn): one post-hook per object and method, live only while id is skinned.
local function hook(obj, method, id, fn)
  if not (obj and type(obj[method]) == "function") then return false end
  local bag = Y.hooked[obj]
  if not bag then bag = {}; Y.hooked[obj] = bag end
  if bag[method] then return true end
  bag[method] = true
  hooksecurefunc(obj, method, function(...) if SK.applied[id] then securecallfunction(fn, ...) end end)
  return true
end
Y.Hook = hook
-- dim(id, frame, on, alpha): fades a Blizzard row; the original alpha comes back on revert.
local function dim(id, f, on, a)
  if not (f and f.SetAlpha) then return end
  if on then
    if Y.dimmed[f] == nil then
      Y.dimmed[f] = f:GetAlpha()
      C.Own(id, function() if Y.dimmed[f] then f:SetAlpha(Y.dimmed[f]); Y.dimmed[f] = nil end end)
    end
    f:SetAlpha(a or 0.4)
  elseif Y.dimmed[f] then f:SetAlpha(Y.dimmed[f]); Y.dimmed[f] = nil end
end
Y.Dim = dim
local function hideLabels(f, key) local bag = X.labels[f]; if bag and bag[key] then bag[key]:Hide() end end
local function mark(id, f, key, texName, layer)
  local t = C.Over(id, f, key, layer or "OVERLAY", texName)
  t:ClearAllPoints(); t:SetAllPoints()
  return t
end
local function unmark(f, key) local bag = C.over[f]; if bag and bag[key] then bag[key]:Hide() end end
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
-- Field reads off Blizzard frames, typed (a missing field must not be called or iterated).
local function tbl(v) return type(v) == "table" and v or nil end
local function num(v) return type(v) == "number" and v or nil end

-- Spellbook and talents ------------------------------------------------------------------
-- CastText(spellID) -> "1.5 sec cast" / "Instant"; a secret cast time stays raw.
-- (12.1.5 has no base-cooldown API in its catalog, so the line is cast time only.)
function Y.CastText(spellID)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
  if not info then return nil end
  local ms = info.castTime
  if not plain(ms) then return ms end
  return ms > 0 and string.format("%.1f sec cast", ms / 1000) or "Instant"
end
local NAME_ROLE = { small = "small", normal = "body", large = "large" }
function Y.SpellItem(id, item)
  local spellID = num(item.spellID) or (item.GetSpellID and item:GetSpellID())
  local name = C.K(item, "Name")
  if name then SK.Font(id, name, NAME_ROLE[s.spellCardSize] or "body") end
  if On("spellCastLines") and type(spellID) == "number" then
    local fs = label(item, "cast", "TOPLEFT", name and 0 or 40, -18, "small")
    if name then fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2) end
    fs:SetText(Y.CastText(spellID) or "")
    Theme:Paint(fs, "muted", 1, "text")
    fs:Show()
  else hideLabels(item, "cast") end
end
-- TalentState(node) -> "chosen", "open" or nil (node info is plain talent data).
function Y.TalentState(info)
  if type(info) ~= "table" then return nil end
  if (info.activeRank or 0) > 0 then return "chosen" end
  if info.canPurchaseRank then return "open" end
end
function Y.TalentButton(id, btn)
  local info = tbl(btn.nodeInfo) or (btn.GetNodeInfo and btn:GetNodeInfo())
  local state = On("talentRings") and Y.TalentState(info)
  if not state then unmark(btn, "ring") return end
  local ring = C.Over(id, btn, "ring", "OVERLAY", "StatusOrb", 7)
  ring:ClearAllPoints(); ring:SetPoint("TOPLEFT", -4, 4); ring:SetPoint("BOTTOMRIGHT", 4, -4)
  Theme:Paint(ring, state == "chosen" and "accent" or "line", state == "chosen" and 0.9 or 0.5, "vertex")
end
local function spellbook(frame, _, id)
  local book = path(frame, "SpellBookFrame", "PagedSpellsFrame") or path(frame, "PagedSpellsFrame")
  local function scan() each(path(book, "ViewFrames") and book.ViewFrames[1] or book, function(f)
    if f.Name or f.spellID then Y.SpellItem(id, f) end
    each(f, function(g) if g.Name and (g.spellID or g.GetSpellID) then Y.SpellItem(id, g) end end)
  end) end
  if book then hook(book, "SetDataProvider", id, scan); hook(book, "UpdatePage", id, scan); book:HookScript("OnShow", function() if SK.applied[id] then scan() end end); scan() end
  local tree = path(frame, "TalentsFrame", "ButtonsParent") or path(frame, "TalentsFrame")
  local talents = path(frame, "TalentsFrame")
  local function rings() each(tree, function(b) if b.nodeInfo or b.GetNodeInfo then Y.TalentButton(id, b) end end) end
  if talents then hook(talents, "UpdateTreeCurrencyInfo", id, rings); hook(talents, "OnTraitConfigUpdated", id, rings); rings() end
end

-- Collections ------------------------------------------------------------------------------
-- Collected(row) -> true / false / nil from a list row's own data.
function Y.Collected(row)
  local d = tbl(row.elementData) or (row.GetElementData and row:GetElementData())
  if type(d) ~= "table" then return nil end
  local id = num(d.mountID) or num(row.mountID)
  if id and C_MountJournal then local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(id); return isCollected end
  if d.petID ~= nil then return d.petID ~= "" end
  if d.isOwned ~= nil then return d.isOwned end
end
local function collections(frame, _, id)
  if frame:GetName() ~= "CollectionsJournal" then return end
  for _, p in ipairs({ { "MountJournal", "ScrollBox", "MountDisplay" }, { "PetJournal", "ScrollBox", "PetCard" } }) do
    local journal = rawget(_G, p[1])
    local box = path(journal, p[2])
    local function rows() each(box, function(r) local got = Y.Collected(r); dim(id, r, On("collectDim") and got == false, 0.45) end) end
    if box then hook(box, "Update", id, rows); rows() end
    local display = path(journal, p[3])
    if display then
      local t = C.Over(id, display, "light", "BACKGROUND", "ModelBackdrop_Ember", 1)
      t:ClearAllPoints(); t:SetAllPoints(); t:SetShown(On("collectModelLight"))
    end
  end
end

-- Transmog --------------------------------------------------------------------------------
function Y.TransmogSlot(id, slot)
  local pending = C.K(slot, "PendingFrame") or C.K(slot, "PendingIcon")
  if On("transmogPending") and pending and pending:IsShown() then
    local t = mark(id, slot, "pending", "Slot_QualityFrame"); Theme:Paint(t, "accent", 1, "vertex")
  else unmark(slot, "pending") end
end
local function transmog(frame, _, id)
  local function scan(f, depth)
    each(f, function(c) if C.K(c, "PendingFrame") or C.K(c, "PendingIcon") then Y.TransmogSlot(id, c) elseif depth < 3 then scan(c, depth + 1) end end)
  end
  local function run() scan(frame, 0) end
  frame:HookScript("OnEvent", function() if SK.applied[id] then run() end end)
  run()
end

-- Group Finder ----------------------------------------------------------------------------
-- Declined(row): Blizzard's own result row says so (its pending label shows the
-- declined string); plain localized text only, a secret value counts as no.
function Y.Declined(row)
  local lbl = row and C.K(row, "PendingLabel")
  if not (lbl and lbl:IsShown()) then return false end
  local text, want = lbl:GetText(), rawget(_G, "LFG_LIST_APP_DECLINED")
  return plain(text) and want ~= nil and text == want
end
local function groupFinder(frame, _, id)
  local box = path(rawget(_G, "LFGListFrame"), "SearchPanel", "ScrollBox")
  local function rows() each(box, function(r) dim(id, r, On("lfgHideDeclined") and Y.Declined(r), 0.15) end) end
  if box then hook(box, "Update", id, rows); rows() end
end

-- Friends: class icons --------------------------------------------------------------------
-- ClassFile(localized) -> "WARRIOR" etc. from Blizzard's class name tables.
function Y.ClassFile(name)
  if not plain(name) then return nil end
  for _, t in ipairs({ rawget(_G, "LOCALIZED_CLASS_NAMES_MALE") or {}, rawget(_G, "LOCALIZED_CLASS_NAMES_FEMALE") or {} }) do
    for file, loc in pairs(t) do if loc == name then return file end end
  end
end
function Y.FriendClass(btn)
  local index = num(btn.id)
  if type(index) ~= "number" then return nil end
  if num(btn.buttonType) == (rawget(_G, "FRIENDS_BUTTON_TYPE_WOW") or 2) and C_FriendList then
    local info = C_FriendList.GetFriendInfoByIndex(index)
    return info and info.connected and Y.ClassFile(info.className)
  elseif C_BattleNet and C_BattleNet.GetFriendAccountInfo then
    local info = C_BattleNet.GetFriendAccountInfo(index)
    local game = info and info.gameAccountInfo
    return game and game.clientProgram == "WoW" and Y.ClassFile(game.className)
  end
end
function Y.FriendRow(id, btn)
  local file = On("friendsClassIcons") and Y.FriendClass(btn)
  if not file then unmark(btn, "class") return end
  local t = C.Over(id, btn, "class", "OVERLAY", nil, 7)
  t:SetAtlas("classicon-" .. string.lower(file))
  t:SetSize(14, 14); t:ClearAllPoints(); t:SetPoint("RIGHT", btn, "RIGHT", -26, 0)
end
local function friends(frame, _, id)
  if frame:GetName() ~= "FriendsFrame" then return end
  local box = path(rawget(_G, "FriendsListFrame"), "ScrollBox")
  local function rows() each(box, function(b) Y.FriendRow(id, b) end) end
  if box then hook(box, "Update", id, rows); rows() end
end

-- Loot: upgrade hint -------------------------------------------------------------------------
local EQUIP_SLOT = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6,
  INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15,
  INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17, INVTYPE_SHIELD = 17, INVTYPE_RANGED = 16 }
Y.EQUIP_SLOT = EQUIP_SLOT
local function ilvl(link) local v = link and C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link); return plain(v) and v or nil end
-- IsUpgrade(link) -> true when the item's level beats what is worn in its slot.
function Y.IsUpgrade(link)
  local loc = link and C_Item and C_Item.GetItemInfoInstant and select(4, C_Item.GetItemInfoInstant(link))
  local slot = loc and EQUIP_SLOT[loc]
  if not slot then return false end
  local new, worn = ilvl(link), ilvl(GetInventoryItemLink("player", slot))
  if not new then return false end
  if slot == 11 or slot == 13 then
    local other = ilvl(GetInventoryItemLink("player", slot + 1))
    if other and (not worn or other < worn) then worn = other end
  end
  return worn == nil or new > worn
end
function Y.Hint(id, btn, link)
  if not btn then return end
  if On("lootUpgradeHint") and Y.IsUpgrade(link) then
    local fs = label(btn, "upgrade", "TOPLEFT", 1, -1, "small")
    fs:SetText("+"); Theme:Paint(fs, "success", 1, "text"); fs:Show()
  else hideLabels(btn, "upgrade") end
end
local function lootRolls(frame, _, id)
  local function run() if num(frame.rollID) then Y.Hint(id, C.K(frame, "IconFrame") or frame, GetLootRollItemLink(frame.rollID)) end end
  frame:HookScript("OnShow", function() if SK.applied[id] then run() end end)
  run()
end
local function loot(frame, _, id)
  local box = path(frame, "ScrollBox")
  local function rows() each(box, function(r) local slot = r.GetSlotIndex and r:GetSlotIndex() or num(r.slotIndex); if slot then Y.Hint(id, C.K(r, "Item") or r, GetLootSlotLink(slot)) end end) end
  if box then hook(box, "Update", id, rows); rows() end
end

-- Bags --------------------------------------------------------------------------------------
function Y.IsJunk(bag, slot)
  local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
  return info ~= nil and info.quality == 0 and not info.hasNoValue
end
function Y.BagButton(id, btn)
  local bag, slot = btn.GetBagID and btn:GetBagID(), btn.GetID and btn:GetID()
  local junk = On("bagsJunk") and bag and slot and Y.IsJunk(bag, slot)
  local icon = C.K(btn, "icon") or C.K(btn, "Icon")
  if junk then
    local t = C.Over(id, btn, "junk", "OVERLAY", nil, 6)
    local path_ = Media:Path("icon", "Skins/pui_merchant")
    if path_ then t:SetTexture(path_) end
    t:SetSize(14, 14); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 2, -2)
    if icon then icon:SetDesaturated(true) end
  else unmark(btn, "junk"); if icon and SK.applied[id] then icon:SetDesaturated(false) end end
end
local VIEW_CVAR = { combined = "1", separate = "0" }
function Y.ApplyBagView()
  local v = VIEW_CVAR[s.bagsView]
  if v and C_CVar then CQ.Defer("skins.bagView", function() C_CVar.SetCVar("combinedBags", v) end) end
end
local function bags(frame, _, id)
  local function items() for _, b in ipairs(tbl(frame.Items) or {}) do Y.BagButton(id, b) end; each(frame, function(b) if b.GetBagID then Y.BagButton(id, b) end end) end
  hook(frame, "UpdateItems", id, items); items()
  C.Own(id, function() for _, b in ipairs(tbl(frame.Items) or {}) do local i = C.K(b, "icon"); if i then i:SetDesaturated(false) end end end)
  Y.ApplyBagView()
end

-- Merchant --------------------------------------------------------------------------------
function Y.Matches(name, query)
  if not query or query == "" then return true end
  if not plain(name) then return true end
  return string.find(string.lower(name), string.lower(query), 1, true) ~= nil
end
function Y.MerchantUpdate(id)
  local f = rawget(_G, "MerchantFrame")
  if not (f and SK.applied[id]) then return end
  local per = rawget(_G, "MERCHANT_ITEMS_PER_PAGE") or 10
  local query = Y.search and Y.search:IsShown() and Y.search:GetText() or ""
  for i = 1, per do
    local row = rawget(_G, "MerchantItem" .. i)
    local index = ((num(f.page) or 1) - 1) * per + i
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(index)
    if row and info then
      local fade = (On("merchantDim") and info.isUsable == false) or not Y.Matches(info.name, query)
      dim(id, row, fade, 0.35)
    elseif row then dim(id, row, false) end
  end
end
local function merchant(frame, _, id)
  local eb = Y.search
  if not eb then
    eb = PUI:CreateFrame("EditBox", nil, frame, "SearchBoxTemplate", "Skins")
    eb:SetSize(130, 20); eb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -32)
    eb:HookScript("OnTextChanged", function() Y.MerchantUpdate(id) end)
    Y.search = eb
  end
  eb:SetShown(On("merchantSearch"))
  C.Own(id, function() eb:Hide() end)
  Y.MerchantUpdate(id)
end

-- Auction House: price font ----------------------------------------------------------------
local PRICE_KEYS = { "GoldDisplay", "SilverDisplay", "CopperDisplay" }
function Y.PriceFonts(id, row, depth)
  for _, k in ipairs(PRICE_KEYS) do local d = C.K(row, k); local fs = d and (C.K(d, "Text") or (d.GetObjectType and d:GetObjectType() == "FontString" and d)); if fs then SK.Font(id, fs, s.ahPriceFont) end end
  if depth < 3 then each(row, function(c) Y.PriceFonts(id, c, depth + 1) end) end
end
local function auction(frame, _, id)
  local function run() Y.PriceFonts(id, frame, 0) end
  frame:HookScript("OnEvent", function() if SK.applied[id] then run() end end)
  run()
end

-- Professions: have / need --------------------------------------------------------------------
function Y.HaveNeed(itemID, need)
  if not (itemID and need) then return nil end
  local have = C_Item.GetItemCount(itemID, true, false, true, true) or 0
  return string.format("%d/%d", have, need), have >= need
end
function Y.ReagentSlot(id, slot)
  local sch = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic()
  local r = sch and sch.reagents and sch.reagents[1]
  local text, ok = Y.HaveNeed(r and r.itemID, sch and sch.quantityRequired)
  if On("profHaveNeed") and text then
    local fs = label(slot, "haveneed", "RIGHT", -2, 0, "small")
    fs:SetText(text); Theme:Paint(fs, ok and "success" or "danger", 1, "text"); fs:Show()
  else hideLabels(slot, "haveneed") end
end
local function professions(frame, _, id)
  local form = path(frame, "CraftingPage", "SchematicForm")
  local function run() local holder = path(form, "Reagents"); each(holder, function(sl) if sl.GetReagentSlotSchematic then Y.ReagentSlot(id, sl) end end) end
  if form then hook(form, "Init", id, run); hook(form, "UpdateAllSlots", id, run); run() end
end

-- Achievements, guild, calendar, vault -----------------------------------------------------
local function achievements(frame, _, id)
  local box = path(rawget(_G, "AchievementFrameAchievements"), "ScrollBox")
  local function rows() each(box, function(r)
    local done = num(r.id) and select(4, GetAchievementInfo(r.id))
    if On("achievementsEarned") and done == true then local t = C.Over(id, r, "earned", "ARTWORK", "Hairline_Ember", 7); t:ClearAllPoints(); t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMLEFT"); t:SetWidth(3); Theme:Paint(t, "accent", 1, "vertex")
    else unmark(r, "earned") end
  end) end
  if box then hook(box, "Update", id, rows); rows() end
end
-- LastOnline(info) -> "3d", "5h" from a roster member's plain last-online fields.
function Y.LastOnline(m)
  if type(m) ~= "table" or m.presence == 1 then return nil end
  local y, mo, d, h = m.lastOnlineYear, m.lastOnlineMonth, m.lastOnlineDay, m.lastOnlineHour
  if not (plain(d) and plain(h)) then return nil end
  if (y or 0) > 0 then return y .. "y" elseif (mo or 0) > 0 then return mo .. "mo" elseif d > 0 then return d .. "d" else return math.max(h, 1) .. "h" end
end
local function guild(frame, _, id)
  if frame:GetName() ~= "CommunitiesFrame" then return end
  local list = path(frame, "CommunitiesList", "ScrollBox")
  local function clubs() each(list, function(r)
    local club = num(r.clubId) or (tbl(r.clubInfo) and r.clubInfo.clubId)
    local util = rawget(_G, "CommunitiesUtil")
    local unread = club and util and util.DoesCommunityHaveUnreadMessages and util.DoesCommunityHaveUnreadMessages(club)
    if On("guildUnread") and unread == true then local t = C.Over(id, r, "unread", "OVERLAY", "StatusOrb", 7); t:SetSize(8, 8); t:ClearAllPoints(); t:SetPoint("TOPRIGHT", -6, -6); Theme:Paint(t, "accent", 1, "vertex")
    else unmark(r, "unread") end
  end) end
  if list then hook(list, "Update", id, clubs); clubs() end
  local roster = path(frame, "MemberList", "ScrollBox")
  local function members() each(roster, function(r)
    local text = On("guildRosterCols") and Y.LastOnline(tbl(r.memberInfo))
    if text then local fs = label(r, "last", "RIGHT", -8, 0, "small"); fs:SetText(text); Theme:Paint(fs, "muted", 1, "text"); fs:Show() else hideLabels(r, "last") end
  end) end
  if roster then hook(roster, "Update", id, members); members() end
end
local CAL_TOKEN = { GUILD_EVENT = "accent", GUILD_ANNOUNCEMENT = "accent", PLAYER = "success", COMMUNITY_EVENT = "success", HOLIDAY = "spark", RAID_LOCKOUT = "danger" }
Y.CAL_TOKEN = CAL_TOKEN
function Y.DayToken(offset, day)
  if not (C_Calendar and offset and day) then return nil end
  local n = C_Calendar.GetNumDayEvents(offset, day) or 0
  for i = 1, n do local e = C_Calendar.GetDayEvent(offset, day, i); local tok = e and CAL_TOKEN[e.calendarType]; if tok then return tok end end
end
local function calendar(frame, _, id)
  if frame:GetName() ~= "CalendarFrame" then return end
  local function days() for i = 1, 42 do
    local b = rawget(_G, "CalendarDayButton" .. i)
    local tok = b and On("calendarColors") and Y.DayToken(num(b.monthOffset), num(b.day))
    if tok then local t = C.Over(id, b, "event", "OVERLAY", "Hairline_Ember", 6); t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", 2, 2); t:SetPoint("BOTTOMRIGHT", -2, 2); t:SetHeight(3); Theme:Paint(t, tok, 1, "vertex")
    elseif b then unmark(b, "event") end
  end end
  local upd = rawget(_G, "CalendarFrame_Update")
  if upd and not Y.calHooked then Y.calHooked = true; hooksecurefunc("CalendarFrame_Update", function() if SK.applied[id] then securecallfunction(days) end end) end
  days()
end
function Y.Unlocked(info) return type(info) == "table" and plain(info.progress) and plain(info.threshold) and info.threshold > 0 and info.progress >= info.threshold end
local function vault(frame, _, id)
  local function run() for _, a in ipairs(tbl(frame.Activities) or {}) do
    if On("vaultGlow") and Y.Unlocked(tbl(a.info)) then local t = C.Over(id, a, "glow", "BACKGROUND", "Shadow_Soft", 7); t:ClearAllPoints(); t:SetPoint("TOPLEFT", -6, 6); t:SetPoint("BOTTOMRIGHT", 6, -6); Theme:Paint(t, "accent", 0.8, "vertex")
    else unmark(a, "glow") end
  end end
  hook(frame, "Refresh", id, run); run()
end

local IMPL = {
  spellbook = { extra = spellbook }, collections = { extra = collections }, transmog = { extra = transmog },
  groupFinder = { extra = groupFinder }, friends = { extra = friends }, lootRolls = { extra = lootRolls }, loot = { extra = loot },
  bags = { extra = bags }, merchant = { extra = merchant, hooks = { { "MerchantFrame_UpdateMerchantInfo" } }, update = function() Y.MerchantUpdate("merchant") end },
  auctionHouse = { extra = auction }, professions = { extra = professions }, achievements = { extra = achievements },
  guild = { extra = guild }, calendar = { extra = calendar }, greatVault = { extra = vault },
}
SK.WINDOW_IMPL = SK.WINDOW_IMPL or {}
for k, v in pairs(IMPL) do assert(not SK.WINDOW_IMPL[k], k); SK.WINDOW_IMPL[k] = v end
-- window id -> extras it gets (Packs.lua appends them to the catalog).
SK.WINDOW_EXTRAS = {
  spellbook = { "spellCastLines", "spellCardSize", "talentRings" }, collections = { "collectDim", "collectModelLight" },
  transmog = { "transmogPending" }, groupFinder = { "lfgHideDeclined" }, friends = { "friendsClassIcons" },
  lootRolls = { "lootUpgradeHint", "toastStyle" }, loot = { "lootUpgradeHint" }, bags = { "bagsJunk", "bagsView" },
  merchant = { "merchantDim", "merchantSearch" }, auctionHouse = { "ahPriceFont" }, professions = { "profHaveNeed" },
  achievements = { "achievementsEarned" }, guild = { "guildUnread", "guildRosterCols" }, calendar = { "calendarColors" },
  greatVault = { "vaultGlow" },
}
