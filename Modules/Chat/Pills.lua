local _, ns = ...
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Chat")

--[[ Chat skin, plan window 3: tabs as Phoenix pills (the selected one outlined and tinted in the accent, an
    accent dot while a tab has unread messages) and a left bar on the edit box in the colour of the channel you
    are typing in. Blizzard's tab art is faded with alpha and our pill sits on a child frame of the tab, so tab
    dragging, docking, renaming and fading stay Blizzard's (our pill fades with the tab). Repainted live on theme
    change and on the Chat > Pill tabs switch; switching it off brings Blizzard's tab art back at once. ]]

local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight", "leftSelectedTexture", "middleSelectedTexture",
    "rightSelectedTexture", "leftHighlightTexture", "middleHighlightTexture", "rightHighlightTexture" }

local pills = setmetatable({}, { __mode = "k" }) -- [tab] = our pill frame
local bars = setmetatable({}, { __mode = "k" })  -- [edit box] = our channel bar

local function artOf(tab)
    local out = {}
    for _, k in ipairs(TAB_ART) do
        local r = tab[k]
        if type(r) == "table" and r.SetAlpha then out[#out + 1] = r end
    end
    return out
end

-- "selected" | "alert" | "idle" for a tab of a chat frame.
function M.PillState(selected, alerting)
    if selected then return "selected" end
    if alerting then return "alert" end
    return "idle"
end

local function selectedOf(cf)
    if not cf then return false end
    if not cf.isDocked then return true end
    return FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == cf or false
end

function M:StylePill(tab, cf)
    if not tab then return end
    local on = self:IsEnabled() and self.db.pillTabs
    local p = pills[tab]
    if not on then
        if p then
            p:Hide()
            for _, r in ipairs(artOf(tab)) do Skin:Restore(r) end
        end
        return
    end
    if not p then
        p = CreateFrame("Frame", nil, tab)
        p:SetPoint("TOPLEFT", 2, -6); p:SetPoint("BOTTOMRIGHT", -2, 2)
        p:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 1))
        p.dot = W.Texture(p, "OVERLAY", 2, ns.Media.textures.CIRCLE)
        p.dot:SetSize(6, 6)
        p.dot:SetPoint("TOPRIGHT", -3, -3)
        pills[tab] = p
        Skin:Register(p, function() M:StylePill(tab, cf) end)
    end
    for _, r in ipairs(artOf(tab)) do Skin:HideRegion(r) end
    p:Show()
    local alerting = ChatFrameUtil and ChatFrameUtil.IsTabAlerting and ChatFrameUtil.IsTabAlerting(tab)
    local s = M.PillState(selectedOf(cf), alerting)
    Skin:Panel(p, s == "selected" and "raised" or "sunken",
        { border = s == "selected" and "accent.primary" or "border.subtle", inset = 1 })
    if s == "selected" then Skin:SetPanelColor(p, "accent.soft") end
    W.Color(p.dot, "accent.primary", 1)
    p.dot:SetShown(s == "alert")
end

-- Channel colour of an edit box's current chat type (ChatTypeInfo, the game's own colours).
function M.ChannelColor(chatType, channelTarget)
    local info = ChatTypeInfo and chatType and ChatTypeInfo[chatType]
    if chatType == "CHANNEL" and channelTarget and ChatTypeInfo then
        info = ChatTypeInfo["CHANNEL" .. tostring(channelTarget)] or info
    end
    if info and info.r then return info.r, info.g, info.b end
    return nil
end

function M:StyleEditBar(box)
    if not box then return end
    local on = self:IsEnabled() and self.db.pillTabs
    local bar = bars[box]
    if not on then if bar then bar:Hide() end; return end
    if not bar then
        bar = box:CreateTexture(nil, "OVERLAY", nil, 3)
        bar:SetTexture(ns.Media.textures.WHITE)
        bar:SetWidth(2)
        bar:SetPoint("TOPLEFT", 2, -3); bar:SetPoint("BOTTOMLEFT", 2, 3)
        bars[box] = bar
    end
    local r, g, b = M.ChannelColor(box:GetAttribute("chatType"), box:GetAttribute("channelTarget"))
    if r then bar:SetVertexColor(r, g, b, 1) else W.Color(bar, "accent.primary", 1) end
    bar:Show()
end

function M:RefreshPills()
    if not (ChatFrameUtil and ChatFrameUtil.ForEachChatFrame) then return end
    ChatFrameUtil.ForEachChatFrame(function(cf)
        self:StylePill(_G[cf:GetName() .. "Tab"], cf)
        self:StyleEditBar(cf.editBox)
    end)
end

local pillHooks
function M:HookPills()
    if pillHooks then return end
    pillHooks = true
    if _G.ChatEdit_UpdateHeader then
        hooksecurefunc("ChatEdit_UpdateHeader", function(box) M:StyleEditBar(box) end)
    end
    if _G.FCF_StopAlertFlash then
        hooksecurefunc("FCF_StopAlertFlash", function(cf)
            if cf and cf.GetName then M:StylePill(_G[cf:GetName() .. "Tab"], cf) end
        end)
    end
    if _G.FCF_Tab_OnClick then
        hooksecurefunc("FCF_Tab_OnClick", function() M:RefreshPills() end)
    end
end
