local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Shared services (plan 1.29, one owner each per 1.O):
--   PUI.Format  numbers and times for every module (meters, data bars, tags, Spark)
--   PUI.Range   refcounted unit range polling (raid fade, plates, arena)
--   PUI.Mouse   one cursor poll for every cursor follower
--   PUI.Glow    C-side AnimationGroup glows (no per-frame Lua)
-- Secret values are passed to the engine (C formatters, SetAlphaFromBoolean)
-- and never compared (G1).
local Secret, Ticker, Schema = PUI.Secret, PUI.Ticker, PUI.Schema

------------------------------------------------------------------------------
-- Format
local Format = { style = "short", decimals = 1 }
PUI.Format = Format
Format.STYLES = { "short", "full", "exact" }
Format.STYLE_LABELS = { short = "Short (12.3K)", full = "Grouped (12,345)", exact = "Plain (12345)" }

local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- Number(v[, style[, decimals]]): text for a number. A secret goes through the
-- engine's own formatter and comes back as a (secret) string for a widget.
function Format.Number(v, style, decimals)
  if Secret.IsSecret(v) then return AbbreviateNumbers(v) end
  if type(v) ~= "number" then return "" end
  style = style or Format.style
  decimals = decimals or Format.decimals
  if style == "exact" then return string.format("%d", math.floor(v + 0.5)) end
  if style == "full" then return BreakUpLargeNumbers(math.floor(v + 0.5)) end
  local a = math.abs(v)
  for i = 1, #UNITS do
    local u = UNITS[i]
    if a >= u[1] then
      local s = string.format("%." .. decimals .. "f", v / u[1])
      if decimals > 0 then s = s:gsub("%.?0+$", "") end
      return s .. u[2]
    end
  end
  return string.format("%d", math.floor(v + 0.5))
end

-- Duration(seconds): "1:05:09", "4:07", "9.5" (below `tenthsBelow`), "45".
function Format.Duration(sec, tenthsBelow)
  if Secret.IsSecret(sec) or type(sec) ~= "number" then return "" end
  if sec < 0 then sec = 0 end
  tenthsBelow = tenthsBelow or 0
  if sec < tenthsBelow then return string.format("%.1f", sec) end
  sec = math.floor(sec + 0.5)
  local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  if m > 0 then return string.format("%d:%02d", m, s) end
  return tostring(s)
end

function Format.Percent(v, decimals)
  if Secret.IsSecret(v) or type(v) ~= "number" then return "" end
  return string.format("%." .. (decimals or 0) .. "f%%", v)
end

Schema:Register("format.numberStyle", {
  type = "select", default = "short", choices = Format.STYLES, labels = Format.STYLE_LABELS,
  label = "Number style", tooltip = "How large numbers look everywhere in Phoenix (meters, data bars, unit text, combat text).",
  mode = "simple", owner = "Core", searchTags = { "numbers", "format", "abbreviate", "thousands" },
  apply = function(v) Format.style = v; PUI.Kernel:Fire("FORMAT_CHANGED") end,
})
Schema:Register("format.decimals", {
  type = "range", default = 1, min = 0, max = 2, step = 1,
  label = "Decimals on short numbers", tooltip = "Decimal places for short numbers, e.g. 12K, 12.3K or 12.34K.",
  mode = "advanced", owner = "Core", searchTags = { "numbers", "decimals" },
  apply = function(v) Format.decimals = v; PUI.Kernel:Fire("FORMAT_CHANGED") end,
})

------------------------------------------------------------------------------
-- Range: Acquire(owner, unit, fn) -> handle. One poll for all units while any
-- handle exists; fn(inRange) receives the engine value (may be secret: pass it
-- to SetAlphaFromBoolean, never compare it).
local Range = { handles = {}, count = 0, interval = 0.2 }
PUI.Range = Range

local function rangeTick()
  for h in pairs(Range.handles) do
    local inRange, checked = UnitInRange(h.unit)
    securecallfunction(h.fn, inRange, checked)
  end
end

function Range:Acquire(owner, unit, fn)
  assert(type(owner) == "string" and type(unit) == "string" and type(fn) == "function", "Range:Acquire(owner, unit, fn)")
  local h = { owner = owner, unit = unit, fn = fn }
  self.handles[h] = true
  self.count = self.count + 1
  if self.count == 1 then Ticker:Register("range.poll", self.interval, rangeTick, "Core") end
  return h
end

function Range:Release(h)
  if not (h and self.handles[h]) then return end
  self.handles[h] = nil
  self.count = self.count - 1
  if self.count == 0 then Ticker:Unregister("range.poll") end
end

function Range:ReleaseOwner(owner)
  for h in pairs(self.handles) do if h.owner == owner then self:Release(h) end end
end

