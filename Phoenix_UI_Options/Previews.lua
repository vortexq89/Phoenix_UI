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
function Previews.State(card) return st(card) end -- tests read the sample widgets

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

-- Action bars (mockup 05): twelve sample buttons skinned by the module's own
-- button painter (ActionBars.Buttons.Skin/ApplyLook), so zoom, border, fonts,
-- range/power/unusable colours, cooldown numbers and the proc glow match the
-- game. Sample states: cooldown, proc, out of range, no power, unusable.
local SAMPLE_KEYS = { "1", "2", "3", "4", "5", "SHIFT-1", "CTRL-2", "BUTTON4", "MOUSEWHEELUP", "F", "ALT-Q", "NUMPAD5" }
local STATES = { [2] = "cooldown", [3] = "proc", [6] = "range", [7] = "power", [8] = "unusable", [10] = "assist" }
function Previews.ActionBars(card, tab)
  local barId = (tab and tab:match("^bar%d+$")) and tab or "bar1"
  local size = math.min(52, get("ab." .. barId .. ".size", 40) or 40)
  local perRow = math.max(1, math.min(12, get("ab." .. barId .. ".perRow", 6) or 6))
  local gap = get("ab." .. barId .. ".spacing", 2) or 2
  local AB = PUI.ActionBars
  local Btn = AB and AB.Buttons
  st(card).icons = st(card).icons or {}
  local span = perRow * (size + gap)
  for i = 1, 12 do
    local b = st(card).icons[i]
    if not b then
      b = CreateFrame("Frame", nil, card)
      if Btn then
        Btn.Skin(b)
        b.icon:SetTexture(A.abilities[i])
      else
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(A.abilities[i])
        b.hotkey = Kit.Text(b, "small", "text.primary", "OVERLAY")
        b.hotkey:SetPoint("TOPRIGHT", -3, -3)
      end
      b.sample = b:CreateFontString(nil, "OVERLAY")
      b.sample:SetFontObject(PUI.Media:FontObject("number"))
      b.sample:SetPoint("CENTER")
      st(card).icons[i] = b
    end
    b:SetSize(size, size)
    b:ClearAllPoints()
    local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
    b:SetPoint("TOPLEFT", card, "TOP", -span / 2 + col * (size + gap), -60 - row * (size + gap))
    b.sample:SetText("")
    if Btn then
      local S = Btn.S
      Btn.ApplyLook(b)
      b.icon:SetVertexColor(1, 1, 1, 1)
      b.range:SetAlpha(0)
      b.dim:SetAlpha(0)
      PUI.Glow:Stop(b)
      local state = STATES[i]
      if state == "cooldown" then
        if S.cdText then b.sample:SetText("18") end
        b.dim:SetAlpha(S.dimOnCooldown and S.dimAlpha or 0.35)
      elseif state == "proc" and S.procGlow ~= "none" then PUI.Glow:Start(b, S.procGlow, S.procColor)
      elseif state == "range" and S.rangeMode == "overlay" then b.range:SetAlpha(1)
      elseif state == "range" and S.rangeMode == "tint" then b.icon:SetVertexColor(S.rangeColor.r, S.rangeColor.g, S.rangeColor.b, 1)
      elseif state == "power" then b.icon:SetVertexColor(S.manaColor.r, S.manaColor.g, S.manaColor.b, 1)
      elseif state == "unusable" then b.icon:SetVertexColor(S.unusableColor.r, S.unusableColor.g, S.unusableColor.b, 1)
      elseif state == "assist" and S.assist then PUI.Glow:Start(b, "solid", S.assistColor) end
      b.hotkey:SetText(Btn.KeyText(SAMPLE_KEYS[i]))
    else
      b.hotkey:SetText(get("ab.hotkeys", true) and SAMPLE_KEYS[i] or "")
    end
    b:Show()
  end
  local n = st(card).abNote
  if not n then
    n = Kit.Text(card, "small", "text.secondary", "OVERLAY")
    st(card).abNote = n
  end
  n:ClearAllPoints()
  n:SetPoint("TOP", card, "TOP", 0, -70 - math.ceil(12 / perRow) * (size + gap))
  n:SetText("2 cooldown  3 proc  6 out of range  7 no power  8 unusable  10 assisted")
  n:Show()
end

