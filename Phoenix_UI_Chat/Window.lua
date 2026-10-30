local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin

--[[ Chat windows: Phoenix backdrop and border (style library) instead of Blizzard's window textures, line fading,
    kept lines, side buttons tucked away, a jump-to-bottom button, hide in combat, tab fading and the selected
    tab's colour, and the edit box (above or below, Phoenix style and font). Chat frames are not protected;
    positions and sizes stay Blizzard's (Edit Mode / the chat menu). Everything is undone on disable. ]]
local M = ns:GetModule("Chat")

local state = setmetatable({}, { __mode = "k" }) -- [chatFrame] = { bg, jump, hidden = { tex }, points = {...} }
local tuckParent
local tucked = {}

local function tuck(frame, show)
    if not frame then return end
    if show then
        if tucked[frame] then frame:SetParent(tucked[frame]); tucked[frame] = nil end
    elseif not tucked[frame] then
        tuckParent = tuckParent or CreateFrame("Frame")
        tuckParent:Hide()
        tucked[frame] = frame:GetParent()
        frame:SetParent(tuckParent)
    end
end

local function st(cf)
    local s = state[cf]
    if not s then s = { hidden = {} }; state[cf] = s end
    return s
end

-- Blizzard's window textures (CHAT_FRAME_TEXTURES: background and the eight border pieces). They are faded
-- with UIFrameFade only while shown, so a hidden piece stays hidden.
local function windowTextures(cf, show)
    local s = st(cf)
    for _, piece in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local tex = _G[cf:GetName() .. piece]
        if tex then
            if show then
                if s.hidden[tex] then tex:Show(); s.hidden[tex] = nil end
            elseif tex:IsShown() then
                s.hidden[tex] = true
                tex:Hide()
            end
        end
    end
end

local EDITBOX_TEXTURES = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }

local function editBoxTextures(box, show)
    local name = box:GetName()
    for _, piece in ipairs(name and EDITBOX_TEXTURES or {}) do
        local tex = _G[name .. piece]
        if tex then tex:SetAlpha(show and 1 or 0) end
    end
end

-- Edit box above the tabs, or Blizzard's own place under the window.
local function placeEditBox(cf, s, restore)
    local box = cf.editBox
    if not box then return end
    if not s.points then
        s.points = {}
        for i = 1, box:GetNumPoints() do s.points[i] = { box:GetPoint(i) } end
    end
    box:ClearAllPoints()
    if not restore and M.db.editBoxTop then
        box:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -5, 24)
        box:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 5, 24)
    else
        for _, p in ipairs(s.points) do box:SetPoint(unpack(p)) end
    end
end

local function styleEditBox(cf, restore)
    local box = cf.editBox
    if not box then return end
    local db, on = M.db, not restore
    if on and db.skinEditBox then
        editBoxTextures(box, false)
        Skin:Backdrop(box, db.background, "bg.sunken")
        Skin:BorderSpec(box, db.border, "border.default")
    elseif box.phoenixStyled then
        editBoxTextures(box, true)
        Skin:Backdrop(box, { alpha = 0 })
        Skin:BorderSpec(box, { style = "none", shadow = "none" })
    end
    box.phoenixStyled = on and db.skinEditBox or nil
    if on and db.styleText then
        Skin:TextSpec(box, db.editBox, "body")
        if box.header then Skin:TextSpec(box.header, db.editBox, "body") end
    end
end

---------------------------------------------------------------- jump to bottom
function M:UpdateScrollButton(cf)
    local s = state[cf]
    local b = s and s.jump
    if not b then return end
    b:SetShown(self:IsEnabled() and self.db.scrollButton and not cf:AtBottom())
end

local function jumpButton(cf, s)
    if s.jump then return s.jump end
    local b = W:IconButton(cf, "arrow-down", 18, L.CHAT_JUMP, L.CHAT_JUMP_DESC)
    b:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 2, -2)
    b:SetFrameLevel(cf:GetFrameLevel() + 6)
    b.onClick = function() cf:ScrollToBottom(); b:Hide() end
    b:Hide()
    s.jump = b
    return b
end

