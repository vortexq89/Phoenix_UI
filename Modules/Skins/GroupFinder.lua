local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Group Finder / PvE / PvP, skins plan window 7 (window chrome and tabs: the shared window skin): premade
    search results and applicants as Phoenix rows (selected outlined in the accent), the dungeon and raid
    lists as rows, PvP's queue buttons and the dungeon-ready dialog as Phoenix buttons (Enter primary, Leave
    secondary) on a Phoenix dialog card. Queue / sign-up / enter clicks stay Blizzard's own. Live both ways
    with Skins > Group Finder. ]]

local function on() return M:IsEnabled() and M.db.groupFinder and true or false end
M.GroupFinderOn = on

local function lists()
    local out = {}
    local lfg = _G.LFGListFrame
    if lfg then
        out[#out + 1] = M.FramePath(lfg, { "SearchPanel", "ScrollBox" })
        out[#out + 1] = M.FramePath(lfg, { "ApplicationViewer", "ScrollBox" })
        out[#out + 1] = M.FramePath(lfg, { "CategorySelection", "ScrollBox" })
    end
    local lfd = _G.LFDQueueFrame
    if lfd then out[#out + 1] = M.FramePath(lfd, { "Specific", "ScrollBox" }) end
    return out
end

function M:SkinGroupFinder()
    local isOn = on()
    for _, box in pairs(lists()) do M.KitScrollBox(box, on, function(row, o) M.KitRow(row, o) end) end
    local ready = _G.LFGDungeonReadyDialog
    if ready then
        if isOn then M.SkinWindow(ready, true) else M.UnskinWindow(ready) end
        M.SkinPopupButton(ready.enterButton or _G.LFGDungeonReadyDialogEnterDungeonButton, "primary", isOn)
        M.SkinPopupButton(ready.leaveButton or _G.LFGDungeonReadyDialogLeaveQueueButton, "secondary", isOn)
    end
    M.SkinPopupButton(_G.LFDQueueFrameFindGroupButton, "primary", isOn)
    M.SkinPopupButton(_G.RaidFinderFrameFindRaidButton, "primary", isOn)
    local pvp = _G.HonorFrame
    if pvp then M.SkinPopupButton(pvp.QueueButton, "primary", isOn) end
    local conq = _G.ConquestFrame
    if conq then M.SkinPopupButton(conq.JoinButton, "primary", isOn) end
    self:ReadyRing(isOn, false)
    self:RatingCards(isOn)
    self:SearchChips(isOn)
end

---------------------------------------------------------------- details
-- Role ring timer: a Cooldown (native swipe animation, no OnUpdate) around the role icon of the ready
-- dialog, in the accent, counting the proposal's 40 seconds.
M.PROPOSAL_SECONDS = 40
local ringTimer
function M:ReadyRing(isOn, start)
    local ready = _G.LFGDungeonReadyDialog
    local icon = ready and (ready.roleIcon or _G.LFGDungeonReadyDialogRoleIcon)
    if type(icon) ~= "table" or not icon.GetObjectType then return end
    if not isOn then if ringTimer then ringTimer:Hide() end; return end
    if not ringTimer then
        ringTimer = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        ringTimer:SetPoint("TOPLEFT", -4, 4); ringTimer:SetPoint("BOTTOMRIGHT", 4, -4)
        ringTimer:SetSwipeTexture(ns.Media.textures.RING_CIRCLE)
        ringTimer:SetDrawEdge(false)
        ringTimer:SetHideCountdownNumbers(false)
    end
    local r, g, b = ns.Theme:Color("accent.primary")
    ringTimer:SetSwipeColor(r, g, b, 0.9)
    if start then ringTimer:SetCooldown(GetTime(), M.PROPOSAL_SECONDS) end
    ringTimer:Show()
end

-- Rated PvP: the bracket buttons as rating cards, the picked one outlined in the accent.
M.RATED_BUTTONS = { "Arena2v2", "Arena3v3", "RatedBG", "RatedSoloShuffle", "RatedBGBlitz" }
function M:RatingCards(isOn)
    local conq = _G.ConquestFrame
    if not conq then return end
    for _, key in ipairs(self.RATED_BUTTONS) do
        local b = conq[key]
        local card = M.KitCard(b, isOn, "raised", false)
        if card and isOn then
            ns.Skin:SetBorderColor(card, M.RowSelected(b) and "accent.primary" or "border.subtle")
        end
    end
end

-- Premade search chips: your last searches as chips under the search box; a click puts the text back in
-- the box (you still press Search / Enter yourself, so the search stays your own action).
M.CHIP_MAX = 6
function M.RememberSearch(list, text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return list end
    for i = #list, 1, -1 do if list[i] == text then table.remove(list, i) end end
    table.insert(list, 1, text)
    while #list > M.CHIP_MAX do table.remove(list) end
    return list
end

local chipBar
function M:SearchChips(isOn)
    local panel = M.FramePath(_G.LFGListFrame, { "SearchPanel" })
    local box = panel and panel.SearchBox
    if type(box) ~= "table" or not box.GetObjectType then return end
    if not isOn then if chipBar then chipBar:Hide() end; return end
    self.db.premadeSearches = self.db.premadeSearches or {}
    local W = ns.Widgets
    if not chipBar then
        chipBar = CreateFrame("Frame", nil, panel)
        chipBar:SetHeight(18)
        chipBar:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -4)
        chipBar.chips = {}
        box:HookScript("OnEnterPressed", function(self)
            M.RememberSearch(M.db.premadeSearches, self:GetText()); M:SearchChips(true)
        end)
    end
    local prev
    for i = 1, M.CHIP_MAX do
        local text = self.db.premadeSearches[i]
        local c = chipBar.chips[i]
        if text and not c then
            c = CreateFrame("Button", nil, chipBar)
            c.label = W.Text(c, "small", "text.secondary", "CENTER")
            c.label:SetPoint("CENTER")
            c:SetScript("OnClick", function(self) box:SetText(self.text); box:SetFocus() end)
            chipBar.chips[i] = c
        end
        if c then
            c:SetShown(text ~= nil)
            if text then
                c.text = text
                c.label:SetText(text)
                c:SetSize(math.max(30, (c.label:GetStringWidth() or 30) + 12), 18)
                c:ClearAllPoints()
                if prev then c:SetPoint("LEFT", prev, "RIGHT", 3, 0) else c:SetPoint("LEFT") end
                ns.Skin:Panel(c, "sunken", { border = "border.subtle" })
                prev = c
            end
        end
    end
    chipBar:Show()
end

local gfHooked, readyHooked
function M:SetupGroupFinder()
    self:SkinGroupFinder()
    if not readyHooked then
        readyHooked = true
        ns.Events:On("LFG_PROPOSAL_SHOW", self, function() M:SkinGroupFinder(); M:ReadyRing(on(), true) end)
    end
    if gfHooked or not _G.PVEFrame then return end
    gfHooked = true
    _G.PVEFrame:HookScript("OnShow", function() M:SkinGroupFinder() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupGroupFinder"
M.RESKINS[#M.RESKINS + 1] = "SkinGroupFinder"
