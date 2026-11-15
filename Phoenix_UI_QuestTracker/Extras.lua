local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Quest Tracker, deferred batch C:
--  * quest-item buttons: a SecureActionButton beside each tracked quest that
--    has a usable quest item (GetQuestLogSpecialItemInfo). The buttons sit on
--    UIParent at the row's screen position and are placed out of combat only,
--    so the tracker never becomes protected.
--  * auto-share: quests you accept are shared with your group when the game
--    allows it (C_QuestLog.IsPushableQuest), never in combat.
local _, ns = ...
local QT = ns.QT
local Schema, CQ = PUI.Schema, PUI.CombatQueue
local OWNER = "QuestTracker"

local X = { buttons = {}, s = { items = true, itemSize = 22, autoShare = false, shareSkipDaily = true } }
QT.Extras = X
local s = X.s

-- Quest item for a quest (nil when it has none or hides it once complete).
function X.Item(questID)
  local index = C_QuestLog.GetLogIndexForQuestID(questID)
  if not index then return nil end
  local link, icon, charges, showComplete = GetQuestLogSpecialItemInfo(index)
  if not link then return nil end
  if C_QuestLog.IsComplete(questID) and not showComplete then return nil end
  return { link = link, icon = icon, charges = charges }
end

local function button(i)
  local b = X.buttons[i]
  if b then return b end
  b = PUI:CreateFrame("Button", "PhoenixUI_QuestItem" .. i, UIParent, "SecureActionButtonTemplate", OWNER)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "item")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.count = b:CreateFontString(nil, "OVERLAY")
  b.count:SetFontObject(PUI.Media:FontObject("small"))
  b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  b:SetScript("OnEnter", function(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  X.buttons[i] = b
  return b
end

-- Place one button per quest (first row of the quest) out of combat.
function X.Place()
  if InCombatLockdown() then CQ.Defer("qt.items", X.Place); return end
  local used = 0
  local f = QT.frame
  if QT.active and s.items and f and f:IsShown() then
    local seen = {}
    for _, r in ipairs(QT.rows) do
      local d = QT.rowData[r]
      local id = r:IsShown() and d and d.quest
      if id and not seen[id] then
        seen[id] = true
        local item = X.Item(id)
        local left, top = f:GetLeft(), r:GetTop()
        if item and left and top then
          used = used + 1
          local b = button(used)
          b:SetAttribute("item", item.link)
          b.link = item.link
          b.icon:SetTexture(item.icon)
          b.count:SetText(item.charges and item.charges > 1 and tostring(item.charges) or "")
          b:SetSize(s.itemSize, s.itemSize)
          b:ClearAllPoints()
          b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 4, top)
          b:Show()
        end
      end
    end
  end
  for i = used + 1, #X.buttons do X.buttons[i]:Hide() end
  X.count = used
end

local refresh = QT.Refresh
function QT.Refresh()
  refresh()
  X.Place()
end

-- Auto-share --------------------------------------------------------------------------
function X.OnAccepted(questID)
  if not (QT.active and s.autoShare) or InCombatLockdown() or not IsInGroup() then return false end
  if not C_QuestLog.IsPushableQuest(questID) then return false end
  if s.shareSkipDaily and C_QuestLog.IsRepeatableQuest(questID) then return false end
  local index = C_QuestLog.GetLogIndexForQuestID(questID)
  if not index then return false end
  QuestLogPushQuest(index)
  return true
end
X.events = CreateFrame("Frame")
X.events:RegisterEvent("QUEST_ACCEPTED")
X.events:SetScript("OnEvent", function(_, _, a1, a2) X.OnAccepted(a2 or a1) end)

local function key(name, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; if QT.active then QT.Refresh() else X.Place() end end
  def.searchTags = { "quest", "tracker", "item", "share" }
  QT.schema["qt." .. name] = def
  Schema:Register("qt." .. name, def)
  s[field] = Schema:Get("qt." .. name)
end
key("itemButtons", "items", { type = "toggle", default = true, label = "Quest item buttons",
  tooltip = "A clickable button beside quests that have a usable item (placed outside combat).", mode = "simple" })
key("itemSize", "itemSize", { type = "range", default = 22, min = 16, max = 36, step = 1, label = "Quest item button size",
  tooltip = "Size of the quest item buttons.", mode = "advanced" })
key("autoShare", "autoShare", { type = "toggle", default = false, label = "Share accepted quests",
  tooltip = "Shares quests you accept with your group when the game allows it.", mode = "simple" })
key("shareSkipRepeatable", "shareSkipDaily", { type = "toggle", default = true, label = "Do not share repeatable quests",
  tooltip = "Daily and weekly quests are not shared automatically.", mode = "advanced" })
