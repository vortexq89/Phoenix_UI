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
    -- { button, flat glyph, Ember Bevel glyph }
    { "CharacterMicroButton", "user", "micro-character" }, { "ProfessionMicroButton", "items", "micro-professions" },
    { "PlayerSpellsMicroButton", "spec", "micro-spells" }, { "SpellbookMicroButton", "spec", "micro-spells" },
    { "TalentMicroButton", "spec", "micro-talents" }, { "AchievementMicroButton", "success", "micro-achievements" },
    { "QuestLogMicroButton", "tracker", "micro-quests" }, { "HousingMicroButton", "home", "micro-housing" },
    { "GuildMicroButton", "guild", "micro-guild" }, { "LFDMicroButton", "friends", "micro-groupfinder" },
    { "CollectionsMicroButton", "palette", "micro-collections" }, { "EJMicroButton", "encounters", "micro-journal" },
    { "StoreMicroButton", "gold", "micro-shop" }, { "MainMenuMicroButton", "cog", "micro-menu" },
    { "HelpMicroButton", "question", "micro-help" },
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
    -- Ember Bevel (Skins > Micro menu style): the framed ember icon fills the button, glow margin included
    local bevel = M.db and M.db.microStyle ~= "flat" and t.bevelName and ns.ChromeBevel
    t.bevel:SetShown(bevel and true or false)
    t.bg:SetShown(not bevel)
    t.glyph:SetShown(not bevel)
    if bevel then
        local w, h = button:GetWidth() or 32, button:GetHeight() or 40
        local cell = math.min(w, h)
        t.bevel:SetSize(cell, cell)
        local state = s == "disabled" and "disabled" or ((s == "hover" or s == "active") and "hover" or "normal")
        if not t.flashing then ns.ChromeBevel:Apply(t.bevel, t.bevelName, state, ns.ChromeBevel.FrameIn(cell)) end
        Skin:SetBorderColor(t, 0, 0, 0, 0) -- the bevel is the border
        return
    end
    W.Color(t.bg, s == "active" and "accent.primary" or "bg.raised", s == "active" and 0.22 or (s == "hover" and 1 or 0.92))
    Skin:SetBorderColor(t, (s == "hover" or s == "active") and "accent.primary" or "border.subtle")
    ns.Icons:Tint(t.glyph, (s == "hover" or s == "active") and "accent.primary" or "text.secondary", s == "disabled" and 0.4 or 1)
end
M.PaintMicro = paintTile

-- t156: Blizzard puts its art back on its own: OnLeave sets the normal texture to alpha 1, SetPushed / SetNormal
-- reset the highlight alpha and SetHighlightAtlas / SetNormalAtlas swap the atlas. A one-time fade lasted until
-- the first hover or window toggle, so the art is faded again after each of those while the skin is on.
local live = setmetatable({}, { __mode = "k" }) -- [micro button] = true while skinned
local function artOf(button)
    local out = {}
    for _, g in ipairs(ART) do
        local tex = button[g] and button[g](button)
        if tex then out[#out + 1] = tex end
    end
    for _, k in ipairs(REGIONS) do
        local r = button[k]
        if type(r) == "table" and r.SetAlpha then out[#out + 1] = r end
    end
    return out
end
local function fade(button)
    if not live[button] then return end
    for _, r in ipairs(artOf(button)) do Skin:HideRegion(r) end
end
M._MicroFade = fade
local REFADE = { "SetPushed", "SetNormal", "SetHighlightAtlas", "SetNormalAtlas", "SetPushedAtlas", "SetButtonState" }

function M.SkinMicroButton(button, glyph, bevelName)
    if not button or tiles[button] then
        if button then live[button] = true; fade(button) end
        return button and tiles[button]
    end
    live[button] = true
    fade(button)
    local t = CreateFrame("Frame", nil, button)
    t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1)
    t:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    t.bg = W.Texture(t, "BACKGROUND", 0)
    t.bg:SetAllPoints()
    Skin:Border(t, "border.subtle")
    t.glyph = W.Icon(t, glyph, 16, "text.secondary", "ARTWORK")
    t.glyph:SetPoint("CENTER")
    t.bevelName = bevelName and ns.ChromeBevel and ns.ChromeBevel.Has(bevelName) and bevelName or nil
    t.bevel = t:CreateTexture(nil, "ARTWORK", nil, 1)
    t.bevel:SetPoint("CENTER")
    t.bevel:Hide()
    -- pressed: the Ember Bevel light burst as a 0.25 s flash
    button:HookScript("OnMouseDown", function(self)
        local tt = tiles[self]
        if tt and tt.bevel:IsShown() then
            tt.flashing = true
            ns.ChromeBevel:Flash(tt.bevel, tt.bevelName, ns.ChromeBevel.FrameIn(tt.bevel:GetWidth() or 32),
                function() tt.flashing = nil; paintTile(self) end)
        end
    end)
    tiles[button] = t
    button:HookScript("OnEnter", function(self) tiles[self].hover = true; fade(self); paintTile(self) end)
    button:HookScript("OnLeave", function(self) tiles[self].hover = false; fade(self); paintTile(self) end)
    for _, fn in ipairs(REFADE) do
        if type(button[fn]) == "function" then hooksecurefunc(button, fn, function(self) fade(self); paintTile(self) end) end
    end
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
            if on then
                M.SkinMicroButton(b, entry[2], entry[3])
                M.PaintMicro(b)
            elseif live[b] then
                live[b] = nil -- switched off: Blizzard's art back, not blank buttons until a reload
                for _, r in ipairs(artOf(b)) do Skin:Restore(r) end
            end
            if tiles[b] then tiles[b]:SetShown(on) end
        end
    end
    -- buttons Blizzard builds later in the login (housing, store) are picked up once the world is in
    if not self._microPEW then
        self._microPEW = true
        ns.Events:On("PLAYER_ENTERING_WORLD", self, function() M:SkinMicroMenu() end)
    end
end
