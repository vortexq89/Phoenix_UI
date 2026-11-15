local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder, review gaps (2026-10-27), workarounds W5 and W6:
--  * Bosses down: Blizzard's own list reads C_LFGList.GetSearchResultEncounterInfo,
--    which is not in the API documentation. It is used only when it exists
--    (looked up with rawget at call time), so a patch that removes it just
--    turns the feature off. Adds a "N down" tag to raid rows and the filter
--    word "bossesdown" (for example "bossesdown == 0" for fresh runs).
--  * Your own lockout (always works, documented): for raid rows the map and
--    difficulty come from C_LFGList.GetActivityInfoTable, the bosses from the
--    Encounter Journal, and each kill from C_RaidLocks.IsEncounterComplete;
--    the row says "you 3/8".
--  * Application ages: every application's age is kept from
--    LFG_LIST_APPLICATION_STATUS_UPDATED (QueueHelper), the oldest one is
--    named on the panel, and a "Cancel oldest" button calls
--    C_LFGList.CancelApplication (also undocumented, existence-checked) from
--    your click. In combat the cancel waits in the CombatQueue.
local _, ns = ...
local GF, P = ns.GF, ns.Panel
local Schema, Secret, CQ = PUI.Schema, PUI.Secret, PUI.CombatQueue
local OWNER = "GroupFinder"
local s = GF.settings
local X = {}
GF.Gaps = X

local function hidden(name)
  local lib = rawget(_G, "C_LFGList")
  local fn = type(lib) == "table" and rawget(lib, name)
  return type(fn) == "function" and fn or nil
end
X.Hidden = hidden

-- BossesDown(resultID) -> number or nil (nil: the function is gone or the result is unknown)
function X.BossesDown(resultID)
  local fn = hidden("GetSearchResultEncounterInfo")
  if not (fn and resultID) then return nil end
  local list = fn(resultID)
  if type(list) ~= "table" then return 0 end
  local n = 0
  for _, name in ipairs(list) do if name ~= nil then n = n + 1 end end
  return n
end

if GF.Extras and GF.Extras.RegisterSort then
  GF.Extras.RegisterSort("bossesdown", "raid bosses this group has already defeated (0 when unknown)", function(id) return X.BossesDown(id) or 0 end)
end

