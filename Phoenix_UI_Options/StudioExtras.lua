local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio, deferred batch B: connector lines between attached movers, layout
-- template thumbnails (click one to apply), a resize grip on the selected
-- mover (width/height for resizable elements, scale for the rest), grow
-- direction for bars and groups in the inspector (the module's own setting,
-- applied live), and the one-time ElvUI mover import. Free party placement
-- lives in Raid Frames (Members.lua); faded Blizzard elements follow state
-- events in Core (Layout + Movers); the Blizzard element list is its own page.
local Studio, Theme = PUI.Studio, PUI.Theme
local Schema, Layout = PUI.Schema, PUI.Layout
local Options = PUI.Options
local Kit = Options.Kit

Schema:Register("studio.connectors", { type = "toggle", default = true, owner = "Studio",
  label = "Connector lines", tooltip = "Draws a line from each attached element to the element it is attached to while Studio is open.",
  mode = "simple", searchTags = { "attach", "link", "line" },
  apply = function() if Studio.IsOpen and Studio:IsOpen() then Studio:DrawConnectors() end end })

-- Connector lines --------------------------------------------------------------------
-- Pure: from the attached element's facing edge midpoint to its target's.
function Studio.ConnectorPoints(a, t, side)
  if side == "RIGHT" then return a.l, a.b + a.h / 2, t.l + t.w, t.b + t.h / 2
  elseif side == "LEFT" then return a.l + a.w, a.b + a.h / 2, t.l, t.b + t.h / 2
  elseif side == "TOP" then return a.l + a.w / 2, a.b, t.l + t.w / 2, t.b + t.h
  end
  return a.l + a.w / 2, a.b + a.h, t.l + t.w / 2, t.b
end
Studio.connectors = {}
local function seg(n)
  local t = Studio.connectors[n]
  if not t then
    t = Studio.overlay:CreateTexture(nil, "ARTWORK")
    Theme:Paint(t, "ok", 0.9)
    Studio.connectors[n] = t
  end
  t:ClearAllPoints()
  t:Show()
  return t
end
-- Two axis-aligned segments (an elbow), 2 px thick, plus a dot at the target.
function Studio:DrawConnectors()
  for _, t in ipairs(self.connectors) do t:Hide() end
  if not (self.overlay and self.session and Schema:Get("studio.connectors")) then return 0 end
  local n, lines = 0, 0
  local vis = self:Visible()
  for id, r in pairs(self.session.pos) do
    local a = r.attach
    if a and vis[id] and vis[a.to] then
      local x1, y1, x2, y2 = Studio.ConnectorPoints(self.session:Rect(id), self.session:Rect(a.to), a.side)
      local h = seg(n + 1)
      h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.min(x1, x2), y1 - 1)
      h:SetSize(math.max(2, math.abs(x2 - x1)), 2)
      local v = seg(n + 2)
      v:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x2 - 1, math.min(y1, y2))
      v:SetSize(2, math.max(2, math.abs(y2 - y1)))
      local dot = seg(n + 3)
      dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x2, y2)
      dot:SetSize(6, 6)
      n = n + 3
      lines = lines + 1
    end
  end
  return lines
end

local placeMover = Studio.PlaceMover
function Studio:PlaceMover(id, noPreview)
  placeMover(self, id, noPreview)
  if not self.bulk then self:DrawConnectors() end
end
local placeAll = Studio.PlaceAll
function Studio:PlaceAll()
  self.bulk = true
  placeAll(self)
  self.bulk = nil
  self:DrawConnectors()
end

-- Resize grip -------------------------------------------------------------------------
-- Pure: the record change for a mover dragged to newW x newH screen pixels.
function Studio.ResizeResult(id, rec, newW, newH)
  local el = Layout:Element(id)
  local s = rec.scale or 1
  if el and el.resizable then
    return { w = math.max(4, math.floor(newW / s + 0.5)), h = math.max(4, math.floor(newH / s + 0.5)) }
  end
  local w = Layout:BaseSize(id, rec)
  local scale = math.max(0.25, math.min(4, newW / math.max(1, w)))
  return { scale = math.floor(scale * 100 + 0.5) / 100 }
end
function Studio:FinishResize(m)
  m:StopMovingOrSizing()
  local s = self.session
  if not (s and s:Has(m.id)) then return end
  local ch = Studio.ResizeResult(m.id, s:Get(m.id), m:GetWidth(), m:GetHeight())
  for field, v in pairs(ch) do s:Set(m.id, field, v) end
  Studio.Changed({ m.id })
