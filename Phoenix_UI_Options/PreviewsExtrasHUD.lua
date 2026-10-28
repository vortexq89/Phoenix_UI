local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for the deferred batch B HUD items: Phoenix minimap buttons,
-- the extra tooltip lines, data bar extras and the queue pop-up timer on the
-- Group Finder page. Sample values only, drawn with the modules' own helpers.
local Options = PUI.Options
local Previews, PX = Options.Previews, Options.PreviewsExtras
local Theme = PUI.Theme
local tex, frame = PX.Tex, PX.Frame

-- Minimap: the Phoenix button row at its corner, size and growth.
PX.extend("Minimap", function(card)
  local MM = PUI.Minimap
  local B = MM and MM.Buttons
  local hud = Previews.State(card).hud
  local map = hud and hud.mm and rawget(hud.mm, "map")
  if not (B and map) then return end
  local S = B.s
  local k = math.min(220, MM.settings.size) / MM.settings.size
  local size = S.size * k
  local ar, ag, ab = Theme:Color("accent")
  for i, name in ipairs(B.ORDER) do
    local t = tex(card, "mmBtn" .. i)
    local x, y = B.Offset(i, size, S.spacing * k, S.corner, S.grow)
    t:SetSize(size, size)
    t:SetPoint(S.corner, map, S.corner, x, y)
    t:SetTexture(B.ICONS[name])
    t:SetShown(S.style == "phoenix")
  end
  local badge = PX.Line(card, "mmBtnBadge")
  badge:ClearAllPoints()
  local cal = PX.Bag(card).mmBtn2
  badge:SetPoint("TOPRIGHT", cal, "TOPRIGHT", 3, 3)
  badge:SetText("2")
  badge:SetTextColor(ar, ag, ab)
  badge:SetShown(S.style == "phoenix")
end)

-- Tooltip: the extra item and player lines under the sample tooltip.
PX.extend("Tooltip", function(card)
  local TT = PUI.Tooltip
  local X = TT and TT.Extras
  local hud = Previews.State(card).hud
  local tip = hud and hud.tt and rawget(hud.tt, "tip")
  if not (X and tip) then return end
  local s = TT.settings
  local rows = {}
  if s.inspect then rows[#rows + 1] = { X.InspectLine({ ilvl = 678.4, spec = "Arms" }), 0.85, 0.85, 0.85 } end
  if s.transmog then rows[#rows + 1] = { "Appearance not collected", 1, 0.5, 0.4 } end
  if s.upgrade then rows[#rows + 1] = { "Track: Hero 3/6  (up to 684)", 0.95, 0.75, 0.3 } end
  if s.setPieces then rows[#rows + 1] = { "Set pieces equipped: 2", 0.6, 0.8, 1 } end
  local anchor = tip
  for i = 1, 4 do
    local fs = PX.Line(card, "ttExtra" .. i)
    local r = rows[i]
    fs:ClearAllPoints()
    if r then
      fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", i == 1 and 10 or 0, i == 1 and -6 or -2)
      fs:SetText(r[1])
      fs:SetTextColor(r[2], r[3], r[4])
      fs:Show()
      anchor = fs
    else
      fs:Hide()
    end
  end
end)

-- Data bars: what the per-spec sets and broker feeds are doing.
PX.extend("DataBars", function(card)
  local DB = PUI.DataBars
  local X = DB and DB.Extras
  local hud = Previews.State(card).hud
  local h = hud and hud.db
  if not (X and h) then return end
  local n = 0
  for _ in pairs(X.spec.sets) do n = n + 1 end
  local feeds = X.FeedNames()
  local parts = {}
  parts[#parts + 1] = X.spec.on and string.format("Per-spec blocks on (%d spec%s saved)", n, n == 1 and "" or "s") or "Per-spec blocks off"
  parts[#parts + 1] = #feeds > 0 and ("Broker feeds: " .. table.concat(feeds, ", ", 1, math.min(4, #feeds))) or "No broker feeds loaded"
  parts[#parts + 1] = "hearth, prof1 and prof2 cells are clickable"
  local fs = PX.Line(card, "dbExtrasNote")
  fs:ClearAllPoints()
  fs:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 8, 8)
  fs:SetWidth(368)
  fs:SetText(table.concat(parts, "; "))
end)

-- Group Finder: the queue pop countdown bar (queue.lfgSeconds lives here).
PX.extend("GroupFinder", function(card)
  local SK = PUI.Skins
  local Q = SK and SK.QueueTimer
  if not Q then return end
  local total = PUI.Queue.lfgSeconds
  local left = math.floor(total * 0.6)
  local frac, text, r, g, b = Q.State(left, total, Q.s.warn)
  local bar = frame(card, "gfQueue")
  bar:SetSize(240, Q.s.height)
  bar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 18)
  bar.bg = rawget(bar, "bg") or bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  local sr, sg, sb = Theme:Color("surface.1")
  bar.bg:SetColorTexture(sr, sg, sb, 0.9)
  bar.fill = rawget(bar, "fill") or bar:CreateTexture(nil, "ARTWORK")
  bar.fill:ClearAllPoints()
  bar.fill:SetPoint("TOPLEFT"); bar.fill:SetPoint("BOTTOMLEFT")
  bar.fill:SetWidth(240 * frac)
  bar.fill:SetColorTexture(r, g, b, 1)
  bar:SetShown(Q.s.on)
  local fs = PX.Line(card, "gfQueueText")
  fs:ClearAllPoints()
  fs:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
  fs:SetText(string.format("Queue pop-up: %s of %d s left%s", text, total, Q.s.on and "" or " (timer off)"))
end)
