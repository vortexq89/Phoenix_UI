local _, ns = ...

--[[ ns.Widgets — themed controls for the config window. Every widget:
    :SetValue(v) / :GetValue(), .onChange = function(widget, value), :SetEnabledState(bool).
    Colours always come from ns.Theme; widgets re-theme on PUI_THEME_CHANGED via ns.Skin:Register. ]]
local W = {}
ns.Widgets = W
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media
local WHITE = Media.textures.WHITE

W.ROW_HEIGHT = 30
W.CONTROL_WIDTH = 220

function W.Texture(parent, layer, sub, path)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(path or WHITE)
    return t
end

function W.Text(parent, role, token, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    Skin:Text(fs, role or "body", token or "text.primary")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function W.Color(tex, token, alpha)
    local r, g, b, a = Theme:Color(token)
    tex:SetVertexColor(r, g, b, alpha or a)
end

function W.Icon(parent, name, size, token)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(Media:Icon(name))
    t:SetSize(size or 16, size or 16)
    W.Color(t, token or "text.secondary")
    return t
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

function W.ShowTooltip(owner, title, text)
    local t = getTip()
    t.title:SetText(title or "")
    t.text:SetText(text or "")
    t.text:SetShown(text ~= nil and text ~= "")
    local w = math.max(t.title:GetStringWidth(), text and math.min(260, t.text:GetStringWidth()) or 0)
    t.text:SetWidth(math.max(w, 1))
    t:SetSize(w + 20, t.title:GetStringHeight() + (t.text:IsShown() and t.text:GetStringHeight() + 4 or 0) + 18)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 6)
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

---------------------------------------------------------------- hover colour helper
-- Lerp a texture between two tokens on enter/leave.
function W.HoverFill(frame, tex, idleToken, hoverToken, duration)
    local function to(token)
        local r1, g1, b1, a1 = tex:GetVertexColor()
        ns.Anim:Color(tex, duration or 0.08, { r1, g1, b1, a1 }, { Theme:Color(token) }, function(r, g, b, a)
            tex:SetVertexColor(r, g, b, a)
        end)
    end
    frame:HookScript("OnEnter", function(self) if not self.disabled and not self.active then to(hoverToken) end end)
    frame:HookScript("OnLeave", function(self) if not self.active then to(idleToken) end end)
end
