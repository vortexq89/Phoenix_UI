local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault (PUI_V2 5.13, Phase 5 core): every bag in one Phoenix window. Slots
-- are the game's own ContainerFrameItemButtonTemplate buttons, created out of
-- combat under one holder frame per bag (the holder's ID is the bag ID), so
-- using, moving and selling items stays Blizzard's secure code. Search uses
-- C_Container.SetItemSearch, sort uses C_Container.SortBags. The bag keys
-- open this window instead of Blizzard's bags while it is on (post-hooks on
-- the open/close/toggle functions); turning it off gives the keys back.
-- Off by default.
local _, ns = ...
local Schema, Layout, CQ, Theme, Media = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Theme, PUI.Media
local OWNER = "Vault"
local BAGS = { 0, 1, 2, 3, 4, 5 }
local PAD, HEADER, FOOTER = 8, 28, 24

local VA = { active = false, holders = {}, buttons = {}, hooked = false, open = false }
ns.VA = VA
PUI.Vault = VA
local s = { mode = "grid", columns = 12, ilvl = true, junk = true, newGlow = true }
VA.settings = s
VA.ilvlText = setmetatable({}, { __mode = "k" })
VA.MODES = { grid = 37, compact = 30 }

local function window()
  local f = VA.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_Vault", UIParent, nil, OWNER)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.6)
  local search = PUI:CreateFrame("EditBox", "PhoenixUI_VaultSearch", f, "SearchBoxTemplate", OWNER)
  search:SetSize(160, 20)
  search:SetPoint("TOPLEFT", PAD + 4, -4)
  search:HookScript("OnTextChanged", function(self) C_Container.SetItemSearch(self:GetText()) end)
  f.search = search
  local sort = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
  sort:SetSize(60, 20)
  sort:SetPoint("TOPRIGHT", -PAD, -4)
  sort:SetText("Sort")
  sort:SetScript("OnClick", function() if not InCombatLockdown() then C_Container.SortBags() end end)
  local junk = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
  junk:SetSize(80, 20)
  junk:SetPoint("RIGHT", sort, "LEFT", -4, 0)
  junk:SetText("Sell junk")
  junk:SetScript("OnClick", function() VA.SellJunk() end)
  junk:Hide()
  f.junk = junk
  local info = f:CreateFontString(nil, "OVERLAY")
  info:SetFontObject(Media:FontObject("small"))
  info:SetPoint("BOTTOMLEFT", PAD, 6)
  f.info = info
  local close = PUI:CreateFrame("Button", nil, f, "UIPanelCloseButton", OWNER)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 22)
  close:SetScript("OnClick", function() VA.Close() end)
  tinsert(UISpecialFrames, "PhoenixUI_Vault")
  f:HookScript("OnHide", function() VA.open = false end)
  f:Hide()
  VA.frame = f
  Layout:Place(f, "vault.window")
  return f
end

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
  b:SetMatchesSearch(not filtered)
  local lvl = s.ilvl and VA.ItemLevel(bag, slot, itemID)
  VA.ilvlText[b]:SetText(lvl and tostring(lvl) or "")
  return info ~= nil
end

