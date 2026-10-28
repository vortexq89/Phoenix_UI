local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault bank panel (plan 5.11: bank/warband/reagent tabs, guild bank, alts).
-- Tabs: Character, Warband, Reagents (reagents across your bank tabs), Guild,
-- Alts. At the banker the character and warband tabs use the game's secure
-- slot buttons (same holder pattern as the bags) so moving items stays
-- Blizzard's code; anywhere else every tab shows a read-only picture from
-- the last visit. The guild bank is read-only (current tab) while it is open.
-- Blizzard's bank window is kept but faded and click-through while Phoenix
-- shows the bank (FrameLedger restores it).
local _, ns = ...
local VA, ST = ns.VA, ns.Store
local Theme, Media, CQ, FL = PUI.Theme, PUI.Media, PUI.CombatQueue, PUI.FrameLedger
local OWNER = "Vault"
local s = VA.settings
local BK = { tab = "character", holders = {}, buttons = {}, tiles = {}, atBank = false, atGuild = false }
ns.Bank = BK
VA.Bank = BK
local PAD, TOP = 10, 58

local BI = (Enum and Enum.BagIndex) or {}
BK.CHAR = {}
for i = 1, 6 do local v = BI["CharacterBankTab_" .. i]; BK.CHAR[#BK.CHAR + 1] = v or (5 + i) end
BK.WARBAND = {}
for i = 1, 5 do local v = BI["AccountBankTab_" .. i]; BK.WARBAND[#BK.WARBAND + 1] = v or (11 + i) end
BK.TABS = { "character", "warband", "reagents", "guild", "alts" }
BK.TAB_LABELS = { character = "Character", warband = "Warband", reagents = "Reagents", guild = "Guild bank", alts = "Alts" }

function BK.BagsFor(tab)
  if tab == "warband" then return BK.WARBAND end
  return BK.CHAR
end

local function frame()
  if BK.frame then return BK.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_VaultBank", UIParent, nil, OWNER)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.6)
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(Media:FontObject("header"))
  f.title:SetPoint("TOPLEFT", PAD + 2, -10)
  f.title:SetText("Bank")
  local close = PUI:CreateFrame("Button", nil, f, "UIPanelCloseButton", OWNER)
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() BK.Hide() end)
  f.tabs = {}
  local x = PAD
  for _, id in ipairs(BK.TABS) do
    local b = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
    b:SetSize(86, 20)
    b:SetPoint("TOPLEFT", x, -32)
    b:SetText(BK.TAB_LABELS[id])
    b:SetScript("OnClick", function() BK.Select(id) end)
    f.tabs[id] = b
    x = x + 90
  end
  f.deposit = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
  f.deposit:SetSize(120, 20)
  f.deposit:SetPoint("BOTTOMRIGHT", -PAD, 6)
  f.deposit:SetText("Deposit reagents")
  f.deposit:SetScript("OnClick", function() BK.Deposit() end)
  f.sort = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
  f.sort:SetSize(60, 20)
  f.sort:SetPoint("RIGHT", f.deposit, "LEFT", -4, 0)
  f.sort:SetText("Sort")
  f.sort:SetScript("OnClick", function() BK.SortTab() end)
  f.info = f:CreateFontString(nil, "OVERLAY")
  f.info:SetFontObject(Media:FontObject("small"))
  f.info:SetPoint("BOTTOMLEFT", PAD + 2, 11)
  f:Hide()
  BK.frame = f
  return f
end
BK.Frame = frame

-- Secure slot buttons for live bank bags, created out of combat.
function BK.EnsureButtons()
  if InCombatLockdown() then CQ.Defer("vault.bankbuttons", BK.EnsureButtons) return false end
  local f = frame()
  for _, list in ipairs({ BK.CHAR, BK.WARBAND }) do
    for _, bag in ipairs(list) do
      local h = BK.holders[bag]
      if not h then
        h = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
        h:SetID(bag)
        h:SetAllPoints(f)
        BK.holders[bag] = h
        BK.buttons[bag] = {}
      end
      local btns = BK.buttons[bag]
      for slot = #btns + 1, C_Container.GetContainerNumSlots(bag) do
        local b = PUI:CreateFrame("ItemButton", nil, h, "ContainerFrameItemButtonTemplate", OWNER)
        b:Initialize(bag, slot)
        btns[slot] = b
      end
    end
  end
  return true
end

-- Read-only tile (Phoenix button, no item actions).
local function tile(i)
  local t = BK.tiles[i]
  if t then return t end
  t = PUI:CreateFrame("Button", nil, frame(), nil, OWNER)
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetAllPoints()
  t.edge = t:CreateTexture(nil, "OVERLAY")
  t.edge:SetPoint("TOPLEFT", -1, 1)
  t.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  t.count = t:CreateFontString(nil, "OVERLAY")
  t.count:SetFontObject(Media:FontObject("small"))
  t.count:SetPoint("BOTTOMRIGHT", -2, 2)
  t:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetItemByID(self.itemID) end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  BK.tiles[i] = t
  return t
end

local function hideAll()
  for _, list in pairs(BK.buttons) do for _, b in ipairs(list) do b:Hide() end end
  for _, t in ipairs(BK.tiles) do t:Hide() end
end

-- entries: { { itemID, count, quality, link } } -> tiles
function BK.DrawTiles(entries, size, cols)
  for i, e in ipairs(entries) do
    local t = tile(i)
    local dx, dy = VA.Cell(i - 1, cols, size, s.gap)
    t:ClearAllPoints()
    t:SetSize(size, size)
    t:SetPoint("TOPLEFT", frame(), "TOPLEFT", PAD + dx, -(TOP + dy))
    t.itemID, t.link = e.itemID, e.link
    t.icon:SetTexture(e.icon or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.itemID)))
    t.count:SetText((e.count or 1) > 1 and e.count or "")
    local quality = e.quality or (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(e.itemID))
    local r, g, b = VA.QualityColor(quality)
    t.edge:SetColorTexture(r or 0, g or 0, b or 0, r and 0.8 or 0)
    t:Show()
  end
  return math.max(1, math.ceil(#entries / cols))
end

function BK.CountsToEntries(map)
  local out = {}
  for id, n in pairs(map or {}) do out[#out + 1] = { itemID = id, count = n } end
  table.sort(out, function(a, b) return a.itemID < b.itemID end)
  return out
end

-- Live entries from bank bags filtered by a facts predicate (reagents tab).
function BK.LiveEntries(bags, pred)
  local out = {}
  for _, bag in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (not pred or pred(VA.Facts(bag, slot, info))) then
        out[#out + 1] = { itemID = info.itemID, count = info.stackCount, quality = info.quality, link = info.hyperlink, icon = info.iconFileID }
      end
    end
  end
  return out
end

function BK.GuildEntries()
  local out = {}
  if not (BK.atGuild and GetCurrentGuildBankTab and GetGuildBankItemInfo) then return out end
  local tab = GetCurrentGuildBankTab()
  for slot = 1, 98 do
    local icon, count, _, _, quality = GetGuildBankItemInfo(tab, slot)
    if icon then
      local link = GetGuildBankItemLink and GetGuildBankItemLink(tab, slot)
      local id = link and tonumber(link:match("item:(%d+)"))
      out[#out + 1] = { itemID = id, count = count, quality = quality, link = link, icon = icon }
    end
  end
  return out
end

function BK.Render()
  local f = BK.frame
  if not f or not f:IsShown() then return end
  hideAll()
  for id, b in pairs(f.tabs) do b:SetEnabled(id ~= BK.tab) end
  local size, cols = s.slotSize, s.bankColumns
  local rows, note = 1, ""
  local isReagent = function(facts) return ns.Rules.Builtin(facts, {}) == "reagents" end
  if (BK.tab == "character" or BK.tab == "warband") and BK.atBank then
    local n = 0
    for _, bag in ipairs(BK.BagsFor(BK.tab)) do
      for slot, b in ipairs(BK.buttons[bag] or {}) do
        if slot <= C_Container.GetContainerNumSlots(bag) then
          local info = C_Container.GetContainerItemInfo(bag, slot)
          SetItemButtonTexture(b, info and info.iconFileID)
          SetItemButtonCount(b, info and info.stackCount)
          SetItemButtonQuality(b, info and info.quality, info and info.hyperlink, false, info and info.isBound)
          local dx, dy = VA.Cell(n, cols, size, s.gap)
          b:ClearAllPoints()
          b:SetSize(size, size)
          b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + dx, -(TOP + dy))
          b:Show()
          n = n + 1
        end
      end
    end
    rows = math.max(1, math.ceil(n / cols))
    note = n == 0 and "No bank tabs bought yet." or ""
  elseif BK.tab == "reagents" then
    local entries = BK.atBank and BK.LiveEntries(BK.CHAR, isReagent) or {}
    if not BK.atBank then
      local me = (ST.DB() or { chars = {} }).chars[PUI.DB:CharKey()]
      entries = BK.CountsToEntries(me and me.bank)
      local keep = {}
      for _, e in ipairs(entries) do
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(e.itemID)
        if isReagent({ classID = classID, quality = 1 }) then keep[#keep + 1] = e end
      end
      entries = keep
      note = "Read-only: last bank visit."
    end
    rows = BK.DrawTiles(entries, size, cols)
  elseif BK.tab == "guild" then
    rows = BK.DrawTiles(BK.GuildEntries(), size, cols)
    note = BK.atGuild and "Read-only view of the open guild bank tab." or "Open the guild bank to see it here."
  elseif BK.tab == "alts" then
    local alt = ST.Alts(true)[BK.altIndex or 1]
    if alt then
      local merged = {}
      for id, n in pairs(alt.bags) do merged[id] = (merged[id] or 0) + n end
      for id, n in pairs(alt.bank) do merged[id] = (merged[id] or 0) + n end
      rows = BK.DrawTiles(BK.CountsToEntries(merged), size, cols)
      note = alt.key .. " (" .. date("%m-%d", alt.updated) .. ")  - click Alts again for the next character"
    else
      note = "Log in on your other characters once with Vault on to see their items here."
    end
  else
    local db = ST.DB()
    local map = BK.tab == "warband" and db and db.warband or (db and db.chars[PUI.DB:CharKey()] or {}).bank
    rows = BK.DrawTiles(BK.CountsToEntries(map), size, cols)
    note = "Read-only: last bank visit."
  end
  f.info:SetText(note)
  f.deposit:SetShown(BK.atBank and BK.tab ~= "guild" and BK.tab ~= "alts")
  f.sort:SetShown(BK.atBank and (BK.tab == "character" or BK.tab == "warband"))
  f:SetSize(math.max(PAD * 2 + 5 * 90, PAD * 2 + cols * (size + s.gap)), TOP + rows * (size + s.gap) + 36)
end

function BK.Select(tab)
  if tab == "alts" and BK.tab == "alts" then
    local n = #ST.Alts(true)
    BK.altIndex = n > 0 and ((BK.altIndex or 1) % n + 1) or 1
  end
  BK.tab = tab
  BK.Render()
end

function BK.Deposit()
  if not BK.atBank or InCombatLockdown() then return false end
  local bt = Enum and Enum.BankType
  C_Bank.AutoDepositItemsIntoBank(BK.tab == "warband" and (bt and bt.Account or 2) or (bt and bt.Character or 0))
  return true
end
function BK.SortTab()
  if not BK.atBank or InCombatLockdown() then return end
  if BK.tab == "warband" then C_Container.SortAccountBankBags() else C_Container.SortBankBags() end
end

local function place()
  local f = frame()
  f:ClearAllPoints()
  if VA.frame and VA.frame:IsShown() then f:SetPoint("TOPRIGHT", VA.frame, "TOPLEFT", -8, 0)
  else f:SetPoint("CENTER", -200, 0) end
end

function BK.Show()
  if not VA.active then return end
  place()
  frame():Show()
  BK.Render()
end
function BK.Hide()
  if BK.frame then BK.frame:Hide() end
end
function BK.Toggle()
  if BK.frame and BK.frame:IsShown() then BK.Hide() else BK.Show() end
end
function BK.OnBagsHidden() if not BK.atBank and not BK.atGuild then BK.Hide() end end

-- Banker events --------------------------------------------------------------
function BK.Opened()
  BK.atBank = true
  BK.EnsureButtons()
  ST.SnapshotBank(BK.CHAR, BK.WARBAND)
  if s.bankView then
    local bf = rawget(_G, "BankFrame")
    if bf and FL:Take(OWNER, bf, "vault.bankframe") then bf:SetAlpha(0); if not InCombatLockdown() then bf:EnableMouse(false) end end
    BK.tab = "character"
    VA.Open()
    BK.Show()
  end
end
function BK.Closed()
  BK.atBank = false
  ST.SnapshotBank(BK.CHAR, BK.WARBAND)
  FL:Release(OWNER, "vault.bankframe")
  BK.Render()
end
function BK.GuildOpened() BK.atGuild = true; if s.bankView then BK.tab = "guild"; BK.Show() end end
function BK.GuildClosed() BK.atGuild = false; BK.Render() end
function BK.Disable()
  BK.Hide()
  FL:Release(OWNER, "vault.bankframe")
end
