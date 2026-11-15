local _, ns = ...
local L = ns.L
local Skin = ns.Skin

--[[ PvP: safer queue pops (no accidental "Leave Queue", visible timer), TAB targets enemy players
    inside arenas/battlegrounds, and /gg to surrender an arena. Arena dampening display was removed:
    it relied on combat-log/aura data that 12.x restricts.
    S16: the countdown is its own toggle with a font, and a queue pop sound plays on the chosen channel (so
    it is heard with game sound off when the channel is Master). Arena frames, objective placement and
    battleground auto release stay on their own pages (Unit Frames, Movers, Automation) and are linked.
    S18: a Shadowsight timer for arenas — the eyes spawn a fixed time after the gates open; the match clock
    (C_PvP.GetActiveMatchDuration, counting from the Engaged state) gives the countdown. Retail only (feature
    "arena"); its own Layout-mode mover. ]]
local M = ns:NewModule("PvP", {
    label = "PVP", desc = "PVP_DESC", category = "combat", order = 50, reloadOnToggle = true,
    defaults = {
        safeQueue = true, showTimer = true, tabBinder = false, surrender = true, queueSound = "",
        timer = ns.Style.Text(14, { outline = "OUTLINE", shadow = false }),
        shadowsight = { enabled = false, delay = 90, shown = 15, point = "TOP", x = 0, y = -120,
                        text = ns.Style.Text(14, { outline = "OUTLINE", shadow = false }) },
    },
})

---------------------------------------------------------------- safe queue
local timer
local function ensureTimer()
    if timer then return timer end
    timer = CreateFrame("Frame", nil, PVPReadyDialog)
    timer:SetSize(120, 18)
    timer:SetPoint("TOP", PVPReadyDialog, "BOTTOM", 0, -4)
    timer.text = timer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timer.text:SetPoint("CENTER", 9, 0)
    timer.icon = ns.Icons:Create(timer, "clock", 14, "accent.primary", "OVERLAY")
    timer.icon:SetPoint("RIGHT", timer.text, "LEFT", -5, 0)
    M:StyleTimer()
    -- the queue-pop countdown: a 5 Hz C_Timer ticker while the ready dialog shows (stops with it)
    local function tick()
        local index = PVPReadyDialog.activeIndex
        local left = index and GetBattlefieldPortExpiration(index)
        if left and left > 0 then timer.text:SetFormattedText(L.PVP_TIME_LEFT, left) else timer.text:SetText("") end
    end
    timer:SetScript("OnShow", function(self)
        if self.ticker then self.ticker:Cancel() end
        self.ticker = C_Timer.NewTicker(0.2, tick); tick()
    end)
    timer:SetScript("OnHide", function(self) if self.ticker then self.ticker:Cancel(); self.ticker = nil end end)
    if timer:IsVisible() then timer.ticker = C_Timer.NewTicker(0.2, tick); tick() end
    return timer
end

function M:StyleTimer(fs)
    fs = fs or (timer and timer.text)
    if fs then Skin:TextSpec(fs, self.db.timer, "number", "accent.primary") end
end

-- Runs after PVPReadyDialog_Display has laid out the buttons, so the Enter button is re-centred the
-- same way Blizzard does it for queues that never offer "Leave Queue".
local function onDisplay(dialog)
    if not M:IsEnabled() then return end
    if M.db.queueSound ~= "" then ns.Media:PlaySound(M.db.queueSound) end
    if M.db.showTimer then ensureTimer():Show() elseif timer then timer:Hide() end
    if not M.db.safeQueue then return end
    dialog.leaveButton:Hide()
    dialog.enterButton:ClearAllPoints()
    dialog.enterButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 25)
end

---------------------------------------------------------------- TAB binder
local TAB = "TAB"
local SAFE = { TARGETNEARESTENEMY = true, TARGETNEARESTENEMYPLAYER = true }

local function applyTab()
    if not M.db.tabBinder then return end
    local current = GetBindingAction(TAB)
    if current ~= "" and not SAFE[current] then return end -- never overwrite a custom bind
    local _, instanceType = IsInInstance()
    local want = (instanceType == "arena" or instanceType == "pvp") and "TARGETNEARESTENEMYPLAYER" or "TARGETNEARESTENEMY"
    if current ~= want then
        SetBinding(TAB, want)
        SaveBindings(GetCurrentBindingSet())
    end
end

---------------------------------------------------------------- surrender
local function surrender()
    if not M.db.surrender then return end
    if IsActiveBattlefieldArena() and C_PvP.CanSurrenderArena() then
        ConfirmSurrenderArena()
    else
        ns:Print(L.PVP_CANT_SURRENDER)
    end
