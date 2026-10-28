local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Spark engine (mockup 09): four scroll areas, pooled text lines, merging and
-- the density cap for big pulls.
--  * Lines are pooled frames animated by C-side AnimationGroups (translation
--    + fade), so a moving line runs no Lua per frame (G2).
--  * Amounts the game hides (secret) are never added, compared or put into a
--    Lua string: a message is a format string plus arguments and goes to
--    SetFormattedText, so the engine writes the number (mockup note 2).
--  * Merge: lines with the same merge key inside the merge window become one
--    line ("Rend x5"); plain amounts are summed, hidden ones show the latest.
--  * Density cap: past the per-area lines-per-second cap, extra lines are
--    counted and shown once as "+N more" (upgrade over MSBT).
-- The flush runs on one Ticker entry that exists only while lines wait.
local _, ns = ...
local Secret, Ticker = PUI.Secret, PUI.Ticker
local E = { areas = {}, pending = {}, active = {}, pool = {}, stats = { shown = 0, merged = 0, capped = 0 } }
ns.Engine = E
local OWNER = "Spark"

E.AREAS = { "incoming", "outgoing", "notification", "static" }
E.AREA_LABELS = { incoming = "Incoming", outgoing = "Outgoing", notification = "Notifications", static = "Static (sticky)" }
E.AREA_DEFAULTS = {
  incoming = { x = -240, y = 40, behaviour = "scroll", direction = "down", align = "RIGHT", size = 20 },
  outgoing = { x = 240, y = 40, behaviour = "parabola", direction = "up", align = "LEFT", size = 22 },
  notification = { x = 0, y = 220, behaviour = "scroll", direction = "up", align = "CENTER", size = 18 },
  static = { x = 0, y = 120, behaviour = "static", direction = "up", align = "CENTER", size = 24 },
}

-- Escape a plain piece of text for a format string.
function E.Escape(text) return (tostring(text or ""):gsub("%%", "%%%%")) end

