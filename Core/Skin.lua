local _, ns = ...

--[[ ns.Skin — the only place that turns theme tokens into regions.
    State for every skinned object lives in weak side tables (never as fields on Blizzard frames),
    originals are recorded so Restore() can undo a skin when a module is disabled. ]]
local Sk = {}
ns.Skin = Sk
local Theme, Media = ns.Theme, ns.Media
local WHITE = Media.textures.WHITE

local state = setmetatable({}, { __mode = "k" })      -- obj -> our regions
local originals = setmetatable({}, { __mode = "k" })  -- obj -> recorded Blizzard values
local registry = setmetatable({}, { __mode = "k" })   -- obj -> reapply fn (theme changes)

local function st(obj)
    local s = state[obj]
    if not s then s = {}; state[obj] = s end
    return s
end

local function px(region, n)
    return PixelUtil.ConvertPixelsToUIForRegion(n or 1, region)
end

-- Re-run fn(obj) now and whenever the theme or UI scale changes.
function Sk:Register(obj, fn)
    registry[obj] = fn
    fn(obj)
end

local function reapplyAll()
    for obj, fn in pairs(registry) do ns.SafeCall(fn, obj) end
end
ns.Events:Listen("PUI_THEME_CHANGED", Sk, reapplyAll)
ns.Events:On("UI_SCALE_CHANGED", Sk, reapplyAll)
ns.Events:On("DISPLAY_SIZE_CHANGED", Sk, reapplyAll)

---------------------------------------------------------------- borders
local SIDES = { "top", "bottom", "left", "right" }

function Sk:Border(frame, token, size, layer)
    local s = st(frame)
    local b = s.border
    if not b then
        b = {}
        for _, side in ipairs(SIDES) do
            local t = frame:CreateTexture(nil, layer or "BORDER", nil, 7)
            t:SetTexture(WHITE)
            b[side] = t
        end
        s.border = b
    end
    local thick = px(frame, size or 1)
    b.top:ClearAllPoints(); b.top:SetPoint("TOPLEFT"); b.top:SetPoint("TOPRIGHT"); b.top:SetHeight(thick)
    b.bottom:ClearAllPoints(); b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT"); b.bottom:SetHeight(thick)
    b.left:ClearAllPoints(); b.left:SetPoint("TOPLEFT"); b.left:SetPoint("BOTTOMLEFT"); b.left:SetWidth(thick)
    b.right:ClearAllPoints(); b.right:SetPoint("TOPRIGHT"); b.right:SetPoint("BOTTOMRIGHT"); b.right:SetWidth(thick)
    self:SetBorderColor(frame, token or "border.subtle")
    for _, side in ipairs(SIDES) do b[side]:Show() end
    return b
end

function Sk:SetBorderColor(frame, token, ...)
    local b = state[frame] and state[frame].border
    if not b then return end
    local r, g, bl, a
    if type(token) == "number" then r, g, bl, a = token, ... else r, g, bl, a = Theme:Color(token) end
    for _, side in ipairs(SIDES) do b[side]:SetVertexColor(r, g, bl, a or 1) end
end

---------------------------------------------------------------- panels
-- style: "base" | "raised" | "sunken" | "hover" | "overlay"; opts: { border, shadow, sheen, inset }
function Sk:Panel(frame, style, opts)
    opts = opts or {}
    local s = st(frame)
    if not s.bg then
        s.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        s.bg:SetTexture(WHITE)
    end
    local inset = opts.inset or 0
    s.bg:ClearAllPoints()
    s.bg:SetPoint("TOPLEFT", inset, -inset)
    s.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    s.bg:SetVertexColor(Theme:Color("bg." .. (style or "base")))
    s.bg:Show()
    if opts.border ~= false then self:Border(frame, opts.border or "border.subtle") end
    if opts.sheen then
        if not s.sheen then
            s.sheen = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
            s.sheen:SetTexture(Media.textures.FADE_V)
        end
        s.sheen:ClearAllPoints()
        s.sheen:SetPoint("TOPLEFT", px(frame), -px(frame))
        s.sheen:SetPoint("TOPRIGHT", -px(frame), -px(frame))
        s.sheen:SetHeight(opts.sheen == true and 24 or opts.sheen)
        s.sheen:SetVertexColor(1, 1, 1, 0.035)
        s.sheen:Show()
    end
    if opts.shadow then self:Shadow(frame, opts.shadow == true and 10 or opts.shadow) end
    return s.bg
end

function Sk:SetPanelColor(frame, token)
    local s = state[frame]
    if s and s.bg then s.bg:SetVertexColor(Theme:Color(token)) end
end

