local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio model: one editing session over the Layout positions with undo/redo
-- (PUI_V2 7). Pure data; Studio.lua draws it. Positions are
-- { point, x, y } relative to UIParent, as stored in layout.positions.
local Studio = { NUDGE = { 1, 10, 100 } }
PUI.Studio = Studio
local Session = {}
Session.__index = Session
Studio.Session = Session
local copy = PUI.Schema.Copy

function Studio.Snap(v, grid)
  if not grid or grid <= 0 then return v end
  return math.floor(v / grid + 0.5) * grid
end

local function round(v) return math.floor(v + 0.5) end

-- A session over every registered element, starting from saved positions.
function Session.New()
  local s = setmetatable({ pos = {}, undo = {}, redo = {}, selected = nil }, Session)
  local L = PUI.Layout
  for i = 1, #L.order do
    local id = L.order[i]
    s.pos[id] = copy(L:Position(id))
  end
  s.start = copy(s.pos)
  return s
end

function Session:Get(id) return self.pos[id] end

function Session:Move(id, x, y, point)
  local cur = self.pos[id]
  if not cur then error("Studio: unknown element '" .. tostring(id) .. "'", 2) end
  local new = { point = point or cur.point, x = round(x), y = round(y) }
  if new.point == cur.point and new.x == cur.x and new.y == cur.y then return false end
  self.undo[#self.undo + 1] = { id = id, before = copy(cur), after = copy(new) }
  self.redo = {}
  self.pos[id] = new
  return true
end

-- step: 1, 10 or 100 px (PUI_V2 7: arrow nudge 1/10/100).
function Session:Nudge(id, dx, dy, step)
  local cur = self.pos[id]
  step = step or 1
  return self:Move(id, cur.x + dx * step, cur.y + dy * step)
end

function Session:Undo()
  local op = table.remove(self.undo)
  if not op then return nil end
  self.pos[op.id] = copy(op.before)
  self.redo[#self.redo + 1] = op
  return op.id
end

function Session:Redo()
  local op = table.remove(self.redo)
  if not op then return nil end
  self.pos[op.id] = copy(op.after)
  self.undo[#self.undo + 1] = op
  return op.id
end

function Session:Dirty() return not PUI.DB.DeepEqual(self.pos, self.start) end

-- Positions to store: only elements away from their default.
function Session:Saved()
  local out, L = {}, PUI.Layout
  for id, pos in pairs(self.pos) do
    local d = L:Element(id) and L:Element(id).default
    if not (d and d.point == pos.point and (d.x or 0) == pos.x and (d.y or 0) == pos.y) then out[id] = copy(pos) end
  end
  return out
end

-- Resets one element to its default anchor (undoable).
function Session:ResetElement(id)
  local d = PUI.Layout:Element(id).default
  return self:Move(id, d.x or 0, d.y or 0, d.point)
end

-- Converts a mover's screen centre to a CENTER offset from UIParent centre.
function Studio.CenterOffset(cx, cy, parentW, parentH)
  return round(cx - parentW / 2), round(cy - parentH / 2)
end
