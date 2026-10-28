local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for module pages (mockups 02/03). Each builder draws test
-- data into the page's preview card with the current bar texture, fonts and
-- accent; Update re-draws on any setting change while the page is open.
-- Display only: nothing here touches protected frames or secret values.
local Options, Theme = PUI.Options, PUI.Theme
local Schema, Kit, A = PUI.Schema, Options.Kit, Options.Assets
local Model = Options.Model
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

-- Unit frames: test frames drawn from the same look table the real frames use
-- (UnitFrames' Styles.Resolve), so the preview never disagrees with the game.
local GOLD = { 0.85, 0.68, 0.3 }
local function ufLook()
  local UF = PUI.UnitFrames
  if UF and UF.Styles and UF.settings then
    local s = UF.settings
    return UF.Styles.Resolve(s.style, { border = s.border, borderColor = s.borderColor, background = s.background,
      power = s.powerStyle, shape = s.portraitShape, edge = s.edge == "look" and nil or s.edge, colorMode = s.colorMode })
  end
  return { border = "thick", borderPx = 2, borderColor = "black", bgAlpha = 0.85, power = "attached", portrait = "3d",
    shape = "square", powerRatio = 0.22, gap = 1, edge = true }
end

local function edgeColor(look, r, g, b)
  if look.borderColor == "class" then return r, g, b end
  if look.borderColor == "accent" then return Theme:Color("accent") end
  if look.borderColor == "gold" then return GOLD[1], GOLD[2], GOLD[3] end
  return 0, 0, 0
end

local function unitFrame(card, y, name, pct, hostile, look)
  local f = st(card).uf and st(card).uf[name]
  if not f then
    f = CreateFrame("Frame", nil, card)
    f.body = f:CreateTexture(nil, "BACKGROUND")
    f.hp = bar(f, 300, 40)
    f.pp = bar(f, 300, 10)
    f.portrait = f:CreateTexture(nil, "ARTWORK")
    f.pframe = Theme:Slice(f, A.border1, 4, "OVERLAY")
    f.border = Theme:Slice(f, A.border1, 4, "OVERLAY")
    f.accent = f:CreateTexture(nil, "OVERLAY")
    f.name = Kit.Text(f.hp, "label", "text.primary", "OVERLAY")
    f.name:SetPoint("LEFT", 10, 0)
    f.val = Kit.Text(f.hp, "mono", "text.primary", "OVERLAY")
    f.val:SetPoint("RIGHT", -10, 0)
    st(card).uf = st(card).uf or {}
    st(card).uf[name] = f
  end
  local w, h = 300, 54
  local ph = math.max(4, math.floor(h * (look.powerRatio or 0.22) + 0.5))
  local floating = look.power == "floating"
  local inset = look.power == "inset"
  local hh = (inset or floating) and h or (h - ph - (look.gap or 1))
  f:SetSize(w, h)
  f:ClearAllPoints()
  f:SetPoint("TOP", hostile and 40 or -40, y)
  f.body:SetAllPoints()
  f.body:SetColorTexture(0.04, 0.04, 0.05, look.bgAlpha or 0.85)
  f.hp:SetSize(w, hh)
  f.hp:ClearAllPoints()
  f.hp:SetPoint("TOPLEFT")
  f.pp:SetSize(inset and (w - 24) or (floating and (w - 40) or w), ph)
  f.pp:ClearAllPoints()
  if inset then f.pp:SetPoint("BOTTOM", f.hp, "BOTTOM", 0, 4)
  elseif floating then f.pp:SetPoint("TOP", f, "BOTTOM", 0, ph / 2)
  else f.pp:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -(look.gap or 1)) end
  local r, g, b = classRGB()
  if hostile then r, g, b = 0.85, 0.22, 0.25 end
  if get("uf.darkMode", false) then
    paintBar(f.hp, pct, 0.16, 0.16, 0.18)
  elseif look.colorMode == "gradient" and not hostile then
    paintBar(f.hp, pct, 0.3 + (1 - pct / 100) * 0.6, 0.85 * pct / 100 + 0.1, 0.2)
  else
    paintBar(f.hp, pct, r, g, b)
  end
  paintBar(f.pp, 72, 0.25, 0.55, 1)
  local er, eg, eb = edgeColor(look, r, g, b)
  f.border:SetShown((look.borderPx or 0) > 0)
  f.border:SetVertexColor(er, eg, eb, look.border == "glow" and 0.6 or 1)
  f.accent:SetShown(look.edge == true)
  f.accent:ClearAllPoints()
  f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("BOTTOMLEFT")
  f.accent:SetWidth(2)
  f.accent:SetColorTexture(Theme:Color("accent"))
  -- portrait beside the frame, the side a real frame would use
  local showP = look.portrait ~= "off"
  f.portrait:SetShown(showP)
  f.pframe:SetShown(showP and (look.borderPx or 0) > 0)
  if showP then
    f.portrait:ClearAllPoints()
    f.portrait:SetSize(h, h)
    if hostile then f.portrait:SetPoint("LEFT", f, "RIGHT", 3, 0) else f.portrait:SetPoint("RIGHT", f, "LEFT", -3, 0) end
    if look.portrait == "class" then f.portrait:SetTexture(A.Icon and A.Icon("unitframes") or A.border1)
    else f.portrait:SetColorTexture(r * 0.35, g * 0.35, b * 0.35, 1) end
    f.pframe:ClearAllPoints()
    f.pframe:SetAllPoints(f.portrait)
    f.pframe:SetVertexColor(er, eg, eb, 1)
  end
  f.name:SetText(name)
  f.val:SetText(pct .. "%")
  f:Show()
  return f
