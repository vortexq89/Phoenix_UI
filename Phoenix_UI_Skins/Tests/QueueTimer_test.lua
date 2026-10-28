local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Skins queue pop-up timer.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ, Ticker = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Ticker
local SK = ns.SK

Tests:Add("Skins", "queue pop-up timer reads PUI.Queue under the ready dialogs; one ticker only while open", function(t)
  if not H then return end
  local Q = SK.QueueTimer
  local keys = { "module.Skins", "skins.queueTimer", "skins.queueTimer.height", "skins.queueTimer.text", "queue.lfgSeconds" }
  local saved = {}
  for i, k in ipairs(keys) do saved[i] = Schema:Get(k) end
  local dialog = CreateFrame("Frame", "LFGDungeonReadyDialog")
  t:cleanup(function()
    PUI.Queue:OnEvent("LFG_PROPOSAL_DONE")
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
    rawset(_G, "LFGDungeonReadyDialog", nil)
  end)
  Schema:Set("module.Skins", true); CQ.Drain()
  dialog:Show()
  PUI.Queue:OnEvent("LFG_PROPOSAL_SHOW")
  t:ok(Q.bar and Q.bar:IsShown(), "bar under the dungeon ready dialog")
  t:ok(Ticker:IsRegistered("skins.queueTimer"), "ticker while the pop is open")
  t:eq(Q.bar.text:GetText(), "40", "same 40 s countdown as the minimap")
  t:eq(Q.bar:GetValue(), 1, "full at the start")
  Schema:Set("queue.lfgSeconds", 30)
  PUI.Queue:OnEvent("LFG_PROPOSAL_SHOW")
  t:eq(Q.bar.text:GetText(), "30", "queue.lfgSeconds read live")
  local frac, text, r = Q.State(5, 40, 10)
  t:same({ frac, text, r }, { 0.125, "5", 0.95 }, "red under the warning time")
  Schema:Set("skins.queueTimer.height", 14)
  t:eq(Q.bar:GetHeight(), 14, "height live")
  Schema:Set("skins.queueTimer.text", false)
  t:eq(Q.bar.text:GetText(), "", "seconds off live")
  Schema:Set("skins.queueTimer", false)
  t:eq(Q.bar:IsShown(), false, "off live")
  t:eq(Ticker:IsRegistered("skins.queueTimer"), false, "no ticker when off")
  Schema:Set("skins.queueTimer", true)
  PUI.Queue:OnEvent("LFG_PROPOSAL_DONE")
  t:eq(Q.bar:IsShown(), false, "hidden when the pop ends")
  t:eq(Ticker:IsRegistered("skins.queueTimer"), false, "ticker gone")
end)