-- Cooldown Manager: sample essential row with the restyle settings.
function Previews.CooldownManager(card)
  local size = math.min(52, get("cdm.essential.size", 40) or 40)
  local gap = get("cdm.essential.spacing", 2) or 2
  local zoom, px = get("cdm.zoom", 0.08) or 0.08, get("cdm.border", 1) or 1
  local bc = get("cdm.borderColor", { r = 0, g = 0, b = 0, a = 1 })
  st(card).cdm = st(card).cdm or {}
  local n = 8
  for i = 1, n do
    local b = st(card).cdm[i]
    if not b then
      b = CreateFrame("Frame", nil, card)
      b.tex = b:CreateTexture(nil, "ARTWORK")
      b.tex:SetTexture(A.abilities[i])
      b.edge = {}
      for e = 1, 4 do b.edge[e] = b:CreateTexture(nil, "OVERLAY") end
      b.num = Kit.Text(b, "body", "text.primary", "OVERLAY")
      b.num:SetPoint("CENTER")
      st(card).cdm[i] = b
    end
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", card, "TOP", -(n * (size + gap)) / 2 + (i - 1) * (size + gap), -70)
    b.tex:ClearAllPoints(); b.tex:SetAllPoints()
    b.tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    local e = b.edge
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(math.max(px, 0.01))
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(math.max(px, 0.01))
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(math.max(px, 0.01))
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(math.max(px, 0.01))
    for k = 1, 4 do e[k]:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1); e[k]:SetShown(px > 0) end
    b.num:SetText((get("cdm.cdText", true) and (i == 2 or i == 5)) and (i == 2 and "18" or "42") or "")
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
    if i == 3 then
      local cc = get("rb.cast.castColor", { r = ar, g = ag, b = ab })
      c = { cc.r, cc.g, cc.b, 40 }
    elseif i == 2 and get("rb.power.color", "power") == "class" then c = { r, g, b, 64 }
    elseif i == 2 and get("rb.power.color", "power") == "accent" then c = { ar, ag, ab, 64 } end
    paintBar(bb, c[4], c[1], c[2], c[3])
    bb:SetShown(i ~= 3 or get("rb.cast.enabled", true))
  end
  local s = st(card)
  if not s.rbCast then
    s.rbCast = Kit.Text(card, "small", "text.primary", "OVERLAY")
  end
  local castBar = s.rb[3]
  s.rbCast:ClearAllPoints()
  s.rbCast:SetPoint("LEFT", castBar, "LEFT", 6, 0)
  s.rbCast:SetText(get("rb.cast.spellName", true) and "Fireball   1.2" or "")
  s.rbCast:SetShown(castBar:IsShown())
  local pt = get("rb.power.text", "none")
  s.rbPower = s.rbPower or Kit.Text(card, "small", "text.primary", "OVERLAY")
  s.rbPower:ClearAllPoints()
  s.rbPower:SetPoint("CENTER", s.rb[2], "CENTER", 0, 0)
  s.rbPower:SetText(pt == "percent" and "64%" or pt == "value" and "64K" or pt == "both" and "64K - 64%" or "")
  s.rbPower:Show()
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


-- HUD previews (mockups 13/14): drawn by the modules' own paint functions
-- (Minimap.PlaceTexts/PaintBorder, Tooltip.UnitLines/PaintSkin, TooltipIDs.Line,
-- DataBars.PaintBar/PaintProgress) fed sample values.
local function hudHolder(card, keyName)
  local s = st(card)
  s.hud = s.hud or {}
  local h = s.hud[keyName]
  if not h then
    h = CreateFrame("Frame", nil, card)
    h:SetPoint("TOPLEFT", 18, -64)
    h:SetSize(384, 300)
    s.hud[keyName] = h
  end
  h:Show()
  return h
end

local function line(parent, list, i, role)
  local fs = list[i]
  if not fs then fs = Kit.Text(parent, role or "small", "text.primary", "OVERLAY"); list[i] = fs end
  fs:Show()
  return fs
end

