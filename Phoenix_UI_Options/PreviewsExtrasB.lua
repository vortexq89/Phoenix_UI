local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for the Action Bars, Cooldown Manager and Resource Bars
-- extras (deferred batch A settings, previews added in batch B). Sample
-- values only, drawn on top of each page's own preview; display only.
local Options = PUI.Options
local Kit, Previews, PX = Options.Kit, Options.Previews, Options.PreviewsExtras
local Theme = PUI.Theme

local function tex(card, id, layer)
  local b = PX.Bag(card)
  local t = b[id]
  if not t then t = card:CreateTexture(nil, layer or "OVERLAY"); b[id] = t end
  t:ClearAllPoints()
  t:Show()
  return t
end
local function frame(card, id)
  local b = PX.Bag(card)
  local f = b[id]
  if not f then f = CreateFrame("Frame", nil, card); b[id] = f end
  f:ClearAllPoints()
  f:Show()
  return f
end
local function note(card, id, anchor, text)
  local fs = PX.Line(card, id)
  fs:ClearAllPoints()
  fs:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
  fs:SetWidth(384)
  fs:SetText(text)
  return fs
end
PX.Tex, PX.Frame = tex, frame

-- Action bars: cooldown number colour by time left, micro menu / bag bar
-- strip at its mode and scale, and a summary of the other extras.
PX.extend("ActionBars", function(card)
  local AB = PUI.ActionBars
  local X = AB and AB.Extras
  local st = Previews.State(card)
  if not (X and st.icons and st.icons[2]) then return end
  local E = X.settings
  local cd = st.icons[2].sample
  if E.cdColors then
    local c = E.cdMidColor -- "18" sits between soon and mid when mid > 18
    if 18 <= E.cdSoon then c = E.cdSoonColor elseif 18 > E.cdMid then c = E.cdColor end
    cd:SetTextColor(c.r, c.g, c.b)
  else
    cd:SetTextColor(1, 1, 1)
  end
  local strip = frame(card, "abMicro")
  local scale = E.micro.scale
  strip:SetSize(8 * 14 * scale, 18 * scale)
  strip:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)
  strip.cells = rawget(strip, "cells") or {}
  for i = 1, 8 do
    local c = strip.cells[i]
    if not c then c = strip:CreateTexture(nil, "ARTWORK"); strip.cells[i] = c end
    c:ClearAllPoints()
    c:SetSize(12 * scale, 16 * scale)
    c:SetPoint("LEFT", strip, "LEFT", (i - 1) * 14 * scale, 0)
    Theme:Paint(c, i == 8 and "accent" or "surface.2", 1)
  end
  strip:SetAlpha(E.micro.mode == "hide" and 0.08 or E.micro.mode == "fade" and E.fadeAlpha or 1)
  local parts = {}
  if E.look ~= "phoenix" then parts[#parts + 1] = E.look .. " look" end
  if E.mask ~= "square" then parts[#parts + 1] = E.mask .. " icons" end
  if E.hideHousing then parts[#parts + 1] = "hidden in housing" end
  if E.hideGamepad then parts[#parts + 1] = "hidden with a gamepad" end
  if E.petRightClick then parts[#parts + 1] = "right-click pet autocast" end
  if #(E.overrides or {}) > 0 then parts[#parts + 1] = #E.overrides .. " button overrides" end
  local n = st.abNote
  note(card, "abExtrasNote", n or card, "Micro menu (top right): " .. E.micro.mode .. ".  "
    .. (#parts > 0 and table.concat(parts, ", ") or "Phoenix look, square icons"))
end)

-- Cooldown manager: glow on a proc sample, hidden spells dimmed, the assist
-- icon, a buff bar with ticks and the focus kick bar.
PX.extend("CooldownManager", function(card)
  local CDM = PUI.CooldownManager
  local X = CDM and CDM.Extras
  local st = Previews.State(card)
  if not (X and st.cdm and st.cdm[3]) then return end
  local E = X.settings
  local g = tex(card, "cdmGlow")
  g:SetPoint("TOPLEFT", st.cdm[3], "TOPLEFT", -3, 3)
  g:SetPoint("BOTTOMRIGHT", st.cdm[3], "BOTTOMRIGHT", 3, -3)
  g:SetColorTexture(E.glowColor.r, E.glowColor.g, E.glowColor.b, 0.55)
  g:SetShown(E.glowMode ~= "off")
  st.cdm[6]:SetAlpha(next(E.hide) and 0.2 or 1)
  local a = tex(card, "cdmAssist", "ARTWORK")
  local size = math.min(52, E.assistSize)
  a:SetSize(size, size)
  a:SetPoint("RIGHT", st.cdm[1], "LEFT", -12, 0)
  a:SetTexture(136048)
  a:SetShown(E.assist)
  local bar = frame(card, "cdmBuffBar")
  bar:SetSize(220, 16)
  bar:SetPoint("TOP", st.cdm[1], "BOTTOMLEFT", 110, -14)
  bar.fill = rawget(bar, "fill") or bar:CreateTexture(nil, "ARTWORK")
  bar.fill:ClearAllPoints()
  bar.fill:SetPoint("TOPLEFT"); bar.fill:SetPoint("BOTTOMLEFT"); bar.fill:SetWidth(220 * 0.62)
  local c = E.barColor
  if c then bar.fill:SetColorTexture(c.r, c.g, c.b, 1) else bar.fill:SetColorTexture(0.9, 0.7, 0.2, 1) end
  bar.ticks = rawget(bar, "ticks") or {}
  for i, pct in ipairs(E.barTicks) do
    local t = bar.ticks[i] or bar:CreateTexture(nil, "OVERLAY")
    bar.ticks[i] = t
    t:ClearAllPoints(); t:SetSize(1, 16); t:SetPoint("LEFT", bar, "LEFT", 220 * pct / 100, 0)
    t:SetColorTexture(1, 1, 1, 0.9); t:Show()
  end
  for i = #E.barTicks + 1, #bar.ticks do bar.ticks[i]:Hide() end
  local kick = frame(card, "cdmKick")
  kick:SetSize(220, 14)
  kick:SetPoint("TOP", bar, "BOTTOM", 0, -6)
  kick.fill = rawget(kick, "fill") or kick:CreateTexture(nil, "ARTWORK")
  kick.fill:SetAllPoints(); kick.fill:SetColorTexture(1, 0.62, 0.18, 0.9)
  kick:SetShown(E.focusKick)
  local parts = {}
  if E.glowMode ~= "off" then parts[#parts + 1] = "3rd icon: glow" end
  if next(E.hide) then parts[#parts + 1] = "6th icon: a hidden spell (dimmed here, gone in game)" end
  if E.focusKick then parts[#parts + 1] = "orange bar: focus kick" end
  if next(E.sounds) then parts[#parts + 1] = "ready sounds on" end
  note(card, "cdmNote", E.focusKick and kick or bar, #parts > 0 and table.concat(parts, "; ") or "No glow, sounds or hidden spells.")
end)

-- Resource bars: threshold colour, latency zone and empower or channel marks
-- on the sample cast, and the aura stack bar.
PX.extend("ResourceBars", function(card)
  local RB = PUI.ResourceBars
  local X = RB and RB.Extras
  local st = Previews.State(card)
  if not (X and st.rb and st.rb[3]) then return end
  local E = X.settings
  local power, cast = st.rb[2], st.rb[3]
  if E.thresholds then
    local c = 64 < E.lowPct and E.lowColor or 64 >= E.highPct and E.highColor or E.midColor
    power:SetStatusBarColor(c.r, c.g, c.b, 1)
  end
  local w, h = cast:GetWidth(), cast:GetHeight()
  local lat = tex(card, "rbLatency")
  lat:SetSize(math.max(1, w * 0.06), h)
  lat:SetPoint("RIGHT", cast, "RIGHT", 0, 0)
  local lc = E.latencyColor
  lat:SetColorTexture(lc.r, lc.g, lc.b, lc.a or 0.45)
  lat:SetShown(E.latency and cast:IsShown())
  for i = 1, 3 do
    local m = tex(card, "rbStage" .. i)
    m:SetSize(1, h)
    m:SetPoint("LEFT", cast, "LEFT", w * i / 4, 0)
    m:SetColorTexture(1, 1, 1, 0.85)
    m:SetShown(E.stages and cast:IsShown())
  end
  local aura = frame(card, "rbAura")
  aura:SetSize(w, 6)
  aura:SetPoint("TOP", cast, "BOTTOM", 0, -4)
  aura.fill = rawget(aura, "fill") or aura:CreateTexture(nil, "ARTWORK")
  aura.fill:ClearAllPoints(); aura.fill:SetPoint("TOPLEFT"); aura.fill:SetPoint("BOTTOMLEFT")
  aura.fill:SetWidth(w * math.min(1, 3 / math.max(1, E.auraMax)))
  local ar, ag, ab = Theme:Color("accent")
  aura.fill:SetColorTexture(ar, ag, ab, 1)
  aura:SetShown(RB.cfg.aura.on)
  local parts = {}
  if E.latency then parts[#parts + 1] = "red end of the cast: latency" end
  if E.stages then parts[#parts + 1] = "lines: empower stages" end
  if RB.cfg.aura.on then parts[#parts + 1] = "thin bar: aura stacks (3 of " .. E.auraMax .. ")" end
  parts[#parts + 1] = "global cooldown bar: " .. (E.gcdMode == "always" and "always" or E.gcdMode == "instance" and "in instances" or "instants only")
  note(card, "rbNote", RB.cfg.aura.on and aura or cast, table.concat(parts, "; "))
end)
