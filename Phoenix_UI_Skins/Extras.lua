local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Phoenix extras on skinned Blizzard windows (skins v2). Each extra is a
-- schema key (skins.<group>.<name>, in the window's gear flyout and on the
-- Skins page) plus its window code. All of it is Phoenix-owned: font strings,
-- textures and buttons Phoenix creates; Blizzard functions are only post-hooked
-- (hooksecurefunc), nothing is written into a Blizzard table, and values the
-- game may hide (map position) go through Secret.IsSecret, never compared.
local _, ns = ...
local SK = ns.SK
local Schema, Theme, Media, Ticker, Secret = PUI.Schema, PUI.Theme, PUI.Media, PUI.Ticker, PUI.Secret
local OWNER = "Skins"
local X = { s = {}, labels = setmetatable({}, { __mode = "k" }) }
SK.Extras = X
local s = X.s

local function refresh() if SK.active then SK.Refresh() end end
local function toggle(label, tooltip, default, mode, after)
  return { type = "toggle", default = default ~= false, label = label, tooltip = tooltip, mode = mode or "advanced", after = after }
end
-- name -> schema def (without key/owner/apply; Packs.lua adds them)
SK.EXTRA_DEFS = {
  charIlvl = toggle("Item level on slots", "Item level under every equipment slot (Character and Inspect).", true, "simple"),
  charEnchants = toggle("Missing enchant flags", "A red mark on enchantable slots without an enchant.", true, "simple"),
  charDurability = toggle("Durability on slots", "Durability percent on damaged items.", true),
  charModelLight = toggle("Model backdrop", "Phoenix ember backdrop behind the character model.", true),
  mailCollectGold = toggle("Collect gold button", "A Phoenix button in the inbox that takes only the gold (no items, skips COD) from every mail.", true, "simple"),
  mapCoords = toggle("Coordinates strip", "Player and cursor coordinates along the bottom of the world map.", true, "simple"),
  popupDanger = toggle("Danger colour on destructive popups", "Delete, abandon and disband confirmations get a red accept button.", true),
  editModeStudio = toggle("Open Phoenix Studio button", "A button in Blizzard's Edit Mode window that opens Phoenix Studio.", true),
}
for name, def in pairs(SK.EXTRA_DEFS) do s[name] = def.default end
function X.On(name) return SK.active and s[name] ~= false end

-- Small Phoenix font string on a Blizzard button (one per button and slot).
local function label(btn, key, point, x, y, role)
  local bag = X.labels[btn]
  if not bag then bag = {}; X.labels[btn] = bag end
  local fs = bag[key]
  if not fs then
    fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Media:FontObject(role or "small"))
    fs:SetPoint(point, x, y)
    bag[key] = fs
  end
  return fs
end
X.Label = label

-- Character / Inspect slots ---------------------------------------------------------------
local ENCHANTABLE = { [5] = true, [7] = true, [8] = true, [9] = true, [11] = true, [12] = true, [15] = true, [16] = true }
X.ENCHANTABLE = ENCHANTABLE
-- EnchantID(link) -> the enchant field of an item link ("" when none).
function X.EnchantID(link)
  if type(link) ~= "string" then return nil end
  return link:match("item:%-?%d+:(%-?%d*)")
end

function X.SlotUpdate(btn, unit)
  if not (btn and btn.GetID) then return end
  local slot = btn:GetID()
  local link = GetInventoryItemLink(unit or "player", slot)
  local il = label(btn, "ilvl", "BOTTOM", 0, 2)
  local en = label(btn, "ench", "TOPLEFT", 2, -2)
  local du = label(btn, "dura", "TOP", 0, -2)
  local ilvl = link and C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
  if X.On("charIlvl") and ilvl then il:SetText(ilvl); Theme:Paint(il, "text.primary", 1, "text"); il:Show() else il:Hide() end
  local enchant = X.EnchantID(link)
  if X.On("charEnchants") and link and ENCHANTABLE[slot] and enchant == "" then
    en:SetText("!"); en:SetTextColor(1, 0.33, 0.4); en:Show()
  else en:Hide() end
  local cur, max = nil, nil
  if (unit or "player") == "player" then cur, max = GetInventoryItemDurability(slot) end
  if X.On("charDurability") and cur and max and max > 0 and cur < max then
    du:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5)); du:SetTextColor(1, 0.76, 0.29); du:Show()
  else du:Hide() end
