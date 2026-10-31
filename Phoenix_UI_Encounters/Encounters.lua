local _, ns = ...
local L, Style, Media, Secret = ns.L, ns.Style, ns.Media, ns.Secret

--[[ Encounters: Phoenix's boss-mod layer for Midnight, built on what the game now provides itself.
    Blizzard sends every boss timer to C_EncounterTimeline and every boss alert through ENCOUNTER_WARNING;
    spell names, icons and texts are secret during an encounter, so Phoenix keeps no per-boss timer tables.
    It draws those events in its own style (Bars.lua, Warnings.lua) and only ever hands the secret fields to
    display sinks (SetText, SetTexture); durations, remaining time, state, source and severity are plain.
    It also owns the pull and break timers and the countdown voice (moved here from Auras & Cooldowns).

    One owner per timer: when BigWigs or DBM is loaded they draw the encounter bars and pulls, so Phoenix
    stands down there (no second set of bars, no second voice) and styles BigWigs' bars instead (BigWigs.lua).
    A client without the game's timeline or warnings (WoW Forever: both Blizzard addons load on "standard"
    only) keeps the pull and break timers, their bars and the countdown voice; the rest steps aside.
    Blizzard frames are never hidden, reparented or hooked: Phoenix turns Blizzard's view off through the same
    CVars the game's own settings use, remembers your value and puts it back when Phoenix stops drawing. ]]
local M = ns:NewModule("Encounters", {
    label = "ENCOUNTERS", desc = "ENCOUNTERS_DESC", category = "combat", order = 12, icon = "encounters",
    descWithout = { feature = "encounterTimeline", desc = "ENCOUNTERS_DESC_TIMERS" },
    defaults = {
        timeline = {
            display = "phoenix",            -- "phoenix": Phoenix bars, "blizzard": the game's timeline
            width = 260, height = 22, spacing = 4, grow = "UP", max = 8, horizon = 0,
            icon = true, texture = "", color = false, fill = "drain", spark = true,
            emphasize = true, emphasizeAt = 5, emphasizeColor = false,
            emphasizeMove = false, emphasizeScale = 1.25, -- emphasised bars in their own, bigger stack (BigWigs)
            rules = "", -- per-ability: "spellID=hide|emph|sound|count, …" (Bars.lua)
            background = Style.Background({ alpha = 0.7 }),
            border = Style.Border(),
            name = Style.Text(12, { shadow = true }),
            time = Style.Text(12, { shadow = true }),
        },
        warnings = {
            display = "phoenix",            -- "phoenix": Phoenix banner, "blizzard": the game's, "hidden": none
            icon = true,
            text = Style.Text(22, { outline = "OUTLINE", shadow = true }),
            sounds = { high = "blizzard", medium = "blizzard", low = "none" },
            lines = 3, flash = true, -- lines on the banner; screen-edge flash on critical warnings
        },
        countdown = { enabled = true, voice = "Jim", from = 5, pull = true, timers = true, bars = false },
        pull = { seconds = 10 },
        breaks = { minutes = 5, sync = true },
        bigwigs = true,
    },
    globalDefaults = { cvars = {} },
})

M.SEVERITY = { [0] = "low", [1] = "medium", [2] = "high" } -- Enum.EncounterEventSeverity
M.BREAK_ICON = 134376 -- fileID: Interface\Icons\INV_Misc_PocketWatch_01
M.PULL_ICON = 132337  -- fileID: Interface\Icons\Ability_Warrior_Charge

---------------------------------------------------------------- boss mods
-- BigWigs' loader and DBM's core are the always-loaded parts of each.
local BOSS_MODS = { "BigWigs", "DBM-Core" }
function M:BossMod()
    for _, name in ipairs(BOSS_MODS) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
end

-- The game runs its boss timeline / warnings on this client (ns.FEATURES).
local FEATURE = { timeline = "encounterTimeline", warnings = "encounterWarnings" }
function M:HasFeature(kind)
    return ns:Supports(FEATURE[kind])
end

-- Phoenix draws `kind` ("timeline" / "warnings") itself.
function M:Draws(kind)
    return self.active and self:HasFeature(kind) and self.db[kind].display == "phoenix" and not self:BossMod()
end

---------------------------------------------------------------- Blizzard CVars
local OWNED = { timeline = "encounterTimelineEnabled", warnings = "encounterWarningsEnabled" }
M.OWNED_CVARS = OWNED

local function setCVar(name, value) ns.Combat:Run("cvar." .. name, C_CVar.SetCVar, name, value) end

-- Turns Blizzard's view off while Phoenix replaces it (or hides warnings) and restores the player's own
-- value afterwards. A boss mod manages these CVars itself, so Phoenix leaves them alone while one is loaded.
function M:ApplyCVars()
    if self:BossMod() then return end
    local saved = self.global.cvars
    for kind, cvar in pairs(OWNED) do
        -- a client without this system (ns.FEATURES) has nothing of the game's to hide or restore
        if self:HasFeature(kind) then
            local replace = self.active and self.db[kind].display ~= "blizzard"
            if replace then
                if saved[kind] == nil then saved[kind] = C_CVar.GetCVar(cvar) or "1" end
                if C_CVar.GetCVar(cvar) ~= "0" then setCVar(cvar, "0") end
            elseif saved[kind] ~= nil then
                setCVar(cvar, saved[kind])
                saved[kind] = nil
            end
        end
    end
end

-- The options read and write the other Blizzard settings straight through C_CVar; the owned ones show the
-- player's own value while Phoenix holds them at 0.
function M:BlizzardValue(kind)
    local saved = self.global.cvars[kind]
    if saved ~= nil then return saved ~= "0" end
    return C_CVar.GetCVarBool(OWNED[kind])
end

-- encounterTimelineIconographyHiddenMask stores the *hidden* icon sets, one bit per Enum.EncounterTimelineIconSet.
function M:IconSetShown(set)
    return not C_CVar.GetCVarBitfield("encounterTimelineIconographyHiddenMask", set)
end

function M:SetIconSetShown(set, shown)
    ns.Combat:Run("cvar.iconset." .. set, C_CVar.SetCVarBitfield, "encounterTimelineIconographyHiddenMask", set, not shown)
end

---------------------------------------------------------------- countdown voice
local ticker
local function stopCountdown()
    if ticker then ticker:Cancel(); ticker = nil end
end
M.StopCountdown = stopCountdown
-- The pull / start voice is speaking (the bars' ability countdown waits for it).
function M.CountdownRunning() return ticker ~= nil end

-- Speaks from db.countdown.from down to 1 for a timer that ends `seconds` from now.
function M:StartCountdown(seconds)
    stopCountdown()
    local c = self.db.countdown
    if not (c.enabled and type(seconds) == "number" and seconds > 0) then return end
    local endsAt = GetTime() + seconds
    local last
    local function tick()
        local left = math.ceil(endsAt - GetTime() - 0.05)
        if left < 1 then stopCountdown(); return end
        if left ~= last and left <= c.from then
            last = left
            local path = Media:Voice(c.voice, left)
            if path then PlaySoundFile(path, "Master") end
        end
    end
    ticker = C_Timer.NewTicker(0.1, tick)
    tick()
end

-- The test button: a countdown from the chosen number right now.
function M:TestCountdown() self:StartCountdown(self.db.countdown.from + 0.5) end

local function plainNumber(v) return not Secret.IsSecret(v) and type(v) == "number" and v or nil end

-- START_PLAYER_COUNTDOWN(initiatedBy, timeRemaining, totalTime, informChat): /countdown and every boss mod's
-- pull. A boss mod speaks its own pull countdown, so Phoenix's voice and bar step aside while one is loaded.
local function onPlayerCountdown(_, _, _, timeRemaining, totalTime)
    if M:BossMod() then return end
    local left = plainNumber(timeRemaining)
    if M.db.countdown.pull then M:StartCountdown(left) end
    if left and M.Bars then M.Bars:StartTimer("pull", L.ENC_PULL_BAR, left, plainNumber(totalTime) or left, M.PULL_ICON) end
end

local function onCancelCountdown()
    stopCountdown()
    if M.Bars then M.Bars:StopTimer("pull") end
end

-- START_TIMER(timerType, timeRemaining, totalTime): Mythic+, arena and battleground starts.
local function onStartTimer(_, _, timerType, timeRemaining)
    if Secret.IsSecret(timerType) or not M.db.countdown.timers then return end
    if timerType == Enum.StartTimerType.PlayerCountdown then return end -- START_PLAYER_COUNTDOWN covers it
    M:StartCountdown(plainNumber(timeRemaining))
end

---------------------------------------------------------------- pull and break
local function canLead()
    return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- /pui pull [seconds] and the Pull button. C_PartyInfo.DoCountdown is restricted to hardware events, which a
-- slash command or a click is; 0 cancels a running pull. Every boss mod and the game's own timer show it.
function M:Pull(seconds)
    seconds = math.floor(tonumber(seconds) or self.db.pull.seconds)
    if not canLead() then ns:Print(L.ENC_NEED_LEAD); return false end
    if seconds < 0 or seconds > 60 then ns:Print(L.ENC_PULL_RANGE); return false end
    return C_PartyInfo.DoCountdown(seconds)
end

-- DBM's and BigWigs' shared break message (prefix "D5", "<name>-<realm>\t1\tBT\t<seconds>"), so a break sent
-- from Phoenix shows in their bars and theirs shows in Phoenix's.
local SYNC_PREFIX = "D5"

local function sendBreak(seconds)
    if not (IsInGroup() and M.db.breaks.sync) then return end
    if C_ChatInfo.InChatMessagingLockdown() then return end
    local name = UnitName("player")
    local realm = (GetRealmName() or ""):gsub("[%s%-]+", "")
    local channel = IsInGroup(2) and "INSTANCE_CHAT" -- 2 = LE_PARTY_CATEGORY_INSTANCE (set by the client, not in luacheck std)
        or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(SYNC_PREFIX, ("%s-%s\t1\tBT\t%d"):format(name, realm, seconds), channel)
end

local function showBreak(seconds)
    if seconds <= 0 then
        if M.Bars then M.Bars:StopTimer("break") end
        return
    end
    if M.Bars and not M:BossMod() then M.Bars:StartTimer("break", L.ENC_BREAK_BAR, seconds, seconds, M.BREAK_ICON) end
end

-- /pui break [minutes] and the Break button; 0 ends a running break.
function M:Break(minutes)
    minutes = tonumber(minutes) or self.db.breaks.minutes
    if not canLead() then ns:Print(L.ENC_NEED_LEAD); return false end
    if C_InstanceEncounter.IsEncounterInProgress() then ns:Print(L.ENC_IN_ENCOUNTER); return false end
    if minutes < 0 or minutes > 60 then ns:Print(L.ENC_BREAK_RANGE); return false end
    local seconds = math.floor(minutes * 60)
    showBreak(seconds)
    sendBreak(seconds)
    return true
end

local function onAddonMessage(_, _, prefix, message, _, sender)
    if Secret.IsSecret(prefix) or Secret.IsSecret(message) or Secret.IsSecret(sender) then return end
    if prefix ~= SYNC_PREFIX or type(message) ~= "string" then return end
    local seconds = tonumber(message:match("^[^\t]*\t%d+\tBT\t(%d+)$"))
    if not seconds or seconds > 3600 then return end
    if Ambiguate(sender, "none") == UnitName("player") then return end -- our own, already shown
    showBreak(seconds)
end

---------------------------------------------------------------- test mode
-- Blizzard's Edit Mode sample events go through the same API as a real boss, so the test shows exactly what
-- an encounter will look like in either display; the warning banner gets the game's three sample warnings.
function M:Test()
    if C_InstanceEncounter.IsEncounterInProgress() then ns:Print(L.ENC_IN_ENCOUNTER); return false end
    if not self:HasFeature("timeline") then
        -- no game timeline to sample: show what this client does have, a pull bar (and its voice)
        if self.Bars then self.Bars:StartTimer("pull", L.ENC_PULL_BAR, 10, 10, self.PULL_ICON) end
        self:StartCountdown(10)
        return true
    end
    if self.testTimer then self.testTimer:Cancel() end
    C_EncounterTimeline.CancelEditModeEvents()
    local loop = C_EncounterTimeline.AddEditModeEvents()
    self.testTimer = C_Timer.NewTimer(math.min(tonumber(loop) or 30, 60), function()
        self.testTimer = nil
        C_EncounterTimeline.CancelEditModeEvents()
    end)
    if self.Warnings then self.Warnings:Test() end
    return true
end

function M:StopTest()
    if self.testTimer then self.testTimer:Cancel(); self.testTimer = nil end
    if self:HasFeature("timeline") then C_EncounterTimeline.CancelEditModeEvents() end
end

---------------------------------------------------------------- slash
function M:OnSlash(rest)
    local cmd, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    if cmd == "pull" then return self:Pull(arg ~= "" and arg or nil) end
    if cmd == "break" then return self:Break(arg ~= "" and arg or nil) end
    if cmd == "test" then return self:Test() end
    ns.Config:Show(self.key)
end

---------------------------------------------------------------- lifecycle
function M:OnInitialize()
    C_ChatInfo.RegisterAddonMessagePrefix(SYNC_PREFIX)
end

function M:Restyle()
    if self.Bars then ns.SafeCall(self.Bars.Refresh, self.Bars) end
    if self.Warnings then ns.SafeCall(self.Warnings.Refresh, self.Warnings) end
end

-- `active` rather than IsEnabled(): the module state only flips after OnEnable / OnDisable return.
function M:OnEnable()
    self.active = true
    ns.Events:On("START_PLAYER_COUNTDOWN", self, onPlayerCountdown)
    ns.Events:On("CANCEL_PLAYER_COUNTDOWN", self, onCancelCountdown)
    ns.Events:On("START_TIMER", self, onStartTimer)
    ns.Events:On("CHAT_MSG_ADDON", self, onAddonMessage)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Restyle)
    if self.Bars then self.Bars:Enable() end
    if self.Warnings then self.Warnings:Enable() end
    if self.BigWigs then self.BigWigs:Enable() end
    self:ApplyCVars()
end

function M:OnDisable()
    stopCountdown()
    self:StopTest()
    if self.Bars then self.Bars:Disable() end
    if self.Warnings then self.Warnings:Disable() end
    self.active = false
    self:ApplyCVars()
end

function M:Refresh()
    self:ApplyCVars()
    if self.Bars then self.Bars:Enable() end
    if self.Warnings then self.Warnings:Enable() end
    self:Restyle()
end