end

local function auraRow(card, anchor, n, debuff)
  st(card).icons = st(card).icons or {}
  for i = 1, 8 do
    local id = (debuff and "uf.d" or "uf.b") .. i
    local ic = st(card).icons[id]
    if not ic then
      ic = CreateFrame("Frame", nil, card)
      ic.tex = ic:CreateTexture(nil, "ARTWORK")
      ic.tex:SetAllPoints()
      ic.edge = Theme:Slice(ic, A.border1, 4, "OVERLAY")
      st(card).icons[id] = ic
    end
    if i <= n then
      ic:SetSize(22, 22)
      ic:ClearAllPoints()
      ic:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i - 1) * 24, debuff and -6 or -32)
      ic.tex:SetColorTexture(debuff and 0.5 or 0.2, debuff and 0.12 or 0.35, debuff and 0.5 or 0.25, 1)
      ic.edge:SetVertexColor(debuff and 0.75 or 0, debuff and 0.2 or 0, debuff and 0.85 or 0, 1)
      ic:Show()
    else
      ic:Hide()
    end
  end
end

-- Buttons under the preview: test frames (all groups shown in place) and
-- "Copy settings from..." on a frame tab.
local function note(card, text, kind)
  local n = st(card).note
  if not n then
    n = Kit.Text(card, "small", "muted", "OVERLAY")
    n:SetPoint("BOTTOMLEFT", 18, 50)
    st(card).note = n
  end
  n:SetText(text or "")
  Theme:Paint(n, kind == "err" and "err" or (kind == "warn" and "warn" or "ok"), 1, "text")
end

