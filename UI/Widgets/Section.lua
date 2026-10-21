local _, ns = ...
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media

-- Card container used for option sections.
function W:Card(parent, title)
    local c = CreateFrame("Frame", nil, parent)
    c.header = W.Text(c, "heading", "text.secondary")
    c.header:SetPoint("TOPLEFT", 30, -15)
    c.tick = W.Texture(c, "ARTWORK", 1)
    c.tick:SetSize(10, 2)
    c.tick:SetPoint("RIGHT", c.header, "LEFT", -6, 0)
    c.header:SetText(title and title:upper() or "")
    c.hasHeader = title ~= nil
    c.header:SetShown(c.hasHeader)
    c.tick:SetShown(c.hasHeader)
    Skin:Register(c, function(self)
        Skin:Panel(self, "raised", { border = "border.subtle", sheen = 28 })
        Skin:Text(self.header, "heading", "text.secondary")
        self.tick:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(self.tick, "HORIZONTAL", "accent.primary", "accent.secondary")
    end)
    return c
end

-- 1px separator line.
function W:Separator(parent, token)
    local t = W.Texture(parent, "ARTWORK")
    t:SetHeight(PixelUtil.ConvertPixelsToUIForRegion(1, parent))
    W.Color(t, token or "border.subtle", 0.6)
    return t
end

-- Small pill label: RELOAD, AFTER COMBAT, NEW, ERROR …
function W:Badge(parent, text, token)
    local b = CreateFrame("Frame", nil, parent)
    b.bg = W.Texture(b, "BACKGROUND", 0, Media.textures.PILL)
    b.bg:SetAllPoints()
    b.text = W.Text(b, "small", token or "state.warning", "CENTER")
    b.text:SetPoint("CENTER", 0, 0)
    function b:Set(t, tok)
        self.token = tok or self.token or "state.warning"
        self.text:SetText(t:upper())
        self.text:SetTextColor(ns.Theme:Color(self.token))
        W.Color(self.bg, self.token, 0.16)
        self:SetSize(self.text:GetStringWidth() + 14, 16)
    end
    b:Set(text or "", token)
    Skin:Register(b, function(self) Skin:Text(self.text, "small"); self:Set(self.text:GetText() or "", self.token) end)
    return b
end

-- Round status dot.
function W:Dot(parent, size)
    local d = W.Texture(parent, "OVERLAY", 1, Media.textures.CIRCLE)
    d:SetSize(size or 6, size or 6)
    return d
end