function Range:SetInterval(sec)
  self.interval = sec
  if self.count > 0 then Ticker:Register("range.poll", sec, rangeTick, "Core") end
end

Schema:Register("range.interval", {
  type = "range", default = 0.2, min = 0.1, max = 1, step = 0.05,
  label = "Range check speed", tooltip = "How often out-of-range units are re-checked (seconds). Lower reacts faster and costs a little more.",
  mode = "advanced", owner = "Core", searchTags = { "range", "fade", "distance" },
  apply = function(v) Range:SetInterval(v) end,
})

------------------------------------------------------------------------------
-- Mouse: one cursor poll (every frame) only while someone follows the cursor.
local Mouse = { subs = {}, count = 0, x = 0, y = 0 }
PUI.Mouse = Mouse

local function mouseTick()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  if scale and scale > 0 then x, y = x / scale, y / scale end
  Mouse.x, Mouse.y = x, y
  for id, fn in pairs(Mouse.subs) do securecallfunction(fn, x, y, id) end
end

function Mouse:Subscribe(id, fn)
  assert(type(id) == "string" and type(fn) == "function", "Mouse:Subscribe(id, fn)")
  if not self.subs[id] then self.count = self.count + 1 end
  self.subs[id] = fn
  if self.count == 1 then Ticker:Register("mouse.poll", 0, mouseTick, "Core") end
end

function Mouse:Unsubscribe(id)
  if not self.subs[id] then return end
  self.subs[id] = nil
  self.count = self.count - 1
  if self.count == 0 then Ticker:Unregister("mouse.poll") end
end

------------------------------------------------------------------------------
-- Glow: styles share one schema prefix (<prefix>.style/.color/.speed) and are
-- drawn with C-side AnimationGroups, so a glowing button costs no Lua per frame.
local Glow = { active = setmetatable({}, { __mode = "k" }) }
PUI.Glow = Glow
Glow.STYLES = { "pulse", "solid", "flash", "none" }
Glow.STYLE_LABELS = { pulse = "Soft pulse", solid = "Solid border", flash = "Quick flash", none = "No glow" }
local SPEED = { pulse = 0.8, flash = 0.25 }

local function build(target)
  local g = PUI:CreateFrame("Frame", nil, target, nil, "Core")
  g:SetPoint("TOPLEFT", -3, 3)
  g:SetPoint("BOTTOMRIGHT", 3, -3)
  g:SetFrameLevel((target:GetFrameLevel() or 1) + 5)
  local edges = {}
  local function edge(p1, p2, w, h)
    local t = g:CreateTexture(nil, "OVERLAY")
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    edges[#edges + 1] = t
  end
  edge("TOPLEFT", "TOPRIGHT", nil, 2); edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
  edge("TOPLEFT", "BOTTOMLEFT", 2, nil); edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
  local ag = g:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.25)
  return { frame = g, edges = edges, group = ag, anim = a }
end

-- Start(target, style, color{r,g,b,a}, speedScale): idempotent restyle.
function Glow:Start(target, style, color, speedScale)
  style = style or "pulse"
  if style == "none" then return self:Stop(target) end
  local g = self.active[target]
  if not g then g = build(target); self.active[target] = g end
  local c = color or { r = 1, g = 0.48, b = 0.1, a = 1 }
  for i = 1, #g.edges do g.edges[i]:SetColorTexture(c.r, c.g, c.b, c.a or 1) end
  g.style = style
  g.group:Stop()
  if SPEED[style] then
    g.anim:SetDuration(SPEED[style] / (speedScale or 1))
    g.group:Play()
  end
  g.frame:SetAlpha(1)
  g.frame:Show()
  return g
end

function Glow:Stop(target)
  local g = self.active[target]
  if not g then return end
  g.group:Stop()
  g.frame:Hide()
  g.style = nil
end

function Glow:IsGlowing(target) local g = self.active[target]; return g ~= nil and g.style ~= nil end

-- Registers <prefix>.style and <prefix>.color for a surface (e.g. "actionbars.procGlow").
function Glow:RegisterSettings(prefix, owner, defaults, onChange)
  defaults = defaults or {}
  Schema:Register(prefix .. ".style", {
    type = "select", default = defaults.style or "pulse", choices = Glow.STYLES, labels = Glow.STYLE_LABELS,
    label = "Glow style", tooltip = "How this glow looks.", mode = "simple", owner = owner,
    searchTags = { "glow", "highlight", "proc" }, apply = function() if onChange then onChange() end end,
  })
  Schema:Register(prefix .. ".color", {
    type = "color", default = defaults.color or { r = 1, g = 0.48, b = 0.1, a = 1 },
    label = "Glow colour", tooltip = "Colour of this glow.", mode = "advanced", owner = owner,
    searchTags = { "glow", "colour", "color" }, apply = function() if onChange then onChange() end end,
  })
end
