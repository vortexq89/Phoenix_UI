local _, ns = ...

--[[ ns.EmblemFX — the Phoenix emblem's living flame: a soft glow behind it that breathes (Alpha animation,
    bounce) and embers rising over it (an 8x4 FlipBook on Media/Textures/Embers). Both are Blizzard animation
    groups, so there is no OnUpdate anywhere; they play only while the emblem is visible, stop in combat and
    whenever General > Emblem effects or Reduce motion say so. Colours follow the live accent (accent.glow and
    accent.secondary), repainted through Skin:Register like every other themed region.
      EmblemFX:Attach(tex, size)   tex = the emblem texture (its parent frame owns the effects) ]]
local FX = {}
ns.EmblemFX = FX
local DIR = ns.C and ns.C.TEXTURES or ("Interface\\AddOns\\" .. (ns.ADDON or "Phoenix_UI") .. "\\Media\\Textures\\")
local GLOW, EMBERS = DIR .. "EmblemGlow", DIR .. "Embers"
local COLS, ROWS, FRAMES, EMBER_TIME, PULSE_TIME = 8, 4, 32, 1.6, 2.4

local all = setmetatable({}, { __mode = "k" }) -- fx frame -> true

local function wanted()
    local s = ns.Theme and ns.Theme.settings or {}
    if s.emblemFX == false or s.reduceMotion then return false end
    return not InCombatLockdown()
end

local function update(f)
    local on = wanted() and f:IsVisible()
    f.glow:SetShown(on); f.embers:SetShown(on)
    if on then
        if not f.pulse:IsPlaying() then f.pulse:Play() end
        if f.flip and not f.flip:IsPlaying() then f.flip:Play() end
    else
        f.pulse:Stop()
        if f.flip then f.flip:Stop() end
    end
end

function FX:UpdateAll() for f in pairs(all) do update(f) end end

function FX:Attach(tex, size)
    if not (tex and tex.GetParent) then return end
    if tex.phoenixFX then return tex.phoenixFX end
    local parent = tex:GetParent()
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:SetFrameLevel(parent:GetFrameLevel())
    f.glow = parent:CreateTexture(nil, "BACKGROUND", nil, 7)
    f.glow:SetTexture(GLOW)
    f.glow:SetBlendMode("ADD")
    f.glow:SetSize(size * 1.7, size * 1.7)
    f.glow:SetPoint("CENTER", tex, "CENTER")
    f.embers = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    f.embers:SetTexture(EMBERS)
    f.embers:SetBlendMode("ADD")
    f.embers:SetSize(size * 1.1, size * 1.1)
    f.embers:SetPoint("BOTTOM", tex, "BOTTOM", 0, size * 0.15)
    f.embers:SetTexCoord(0, 1 / COLS, 0, 1 / ROWS)

    f.pulse = f:CreateAnimationGroup()
    f.pulse:SetLooping("BOUNCE")
    local a = f.pulse:CreateAnimation("Alpha")
    a:SetTarget(f.glow); a:SetFromAlpha(0.35); a:SetToAlpha(0.8); a:SetDuration(PULSE_TIME); a:SetSmoothing("IN_OUT")

    local ok, flip = pcall(function()
        local g = f:CreateAnimationGroup()
        g:SetLooping("REPEAT")
        local fb = g:CreateAnimation("FlipBook")
        fb:SetTarget(f.embers)
        fb:SetFlipBookRows(ROWS); fb:SetFlipBookColumns(COLS); fb:SetFlipBookFrames(FRAMES)
        fb:SetFlipBookFrameWidth(0); fb:SetFlipBookFrameHeight(0)
        fb:SetDuration(EMBER_TIME)
        return g
    end)
    f.flip = ok and flip or nil

    ns.Skin:Register(f, function(self)
        local r, g, b = ns.Theme:Color("accent.glow")
        self.glow:SetVertexColor(r, g, b, 1)
        local sr, sg, sb = ns.Theme:Color("accent.secondary")
        self.embers:SetVertexColor(sr, sg, sb, 0.9)
    end)
    f:SetScript("OnShow", update)
    f:SetScript("OnHide", update)
    all[f] = true
    tex.phoenixFX = f
    update(f)
    return f
end

ns.Events:On("PLAYER_REGEN_DISABLED", FX, function() FX:UpdateAll() end)
ns.Events:On("PLAYER_REGEN_ENABLED", FX, function() FX:UpdateAll() end)
ns.Events:On("PUI_SETTING_CHANGED", FX, function(_, _, key, path)
    if key == "General" and (path == "theme.emblemFX" or path == "theme.reduceMotion") then FX:UpdateAll() end
end)
