local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

-- An item card for replacement windows: the thing's own icon in a frame of its quality colour, name (quality colour),
-- count on the icon, a small line under the name. W.PaintItemCard(c, d): d = { texture, name, count, quality, sub, dim }.
function W.ItemCard(parent, width, height)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(width, height)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local size = height - 8
    c.box = CreateFrame("Frame", nil, c)
    c.box:SetSize(size + 2, size + 2)
    c.box:SetPoint("LEFT", 3, 0)
    c.icon = c.box:CreateTexture(nil, "ARTWORK")
    c.icon:SetPoint("TOPLEFT", 1, -1)
    c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    Skin:Icon(c.icon)
    Skin:Border(c.box, "border.subtle")
    c.count = c.box:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    c.count:SetPoint("BOTTOMRIGHT", -2, 2)
    c.name = W.Text(c, "body", "text.primary")
    c.name:SetPoint("TOPLEFT", c.box, "TOPRIGHT", 6, -2)
    c.name:SetPoint("RIGHT", -4, 0)
    c.sub = W.Text(c, "small", "text.muted")
    c.sub:SetPoint("BOTTOMLEFT", c.box, "BOTTOMRIGHT", 6, 2)
    c.sub:SetPoint("RIGHT", -4, 0)
    return c
end

function W.PaintItemCard(c, d, border)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- a quest icon atlas may have been on this card before
    c.icon:SetTexture(d.texture)
    c.icon:SetDesaturated(d.dim and true or false)
    c.count:SetText((tonumber(d.count) or 0) > 1 and BreakUpLargeNumbers(d.count) or "")
    c.name:SetText(d.name or "")
    c.sub:SetText(d.sub or "")
    local S = ns:Loaded("Skins") -- its quality ramp when the plugin is on
    local q = S and S.QualityBar and S.QualityBar(d.quality)
    if q then
        Skin:SetBorderColor(c.box, q.r, q.g, q.b, 1)
        c.name:SetTextColor(q.r, q.g, q.b, 1)
    else
        Skin:SetBorderColor(c.box, "border.subtle")
        Skin:Text(c.name, "body", "text.primary")
    end
    Skin:Panel(c, "raised", { border = border or "border.subtle" })
    c:Show()
end
