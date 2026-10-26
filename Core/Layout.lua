local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Layout v2: where and how every movable Phoenix element sits (plan 4, mockup 12).
-- Elements register an id, a label and a default anchor. Studio saves one
-- record per moved element in the hidden schema key layout.positions:
--   { point, x, y }                   anchor relative to UIParent (required)
--   scale, w, h                       size (w/h only for spec.resizable)
--   strata, level                     frame layer (BACKGROUND..DIALOG, 0..100)
--   alpha, hide, clickThrough         look
--   attach = { to, side, gap, align, matchW, matchH }   edge-to-edge attach
--   fade = { combat, ooc, mounted, resting, skyriding, vehicle, petBattle, hover }
-- layout.positions is overridable, so per-spec and per-content layouts come
-- from the Overrides layer (condition > spec > profile). Protected frames are
-- placed after combat through the CombatQueue. Anchor cycles are refused at
-- edit time and reported (never hidden) if a stored layout contains one.
local Layout = { elements = {}, order = {}, frames = setmetatable({}, { __mode = "v" }), cycles = {} }
PUI.Layout = Layout
local CQ = PUI.CombatQueue

Layout.STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
Layout.SIDES = { "LEFT", "RIGHT", "TOP", "BOTTOM" }
Layout.ALIGNS = { "START", "CENTER", "END" }
-- Alpha-by-state priority, first match wins (documented, fixed order).
Layout.FADE_ORDER = { "petBattle", "combat", "vehicle", "skyriding", "mounted", "resting", "ooc" }
Layout.FADE_LABELS = { petBattle = "In a pet battle", combat = "In combat", vehicle = "In a vehicle", skyriding = "Skyriding",
  mounted = "Mounted", resting = "Resting", ooc = "Out of combat" }
local STRATA_OK = {}
for _, s in ipairs(Layout.STRATA) do STRATA_OK[s] = true end
local SIDE_OK = { LEFT = true, RIGHT = true, TOP = true, BOTTOM = true }
local ALIGN_OK = { START = true, CENTER = true, END = true }
local FX = { TOPLEFT = 0, TOP = 0.5, TOPRIGHT = 1, LEFT = 0, CENTER = 0.5, RIGHT = 1, BOTTOMLEFT = 0, BOTTOM = 0.5, BOTTOMRIGHT = 1 }
local FY = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0 }
Layout.FX, Layout.FY = FX, FY

