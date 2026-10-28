local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group frame indicators (plan 5.2, 15.3 "Buff/Debuff Manager", mockup 03):
--   * aura icons through the one aura engine (PUI.Auras on Blizzard's
--     CustomAuraContainer): debuffs, buffs and a big centre defensive, each
--     with its own filter, count, size and corner; the lockout preset hides
--     Sated / Exhaustion-type debuffs (shared list PUI.Auras.LOCKOUTS);
--   * corner indicators (Buff Manager): spells you care about as small
--     coloured squares in a corner ("TOPLEFT:774:mine:3DDC97"), with healer
--     presets per class. Honest note: in restricted content the game may hide
--     whether a non-whitelisted aura is present; then the square stays off;
--   * private-aura anchors (boss mechanics the game draws itself);
--   * enemy target dots from PUI.Targeting (shared with Arena frames).
local _, ns = ...
local Auras = PUI.Auras
local OWNER = "RaidFrames"
local I = {}
ns.Indicators = I

I.KINDS = { "debuffs", "buffs", "defensive" }
I.POINTS = { "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT", "CENTER", "LEFT", "RIGHT" }
I.POINT_LABELS = { BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right", TOPLEFT = "Top left", TOPRIGHT = "Top right",
  CENTER = "Centre", LEFT = "Left edge", RIGHT = "Right edge", TOP = "Top", BOTTOM = "Bottom" }
I.FILTERS = {
  debuffs = { "raid", "all", "dispellable", "important", "cc" },
  buffs = { "mine", "mineAll", "raid", "external", "defensive" },
  defensive = { "big", "bigExternal" },
}
I.FILTER_LABELS = { raid = "Boss and role debuffs (raid frame rules)", all = "All", dispellable = "Only ones I can dispel",
  important = "Important", cc = "Crowd control", mine = "My heals and buffs (in combat rules)", mineAll = "All of mine",
  external = "External defensives", defensive = "Big defensives", big = "Big defensives", bigExternal = "Big and external defensives" }
local FILTER_TOKENS = {
  debuffs = { raid = "HARMFUL|RAID_IN_COMBAT", all = "HARMFUL", dispellable = "HARMFUL|RAID_PLAYER_DISPELLABLE",
    important = "HARMFUL|IMPORTANT", cc = "HARMFUL|CROWD_CONTROL" },
  buffs = { mine = "HELPFUL|PLAYER|RAID_IN_COMBAT", mineAll = "HELPFUL|PLAYER", raid = "HELPFUL|RAID",
    external = "HELPFUL|EXTERNAL_DEFENSIVE", defensive = "HELPFUL|BIG_DEFENSIVE" },
  defensive = { big = "HELPFUL|BIG_DEFENSIVE", bigExternal = "HELPFUL|BIG_DEFENSIVE" },
}
function I.FilterFor(kind, choice)
  local t = FILTER_TOKENS[kind]
  return Auras.Filter(t[choice] or t[I.FILTERS[kind][1]])
end

-- Holder: a fixed-size frame we own; the engine container anchors inside it (G36).
local function holder(o, kind)
  o.holders = o.holders or {}
  local h = o.holders[kind]
  if not h then
    h = PUI:CreateFrame("Frame", nil, o.layer, nil, OWNER)
    o.holders[kind] = h
  end
  return h
end

local GROW = { BOTTOMLEFT = { "RIGHT", "UP" }, BOTTOMRIGHT = { "LEFT", "UP" }, TOPLEFT = { "RIGHT", "DOWN" },
  TOPRIGHT = { "LEFT", "DOWN" }, CENTER = { "RIGHT", "DOWN" }, LEFT = { "LEFT", "DOWN" }, RIGHT = { "RIGHT", "DOWN" } }
-- LEFT / RIGHT sit outside the frame edge; corners and centre sit inside.
local function place(o, kind, a)
  local h = holder(o, kind)
  local n = math.max(1, a.max)
  local w = n * (a.size + 1) - 1
  h:SetSize(kind == "defensive" and a.size or w, a.size)
  h:ClearAllPoints()
  local p = a.point
  if p == "LEFT" then h:SetPoint("RIGHT", o.content, "LEFT", -2, 0)
  elseif p == "RIGHT" then h:SetPoint("LEFT", o.content, "RIGHT", 2, 0)
  elseif p == "CENTER" then h:SetPoint("CENTER", o.content, "CENTER", 0, 0)
  else
    local x = p:find("LEFT") and 2 or -2
    local y = p:find("TOP") and -2 or 2
    if p:find("BOTTOM") and o.showPower then y = y + (o.power:GetHeight() or 0) + 1 end
    h:SetPoint(p, o.content, p, x, y)
  end
  return h
end

