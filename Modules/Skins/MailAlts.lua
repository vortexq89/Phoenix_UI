local _, ns = ...
local M, W, L = ns.modules.Skins, ns.Widgets, ns.L

--[[ Mail: a button beside the recipient box lists your other characters on this realm; picking one fills
    the box. Characters are remembered at login (name, class, level) in the account-wide saved table.
    Skins option "mailAlts" (on by default), applied live. Nothing is sent for you. ]]
local function altStore()
    local g = ns.DB.sv.global
    g.alts = type(g.alts) == "table" and g.alts or {}
    return g.alts
end

function M:RememberCharacter()
    local name, realm = UnitName("player"), GetRealmName()
    if type(name) ~= "string" or type(realm) ~= "string" then return end
    local _, classFile = UnitClass("player")
    local list = altStore()
    list[realm] = list[realm] or {}
    list[realm][name] = { class = classFile, level = UnitLevel("player"), seen = time() }
end

-- Other characters on this realm, highest level first: { { name, class, level } }.
function M:MailAlts()
    local me, realm = UnitName("player"), GetRealmName()
    local out = {}
    for name, c in pairs(altStore()[realm] or {}) do
        if name ~= me then out[#out + 1] = { name = name, class = c.class, level = c.level or 0 } end
    end
    table.sort(out, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    return out
end

local button
local function pick(name)
    local box = _G.SendMailNameEditBox
    if box then box:SetText(name); box:SetCursorPosition(#name) end
    W.HidePopover()
end

local function open()
    local alts = M:MailAlts()
    local content = CreateFrame("Frame")
    local y = 0
    for _, a in ipairs(alts) do
        local b = W:Button(content, ("%s  (%d)"):format(a.name, a.level), "ghost", nil, 200)
        b:SetPoint("TOPLEFT", 8, -y)
        b:SetPoint("TOPRIGHT", -8, -y)
        if a.class and b.label and ns.Util.ClassColor then b.label:SetTextColor(ns.Util.ClassColor(a.class)) end
        b.onClick = function() pick(a.name) end
        y = y + 30
    end
    if #alts == 0 then
        local t = W.Text(content, "small", "text.muted")
        t:SetPoint("TOPLEFT", 10, 0)
        t:SetText(L.MAIL_ALTS_NONE)
        y = 24
    end
    W:Popover(button, L.MAIL_ALTS, content, 220, y)
end

function M:RefreshMailAlts()
    local box = _G.SendMailNameEditBox
    if not box then return end
    if self.db.mailAlts and not button then
        button = W:Button(box:GetParent() or box, L.MAIL_ALTS, "secondary", nil, 70)
        button:SetHeight(22)
        button:SetPoint("LEFT", box, "RIGHT", 6, 0)
        button.onClick = open
    end
    if button then button:SetShown(self.db.mailAlts and true or false) end
end

local owner = {}
ns.Events:On("PLAYER_LOGIN", owner, function()
    M:RememberCharacter()
    if M:IsEnabled() then M:RefreshMailAlts() end
end)
ns.Events:On("PLAYER_LEVEL_UP", owner, function() M:RememberCharacter() end)
M.MailAltsButton = function() return button end
