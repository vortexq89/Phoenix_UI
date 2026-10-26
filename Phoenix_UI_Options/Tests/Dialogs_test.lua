local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Own dialogs (plan 1.26/1.27, G5, G10, G37).
local Tests, Dialogs = PUI.Tests, PUI.Dialogs

Tests:Add("Dialogs", "confirm: accept and cancel run once; a new dialog resets the old one", function(t)
  local accepted, cancelled = 0, 0
  t:cleanup(function() Dialogs:Close() end)
  local w = Dialogs:Confirm({ title = "Delete profile", text = "Delete Raid?", accept = "Delete", danger = true,
    onAccept = function() accepted = accepted + 1 end, onCancel = function() cancelled = cancelled + 1 end })
  t:ok(w:IsShown(), "shown")
  t:eq(w.title:GetText(), "Delete profile", "title")
  PUI.Options.Dialogs:Accept()
  PUI.Options.Dialogs:Accept()
  t:eq(accepted, 1, "accept runs once")
  Dialogs:Confirm({ title = "A", text = "a", onCancel = function() cancelled = cancelled + 1 end })
  Dialogs:Confirm({ title = "B", text = "b" })
  t:eq(cancelled, 1, "replacing an open dialog cancels it (revert on every hide path)")
  t:eq(w.title:GetText(), "B", "reset")
  t:throws(function() Dialogs:Confirm({ text = "no title" }) end, "spec checked")
  t:ok(StaticPopup_FindVisible() == nil, "no StaticPopup used")
end)

Tests:Add("Dialogs", "keep-or-revert counts down on an owned Ticker entry and reverts", function(t)
  local reverted, kept = 0, 0
  t:cleanup(function() Dialogs:Close() end)
  Dialogs:KeepOrRevert({ title = "UI scale", seconds = 2, onKeep = function() kept = kept + 1 end, onRevert = function() reverted = reverted + 1 end })
  t:ok(PUI.Ticker:IsRegistered("dialogs.countdown"), "countdown armed")
  PUI.Ticker.entries["dialogs.countdown"].fn()
  PUI.Ticker.entries["dialogs.countdown"].fn()
  t:eq(reverted, 1, "reverted at zero")
  t:ok(not PUI.Ticker:IsRegistered("dialogs.countdown"), "timer disarmed (G33)")
  Dialogs:KeepOrRevert({ title = "UI scale", onKeep = function() kept = kept + 1 end, onRevert = function() reverted = reverted + 1 end })
  PUI.Options.Dialogs:Accept()
  t:eq(kept, 1, "kept")
  t:eq(reverted, 1, "no revert after keep")
end)

Tests:Add("Dialogs", "copy box is read-only and pre-selected", function(t)
  t:cleanup(function() Dialogs:Close() end)
  local w = Dialogs:Copy("Copy link", "https://example.invalid/x")
  t:eq(w.box:GetText(), "https://example.invalid/x", "text")
  w.box.scripts.OnTextChanged(w.box, true)
  t:eq(w.box:GetText(), "https://example.invalid/x", "typing cannot change it")
  t:ok(not w.buttons[2]:IsShown(), "single Done button")
end)