---------------------------------------------------------------- window
function M:StyleWindow(cf)
    if not (cf and cf.GetName) then return end
    local db, s = self.db, st(cf)
    if db.skinWindows then
        if not s.bg then
            s.bg = CreateFrame("Frame", nil, cf)
            s.bg:SetPoint("TOPLEFT", cf, "TOPLEFT", -4, 4)
            s.bg:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 4, -6)
        end
        s.bg:SetFrameLevel(math.max(0, cf:GetFrameLevel() - 1))
        Skin:Backdrop(s.bg, db.background, "bg.sunken")
        Skin:BorderSpec(s.bg, db.border, "border.default")
        s.bg:Show()
        windowTextures(cf, false)
    else
        if s.bg then s.bg:Hide() end
        windowTextures(cf, true)
    end
    cf:SetFading(db.fade)
    cf:SetTimeVisible(math.max(5, db.fadeAfter or 120))
    if (db.maxLines or 0) > 0 and cf:GetMaxLines() ~= db.maxLines then cf:SetMaxLines(db.maxLines) end
    tuck(cf.buttonFrame, db.sideButtons)
    jumpButton(cf, s)
    tuck(cf.ScrollToBottomButton, not db.scrollButton)
    self:UpdateScrollButton(cf)
    placeEditBox(cf, s)
    styleEditBox(cf)
    if cf == DEFAULT_CHAT_FRAME then
        for _, f in ipairs({ ChatFrameMenuButton, ChatFrameChannelButton, QuickJoinToastButton,
            ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton }) do
            tuck(f, db.sideButtons)
        end
    end
end

---------------------------------------------------------------- tabs
-- Selected tab label in its own colour (FCFTab_UpdateColors post-hook, via Chat.lua's tab state).
function M:StyleSelectedTab(tab, cf)
    local color = self.db.selectedTabColor
    local fs = tab.GetFontString and tab:GetFontString()
    if type(color) ~= "table" or not fs then return end
    local selected = not cf.isDocked or (FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == cf)
    if selected then fs:SetTextColor(Skin:SpecColor(color, "accent.primary")) end
end

-- Tabs that stay visible: after Blizzard picks a tab's alphas, the idle one becomes the mouse-over one.
-- ChatFrameUtil.SetTabAlphas is the game's addon-safe store for exactly this (kept off the tab frame).
local function tabAlpha(cf)
    if not (M:IsEnabled() and not M.db.fadeTabs and cf and cf.GetName) then return end
    local tab = _G[cf:GetName() .. "Tab"]
    if not tab then return end
    local over = ChatFrameUtil.GetTabAlphas(tab)
    if type(over) ~= "number" then return end
    ChatFrameUtil.SetTabAlphas(tab, over, over)
    tab:SetAlpha(over)
end
M.TabAlpha = tabAlpha

---------------------------------------------------------------- hide in combat
local hiddenForCombat = false
local function combatAlpha(hide)
    hiddenForCombat = hide
    ChatFrameUtil.ForEachChatFrame(function(cf)
        local typing = cf.editBox and cf.editBox:HasFocus()
        cf:SetAlpha((hide and not typing) and 0 or 1)
        local tab = _G[cf:GetName() .. "Tab"]
        if tab then tab:SetAlpha(hide and 0 or 1) end
    end)
end
M.CombatAlpha = combatAlpha

local function onCombat(_, event)
    if not (M:IsEnabled() and M.db.hideInCombat) then
        if hiddenForCombat then combatAlpha(false) end
        return
    end
    combatAlpha(event == "PLAYER_REGEN_DISABLED")
end

function M:HookWindows()
    if FCFTab_UpdateAlpha then hooksecurefunc("FCFTab_UpdateAlpha", tabAlpha) end
    ns.Events:On("PLAYER_REGEN_DISABLED", self, onCombat)
    ns.Events:On("PLAYER_REGEN_ENABLED", self, onCombat)
    -- typing in combat shows the window while its edit box has focus
    ChatFrameUtil.ForEachChatFrame(function(cf)
        local box = cf.editBox
        if box then
            box:HookScript("OnEditFocusGained", function() if hiddenForCombat then cf:SetAlpha(1) end end)
            box:HookScript("OnEditFocusLost", function() if hiddenForCombat then cf:SetAlpha(0) end end)
        end
    end)
end

function M:RestoreWindows()
    if hiddenForCombat then combatAlpha(false) end
    for cf, s in pairs(state) do
        if s.bg then s.bg:Hide() end
        if s.jump then s.jump:Hide() end
        windowTextures(cf, true)
        placeEditBox(cf, s, true)
        styleEditBox(cf, true)
    end
    for frame in pairs(tucked) do tuck(frame, true) end
end