---------------------------------------------------------------- 9-slice soft shadow / glow
local SLICE = { -- texture is 64x64 with 16px corners
    { "TOPLEFT", 0, 0.25, 0, 0.25 }, { "TOP", 0.25, 0.75, 0, 0.25 }, { "TOPRIGHT", 0.75, 1, 0, 0.25 },
    { "LEFT", 0, 0.25, 0.25, 0.75 }, { "RIGHT", 0.75, 1, 0.25, 0.75 },
    { "BOTTOMLEFT", 0, 0.25, 0.75, 1 }, { "BOTTOM", 0.25, 0.75, 0.75, 1 }, { "BOTTOMRIGHT", 0.75, 1, 0.75, 1 },
}

local function nineSlice(frame, slot, file, size, r, g, b, a)
    local s = st(frame)
    local sh = s[slot]
    if not sh then
        sh = {}
        for i, def in ipairs(SLICE) do
            local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
            t:SetTexCoord(def[2], def[3], def[4], def[5])
            sh[i] = t
        end
        s[slot] = sh
    end
    local o = size
    for i = 1, 8 do sh[i]:SetTexture(file); sh[i]:ClearAllPoints() end
    sh[1]:SetPoint("TOPLEFT", -o, o);                 sh[1]:SetSize(o, o)
    sh[3]:SetPoint("TOPRIGHT", o, o);                 sh[3]:SetSize(o, o)
    sh[6]:SetPoint("BOTTOMLEFT", -o, -o);             sh[6]:SetSize(o, o)
    sh[8]:SetPoint("BOTTOMRIGHT", o, -o);             sh[8]:SetSize(o, o)
    sh[2]:SetPoint("TOPLEFT", sh[1], "TOPRIGHT");     sh[2]:SetPoint("BOTTOMRIGHT", sh[3], "BOTTOMLEFT")
    sh[7]:SetPoint("TOPLEFT", sh[6], "TOPRIGHT");     sh[7]:SetPoint("BOTTOMRIGHT", sh[8], "BOTTOMLEFT")
    sh[4]:SetPoint("TOPLEFT", sh[1], "BOTTOMLEFT");   sh[4]:SetPoint("BOTTOMRIGHT", sh[6], "TOPRIGHT")
    sh[5]:SetPoint("TOPLEFT", sh[3], "BOTTOMLEFT");   sh[5]:SetPoint("BOTTOMRIGHT", sh[8], "TOPRIGHT")
    for i = 1, 8 do sh[i]:SetVertexColor(r, g, b, a); sh[i]:Show() end
end

local function hideSlices(frame, slot)
    local s = state[frame]
    if s and s[slot] then for i = 1, 8 do s[slot][i]:Hide() end end
end

function Sk:Shadow(frame, size, token, alpha)
    local r, g, b = 0, 0, 0
    if token then r, g, b = Theme:Color(token) end
    nineSlice(frame, "shadow", Media.textures.SHADOW, size or 10, r, g, b, alpha or 0.6)
end

-- Coloured outer glow; kind: "Soft" | "Tight" | "Wide" (Core/TextureData.lua).
function Sk:Glow(frame, size, kind, r, g, b, a)
    nineSlice(frame, "glow", Media:Glow(kind), size or 8, r, g, b, a or 0.9)
end

function Sk:HideGlow(frame) hideSlices(frame, "glow") end

function Sk:HideShadow(frame) hideSlices(frame, "shadow") end

---------------------------------------------------------------- gradients
--[[ A shading gradient over a status bar's fill: an overlay pinned to the fill texture, black at one end and
    clear at the other, so it follows the fill and works whatever colour (even a secret one) the bar carries.
    mode: "none" | "HORIZONTAL" (darker at the start of the fill) | "VERTICAL" (darker at the bottom). ]]
function Sk:FillGradient(bar, mode, strength)
    local s = st(bar)
    if mode ~= "HORIZONTAL" and mode ~= "VERTICAL" then
        if s.fillShade then s.fillShade:Hide() end
        return
    end
    if not s.fillShade then
        s.fillShade = bar:CreateTexture(nil, "ARTWORK", nil, 7)
        s.fillShade:SetTexture(WHITE)
    end
    local fill = bar:GetStatusBarTexture()
    s.fillShade:ClearAllPoints()
    if fill then s.fillShade:SetAllPoints(fill) else s.fillShade:SetAllPoints(bar) end
    local a = strength or 0.45
    if mode == "HORIZONTAL" then
        s.fillShade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, a), CreateColor(0, 0, 0, 0))
    else
        s.fillShade:SetGradient("VERTICAL", CreateColor(0, 0, 0, a), CreateColor(0, 0, 0, 0))
    end
    s.fillShade:Show()
