local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Pulse timer bars: one pooled bar group drawn in Phoenix's own art. A bar's
-- fill is engine-driven (StatusBar:SetTimerDuration with a duration object),
-- so no bar runs Lua per frame (G2). The only Lua that runs is one text pass
-- on a Ticker entry, registered only while at least one bar is shown.
-- Names, icons and remaining times that the game may hide (secret) go straight
-- to widgets (SetText / SetTexture / SetFormattedText); nothing compares them.
--   g = Bars.NewGroup(owner, id, style)   style = live table (width, height, ...)
--   bar = g:Acquire(key)                  bar:Fill{ name, icon, duration|start+length, remaining = fn, color, emphasis }
--   g:Release(key)  g:ReleaseAll()  g:Count()  g:Layout()
local _, ns = ...
local Ticker = PUI.Ticker
local Bars = { groups = {} }
ns.Bars = Bars

Bars.DEFAULT = { width = 240, height = 20, gap = 3, grow = "down", icon = true, iconSide = "LEFT", font = "small",
  timeFormat = "auto", alpha = 1, background = 0.55, spark = true, max = 8 }

-- TimeText(sec, fmt): "12", "4.2" (under 10 s with auto/tenths), "1:05".
function Bars.TimeText(sec, fmt)
  sec = math.max(0, sec or 0)
  if sec >= 60 then return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec) % 60) end
  if fmt == "tenths" or (fmt ~= "seconds" and sec < 10) then return string.format("%.1f", sec) end
  return string.format("%d", math.ceil(sec))
end

local Group = {}
Group.__index = Group

local function build(g)
  local f = CreateFrame("Frame", nil, g.anchor)
  f.status = CreateFrame("StatusBar", nil, f)
  f.status:SetMinMaxValues(0, 1)
  f.bg = f.status:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints()
  f.edge = f:CreateTexture(nil, "BORDER")
  f.edge:SetPoint("TOPLEFT", -1, 1); f.edge:SetPoint("BOTTOMRIGHT", 1, -1); f.edge:SetColorTexture(0, 0, 0, 0.9)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.name = f.status:CreateFontString(nil, "OVERLAY")
  f.time = f.status:CreateFontString(nil, "OVERLAY")
  f.name:SetPoint("LEFT", f.status, "LEFT", 6, 0)
  f.time:SetPoint("RIGHT", f.status, "RIGHT", -6, 0)
  f.spark = f.status:CreateTexture(nil, "OVERLAY")
  f.spark:SetSize(8, 1); f.spark:SetBlendMode("ADD"); f.spark:SetColorTexture(1, 0.95, 0.8, 0.85)
  return f
end

-- Paint(bar): size, texture, fonts and colour from the live style.
local function paint(g, f)
  local s = g.style
  local h, w = s.height, s.width
  f:SetSize(w, h)
  f:SetAlpha(s.alpha)
  local tex = PUI.Bars and PUI.Bars:TexturePath() or "Interface\\Buttons\\WHITE8X8"
  f.status:SetStatusBarTexture(tex)
  f.bg:SetTexture(tex)
  local c = f.data and f.data.color or { r = 0.91, g = 0.64, b = 0.24 }
  f.status:SetStatusBarColor(c.r, c.g, c.b, 1)
  f.bg:SetVertexColor(c.r * 0.2, c.g * 0.2, c.b * 0.2, s.background)
  f.status:ClearAllPoints()
  f.icon:SetShown(s.icon)
  f.icon:SetSize(h, h)
  f.icon:ClearAllPoints()
  if s.icon and s.iconSide == "RIGHT" then
    f.icon:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.status:SetPoint("TOPLEFT"); f.status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -h - 1, 0)
  elseif s.icon then
    f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.status:SetPoint("TOPLEFT", f, "TOPLEFT", h + 1, 0); f.status:SetPoint("BOTTOMRIGHT")
  else
    f.status:SetAllPoints()
  end
  local font = PUI.Media:FontObject(s.font)
  f.name:SetFontObject(font); f.time:SetFontObject(font)
  f.spark:SetShown(s.spark)
  f.spark:SetHeight(h)
  f.spark:ClearAllPoints()
  f.spark:SetPoint("CENTER", f.status:GetStatusBarTexture(), "RIGHT", 0, 0)
end

