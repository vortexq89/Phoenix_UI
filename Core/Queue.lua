local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Queue (plan 1.O "Queue-pop countdown, queue status"): the one shared
-- queue-status and queue-pop countdown provider. Group Finder owns the
-- feature; the Minimap queue eye and the Skins queue-popup timer only read
-- this provider, so there is never a second timer. Event-driven only: the
-- countdown is a deadline (GetTime() + seconds) that readers turn into text on
-- their own Ticker entry while they are shown.
--   Queue:Pop() -> { kind = "lfg"|"pvp", deadline, total } or nil
--   Queue:Remaining() -> seconds left on the current pop, or nil
--   Queue:Status() -> { lfg = bool, pvp = bool, listed = bool }
-- Kernel signal "QUEUE_CHANGED" fires on every change.
local Queue = { pop = nil, status = { lfg = false, pvp = false, listed = false }, lfgSeconds = 40 }
PUI.Queue = Queue

local function changed() PUI.Kernel:Fire("QUEUE_CHANGED", Queue.pop) end

function Queue:Pop() return self.pop end

function Queue:Remaining()
  local p = self.pop
  if not p then return nil end
  local left = p.deadline - GetTime()
  if left <= 0 then return 0 end
  return left
end

function Queue:Status() return self.status end

-- Battleground / arena invite: the client knows the exact expiry.
local function pvpPop()
  local n = type(GetMaxBattlefieldID) == "function" and GetMaxBattlefieldID() or 0
  for i = 1, n do
    local status = GetBattlefieldStatus(i)
    if status == "confirm" then
      local ms = GetBattlefieldPortExpiration(i)
      local secs = type(ms) == "number" and ms or 0
      if secs > 1000 then secs = secs / 1000 end -- older clients returned milliseconds
      return secs
    end
  end
end

local function anyPvpQueued()
  local n = type(GetMaxBattlefieldID) == "function" and GetMaxBattlefieldID() or 0
  for i = 1, n do
    local status = GetBattlefieldStatus(i)
    if status == "queued" or status == "confirm" then return true end
  end
  return false
end

function Queue:OnEvent(event)
  if event == "LFG_PROPOSAL_SHOW" then
    self.pop = { kind = "lfg", deadline = GetTime() + self.lfgSeconds, total = self.lfgSeconds }
  elseif event == "LFG_PROPOSAL_FAILED" or event == "LFG_PROPOSAL_SUCCEEDED" or event == "LFG_PROPOSAL_DONE" then
    if self.pop and self.pop.kind == "lfg" then self.pop = nil end
  elseif event == "UPDATE_BATTLEFIELD_STATUS" then
    local secs = pvpPop()
    if secs and secs > 0 then
      if not (self.pop and self.pop.kind == "pvp") then self.pop = { kind = "pvp", deadline = GetTime() + secs, total = secs } end
    elseif self.pop and self.pop.kind == "pvp" then
      self.pop = nil
    end
    self.status.pvp = anyPvpQueued()
  end
  if event == "LFG_UPDATE" or event == "LFG_QUEUE_STATUS_UPDATE" or event:find("^LFG_PROPOSAL") then
    local mode = GetLFGMode and GetLFGMode(LE_LFG_CATEGORY_LFD or 1)
    self.status.lfg = mode ~= nil
  end
  if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
    self.status.listed = C_LFGList.GetActiveEntryInfo() ~= nil
  end
  changed()
end

Queue.EVENTS = { "LFG_PROPOSAL_SHOW", "LFG_PROPOSAL_FAILED", "LFG_PROPOSAL_SUCCEEDED", "LFG_PROPOSAL_DONE",
  "LFG_UPDATE", "LFG_QUEUE_STATUS_UPDATE", "UPDATE_BATTLEFIELD_STATUS", "LFG_LIST_ACTIVE_ENTRY_UPDATE" }
local f = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
for _, ev in ipairs(Queue.EVENTS) do f:RegisterEvent(ev) end
f:SetScript("OnEvent", function(_, event) Queue:OnEvent(event) end)
Queue.frame = f

PUI.Schema:Register("queue.lfgSeconds", {
  type = "range", default = 40, min = 20, max = 60, step = 1, owner = "Core",
  label = "Dungeon queue-pop time", tooltip = "How long a dungeon or raid finder invite stays open, used for the queue-pop countdown everywhere (minimap queue eye, queue popup). Battleground invites use the game's own expiry.",
  mode = "advanced", searchTags = { "queue", "countdown", "lfg", "pop" },
  apply = function(v) Queue.lfgSeconds = v end,
})
