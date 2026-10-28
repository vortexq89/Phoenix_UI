local _, ns = ...
local Skin = ns.Skin
local M = ns:GetModule("Skins")

--[[ Talents & spellbook, skins plan window 8 (window chrome and the main tabs: shared window skin): the talent
    tree background darkened behind a Phoenix vignette, a 1 px ring around every talent node (accent when the
    node has points, subtle when not; node icons untouched), and the spellbook's category tabs as Phoenix tabs.
    Talent choices, loadouts and drag to bars stay Blizzard's. Live with Skins > Talents & spellbook. ]]

local rings = setmetatable({}, { __mode = "k" })
local vignette

local function on() return M:IsEnabled() and M.db.spellbook and true or false end

-- Ring colour for a node from its plain node info (ranks are not secret values).
function M.NodeRingToken(info)
    if type(info) ~= "table" then return "border.subtle" end
    local rank = tonumber(info.activeRank) or tonumber(info.currentRank) or 0
    return rank > 0 and "accent.primary" or "border.subtle"
end

local function ringFor(button, isOn)
    local r = rings[button]
    if not isOn then if r then r:Hide() end; return end
    if not r then
        r = CreateFrame("Frame", nil, button)
        r:SetPoint("TOPLEFT", -1, 1); r:SetPoint("BOTTOMRIGHT", 1, -1)
        r:SetFrameLevel(button:GetFrameLevel() + 2)
        Skin:Border(r, "border.subtle")
        rings[button] = r
    end
    local info = button.GetNodeInfo and select(2, pcall(button.GetNodeInfo, button)) or button.nodeInfo
    Skin:SetBorderColor(r, M.NodeRingToken(info))
    r:Show()
end
M.TalentRing = ringFor

function M:SkinTalents()
    local psf = _G.PlayerSpellsFrame
    if not psf then return end
    local isOn = on()
    local tf = psf.TalentsFrame
    if tf then
        if isOn and not vignette then
            vignette = tf:CreateTexture(nil, "BACKGROUND", nil, 7)
            vignette:SetTexture(ns.Media.textures.WHITE)
            vignette:SetAllPoints()
        end
        if vignette then
            vignette:SetShown(isOn)
            Skin:Gradient(vignette, "VERTICAL", "bg.base", "bg.base", 0.65, 0.35)
        end
        if tf.EnumerateAllTalentButtons then
            local n = 0
            for button in tf:EnumerateAllTalentButtons() do
                n = n + 1
                if n > 600 or type(button) ~= "table" then break end -- a tree has ~120 nodes; never loop forever
                ringFor(button, isOn)
            end
        end
    end
    local sb = psf.SpellBookFrame
    local ts = sb and sb.CategoryTabSystem
    if ts and type(ts.tabs) == "table" then
        for _, tab in ipairs(ts.tabs) do
            if isOn then M.PaintTab(tab) else Skin:Restore(tab) end
        end
    end
end

local talentsHooked
function M:SetupTalents()
    self:SkinTalents()
    local psf = _G.PlayerSpellsFrame
    if talentsHooked or not psf then return end
    talentsHooked = true
    psf:HookScript("OnShow", function() M:SkinTalents() end)
    local function later() if psf:IsShown() and C_Timer then C_Timer.After(0, function() M:SkinTalents() end) end end
    ns.Events:On("TRAIT_CONFIG_UPDATED", self, later)
    ns.Events:On("TRAIT_NODE_CHANGED", self, later)
    ns.Events:Listen("PUI_THEME_CHANGED", rings, function() if psf:IsShown() then M:SkinTalents() end end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupTalents"
M.RESKINS[#M.RESKINS + 1] = "SkinTalents"