end

M.Surrender = surrender -- the settings button and /gg share it

---------------------------------------------------------------- Shadowsight (arena)
local ENGAGED = Enum and Enum.PvPMatchState and Enum.PvPMatchState.Engaged or 3

-- The timer's text for `elapsed` seconds into the match: the countdown, "up" for `shown` seconds, then nothing.
function M.ShadowsightText(elapsed, delay, shown)
    if type(elapsed) ~= "number" then return nil end
    local left = delay - elapsed
    if left > 0 then return L.PVP_SHADOWSIGHT_IN:format(math.floor(left / 60), math.floor(left % 60)) end
    if left > -shown then return L.PVP_SHADOWSIGHT_UP end
    return nil
end

local sight
local function sightStore()
    return {
        active = function() return M:IsEnabled() and M.db.shadowsight.enabled and ns:Supports("arena") end,
        get = function() local c = M.db.shadowsight; return { point = c.point, x = c.x, y = c.y } end,
        set = function(v) local c = M.db.shadowsight; c.point, c.x, c.y = v.point or c.point, v.x or c.x, v.y or c.y end,
        apply = function() M:PlaceShadowsight() end,
        reset = function()
            local d, c = M.defaults.shadowsight, M.db.shadowsight
            c.point, c.x, c.y = d.point, d.x, d.y
            M:PlaceShadowsight()
        end,
    }
end

-- 5 Hz C_Timer ticker, running only while the frame shows and it is an arena (or the mover sample is up)
local sightTicker
local function inArena() return IsActiveBattlefieldArena and IsActiveBattlefieldArena() and true or false end
local function sightTick()
    local self = sight
    if not (self and self:IsShown() and (self.sample or inArena())) then
        if sightTicker then sightTicker:Cancel(); sightTicker = nil end
        if self then self.text:SetText(""); self.icon:SetShown(false) end
        return
    end
    local c = M.db.shadowsight
    local text
    if self.sample then
        text = M.ShadowsightText(52, c.delay, c.shown)
    elseif c.enabled and IsActiveBattlefieldArena and IsActiveBattlefieldArena() and C_PvP.GetActiveMatchState
        and C_PvP.GetActiveMatchState() == ENGAGED then
        text = M.ShadowsightText(C_PvP.GetActiveMatchDuration(), c.delay, c.shown)
    end
    self.text:SetText(text or "")
    self.icon:SetShown(text ~= nil)
end

function M:UpdateShadowsightTicker()
    if sightTicker or not sight then return end
    if sight:IsShown() and (sight.sample or inArena()) then
        sightTicker = C_Timer.NewTicker(0.2, sightTick)
        sightTick()
    end
end

function M:PlaceShadowsight()
    if not sight then return end
    local c = self.db.shadowsight
    sight:ClearAllPoints()
    sight:SetPoint(c.point, UIParent, c.point, c.x, c.y)
    Skin:TextSpec(sight.text, c.text, "number", "accent.primary")
    sight:SetShown(c.enabled and ns:Supports("arena"))
    self:UpdateShadowsightTicker()
end

local function buildShadowsight()
    sight = CreateFrame("Frame", "PhoenixUI_Shadowsight", UIParent)
    sight:SetSize(180, 22)
    sight.text = sight:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sight.text:SetPoint("CENTER", 10, 0)
    sight.icon = ns.Icons:Create(sight, "preview", 16, "accent.primary", "OVERLAY")
    sight.icon:SetPoint("RIGHT", sight.text, "LEFT", -5, 0)
    sight:SetScript("OnShow", function() M:UpdateShadowsightTicker() end)
    M.shadowsightFrame = sight
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("pvp.shadowsight", sight, L.PVP_SHADOWSIGHT, sightStore()) end
    M:PlaceShadowsight()
end

-- reloadOnToggle: OnEnable runs at most once per session.
function M:OnEnable()
    hooksecurefunc("PVPReadyDialog_Display", onDisplay)
    RegisterNewSlashCommand(surrender, "gg", "pvpgg")
    local function deferTab() ns.Combat:Run("pvp.tab", applyTab) end
    ns.Events:On("PLAYER_ENTERING_WORLD", self, deferTab)
    ns.Events:On("ZONE_CHANGED_NEW_AREA", self, function() deferTab(); M:UpdateShadowsightTicker() end)
    ns.Events:On("PVP_MATCH_STATE_CHANGED", self, function() M:UpdateShadowsightTicker() end)
    if ns:Supports("arena") then buildShadowsight() end
end

function M:Refresh()
    ns.Combat:Run("pvp.tab", applyTab)
    self:StyleTimer()
    self:PlaceShadowsight()
end
