local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Sort and undo (plan 5.11 upgrade: undo the last sort). Before Phoenix asks
-- the game to sort (C_Container.SortBags), it snapshots every slot. Undo
-- builds a move plan (Plan, pure) that puts each item back where it was and
-- runs it one swap at a time on a Ticker entry, only out of combat (paused by
-- CombatQueue) and only while the two slots are unlocked. Stacks the sort
-- merged cannot be split back; those are reported, never guessed.
local _, ns = ...
local Ticker, CQ = PUI.Ticker, PUI.CombatQueue
local OWNER = "Vault"
local S = { snapshot = nil, queue = nil }
ns.Sort = S

-- Slot identity: item link (or ID) plus stack size.
function S.Key(info)
  if not info then return nil end
  return tostring(info.hyperlink or info.itemID) .. "#" .. tostring(info.stackCount or 1)
end

-- layout = { ["bag:slot"] = key or nil }, slots = ordered { "bag:slot", ... }
function S.Snapshot(bags, read)
  local layout, slots = {}, {}
  for _, bag in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local id = bag .. ":" .. slot
      slots[#slots + 1] = id
      layout[id] = S.Key((read or C_Container.GetContainerItemInfo)(bag, slot))
    end
  end
  return { layout = layout, slots = slots, t = time() }
end

-- Pure planner: swaps that turn `current` into `target` over `slots`.
-- Returns moves { { from, to } } and the count of items that cannot return.
function S.Plan(slots, current, target)
  local cur = {}
  for _, id in ipairs(slots) do cur[id] = current[id] end
  local moves, missing = {}, 0
  for _, dst in ipairs(slots) do
    local want = target[dst]
    if want ~= cur[dst] then
      local src
      if want then
        for _, id in ipairs(slots) do
          if id ~= dst and cur[id] == want and target[id] ~= cur[id] then src = id; break end
        end
      end
      if src then
        moves[#moves + 1] = { from = src, to = dst }
        cur[src], cur[dst] = cur[dst], cur[src]
      elseif want then
        missing = missing + 1
      end
    end
  end
  return moves, missing
end

local function split(id) local b, s = id:match("^(%-?%d+):(%d+)$"); return tonumber(b), tonumber(s) end
local function locked(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  return info and info.isLocked
end

function S.Step()
  local q = S.queue
  if not q or #q == 0 then S.Stop(); return end
  if InCombatLockdown() then S.Stop(); CQ.Defer("vault.undo", S.Resume); return end
  if GetCursorInfo and GetCursorInfo() then return end
  local m = q[1]
  local fb, fs = split(m.from)
  local tb, ts = split(m.to)
  if locked(fb, fs) or locked(tb, ts) then return end
  table.remove(q, 1)
  C_Container.PickupContainerItem(fb, fs)
  C_Container.PickupContainerItem(tb, ts)
  if ClearCursor then ClearCursor() end
  if #q == 0 then S.Stop() end
end
function S.Stop() if Ticker:IsRegistered("vault.undo") then Ticker:Unregister("vault.undo") end end
function S.Resume() if S.queue and #S.queue > 0 then Ticker:Register("vault.undo", 0.15, S.Step, OWNER) end end

function S.Sort(bags)
  if InCombatLockdown() then return false end
  S.snapshot = S.Snapshot(bags)
  C_Container.SortBags()
  return true
end

-- Returns moves planned and items that could not be put back.
function S.Undo(bags)
  local snap = S.snapshot
  if not snap or InCombatLockdown() then return nil end
  local now = S.Snapshot(bags)
  local moves, missing = S.Plan(snap.slots, now.layout, snap.layout)
  S.queue = moves
  S.snapshot = nil
  S.Resume()
  return #moves, missing
end
function S.CanUndo() return S.snapshot ~= nil end