function Previews.Minimap(card)
  local MM = PUI.Minimap
  if not MM then return end
  local h = hudHolder(card, "mm")
  local S = MM.settings
  local size = math.min(220, S.size)
  if not rawget(h, "map") then
    h.map = CreateFrame("Frame", nil, h)
    h.map.tex = h.map:CreateTexture(nil, "ARTWORK")
    h.map.tex:SetAllPoints()
    h.border = CreateFrame("Frame", nil, h)
    h.border.tex = h.border:CreateTexture(nil, "BACKGROUND")
    h.border.tex:SetAllPoints()
    h.texts = {}
    for _, k in ipairs({ "zone", "clock", "coords", "difficulty", "queue" }) do
      h.texts[k] = Kit.Text(h.map, "small", "text.primary", "OVERLAY")
    end
    h.bin = {}
  end
  h.map:ClearAllPoints()
  h.map:SetPoint("TOPLEFT", 8, -8)
  h.map:SetSize(size, size)
  h.map.tex:SetColorTexture(0.16, 0.22, 0.14, 1)
  h.map.tex:SetMask(MM.MASKS[S.shape])
  MM.PaintBorder(h.border, h.map, S)
  MM.PlaceTexts(h.map, h.texts, S)
  h.texts.zone:SetText("Silvermoon City"); h.texts.zone:SetShown(S.zone)
  h.texts.clock:SetText(MM.ClockText(S)); h.texts.clock:SetShown(S.clock)
  h.texts.coords:SetText("48.2, 61.7"); h.texts.coords:SetShown(S.coords)
  h.texts.difficulty:SetText(MM.DifficultyText(8, 5, 16)); h.texts.difficulty:SetShown(S.difficulty)
  h.texts.queue:ClearAllPoints()
  h.texts.queue:SetPoint("BOTTOMLEFT", h.map, "BOTTOMLEFT", 6, 22)
  h.texts.queue:SetText("0:31"); h.texts.queue:SetShown(S.queueEye)
  local Bin = PUI.ButtonBin
  if Bin then
    local bs = Bin.settings
    local cells = Bin.Grid(14, bs.columns, math.min(bs.size, 24), bs.spacing)
    for i = 1, #cells do
      local b = h.bin[i]
      if not b then b = h:CreateTexture(nil, "ARTWORK"); h.bin[i] = b end
      b:ClearAllPoints()
      b:SetSize(math.min(bs.size, 24), math.min(bs.size, 24))
      b:SetPoint("TOPLEFT", h, "TOPLEFT", cells[i].x, -size - 30 + cells[i].y + 30)
      b:SetColorTexture(0.25 + (i % 5) * 0.1, 0.3, 0.45 - (i % 3) * 0.1, 1)
      b:SetShown(bs.enabled)
    end
  end
end

