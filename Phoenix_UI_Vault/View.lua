local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault views: places the secure slot buttons for the current view, draws
-- section headers (Phoenix font strings only), handles pin/junk modes, junk
-- selling, sort/undo, search and the bag-key hooks.
local _, ns = ...
local VA, R, Sort = ns.VA, ns.Rules, ns.Sort
local Media, Schema = PUI.Media, PUI.Schema
local OWNER = "Vault"
local s = VA.settings
local PAD, HEADER, FOOTER, SECTION = 10, 64, 30, 20
VA.VIEWS = { "category", "grid", "compact", "list" }

local function label(i)
  local l = VA.labels[i]
  if not l then
    l = VA.frame:CreateFontString(nil, "OVERLAY")
    l:SetFontObject(Media:FontObject("small"))
    VA.labels[i] = l
  end
  l:Show()
  return l
end

-- Pure grid maths (tested): position of item n (0-based) in a block.
function VA.Cell(n, cols, size, gap)
  return (n % cols) * (size + gap), math.floor(n / cols) * (size + gap)
end

local function place(b, x, y, size)
  b:ClearAllPoints()
  b:SetSize(size, size)
  b:SetPoint("TOPLEFT", VA.frame, "TOPLEFT", x, -y)
  b:Show()
end

-- Collect filled and empty slots once per refresh.
function VA.Scan()
  local filled, empty = {}, {}
  for _, bag in ipairs(VA.BAGS) do
    local list = VA.buttons[bag] or {}
    local slots = C_Container.GetContainerNumSlots(bag)
    for slot, b in ipairs(list) do
      if slot <= slots then
        local info = VA.UpdateButton(b, bag, slot)
        if info then filled[#filled + 1] = { b = b, facts = VA.Facts(bag, slot, info), info = info }
        else empty[#empty + 1] = b end
      else
        b:Hide()
      end
    end
  end
  return filled, empty
end

local function byQuality(a, b)
  local qa, qb = a.facts.quality or 0, b.facts.quality or 0
  if qa ~= qb then return qa > qb end
  return (a.facts.id or 0) < (b.facts.id or 0)
end

function VA.Refresh()
  if not VA.active or not VA.frame then return end
  local size = s.view == "compact" and s.compactSize or (s.view == "list" and VA.SIZES.list or s.slotSize)
  local gap = s.gap
  local cols = s.view == "list" and s.listColumns or s.columns
  local colW = s.view == "list" and 260 or (size + gap)
  local filled, empty = VA.Scan()
  for _, l in ipairs(VA.labels) do l:Hide() end
  local y, li = HEADER, 0
  if s.view == "category" or s.view == "list" then
    local sections = R.Group(filled, { pins = VA.ctx.pins, assign = VA.ctx.assign, rules = VA.ctx.rules, hidden = VA.ctx.hidden,
      junk = VA.ctx.junk, showNew = s.newCategory, sortWithin = byQuality })
    VA.sections = sections
    for _, sec in ipairs(sections) do
      li = li + 1
      local l = label(li)
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", VA.frame, "TOPLEFT", PAD + 2, -y)
      local collapsed = s.sections[sec.id] and s.sections[sec.id].collapsed
      l:SetText((collapsed and "+ " or "") .. sec.label:upper() .. "  |cff8a8a8a" .. #sec.items .. "|r"
        .. (sec.id == "junk" and VA.atMerchant and "  |cffe8a33d(Sell junk)|r" or ""))
      y = y + SECTION
      for i, e in ipairs(sec.items) do
        if collapsed then e.b:Hide() else
          local dx, dy = (i - 1) % cols * colW, math.floor((i - 1) / cols) * (size + gap)
          place(e.b, PAD + dx, y + dy, size)
        end
      end
      if not collapsed then y = y + math.ceil(#sec.items / cols) * (size + gap) + 6 end
    end
    if #empty > 0 then
      li = li + 1
      local l = label(li)
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", VA.frame, "TOPLEFT", PAD + 2, -y)
      l:SetText("EMPTY  |cff8a8a8a" .. #empty .. "|r")
      y = y + SECTION
      local shown = s.hideEmpty and math.min(1, #empty) or #empty
      for i, b in ipairs(empty) do
        if i <= shown then
          local dx, dy = (i - 1) % cols * colW, math.floor((i - 1) / cols) * (size + gap)
          place(b, PAD + dx, y + dy, size)
        else b:Hide() end
      end
      y = y + math.ceil(shown / cols) * (size + gap) + 6
    end
  else
    VA.sections = {}
    local n = 0
    for _, bag in ipairs(VA.BAGS) do
      local slots = C_Container.GetContainerNumSlots(bag)
      for slot, b in ipairs(VA.buttons[bag] or {}) do
        if slot <= slots then
          local dx, dy = VA.Cell(n, cols, size, gap)
          place(b, PAD + dx, y + dy, size)
          n = n + 1
        end
      end
    end
    y = y + math.max(1, math.ceil(n / cols)) * (size + gap)
  end
  VA.frame:SetSize(PAD * 2 + cols * colW - (s.view == "list" and 0 or gap), y + FOOTER + 4)
  VA.frame.title:SetText("Bags  |cff8a8a8a" .. #filled .. "/" .. (#filled + #empty) .. "  " .. s.view .. "|r")
  if ns.Store then VA.frame.info:SetText(ns.Store.FooterText()) end
  VA.frame.sell:SetShown(VA.atMerchant and VA.JunkCount() > 0)
  VA.frame.undo:SetEnabled(Sort.CanUndo())
  VA.frame.modeNote:SetText(VA.mode == "pin" and "|cffe8a33dPin mode: click items|r" or VA.mode == "junk" and "|cffe8a33dJunk mode: click items|r" or "")
  VA.count, VA.free = #filled, #empty
  return #filled, #empty
end

function VA.Rebuild()
  VA.ctx = VA.Context()
  VA.Refresh()
end

function VA.CycleView()
  local i = 1
  for k, v in ipairs(VA.VIEWS) do if v == s.view then i = k end end
  Schema:Set("vault.view", VA.VIEWS[i % #VA.VIEWS + 1])
end

-- Search -------------------------------------------------------------------
function VA.SetSearch(text)
  local mode = R.SearchMode(text)
  VA.searchRule = nil
  if mode == "rule" then
    local fn = R.Compile(text)
    VA.searchRule = fn
    C_Container.SetItemSearch("")
  else
    C_Container.SetItemSearch(text or "")
  end
  VA.Refresh()
end

-- Pin / junk modes ---------------------------------------------------------
local function toggleIn(key, id)
  local list = Schema.Copy(Schema:Get(key))
  local found
  for i, v in ipairs(list) do if tonumber(v) == id then found = i end end
  if found then table.remove(list, found) else list[#list + 1] = tostring(id) end
  Schema:Set(key, list)
  return not found
end
VA.ToggleIn = toggleIn

function VA.SetMode(mode)
  VA.mode = mode
  VA.Refresh()
end
function VA.ModeClick(b)
  local info = C_Container.GetContainerItemInfo(b.puiBag, b.puiSlot)
  if not info or not info.itemID then return end
  if VA.mode == "pin" then toggleIn("vault.pins", info.itemID)
  elseif VA.mode == "junk" then toggleIn("vault.junkList", info.itemID) end
end

-- Junk (owner) -------------------------------------------------------------
function VA.JunkList()
  local out, junk = {}, (VA.ctx and VA.ctx.junk) or {}
  for _, bag in ipairs(VA.BAGS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.hasNoValue and (info.quality == 0 or junk[info.itemID]) and not (VA.ctx and VA.ctx.pins[info.itemID]) then
        out[#out + 1] = { bag = bag, slot = slot, grey = info.quality == 0 }
      end
    end
  end
  return out
end
function VA.JunkCount() return #VA.JunkList() end
VA.Junk = VA.JunkCount

-- Greys go through the game's own sell-all; items you marked as junk are
-- sold one by one (at most 12 a visit so they stay in buyback).
function VA.SellJunk()
  if not VA.atMerchant or InCombatLockdown() then return 0 end
  local list, n, marked = VA.JunkList(), 0, 0
  local greys = false
  for _, e in ipairs(list) do
    if e.grey then greys = true
    elseif marked < 12 then C_Container.UseContainerItem(e.bag, e.slot); marked = marked + 1 end
  end
  if greys then C_MerchantFrame.SellAllJunkItems() end
  n = marked + (greys and 1 or 0)
  return n
end
function VA.OwnsJunk() return VA.active end

-- Sort / undo --------------------------------------------------------------
function VA.Sort()
  if C_Container.SetSortBagsRightToLeft then C_Container.SetSortBagsRightToLeft(s.sortRightToLeft) end
  Sort.Sort(VA.BAGS)
  VA.Refresh()
end
function VA.UndoSort()
  local n, missing = Sort.Undo(VA.BAGS)
  if n and missing and missing > 0 then
    PUI.Announce.Say(missing .. " stack(s) were merged by the sort and stay where they are.")
  end
  VA.Refresh()
  return n, missing
end

function VA.OpenSets()
  if PUI.Options and PUI.Options.Open then PUI.Options:Open("Loadouts") end
end

-- Open / close and the bag keys ---------------------------------------------
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
  VA.Window():Show()
  VA.open = true
  VA.Rebuild()
end
function VA.Close()
  if VA.frame then VA.frame:Hide() end
  VA.open = false
  if VA.mode ~= "use" then VA.mode = "use" end
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

function VA.Hook()
  if VA.hooked then return end
  VA.hooked = true
  hooksecurefunc("ToggleAllBags", VA.OnToggle)
  hooksecurefunc("ToggleBackpack", VA.OnToggle)
  hooksecurefunc("OpenAllBags", VA.OnOpen)
  hooksecurefunc("CloseAllBags", VA.OnClose)
end