end
local function grip(m)
  local g = CreateFrame("Frame", nil, m)
  g:SetSize(12, 12)
  g:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 4, -4)
  g:SetFrameLevel(m:GetFrameLevel() + 2)
  g:EnableMouse(true)
  g:SetScript("OnMouseDown", function()
    if Studio.session:Locked(m.id) then return end
    m:SetResizable(true)
    m:StartSizing("BOTTOMRIGHT")
  end)
  g:SetScript("OnMouseUp", function() Studio:FinishResize(m) end)
  g:Hide()
  return g
end
local mover = Studio.Mover
function Studio:Mover(id)
  local m = mover(self, id)
  if not rawget(m, "grip") then
    m.grip = grip(m)
    local setSel = m.SetSelected
    function m:SetSelected(on, primary)
      setSel(self, on, primary)
      self.grip:SetShown(primary == true and not Studio.IsBlizzard(self.id))
    end
  end
  return m
end

-- Grow direction in the inspector --------------------------------------------------------
local GROW_SUFFIX = { ".growX", ".growY", ".growth", ".grow", ".growLeft", ".growUp", ".direction", ".drGrow" }
local GROW_EXTRA = { ["arena.frames"] = { "arena.grow", "arena.drGrow" }, ["pulse.bars"] = { "pulse.grow" } }
-- Schema keys that set the direction the element grows in (module settings).
function Studio.GrowKeys(id)
  local out = {}
  local function add(k) if Schema:Def(k) and #out < 2 then out[#out + 1] = k end end
  for _, k in ipairs(GROW_EXTRA[id] or {}) do add(k) end
  if id:find("^casthistory%.") then add("ch.direction") end
  local area = id:match("^spark%.(%w+)$")
  if area then add("spark.area." .. area .. ".direction") end
  for _, suf in ipairs(GROW_SUFFIX) do add(id .. suf) end
  return out
end
local function valueLabel(def, v)
  if def.type == "toggle" then return v and "on" or "off" end
  local labels = def.choiceLabels
  return labels and labels[v] or tostring(v)
