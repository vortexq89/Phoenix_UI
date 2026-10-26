local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for module pages (mockups 02/03). Each builder draws test
-- data into the page's preview card with the current bar texture, fonts and
-- accent; Update re-draws on any setting change while the page is open.
-- Display only: nothing here touches protected frames or secret values.
local Options, Theme = PUI.Options, PUI.Theme
local Schema, Kit, A = PUI.Schema, Options.Kit, Options.Assets
local Previews = {}
local state = setmetatable({}, { __mode = "k" }) -- card -> { uf, icons, rb, cast }
local function st(card) state[card] = state[card] or {}; return state[card] end
Options.Previews = Previews

local function get(key, fallback)
  if Schema:Def(key) then return Schema:Get(key) end
  return fallback
end

local function bar(card, w, h)
  local b = CreateFrame("StatusBar", nil, card)
  b:SetSize(w, h)
  b:SetMinMaxValues(0, 100)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.edge = Theme:Slice(b, A.border1, 4, "OVERLAY")
  b.edge:SetVertexColor(0, 0, 0, 0.9)
  return b
end

local function paintBar(b, value, r, g, bl)
  local tex = PUI.Bars:TexturePath()
  b:SetStatusBarTexture(tex)
  b:SetStatusBarColor(r, g, bl, 1)
  b.bg:SetTexture(tex)
  b.bg:SetVertexColor(r * 0.25, g * 0.25, bl * 0.25, PUI.Bars.backgroundAlpha or 0.6)
  b:SetValue(value)
end

local function classRGB()
  local _, class = UnitClass("player")
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.24, 0.86, 0.59
end

-- Unit frames: player + target test frames with health, power and a cast bar.
local function unitFrame(card, y, name, pct, hostile)
  local f = st(card).uf and st(card).uf[name]
  if not f then
    f = CreateFrame("Frame", nil, card)
    f:SetSize(300, 64)
    f.hp = bar(f, 300, 40)
    f.hp:SetPoint("TOP")
    f.pp = bar(f, 300, 10)
    f.pp:SetPoint("TOP", f.hp, "BOTTOM", 0, -3)
    f.name = Kit.Text(f.hp, "label", "text.primary", "OVERLAY")
    f.name:SetPoint("LEFT", 10, 0)
    f.val = Kit.Text(f.hp, "mono", "text.primary", "OVERLAY")
    f.val:SetPoint("RIGHT", -10, 0)
    st(card).uf = st(card).uf or {}
    st(card).uf[name] = f
  end
  f:SetPoint("TOP", 0, y)
  local r, g, b = classRGB()
  if hostile then r, g, b = 0.85, 0.22, 0.25 end
  if get("uf.colorMode", "class") ~= "class" and not hostile then r, g, b = 0.24, 0.86, 0.59 end
  paintBar(f.hp, pct, r, g, b)
  paintBar(f.pp, 72, 0.25, 0.55, 1)
  f.name:SetText(name)
  f.val:SetText(pct .. "%")
  f:Show()
  return f
end

function Previews.UnitFrames(card)
  unitFrame(card, -60, UnitName("player") or "Player", 86, false)
  local t = unitFrame(card, -150, "Training Dummy", 42, true)
  if not st(card).cast then
    st(card).cast = bar(card, 300, 16)
    st(card).cast.text = Kit.Text(st(card).cast, "small", "text.primary", "OVERLAY")
    st(card).cast.text:SetPoint("LEFT", 8, 0)
  end
  st(card).cast:SetPoint("TOP", t, "BOTTOM", 0, -12)
  local ar, ag, ab = Theme:Color("accent")
  paintBar(st(card).cast, 64, ar, ag, ab)
  st(card).cast.text:SetText("Pyroblast  1.4")
  st(card).cast:Show()
end

-- Action bars: 12 ability icons, size and per-row from bar 1 settings.
function Previews.ActionBars(card, tab)
  local barId = (tab and tab:match("^bar%d+$")) and tab or "bar1"
  local size = math.min(52, get("ab." .. barId .. ".size", 40) or 40)
  local perRow = math.max(1, math.min(12, get("ab." .. barId .. ".perRow", 6) or 6))
  st(card).icons = st(card).icons or {}
  local span = perRow * (size + 4)
  for i = 1, 12 do
    local b = st(card).icons[i]
    if not b then
      b = CreateFrame("Frame", nil, card)
      b.tex = b:CreateTexture(nil, "ARTWORK")
      b.tex:SetPoint("TOPLEFT", 1, -1)
      b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
      b.tex:SetTexture(A.abilities[i])
      b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      b.edge = Theme:Slice(b, A.border1, 4, "OVERLAY")
      b.edge:SetVertexColor(0, 0, 0, 1)
      b.key = Kit.Text(b, "small", "text.primary", "OVERLAY")
      b.key:SetPoint("TOPRIGHT", -3, -3)
      st(card).icons[i] = b
    end
    b:SetSize(size, size)
    b:ClearAllPoints()
    local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
    b:SetPoint("TOPLEFT", card, "TOP", -span / 2 + col * (size + 4), -60 - row * (size + 4))
    b.key:SetText(get("ab.hotkeys", true) and tostring(i % 10) or "")
    b:Show()
  end
end

-- Resource bars: health, power and cast stacked at the configured width.
function Previews.ResourceBars(card)
  local w = math.min(360, get("rb.width", 260) or 260)
  st(card).rb = st(card).rb or { bar(card, w, 18), bar(card, w, 12), bar(card, w, 14) }
  local r, g, b = classRGB()
  local ar, ag, ab = Theme:Color("accent")
  local colours = { { r, g, b, 78 }, { 0.25, 0.55, 1, 64 }, { ar, ag, ab, 40 } }
  local y = -70
  for i, bb in ipairs(st(card).rb) do
    bb:SetWidth(w)
    bb:ClearAllPoints()
    bb:SetPoint("TOP", 0, y)
    y = y - bb:GetHeight() - (get("rb.spacing", 4) or 4)
    local c = colours[i]
    paintBar(bb, c[4], c[1], c[2], c[3])
    bb:SetShown(i ~= 3 or get("rb.cast.enabled", true))
  end
end

local function hideAll(card)
  for _, list in pairs({ st(card).uf or {}, st(card).icons or {}, st(card).rb or {} }) do
    for _, f in pairs(list) do f:Hide() end
  end
  if st(card).cast then st(card).cast:Hide() end
end

function Previews.Update(owner, card, key)
  local fn = Previews[owner]
  if type(fn) ~= "function" or owner == "Update" then return end
  hideAll(card)
  fn(card, Options.views.page and Options.views.page.tab)
end

-- wrap builders so switching page/tab always starts clean
for _, owner in ipairs({ "UnitFrames", "ActionBars", "ResourceBars" }) do
  local fn = Previews[owner]
  Previews[owner] = function(card, tab) hideAll(card); fn(card, tab) end
end