end

function Sk:Gradient(tex, orientation, tokenA, tokenB, alphaA, alphaB)
    local r1, g1, b1, a1 = Theme:Color(tokenA)
    local r2, g2, b2, a2 = Theme:Color(tokenB)
    tex:SetGradient(orientation, CreateColor(r1, g1, b1, alphaA or a1), CreateColor(r2, g2, b2, alphaB or a2))
end

---------------------------------------------------------------- text
local function recordFont(fs)
    if originals[fs] then return end
    local path, osize, oflags = fs:GetFont()
    local r, g, b, a = fs:GetTextColor()
    originals[fs] = { font = { path, osize, oflags }, fontObject = fs.GetFontObject and fs:GetFontObject(), color = { r, g, b, a } }
end

function Sk:Text(fs, role, colorToken, size, flags)
    recordFont(fs)
    local path, rsize, rflags = Theme:Font(role, size)
    -- Phoenix's own interface text never goes under 12 (user text specs are left alone: see TextSpec)
    fs:SetFont(path, math.max(12, rsize), flags or rflags)
    if flags == nil and rflags == "" then
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(1, -1)
    end
    if colorToken then fs:SetTextColor(Theme:Color(colorToken)) end
end

---------------------------------------------------------------- style specs
--[[ Specs are the saved shapes built by ns.Style (Core/Style.lua) and edited by the options. Modules and
    the option previews both style through these, so a preview is drawn by the same code as the real frame.
    A spec colour of false means "the theme token passed by the caller". ]]
local OUTLINES = { NONE = "", OUTLINE = "OUTLINE", THICK = "THICKOUTLINE", MONO = "OUTLINE, MONOCHROME" }
Sk.OUTLINES = OUTLINES

-- color: { r, g, b[, a] } | { token = "class" } (the player's class colour, kept live) | false (the caller's token)
function Sk:SpecColor(color, token)
    if type(color) == "table" then
        if color.token == "class" then
            local _, classFile = UnitClass("player")
            local r, g, b = ns.Util.ClassColor(classFile)
            return r, g, b, color.a or 1
        end
        return color.r or 1, color.g or 1, color.b or 1, color.a or 1
    end
    return Theme:Color(token or "text.primary")
end

-- spec: { font = key|"", size, outline = NONE|OUTLINE|THICK|MONO, shadow = bool, color = {r,g,b}|false }
function Sk:TextSpec(fs, spec, role, token)
    recordFont(fs)
    local path, size = Theme:Font(role or "unit", spec.size)
    if spec.font and spec.font ~= "" then path = Media:Font(spec.font) end
    fs:SetFont(path, size, OUTLINES[spec.outline] or "")
    if spec.shadow then
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowColor(0, 0, 0, 0)
        fs:SetShadowOffset(0, 0)
    end
    -- no token and no picked colour: the element keeps the colour its owner gives it (reaction, class …)
    if type(spec.color) == "table" or token then fs:SetTextColor(self:SpecColor(spec.color, token)) end
end

local JUSTIFY = { LEFT = "LEFT", TOPLEFT = "LEFT", BOTTOMLEFT = "LEFT", RIGHT = "RIGHT", TOPRIGHT = "RIGHT", BOTTOMRIGHT = "RIGHT" }

-- spec: { anchor = "CENTER"|"LEFT"|..., x, y }. Only for FontStrings we created ourselves.
function Sk:Place(fs, parent, spec)
    local anchor = spec.anchor or "CENTER"
    local inset = (JUSTIFY[anchor] == "LEFT" and 4) or (JUSTIFY[anchor] == "RIGHT" and -4) or 0
    fs:ClearAllPoints()
    fs:SetPoint(anchor, parent, anchor, inset + (spec.x or 0), spec.y or 0)
    fs:SetJustifyH(JUSTIFY[anchor] or "CENTER")
end

--[[ The style library: one spec drives every module's borders, shadows and backdrops (Core/Style.lua).
    border spec: { style, size = px, color = {r,g,b,a}|{token="class"}|false, shadow = "auto"|"none"|"soft"|"hard"|"glow",
      shadowSize = px (0 = sized from the border) }
      theme   follow Appearance & General (theme.borderStyle, theme.borderSize)
      none    nothing                       pixel   exactly one physical pixel, whatever the size
      solid   size px lines                 thick   double weight (min 2 px)
      inset   lines plus a faint inner highlight, for a pressed-in look
      shadow  lines plus a soft drop shadow glow    tinted outer glow, no lines
      ember   accent lines plus an accent glow (the Phoenix signature)
    Shadows use their own slices, so a glow and a shadow can be worn together. ]]