-- spec: label, default {point,x,y}, owner, size {w,h}, resizable, keys (schema
-- key prefix for "explain"), visibility (PUI.Visibility watcher id), kind.
function Layout:RegisterElement(id, spec)
  assert(type(id) == "string" and id ~= "", "Layout:RegisterElement needs an id")
  assert(type(spec.label) == "string", id .. ": label required")
  assert(type(spec.default) == "table" and spec.default.point, id .. ": default anchor required")
  if not self.elements[id] then self.order[#self.order + 1] = id end
  spec.id = id
  spec.owner = spec.owner or "Core"
  self.elements[id] = spec
end

function Layout:Element(id) return self.elements[id] end

local function num(v, lo, hi) return type(v) == "number" and v == v and v >= lo and v <= hi end

-- Shape check for one stored record (import, schema validate).
function Layout.ValidRecord(r)
  if type(r) ~= "table" then return false, "not a table" end
  if not (PUI.Schema.POINTS[r.point] and type(r.x) == "number" and type(r.y) == "number") then return false, "bad anchor" end
  if r.scale ~= nil and not num(r.scale, 0.25, 4) then return false, "scale 0.25..4" end
  if r.w ~= nil and not num(r.w, 4, 4000) then return false, "bad width" end
  if r.h ~= nil and not num(r.h, 4, 4000) then return false, "bad height" end
  if r.strata ~= nil and not STRATA_OK[r.strata] then return false, "bad strata" end
  if r.level ~= nil and not num(r.level, 0, 100) then return false, "level 0..100" end
  if r.alpha ~= nil and not num(r.alpha, 0, 1) then return false, "alpha 0..1" end
  local a = r.attach
  if a ~= nil then
    if type(a) ~= "table" or type(a.to) ~= "string" or not SIDE_OK[a.side] then return false, "bad attach" end
    if a.gap ~= nil and not num(a.gap, -200, 200) then return false, "gap -200..200" end
    if a.align ~= nil and not ALIGN_OK[a.align] then return false, "bad align" end
  end
  if r.fade ~= nil then
    if type(r.fade) ~= "table" then return false, "bad fade" end
    for k, v in pairs(r.fade) do
      if k == "hover" then
        if type(v) ~= "boolean" then return false, "bad fade hover" end
      elseif not (Layout.FADE_LABELS[k] and num(v, 0, 1)) then return false, "bad fade " .. tostring(k) end
    end
  end
  return true
end

function Layout.ValidPositions(t)
  if type(t) ~= "table" then return false, "not a table" end
  for id, r in pairs(t) do
    if type(id) ~= "string" then return false, "bad element id" end
    local ok, why = Layout.ValidRecord(r)
    if not ok then return false, id .. ": " .. why end
  end
  return true
end

-- The effective record of an element: saved, else default.
function Layout:Position(id, positions)
  positions = positions or PUI.Schema:Get("layout.positions")
  local saved = positions[id]
  if saved then return saved end
  local d = self.elements[id] and self.elements[id].default
  return d and { point = d.point, x = d.x or 0, y = d.y or 0 } or nil
end

-- Would attaching id to `to` create a cycle (or self attach)?
function Layout.WouldCycle(positions, id, to)
  local seen, cur = { [id] = true }, to
  while cur do
    if seen[cur] then return true end
    seen[cur] = true
    local r = positions[cur]
    cur = r and r.attach and r.attach.to
  end
  return false
end

-- Base (unscaled) size of an element: record w/h, else frame, else spec.size.
function Layout:BaseSize(id, rec)
  local el, f = self.elements[id], self.frames[id]
  local w = rec and rec.w or (f and f.GetWidth and f:GetWidth()) or 0
  local h = rec and rec.h or (f and f.GetHeight and f:GetHeight()) or 0
  if not w or w <= 0 then w = el and el.size and el.size[1] or 120 end
  if not h or h <= 0 then h = el and el.size and el.size[2] or 40 end
  return w, h
end

-- Pure: the on-screen rect { l, b, w, h } of id in UIParent units, following
-- attach chains. W/H is the parent size. Cycles fall back to the own anchor.
function Layout:Rect(id, positions, W, H, depth)
  positions = positions or PUI.Schema:Get("layout.positions")
  W = W or UIParent:GetWidth(); H = H or UIParent:GetHeight()
  depth = depth or 0
  local r = self:Position(id, positions)
  if not r then return nil end
  local s = r.scale or 1
  local w, h = self:BaseSize(id, r)
  local a = r.attach
  if a and depth < 16 and not Layout.WouldCycle(positions, id, a.to) and (self.elements[a.to] or positions[a.to]) then
    local t = self:Rect(a.to, positions, W, H, depth + 1)
    if a.matchW then w = t.w / s end
    if a.matchH then h = t.h / s end
    local sw, sh, gap = w * s, h * s, a.gap or 0
    local l, b
    local frac = a.align == "START" and 0 or (a.align == "END" and 1 or 0.5)
    if a.side == "RIGHT" or a.side == "LEFT" then
      l = a.side == "RIGHT" and (t.l + t.w + gap) or (t.l - gap - sw)
      b = t.b + (t.h - sh) * (1 - frac)
    else
      b = a.side == "TOP" and (t.b + t.h + gap) or (t.b - gap - sh)
      l = t.l + (t.w - sw) * frac
    end
    return { l = l, b = b, w = sw, h = sh }
  end
  local sw, sh = w * s, h * s
  -- SetPoint offsets are in the frame's own scale: screen offset = x * s
  local ax, ay = FX[r.point] * W + r.x * s, FY[r.point] * H + r.y * s
  return { l = ax - FX[r.point] * sw, b = ay - FY[r.point] * sh, w = sw, h = sh }
end

-- Point pairs for edge-to-edge attach.
local ATTACH = {
  RIGHT = { START = { "TOPLEFT", "TOPRIGHT" }, CENTER = { "LEFT", "RIGHT" }, END = { "BOTTOMLEFT", "BOTTOMRIGHT" } },
  LEFT = { START = { "TOPRIGHT", "TOPLEFT" }, CENTER = { "RIGHT", "LEFT" }, END = { "BOTTOMRIGHT", "BOTTOMLEFT" } },
  TOP = { START = { "BOTTOMLEFT", "TOPLEFT" }, CENTER = { "BOTTOM", "TOP" }, END = { "BOTTOMRIGHT", "TOPRIGHT" } },
  BOTTOM = { START = { "TOPLEFT", "BOTTOMLEFT" }, CENTER = { "TOP", "BOTTOM" }, END = { "TOPRIGHT", "BOTTOMRIGHT" } },
}
Layout.ATTACH = ATTACH
local GAP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, TOP = { 0, 1 }, BOTTOM = { 0, -1 } }

