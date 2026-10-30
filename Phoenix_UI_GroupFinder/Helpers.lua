local _, ns = ...
local L = ns.L
local Skin = ns.Skin
local M = ns:GetModule("GroupFinder")

--[[ Sign-up helpers. Each one ends in a click on Blizzard's own button, made by the secure action code
    (SecureActionButtonTemplate, type "click": SecureTemplates.lua SECURE_ACTIONS.click), started by your own
    mouse click or key press. Phoenix never calls a sign-up or role-check function itself.
      * Quick sign-up: after you select a group (Blizzard's click), a secure button covers that entry; clicking
        it again clicks Blizzard's Sign Up. Right-click still opens Blizzard's menu for the entry.
      * Enter to sign up: while the list is open, Enter clicks Sign Up (or the dialog's Sign Up when it is
        shown), through an override binding to our secure button.
      * Role checks: a key you choose clicks Accept on Blizzard's role-check window while it is shown.
    Bindings and secure attributes only change out of combat; a holder state driver hides the overlay in
    combat. Not built: auto sign-up and auto-accepting role checks without input (the brief and taint rules),
    and remembering the sign-up note (Blizzard's note box refuses SetText from addons:
    LFGListApplicationDialog Description EditBox:SetSecurityDisableSetText). ]]
local holder, quick, enter, role
local owner = CreateFrame("Frame") -- owns our override bindings

local function secureButton(name, parent)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "click")
    return b
end

local function build()
    if holder or InCombatLockdown() then return end
    holder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    holder:SetAllPoints()
    RegisterStateDriver(holder, "visibility", "[combat] hide; show")
    quick = secureButton("PhoenixUI_GroupFinderSignUp", holder)
    quick:SetFrameStrata("HIGH")
    quick:Hide()
    quick.hint = quick:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    quick.hint:SetPoint("BOTTOMLEFT", 10, 4)
    quick.glow = CreateFrame("Frame", nil, quick)
    quick.glow:SetPoint("TOPLEFT", 3, -2)
    quick.glow:SetPoint("BOTTOMRIGHT", -3, 0)
    -- our own tooltip: running Blizzard's entry OnEnter from addon code would taint the list
    quick:SetScript("OnEnter", function(self)
        local entry = self.entry
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 25, 0)
        local a = M.Activity((M:Record(entry.resultID) or {}).activityID)
        GameTooltip:AddLine(a and a.fullName or L.GROUPFINDER, 1, 0.82, 0)
        M:AddMembers(GameTooltip, entry.resultID)
        M:AddTooltipLines(GameTooltip, entry.resultID)
        GameTooltip:AddLine(L.LFG_QUICK_TIP, 0.25, 0.81, 0.44, true)
        GameTooltip:Show()
    end)
    quick:SetScript("OnLeave", function() GameTooltip:Hide() end)
    enter = secureButton("PhoenixUI_GroupFinderEnter", holder)
    role = secureButton("PhoenixUI_GroupFinderRoleCheck", holder)
end

local function signUpButton()
    local search = LFGListFrame and LFGListFrame.SearchPanel
    return search and search.SignUpButton
end

---------------------------------------------------------------- quick sign-up over the selected entry
function M:PlaceQuick(entry)
    if not quick or InCombatLockdown() then return end
    local db = self.db
    if not (db.quickSignUp and entry and entry:IsVisible()) then
        quick:Hide()
        quick.entry = nil
        return
    end
    quick.entry = entry
    quick:ClearAllPoints()
    quick:SetAllPoints(entry)
    quick:SetFrameLevel(entry:GetFrameLevel() + 20)
    quick:SetAttribute("clickbutton", signUpButton())
    quick:SetAttribute("type2", "click")
    quick:SetAttribute("clickbutton2", entry)
    Skin:Text(quick.hint, "small", "accent.primary", 10, "OUTLINE")
    quick.hint:SetText(L.LFG_QUICK_HINT)
    Skin:BorderSpec(quick.glow, { style = "ember", size = 1, color = false, shadow = "none" }, "accent.primary")
    quick:Show()
end

-- After Blizzard paints an entry: cover the selected one (and only that one).
function M:TrackSelection(entry)
    local search = LFGListFrame and LFGListFrame.SearchPanel
    if not search or not quick then return end
    local selected = search.selectedResult
    if entry.resultID == selected and selected ~= nil then
        self:PlaceQuick(entry)
    elseif quick.entry == entry or (quick.entry and quick.entry.resultID ~= selected) then
        self:PlaceQuick(nil)
    end
end

---------------------------------------------------------------- key bindings
local function bindEnter(active)
    if InCombatLockdown() or not enter then return end
    ClearOverrideBindings(owner)
    M.bound = nil
    if active and M.db.enterSignUp then
        local dialog = LFGListApplicationDialog
        local target = (dialog and dialog:IsShown()) and dialog.SignUpButton or signUpButton()
        if target then
            enter:SetAttribute("clickbutton", target)
            SetOverrideBindingClick(owner, true, "ENTER", enter:GetName(), "LeftButton")
            M.bound = "ENTER"
        end
    end
    if M.roleShown and M.db.roleCheckKey ~= "off" then
        local accept = _G.LFDRoleCheckPopupAcceptButton
        if accept then
            role:SetAttribute("clickbutton", accept)
            SetOverrideBindingClick(owner, true, M.db.roleCheckKey, role:GetName(), "LeftButton")
        end
    end
end

function M:RefreshHelpers()
    local search = LFGListFrame and LFGListFrame.SearchPanel
    ns.Combat:Run("groupfinder.bind", bindEnter, search and search:IsVisible() or false)
    if quick and quick.entry then self:PlaceQuick(quick.entry) end
end

local hooked
function M:EnableHelpers()
    build()
    if not holder then
        ns.Events:On("PLAYER_REGEN_ENABLED", self, function() build(); self:RefreshHelpers() end)
    end
    ns.Events:On("LFG_ROLE_CHECK_SHOW", self, function() self.roleShown = true; self:RefreshHelpers() end)
    ns.Events:On("LFG_ROLE_CHECK_HIDE", self, function() self.roleShown = false; self:RefreshHelpers() end)
    if hooked then return end
    local search = LFGListFrame and LFGListFrame.SearchPanel
    if not search then return end
    hooked = true
    local refresh = function() if M:IsEnabled() then M:RefreshHelpers() end end
    search:HookScript("OnShow", refresh)
    search:HookScript("OnHide", function()
        if M:IsEnabled() then M:PlaceQuick(nil); M:RefreshHelpers() end
    end)
    if LFGListApplicationDialog then
        LFGListApplicationDialog:HookScript("OnShow", refresh)
        LFGListApplicationDialog:HookScript("OnHide", refresh)
    end
    hooksecurefunc("LFGListSearchEntry_Update", function(entry)
        if M:IsEnabled() then pcall(M.TrackSelection, M, entry) end
    end)
end

function M:DisableHelpers()
    ns.Combat:Run("groupfinder.bind", function() ClearOverrideBindings(owner) end)
    if quick and not InCombatLockdown() then quick:Hide() end
end
