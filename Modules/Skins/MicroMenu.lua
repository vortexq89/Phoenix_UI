local _, ns = ...
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Skins")

--[[ Micro menu, skins plan window 2: each micro button becomes a flat 1 px-bordered tile with a Phoenix glyph
    (Phoenix's own menu chrome; no game content icon is involved). Blizzard's button art is faded with alpha
    and our tile sits on a child frame below the button's own alert pieces, so the flash border, notification
    badge and the guild / talent / mail alerts still show on top. Hover and the open window's tile use the
    accent; colours repaint live on theme change. Buttons, scripts and positions are never touched (Edit Mode
    and the Phoenix action-bar fade keep working). ]]

-- global button name -> Phoenix glyph
M.MICRO = {
    { "CharacterMicroButton", "user" }, { "ProfessionMicroButton", "items" }, { "PlayerSpellsMicroButton", "spec" },
    { "SpellbookMicroButton", "spec" }, { "TalentMicroButton", "spec" },
    { "AchievementMicroButton", "success" }, { "QuestLogMicroButton", "tracker" }, { "HousingMicroButton", "home" },
    { "GuildMicroButton", "guild" }, { "LFDMicroButton", "friends" }, { "CollectionsMicroButton", "palette" },
    { "EJMicroButton", "encounters" }, { "StoreMicroButton", "gold" }, { "MainMenuMicroButton", "cog" },
    { "HelpMicroButton", "question" },
}
local ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local REGIONS = { "Background", "PushedBackground", "Portrait", "PortraitMask", "Shadow", "PushedShadow" }

local tiles = setmetatable({}, { __mode = "k" }) -- [micro button] = our tile

-- Tile colours for a state: "hover" | "active" | "idle" | "disabled".
function M.MicroState(button, hover)
    if button.IsEnabled and not button:IsEnabled() then return "disabled" end
    if hover then return "hover" end
    if button.GetButtonState and button:GetButtonState() == "PUSHED" then return "active" end
    return "idle"
end

local function paintTile(button)
    local t = tiles[button]
    if not t then return end
    local s = M.MicroState(button, t.hover)
    W.Color(t.bg, s == "active" and "accent.primary" or "bg.raised", s == "active" and 0.22 or (s == "hover" and 1 or 0.92))
    Skin:SetBorderColor(t, (s == "hover" or s == "active") and "accent.primary" or "border.subtle")
    ns.Icons:Tint(t.glyph, (s == "hover" or s == "active") and "accent.primary" or "text.secondary", s == "disabled" and 0.4 or 1)
end
M.PaintMicro = paintTile

function M.SkinMicroButton(button, glyph)
    if not button or tiles[button] then return tiles[button] end
    for _, g in ipairs(ART) do
        local tex = button[g] and button[g](button)
        if tex then Skin:HideRegion(tex) end
    end
    for _, k in ipairs(REGIONS) do
        local r = button[k]
        if type(r) == "table" and r.SetAlpha then Skin:HideRegion(r) end
    end
    local t = CreateFrame("Frame", nil, button)
    t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1)
    t:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    t.bg = W.Texture(t, "BACKGROUND", 0)
    t.bg:SetAllPoints()
    Skin:Border(t, "border.subtle")
    t.glyph = W.Icon(t, glyph, 16, "text.secondary", "ARTWORK")
    t.glyph:SetPoint("CENTER")
    tiles[button] = t
    button:HookScript("OnEnter", function(self) tiles[self].hover = true; paintTile(self) end)
    button:HookScript("OnLeave", function(self) tiles[self].hover = false; paintTile(self) end)
    if button.SetButtonState then hooksecurefunc(button, "SetButtonState", paintTile) end
    Skin:Register(button, paintTile)
    paintTile(button)
    return t
end

-- t146: the bag bar beside the micro menu kept Blizzard's gold rings and round-masked icons. Skinned with the
-- micro menu: each bag becomes a square, flat-bordered tile like the Phoenix bag window's slots. Art is faded
-- by alpha and the circle mask taken off the icon; both come back with the switch off. Clicks, drags and the
-- bag tooltips stay Blizzard's.
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
    "CharacterBag3Slot", "CharacterReagentBag0Slot" }
local bagSkinned = setmetatable({}, { __mode = "k" })
function M.SkinBagButton(b, on)
    local icon = b and (b.icon or b.Icon)
    if not icon then return end
    if on then
        for _, g in ipairs(ART) do
            local tex = b[g] and b[g](b)
            if tex then Skin:HideRegion(tex) end
        end
        if b.IconBorder then Skin:HideRegion(b.IconBorder) end
        if b.CircleMask and not bagSkinned[b] then icon:RemoveMaskTexture(b.CircleMask) end
        bagSkinned[b] = true
        Skin:IconFrame(b, icon, {}, 0.08, "border.subtle")
    elseif bagSkinned[b] then
        bagSkinned[b] = nil
        for _, g in ipairs(ART) do
            local tex = b[g] and b[g](b)
            if tex then Skin:Restore(tex) end
        end
        if b.IconBorder then Skin:Restore(b.IconBorder) end
        if b.CircleMask then icon:AddMaskTexture(b.CircleMask) end
        Skin:HideIconFrame(icon)
    end
end
M.BAG_BUTTONS = BAG_BUTTONS

function M:SkinMicroMenu()
    local on = self:IsEnabled() and self.db.microMenu and true or false
    for _, name in ipairs(BAG_BUTTONS) do M.SkinBagButton(_G[name], on) end
    for _, entry in ipairs(self.MICRO) do
        local b = _G[entry[1]]
        if b then
            if on then M.SkinMicroButton(b, entry[2]) end
            if tiles[b] then tiles[b]:SetShown(on) end
        end
    end
end
