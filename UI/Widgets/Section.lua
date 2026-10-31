local _, ns = ...
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media

-- Card container used for option sections. icon (optional) replaces the accent tick before the title.
function W:Card(parent, title, icon)
    local c = CreateFrame("Frame", nil, parent)
    c.header = W.Text(c, "heading", "text.secondary")
    -- The tick (10 px) or icon (14 px) sits 6 px before the title and lines up with the 16 px row inset.
    c.header:SetPoint("TOPLEFT", icon and title and 36 or 32, -16)
    c.header:SetText(title and title:upper() or "")
    c.hasHeader = title ~= nil
    c.header:SetShown(c.hasHeader)
    if icon and c.hasHeader then
        c.icon = W.Icon(c, icon, 14, "accent.primary")
        c.icon:SetPoint("RIGHT", c.header, "LEFT", -6, 0)
    else
        c.tick = W.Texture(c, "ARTWORK", 1)
        c.tick:SetSize(10, 2)
        c.tick:SetPoint("RIGHT", c.header, "LEFT", -6, 0)
        c.tick:SetShown(c.hasHeader)
    end
    Skin:Register(c, function(self)
        local art = ns.Art and ns.Art.Enabled()
        Skin:Panel(self, "raised", { border = "border.subtle", sheen = not art and 28 or nil, art = "card", alpha = "card" })
        Skin:Text(self.header, "heading", "text.secondary")
        if self.tick then
            self.tick:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(self.tick, "HORIZONTAL", "accent.primary", "accent.secondary")
        end
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

-- Small pill label: RELOAD, AFTER COMBAT, NEW, ERROR … with an optional leading icon.
function W:Badge(parent, text, token, icon)
    local b = CreateFrame("Frame", nil, parent)
    b.bg = W.Texture(b, "BACKGROUND", 0, Media.textures.PILL)
    b.bg:SetAllPoints()
    b.text = W.Text(b, "small", token or "state.warning", "CENTER")
    if icon then
        b.icon = W.Icon(b, icon, 10, token or "state.warning")
        b.icon:SetPoint("LEFT", 6, 0)
        b.text:SetPoint("CENTER", 6, 0)
    else
        b.text:SetPoint("CENTER", 0, 0)
    end
    function b:Set(t, tok)
        self.token = tok or self.token or "state.warning"
        self.text:SetText(t:upper())
        self.text:SetTextColor(ns.Theme:Color(self.token))
        W.Color(self.bg, self.token, 0.16)
        if self.icon then ns.Icons:Tint(self.icon, self.token) end
        self:SetSize(self.text:GetStringWidth() + (self.icon and 26 or 14), 16)
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