function Previews.Tooltip(card)
  local TT, IDs = PUI.Tooltip, PUI.TooltipIDs
  if not (TT and IDs) then return end
  local h = hudHolder(card, "tt")
  local S = TT.settings
  if not rawget(h, "tip") then
    h.tip = CreateFrame("Frame", nil, h)
    h.tip:SetPoint("TOPLEFT", 8, -8)
    h.tip:SetSize(300, 160)
    h.skin = TT.SkinFrame(h.tip)
    h.lines = {}
  end
  h.tip:SetScale(S.scale)
  TT.PaintSkin(h.skin, S.qualityBorder and 0.64 or nil, S.qualityBorder and 0.21 or nil, S.qualityBorder and 0.93 or nil)
  h.skin:SetShown(S.skin)
  for _, fs in ipairs(h.lines) do fs:Hide() end
  local rows = { { "Vex <Phoenix Rising>", S.classNames and 0.25 or 1, S.classNames and 0.78 or 1, S.classNames and 0.92 or 1 } }
  for _, l in ipairs(TT.UnitLines(TT.SAMPLE_UNIT)) do rows[#rows + 1] = l end
  if S.forces then rows[#rows + 1] = { "Enemy forces  4 (0.96%)", 1, 0.82, 0 } end
  if IDs.enabled then
    for _, kind in ipairs({ "spell", "icon", "npc" }) do
      if IDs.settings.kinds[kind] then rows[#rows + 1] = { IDs.Line(kind, kind == "spell" and { 12294, 1265418 } or { kind == "icon" and 132355 or 221986 }), 1, 1, 1 } end
    end
  end
  local y = -8
  for i, r in ipairs(rows) do
    local fs = line(h.tip, h.lines, i, i == 1 and "label" or "small")
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", h.tip, "TOPLEFT", 10, y)
    fs:SetText(r[1])
    fs:SetTextColor(r[2] or 1, r[3] or 1, r[4] or 1)
    y = y - 16
  end
  h.tip:SetHeight(-y + 10)
  h.rows = rows
end

function Previews.DataBars(card)
  local DB = PUI.DataBars
  if not DB then return end
  local h = hudHolder(card, "db")
  h.bars = rawget(h, "bars") or {}
  local y = -8
  for i, c in ipairs(DB.cfg) do
    local list = DB.Parse(c.blocks)
    local b = h.bars[i]
    if not b then b = CreateFrame("Frame", nil, h); h.bars[i] = b end
    if #list > 0 then
      local copy = {}
      for k, v in pairs(c) do copy[k] = v end
      copy.fill = false
      copy.width = math.min(368, c.width)
      DB.PaintBar(b, list, copy, true)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", h, "TOPLEFT", 8, y)
      b:Show()
      y = y - c.height - 8
    else
      b:Hide()
    end
  end
  if not rawget(h, "pb") then
    h.pb = CreateFrame("StatusBar", nil, h)
    h.pb.rested = h.pb:CreateTexture(nil, "ARTWORK")
    h.pb.text = Kit.Text(h.pb, "small", "text.primary", "OVERLAY")
    h.pb.text:SetPoint("CENTER")
  end
  local P = DB.progress
  h.pb:ClearAllPoints()
  h.pb:SetPoint("TOPLEFT", h, "TOPLEFT", 8, y - 4)
  DB.PaintProgress(h.pb, P.mode == "auto" and "xp" or P.mode, 640, 1000, 40)
  h.pb:SetWidth(math.min(368, P.width))
  h.pb:SetShown(P.enabled)
end

-- Chat: sample lines run through the module's own text helpers with the
-- current settings (timestamps, channel names, links, emoji, keywords, panel).
function Previews.Chat(card)
  local CH = PUI.Chat
  if not CH then return end
  local T, S = CH.Text, CH.settings
  local h = hudHolder(card, "chat")
  if not rawget(h, "panel") then
    h.panel = h:CreateTexture(nil, "BACKGROUND")
    h.panel:SetPoint("TOPLEFT", 4, -4)
    h.panel:SetSize(376, 190)
    h.lines = {}
  end
  local c = S.panelColor
  local style = CH.STYLES[S.style] or CH.STYLES.phoenix
  h.panel:SetColorTexture(c.r, c.g, c.b, math.max(0.08, style.bg * S.panelAlpha))
  local kw = T.ParseKeywords(S.keywords ~= "" and S.keywords or "summon")
  local fmt = CH.STAMPS[S.timestamps]
  local stamp = fmt and ("|cff" .. CH.Hex(S.stampColor, "8a8a8a") .. "19:42|r ") or ""
  local samples = {
    "[" .. T.ShortChannel("2. Trade - City", S.channelNames) .. "] Thrall: WTS key +12, see raider.io/x :star:",
    "[Party] Liadrin: need a summon please :healer:",
    "|cffe0a0ffVex whispers:|r you still need a tank? :tank:",
    "|cff8a8a8aBattleground: 6 joined, 2 left|r",
  }
  for i, text in ipairs(samples) do
    local out = text
    if S.urls then out = T.LinkURLs(out, CH.Hex(S.urlColor, "4fb3ff")) end
    if S.emoji then out = T.ReplaceEmoji(out, S.emojiSize) end
    if S.keywordHighlight then out = T.Highlight(out, kw, CH.Hex(S.keywordColor, "ffd24a")) end
    local fs = line(h, h.lines, i, "body")
    local path = CH.FontPath()
    if path then fs:SetFont(path, S.fontSize, S.outline == "none" and "" or S.outline) end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 4 + S.padding + 6, -(10 + (i - 1) * (S.fontSize + 10)))
    fs:SetWidth(360)
    fs:SetJustifyH("LEFT")
    fs:SetText(stamp .. out)
    fs:SetAlpha((S.idleFade > 0 and i == 1) and math.max(S.fadeAlpha, 0.3) or 1)
  end
  local n = line(h, h.lines, #samples + 1, "small")
  n:ClearAllPoints()
  n:SetPoint("TOPLEFT", 8, -204)
  n:SetText("Window 1 is placed with Edit Mode. The voice transcription window is never changed.")
end

-- Vault: sample items grouped by the real rules engine with your rules,
-- pins and hidden categories; borders use the same quality colours.
function Previews.Vault(card)
  local VA = PUI.Vault
  if not VA or not VA.Context then return end
  local S = VA.settings
  local R = VA.Rules
  local h = hudHolder(card, "vault")
  h.tiles = rawget(h, "tiles") or {}
  h.heads = rawget(h, "heads") or {}
  local sample = {
    { id = 1, quality = 4, classID = 4, ilvl = 645, name = "Helm", sets = { "PvP" } }, { id = 2, quality = 3, classID = 2, ilvl = 639, name = "Blade" },
    { id = 3, quality = 1, classID = 0, name = "Flask" }, { id = 4, quality = 1, classID = 0, name = "Feast" },
    { id = 5, quality = 2, classID = 7, name = "Ore" }, { id = 6, quality = 2, classID = 7, name = "Herb" },
    { id = 7, quality = 4, keystone = true, name = "Keystone" }, { id = 8, quality = 0, classID = 15, name = "Grey" },
  }
  local entries = {}
  for _, f in ipairs(sample) do entries[#entries + 1] = { facts = f } end
  local ctx = VA.Context()
  ctx.rules = ctx.rules or {}
  local sections = R.Group(entries, ctx)
  local size = math.min(32, S.view == "compact" and S.compactSize or S.slotSize)
  local y, ti = 8, 0
  for i, sec in ipairs(sections) do
    local head = line(h, h.heads, i, "small")
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", 8, -y)
    head:SetText(S.view == "category" and (sec.label:upper() .. "  " .. #sec.items) or "")
    if S.view == "category" then y = y + 16 end
    for k, e in ipairs(sec.items) do
      ti = ti + 1
      local tile = h.tiles[ti]
      if not tile then
        tile = CreateFrame("Frame", nil, h)
        tile.fill = tile:CreateTexture(nil, "ARTWORK"); tile.fill:SetAllPoints()
        tile.edge = Theme:Slice(tile, A.border1, 4, "OVERLAY")
        h.tiles[ti] = tile
      end
      local col = S.view == "category" and 0 or (ti - 1)
      tile:ClearAllPoints()
      tile:SetSize(size, size)
      tile:SetPoint("TOPLEFT", 8 + ((S.view == "category" and (k - 1) or (col % S.columns)) * (size + S.gap)), -y)
      tile.fill:SetColorTexture(0.18 + e.facts.id * 0.04, 0.2, 0.26, 1)
      local r, g, b = VA.QualityColor(e.facts.quality)
      tile.edge:SetVertexColor(r or 0, g or 0, b or 0, (S.qualityBorder and (e.facts.quality or 0) >= S.qualityMin and r) and 1 or 0.3)
      tile:Show()
    end
    if S.view == "category" then y = y + size + S.gap + 6 end
  end
  for i = ti + 1, #h.tiles do h.tiles[i]:Hide() end
  for i = #sections + 1, #h.heads do h.heads[i]:Hide() end
end

-- Shared row helper for the step 8c previews: a pooled bar with left/right text.
local function meterRow(h, i)
  h.mrows = rawget(h, "mrows") or {}
  local r = h.mrows[i]
  if not r then
    r = bar(h, 300, 16)
    r.l = Kit.Text(r, "small", "text.primary", "OVERLAY"); r.l:SetPoint("LEFT", 4, 0)
    r.r = Kit.Text(r, "small", "text.primary", "OVERLAY"); r.r:SetPoint("RIGHT", -4, 0)
    h.mrows[i] = r
  end
  r:Show()
  return r
end
local function hideFrom(list, n) for i = n + 1, #(list or {}) do list[i]:Hide() end end

-- Embers: sample fight drawn with the module's own number format, look,
-- pinned own row (you are 15th) and best-pull marker.
function Previews.Embers(card)
  local EM = PUI.Embers
  if not EM then return end
  local S = EM.settings
  local h = hudHolder(card, "embers")
  local sample = { { "Thrall", "SHAMAN", 1.42e6 }, { "Liadrin", "PALADIN", 1.38e6 }, { "Vex", "MAGE", 1.21e6 }, { "Nyx", "ROGUE", 1.05e6 },
    { "Durotan", "WARRIOR", 0.98e6 }, { "Jaina", "MAGE", 0.91e6 }, { "Anduin", "PRIEST", 0.85e6 }, { "Tyrande", "PRIEST", 0.8e6 } }
  local data, total = {}, 0
  for i, x in ipairs(sample) do data[i] = { name = x[1], class = x[2], value = x[3], rank = i }; total = total + x[3] end
  for i = #sample + 1, 15 do data[i] = { name = "Raider " .. i, class = "HUNTER", value = 0.5e6 - i * 1e4, rank = i } end
  data[15] = { name = "You", class = "MAGE", value = 0.41e6, rank = 15, me = true }
  local look = (EM.Window and EM.Window.LOOKS or {})[S.look] or { bar = true, alphaScale = 1, heightScale = 1 }
  local shown = math.min(S.rows, 10)
  local visible = PUI.Embers and EM.Window and EM.Window.Visible(data, shown, S.pinSelf) or data
  h.head = rawget(h, "head") or Kit.Text(h, "small", "text.primary", "OVERLAY")
  h.head:ClearAllPoints(); h.head:SetPoint("TOPLEFT", 4, -2)
  h.head:SetText((S.header and ("Damage - Current" .. (S.headerTimer and "   3:42" or "") .. (S.compareBest and "   best 1.02M/s" or ""))) or "")
  local rh = math.max(10, math.floor(S.rowHeight * (look.heightScale or 1) + 0.5))
  local ar, ag, ab = Theme:Color("accent")
  local n = 0
  for i = 1, shown do
    local d = visible[i]
    if d then
      n = i
      local r = meterRow(h, i)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 4, -18 - (i - 1) * (rh + S.spacing))
      r:SetSize(math.min(370, S.width), rh)
      local cr, cg, cb = ar, ag, ab
      if S.classColors then cr, cg, cb = EM.ClassColor(d.class) end
      paintBar(r, d.value / sample[1][3] * 100, cr, cg, cb)
      r:SetStatusBarColor(cr, cg, cb, look.bar and S.barAlpha * (look.alphaScale or 1) or 0)
      r.l:SetText((S.showRank and (d.rank .. ". ") or "") .. d.name)
      r.r:SetText(EM.FormatNumber(d.value) .. (S.showPercent and string.format("  %.0f%%", d.value / total * 100) or ""))
    end
  end
  hideFrom(h.mrows, n)
  st(card).embersRows = n
end

-- Ascent: a sample key at 18:42 of 33:00 with forces, pace and splits, using
-- the module's own threshold and pace maths.
function Previews.Ascent(card)
  local AS = PUI.Ascent
  if not AS then return end
  local S = AS.settings
  local h = hudHolder(card, "ascent")
  h.lines = rawget(h, "lines") or {}
  local elapsed, limit, pct = 1122, 1980, 78.4
  local t = AS.Thresholds(limit)
  local pace = AS.Pace(elapsed, limit, pct)
  local out = {
    "Ara-Kara +12   Xal'atath's Bargain, Tyrannical, Fortified",
    AS.Clock(elapsed, S.timerFormat) .. " / " .. AS.Clock(limit) .. "   +3 " .. AS.Clock(math.max(0, t[1] - elapsed)) .. "   +2 " .. AS.Clock(t[2] - elapsed),
    "Enemy forces " .. (S.forcesFormat == "count" and "312/398" or S.forcesFormat == "percent" and "78.4%" or "78.4% (312/398)"),
  }
  if S.pace and AS.Display then out[#out + 1] = AS.Display.PaceText(pace, elapsed, limit) end
  if S.splits then out[#out + 1] = "+ Avanoxx 4:31  -0:22 vs best" end
  out[#out + 1] = "Deaths 2 (-0:10)" .. (S.brLust and S.brLustPlacement == "block" and "   BR 1   Lust ready" or "")
  if S.kicks then out[#out + 1] = "Kicks  Thrall 6   Zinn 4" end
  for i, text in ipairs(out) do
    local fs = line(h, h.lines, i, i == 2 and "header" or "small")
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 6, -4 - (i - 1) * 18)
    fs:SetText(text)
  end
  hideFrom(h.lines, #out)
  st(card).ascentLines = #out
end

-- Quest Tracker: sample quests through the tracker's own colour helpers.
function Previews.QuestTracker(card)
  local QT = PUI.QuestTracker
  if not QT then return end
  local S = QT.settings
  local h = hudHolder(card, "qt")
  h.lines = rawget(h, "lines") or {}
  local rows = {}
  local ar, ag, ab = Theme:Color("accent")
  if S.mplusBlock then rows[#rows + 1] = { "Ara-Kara +12   18:42 / 33:00", ar, ag, ab } end
  rows[#rows + 1] = { "- CAMPAIGN  2", ar, ag, ab }
  rows[#rows + 1] = { (S.showLevel and "[80] " or "") .. "> The Voidspire Accord", 1, 0.82, 0 }
  rows[#rows + 1] = { "   Seal the breach 2/3", QT.ProgressColor("2/3") }
  rows[#rows + 1] = { "   Gather shards 1/7", QT.ProgressColor("1/7") }
  if S.completed ~= "hide" then
    local r, g, b = Theme:Color("success")
    if S.completed == "fade" then r, g, b = r * 0.6, g * 0.6, b * 0.6 end
    rows[#rows + 1] = { "Hunting Wyrms  (turn in)", r, g, b }
  end
  for i, x in ipairs(rows) do
    local fs = line(h, h.lines, i, "body")
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 6, -4 - (i - 1) * (S.fontSize + S.rowSpacing + 2))
    fs:SetText(x[1])
    fs:SetTextColor(x[2], x[3], x[4])
  end
  hideFrom(h.lines, #rows)
  st(card).qtLines = #rows
end

-- Reminders: sample icons per group with the current size, spacing and names.
function Previews.Reminders(card)
  local RM = PUI.Reminders
  if not RM then return end
  local S = RM.settings
  local h = hudHolder(card, "rm")
  h.icons = rawget(h, "icons") or {}
  local sample = {}
  if S.raid then sample[#sample + 1] = { 135932, "Arcane Intellect" } end
  if S.class then sample[#sample + 1] = { 132273, "Lethal poison" } end
  if S.pet then sample[#sample + 1] = { 136218, "Summon your pet" } end
  for _, c in ipairs(RM.ParseCustom(S.customList)) do sample[#sample + 1] = { C_Spell.GetSpellTexture(c.any[1]), c.label or "Custom" } end
  local size = math.min(S.size, 48)
  for i, x in ipairs(sample) do
    if i > 8 then break end
    local ic = h.icons[i]
    if not ic then
      ic = CreateFrame("Frame", nil, h)
      ic.tex = ic:CreateTexture(nil, "ARTWORK"); ic.tex:SetAllPoints()
      ic.label = Kit.Text(ic, "small", "text.primary", "OVERLAY"); ic.label:SetPoint("TOP", ic, "BOTTOM", 0, -2)
      h.icons[i] = ic
    end
    ic:ClearAllPoints()
    ic:SetSize(size, size)
    ic:SetPoint("TOPLEFT", 8 + (i - 1) * (size + S.spacing + 30), -10)
    ic.tex:SetTexture(x[1])
    ic.label:SetText(S.text and x[2] or "")
    ic:Show()
  end
  hideFrom(h.icons, math.min(8, #sample))
  st(card).rmIcons = math.min(8, #sample)
end

local function hideAll(card)
  for _, list in pairs({ st(card).uf or {}, st(card).icons or {}, st(card).rb or {}, st(card).cdm or {} }) do
    for _, f in pairs(list) do f:Hide() end
  end
  if st(card).cast then st(card).cast:Hide() end
  if st(card).abNote then st(card).abNote:Hide() end
  if st(card).rbCast then st(card).rbCast:Hide() end
  if st(card).rbPower then st(card).rbPower:Hide() end
  if st(card).testBtn then st(card).testBtn:Hide(); st(card).copyBtn:Hide() end
  if st(card).rfHolder then st(card).rfHolder:Hide() end
  for _, b in pairs(st(card).rfTest or {}) do b:Hide() end
  if st(card).rfPreset then st(card).rfPreset:Hide() end
  if st(card).npHolder then st(card).npHolder:Hide() end
  for _, h in pairs(st(card).hud or {}) do h:Hide() end
end

function Previews.Update(owner, card, key)
  local fn = Previews[owner]
  if type(fn) ~= "function" or owner == "Update" then return end
  hideAll(card)
  fn(card, Options.views.page and Options.views.page.tab)
end

-- wrap builders so switching page/tab always starts clean
for _, owner in ipairs({ "UnitFrames", "ActionBars", "ResourceBars", "RaidFrames", "Nameplates", "CooldownManager", "Minimap", "Tooltip", "DataBars", "Chat", "Vault",
  "Embers", "Ascent", "QuestTracker", "Reminders" }) do
  local fn = Previews[owner]
  Previews[owner] = function(card, tab) hideAll(card); fn(card, tab) end
end
