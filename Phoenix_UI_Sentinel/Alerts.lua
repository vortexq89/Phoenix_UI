local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Alerts (mockup 15 "new-error alert"): popup + count badge ON at first
-- install; sound, chat line and auto-open OFF. One alert per error
-- signature per throttle window (the error is always counted). Auto-open
-- never happens in combat: it waits for the end of the fight. Ignored
-- errors do not alert but stay listed. With BugSack loaded you choose who
-- shows new errors (Sentinel still captures and uploads either way).
local S = PUI.Sentinel
local Alerts = { last = {}, unseen = 0 }
S.Alerts = Alerts
local o = {}
Alerts.opts = o

Alerts.SOUNDS = { ["Raid Warning"] = 8959, ["Ready Check"] = 8960, Tell = 3081, Alarm = 12867 }

function Alerts:Yield() return PUI.Coexist:Yields("sentinel.display") end

-- Decide(inc, now) -> true when this occurrence should alert (pure).
function Alerts:Decide(inc, now, state)
  if inc.kind == "heartbeat" or inc.kind == "test" then return false end
  if state == "ignored" then return false end
  local last = self.last[inc.hash]
  if last and now - last < (o.throttle or 60) then return false end
  return true
end

function Alerts:OnError(inc, isNew)
  local state = S.Store and S.Store:State(inc) or "new"
  if isNew or state == "back" then self.unseen = self.unseen + 1 end
  self:PaintBadge()
  local now = GetTime()
  if not self:Decide(inc, now, state) or not PUI.Kernel.loggedIn then return false end
  self.last[inc.hash] = now
  if self:Yield() then return false end
  if S.toastEnabled and S.Toast then S.Toast:Notify(inc) end
  if o.alertSound then PlaySound(self.SOUNDS[o.alertSoundName] or 8959, "Master") end
  if o.alertChat then
    PUI.Slash.Print(string.format("error in %s: %s  %s", inc.module or "?", (inc.message or ""):sub(1, 80), PUI.Links.Make("sentinel", inc.hash, "open")))
  end
  if o.autoOpen then
    if InCombatLockdown() then PUI.CombatQueue.Defer("sentinel.autoOpen", function() S.Reporter:Open(inc) end)
    else S.Reporter:Open(inc) end
  end
  return true
end

function Alerts:Seen() self.unseen = 0; self:PaintBadge() end

-- Badge: a small button with the count of new errors this session.
PUI.Layout:RegisterElement("sentinel.badge", { label = "Error count badge", owner = "Sentinel", size = { 64, 22 }, default = { point = "TOPRIGHT", x = -230, y = -8 } })
function Alerts:BuildBadge()
  local b = PUI:CreateFrame("Button", "PhoenixUISentinelBadge", UIParent, nil, "Sentinel")
  b:SetSize(64, 22)
  PUI.Layout:Place(b, "sentinel.badge")
  b:SetFrameStrata("HIGH")
  PUI.Theme:Backdrop(b, "surface.0")
  b.edge = b:CreateTexture(nil, "ARTWORK"); b.edge:SetPoint("TOPLEFT"); b.edge:SetPoint("BOTTOMLEFT"); b.edge:SetWidth(3)
  b.edge:SetColorTexture(0.85, 0.2, 0.2, 1)
  b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFontObject(PUI.Media:FontObject("small")); b.text:SetPoint("CENTER", 2, 0)
  b:SetScript("OnClick", function() S.Reporter:Toggle() end)
  b:Hide()
  self.badge = b
  return b
end
function Alerts:PaintBadge()
  local show = o.alertBadge and self.unseen > 0 and not self:Yield()
  if not show then if self.badge then self.badge:Hide() end return end
  local b = self.badge or self:BuildBadge()
  b.text:SetText(string.format("%d new", self.unseen))
  b:Show()
end