local function hideLines(s, key)
    if s and s[key] then for _, side in ipairs(SIDES) do s[key][side]:Hide() end end
end

local function inner(frame, thick, r, g, b, a)
    local s = st(frame)
    local t = s.inner
    if not t then
        t = {}
        for _, side in ipairs(SIDES) do
            local tex = frame:CreateTexture(nil, "BORDER", nil, 6)
            tex:SetTexture(WHITE)
            t[side] = tex
        end
        s.inner = t
    end
    local one = px(frame, 1)
    t.top:ClearAllPoints(); t.top:SetPoint("TOPLEFT", thick, -thick); t.top:SetPoint("TOPRIGHT", -thick, -thick); t.top:SetHeight(one)
    t.bottom:ClearAllPoints(); t.bottom:SetPoint("BOTTOMLEFT", thick, thick); t.bottom:SetPoint("BOTTOMRIGHT", -thick, thick)
    t.bottom:SetHeight(one)
    t.left:ClearAllPoints(); t.left:SetPoint("TOPLEFT", thick, -thick); t.left:SetPoint("BOTTOMLEFT", thick, thick); t.left:SetWidth(one)
    t.right:ClearAllPoints(); t.right:SetPoint("TOPRIGHT", -thick, -thick); t.right:SetPoint("BOTTOMRIGHT", -thick, thick)
    t.right:SetWidth(one)
    for _, side in ipairs(SIDES) do t[side]:SetVertexColor(r, g, b, a); t[side]:Show() end
end

-- The style and size a spec draws with ("theme" resolved through Appearance & General).
function Sk:ResolveBorder(spec)
    local style, size = spec.style or "solid", spec.size or 1
    if style == "theme" then
        local t = Theme.settings
        style, size = t.borderStyle or "solid", t.borderSize or size
        if style == "theme" then style = "solid" end
    end
    return style, size
end

local function shadowOf(style, shadow)
    if shadow and shadow ~= "auto" then return shadow end
    return style == "shadow" and "soft" or "none"
end

function Sk:BorderSpec(frame, spec, token)
    local style, size = self:ResolveBorder(spec)
    local r, g, b, a = self:SpecColor(spec.color, token or "border.black")
    local s = state[frame]
    hideLines(s, "inner")
    if style == "none" or style == "glow" then
        hideLines(s, "border")
    else
        local thick = (style == "pixel" and 1) or (style == "thick" and math.max(2, size * 2)) or size
        self:Border(frame, nil, thick)
        if style == "ember" and type(spec.color) ~= "table" then
            self:SetBorderColor(frame, "accent.primary")
        else
            self:SetBorderColor(frame, r, g, b, a)
        end
        if style == "inset" then inner(frame, px(frame, thick), 1, 1, 1, 0.08) end
    end
    if style == "glow" then
        self:Glow(frame, 4 + size * 3, "Tight", r, g, b, a)
    elseif style == "ember" then
        local gr, gg, gb = Theme:Color("accent.glow")
        self:Glow(frame, 6 + size * 3, "Soft", gr, gg, gb, 0.85)
    else
        self:HideGlow(frame)
    end
    local kind = shadowOf(style, spec.shadow)
    local depth = Theme.settings.shadowAlpha or 0.75
    local fixed = type(spec.shadowSize) == "number" and spec.shadowSize > 0 and spec.shadowSize or nil
    if kind == "soft" then
        self:Shadow(frame, fixed or 6 + size * 3, nil, depth)
    elseif kind == "hard" then
        nineSlice(frame, "shadow", Media:Glow("Tight"), fixed or 3 + size * 2, 0, 0, 0, math.min(1, depth + 0.2))
    elseif kind == "glow" then
        local gr, gg, gb = Theme:Color("accent.glow")
        nineSlice(frame, "shadow", Media:Glow("Wide"), fixed or 8 + size * 3, gr, gg, gb, 0.7)
    else
        self:HideShadow(frame)
    end
end