function I.SetupAuras(o, s)
  o.auras = o.auras or {}
  for _, kind in ipairs(I.KINDS) do
    local a = s.auras[kind]
    local on = a.enabled and a.max > 0 and o.unit ~= nil
    local handle = o.auras[kind]
    local groups = { { key = kind, filter = I.FilterFor(kind, a.filter), max = on and a.max or 0, enabled = on,
      sort = kind == "debuffs" and "unitFrameDebuff" or (kind == "defensive" and "bigDefensive" or "expiration") } }
    if kind == "defensive" then
      groups[2] = { key = "external", filter = Auras.Filter("HELPFUL|EXTERNAL_DEFENSIVE"),
        max = (on and a.filter == "bigExternal") and a.max or 0, enabled = on and a.filter == "bigExternal", sort = "bigDefensive" }
    end
    if on then
      local frame = place(o, kind, a)
      frame:Show()
      local g = GROW[a.point] or GROW.BOTTOMLEFT
      local layout = { anchor = a.point == "CENTER" and "CENTER" or ((g[2] == "UP" and "BOTTOM" or "TOP") .. (g[1] == "LEFT" and "RIGHT" or "LEFT")),
        growX = g[1], growY = g[2], padding = 1, lineSize = a.max, size = a.size }
      if not handle then
        handle = Auras:Create(OWNER, frame, o.unit, layout)
        o.auras[kind] = handle
      else
        handle:SetLayout(layout)
        handle:SetUnit(o.unit)
      end
      if handle.container then handle.container:ClearAllPoints(); handle.container:SetPoint(layout.anchor, frame, layout.anchor) end
      handle:Configure(groups)
      handle:SetExclusions(s.lockouts and kind == "debuffs" and Auras.LOCKOUTS or {})
      if handle.container then handle.container:Show() end
    elseif handle then
      handle:Configure(groups)
      if handle.container then handle.container:Hide() end
      if o.holders and o.holders[kind] then o.holders[kind]:Hide() end
    end
  end
end

function I.OffAuras(o)
  for kind, handle in pairs(o.auras or {}) do
    local groups = { { key = kind, filter = I.FilterFor(kind, I.FILTERS[kind][1]), enabled = false } }
    if kind == "defensive" then groups[2] = { key = "external", filter = Auras.Filter("HELPFUL|EXTERNAL_DEFENSIVE"), enabled = false } end
    handle:Configure(groups)
    if handle.container then handle.container:Hide() end
  end
end

------------------------------------------------------------------------------
-- Corner indicators: "POINT:spellID[:mine|any][:RRGGBB]".
I.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "LEFT", "RIGHT" }
local CORNER_SET = {}
for _, p in ipairs(I.CORNERS) do CORNER_SET[p] = true end
I.PALETTE = { "3DDC97", "F4C46A", "5AB4FF", "B07CFF", "FF7A1A", "FF5468", "1FC8B0", "ECE8E2" }

function I.ParseCorner(text)
  if type(text) ~= "string" then return nil, "not text" end
  local point, id, who, hex = text:match("^%s*(%u+)%s*:%s*(%d+)%s*:?%s*(%a*)%s*:?%s*(%x*)%s*$")
  if not point then return nil, "use CORNER:spellID[:mine|any][:RRGGBB]" end
  if not CORNER_SET[point] then return nil, "unknown corner " .. point end
  if who ~= "" and who ~= "mine" and who ~= "any" then return nil, "who must be mine or any" end
  if hex ~= "" and #hex ~= 6 then return nil, "colour must be 6 hex digits" end
  return { point = point, id = tonumber(id), mine = who ~= "any", hex = hex ~= "" and hex or nil }
end
function I.ValidateCorner(text)
  local e, why = I.ParseCorner(text)
  if not e then return false, why end
  return true
end
function I.CornerLabel(text)
  local e = I.ParseCorner(text)
  if not e then return text end
  local name = C_Spell.GetSpellName(e.id) or ("spell " .. e.id)
  return string.format("%s  -  %s%s", I.POINT_LABELS[e.point] or e.point, name, e.mine and " (yours)" or " (anyone's)")
end

-- Healer presets by class token (spell IDs; verify each tier in game).
I.PRESETS = {
  DRUID = { "TOPLEFT:774:mine", "TOPRIGHT:33763:mine", "BOTTOMLEFT:8936:mine", "BOTTOMRIGHT:48438:mine" },
  PRIEST = { "TOPLEFT:17:mine", "TOPRIGHT:139:mine", "BOTTOMLEFT:194384:mine", "BOTTOMRIGHT:41635:mine" },
  SHAMAN = { "TOPLEFT:61295:mine", "TOPRIGHT:974:mine" },
  PALADIN = { "TOPLEFT:53563:mine", "TOPRIGHT:156910:mine", "BOTTOMLEFT:287280:mine" },
  MONK = { "TOPLEFT:119611:mine", "TOPRIGHT:124682:mine", "BOTTOMLEFT:115175:mine" },
  EVOKER = { "TOPLEFT:366155:mine", "TOPRIGHT:364343:mine", "BOTTOMLEFT:355941:mine" },
}
function I.PresetFor(class) return I.PRESETS[class] end

