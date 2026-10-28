local _, ns = ...
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Skins")

--[[ Popups and ready check, skins plan window 26 (the cards themselves use the shared dialog skin; tooltips
    are the Tooltip module's: 1 px border, quality and class colours): the first button of a popup (Accept /
    Okay / Yes) becomes the Phoenix primary button (accent gradient), the others secondary, and a popup's
    typing field (delete confirmation, names) a sunken Phoenix field with an accent border while typing.
    Blizzard's button art is faded with alpha, our fill sits on a child frame, and OnClick stays Blizzard's, so
    confirming a protected action (release, delete, leave) is still Blizzard's own click. Live both ways with
    Skins > Popups, repainted on theme change. ]]

M.POPUPS = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }
local ART = { "Left", "Middle", "Right" }
local TEX = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
local fills = setmetatable({}, { __mode = "k" }) -- [blizzard button] = our fill frame

-- "primary" for the first button of a popup or the ready check's Yes, else "secondary".
function M.PopupVariant(index) return index == 1 and "primary" or "secondary" end

local function buttonArt(b)
    local out = {}
    for _, k in ipairs(ART) do if type(b[k]) == "table" and b[k].SetAlpha then out[#out + 1] = b[k] end end
    for _, g in ipairs(TEX) do
        local tex = b[g] and b[g](b)
        if tex then out[#out + 1] = tex end
    end
    return out
end

local function paintButton(b)
    local f = fills[b]
    if not f then return end
    if f.variant == "primary" then
        f.bg:SetVertexColor(1, 1, 1, f.hover and 1 or 0.92)
        Skin:Gradient(f.bg, "HORIZONTAL", "accent.primary", "accent.secondary")
        Skin:SetBorderColor(f, "accent.primary")
    else
        f.bg:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
        W.Color(f.bg, f.hover and "accent.primary" or "bg.raised", f.hover and 0.16 or 1)
        Skin:SetBorderColor(f, f.hover and "accent.primary" or "border.subtle")
    end
    local fs = b.GetFontString and b:GetFontString()
    if fs then Skin:Text(fs, "body", f.variant == "primary" and "bg.base" or "text.primary") end
end
M.PaintPopupButton = paintButton

function M.SkinPopupButton(b, variant, on)
    if type(b) ~= "table" or not b.GetObjectType then return end
    local f = fills[b]
    if not on then
        if f then
            f:Hide()
            for _, r in ipairs(buttonArt(b)) do Skin:Restore(r) end
            local fs = b.GetFontString and b:GetFontString()
            if fs then Skin:Restore(fs) end
            Skin:Restore(b)
        end
        return
    end
    if not f then
        f = CreateFrame("Frame", nil, b)
        f:SetAllPoints()
        f:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
        f.bg = W.Texture(f, "BACKGROUND", 0)
        f.bg:SetPoint("TOPLEFT", 1, -1); f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        Skin:Border(f, "border.subtle")
        fills[b] = f
        b:HookScript("OnEnter", function(self) fills[self].hover = true; paintButton(self) end)
        b:HookScript("OnLeave", function(self) fills[self].hover = false; paintButton(self) end)
    end
    f.variant = variant
    for _, r in ipairs(buttonArt(b)) do Skin:HideRegion(r) end
    f:Show()
    Skin:Register(b, paintButton)
end

local function popupButtons(popup)
    local out, name = {}, popup:GetName()
    local box = popup.ButtonContainer
    for i = 1, 4 do
        local b = (box and box["Button" .. i]) or popup["button" .. i] or (name and _G[name .. "Button" .. i])
        if b then out[#out + 1] = b end
    end
    return out
end

local fields = setmetatable({}, { __mode = "k" })
local function skinField(box, on)
    if not box then return end
    local o = fields[box]
    if not on then
        if o then
            for _, k in ipairs({ "Left", "Middle", "Right", "Mid" }) do if type(box[k]) == "table" then Skin:Restore(box[k]) end end
            Skin:Restore(box)
        end
        return
    end
    if not o then
        o = { focus = false }
        fields[box] = o
        box:HookScript("OnEditFocusGained", function(self) o.focus = true; if o.paint then o.paint(self) end end)
        box:HookScript("OnEditFocusLost", function(self) o.focus = false; if o.paint then o.paint(self) end end)
        o.paint = function(self)
            if not (M:IsEnabled() and M.db.popups) then return end
            Skin:Panel(self, "sunken", { border = o.focus and "accent.primary" or "border.subtle" })
        end
    end
    for _, k in ipairs({ "Left", "Middle", "Right", "Mid" }) do
        if type(box[k]) == "table" and box[k].SetAlpha then Skin:HideRegion(box[k]) end
    end
    Skin:Register(box, o.paint)
end

function M:SkinPopups()
    local on = self:IsEnabled() and self.db.popups and true or false
    for _, name in ipairs(self.POPUPS) do
        local popup = _G[name]
        if popup then
            for i, b in ipairs(popupButtons(popup)) do M.SkinPopupButton(b, M.PopupVariant(i), on) end
            skinField(popup.EditBox or _G[name .. "EditBox"], on)
        end
    end
    local rc = self:IsEnabled() and self.db.readyCheck and true or false
    M.SkinPopupButton(_G.ReadyCheckFrameYesButton, "primary", rc)
    M.SkinPopupButton(_G.ReadyCheckFrameNoButton, "secondary", rc)
end

local popupsHooked
function M:SetupPopups()
    self:SkinPopups()
    if popupsHooked then return end
    popupsHooked = true
    for _, name in ipairs(self.POPUPS) do
        local popup = _G[name]
        if popup then popup:HookScript("OnShow", function() M:SkinPopups() end) end
    end
end