function Bars.NewGroup(owner, id, style, parent)
  local g = setmetatable({ owner = owner, id = id, style = style, live = {}, order = {}, pool = {} }, Group)
  g.anchor = PUI:CreateFrame("Frame", nil, parent or UIParent, nil, owner)
  g.anchor:SetSize(style.width, style.height)
  Bars.groups[id] = g
  return g
end

function Group:Count() return #self.order end

function Group:Acquire(key)
  local f = self.live[key]
  if f then return f end
  f = table.remove(self.pool) or build(self)
  f.key, f.group = key, self
  f.Fill = Group.Fill
  self.live[key] = f
  self.order[#self.order + 1] = key
  f:Show()
  self:Arm()
  return f
end

-- Fill(data): { name, icon, color, duration (engine object) | start + length (plain),
--   remaining = fn() -> seconds (may be secret), sortKey (plain, optional), emphasis }
function Group.Fill(f, data)
  f.data = data
  local g = f.group
  f.name:SetText(data.name or "")
  f.icon:SetTexture(data.icon)
  local d = data.duration
  if not d and data.start and data.length and C_DurationUtil then
    d = C_DurationUtil.CreateDuration()
    d:SetTimeFromStart(data.start, data.length)
  end
  if d then f.status:SetTimerDuration(d, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime) end
  paint(g, f)
  if data.emphasis then PUI.Glow:Start(f, "pulse", g.style.emphasisColor) else PUI.Glow:Stop(f) end
  g:Layout()
  g:Text()
  return f
end

function Group:Release(key)
  local f = self.live[key]
  if not f then return end
  self.live[key] = nil
  for i = #self.order, 1, -1 do if self.order[i] == key then table.remove(self.order, i) end end
  PUI.Glow:Stop(f)
  f:Hide()
  f.data = nil
  self.pool[#self.pool + 1] = f
  self:Layout()
  if #self.order == 0 then self:Arm() end
end

function Group:ReleaseAll()
  for i = #self.order, 1, -1 do self:Release(self.order[i]) end
end

-- Bars with a plain sortKey sort soonest first; the rest keep arrival order
-- (timeline events already come sorted by the game).
function Group:Layout()
  local s = self.style
  local keyed = {}
  for i, key in ipairs(self.order) do
    local f = self.live[key]
    keyed[i] = { key = key, sort = f.data and f.data.sortKey, i = i }
  end
  table.sort(keyed, function(a, b)
    if a.sort and b.sort and a.sort ~= b.sort then return a.sort < b.sort end
    if a.sort and not b.sort then return true end
    if b.sort and not a.sort then return false end
    return a.i < b.i
  end)
  local step = (s.height + s.gap) * (s.grow == "up" and 1 or -1)
  for i, k in ipairs(keyed) do
    local f = self.live[k.key]
    f:ClearAllPoints()
    f:SetPoint(s.grow == "up" and "BOTTOMLEFT" or "TOPLEFT", self.anchor, s.grow == "up" and "BOTTOMLEFT" or "TOPLEFT", 0, (i - 1) * step)
    f:SetShown(i <= s.max)
  end
  self.anchor:SetSize(s.width, math.max(s.height, math.min(#keyed, s.max) * (s.height + s.gap)))
end

function Group:Restyle()
  for _, key in ipairs(self.order) do paint(self, self.live[key]) end
  self:Layout()
end

-- Text pass: one Ticker entry per group, only while bars are shown.
function Group:Text()
  local fmt = self.style.timeFormat
  for _, key in ipairs(self.order) do
    local f = self.live[key]
    local d = f.data
    if d then
      if d.remaining then
        local left = d.remaining()
        if PUI.Secret.IsSecret(left) then f.time:SetFormattedText("%.1f", left)
        elseif type(left) == "number" then
          f.time:SetText(Bars.TimeText(left, fmt))
          if left <= 0 and d.autoRelease then self:Release(key) end
        else f.time:SetText("") end
      elseif d.start and d.length then
        local left = d.start + d.length - GetTime()
        f.time:SetText(Bars.TimeText(left, fmt))
        if left <= 0 and d.autoRelease ~= false then self:Release(key) end
      end
    end
  end
end

function Group:Arm()
  local key = "pulse.text." .. self.id
  if #self.order > 0 then
    if not Ticker:IsRegistered(key) then Ticker:Register(key, 0.1, function() self:Text() end, self.owner) end
  else
    Ticker:Unregister(key)
  end
end