-- OwnLockout(activityID) -> killed, total (nil when not a raid or unknown)
X.lockCache = {}
function X.OwnLockout(activityID)
  if type(activityID) ~= "number" then return nil end
  local info = C_LFGList.GetActivityInfoTable(activityID)
  local mapID, diff = info and info.mapID, info and info.difficultyID
  if type(mapID) ~= "number" or type(diff) ~= "number" or mapID == 0 then return nil end
  local jid = C_EncounterJournal.GetInstanceForGameMap(mapID)
  local byIndex = rawget(_G, "EJ_GetEncounterInfoByIndex")
  if type(jid) ~= "number" or type(byIndex) ~= "function" then return nil end
  local ids = X.lockCache[jid]
  if not ids then
    ids = {}
    for i = 1, 30 do
      local name, _, _, _, _, _, encounterID = byIndex(i, jid)
      if not name then break end
      if type(encounterID) == "number" then ids[#ids + 1] = encounterID end
    end
    X.lockCache[jid] = ids
  end
  if #ids == 0 then return nil end
  local killed = 0
  for _, id in ipairs(ids) do if C_RaidLocks.IsEncounterComplete(mapID, id, diff) == true then killed = killed + 1 end end
  return killed, #ids
end

local rowText = P.RowText
function P.RowText(e)
  local l, r = rowText(e)
  if s.bossesDown and e and e.meta and e.meta.activity and e.meta.activity.category == "raid" then
    local n = X.BossesDown(e.id)
    if n and n > 0 then l = l .. " |cffe8a33d" .. n .. " down|r" end
  end
  if s.ownLockout and e and e.meta and e.meta.activity and e.meta.activity.category == "raid" then
    local k, total = X.OwnLockout(e.meta.activity.id)
    if k then l = l .. " |cffb0b0b0you " .. k .. "/" .. total .. "|r" end
  end
  return l, r
end

-- Applications --------------------------------------------------------------------------------------------
function X.Oldest()
  local Q = ns.Queue
  if not Q then return nil end
  local _, id = Q.ApplicationCount()
  if not id then return nil end
  return id, math.floor((GetTime() - Q.applications[id]) / 60)
end
function X.CanCancel() return s.cancelOldest and hidden("CancelApplication") ~= nil end
function X.CancelOldest()
  local id = X.Oldest()
  local fn = hidden("CancelApplication")
  if not (id and fn) then return false end
  CQ.Defer("gf.cancelOldest", function() local f = hidden("CancelApplication"); if f then f(id) end end)
  return true
end

local update = P.Update
function P.Update()
  update()
  local f = P.frame
  if not (f and f:IsShown()) then return end
  if not f.cancel then
    f.cancel = CreateFrame("Button", nil, f); f.cancel:SetSize(90, 16); f.cancel:SetPoint("BOTTOMRIGHT", -8, 28)
    f.cancel.text = f.cancel:CreateFontString(nil, "OVERLAY"); f.cancel.text:SetFontObject(PUI.Media:FontObject("small"))
    f.cancel.text:SetAllPoints(); f.cancel.text:SetText("|cffe8a33dCancel oldest|r")
    f.cancel:SetScript("OnClick", function() X.CancelOldest() end)
  end
  local id, age = X.Oldest()
  f.cancel:SetShown(id ~= nil and X.CanCancel())
  if id and s.oldestAge then f.apps:SetText(f.apps:GetText() .. "  |cffb0b0b0oldest " .. age .. "m|r") end
  for i = 1, P.shownRows or 0 do
    local r = P.rows[i]
    if r and id and r.resultID == id and s.oldestAge then r.name:SetTextColor(PUI.Theme:Color("accent")) end
  end
end

-- LFG reminder (review gap): when a queue pops (dungeon finder, battleground
-- or a Group Finder invite), the game icon flashes in the taskbar, a sound
-- plays on the Master channel (heard even with effects muted or the game in
-- the background) and a Phoenix notice says what popped.
X.POP = { LFG_PROPOSAL_SHOW = "Your group is ready", LFG_LIST_APPLICATION_STATUS_UPDATED = "Group Finder invite" }
function X.Pop(event, a, b)
  if not s.popAlert then return false end
  if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" and b ~= "invited" then return false end
  local text = X.POP[event]
  if not text then return false end
  if FlashClientIcon then FlashClientIcon() end
  if s.popSound then PlaySound(SOUNDKIT and SOUNDKIT.READY_CHECK or 8960, "Master") end
  if PUI.Toast then PUI.Toast:Show(text, "ok", true) end
  X.lastPop = text
  return true
end
X.popEvents = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
X.popEvents:SetScript("OnEvent", function(_, event, a, b) X.Pop(event, a, b) end)
function X.TrackPop()
  local e = X.popEvents
  e:UnregisterAllEvents()
  if GF.active and s.popAlert then e:RegisterEvent("LFG_PROPOSAL_SHOW"); e:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED") end
end
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then X.TrackPop() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then X.TrackPop() end end)

local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v; X.TrackPop(); if GF.active then GF.Refresh(); P.Update() end end
  GF.schema["gf." .. name] = def
  Schema:Register("gf." .. name, def)
  s[name] = Schema:Get("gf." .. name)
end
key("bossesDown", { type = "toggle", default = true, mode = "simple", label = "Bosses down on raid rows",
  tooltip = "Shows how many bosses a raid group has already killed and adds the filter word bossesdown. Uses a game function Blizzard's own list uses; it turns off by itself if a patch removes it." })
key("ownLockout", { type = "toggle", default = true, mode = "simple", label = "Your lockout on raid rows",
  tooltip = "For raid groups, shows how many of that raid's bosses you have already killed this week at that difficulty." })
key("oldestAge", { type = "toggle", default = true, mode = "simple", label = "Show the age of your oldest application",
  tooltip = "Names your oldest application on the panel and highlights its row." })
key("cancelOldest", { type = "toggle", default = true, mode = "advanced", label = "Cancel oldest button",
  tooltip = "A button on the panel that cancels your oldest application, so a new one fits under the limit of five. In combat it waits until combat ends." })
key("popAlert", { type = "toggle", default = true, mode = "simple", label = "Queue pop reminder",
  tooltip = "When your group is ready or a Group Finder group invites you, the game icon flashes, a sound plays and a notice appears.", searchTags = { "queue", "pop", "lfg", "reminder" } })
key("popSound", { type = "toggle", default = true, mode = "advanced", label = "Queue pop sound",
  tooltip = "Play the ready sound on the Master channel, so you hear it with effects muted or the game in the background." })
X.TrackPop()