end
-- Next value of a grow key (toggles flip; selects cycle through their choices).
function Studio.NextGrow(key)
  local def, v = Schema:Def(key), Schema:Get(key)
  if def.type == "toggle" then return not v end
  local choices = type(def.choices) == "function" and def.choices() or def.choices
  for i, c in ipairs(choices) do if c == v then return choices[i % #choices + 1] end end
  return choices[1]
end
local function shortLabel(key)
  local def = Schema:Def(key)
  local l = PUI.L[def.label] or key
  return (l:gsub("^.-:%s*", ""))
end
local refreshInspector = Studio.RefreshInspector
function Studio:RefreshInspector()
  refreshInspector(self)
  local p, id = self.inspector, self.session and self.session.selected
  if not (p and id) then return end
  if not rawget(p, "grow") then
    p:SetHeight(780)
    p.growTitle = Kit.Section(p, "Grows (module setting, applies now)")
    p.growTitle:SetPoint("TOPLEFT", 18, -672)
    p.grow = {}
    for i = 1, 2 do
      local b = Kit.Button(p, "", 140, nil, "secondary")
      b:SetPoint("TOPLEFT", 18 + (i - 1) * 148, -694)
      p.grow[i] = b
    end
  end
  local keys = Studio.GrowKeys(id)
  p.growTitle:SetShown(#keys > 0)
  for i, b in ipairs(p.grow) do
    local k = keys[i]
    if k then
      b:SetLabel(shortLabel(k) .. ": " .. valueLabel(Schema:Def(k), Schema:Get(k)))
      b:SetScript("OnClick", function() Schema:Set(k, Studio.NextGrow(k)); Studio:RefreshInspector() end)
      b:Show()
    else
      b:Hide()
    end
  end
end

-- Template thumbnails ---------------------------------------------------------------------
-- Pure: thumbnail rects { l, b, w, h } (0..1 of the screen) of a saved template.
function Studio.ThumbRects(t)
  local out = {}
  local W, H = t.W or UIParent:GetWidth(), t.H or UIParent:GetHeight()
  if not (W and H and W > 0 and H > 0) then return out end
  local pos = t.positions or {}
  local merged = setmetatable({}, { __index = function(_, k) return pos[k] end })
  for id in pairs(pos) do
    if Layout:Element(id) then
      local r = Layout:Rect(id, merged, W, H)
      if r then out[#out + 1] = { id = id, l = r.l / W, b = r.b / H, w = r.w / W, h = r.h / H } end
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end
local THUMB_W, THUMB_H = 112, 63
function Studio:DrawThumbnails()
  local p = self.layouts
  if not p then return 0 end
  p.thumbs = rawget(p, "thumbs") or {}
  local names = Studio.Templates()
  local all = Schema:Get("studio.templates")
  for i = 1, 4 do
    local f = p.thumbs[i]
    if not f then
      f = CreateFrame("Button", nil, p)
      f:SetSize(THUMB_W, THUMB_H + 16)
      f:SetPoint("TOPLEFT", 18 + (i - 1) * (THUMB_W + 12), -420)
      f.bg = f:CreateTexture(nil, "BACKGROUND")
      f.bg:SetPoint("TOPLEFT"); f.bg:SetSize(THUMB_W, THUMB_H)
      f.bg:SetColorTexture(0.06, 0.07, 0.09, 1)
      f.name = Kit.Text(f, "small", "text.secondary")
      f.name:SetPoint("BOTTOMLEFT", 0, 0)
      f.name:SetWidth(THUMB_W)
      f.cells = {}
      p.thumbs[i] = f
    end
    local name = names[i]
    if name then
      local rects = Studio.ThumbRects(all[name])
      for k, r in ipairs(rects) do
        local c = f.cells[k]
        if not c then c = f:CreateTexture(nil, "ARTWORK"); Theme:Paint(c, "accent", 0.55); f.cells[k] = c end
        c:ClearAllPoints()
        c:SetPoint("BOTTOMLEFT", f.bg, "BOTTOMLEFT", r.l * THUMB_W, r.b * THUMB_H)
        c:SetSize(math.max(1, r.w * THUMB_W), math.max(1, r.h * THUMB_H))
        c:Show()
      end
      for k = #rects + 1, #f.cells do f.cells[k]:Hide() end
      f.name:SetText(name)
      f.template = name
      f:SetScript("OnClick", function()
        Studio.ApplyTemplate(Studio.session, name); Studio:PlaceAll(); Studio:RefreshButtons()
        p.say("Applied '" .. name .. "' (scaled to your screen). Undo reverts it.")
      end)
      f:Show()
    else
      f:Hide()
    end
  end
  return math.min(4, #names)
end

-- ElvUI import -----------------------------------------------------------------------------
function Studio:ImportElvUI()
  local p = self.layouts
  local plan, why = PUI.Movers.Import.ElvUI()
  if not plan then p.say(why, "err"); return false end
  local ok = Studio.ApplyPlan(self.session, { positions = plan.positions, blizzard = {}, invalid = {} })
  self:ApplyFilter(); self:PlaceAll(); self:RefreshButtons()
  p.say(string.format("ElvUI profile %s: %d Phoenix elements previewed, %d ElvUI movers have no Phoenix match. Save & exit keeps them.",
    plan.profile, plan.count, #plan.skipped))
  return ok, plan
end

local buildLayouts = Studio.BuildLayoutsPanel
function Studio:BuildLayoutsPanel(o)
  buildLayouts(self, o)
  local p = self.layouts
  p:SetHeight(560)
  p.elvui = Kit.Button(p, "Import from ElvUI", 180, function() Studio:ImportElvUI() end, "secondary")
  p.elvui:SetPoint("TOPLEFT", p.moveany, "BOTTOMLEFT", 0, -8)
  Kit.Section(p, "Saved layouts (click to apply)"):SetPoint("TOPLEFT", 18, -446)
  for _, f in ipairs(rawget(p, "thumbs") or {}) do f:Hide() end
  p.thumbs = {}
  local base = Studio.DrawThumbnails
  self.DrawThumbnails = function(s)
    local n = base(s)
    for i, f in ipairs(p.thumbs) do f:ClearAllPoints(); f:SetPoint("TOPLEFT", 18 + (i - 1) * (THUMB_W + 12), -468) end
    return n
  end
  p:HookScript("OnShow", function() Studio:DrawThumbnails() end)
end
local saveTemplate = Studio.SaveTemplate
function Studio.SaveTemplate(session, name)
  local ok, why = saveTemplate(session, name)
  if ok and Studio.layouts and Studio.layouts:IsShown() then Studio:DrawThumbnails() end
  return ok, why
end
