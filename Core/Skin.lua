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
    originals[fs] = { font = { path, osize, oflags }, fontObject = fs:GetFontObject(), color = { r, g, b, a } }
end

function Sk:Text(fs, role, colorToken, size, flags)
    recordFont(fs)
    local path, rsize, rflags = Theme:Font(role, size)
    fs:SetFont(path, rsize, flags or rflags)
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

function Sk:SpecColor(color, token)
    if type(color) == "table" then return color.r or 1, color.g or 1, color.b or 1, color.a or 1 end
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

-- spec: { style = "none"|"solid"|"glow"|"shadow", size = px, color = {r,g,b,a}|false }
function Sk:BorderSpec(frame, spec, token)
    local style = spec.style or "solid"
    local r, g, b, a = self:SpecColor(spec.color, token or "border.black")
    local s = state[frame]
    if style == "none" then
        if s and s.border then for _, side in ipairs(SIDES) do s.border[side]:Hide() end end
        self:HideGlow(frame)
        return
    end
    if style == "glow" then
        if s and s.border then for _, side in ipairs(SIDES) do s.border[side]:Hide() end end
        self:Glow(frame, 4 + (spec.size or 1) * 3, "Tight", r, g, b, a)
        return
    end
    self:Border(frame, nil, spec.size or 1)
    self:SetBorderColor(frame, r, g, b, a)
    if style == "shadow" then
        self:Glow(frame, 6 + (spec.size or 1) * 3, "Soft", 0, 0, 0, 0.75)
    else
        self:HideGlow(frame)
    end
end

-- spec: { alpha = 0..1, color = {r,g,b}|false }; drawn under everything on frame.
function Sk:Backdrop(frame, spec, token)
    local s = st(frame)
    if not s.backdrop then
        s.backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        s.backdrop:SetTexture(WHITE)
        s.backdrop:SetAllPoints()
    end
    local r, g, b = self:SpecColor(spec.color, token or "bg.sunken")
    s.backdrop:SetVertexColor(r, g, b, spec.alpha or 0.6)
    s.backdrop:SetShown((spec.alpha or 0.6) > 0)
end

-- Icon crop: zoom 0 = Blizzard's full art, 0.08 = the usual trim, up to 0.3.
function Sk:IconZoom(tex, zoom)
    if not originals[tex] then originals[tex] = { texcoord = { tex:GetTexCoord() } } end
    local z = zoom or 0.08
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
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
        if s.border then for _, side in ipairs(SIDES) do s.border[side]:Hide() end end
        if s.backdrop then s.backdrop:Hide() end
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