local function hexRGB(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- Builds the squares for the current list (shared by all buttons).
function I.CompileCorners(list)
  local out, perPoint = {}, {}
  for i, text in ipairs(list or {}) do
    local e = I.ParseCorner(text)
    if e then
      perPoint[e.point] = (perPoint[e.point] or 0) + 1
      e.slot = perPoint[e.point]
      e.name = C_Spell.GetSpellName(e.id)
      e.rgb = { hexRGB(e.hex or I.PALETTE[((i - 1) % #I.PALETTE) + 1]) }
      out[#out + 1] = e
    end
  end
  return out
end

local function cornerSquare(o, i)
  local sq = o.corners[i]
  if not sq then
    sq = o.layer:CreateTexture(nil, "OVERLAY", nil, 5)
    sq.edge = o.layer:CreateTexture(nil, "OVERLAY", nil, 4)
    sq.edge:SetColorTexture(0, 0, 0, 1)
    o.corners[i] = sq
  end
  return sq
end

function I.LayoutCorners(o, s)
  local size = s.cornerSize or 7
  local list = ns.RF and ns.RF.corners or {}
  for i, e in ipairs(list) do
    local sq = cornerSquare(o, i)
    sq:SetSize(size, size)
    sq:ClearAllPoints()
    local dx = (e.point:find("RIGHT") and -1 or 1) * ((e.slot - 1) * (size + 1) + 2)
    local dy = (e.point:find("TOP") and -2) or (e.point:find("BOTTOM") and 2) or 0
    if e.point == "TOP" or e.point == "BOTTOM" then dx = (e.slot - 1) * (size + 1) end
    if e.point:find("BOTTOM") and o.showPower then dy = dy + (o.power:GetHeight() or 0) + 1 end
    sq:SetPoint(e.point, o.content, e.point, dx, dy)
    sq.edge:SetPoint("TOPLEFT", sq, "TOPLEFT", -1, 1)
    sq.edge:SetPoint("BOTTOMRIGHT", sq, "BOTTOMRIGHT", 1, -1)
    sq:SetColorTexture(e.rgb[1], e.rgb[2], e.rgb[3], 1)
  end
  for i = #list + 1, #o.corners do o.corners[i]:Hide(); o.corners[i].edge:Hide() end
end

function I.UpdateCorners(o, s)
  local list = ns.RF and ns.RF.corners or {}
  for i, e in ipairs(list) do
    local sq = cornerSquare(o, i)
    local aura
    if o.unit then
      if e.mine and e.name then aura = C_UnitAuras.GetAuraDataBySpellName(o.unit, e.name, "HELPFUL|PLAYER")
      elseif not e.mine then aura = C_UnitAuras.GetUnitAuraBySpellID(o.unit, e.id) end
    end
    local on = type(aura) ~= "nil"
    sq:SetShown(on); sq.edge:SetShown(on)
  end
end

------------------------------------------------------------------------------
-- Private auras: anchors the engine fills itself; we never see their data.
function I.ClearPrivate(o)
  for i = #o.privateAnchors, 1, -1 do
    Auras:RemovePrivateAnchor(o.privateAnchors[i])
    o.privateAnchors[i] = nil
  end
end

function I.UpdatePrivate(o, s)
  I.ClearPrivate(o)
  if s.privateAuras <= 0 or not o.unit then return end
  local size = s.privateSize > 0 and s.privateSize or math.max(10, math.floor((o.height or s.height or 44) * 0.45))
  local p = s.privatePoint
  local grow = p:find("RIGHT") and -1 or 1
  for i = 1, s.privateAuras do
    local id = Auras:AddPrivateAnchor(OWNER, o.layer, o.unit, { index = i, size = size, point = p, relativePoint = p,
      x = (p == "CENTER" and (i - (s.privateAuras + 1) / 2) * (size + 1)) or grow * (2 + (i - 1) * (size + 1)),
      y = p:find("TOP") and -2 or (p:find("BOTTOM") and 2 or 0),
      showCountdown = true, showNumbers = s.privateNumbers, showDispel = s.privateDispel })
    if id ~= nil then o.privateAnchors[#o.privateAnchors + 1] = id end
  end
end

------------------------------------------------------------------------------
-- Enemy target dots (PUI.Targeting).
function I.PaintDots(o, s)
  if not (s.targetDots and o.unit) then
    for _, d in ipairs(o.dots) do d:Hide() end
    return
  end
  PUI.Targeting:Paint(o.dots, o.unit, { arena = true, boss = s.targetDotsBoss })
end