end
function X.HideSlot(btn) for _, fs in pairs(X.labels[btn] or {}) do fs:Hide() end end

local CHAR_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet",
  "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand" }
X.CHAR_SLOTS = CHAR_SLOTS
local function eachSlot(prefix, fn)
  for _, name in ipairs(CHAR_SLOTS) do
    local b = rawget(_G, prefix .. name .. "Slot")
    if b then fn(b) end
  end
end

local function modelLight(frame, id)
  local scene = rawget(_G, "CharacterModelScene")
  if not scene then return end
  local t = SK.Controls.Over(id, scene, "light", "BACKGROUND", "ModelBackdrop_Ember", -8)
  t:ClearAllPoints(); t:SetAllPoints()
  t:SetShown(X.On("charModelLight"))
end

-- Mail: collect gold ---------------------------------------------------------------------
-- Gold() -> inbox indices that carry money, no COD and no items (pure; tests).
function X.GoldMails()
  local list = {}
  local n = GetInboxNumItems and GetInboxNumItems() or 0
  for i = 1, n do
    local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
    if type(money) == "number" and money > 0 and (cod or 0) == 0 and not hasItem then list[#list + 1] = i end
  end
  return list
end
-- Taking money is server-throttled: one mail per Ticker step, last index first
-- so earlier indices stay valid.
function X.CollectGold()
  local list = X.GoldMails()
  X.collectQueue = list
  if #list == 0 then return 0 end
  Ticker:Register("skins.mailGold", 0.4, function()
    local q = X.collectQueue
    local i = q and table.remove(q)
    if i then TakeInboxMoney(i) end
    if not q or #q == 0 then Ticker:Unregister("skins.mailGold") end
  end, OWNER)
  return #list
end
local function mailButton(frame, id)
  local inbox = rawget(_G, "InboxFrame")
  if not inbox then return end
  local b = X.mailBtn
  if not b then
    b = PUI:CreateFrame("Button", nil, inbox, "UIPanelButtonTemplate", OWNER)
    b:SetSize(110, 22)
    b:SetText("Collect gold")
    local open = rawget(_G, "OpenAllMail")
    if open then b:SetPoint("LEFT", open, "RIGHT", 8, 0) else b:SetPoint("BOTTOM", inbox, "BOTTOM", 60, 92) end
    b:SetScript("OnClick", function() X.CollectGold() end)
    X.mailBtn = b
  end
  b:SetShown(X.On("mailCollectGold"))
  table.insert(SK.owned[id], function() b:Hide() end)
end

-- World map: coordinates strip -----------------------------------------------------------
function X.MapText()
  local map = C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  local text = "Player --"
  if pos then
    local x, y = pos:GetXY()
    if not (Secret.IsSecret(x) or Secret.IsSecret(y)) and type(x) == "number" and type(y) == "number" then
      text = string.format("Player %.1f, %.1f", x * 100, y * 100)
    end
  end
  local wm = rawget(_G, "WorldMapFrame")
  local sc = wm and wm.ScrollContainer
  if sc and sc.GetNormalizedCursorPosition and sc:IsMouseOver() then
    local cx, cy = sc:GetNormalizedCursorPosition()
    if type(cx) == "number" and type(cy) == "number" and not (Secret.IsSecret(cx) or Secret.IsSecret(cy)) then
      text = text .. string.format("   Cursor %.1f, %.1f", cx * 100, cy * 100)
    end
  end
  return text
end
local function mapStrip(frame, id)
  if frame:GetName() ~= "WorldMapFrame" then return end
  local strip = X.mapStrip
  if not strip then
    strip = PUI:CreateFrame("Frame", nil, frame, nil, OWNER)
    strip:SetHeight(18)
    strip:SetPoint("BOTTOMLEFT", 8, 6)
    strip:SetWidth(320)
    strip:SetFrameLevel(frame:GetFrameLevel() + 30)
    strip.bg = strip:CreateTexture(nil, "BACKGROUND")
    strip.bg:SetAllPoints()
    strip.bg:SetColorTexture(0, 0, 0, 0.55)
    strip.text = strip:CreateFontString(nil, "OVERLAY")
    strip.text:SetFontObject(Media:FontObject("mono"))
    strip.text:SetPoint("LEFT", 6, 0)
    strip:SetScript("OnShow", function(self)
      Ticker:Register("skins.mapCoords", 0.1, function() self.text:SetText(X.MapText()) end, OWNER)
    end)
    strip:SetScript("OnHide", function() Ticker:Unregister("skins.mapCoords") end)
    X.mapStrip = strip
  end
  strip:SetShown(X.On("mapCoords"))
  table.insert(SK.owned[id], function() strip:Hide() end)
end

-- Popups: danger colour --------------------------------------------------------------------
X.DANGER = { "DELETE", "DESTROY", "ABANDON", "DISBAND", "REMOVE", "UNLEARN", "RESET", "QUIT_GUILD", "GUILD_DEMOTE", "CONFIRM_LEAVE" }
-- IsDanger(which): a destructive StaticPopup by its Blizzard name (a plain string).
function X.IsDanger(which)
  if type(which) ~= "string" or Secret.IsSecret(which) then return false end
  for _, word in ipairs(X.DANGER) do if which:find(word, 1, true) then return true end end
  return false
end
function X.PopupShown(dialog)
  if not (dialog and SK.applied.popups) then return end
  local b1 = SK.Controls.K(dialog, "button1") or (dialog.GetButton1 and dialog:GetButton1())
  local face = b1 and SK.Controls.over[b1] and SK.Controls.over[b1].face
  if not face then return end
  if X.On("popupDanger") and X.IsDanger(dialog.which) then
    local path = SK.Controls.Tex("Button_Danger")
    if path then face:SetTexture(path) end
  else
    local path = SK.Controls.Tex("Button_Normal")
    if path then face:SetTexture(path) end
  end
end

-- Edit Mode: open Phoenix Studio ----------------------------------------------------------
local function studioButton(frame, id)
  if frame:GetName() ~= "EditModeManagerFrame" or not SK.Controls.Usable(frame) then return end
  local b = X.studioBtn
  if not b then
    b = PUI:CreateFrame("Button", nil, frame, "UIPanelButtonTemplate", OWNER)
    b:SetSize(170, 22)
    b:SetText("Open Phoenix Studio")
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    b:SetScript("OnClick", function() PUI.OptionsHost:OpenStudio() end)
    X.studioBtn = b
  end
  b:SetShown(X.On("editModeStudio"))
  table.insert(SK.owned[id], function() b:Hide() end)
end

-- Window code, merged into the packs by Packs.lua ----------------------------------------------
SK.WINDOW_IMPL = {
  character = {
    hooks = { { "PaperDollItemSlotButton_Update" } },
    update = function(btn) X.SlotUpdate(btn, "player") end,
    extra = function(frame, _, id) eachSlot("Character", function(b) X.SlotUpdate(b, "player") end); modelLight(frame, id) end,
    revert = function() eachSlot("Character", X.HideSlot) end,
  },
  inspect = {
    hooks = { { "InspectPaperDollItemSlotButton_Update" } },
    update = function(btn) local f = rawget(_G, "InspectFrame"); X.SlotUpdate(btn, f and f.unit or "target") end,
    revert = function() eachSlot("Inspect", X.HideSlot) end,
  },
  mail = { extra = mailButton },
  map = { extra = mapStrip },
  popups = { hooks = { { "StaticPopup_OnShow" } }, update = X.PopupShown },
  editMode = { extra = studioButton },
}