-- spec: { alpha = 0..1, color = {r,g,b}|false, style = "solid"|"gradient"|"glass" }; drawn under everything on frame.
function Sk:Backdrop(frame, spec, token)
    local s = st(frame)
    if not s.backdrop then
        s.backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        s.backdrop:SetTexture(WHITE)
        s.backdrop:SetAllPoints()
    end
    local r, g, b = self:SpecColor(spec.color, token or "bg.sunken")
    local alpha = spec.alpha or 0.6
    local style = spec.style or "solid"
    if style == "gradient" then
        -- darker at the bottom, like light falling from above
        s.backdrop:SetVertexColor(1, 1, 1, 1)
        s.backdrop:SetGradient("VERTICAL", CreateColor(r * 0.45, g * 0.45, b * 0.45, alpha), CreateColor(r, g, b, alpha))
    else
        s.backdrop:SetGradient("VERTICAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, alpha))
    end
    s.backdrop:SetShown(alpha > 0)
    if style == "glass" and alpha > 0 then
        if not s.glass then
            s.glass = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
            s.glass:SetTexture(Media.textures.FADE_V)
        end
        s.glass:ClearAllPoints()
        s.glass:SetPoint("TOPLEFT"); s.glass:SetPoint("TOPRIGHT")
        s.glass:SetHeight(math.max(4, (frame:GetHeight() or 12) * 0.5))
        s.glass:SetVertexColor(1, 1, 1, 0.07)
        s.glass:Show()
    elseif s.glass then
        s.glass:Hide()
    end
end

-- Icon crop: zoom 0 = Blizzard's full art, 0.08 = the usual trim, up to 0.3.
function Sk:IconZoom(tex, zoom)
    if not originals[tex] then originals[tex] = { texcoord = { tex:GetTexCoord() } } end
    local z = zoom or 0.08
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
end

-- Zoom plus a border for an icon owned by someone else (Blizzard aura buttons): the border lives on a
-- child frame of ours laid over the icon, so the owner's own regions and sizes are never changed.
local iconFrames = setmetatable({}, { __mode = "k" })
function Sk:IconFrame(owner, icon, spec, zoom, token)
    self:IconZoom(icon, zoom)
    local h = iconFrames[icon]
    if not h then
        h = CreateFrame("Frame", nil, owner)
        h:SetAllPoints(icon)
        h:SetFrameLevel(owner:GetFrameLevel() + 2)
        iconFrames[icon] = h
    end
    self:BorderSpec(h, spec, token or "border.black")
    return h
end

---------------------------------------------------------------- status bars
function Sk:StatusBar(bar, opts)
    opts = opts or {}
    local o = originals[bar]
    if not o then
        local tex = bar:GetStatusBarTexture()
        originals[bar] = { texture = tex and tex:GetTexture(), atlas = tex and tex:GetAtlas() }
    end
    bar:SetStatusBarTexture(opts.texture or Theme:Bar())
    if opts.background ~= false then
        local s = st(bar)
        if not s.barbg then
            s.barbg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
            s.barbg:SetAllPoints()
            s.barbg:SetTexture(WHITE)
        end
        s.barbg:SetVertexColor(Theme:Color("bg.sunken"))
        s.barbg:Show()
    end
    if opts.border then self:Border(bar, opts.border == true and "border.black" or opts.border) end
end

---------------------------------------------------------------- icons
function Sk:Icon(tex, frameForBorder)
    if not originals[tex] then originals[tex] = { texcoord = { tex:GetTexCoord() } } end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if frameForBorder then self:Border(frameForBorder, "border.black") end
end

---------------------------------------------------------------- hide regions (non-protected art)
function Sk:HideRegion(region)
    if not region then return end
    if not originals[region] then originals[region] = { alpha = region:GetAlpha() } end
    region:SetAlpha(0)
end

---------------------------------------------------------------- undo
function Sk:Restore(obj)
    registry[obj] = nil
    local s = state[obj]
    if s then
        if s.bg then s.bg:Hide() end
        if s.sheen then s.sheen:Hide() end
        if s.barbg then s.barbg:Hide() end
        if s.fillShade then s.fillShade:Hide() end
        if s.border then for _, side in ipairs(SIDES) do s.border[side]:Hide() end end
        if s.backdrop then s.backdrop:Hide() end
        if s.glass then s.glass:Hide() end
        hideLines(s, "inner")
        self:HideShadow(obj)
        self:HideGlow(obj)
    end
    local o = originals[obj]
    if not o then return end
    originals[obj] = nil
    if o.fontObject then
        obj:SetFontObject(o.fontObject)
    elseif o.font and o.font[1] then
        obj:SetFont(o.font[1], o.font[2], o.font[3])
    end
    if o.color then obj:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4]) end
    if o.atlas then
        obj:SetStatusBarTexture(o.atlas)
    elseif o.texture then
        obj:SetStatusBarTexture(o.texture)
    end
    if o.texcoord then obj:SetTexCoord(unpack(o.texcoord)) end
    if o.alpha then obj:SetAlpha(o.alpha) end
end

function Sk:IsSkinned(obj)
    return originals[obj] ~= nil or state[obj] ~= nil
end