local function ufTools(card, tab)
  local UF = PUI.UnitFrames
  local s = st(card)
  if not s.testBtn then
    s.testBtn = Kit.Button(card, "Show test frames", 150, function()
      if not (UF and UF.active) then note(card, "Turn Unit Frames on first.", "warn") return end
      local ok, why = UF.SetTestMode(not UF.test)
      if not ok then note(card, "Test frames: " .. tostring(why), "err") end
      Previews.Update("UnitFrames", card)
    end, "secondary")
    s.testBtn:SetPoint("BOTTOMLEFT", 16, 14)
    s.copyBtn = Kit.Button(card, "Copy settings from...", 170, nil, "secondary")
    s.copyBtn:SetPoint("LEFT", s.testBtn, "RIGHT", 8, 0)
  end
  s.testBtn:SetText(UF and UF.test and "Hide test frames" or "Show test frames")
  s.testBtn:Show()
  local isGroup = UF and UF.GROUPS and UF.GROUPS[tab] ~= nil
  s.copyBtn:SetShown(isGroup)
  if isGroup then
    local list = {}
    for _, g in ipairs(UF.ORDER) do if g ~= tab then list[#list + 1] = g end end
    s.copyBtn:SetScript("OnClick", function(btn)
      Options.Widgets.OpenMenu(btn, list, function(g) return UF.GROUPS[g].label or g end, nil, function(from)
        local n = UF.CopyGroup(from, tab)
        note(card, n .. " setting(s) copied to " .. (UF.GROUPS[tab].label or tab) .. ".", "ok")
      end)
    end)
  end
end

function Previews.UnitFrames(card, tab)
  local look = ufLook()
  unitFrame(card, -56, UnitName("player") or "Player", 86, false, look)
  local t = unitFrame(card, -150, "Training Dummy", 42, true, look)
  auraRow(card, t, 4, true)
  auraRow(card, t, 6, false)
  if not st(card).cast then
    st(card).cast = bar(card, 300, 16)
    st(card).cast.text = Kit.Text(st(card).cast, "small", "text.primary", "OVERLAY")
    st(card).cast.text:SetPoint("LEFT", 8, 0)
  end
  st(card).cast:ClearAllPoints()
  st(card).cast:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -62)
  local ar, ag, ab = Theme:Color("accent")
  paintBar(st(card).cast, 64, ar, ag, ab)
  st(card).cast.text:SetText("Pyroblast  1.4")
  st(card).cast:Show()
  ufTools(card, tab)
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

