local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault (plan 5.11, mockup 11): every bag in one Phoenix window. Slots are
-- the game's own ContainerFrameItemButtonTemplate buttons, created out of
-- combat under one holder frame per bag (holder ID = bag ID), so using,
-- moving and selling stays Blizzard's secure code; Phoenix only positions
-- them. Views: category (default, D-MOD-DEF2) with the rules engine in
-- Rules.lua, grid, compact and list. Junk is owned here (auto-sell OFF by
-- default; Flow's sell-junk defers to Vault while Vault is on). Keystone
-- shelf, pins, manual assignment, undo the last sort (Sort.lua), gold history
-- and currencies feed PUI.Wallet, alts and bank in Store.lua / Bank.lua.
-- Item quality colours come from ColorManager. Off by default.
local _, ns = ...
local Schema, Layout, CQ, Theme, Media = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Theme, PUI.Media
local R = ns.Rules
local OWNER = "Vault"
local BAGS = { 0, 1, 2, 3, 4, 5 }
local PAD, HEADER, FOOTER, SECTION = 10, 64, 30, 18

local VA = { active = false, holders = {}, buttons = {}, hooked = false, open = false, sections = {}, labels = {}, mode = "use" }
ns.VA = VA
PUI.Vault = VA
VA.Rules = R
VA.BAGS = BAGS
local s = {}
VA.settings = s
VA.ilvlText = setmetatable({}, { __mode = "k" })
VA.nameText = setmetatable({}, { __mode = "k" })
VA.border = setmetatable({}, { __mode = "k" })
VA.SIZES = { category = 37, grid = 37, compact = 30, list = 24 }

-- Quality colour: ColorManager first (respects the user's colour overrides),
-- then the item API.
function VA.QualityColor(quality)
  if type(quality) ~= "number" or PUI.Secret.IsSecret(quality) then return nil end
  local cm = rawget(_G, "ColorManager")
  local c = cm and cm.GetColorDataForItemQuality and cm.GetColorDataForItemQuality(quality)
  if c and c.color then return c.color:GetRGB() end
  if C_Item.GetItemQualityColor then
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then return r, g, b end
  end
  return nil
end

local function header(f)
  local function button(text, w, onClick, tip)
    local b = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
    b:SetSize(w, 20)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then
      b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(tip); GameTooltip:Show() end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
  end
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(Media:FontObject("header"))
  f.title:SetPoint("TOPLEFT", PAD + 2, -10)
  f.search = PUI:CreateFrame("EditBox", "PhoenixUI_VaultSearch", f, "SearchBoxTemplate", OWNER)
  f.search:SetSize(200, 20)
  f.search:SetPoint("TOPLEFT", PAD + 6, -34)
  f.search:HookScript("OnTextChanged", function(self) VA.SetSearch(self:GetText()) end)
  local ins = f.search.Instructions
  if type(ins) == "table" and ins.SetText then ins:SetText("Search: name, type, ilvl>650, set:PvP") end
  f.sort = button("Sort", 54, function() VA.Sort() end, "Sort your bags (Phoenix remembers the old order so you can undo).")
  f.sort:SetPoint("TOPRIGHT", -PAD, -34)
  f.undo = button("Undo", 54, function() VA.UndoSort() end, "Put every item back where it was before the last sort.")
  f.undo:SetPoint("RIGHT", f.sort, "LEFT", -4, 0)
  f.view = button("View", 64, function() VA.CycleView() end, "Switch view: category, grid, compact, list.")
  f.view:SetPoint("RIGHT", f.undo, "LEFT", -4, 0)
  f.pin = button("Pin", 44, function() VA.SetMode(VA.mode == "pin" and "use" or "pin") end, "Pin mode: click items to pin or unpin them.")
  f.pin:SetPoint("RIGHT", f.view, "LEFT", -4, 0)
  f.junkMode = button("Junk", 50, function() VA.SetMode(VA.mode == "junk" and "use" or "junk") end, "Junk mode: click items to mark or unmark them as junk.")
  f.junkMode:SetPoint("RIGHT", f.pin, "LEFT", -4, 0)
  f.sets = button("Sets", 46, function() VA.OpenSets() end, "Equipment sets are built in Loadouts.")
  f.sets:SetPoint("TOPRIGHT", -PAD - 24, -8)
  f.bank = button("Bank", 50, function() if ns.Bank then ns.Bank.Toggle() end end, "Bank, warband bank, reagents, guild bank and your alts' items.")
  f.bank:SetPoint("RIGHT", f.sets, "LEFT", -4, 0)
  f.sell = button("Sell junk", 76, function() VA.SellJunk() end)
  f.sell:SetPoint("BOTTOMRIGHT", -PAD, 6)
  f.sell:Hide()
  f.info = f:CreateFontString(nil, "OVERLAY")
  f.info:SetFontObject(Media:FontObject("small"))
  f.info:SetPoint("BOTTOMLEFT", PAD + 2, 11)
  f.infoHit = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.infoHit:SetPoint("BOTTOMLEFT", PAD, 4)
  f.infoHit:SetSize(320, 22)
  f.infoHit:EnableMouse(true)
  f.infoHit:SetScript("OnEnter", function(self) if ns.Store then ns.Store.GoldTooltip(self) end end)
  f.infoHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.modeNote = f:CreateFontString(nil, "OVERLAY")
  f.modeNote:SetFontObject(Media:FontObject("small"))
  f.modeNote:SetPoint("LEFT", f.search, "RIGHT", 10, 0)
end

local function window()
  local f = VA.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_Vault", UIParent, nil, OWNER)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.6)
  header(f)
  local close = PUI:CreateFrame("Button", nil, f, "UIPanelCloseButton", OWNER)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() VA.Close() end)
  tinsert(UISpecialFrames, "PhoenixUI_Vault")
  f:HookScript("OnHide", function() VA.open = false; if ns.Bank then ns.Bank.OnBagsHidden() end end)
  f:Hide()
  VA.frame = f
  Layout:Place(f, "vault.window")
  return f
end
VA.Window = window

local function holder(bag)
  local h = VA.holders[bag]
  if not h then
    h = PUI:CreateFrame("Frame", nil, window(), nil, OWNER)
    h:SetID(bag)
    h:SetAllPoints(window())
    VA.holders[bag] = h
    VA.buttons[bag] = {}
  end
  return h
end

-- Pin/junk modes: a Phoenix overlay catches the click so the secure button
-- never runs (no item is used or moved by accident).
local function overlay(b)
  local o = PUI:CreateFrame("Button", nil, b, nil, OWNER)
  o:SetAllPoints(b)
  o:SetFrameLevel(b:GetFrameLevel() + 5)
  o:SetScript("OnClick", function() VA.ModeClick(b) end)
  o:Hide()
  b.puiOverlay = o
end

-- Buttons are only ever created out of combat (template is secure).
function VA.EnsureButtons()
  if InCombatLockdown() then CQ.Defer("vault.buttons", VA.EnsureButtons) return false end
  for _, bag in ipairs(BAGS) do
    local h = holder(bag)
    local list = VA.buttons[bag]
    for slot = #list + 1, C_Container.GetContainerNumSlots(bag) do
      local b = PUI:CreateFrame("ItemButton", nil, h, "ContainerFrameItemButtonTemplate", OWNER)
      b:Initialize(bag, slot)
      local t = b:CreateFontString(nil, "OVERLAY")
      t:SetFontObject(Media:FontObject("small"))
      t:SetPoint("TOPLEFT", 2, -2)
      VA.ilvlText[b] = t
      local n = b:CreateFontString(nil, "OVERLAY")
      n:SetFontObject(Media:FontObject("body"))
      n:SetPoint("LEFT", b, "RIGHT", 6, 0)
      n:SetWidth(220)
      n:SetJustifyH("LEFT")
      VA.nameText[b] = n
      local e = b:CreateTexture(nil, "OVERLAY", nil, 2)
      e:SetPoint("TOPLEFT", -1, 1)
      e:SetPoint("BOTTOMRIGHT", 1, -1)
      e:SetColorTexture(1, 1, 1, 0)
      VA.border[b] = e
      overlay(b)
      b.puiBag, b.puiSlot = bag, slot
      list[slot] = b
    end
  end
  return true
end

function VA.ItemLevel(bag, slot, itemID)
  if not itemID or not C_Item.IsEquippableItem(itemID) then return nil end
  local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
  if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_TABARD" or equipLoc == "INVTYPE_BODY" then return nil end
  local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
  if not C_Item.DoesItemExist(loc) then return nil end
  return C_Item.GetCurrentItemLevel(loc)
end

-- Equipment-set membership per slot (names only, for rules and the category).
function VA.SetNames(bag, slot)
  if not C_Container.GetContainerItemEquipmentSetInfo then return nil end
  local inSet, list = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
  if not inSet or type(list) ~= "string" or list == "" then return nil end
  local out = {}
  for n in list:gmatch("[^,]+") do out[#out + 1] = (n:gsub("^%s+", ""):gsub("%s+$", "")) end
  return out
end

-- Facts for the rules engine (plain values only).
function VA.Facts(bag, slot, info)
  local id = info.itemID
  local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
  local name, expansion
  if C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
  local f = { id = id, link = info.hyperlink, name = name, quality = info.quality, count = info.stackCount, bound = info.isBound,
    noValue = info.hasNoValue, classID = classID, subclassID = subclassID, equipLoc = equipLoc, expansion = expansion,
    ilvl = s.ilvl and VA.ItemLevel(bag, slot, id) or nil, sets = VA.SetNames(bag, slot) }
  f.keystone = C_Item.IsItemKeystoneByID and C_Item.IsItemKeystoneByID(id) or false
  f.new = s.newCategory and C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot) or false
  return f
end

local function idSet(list)
  local out = {}
  for _, v in ipairs(list or {}) do local n = tonumber(v); if n then out[n] = true end end
  return out
end
function VA.Context()
  local ctx = { pins = idSet(s.pins), junk = idSet(s.junkList), assign = {}, rules = {}, hidden = {} }
  for _, item in ipairs(s.assign or {}) do
    local id, cat = item:match("^%s*(%d+)%s*=%s*(.-)%s*$")
    if id and cat ~= "" then ctx.assign[tonumber(id)] = cat end
  end
  for _, item in ipairs(s.rules or {}) do
    local rule = R.ParseRule(item)
    if rule then ctx.rules[#ctx.rules + 1] = rule end
  end
  for id, row in pairs(s.sections or {}) do if row.show == false then ctx.hidden[id] = true end end
  -- assignments may name a user rule by label
  for id, cat in pairs(ctx.assign) do
    for _, rule in ipairs(ctx.rules) do if rule.label:lower() == cat:lower() then ctx.assign[id] = rule.id end end
  end
  return ctx
end

function VA.UpdateButton(b, bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  local tex, count, locked, quality, link, filtered, noValue, itemID, bound
  if info then
    tex, count, locked, quality, link = info.iconFileID, info.stackCount, info.isLocked, info.quality, info.hyperlink
    filtered, noValue, itemID, bound = info.isFiltered, info.hasNoValue, info.itemID, info.isBound
  end
  SetItemButtonTexture(b, tex)
  SetItemButtonCount(b, count)
  SetItemButtonQuality(b, quality, link, false, bound)
  SetItemButtonDesaturated(b, locked)
  b:UpdateJunkItem(quality, noValue)
  if s.newGlow then b:UpdateNewItem(quality) end
  local match = not filtered
  if VA.searchRule and info then match = VA.searchRule(VA.Facts(bag, slot, info)) end
  b:SetMatchesSearch(match)
  local lvl = s.ilvl and VA.ItemLevel(bag, slot, itemID)
  VA.ilvlText[b]:SetText(lvl and tostring(lvl) or "")
  local r, g, bl = VA.QualityColor(quality)
  local edge = VA.border[b]
  if s.qualityBorder and r and quality and quality >= s.qualityMin then edge:SetColorTexture(r, g, bl, 0.9) else edge:SetColorTexture(1, 1, 1, 0) end
  local n = VA.nameText[b]
  if s.view == "list" and itemID then
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or ""
    n:SetText(((count or 1) > 1 and (count .. "x ") or "") .. (name or ""))
    if r then n:SetTextColor(r, g, bl) else n:SetTextColor(1, 1, 1) end
    n:Show()
  else
    n:Hide()
  end
  VA.Badge(b, link and lvl and VA.WantsBadge() and PUI.Wisdom.IsUpgrade(link))
  b.puiOverlay:SetShown(VA.mode ~= "use" and info ~= nil)
  return info
end

-- Upgrade badge from Wisdom (when that module is on), one texture per slot.
VA.badges = setmetatable({}, { __mode = "k" })
function VA.WantsBadge()
  local w = PUI.Wisdom
  return w ~= nil and w.active and w.settings.bags
end
function VA.Badge(b, on)
  local t = VA.badges[b]
  if not t then
    if not on then return end
    t = b:CreateTexture(nil, "OVERLAY")
    t:SetSize(14, 14)
    t:SetPoint("TOPLEFT", 1, -1)
    t:SetAtlas("PetJournal-FavoritesIcon")
    VA.badges[b] = t
  end
  t:SetShown(on and true or false)
end