-- Compose(template, tokens) -> fmt, args: tokens %a (amount, may be secret),
-- %s (spell), %n (name), %c (count), %e (event word), %t (trailer). Only %a
-- becomes a %s slot; everything else is plain and escaped.
function E.Compose(template, tok)
  local args = {}
  local fmt = template:gsub("%%(%a)", function(c)
    if c == "a" then
      if tok.amount == nil then return "" end
      args[#args + 1] = tok.amount
      return "%s"
    end
    local v = (c == "s" and tok.spell) or (c == "n" and tok.name) or (c == "c" and tok.count and tok.count > 1 and ("x" .. tok.count))
      or (c == "e" and tok.event) or (c == "t" and tok.trailer) or nil
    if v == nil or Secret.IsSecret(v) then return "" end
    return E.Escape(v)
  end)
  fmt = fmt:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")
  return fmt, args
end

-- Amount text: PUI.Format (secrets go through the engine's abbreviator).
function E.AmountText(v, short)
  if v == nil then return nil end
  if short then return PUI.Format.Number(v, "short") end
  return PUI.Format.Number(v, "full")
end

-- Area frames ------------------------------------------------------------------
function E.Area(id)
  local a = E.areas[id]
  if a then return a end
  a = { id = id, frame = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER), window = {}, overflow = 0 }
  a.frame:SetSize(260, 200)
  PUI.Layout:Place(a.frame, "spark." .. id)
  E.areas[id] = a
  return a
end

local function newLine()
  local l = CreateFrame("Frame", nil, UIParent)
  l:SetSize(300, 28)
  l.text = l:CreateFontString(nil, "OVERLAY")
  l.icon = l:CreateTexture(nil, "ARTWORK"); l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  l.anim = l:CreateAnimationGroup()
  l.move = l.anim:CreateAnimation("Translation")
  l.drift = l.anim:CreateAnimation("Translation")
  l.fade = l.anim:CreateAnimation("Alpha")
  l.fade:SetFromAlpha(1); l.fade:SetToAlpha(0)
  l.anim:SetScript("OnFinished", function() E.Release(l) end)
  return l
end

function E.Release(l)
  if not E.active[l] then return end
  E.active[l] = nil
  l.anim:Stop()
  l:Hide()
  l.text:SetText("")
  E.pool[#E.pool + 1] = l
end
function E.ActiveCount() local n = 0; for _ in pairs(E.active) do n = n + 1 end; return n end

-- Show(areaId, msg, st): msg = { fmt, args, color, crit, icon }; st = area settings.
function E.Show(areaId, msg, st, master)
  local a = E.Area(areaId)
  local l = table.remove(E.pool) or newLine()
  E.active[l] = true
  E.stats.shown = E.stats.shown + 1
  l:SetParent(a.frame)
  l:ClearAllPoints()
  l:SetPoint(st.align == "LEFT" and "LEFT" or (st.align == "RIGHT" and "RIGHT" or "CENTER"), a.frame, st.align == "LEFT" and "LEFT" or (st.align == "RIGHT" and "RIGHT" or "CENTER"), 0, 0)
  local size = st.size * ((msg.crit and master.critScale) or 1)
  local path = PUI.Media:FontObject("normal"):GetFont()
  l.text:SetFont(path, math.floor(size + 0.5), master.outline ~= "NONE" and master.outline or "")
  l.text:SetJustifyH(st.align)
  l.text:ClearAllPoints()
  l.text:SetPoint(st.align == "RIGHT" and "RIGHT" or (st.align == "LEFT" and "LEFT" or "CENTER"), l, st.align == "RIGHT" and "RIGHT" or (st.align == "LEFT" and "LEFT" or "CENTER"), 0, 0)
  if #msg.args > 0 then l.text:SetFormattedText(msg.fmt, unpack(msg.args)) else l.text:SetText((msg.fmt:gsub("%%%%", "%%"))) end
  local c = msg.color or { r = 1, g = 1, b = 1 }
  l.text:SetTextColor(c.r, c.g, c.b, 1)
  local showIcon = master.icons and msg.icon ~= nil
  l.icon:SetShown(showIcon)
  if showIcon then
    l.icon:SetTexture(msg.icon); l.icon:SetSize(size, size); l.icon:ClearAllPoints()
    l.icon:SetPoint(st.align == "RIGHT" and "LEFT" or "RIGHT", l.text, st.align == "RIGHT" and "RIGHT" or "LEFT", st.align == "RIGHT" and 4 or -4, 0)
  end
  l:SetAlpha(st.alpha)
  -- animation (C side)
  local dist = st.distance * (st.direction == "down" and -1 or 1)
  local dur = st.duration / math.max(0.25, master.speed)
  if st.behaviour == "static" then dist = 0 end
  l.move:SetOffset(0, dist); l.move:SetDuration(dur)
  local bend = st.behaviour == "parabola" and (st.align == "RIGHT" and -40 or 40) or 0
  l.drift:SetOffset(bend, 0); l.drift:SetDuration(dur); l.drift:SetSmoothing(st.behaviour == "parabola" and "IN" or "NONE")
  l.fade:SetStartDelay(dur * 0.7); l.fade:SetDuration(dur * 0.3)
  l.anim:SetDuration(dur)
  l:Show()
  l.anim:Play()
  l.area, l.msg = areaId, msg
  return l
end

-- Queue(areaId, msg, st, master): merge + cap, flushed on the Ticker.
-- msg.mergeKey (plain string) and msg.plainAmount (number when readable).
function E.Queue(areaId, msg, st, master)
  if not st.enabled then return nil end
  if master.merge and msg.mergeKey then
    for _, p in ipairs(E.pending) do
      if p.area == areaId and p.msg.mergeKey == msg.mergeKey then
        p.count = p.count + 1
        E.stats.merged = E.stats.merged + 1
        if p.sum and msg.plainAmount then p.sum = p.sum + msg.plainAmount else p.sum = nil end
        p.msg.latest = msg
        return p
      end
    end
  end
  local p = { area = areaId, msg = msg, count = 1, sum = msg.plainAmount, at = GetTime(), st = st, master = master }
  E.pending[#E.pending + 1] = p
  if not Ticker:IsRegistered("spark.flush") then Ticker:Register("spark.flush", 0.05, E.Flush, OWNER) end
  return p
end

-- Rebuild a merged message: count token, summed or latest amount.
local function finalize(p)
  local m = p.msg
  if p.count > 1 and m.build then
    local amount = p.sum and E.AmountText(p.sum, m.short) or (m.latest and m.latest.amountText) or m.amountText
    local fmt, args = m.build(amount, p.count)
    m.fmt, m.args = fmt, args
  end
  return m
end

function E.Flush(force)
  local now = GetTime()
  local keep = {}
  for _, p in ipairs(E.pending) do
    if force == true or now - p.at >= p.master.mergeWindow then
      local a = E.Area(p.area)
      -- density cap: lines shown in the last second
      local w = a.window
      while #w > 0 and now - w[1] > 1 do table.remove(w, 1) end
      if #w >= p.st.cap and p.master.capOn then
        a.overflow = a.overflow + 1
        E.stats.capped = E.stats.capped + 1
      else
        w[#w + 1] = now
        a.lastSt = p.st
        E.Show(p.area, finalize(p), p.st, p.master)
      end
    else
      keep[#keep + 1] = p
    end
  end
  E.pending = keep
  for id, a in pairs(E.areas) do
    if a.overflow > 0 and (#a.window == 0 or now - a.window[#a.window] > 0.25 or force == true) then
      local st = a.lastSt or (E.settingsFor and E.settingsFor(id))
      if st then
        E.Show(id, { fmt = string.format("+%d more", a.overflow), args = {}, color = { r = 0.75, g = 0.75, b = 0.8 } }, st, E.master)
        a.window[#a.window + 1] = now
      end
      a.overflow = 0
    end
  end
  local waiting = #E.pending > 0
  for _, a in pairs(E.areas) do if a.overflow > 0 then waiting = true end end
  if not waiting then Ticker:Unregister("spark.flush") end
end

function E.Clear()
  for l in pairs(E.active) do E.Release(l) end
  wipe(E.pending)
  for _, a in pairs(E.areas) do a.overflow = 0; wipe(a.window) end
  Ticker:Unregister("spark.flush")
end
