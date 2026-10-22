local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

-- Small movable, themed dialog (copy URL, copy chat …). Its edit boxes close it on Escape
-- (no keyboard capture on the frame itself: SetPropagateKeyboardInput is restricted in combat).
function W:Popup(title, width, height, icon)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.accent = W.Texture(f, "ARTWORK", 2)
    f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT")
    f.accent:SetHeight(2)
    f.title = W.Text(f, "heading", "text.secondary")
    f.title:SetPoint("TOPLEFT", icon and 36 or 16, -14)
    if icon then
        f.icon = W.Icon(f, icon, 14, "accent.primary")
        f.icon:SetPoint("RIGHT", f.title, "LEFT", -6, 0)
    end
    f.title:SetText(title:upper())
    f.close = W:IconButton(f, "close", 24, ns.L.CLOSE)
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close.onClick = function() f:Hide() end
    Skin:Register(f, function(self)
        Skin:Panel(self, "raised", { border = "border.strong", shadow = 14, sheen = 30 })
        self.accent:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(self.accent, "HORIZONTAL", "accent.primary", "accent.secondary")
        Skin:Text(self.title, "heading", "text.secondary")
    end)
    f:Hide()
    return f
end
