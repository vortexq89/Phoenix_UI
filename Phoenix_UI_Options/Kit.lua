local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Kit: the design-spec widget kit (section 6). Fonts by role, glass panels,
-- cards, buttons (primary/secondary/ghost), toggle, slider + value box,
-- segmented control, badge, section header, icon. Every control writes
-- through Model.Commit, so changes apply live; no OnUpdate anywhere (the
-- toggle knob animates with an AnimationGroup).
local Options, Theme, Media = PUI.Options, PUI.Theme, PUI.Media
local A = Options.Assets
local Kit = {}
Options.Kit = Kit

-- Fonts (section 3). Locale fallback for scripts Inter/Rajdhani lack.
local ROLE = {
  display = { "Rajdhani Bold", 28 }, hero = { "Rajdhani Bold", 26 }, title = { "Rajdhani Bold", 19 },
  body = { "Inter SemiBold", 13 }, text = { "Inter", 12.5 }, label = { "Inter SemiBold", 12 },
  caption = { "Inter Bold", 10.5 }, small = { "Inter", 11 }, mono = { "JetBrains Mono", 12 },
}
local FALLBACK = { koKR = "Noto Sans KR", zhCN = "Noto Sans SC", zhTW = "Noto Sans SC" }
local objects = {}

local function fontPath(name)
  local fb = FALLBACK[GetLocale()]
  if fb then name = fb end
  return Media:Path("font", name) or Media:Font(PUI.Schema:Get("media.uiFont"))
end
Kit.FontPath = fontPath

function Kit.FontObject(role)
  local o = objects[role]
  if o then return o end
  local spec = ROLE[role] or ROLE.body
  o = CreateFont("PhoenixUIKit_" .. role)
  o:SetFont(fontPath(spec[1]), spec[2], "")
  objects[role] = o
  return o
end

