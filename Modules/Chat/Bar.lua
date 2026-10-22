local _, ns = ...
local L, W, Skin, Theme = ns.L, ns.Widgets, ns.Skin, ns.Theme

--[[ Chat bar: one-click channel switches (Say, Yell, Party, Instance, Raid, Guild), a /roll, a ready check and a
    10 second pull timer, docked above the tabs or along the left side of the main chat window. The raid
    icon picker inserts {rt1}…{rt8} (the game turns them into icons) into the open edit box.
    Channel buttons open the edit box the way a clicked player name does (ChatFrameUtil.OpenChat); nothing
    is sent until you press Enter. Ready check and pull timer are the game's own and only work as leader. ]]
local M = ns:GetModule("Chat")

M.BAR_CHANNELS = {
    { chatType = "SAY", command = "/s " }, { chatType = "YELL", command = "/y " },
    { chatType = "PARTY", command = "/p " }, { chatType = "INSTANCE_CHAT", command = "/i " },
    { chatType = "RAID", command = "/raid " }, { chatType = "GUILD", command = "/g " },
}
local SIZE, GAP = 20, 2

-- First character of a localized channel name (UTF-8 safe), the button's label.
function M.Initial(name)
    if type(name) ~= "string" or name == "" then return "?" end
    return name:match("^[%z\1-\127\194-\244][\128-\191]*"):upper()
end

local function channelColor(chatType)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info and info.r then return info.r, info.g, info.b end
    return Theme:Color("text.primary")
end

local function insert(text)
    local box = ChatFrameUtil.GetActiveWindow()
    if box and box:HasFocus() then box:Insert(text) else ChatFrameUtil.OpenChat(text) end
end

---------------------------------------------------------------- raid icon picker
local picker
-- Raid markers 1-8 from the game's 4x4 marker sheet.
local MARKERS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function setMarker(tex, i)
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    tex:SetTexture(MARKERS)
    tex:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

local function showPicker(anchor)
    if not picker then
        picker = CreateFrame("Frame", "PhoenixUIChatIcons", UIParent)
        picker:SetFrameStrata("DIALOG")
        picker:SetClampedToScreen(true)
        picker:SetSize(8 * 22 + 10, 32)
        Skin:Register(picker, function(self) Skin:Panel(self, "raised", { border = "border.default", shadow = true }) end)
        for i = 1, 8 do
            local b = CreateFrame("Button", nil, picker)
            b:SetSize(20, 20)
            b:SetPoint("LEFT", 5 + (i - 1) * 22, 0)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetAllPoints()
            setMarker(b.tex, i)
            b:SetScript("OnClick", function() insert("{rt" .. i .. "}"); picker:Hide() end)
        end
        tinsert(UISpecialFrames, "PhoenixUIChatIcons")
        picker:Hide()
    end
    picker:ClearAllPoints()
    picker:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 4)
    picker:SetShown(not picker:IsShown())
end
M.ShowIconPicker = showPicker

local iconButtons = {}
local function editBoxPicker(box)
    local b = iconButtons[box]
    if not b then
        b = CreateFrame("Button", nil, box)
        b:SetSize(16, 16)
        b:SetPoint("RIGHT", box, "RIGHT", -8, 0)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        setMarker(b.tex, 1)
        b:SetAlpha(0.7)
        b:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
        b:SetScript("OnLeave", function(self) self:SetAlpha(0.7) end)
        b:SetScript("OnClick", function(self) showPicker(self) end)
        iconButtons[box] = b
    end
    b:SetShown(M:IsEnabled() and M.db.raidIcons)
end

---------------------------------------------------------------- the bar
local bar
local function button(parent, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIZE, SIZE)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    W.AttachTooltip(b, tip)
    Skin:Register(b, function(self) Skin:Panel(self, "sunken", { border = "border.subtle" }) end)
    return b
end

local function buildBar()
    bar = CreateFrame("Frame", "PhoenixUIChatBar", UIParent)
    bar.buttons = {}
    for _, c in ipairs(M.BAR_CHANNELS) do
        local b = button(bar, function() ChatFrameUtil.OpenChat(c.command) end, _G[c.chatType] or c.chatType)
        b.chatType = c.chatType
        bar.buttons[#bar.buttons + 1] = b
    end
    local roll = button(bar, function() RandomRoll(1, 100) end, L.CHAT_BAR_ROLL)
    roll.text = "%"
    local ready = button(bar, function() C_PartyInfo.DoReadyCheck() end, L.CHAT_BAR_READY)
    ready.icon = W.Icon(ready, "check", 12)
    local pull = button(bar, function() C_PartyInfo.DoCountdown(10) end, L.CHAT_BAR_PULL)
    pull.icon = W.Icon(pull, "clock", 12)
    local icons = button(bar, function(self) showPicker(self) end, L.CHAT_RAID_ICONS)
    icons.tex = icons:CreateTexture(nil, "ARTWORK")
    icons.tex:SetSize(14, 14)
    icons.tex:SetPoint("CENTER")
    setMarker(icons.tex, 1)
    for _, b in ipairs({ roll, ready, pull, icons }) do bar.buttons[#bar.buttons + 1] = b end
    for _, b in ipairs(bar.buttons) do if b.icon then b.icon:SetPoint("CENTER") end end
end

-- Positions of n buttons for a side: "TOP" (a row) or "LEFT" (a column); returns { {x, y} }, width, height.
function M.BarLayout(n, side)
    local pts = {}
    for i = 1, n do
        local o = (i - 1) * (SIZE + GAP)
        pts[i] = side == "LEFT" and { 0, -o } or { o, 0 }
    end
    local long = n * SIZE + (n - 1) * GAP
    if side == "LEFT" then return pts, SIZE, long end
    return pts, long, SIZE
end

function M:RefreshBar()
    ChatFrameUtil.ForEachChatFrame(function(cf) if cf.editBox then editBoxPicker(cf.editBox) end end)
    if not (self:IsEnabled() and self.db.chatBar) then
        if bar then bar:Hide() end
        return
    end
    if not bar then buildBar() end
    local side = self.db.chatBarSide == "LEFT" and "LEFT" or "TOP"
    local pts, w, h = M.BarLayout(#bar.buttons, side)
    bar:SetSize(w, h)
    bar:ClearAllPoints()
    local cf = DEFAULT_CHAT_FRAME
    if side == "LEFT" then
        bar:SetPoint("TOPRIGHT", cf, "TOPLEFT", -(self.db.sideButtons and 34 or 8), 0)
    else
        bar:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", 0, self.db.editBoxTop and 60 or 28)
    end
    for i, b in ipairs(bar.buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", pts[i][1], pts[i][2])
        if b.chatType then
            Skin:Text(b.label, "small", nil, 11, "OUTLINE")
            b.label:SetText(M.Initial(_G[b.chatType]))
            b.label:SetTextColor(channelColor(b.chatType))
        elseif b.text then
            Skin:Text(b.label, "small", "text.primary", 11, "OUTLINE")
            b.label:SetText(b.text)
        end
    end
    bar:Show()
end

function M:HideBar()
    if bar then bar:Hide() end
    if picker then picker:Hide() end
    for _, b in pairs(iconButtons) do b:Hide() end
end
