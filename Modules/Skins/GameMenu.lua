local _, ns = ...
local L = ns.L
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Skins")

--[[ Game Menu (Esc), skins plan window 1: a centred card with the Phoenix emblem and an accent underline in
    the header, and every button as a full-width row with a Phoenix line glyph on the left (menu chrome only),
    the hover in the soft accent and the label turning accent on hover. The buttons come from the menu's own
    pool every time it opens (GameMenuFrame:InitButtons), so a post-hook dresses whatever rows exist; their art
    is faded with alpha, our regions sit on a child frame, and OnClick is never touched, so Logout / Exit stay
    Blizzard's own secure-safe calls. Colours follow the live accent through Skin:Register. ]]

local EMBLEM = "Interface\\AddOns\\Phoenix_UI\\Media\\Textures\\Emblem64"
local BUTTON_ART = { "Left", "Middle", "Right" }
local BUTTON_TEX = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }

-- Button label (the game's own global strings) -> Phoenix glyph; nil = no glyph, the row still gets the look.
function M.MenuIcon(text)
    if not text or text == "" then return nil end
    local map = M.menuIcons
    if not map then
        map = {}
        local pairsList = {
            { "GAMEMENU_OPTIONS", "cog" }, { "SETTINGS", "cog" }, { "MACROS", "terminal" }, { "ADDONS", "addon" },
            { "GAMEMENU_SUPPORT", "question" }, { "GAMEMENU_HELP", "question" }, { "LOG_OUT", "user" },
            { "EXIT_GAME", "close" }, { "RETURN_TO_GAME", "play" }, { "BLIZZARD_STORE", "gold" },
            { "GAMEMENU_NEW_BUTTON", "bell" }, { "HUD_EDIT_MODE_MENU", "editmode" }, { "GAMEMENU_EDIT_MODE", "editmode" },
            { "KEY_BINDINGS", "keyboard" }, { "GAMEMENU_HOUSING", "home" },
        }
        for _, p in ipairs(pairsList) do
            local s = _G[p[1]]
            if type(s) == "string" then map[s] = p[2] end
        end
        if L.LAUNCHER_TITLE then map[L.LAUNCHER_TITLE] = "skins" end
        M.menuIcons = map
    end
    return map[text]
end

local rows = setmetatable({}, { __mode = "k" }) -- [blizzard button] = our overlay

local function paintRow(button)
    local o = rows[button]
    if not o then return end
    local hover = o.hover
    W.Color(o.bg, hover and "accent.primary" or "bg.raised", hover and 0.16 or 1)
    Skin:SetBorderColor(o, hover and "accent.primary" or "border.subtle")
    W.Color(o.bar, "accent.primary", hover and 1 or 0)
    if o.icon then ns.Icons:Tint(o.icon, hover and "accent.primary" or "text.secondary") end
    local fs = button.GetFontString and button:GetFontString()
    if fs then Skin:Text(fs, "body", hover and "accent.text" or "text.primary") end
end
M.PaintMenuRow = paintRow

function M.SkinMenuButton(button)
    if not button then return end
    local o = rows[button]
    if not o then
        for _, k in ipairs(BUTTON_ART) do Skin:HideRegion(button[k]) end
        for _, g in ipairs(BUTTON_TEX) do
            local tex = button[g] and button[g](button)
            if tex then Skin:HideRegion(tex) end
        end
        o = CreateFrame("Frame", nil, button)
        o:SetAllPoints()
        o:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        o.bg = W.Texture(o, "BACKGROUND", 0)
        o.bg:SetPoint("TOPLEFT", 1, -1); o.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        o.bar = W.Texture(o, "ARTWORK", 1)
        o.bar:SetPoint("TOPLEFT", 1, -1); o.bar:SetPoint("BOTTOMLEFT", 1, 1); o.bar:SetWidth(2)
        Skin:Border(o, "border.subtle")
        rows[button] = o
        button:HookScript("OnEnter", function(self) rows[self].hover = true; paintRow(self) end)
        button:HookScript("OnLeave", function(self) rows[self].hover = false; paintRow(self) end)
        Skin:Register(button, paintRow)
    end
    local name = M.MenuIcon(button.GetText and button:GetText())
    if name and not o.icon then
        o.icon = W.Icon(o, name, 14, "text.secondary", "OVERLAY")
        o.icon:SetPoint("LEFT", 10, 0)
    elseif o.icon and name then
        ns.Icons:Apply(o.icon, name, 14)
    end
    if o.icon then o.icon:SetShown(name and true or false) end
    o.hover = false
    paintRow(button)
end

local header
local function skinHeader(menu)
    if header then return end
    header = CreateFrame("Frame", nil, menu)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(34)
    header:SetFrameLevel(menu:GetFrameLevel() + 1)
    header.emblem = header:CreateTexture(nil, "ARTWORK")
    header.emblem:SetTexture(EMBLEM)
    header.emblem:SetSize(22, 22)
    header.emblem:SetPoint("LEFT", 10, 0)
    header.line = W.Texture(header, "ARTWORK", 1)
    header.line:SetPoint("BOTTOMLEFT", 8, 0); header.line:SetPoint("BOTTOMRIGHT", -8, 0); header.line:SetHeight(1)
    Skin:Register(header, function(self)
        Skin:Gradient(self.line, "HORIZONTAL", "accent.primary", "accent.secondary", 1, 0.2)
    end)
end

function M:SkinGameMenu(menu)
    menu = menu or _G.GameMenuFrame
    if not menu then return end
    local on = self:IsEnabled() and self.db.gameMenu and true or false
    if header then header:SetShown(on) end
    for _, o in pairs(rows) do o:SetShown(on) end
    if not on then return end
    skinHeader(menu)
    local pool = menu.buttonPool
    if pool and pool.EnumerateActive then
        for button in pool:EnumerateActive() do M.SkinMenuButton(button) end
    end
end

local menuHooked
function M:SetupGameMenu()
    local menu = _G.GameMenuFrame
    if menuHooked or not menu then return end
    menuHooked = true
    if type(menu.InitButtons) == "function" then
        hooksecurefunc(menu, "InitButtons", function(self) M:SkinGameMenu(self) end)
    end
    menu:HookScript("OnShow", function(self) M:SkinGameMenu(self) end)
end
