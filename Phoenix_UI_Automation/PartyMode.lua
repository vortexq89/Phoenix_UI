-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local M = ns.modules.Automation

--[[ Party mode: coloured lights wash in from the screen edges for a few seconds. Start it with the button, or let
    a boss kill, a timed Mythic+ key or a level up start it. A session you started yourself is never ended by a
    trigger. Colours step on a C_Timer ticker (no OnUpdate); the overlay never takes the mouse. ]]

local PALETTE = {
    { 1, 0.35, 0.1 }, { 1, 0.8, 0.15 }, { 0.3, 1, 0.45 }, { 0.2, 0.7, 1 }, { 0.75, 0.35, 1 }, { 1, 0.3, 0.7 },
}
M.PARTY_PALETTE = PALETTE

local overlay, ticker, stopTimer
M.party = { on = false, manual = false, step = 0 }

local function build()
    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints(); overlay:SetFrameStrata("FULLSCREEN_DIALOG"); overlay:EnableMouse(false)
    overlay.edges = {}
    local function edge(p1, p2, horizontal, flip)
        local t = overlay:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint(p1); t:SetPoint(p2)
        t.horizontal, t.flip = horizontal, flip
        overlay.edges[#overlay.edges + 1] = t
        return t
    end
    edge("TOPLEFT", "TOPRIGHT", true, false); edge("BOTTOMLEFT", "BOTTOMRIGHT", true, true)
    edge("TOPLEFT", "BOTTOMLEFT", false, false); edge("TOPRIGHT", "BOTTOMRIGHT", false, true)
    overlay:Hide()
end

-- paint step n: each edge gets the next palette colour, fading towards the screen centre
function M.PartyPaint(n, strength)
    if not overlay then build() end
    local size = math.floor(80 + 120 * strength)
    for i, t in ipairs(overlay.edges) do
        local c = PALETTE[(n + i - 1) % #PALETTE + 1]
        local a = 0.25 + 0.5 * strength
        if t.horizontal then t:SetHeight(size) else t:SetWidth(size) end
        local from, to = CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], 0)
        if t.horizontal then
            if t.flip then t:SetGradient("VERTICAL", from, to) else t:SetGradient("VERTICAL", to, from) end
        else
            if t.flip then t:SetGradient("HORIZONTAL", to, from) else t:SetGradient("HORIZONTAL", from, to) end
        end
    end
    return overlay
end

function M:StopParty()
    if ticker then ticker:Cancel(); ticker = nil end
    if stopTimer then stopTimer:Cancel(); stopTimer = nil end
    if overlay then overlay:Hide() end
    M.party.on, M.party.manual = false, false
end

-- manual = true: stays on until stopped (button); otherwise ends after db.partyDuration seconds
function M:StartParty(manual)
    if M.party.on and M.party.manual and not manual then return end -- a trigger never ends a manual session
    local db = self.db
    if stopTimer then stopTimer:Cancel(); stopTimer = nil end
    M.party.on, M.party.manual = true, manual and true or false
    local strength = (tonumber(db.partyStrength) or 60) / 100
    M.PartyPaint(M.party.step, strength):Show()
    if not ticker then
        ticker = C_Timer.NewTicker(0.35, function()
            M.party.step = M.party.step + 1
            M.PartyPaint(M.party.step, (tonumber(M.db.partyStrength) or 60) / 100)
        end)
    end
    if db.partySound and PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE then
        pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    end
    if not manual then stopTimer = C_Timer.NewTimer(tonumber(db.partyDuration) or 6, function() M:StopParty() end) end
end

function M:ToggleParty()
    if M.party.on then self:StopParty() else self:StartParty(true) end
end

local owner = {}
function M:EnableParty()
    ns.Events:On("ENCOUNTER_END", owner, function(_, _, _, _, _, success)
        if M.db.partyBoss and success == 1 then M:StartParty(false) end
    end)
    ns.Events:On("CHALLENGE_MODE_COMPLETED", owner, function()
        if M.db.partyMplus then M:StartParty(false) end
    end)
    ns.Events:On("PLAYER_LEVEL_UP", owner, function()
        if M.db.partyLevel then M:StartParty(false) end
    end)
end