-- Raid & Party (mockup 03): sample members drawn by the module's own element
-- builder and painter (RF.Elements), so the preview always matches the game.
-- The Party tab shows 5 members; raid tabs show that tier's layout (scaled
-- to fit); other tabs show the active tier. Buttons: test on screen (5 / 20 /
-- 40) and "Load heal preset" for the corner indicators.
local function rfTools(card)
  local RF = PUI.RaidFrames
  local s = st(card)
  if not s.rfTest then
    s.rfTest = {}
    local x = 16
    for _, n in ipairs({ 5, 20, 40 }) do
      local b = Kit.Button(card, "Test " .. n, 74, function()
        if not (RF and RF.active) then note(card, "Turn Raid & Party on first.", "warn") return end
        local on = not (RF.test and RF.testCount == n)
        local ok, why = RF.SetTestMode(on, n)
        if not ok then note(card, "Test mode: " .. tostring(why), "err") end
        Previews.Update("RaidFrames", card)
      end, "secondary")
      b:SetPoint("BOTTOMLEFT", x, 14)
      x = x + 80
      s.rfTest[n] = b
    end
    s.rfPreset = Kit.Button(card, "Load heal preset", 140, function()
      local _, class = UnitClass("player")
      local preset = RF and RF.Indicators.PresetFor(class)
      if not preset then note(card, "No heal preset for your class; add spells by hand.", "warn") return end
      Model.Commit("rf.corners", preset)
      note(card, #preset .. " corner indicators loaded for your class.", "ok")
    end, "secondary")
    s.rfPreset:SetPoint("BOTTOMRIGHT", -16, 14)
  end
  for n, b in pairs(s.rfTest) do
    b:SetText((RF and RF.test and RF.testCount == n) and ("Hide " .. n) or ("Test " .. n))
    b:Show()
  end
  s.rfPreset:Show()
end

function Previews.RaidFrames(card, tab)
  local RF = PUI.RaidFrames
  if not (RF and RF.Elements) then return end
  local S = RF.settings
  local tier = (tab == "party" or tab == "small" or tab == "medium" or tab == "large") and tab or RF.tier or "medium"
  local t = S.tiers[tier]
  local count = tier == "party" and 5 or (tier == "small" and 10 or 20)
  local s = st(card)
  if not s.rfHolder then
    s.rfHolder = CreateFrame("Frame", nil, card)
    s.rfHolder:SetPoint("TOPLEFT", 18, -56)
    s.rfHolder:SetSize(1, 1)
    s.rf = {}
  end
  -- Scale the whole grid to fit inside the card (384 x 250).
  local cols = math.ceil(count / t.perColumn)
  local vertical = t.orientation == "vertical"
  local w = vertical and (cols * (t.width + t.groupSpacing)) or (math.min(count, t.perColumn) * (t.width + t.spacing))
  local h = vertical and (math.min(count, t.perColumn) * (t.height + t.spacing)) or (cols * (t.height + t.groupSpacing))
  local scale = math.min(1, 384 / math.max(1, w), 250 / math.max(1, h))
  s.rfHolder:SetScale(scale)
  s.rfHolder:Show()
  for i = 1, math.max(count, #s.rf) do
    local o = s.rf[i]
    if i <= count then
      if not o then
        o = { button = CreateFrame("Frame", nil, s.rfHolder), test = true }
        RF.Elements.Build(o)
        s.rf[i] = o
      end
      o.button:SetSize(t.width, t.height)
      o.button:ClearAllPoints()
      local x, y = RF.TestPosition(i, t)
      o.button:SetPoint("TOPLEFT", s.rfHolder, "TOPLEFT", math.abs(x), -math.abs(y))
      RF.Elements.Layout(o, S, t.width, t.height)
      RF.Elements.PaintSample(o, S, i)
      o.button:Show()
    elseif o then
      o.button:Hide()
    end
  end
  rfTools(card)
end

-- Nameplates: four sample plates built by the module's own builder and
-- painter (PUI.Nameplates.Plate), so the preview always matches the game:
-- your target with arrows and forces text, a threat-coloured quest enemy
-- with the focus outline, a friendly name-only player, and a low-health
-- enemy in execute range.
function Previews.Nameplates(card)
  local NP = PUI.Nameplates
  if not (NP and NP.Plate) then return end
  local s = st(card)
  if not s.npHolder then
    s.npHolder = CreateFrame("Frame", nil, card)
    s.npHolder:SetPoint("TOPLEFT", 18, -64)
    s.npHolder:SetSize(384, 260)
    s.np = {}
  end
  s.npHolder:Show()
  local S = NP.settings
  for i = 1, #NP.Plate.SAMPLES do
    local f = s.np[i]
    if not f then
      f = NP.Plate.Build()
      f:SetParent(s.npHolder)
      s.np[i] = f
    end
    f:ClearAllPoints()
    f:SetPoint("TOP", s.npHolder, "TOP", 0, -24 - (i - 1) * 60)
    NP.Plate.PaintSample(f, S, i)
    f:Show()
  end
end

local function hideAll(card)
  for _, list in pairs({ st(card).uf or {}, st(card).icons or {}, st(card).rb or {} }) do
    for _, f in pairs(list) do f:Hide() end
  end
  if st(card).cast then st(card).cast:Hide() end
  if st(card).testBtn then st(card).testBtn:Hide(); st(card).copyBtn:Hide() end
  if st(card).rfHolder then st(card).rfHolder:Hide() end
  for _, b in pairs(st(card).rfTest or {}) do b:Hide() end
  if st(card).rfPreset then st(card).rfPreset:Hide() end
  if st(card).npHolder then st(card).npHolder:Hide() end
end

function Previews.Update(owner, card, key)
  local fn = Previews[owner]
  if type(fn) ~= "function" or owner == "Update" then return end
  hideAll(card)
  fn(card, Options.views.page and Options.views.page.tab)
end

-- wrap builders so switching page/tab always starts clean
for _, owner in ipairs({ "UnitFrames", "ActionBars", "ResourceBars", "RaidFrames", "Nameplates" }) do
  local fn = Previews[owner]
  Previews[owner] = function(card, tab) hideAll(card); fn(card, tab) end
end