-- fs with a role and a colour token.
function Kit.Text(parent, role, token, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(Kit.FontObject(role))
  Theme:Paint(fs, token or "text.primary", 1, "text")
  fs:SetJustifyH("LEFT")
  return fs
end

function Kit.Icon(parent, path, size, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetSize(size, size)
  t:SetTexture(path)
  return t
end

-- Surfaces ------------------------------------------------------------------
-- Glass window: shadow, obsidian glass fill, rounded panel frame.
function Kit.Window(frame)
  local sh = Theme:Slice(frame, A.shadow, 56, "BACKGROUND", -8)
  sh:ClearAllPoints()
  sh:SetPoint("TOPLEFT", -28, 22)
  sh:SetPoint("BOTTOMRIGHT", 28, -34)
  sh:SetVertexColor(0, 0, 0, 0.85)
  local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  fill:SetPoint("TOPLEFT", 3, -3)
  fill:SetPoint("BOTTOMRIGHT", -3, 3)
  Theme:PanelFill(fill)
  frame.glassFill = fill
  local edge = Theme:Slice(frame, A.panel, 32, "BACKGROUND", -5)
  edge:SetVertexColor(0.55, 0.57, 0.64, 0.95)
  return fill
end

function Kit.Card(parent, alpha)
  local c = CreateFrame("Frame", nil, parent)
  local t = Theme:Slice(c, A.card, 28, "BACKGROUND")
  t:SetVertexColor(1, 1, 1, alpha or 1)
  c.bg = t
  return c
end

function Kit.Divider(parent, vertical)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(1, 1, 1, 0.07)
  if vertical then t:SetWidth(1) else t:SetHeight(1) end
  return t
end

-- Section header: caps caption + hairline.
function Kit.Section(parent, text)
  local fs = Kit.Text(parent, "caption", "muted")
  fs:SetText(text:upper())
  local line = Kit.Divider(parent)
  line:SetPoint("LEFT", fs, "RIGHT", 10, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
  fs.line = line
  return fs
end

-- Buttons -------------------------------------------------------------------
-- kind: "primary" (accent fill, dark text), "secondary", "ghost", "danger".
function Kit.Button(parent, text, width, onClick, kind, icon)
  kind = kind or "secondary"
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 110, 30)
  local bg = Theme:Slice(b, kind == "primary" and A.primary or A.secondary, 20)
  if kind == "primary" then Theme:Paint(bg, "accent", 1, "vertex")
  elseif kind == "ghost" then bg:SetVertexColor(1, 1, 1, 0)
  elseif kind == "danger" then Theme:Paint(bg, "err", 0.85, "vertex") end
  b.bg = bg
  b.label = Kit.Text(b, "label", kind == "primary" and "bg0" or "text.primary")
  b.label:SetJustifyH("CENTER")
  b.label:SetText(text)
  if icon then
    b.icon = Kit.Icon(b, icon, 16)
    b.icon:SetPoint("LEFT", 10, 0)
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
  else
    b.label:SetPoint("CENTER")
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 2, -2)
  hl:SetPoint("BOTTOMRIGHT", -2, 2)
  hl:SetColorTexture(1, 1, 1, 0.05)
  b:SetScript("OnClick", onClick)
  function b:SetLabel(t) self.label:SetText(t) end
  return b
end

-- Badge: 20 high pill. kind: accent, ok, warn, err, neutral.
local BADGE = { accent = "accent", ok = "ok", warn = "warn", err = "err", neutral = "muted" }
function Kit.Badge(parent, text, kind)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(20)
  local bg = Theme:Slice(f, A.control, 20)
  Theme:Paint(bg, BADGE[kind] or "muted", 0.16, "vertex")
  f.text = Kit.Text(f, "small", kind == "neutral" and "text.secondary" or (BADGE[kind] or "muted"))
  f.text:SetPoint("CENTER")
  function f:SetText(t)
    self.text:SetText(t)
    self:SetWidth(math.max(28, (self.text:GetStringWidth() or 0) + 18))
  end
  f:SetText(text)
  return f
end

-- Toggle: 38x22 track, 16 knob; on = accent track; knob slides 0.12 s.
function Kit.Toggle(parent, onChange)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(38, 22)
  local track = b:CreateTexture(nil, "ARTWORK")
  track:SetAllPoints()
  track:SetTexture(A.toggleTrack)
  local knob = b:CreateTexture(nil, "OVERLAY")
  knob:SetSize(18, 18)
  knob:SetTexture(A.knob)
  local group = b:CreateAnimationGroup()
  local move = group:CreateAnimation("Translation")
  move:SetDuration(0.12)
  move:SetSmoothing("OUT")
  b.track, b.knob, b.anim, b.move = track, knob, group, move
  local function place(on)
    knob:ClearAllPoints()
    knob:SetPoint("CENTER", b, on and "RIGHT" or "LEFT", on and -11 or 11, 0)
    if on then Theme:Paint(track, "accent", 1, "vertex") else Theme:Paint(track, "line2", 1, "vertex") end
  end
  group:SetScript("OnFinished", function() place(b.value) end)
  function b:SetValue_(on, animate)
    local was = self.value
    self.value = on and true or false
    if animate and was ~= nil and was ~= self.value then
      move:SetOffset(self.value and 16 or -16, 0)
      if self.value then Theme:Paint(track, "accent", 1, "vertex") else Theme:Paint(track, "line2", 1, "vertex") end
      group:Play()
    else
      place(self.value)
    end
  end
  b:SetScript("OnClick", function(self)
    local v = not self.value
    self:SetValue_(v, true)
    if onChange then onChange(v) end
  end)
  b:SetValue_(false)
  return b
end

-- Slider with accent fill and an editable mono value box.
function Kit.Slider(parent, def, width, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 28)
  local s = CreateFrame("Slider", nil, f)
  s:SetOrientation("HORIZONTAL")
  s:SetPoint("LEFT")
  s:SetPoint("RIGHT", -72, 0)
  s:SetHeight(18)
  s:SetMinMaxValues(def.min or 0, def.max or 1)
  s:SetValueStep(def.step or 1)
  s:SetObeyStepsToValues(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  track:SetColorTexture(1, 1, 1, 0.10)
  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("LEFT")
  fill:SetHeight(4)
  Theme:Paint(fill, "accent")
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(A.knob)
  thumb:SetSize(18, 18)
  s:SetThumbTexture(thumb)
  local box = CreateFrame("EditBox", nil, f)
  box:SetSize(60, 28)
  box:SetPoint("RIGHT")
  box:SetAutoFocus(false)
  box:SetJustifyH("CENTER")
  box:SetFontObject(Kit.FontObject("mono"))
  local boxBg = Theme:Slice(box, A.control, 20)
  boxBg:SetVertexColor(0.06, 0.07, 0.09, 1)
  f.slider, f.fill, f.box = s, fill, box
  local function sync(value)
    local lo, hi = def.min or 0, def.max or 1
    local w = s:GetWidth() or 0
    local frac = (hi > lo) and (value - lo) / (hi - lo) or 0
    fill:SetWidth(math.max(1, w * frac))
    box:SetText(PUI.Options.Model.Format(def, value) .. (def.unit and (" " .. def.unit) or ""))
  end
  s:SetScript("OnValueChanged", function(_, value, user)
    sync(value)
    if user and onChange then onChange(value) end
  end)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(_, delta) if onChange then onChange(s:GetValue() + delta * (def.step or 1)) end end)
  box:SetScript("OnEnterPressed", function(self)
    local v = tonumber((self:GetText() or ""):match("[-%d%.]+"))
    self:ClearFocus()
    if v and onChange then onChange(v) else sync(s:GetValue()) end
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); sync(s:GetValue()) end)
  function f:SetValue_(value)
    s:SetValue(value)
    sync(value)
  end
  return f
end

-- Segmented control: up to ~5 choices; active segment bg3.
function Kit.Segmented(parent, choices, labels, onPick)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(30)
  local bg = Theme:Slice(f, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  f.buttons = {}
  local x = 3
  for i = 1, #choices do
    local b = CreateFrame("Button", nil, f)
    b.value = choices[i]
    b.text = Kit.Text(b, "label", "text.secondary")
    b.text:SetText(labels and labels[i] or tostring(choices[i]))
    b.text:SetPoint("CENTER")
    local w = math.max(48, (b.text:GetStringWidth() or 0) + 26)
    b:SetSize(w, 24)
    b:SetPoint("LEFT", x, 0)
    x = x + w + 2
    b.sel = Theme:Slice(b, A.control, 20)
    Theme:Paint(b.sel, "bg3", 1, "vertex")
    b:SetScript("OnClick", function(self) if onPick then onPick(self.value) end end)
    f.buttons[i] = b
  end
  f:SetWidth(x + 1)
  function f:SetValue_(value)
    for _, b in ipairs(self.buttons) do
      local on = b.value == value
      b.sel:SetShown(on)
      Theme:Paint(b.text, on and "text.primary" or "muted", 1, "text")
    end
  end
  return f
end

-- Accent-gradient selection bar (sidebar active row, tabs).
function Kit.AccentBar(parent, w, h)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(w, h)
  Theme:Paint(t, "accent")
  return t
end