-- Applies the record's look to a frame. The frame's own look is remembered the
-- first time Studio changes it, so clearing a field (unhide, scale back to
-- 100%, click-through off) puts the module's look back live.
local prior = setmetatable({}, { __mode = "k" })
local function remember(frame)
  if prior[frame] then return prior[frame] end
  local p = {
    scale = frame.GetScale and frame:GetScale() or 1, alpha = frame.GetAlpha and frame:GetAlpha() or 1,
    strata = frame.GetFrameStrata and frame:GetFrameStrata() or nil, level = frame.GetFrameLevel and frame:GetFrameLevel() or nil,
    mouse = frame.IsMouseEnabled and frame:IsMouseEnabled(),
  }
  prior[frame] = p
  return p
end
local function look(frame, r, fadeAlpha)
  local touches = r.scale or r.strata or r.level or r.alpha or r.hide or r.clickThrough or fadeAlpha
  local p = prior[frame]
  if not (touches or p) then return end
  p = remember(frame)
  if frame.SetScale then frame:SetScale(r.scale or p.scale or 1) end
  if frame.SetFrameStrata and (r.strata or p.strata) then frame:SetFrameStrata(r.strata or p.strata) end
  if frame.SetFrameLevel and (r.level or p.level) then frame:SetFrameLevel(r.level or p.level) end
  local alpha = r.hide and 0 or fadeAlpha or r.alpha or p.alpha or 1
  if frame.SetAlpha then frame:SetAlpha(alpha) end
  if frame.EnableMouse then
    if r.clickThrough or r.hide then frame:EnableMouse(false)
    elseif type(p.mouse) == "boolean" then frame:EnableMouse(p.mouse) end
  end
  if r.w and frame.SetWidth then frame:SetWidth(r.w) end
  if r.h and frame.SetHeight then frame:SetHeight(r.h) end
end
Layout.prior = prior

local function place(frame, id, r)
  frame:ClearAllPoints()
  local a = r.attach
  local target = a and Layout.frames[a.to]
  if a and target and not Layout.cycles[id] then
    local pts = ATTACH[a.side][a.align or "CENTER"]
    local g = GAP[a.side]
    frame:SetPoint(pts[1], target, pts[2], g[1] * (a.gap or 0), g[2] * (a.gap or 0))
    if a.matchW and frame.SetWidth and target.GetWidth then frame:SetWidth(target:GetWidth() or 0) end
    if a.matchH and frame.SetHeight and target.GetHeight then frame:SetHeight(target:GetHeight() or 0) end
  else
    frame:SetPoint(r.point, UIParent, r.point, r.x, r.y)
  end
  look(frame, r, Layout:FadeFor(id, r))
end

-- Anchors a frame to its element record now (or after combat if protected),
-- then re-places everything attached to it.
function Layout:Place(frame, id, pos, positions)
  self.frames[id] = frame
  pos = pos or self:Position(id, positions)
  if not pos then return end
  if frame.IsProtected and frame:IsProtected() and CQ.InCombat() then
    CQ.Defer("layout." .. id, function() place(frame, id, pos) end)
  else
    place(frame, id, pos)
  end
  if positions == nil and not self.placing then self:PlaceDependents(id) end
end

function Layout:PlaceDependents(id)
  local positions = PUI.Schema:Get("layout.positions")
  self.placing = true
  for did, r in pairs(positions) do
    local f = self.frames[did]
    if f and r.attach and r.attach.to == id then self:Place(f, did, r) end
  end
  self.placing = false
end

function Layout:Frame(id) return self.frames[id] end

