local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Unit frames, review gap: free text slots ("+ Add text slot"). Besides the
-- four fixed zones, each frame group takes any number of extra texts, one
-- line each: "<tag> @ <point> <x> <y> <size>", for example
--   "health:percent @ TOPRIGHT 0 10 14"  or just  "name @ BOTTOM".
-- Tags are the same ones the fixed zones use, so values reach the text
-- through Tags.Render (secret values go to SetText/SetFormattedText only).
local _, ns = ...
local UF, E, Tags = ns.UF, ns.Elements, ns.Tags
local Schema = PUI.Schema
local OWNER = "UnitFrames"
local T = {}
UF.TextSlots = T
T.POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

-- Parse(line) -> { tag, point, x, y, size } or nil, why
function T.Parse(line)
  if type(line) ~= "string" then return nil, "not text" end
  local tag, rest = line:match("^%s*([%w:%-]+)%s*@?%s*(.-)%s*$")
  if not tag then return nil, "start with a tag, for example health:percent" end
  if not Tags.render[tag] then return nil, "unknown tag '" .. tag .. "'" end
  local point, x, y, size = rest:match("^(%u*)%s*(%-?%d*)%s*(%-?%d*)%s*(%d*)$")
  if point == nil then return nil, "write it as tag @ POINT x y size" end
  if point ~= "" and not T.POINTS[point] then return nil, "unknown point '" .. point .. "'" end
  return { tag = tag, point = point ~= "" and point or "CENTER", x = tonumber(x) or 0, y = tonumber(y) or 0, size = tonumber(size) }
end

function T.Slots(c)
  local out = {}
  for _, line in ipairs(c.textSlots or {}) do local e = T.Parse(line); if e then out[#out + 1] = e end end
  return out
end

-- Build(o): one font string per slot on the frame's text layer.
function T.Build(o)
  local c = o.cfg
  if not (c and o.textLayer) then return 0 end
  o.slotTexts = o.slotTexts or {}
  local slots = T.Slots(c)
  for i, e in ipairs(slots) do
    local fs = o.slotTexts[i]
    if not fs then fs = o.textLayer:CreateFontString(nil, "OVERLAY"); o.slotTexts[i] = fs end
    fs:SetFontObject(PUI.Media:FontObject("small"))
    local base = o.texts and o.texts.left
    local path, size, flags = nil, nil, nil
    if base and base.GetFont then path, size, flags = base:GetFont() end
    if path and fs.SetFont then fs:SetFont(path, e.size or size or 12, flags) end
    fs:ClearAllPoints()
    fs:SetPoint(e.point, o.health, e.point, e.x, e.y)
    fs:SetJustifyH(e.point:find("LEFT") and "LEFT" or (e.point:find("RIGHT") and "RIGHT" or "CENTER"))
    fs.slot = e
    fs:Show()
    if UF.test then fs:SetText(Tags.LABELS and Tags.LABELS[e.tag] or e.tag) elseif o.unit then Tags.Render(fs, e.tag, o.unit) end
  end
  for i = #slots + 1, #o.slotTexts do o.slotTexts[i]:Hide(); o.slotTexts[i].slot = nil end
  return #slots
end

local layout = E.Layout
function E.Layout(o, c, ...)
  local a, b = layout(o, c, ...)
  T.Build(o)
  return a, b
end
local update = E.UpdateTexts
function E.UpdateTexts(o, channel)
  update(o, channel)
  for _, fs in ipairs(o.slotTexts or {}) do
    local e = fs.slot
    if e and (channel == nil or Tags.events[e.tag] == channel) then Tags.Render(fs, e.tag, o.unit) end
  end
end
local channels = UF.Channels
function UF.Channels(o)
  local list = channels(o)
  local c = UF.cfg[o.group]
  local ids = {}
  for _, e in ipairs(T.Slots(c)) do ids[#ids + 1] = e.tag end
  local extra = Tags.Channels(ids, {})
  for ch in pairs(extra) do list[ch] = true end
  return list
end

for _, g in ipairs(UF.ORDER) do
  local label = UF.GROUPS[g].label
  local main = (g == "player" or g == "target")
  local def = { type = "list", default = {}, mode = main and "simple" or "advanced", label = label .. " extra texts",
    tooltip = "Add text slot: one line each, \"tag @ POINT x y size\" (for example health:percent @ TOPRIGHT 0 10 14).",
    searchTags = { "text slot", "add text", "tags" }, overridable = true }
  UF.groupKey(g, "textSlots", def, function(c, v) c.textSlots = v end)
  Schema:Register("uf." .. g .. ".textSlots", def)
  UF.cfg[g].textSlots = Schema:Get("uf." .. g .. ".textSlots")
end