function VA.Junk()
  local n = 0
  for _, bag in ipairs(BAGS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == 0 and not info.hasNoValue then n = n + 1 end
    end
  end
  return n
end

function VA.SellJunk()
  if not VA.atMerchant then return end
  C_MerchantFrame.SellAllJunkItems()
end

-- Positions every slot in a grid; returns the item count and free slots.
function VA.Refresh()
  if not VA.active or not VA.frame then return end
  local size = VA.MODES[s.mode] or VA.MODES.grid
  local cols = s.columns
  local i, used, free = 0, 0, 0
  for _, bag in ipairs(BAGS) do
    local list = VA.buttons[bag] or {}
    local slots = C_Container.GetContainerNumSlots(bag)
    for slot, b in ipairs(list) do
      if slot <= slots then
        local col, rowN = i % cols, math.floor(i / cols)
        b:ClearAllPoints()
        b:SetSize(size, size)
        b:SetPoint("TOPLEFT", VA.frame, "TOPLEFT", PAD + col * (size + 2), -(HEADER + rowN * (size + 2)))
        if VA.UpdateButton(b, bag, slot) then used = used + 1 else free = free + 1 end
        b:Show()
        i = i + 1
      else
        b:Hide()
      end
    end
  end
  local rows = math.max(1, math.ceil(i / cols))
  VA.frame:SetSize(PAD * 2 + cols * (size + 2), HEADER + rows * (size + 2) + FOOTER)
  VA.frame.info:SetText(string.format("%d free   %s", free, C_CurrencyInfo.GetCoinTextureString(GetMoney())))
  VA.frame.junk:SetShown(s.junk and VA.atMerchant and VA.Junk() > 0)
  VA.count, VA.free = used, free
  return used, free
end

local BLIZZARD = { "ContainerFrameCombinedBags" }
for n = 1, 13 do BLIZZARD[#BLIZZARD + 1] = "ContainerFrame" .. n end
function VA.HideBlizzard()
  for _, name in ipairs(BLIZZARD) do
    local f = rawget(_G, name)
    if f and f:IsShown() then f:Hide() end
  end
end

function VA.Open()
  if not VA.active then return end
  VA.HideBlizzard()
  if not VA.EnsureButtons() then return end
  window():Show()
  VA.open = true
  VA.Refresh()
end
function VA.Close()
  if VA.frame then VA.frame:Hide() end
  VA.open = false
end
function VA.Toggle() if VA.open then VA.Close() else VA.Open() end end

-- Blizzard's bag functions call each other (Toggle -> Close -> Open), so the
-- hooks only record what happened and the result is settled one frame later.
function VA.Note(kind)
  if not VA.active then return end
  local p = VA.pending
  if not p then
    p = { wasOpen = VA.open, kinds = {} }
    VA.pending = p
    C_Timer.After(0, VA.Resolve)
  end
  p.kinds[kind] = true
end
function VA.Resolve()
  local p = VA.pending
  VA.pending = nil
  if not p or not VA.active then return end
  VA.HideBlizzard()
  if p.kinds.toggle then
    if p.wasOpen then VA.Close() else VA.Open() end
  elseif p.kinds.open then
    VA.Open()
  elseif p.kinds.close then
    VA.Close()
  end
end
function VA.OnToggle() VA.Note("toggle") end
function VA.OnOpen() VA.Note("open") end
function VA.OnClose() VA.Note("close") end

local function hook()
  if VA.hooked then return end
  VA.hooked = true
  hooksecurefunc("ToggleAllBags", VA.OnToggle)
  hooksecurefunc("ToggleBackpack", VA.OnToggle)
  hooksecurefunc("OpenAllBags", VA.OnOpen)
  hooksecurefunc("CloseAllBags", VA.OnClose)
end

local function onEnable(mod)
  VA.active = true
  hook()
  window()
  VA.EnsureButtons()
  local refresh = function() if VA.open then VA.Refresh() end end
  mod:RegisterEvent("BAG_UPDATE_DELAYED", function() VA.EnsureButtons(); refresh() end)
  mod:RegisterEvent("INVENTORY_SEARCH_UPDATE", refresh)
  mod:RegisterEvent("ITEM_LOCK_CHANGED", refresh)
  mod:RegisterEvent("PLAYER_MONEY", refresh)
  mod:RegisterEvent("MERCHANT_SHOW", function() VA.atMerchant = true; refresh() end)
  mod:RegisterEvent("MERCHANT_CLOSED", function() VA.atMerchant = false; refresh() end)
end

local function onDisable()
  VA.active = false
  VA.Close()
  if VA.frame and VA.frame.search then VA.frame.search:SetText("") end
end

Layout:RegisterElement("vault.window", { label = "Bags", owner = OWNER, size = { 470, 300 }, default = { point = "BOTTOMRIGHT", x = -60, y = 120 } })

local schema = {}
VA.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; VA.Refresh() end
  schema["vault." .. name] = def
end
key("mode", { type = "select", default = "grid", choices = { "grid", "compact" }, label = "View",
  tooltip = "Grid uses full-size slots; compact uses smaller ones.", mode = "simple" })
key("columns", { type = "range", default = 12, min = 6, max = 24, step = 1, label = "Columns", tooltip = "Slots per row.", mode = "simple" })
key("ilvl", { type = "toggle", default = true, label = "Item level on gear", tooltip = "Writes the item level on equippable items.", mode = "advanced" })
key("junk", { type = "toggle", default = true, label = "Sell junk button", tooltip = "Shows a Sell junk button at vendors when you carry grey items.", mode = "advanced" })
key("newGlow", { type = "toggle", default = true, label = "New item glow", tooltip = "Highlights items you just received.", mode = "advanced" })

VA.module = PUI:RegisterModule(OWNER, {
  label = "Vault", tooltip = "All bags in one window with search, sort, item levels and junk selling.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