-- Placement order: elements before the ones attached to them.
function Layout.Order(positions, ids)
  local out, done, visiting = {}, {}, {}
  local function visit(id)
    if done[id] or visiting[id] then return end
    visiting[id] = true
    local r = positions[id]
    if r and r.attach then visit(r.attach.to) end
    visiting[id] = nil
    done[id] = true
    out[#out + 1] = id
  end
  table.sort(ids)
  for _, id in ipairs(ids) do visit(id) end
  return out
end

function Layout:ApplyAll()
  local positions = PUI.Schema:Get("layout.positions")
  self.cycles = {}
  for id, r in pairs(positions) do
    if r.attach and Layout.WouldCycle(positions, id, r.attach.to) then
      self.cycles[id] = r.attach.to
      PUI:Log("layout.cycle", id, r.attach.to)
    end
  end
  local ids = {}
  for id in pairs(self.frames) do ids[#ids + 1] = id end
  self.placing = true
  for _, id in ipairs(Layout.Order(positions, ids)) do self:Place(self.frames[id], id, nil, positions) end
  self.placing = false
  self:RefreshFade(positions)
end

PUI.Schema:Register("layout.positions", {
  type = "layout", default = {}, overridable = true,
  label = "Element positions", tooltip = "Where Studio placed each Phoenix element, with its size, layer, look and attachments.",
  mode = "advanced", owner = "Studio",
  apply = function() Layout:ApplyAll() end,
})

------------------------------------------------------------------------------
-- Alpha by state. Pure resolver plus an event-driven refresher that is armed
-- only while some record uses it (coalesced to one pass per frame).
function Layout.FadeAlpha(fade, state, hover)
  if not fade then return nil end
  if state.petBattle and fade.petBattle then return fade.petBattle end
  if hover and fade.hover then return 1 end
  for i = 2, #Layout.FADE_ORDER do
    local k = Layout.FADE_ORDER[i]
    local active
    if k == "ooc" then active = not state.combat else active = state[k] end
    if active and fade[k] then return fade[k] end
  end
  return nil
end

local hovered = {}
Layout.hovered = hovered
local hooked = setmetatable({}, { __mode = "k" })
function Layout:FadeFor(id, r)
  if not (r and r.fade) then return nil end
  local V = PUI.Visibility
  local state = V and (V.state and next(V.state) and V.state or V.Probe()) or {}
  return Layout.FadeAlpha(r.fade, state, hovered[id])
end

local fadeFrame = PUI:CreateFrame("Frame", nil, nil, nil, "Studio")
local FADE_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING", "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_ENTERED_VEHICLE",
  "UNIT_EXITED_VEHICLE", "PLAYER_IS_GLIDING_CHANGED", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "PLAYER_ENTERING_WORLD" }
local function refade()
  PUI.Ticker:Unregister("layout.fade")
  local positions = PUI.Schema:Get("layout.positions")
  local V = PUI.Visibility
  if V then V.state = V.Probe() end
  for id, r in pairs(positions) do
    local f = Layout.frames[id]
    if f and r.fade and not r.hide and f.SetAlpha then f:SetAlpha(Layout:FadeFor(id, r) or r.alpha or 1) end
  end
end
Layout.Refade = refade
local function queue() PUI.Ticker:Register("layout.fade", 0, refade, "Studio") end
fadeFrame:SetScript("OnEvent", function(_, event)
  queue()
  -- leaving combat is observed through a CombatQueue entry (guardrail "regen")
  if event == "PLAYER_REGEN_DISABLED" then C_Timer.After(0, function() CQ.Defer("layout.fade.regen", queue) end) end
end)

function Layout:RefreshFade(positions)
  local any = false
  for id, r in pairs(positions) do
    if r.fade then
      any = true
      local f = self.frames[id]
      if f and r.fade.hover and f.HookScript and not hooked[f] then
        hooked[f] = true
        f:HookScript("OnEnter", function() hovered[id] = true; queue() end)
        f:HookScript("OnLeave", function() hovered[id] = nil; queue() end)
      end
    end
  end
  for _, e in ipairs(FADE_EVENTS) do
    if any then fadeFrame:RegisterEvent(e) else fadeFrame:UnregisterEvent(e) end
  end
  self.fadeArmed = any
end
