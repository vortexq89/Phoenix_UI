local _, ns = ...

--[[ ns.Widgets — themed controls for the config window. Every widget:
    :SetValue(v) / :GetValue(), .onChange = function(widget, value), :SetEnabledState(bool).
    Colours always come from ns.Theme; widgets re-theme on PUI_THEME_CHANGED via ns.Skin:Register. ]]
local W = {}
ns.Widgets = W
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media
local WHITE = Media.textures.WHITE

W.ROW_HEIGHT = 30
W.CONTROL_WIDTH = 200

-- Control metrics (t222, specs/001-settings-window): measured sizes and alphas, in one place. Colours are white or
-- black at these alphas over the theme surfaces, the accent, or a theme bg.* token named here (read with W.RGB).
W.EUI = {
    toggle = { w = 40, h = 20, pad = 2, slide = 0.075, offRGB = 0.267, offA = 0.65, onA = 0.75, knobOffA = 0.5, knobOnA = 1 },
    checkbox = { box = "bg.control", borderA = 0.05, checkedBorderA = 0.15 },
    slider = { trackA = 0.16, fillA = 0.75, input = "bg.sunken", inputA = 0.25, inputBorderA = 0.02 },
    dropdown = { bg = "bg.hover", bgA = 0.9, bgHoverA = 0.98, borderA = 0.20, borderHoverA = 0.30,
        textA = 0.50, textHoverA = 0.60, itemHoverA = 0.08, itemSelA = 0.04, maxHeight = 200, scrollW = 4 },
    button = { bg = "bg.raised", bgA = 0.6, bgHoverA = 0.65, borderA = 0.3, borderHoverA = 0.45,
        textA = 0.55, textHoverA = 0.70 },
    row = { h = 50, dualW = 350, dualGap = 42, tripleW = 180, tripleGap = 50, oddA = 0.1, evenA = 0.2 },
    section = { textA = 0.41 },
    window = { w = 1300, h = 946, sidebar = 295, header = 138, tabs = 40, footer = 82, pad = 45 },
    -- design v2: smooth corners (Skin:SetRound / Skin:RoundFill); control = buttons, fields and dropdowns
    radius = { control = 5, box = 4, card = 10, nav = 6 },
    nav = { selectedA = 1, enabledA = 0.6, disabledA = 0.11, hoverA = 0.86, hoverDisabledA = 0.39, rowH = 28, groupGap = 10 },
}

-- RGB of a metrics colour: a theme token name, so controls follow the active palette.
function W.RGB(token)
    local r, g, b = Theme:Color(token)
    return r, g, b
end

function W.Texture(parent, layer, sub, path)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(path or WHITE)
    return t
end

function W.Text(parent, role, token, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Skin:Text(fs, role or "body", token or "text.primary")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function W.Color(tex, token, alpha)
    if ns.Icons:Owns(tex) then
        ns.Icons:SetState(tex, nil)
        return ns.Icons:Tint(tex, token, alpha)
    end
    local r, g, b, a = Theme:Color(token)
    tex:SetVertexColor(r, g, b, alpha or a)
end

-- Tintable glyph from the Phoenix icon set (ns.Icons). Colour with ns.Icons:Tint / :SetState.
function W.Icon(parent, name, size, token, layer)
    return ns.Icons:Create(parent, name, size or 16, token or "text.secondary", layer)
end

-- Icon tiles (module cards, page header, search results): a tinted glyph sits on an accent tile; full-colour
-- game art instead fills the tile on a neutral backing, so it never reads as an orange square with a speck.
function W.TileColor(bg, icon, token, alpha)
    local art = ns.Icons:IsArt(icon)
    W.Color(bg, art and "bg.sunken" or token, art and 1 or alpha)
    local w = bg:GetWidth()
    if type(w) == "number" and w > 0 then
        icon.puiGlyph = icon.puiGlyph or icon:GetWidth()
        local size = art and (w - 4) or icon.puiGlyph
        icon:SetSize(size, size)
    end
end

-- Shared disabled handling.
function W.SetEnabledState(frame, enabled)
    frame.disabled = not enabled
    frame:SetAlpha(enabled and 1 or 0.4)
    if frame.EnableMouse then frame:EnableMouse(enabled) end
end

---------------------------------------------------------------- themed tooltip
local tip
local function getTip()
    if tip then return tip end
    tip = CreateFrame("Frame", nil, UIParent)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetClampedToScreen(true)
    tip.title = W.Text(tip, "body", "text.primary")
    tip.text = W.Text(tip, "desc", "text.secondary")
    tip.text:SetWordWrap(true)
    tip.title:SetPoint("TOPLEFT", 10, -9)
    tip.text:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -4)
    tip.text:SetWidth(260)
    Skin:Register(tip, function(f)
        Skin:Panel(f, "raised", { border = "border.strong", shadow = 8 })
        Skin:Text(f.title, "body", "text.primary")
        Skin:Text(f.text, "desc", "text.secondary")
    end)
    tip:Hide()
    return tip
end

-- beside = true: the tip sits right of the owner's text, centred on it, so it never covers the rows above
-- (a setting's label); otherwise it sits above the owner.
function W.ShowTooltip(owner, title, text, beside)
    local t = getTip()
    t.title:SetText(title or "")
    t.text:SetText(text or "")
    t.text:SetShown(text ~= nil and text ~= "")
    local w = math.max(t.title:GetStringWidth(), text and math.min(260, t.text:GetStringWidth()) or 0)
    t.text:SetWidth(math.max(w, 1))
    t:SetSize(w + 20, t.title:GetStringHeight() + (t.text:IsShown() and t.text:GetStringHeight() + 4 or 0) + 18)
    t:ClearAllPoints()
    if beside and owner.GetUnboundedStringWidth then
        local tw = math.min(owner:GetUnboundedStringWidth() or 0, owner:GetWidth() or 0)
        t:SetPoint("LEFT", owner, "LEFT", math.floor(tw + 16), 0)
    else
        t:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 6)
    end
    t.beside = beside and true or nil
    ns.Anim:FadeIn(t, 0.1)
end

function W.HideTooltip()
    if tip then tip:Hide() end
end

function W.AttachTooltip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        local t = type(title) == "function" and title(self) or title
        local d = type(text) == "function" and text(self) or text
        if t then W.ShowTooltip(self, t, d) end
    end)
    frame:HookScript("OnLeave", W.HideTooltip)
end
