local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Layout: where every movable Phoenix element sits (PUI_V2 7, Studio v1).
-- Elements register an id, a label and a default anchor; positions the user
-- saved in Studio live in the hidden schema key layout.positions as
-- { [id] = { point = "CENTER", x = n, y = n } } relative to UIParent.
-- Placing a protected frame in combat is deferred through the CombatQueue.
local Layout = { elements = {}, order = {}, frames = setmetatable({}, { __mode = "v" }) }
PUI.Layout = Layout

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

-- The effective position of an element: saved, else default.
function Layout:Position(id)
  local saved = PUI.Schema:Get("layout.positions")[id]
  if saved then return saved end
  local d = self.elements[id] and self.elements[id].default
  return d and { point = d.point, x = d.x or 0, y = d.y or 0 } or nil
end

local function place(frame, pos)
  frame:ClearAllPoints()
  frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

-- Anchors a frame to its element position now (or after combat if protected).
function Layout:Place(frame, id, pos)
  self.frames[id] = frame
  pos = pos or self:Position(id)
  if not pos then return end
  if frame.IsProtected and frame:IsProtected() and PUI.CombatQueue.InCombat() then
    PUI.CombatQueue.Defer("layout." .. id, function() place(frame, pos) end)
  else
    place(frame, pos)
  end
end

function Layout:Frame(id) return self.frames[id] end

function Layout:ApplyAll()
  for id, frame in pairs(self.frames) do self:Place(frame, id) end
end

PUI.Schema:Register("layout.positions", {
  type = "layout", default = {},
  label = "Element positions", tooltip = "Where Studio placed each Phoenix element.",
  mode = "advanced", owner = "Studio",
  apply = function() Layout:ApplyAll() end,
})
