local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio model v2 (plan 4, mockup 12): one editing session over every element
-- record (Phoenix elements from layout.positions, Blizzard elements from
-- studio.blizzard.positions) with batched undo/redo, multi-select, align and
-- distribute, edge-to-edge attach with matched sizes, snapping to the grid and
-- to other elements, distance labels, overlap picking, layout export/import,
-- templates and "explain this element". Pure data; Studio.lua draws it.
local Studio = { NUDGE = { 1, 10, 100 }, PREFIX = "!PUI_LAY1:" }
PUI.Studio = Studio
local Session = {}
Session.__index = Session
Studio.Session = Session
local Schema, Layout = PUI.Schema, PUI.Layout
local copy = Schema.Copy
local function round(v) return math.floor(v + 0.5) end

function Studio.Snap(v, grid)
  if not grid or grid <= 0 then return v end
  return math.floor(v / grid + 0.5) * grid
end

local function isBlizzard(id) return id:sub(1, 3) == "bz." end
Studio.IsBlizzard = isBlizzard

-- Elements this session edits: every Phoenix element, plus Blizzard ones when enabled.
function Studio.Ids(includeBlizzard)
  local out = {}
  for i = 1, #Layout.order do
    local id = Layout.order[i]
    if not isBlizzard(id) or includeBlizzard then out[#out + 1] = id end
  end
  return out
end

function Session.New(opts)
  opts = opts or {}
  local blizz = opts.blizzard
  if blizz == nil then blizz = Schema:Get("studio.blizzard.enabled") end
  local s = setmetatable({ pos = {}, undo = {}, redo = {}, selected = nil, sel = {}, touched = {}, ids = Studio.Ids(blizz),
    W = opts.W or UIParent:GetWidth(), H = opts.H or UIParent:GetHeight() }, Session)
  local saved, bz = Schema:Get("layout.positions"), Schema:Get("studio.blizzard.positions")
  for _, id in ipairs(s.ids) do
    if isBlizzard(id) then
      local r = bz[id]
      if r then s.touched[id] = true end
      s.pos[id] = copy(r or (PUI.Movers and PUI.Movers:Current(id)) or Layout:Position(id, {}))
    else
      s.pos[id] = copy(Layout:Position(id, saved))
    end
  end
  s.start, s.startTouched = copy(s.pos), copy(s.touched)
  return s
end

function Session:Get(id) return self.pos[id] end
function Session:Has(id) return self.pos[id] ~= nil end
function Session:Rect(id) return Layout:Rect(id, self.pos, self.W, self.H) end

-- Edit Mode owns this element: Phoenix never changes it.
function Session:Locked(id)
  local el = Layout:Element(id)
  return el ~= nil and el.editMode == true
end

-- One undoable step over several elements: changes = { [id] = newRecord }.
function Session:Commit(changes, label)
  local step = { label = label, before = {}, after = {}, touchedBefore = {} }
  local any = false
  for id, new in pairs(changes) do
    local cur = self.pos[id]
    if not cur then error("Studio: unknown element '" .. tostring(id) .. "'", 2) end
    if not self:Locked(id) and not PUI.DB.DeepEqual(cur, new) then
      step.before[id], step.after[id], step.touchedBefore[id] = copy(cur), copy(new), self.touched[id]
      self.pos[id] = copy(new)
      self.touched[id] = true
      any = true
    end
  end
  if not any then return false end
  self.undo[#self.undo + 1] = step
  self.redo = {}
  return true
end

local function firstKey(t) for k in pairs(t) do return k end end

function Session:Undo()
  local op = table.remove(self.undo)
  if not op then return nil end
  for id, r in pairs(op.before) do self.pos[id] = copy(r); self.touched[id] = op.touchedBefore[id] end
  self.redo[#self.redo + 1] = op
  return firstKey(op.before), op
end

function Session:Redo()
  local op = table.remove(self.redo)
  if not op then return nil end
  for id, r in pairs(op.after) do self.pos[id] = copy(r); self.touched[id] = true end
  self.undo[#self.undo + 1] = op
  return firstKey(op.after), op
end

local function with(rec, fields)
  local r = copy(rec)
  for k, v in pairs(fields) do if v == false then r[k] = nil else r[k] = v end end
  return r
end
Studio.With = with

function Session:Move(id, x, y, point)
  local cur = self.pos[id]
  if not cur then error("Studio: unknown element '" .. tostring(id) .. "'", 2) end
  -- moving an attached element by hand detaches it
  local r = with(cur, { point = point or cur.point, x = round(x), y = round(y), attach = false })
  return self:Commit({ [id] = r }, "move")
end

-- step: 1, Shift or Ctrl step (studio.nudgeShift / nudgeCtrl).
function Session:Nudge(id, dx, dy, step)
  local cur = self.pos[id]
  step = step or 1
  if cur.attach then
    local a = copy(cur.attach)
    local horizontal = a.side == "LEFT" or a.side == "RIGHT"
    local sign = (a.side == "RIGHT" or a.side == "TOP") and 1 or -1
    a.gap = math.max(-200, math.min(200, (a.gap or 0) + sign * (horizontal and dx or dy) * step))
    return self:Commit({ [id] = with(cur, { attach = a }) }, "gap")
  end
  return self:Move(id, cur.x + dx * step, cur.y + dy * step)
end

-- Sets one record field (scale, w, h, strata, level, alpha, hide, clickThrough).
function Session:Set(id, field, value)
  local cur = self.pos[id]
  if value == nil then value = false end
  return self:Commit({ [id] = with(cur, { [field] = value }) }, field)
end

-- Alpha for one state ("combat", "ooc", ...), or hover = true/false; nil clears.
function Session:SetFade(id, state, value)
  local cur = self.pos[id]
  local fade = copy(cur.fade or {})
  fade[state] = value
  if next(fade) == nil then fade = false end
  return self:Commit({ [id] = with(cur, { fade = fade }) }, "fade")
end

-- Edge-to-edge attach. Refuses self, unknown targets and cycles.
function Session:Attach(id, to, side, gap, align, matchW, matchH)
  if not (self.pos[id] and self.pos[to]) then return false, "unknown element" end
  if Layout.WouldCycle(self.pos, id, to) then return false, "that would attach the element to itself" end
  local a = { to = to, side = side or "RIGHT", gap = gap or 0, align = align or "CENTER" }
  if matchW then a.matchW = true end
  if matchH then a.matchH = true end
  return self:Commit({ [id] = with(self.pos[id], { attach = a }) }, "attach")
end

-- Detach keeps the element where it is on screen.
function Session:Detach(id)
  local cur = self.pos[id]
  if not (cur and cur.attach) then return false end
  local r = self:Rect(id)
  local s = cur.scale or 1
  local x = (r.l + r.w / 2 - self.W / 2) / s
  local y = (r.b + r.h / 2 - self.H / 2) / s
  return self:Commit({ [id] = with(cur, { attach = false, point = "CENTER", x = round(x), y = round(y) }) }, "detach")
end

-- Places id so its rect's centre lands at screen-centre offset (cx, cy).
function Session:CenterAt(id, cx, cy)
  local cur = self.pos[id]
  local s = cur.scale or 1
  return with(cur, { point = "CENTER", x = round(cx / s), y = round(cy / s), attach = false })
end

-- Selection ---------------------------------------------------------------
function Session:Select(id, add)
  if not add then self.sel = {} end
  if id then
    if add and self.sel[id] then self.sel[id] = nil else self.sel[id] = true end
  end
  self.selected = id and self.sel[id] and id or firstKey(self.sel)
  return self.selected
end

function Session:Selection()
  local out = {}
  for id in pairs(self.sel) do out[#out + 1] = id end
  table.sort(out)
  return out
end

function Session:SelectBox(l, b, r, t, add, visible)
  if not add then self.sel = {} end
  for id in pairs(self.pos) do
    local rc = (not visible or visible[id]) and self:Rect(id)
    if rc and rc.l < r and rc.l + rc.w > l and rc.b < t and rc.b + rc.h > b then self.sel[id] = true end
  end
  self.selected = firstKey(self.sel)
  return #self:Selection()
end

-- Moves every id by (dx, dy) screen pixels in one step (attached ones follow their anchor).
function Session:MoveGroup(ids, dx, dy)
  local ch = {}
  for _, id in ipairs(ids) do
    local cur = self.pos[id]
    if cur and not cur.attach then
      local s = cur.scale or 1
      ch[id] = with(cur, { x = round(cur.x + dx / s), y = round(cur.y + dy / s) })
    end
  end
  return self:Commit(ch, "group move")
end

-- Align: left, right, hcenter, top, bottom, vcenter (to the selection's bounds).
function Session:Align(ids, how)
  if #ids < 2 then return false end
  local rects, minL, maxR, minB, maxT = {}, math.huge, -math.huge, math.huge, -math.huge
  for _, id in ipairs(ids) do
    local r = self:Rect(id)
    rects[id] = r
    minL, maxR = math.min(minL, r.l), math.max(maxR, r.l + r.w)
    minB, maxT = math.min(minB, r.b), math.max(maxT, r.b + r.h)
  end
  local ch = {}
  for _, id in ipairs(ids) do
    local r = rects[id]
    local cx, cy = r.l + r.w / 2, r.b + r.h / 2
    if how == "left" then cx = minL + r.w / 2
    elseif how == "right" then cx = maxR - r.w / 2
    elseif how == "hcenter" then cx = (minL + maxR) / 2
    elseif how == "top" then cy = maxT - r.h / 2
    elseif how == "bottom" then cy = minB + r.h / 2
    elseif how == "vcenter" then cy = (minB + maxT) / 2 end
    ch[id] = self:CenterAt(id, cx - self.W / 2, cy - self.H / 2)
  end
  return self:Commit(ch, "align " .. how)
end

-- Distribute: equal gaps between elements along "h" or "v".
function Session:Distribute(ids, axis)
  if #ids < 3 then return false end
  local items, total = {}, 0
  for _, id in ipairs(ids) do
    local r = self:Rect(id)
    items[#items + 1] = { id = id, r = r }
    total = total + (axis == "h" and r.w or r.h)
  end
  table.sort(items, function(a, b) if axis == "h" then return a.r.l < b.r.l end return a.r.b < b.r.b end)
  local first, last = items[1].r, items[#items].r
  local span = axis == "h" and (last.l + last.w - first.l) or (last.b + last.h - first.b)
  local gap = (span - total) / (#items - 1)
  local cursor = axis == "h" and first.l or first.b
  local ch = {}
  for _, it in ipairs(items) do
    local r = it.r
    if axis == "h" then
      ch[it.id] = self:CenterAt(it.id, cursor + r.w / 2 - self.W / 2, r.b + r.h / 2 - self.H / 2)
      cursor = cursor + r.w + gap
    else
      ch[it.id] = self:CenterAt(it.id, r.l + r.w / 2 - self.W / 2, cursor + r.h / 2 - self.H / 2)
      cursor = cursor + r.h + gap
    end
  end
  return self:Commit(ch, "distribute")
end

-- Snapping ------------------------------------------------------------------
-- Proposed drag result: centre offset (cx, cy) of id. Returns snapped cx, cy
-- and guides { { axis = "x"|"y", at = screen coordinate, to = id|"screen" } }.
function Session:SnapCenter(id, cx, cy, opts)
  opts = opts or {}
  local mode, dist, grid = opts.mode or "both", opts.distance or 8, opts.grid
  local me = self:Rect(id)
  local w, h = me.w, me.h
  local guides = {}
  local function best(own, candidates)
    local pick, pickAt, pickTo
    for _, c in ipairs(candidates) do
      for _, o in ipairs(own) do
        local d = c.at - o
        if math.abs(d) <= dist and (not pick or math.abs(d) < math.abs(pick)) then pick, pickAt, pickTo = d, c.at, c.to end
      end
    end
    return pick, pickAt, pickTo
  end
  local snappedX, snappedY = false, false
  if mode == "elements" or mode == "both" then
    local sx, sy = cx + self.W / 2, cy + self.H / 2 -- centre in screen coordinates
    local xs, ys = { { at = self.W / 2, to = "screen" }, { at = 0, to = "screen" }, { at = self.W, to = "screen" } },
      { { at = self.H / 2, to = "screen" }, { at = 0, to = "screen" }, { at = self.H, to = "screen" } }
    for oid in pairs(self.pos) do
      if oid ~= id and not (self.sel[oid] and self.sel[id]) and (not opts.visible or opts.visible[oid]) then
        local r = self:Rect(oid)
        xs[#xs + 1] = { at = r.l, to = oid }; xs[#xs + 1] = { at = r.l + r.w, to = oid }; xs[#xs + 1] = { at = r.l + r.w / 2, to = oid }
        ys[#ys + 1] = { at = r.b, to = oid }; ys[#ys + 1] = { at = r.b + r.h, to = oid }; ys[#ys + 1] = { at = r.b + r.h / 2, to = oid }
      end
    end
    local dx, atx, tox = best({ sx - w / 2, sx, sx + w / 2 }, xs)
    local dy, aty, toy = best({ sy - h / 2, sy, sy + h / 2 }, ys)
    if dx then cx = cx + dx; snappedX = true; guides[#guides + 1] = { axis = "x", at = atx, to = tox } end
    if dy then cy = cy + dy; snappedY = true; guides[#guides + 1] = { axis = "y", at = aty, to = toy } end
  end
  if (mode == "grid" or mode == "both") and grid and grid > 0 then
    if not snappedX then cx = Studio.Snap(cx, grid) end
    if not snappedY then cy = Studio.Snap(cy, grid) end
  end
  return round(cx), round(cy), guides
end

-- Distance labels: nearest gap on each side to an element or the screen edge.
-- Returns { left = { gap, to }, right = ..., up = ..., down = ... }.
function Session:Distances(id, visible)
  local me = self:Rect(id)
  local out = {
    left = { gap = round(me.l), to = "screen" }, right = { gap = round(self.W - me.l - me.w), to = "screen" },
    down = { gap = round(me.b), to = "screen" }, up = { gap = round(self.H - me.b - me.h), to = "screen" },
  }
  for oid in pairs(self.pos) do
    if oid ~= id and (not visible or visible[oid]) then
      local r = self:Rect(oid)
      local vOverlap = r.b < me.b + me.h and r.b + r.h > me.b
      local hOverlap = r.l < me.l + me.w and r.l + r.w > me.l
      if vOverlap then
        local g = me.l - (r.l + r.w)
        if g >= 0 and g < out.left.gap then out.left = { gap = round(g), to = oid } end
        g = r.l - (me.l + me.w)
        if g >= 0 and g < out.right.gap then out.right = { gap = round(g), to = oid } end
      end
      if hOverlap then
        local g = me.b - (r.b + r.h)
        if g >= 0 and g < out.down.gap then out.down = { gap = round(g), to = oid } end
        g = r.b - (me.b + me.h)
        if g >= 0 and g < out.up.gap then out.up = { gap = round(g), to = oid } end
      end
    end
  end
  return out
end

-- Overlap picking: every element under a screen point, smallest first.
function Session:ElementsAt(x, y, visible)
  local out = {}
  for id in pairs(self.pos) do
    if not visible or visible[id] then
      local r = self:Rect(id)
      if x >= r.l and x <= r.l + r.w and y >= r.b and y <= r.b + r.h then out[#out + 1] = { id = id, area = r.w * r.h } end
    end
  end
  table.sort(out, function(a, b) if a.area ~= b.area then return a.area < b.area end return a.id < b.id end)
  for i = 1, #out do out[i] = out[i].id end
  return out
end

-- Saving ------------------------------------------------------------------
function Session:Dirty() return not PUI.DB.DeepEqual(self.pos, self.start) or not PUI.DB.DeepEqual(self.touched, self.startTouched) end

local function isDefault(id, pos)
  local d = Layout:Element(id) and Layout:Element(id).default
  if not d then return false end
  for k in pairs(pos) do if k ~= "point" and k ~= "x" and k ~= "y" then return false end end
  return d.point == pos.point and (d.x or 0) == pos.x and (d.y or 0) == pos.y
end

-- Positions to store: Phoenix elements away from their default record, and
-- Blizzard elements the user changed. Returns phoenix, blizzard.
function Session:Saved()
  local out, bz = {}, {}
  for id, pos in pairs(self.pos) do
    if isBlizzard(id) then
      if self.touched[id] and not self:Locked(id) then bz[id] = copy(pos) end
    elseif not isDefault(id, pos) then out[id] = copy(pos) end
  end
  return out, bz
end

-- Resets one element to its default (Phoenix) or to Blizzard's own placement.
function Session:ResetElement(id)
  if isBlizzard(id) then
    local before = copy(self.pos[id])
    local was = self.touched[id]
    if not was then return false end
    self.touched[id] = nil
    local cur = PUI.Movers and PUI.Movers:Current(id) or self.pos[id]
    self.pos[id] = copy(cur)
    self.undo[#self.undo + 1] = { label = "reset", before = { [id] = before }, after = { [id] = copy(cur) }, touchedBefore = { [id] = was } }
    self.redo = {}
    return true
  end
  local d = Layout:Element(id).default
  return self:Commit({ [id] = { point = d.point, x = d.x or 0, y = d.y or 0 } }, "reset")
end

-- Every Phoenix element back to default (one undo step).
function Session:ResetAll()
  local ch = {}
  for id in pairs(self.pos) do
    if not isBlizzard(id) then
      local d = Layout:Element(id).default
      ch[id] = { point = d.point, x = d.x or 0, y = d.y or 0 }
    end
  end
  return self:Commit(ch, "reset all")
end

-- Converts a mover's screen centre to a CENTER offset from UIParent centre.
function Studio.CenterOffset(cx, cy, parentW, parentH)
  return round(cx - parentW / 2), round(cy - parentH / 2)
end

-- Export / import -------------------------------------------------------------
-- "!PUI_LAY1:" + base64(compress(serialize{ v, kind = "layout", W, H, positions, blizzard })).
function Studio.Export(session, name)
  local phoenix, bz = session:Saved()
  local payload = PUI.Profiles.Serialize({ v = 1, kind = "layout", name = name or "Layout", W = round(session.W), H = round(session.H),
    positions = phoenix, blizzard = bz })
  local packed = C_EncodingUtil and C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(payload)) or payload
  return Studio.PREFIX .. packed
end

local function scaleRecords(t, fx, fy)
  for _, r in pairs(t) do
    if not r.attach then r.x, r.y = round(r.x * fx), round(r.y * fy) end
  end
end

-- Decode: returns a preview plan { name, positions, blizzard, known, unknown,
-- changed, kept, invalid, scaled } or nil, reason. Nothing changes yet.
function Studio.Decode(text, session)
  if type(text) ~= "string" then return nil, "paste a Phoenix layout string" end
  text = text:gsub("%s", "")
  if #text > 200000 then return nil, "string is too large" end
  if text:sub(1, #Studio.PREFIX) ~= Studio.PREFIX then return nil, "not a Phoenix layout string (should start with " .. Studio.PREFIX .. ")" end
  local raw = text:sub(#Studio.PREFIX + 1)
  if C_EncodingUtil then
    local bin = C_EncodingUtil.DecodeBase64(raw)
    raw = bin and C_EncodingUtil.DecompressString(bin)
    if not raw then return nil, "string is damaged (could not decompress)" end
  end
  local data, err = PUI.Profiles.Deserialize(raw)
  if not data then return nil, "string is damaged (" .. tostring(err) .. ")" end
  if type(data) ~= "table" or data.v ~= 1 or data.kind ~= "layout" or type(data.positions) ~= "table" then return nil, "unsupported layout version" end
  local plan = { name = type(data.name) == "string" and data.name or "Imported layout", positions = {}, blizzard = {},
    known = 0, unknown = 0, changed = 0, kept = 0, invalid = {} }
  local function take(src, dst)
    for id, r in pairs(type(src) == "table" and src or {}) do
      local ok, why = Layout.ValidRecord(r)
      if type(id) ~= "string" or not Layout:Element(id) then plan.unknown = plan.unknown + 1
      elseif not ok then plan.invalid[#plan.invalid + 1] = id .. ": " .. why
      else
        dst[id] = copy(r)
        plan.known = plan.known + 1
        if session and session:Has(id) and PUI.DB.DeepEqual(session:Get(id), r) then plan.kept = plan.kept + 1 else plan.changed = plan.changed + 1 end
      end
    end
  end
  take(data.positions, plan.positions)
  take(data.blizzard, plan.blizzard)
  table.sort(plan.invalid)
  local W, H = session and session.W or UIParent:GetWidth(), session and session.H or UIParent:GetHeight()
  if type(data.W) == "number" and type(data.H) == "number" and data.W > 0 and data.H > 0 and (round(data.W) ~= round(W) or round(data.H) ~= round(H)) then
    scaleRecords(plan.positions, W / data.W, H / data.H)
    scaleRecords(plan.blizzard, W / data.W, H / data.H)
    plan.scaled = true
  end
  return plan
end

-- Applies a plan into the session as one undoable step (live preview; the
-- user still saves or discards). Elements the plan does not name are kept.
function Studio.ApplyPlan(session, plan)
  if #plan.invalid > 0 then return false, #plan.invalid .. " invalid element(s); nothing was changed" end
  local ch = {}
  for id, r in pairs(plan.positions) do if session:Has(id) then ch[id] = r end end
  for id, r in pairs(plan.blizzard) do if session:Has(id) then ch[id] = r end end
  session:Commit(ch, "import")
  return true
end

-- Templates: named layouts kept in studio.templates (per profile).
function Studio.SaveTemplate(session, name)
  if type(name) ~= "string" or name:gsub("%s", "") == "" then return false, "name the layout" end
  local t = Schema:Get("studio.templates")
  local phoenix, bz = session:Saved()
  t[name] = { positions = phoenix, blizzard = bz, W = round(session.W), H = round(session.H), at = time and time() or 0 }
  Schema:Set("studio.templates", t)
  return true
end

function Studio.Templates()
  local out = {}
  for name in pairs(Schema:Get("studio.templates")) do out[#out + 1] = name end
  table.sort(out)
  return out
end

function Studio.ApplyTemplate(session, name)
  local t = Schema:Get("studio.templates")[name]
  if not t then return false, "no layout named " .. tostring(name) end
  local plan = { positions = copy(t.positions or {}), blizzard = copy(t.blizzard or {}), invalid = {} }
  if t.W and t.H and t.W > 0 and t.H > 0 then
    scaleRecords(plan.positions, session.W / t.W, session.H / t.H)
    scaleRecords(plan.blizzard, session.W / t.W, session.H / t.H)
  end
  return Studio.ApplyPlan(session, plan)
end

function Studio.DeleteTemplate(name)
  local t = Schema:Get("studio.templates")
  if not t[name] then return false end
  t[name] = nil
  Schema:Set("studio.templates", t)
  return true
end

-- Explain this element ---------------------------------------------------------
-- Every setting that drives the element: its own schema keys (spec.keys prefix,
-- else the element id), its layout record, attach chain, "where to show" and
-- per-spec/per-content override provenance. Returns { lines = {...}, keys = n }.
function Studio.ExplainElement(id, session)
  local el = Layout:Element(id)
  if not el then return nil end
  local lines, keys = {}, 0
  local prefix = el.keys or id
  local rec = session and session:Get(id) or Layout:Position(id)
  lines[#lines + 1] = string.format("Anchor %s %d, %d to %s", rec.point, rec.x, rec.y, rec.attach and ("the " .. rec.attach.side:lower() .. " edge of " .. ((Layout:Element(rec.attach.to) or {}).label or rec.attach.to)) or "the screen")
  if rec.scale then lines[#lines + 1] = string.format("Scale %d%%", round(rec.scale * 100)) end
  if rec.strata or rec.level then lines[#lines + 1] = string.format("Layer %s, level %s", rec.strata or "default", tostring(rec.level or "default")) end
  if rec.hide then lines[#lines + 1] = "Hidden by Studio" elseif rec.alpha then lines[#lines + 1] = string.format("Opacity %d%%", round(rec.alpha * 100)) end
  if rec.clickThrough then lines[#lines + 1] = "Click-through" end
  if rec.fade then
    for _, k in ipairs(Layout.FADE_ORDER) do
      if rec.fade[k] then lines[#lines + 1] = string.format("%s: %d%%", Layout.FADE_LABELS[k], round(rec.fade[k] * 100)) end
    end
    if rec.fade.hover then lines[#lines + 1] = "Mouse-over shows it fully" end
  end
  if el.editMode then lines[#lines + 1] = "Blizzard's Edit Mode owns this element" end
  local _, src = PUI.Overrides and PUI.Overrides:Lookup(isBlizzard(id) and "studio.blizzard.positions" or "layout.positions")
  if src then lines[#lines + 1] = "Layout comes from the " .. src .. " override" end
  for _, key in ipairs(Schema.keys) do
    if key == prefix or key:sub(1, #prefix + 1) == prefix .. "." then
      local def = Schema:Def(key)
      if def and not def.hidden then
        keys = keys + 1
        local v = Schema:Get(key)
        local shown = type(v) == "table" and "(table)" or tostring(v)
        lines[#lines + 1] = string.format("%s = %s%s", def.label, shown, Schema:IsDefault(key) and "" or " (changed)")
      end
    end
  end
  if el.visibility and PUI.Visibility then
    local shown, why = PUI.Visibility:Why(el.visibility)
    if shown == false then lines[#lines + 1] = "Hidden now: " .. tostring(why) end
  end
  return { lines = lines, keys = keys, label = el.label }
end
