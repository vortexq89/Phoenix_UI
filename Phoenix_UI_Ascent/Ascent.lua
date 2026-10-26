local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ascent (plan 5.15, mockup 07): the Mythic+ block. Timer on the game's world
-- timer (resumes after a reload) with +3/+2 marks on a timer bar, enemy forces
-- with a pace line against the +1/+2/+3 pace, boss splits against your best,
-- deaths and time lost (the death log opens the Embers recap), party kicks
-- (Embers owns the counts), battle res + Bloodlust widget, route notes and an
-- end-of-run summary card. Owners (1.O): Ascent owns keystones (/keys, insert,
-- auto-slot; Keystones.lua) and the enemy-forces data that Tooltip and
-- Nameplates show; the Quest Tracker hosts this block at its top when it runs.
-- Forces and the world timer may be secret: they go to bars and formatters as
-- they come, and pace maths runs only on plain values. Retail only. Off by default.
local _, ns = ...
local Schema, Secret, Ticker = PUI.Schema, PUI.Secret, PUI.Ticker
local OWNER = "Ascent"

local AS = { active = false, run = nil, OWNER = OWNER }
ns.AS = AS
PUI.Ascent = AS
local s = {
  placement = "tracker", sounds = true, tts = false, hideBlizzard = false, splits = true, splitsCompare = "level", pace = true,
  paceTiers = "all", brLust = true, brLustPlacement = "block", kicks = true, deathLog = 3, notes = true, scale = 1, width = 260,
  bgAlpha = 0.85, timerFormat = "clock", forcesFormat = "both", marks = true, summary = "popup", summaryHide = 0,
  sumDamage = true, sumHealing = true, sumKicks = true, sumDeaths = true, autoSlot = true, keysCommand = true,
  keysReply = true, keysShare = true, forcesData = true,
}
AS.settings = s

AS.PLUS3, AS.PLUS2 = 0.6, 0.8
AS.PLACEMENTS = { "tracker", "standalone" }

function AS.Clock(seconds, fmt)
  seconds = math.max(0, seconds or 0)
  if fmt == "tenths" then
    local m = math.floor(seconds / 60)
    return string.format("%d:%04.1f", m, seconds - m * 60)
  end
  seconds = math.floor(seconds)
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function plain(v) if Secret.IsSecret(v) then return nil end return v end
AS.Plain = plain

-- Timer ---------------------------------------------------------------------------
function AS.TimerID()
  for _, id in ipairs({ GetWorldElapsedTimers() }) do
    local _, _, kind = GetWorldElapsedTime(id)
    if kind == Enum.WorldElapsedTimerTypes.ChallengeMode then return id end
  end
end

-- Elapsed seconds: the world timer when it is readable, otherwise the run's own
-- start time (GetTime, never secret) so thresholds keep working.
function AS.Elapsed()
  local id = AS.TimerID()
  if id then
    local _, elapsed = GetWorldElapsedTime(id)
    local v = plain(elapsed)
    if v then return v end
  end
  local run = AS.run
  if run and run.t0 then return GetTime() - run.t0 end
  return nil
end

-- Thresholds for a time limit: { +3, +2, +1 } in seconds.
function AS.Thresholds(limit) return { limit * AS.PLUS3, limit * AS.PLUS2, limit } end

-- Upgrade level the run would get at `elapsed` (3, 2, 1, or 0 = over time).
function AS.Upgrades(elapsed, limit)
  local t = AS.Thresholds(limit)
  if elapsed <= t[1] then return 3 elseif elapsed <= t[2] then return 2 elseif elapsed <= t[3] then return 1 end
  return 0
end

-- Enemy forces (1.O owner) --------------------------------------------------------
-- The weighted criteria as the game gives it (values may be secret).
function AS.Forces()
  for i = 1, 32 do
    local c = C_ScenarioInfo.GetCriteriaInfo(i)
    if not c then return nil end
    if c.isWeightedProgress then return c end
  end
end

-- Plain percent of enemy forces, or nil when the game hides it.
function AS.ForcesPercent(c)
  c = c or AS.Forces()
  if not c then return nil end
  local q, t = plain(c.quantity), plain(c.totalQuantity)
  if not (q and t) or t <= 0 then return nil end
  return math.min(100, q / t * 100)
end

-- Forces one unit is worth (Tooltip and Nameplates text slot read this).
-- Returns the game's own text, possibly secret, for a FontString.
function AS.UnitForces(unit)
  if not s.forcesData or not C_ChallengeMode.IsChallengeModeActive() then return nil end
  if PUI.Coexist:Yields("ascent.forcestips") then return nil end
  local _, _, text = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
  return text
end

-- Pace line (upgrade): forces ahead (+) or behind (-) the even pace for each
-- tier, from plain forces and timer data. { [3] = diff, [2] = diff, [1] = diff }.
function AS.Pace(elapsed, limit, pct)
  if not (elapsed and limit and pct) or limit <= 0 then return nil end
  local out = {}
  for tier, factor in pairs({ [3] = AS.PLUS3, [2] = AS.PLUS2, [1] = 1 }) do
    local needed = math.min(100, elapsed / (limit * factor) * 100)
    out[tier] = pct - needed
  end
  return out
end

-- Records (per character) -----------------------------------------------------
local function records() return Schema:Get("ascent.records") end
AS.Records = records

function AS.RecordKey(mapID, level) return tostring(mapID) .. ":" .. tostring(level) end

function AS.Best(mapID, level)
  local r = records()[PUI.DB:CharKey()]
  return r and r[AS.RecordKey(mapID, level)]
end

-- Best splits to compare against: same level, or (setting) best run on the map.
function AS.CompareRun(mapID, level)
  local exact = AS.Best(mapID, level)
  if exact or s.splitsCompare ~= "map" then return exact end
  local mine, best = records()[PUI.DB:CharKey()] or {}, nil
  for key, rec in pairs(mine) do
    local m = key:match("^(%d+):")
    if tonumber(m) == mapID and rec.onTime and (not best or rec.time < best.time) then best = rec end
  end
  return best
end

-- Store a finished run when it beats the character's best on that map/level.
function AS.SaveRun(run)
  local all = records()
  local me = PUI.DB:CharKey()
  all[me] = all[me] or {}
  local key = AS.RecordKey(run.mapID, run.level)
  local old = all[me][key]
  local better = not old or (run.onTime and not old.onTime) or (run.onTime == old.onTime and run.time < old.time)
  if better then
    all[me][key] = { time = run.time, onTime = run.onTime, deaths = run.deaths, splits = run.splits, at = time() }
    Schema:Set("ascent.records", all)
  end
  return better
end

-- Leaderboard: this character's best per dungeon (highest timed level first).
function AS.Leaderboard()
  local out = {}
  local mine = records()[PUI.DB:CharKey()] or {}
  for key, rec in pairs(mine) do
    local mapID, level = key:match("^(%d+):(%d+)$")
    out[#out + 1] = { mapID = tonumber(mapID), level = tonumber(level), time = rec.time, onTime = rec.onTime }
  end
  table.sort(out, function(a, b)
    if a.onTime ~= b.onTime then return a.onTime end
    if a.level ~= b.level then return a.level > b.level end
    return a.time < b.time
  end)
  return out
end

-- Run lifecycle ------------------------------------------------------------------
function AS.Start()
  local mapID = C_ChallengeMode.GetActiveChallengeMapID()
  if not mapID then AS.run = nil; return nil end
  local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
  local season = PUI.Season and PUI.Season:Thresholds(mapID)
  if season then limit = season[1] end
  local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
  local names = {}
  for _, id in ipairs(affixes or {}) do names[#names + 1] = (C_ChallengeMode.GetAffixInfo(id)) end
  AS.run = { mapID = mapID, name = name, limit = limit or 0, level = level, affixes = names, splits = {}, warned = {}, t0 = GetTime() }
  return AS.run
end

function AS.OnBoss(_, _, encounterID, encounterName, _, _, success)
  local run = AS.run
  if not run or success ~= 1 then return end
  local elapsed = AS.Elapsed()
  if not elapsed then return end
  run.splits[#run.splits + 1] = { name = encounterName, id = encounterID, at = elapsed }
  if ns.Display then ns.Display.Draw() end
end

function AS.OnComplete()
  local run = AS.run
  if not run then return end
  local info = C_ChallengeMode.GetChallengeCompletionInfo()
  if not info or info.practiceRun then AS.run = nil; return end
  -- completion time from the completion info (the world timer can be stale)
  run.time = (plain(info.time) or 0) / 1000
  run.onTime = info.onTime
  run.upgrades = info.keystoneUpgradeLevels
  run.deaths = plain((C_ChallengeMode.GetDeathCount()))
  local old, new = plain(info.oldOverallDungeonScore), plain(info.newOverallDungeonScore)
  run.scoreDelta = (old and new) and (new - old) or nil
  run.pb = AS.SaveRun(run)
  PUI.Slash.Print(string.format("%s +%d: %s, %s, %d deaths%s%s", run.name or "?", run.level or 0, AS.Clock(run.time),
    run.onTime and ("+" .. (run.upgrades or 1)) or "over time", run.deaths or 0,
    run.scoreDelta and string.format(", score %+d", run.scoreDelta) or "", run.pb and " - personal best!" or ""))
  if ns.Summary then ns.Summary.Show(run) end
  AS.last = run
  AS.run = nil
end

local function alert(text)
  if s.sounds then PlaySound(SOUNDKIT.RAID_WARNING) end
  if s.tts then C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard), text, 0, 100, false) end
end
AS.Alert = alert

-- One alert per crossed threshold.
function AS.CheckThresholds(elapsed)
  local run = AS.run
  if not run or (run.limit or 0) <= 0 then return end
  local up = AS.Upgrades(elapsed, run.limit)
  if up < 3 and not run.warned[3] then run.warned[3] = true; if up == 2 then alert("Plus three lost") end end
  if up < 2 and not run.warned[2] then run.warned[2] = true; if up == 1 then alert("Plus two lost") end end
  if up < 1 and not run.warned[1] then run.warned[1] = true; alert("Out of time") end
end

-- Battle res and Bloodlust ------------------------------------------------------
AS.BREZ = 20484
AS.SATED = { 57723, 57724, 80354, 95809, 160455, 264689, 390435 }

-- Shared battle-res charges (the game pools them in keys and boss fights).
function AS.BattleRes()
  local c = C_Spell.GetSpellCharges(AS.BREZ)
  if not c then return nil end
  return { charges = c.currentCharges, max = c.maxCharges, start = c.cooldownStartTime, duration = c.cooldownDuration }
end

-- "ready" | "sated" | "unknown" (the aura is hidden right now) and seconds left.
function AS.Lust()
  for _, id in ipairs(AS.SATED) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if Secret.IsSecret(aura) then return "unknown" end
    if aura then
      local exp = plain(aura.expirationTime)
      return "sated", exp and math.max(0, exp - GetTime()) or nil
    end
  end
  return "ready"
end

-- Blizzard's M+ block: faded (not moved or hidden) while Phoenix's block shows,
-- unless the Quest Tracker already replaced Blizzard's tracker.
local function blizzTracker(hide)
  local t = rawget(_G, "ObjectiveTrackerFrame")
  if not t then return end
  if hide then
    if AS.trackerAlpha == nil then AS.trackerAlpha = t:GetAlpha() end
    t:SetAlpha(0)
  elseif AS.trackerAlpha ~= nil then
    t:SetAlpha(AS.trackerAlpha)
    AS.trackerAlpha = nil
  end
end
AS.BlizzTracker = blizzTracker

local function refresh()
  if not AS.active then return end
  if C_ChallengeMode.IsChallengeModeActive() then
    if not AS.run then AS.Start() end
    blizzTracker(s.hideBlizzard and AS.run ~= nil)
    Ticker:Register("ascent.timer", 0.25, function() ns.Display.Draw() end, OWNER)
    ns.Display.Draw()
  else
    Ticker:Unregister("ascent.timer")
    blizzTracker(false)
    ns.Display.Hide()
  end
  PUI.Kernel:Fire("ASCENT_RUN", AS.run ~= nil)
end
AS.Refresh = refresh
function AS.Draw() if ns.Display then ns.Display.Draw() end end

local function onEnable(mod)
  AS.active = true
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", function() refresh(); ns.Keys.Scan() end)
  mod:RegisterEvent("CHALLENGE_MODE_START", function() AS.run = nil; refresh() end)
  mod:RegisterEvent("CHALLENGE_MODE_RESET", function() AS.run = nil; refresh() end)
  mod:RegisterEvent("WORLD_STATE_TIMER_START", refresh)
  mod:RegisterEvent("WORLD_STATE_TIMER_STOP", refresh)
  mod:RegisterEvent("ENCOUNTER_END", AS.OnBoss)
  mod:RegisterEvent("SCENARIO_CRITERIA_UPDATE", function() if AS.run then ns.Display.Draw() end end)
  mod:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED", function() if AS.run then ns.Display.Draw() end end)
  mod:RegisterEvent("CHALLENGE_MODE_COMPLETED", function() AS.OnComplete(); refresh(); ns.Keys.Scan() end)
  ns.Keys.Enable(mod)
  refresh()
end

local function onDisable()
  AS.active = false
  Ticker:Unregister("ascent.timer")
  blizzTracker(false)
  ns.Display.Hide()
  if ns.Summary then ns.Summary.Hide() end
  ns.Keys.Disable()
  PUI.Kernel:Fire("ASCENT_RUN", false)
end

PUI.Layout:RegisterElement("ascent.timer", { label = "Mythic+ block", owner = OWNER, size = { 260, 220 }, default = { point = "TOPRIGHT", x = -19, y = -207 } })
PUI.Layout:RegisterElement("ascent.brlust", { label = "Battle res and Bloodlust", owner = OWNER, size = { 120, 28 }, default = { point = "TOPRIGHT", x = -19, y = -170 } })
PUI.Layout:RegisterElement("ascent.summary", { label = "Mythic+ run summary", owner = OWNER, size = { 420, 180 }, default = { point = "CENTER", x = 0, y = 160 } })

-- Settings -------------------------------------------------------------------------
local schema = {}
AS.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = def.apply or function(value) s[name] = value; if AS.active then refresh() end end
  schema["ascent." .. name] = def
end
-- Simple
key("placement", { type = "select", default = "tracker", choices = AS.PLACEMENTS,
  choiceLabels = { tracker = "Top of the Phoenix quest tracker", standalone = "Its own window" }, label = "Where the M+ block sits",
  tooltip = "Docks the Mythic+ block at the top of the Phoenix quest tracker, or shows it as its own movable window. When the Phoenix tracker is off it always uses its own window.",
  mode = "simple", searchTags = { "mythic", "timer", "dock", "tracker" } })
key("sounds", { type = "toggle", default = true, label = "Threshold sounds", tooltip = "Plays a warning when the +3, +2 or +1 time runs out.", mode = "simple" })
key("pace", { type = "toggle", default = true, label = "Pace line", tooltip = "Shows whether your enemy forces are ahead of or behind an even pace for +1, +2 and +3.", mode = "simple" })
key("splits", { type = "toggle", default = true, label = "Boss splits", tooltip = "Boss kill times and the difference to your best run.", mode = "simple" })
key("brLust", { type = "toggle", default = true, label = "Battle res and Bloodlust", tooltip = "Shows shared battle-res charges and whether you can get Bloodlust again.", mode = "simple" })
key("summary", { type = "select", default = "popup", choices = { "popup", "chat", "off" },
  choiceLabels = { popup = "Summary card", chat = "Chat line only", off = "Nothing" }, label = "After a run",
  tooltip = "What you see when a key finishes: a summary card with time, score change and everyone's numbers, a chat line, or nothing.", mode = "simple" })
key("autoSlot", { type = "toggle", default = true, label = "Insert my keystone",
  tooltip = "Puts your keystone in the font of power when you open it (out of combat).", mode = "simple", searchTags = { "keystone", "insert", "slot", "font" } })
key("keysCommand", { type = "toggle", default = true, label = "/keys command",
  tooltip = "Type /keys to list your key, your alts' keys and your group's keys (/pui keys always works).", mode = "simple", searchTags = { "keys", "keystone" } })
key("hideBlizzard", { type = "toggle", default = false, label = "Hide Blizzard M+ tracker", tooltip = "Fades the Blizzard objective tracker while a key runs.", mode = "simple" })
-- Advanced
key("width", { type = "range", default = 260, min = 200, max = 380, step = 4, label = "Block width", tooltip = "Width of the Mythic+ block.", mode = "advanced" })
key("scale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Block scale", tooltip = "Size of the Mythic+ block.", mode = "advanced" })
key("bgAlpha", { type = "range", default = 0.85, min = 0, max = 1, step = 0.05, label = "Background opacity", tooltip = "Background opacity of the Mythic+ block.", mode = "advanced" })
key("timerFormat", { type = "select", default = "clock", choices = { "clock", "tenths" }, choiceLabels = { clock = "18:42", tenths = "18:42.5" },
  label = "Timer format", tooltip = "Show tenths of a second on the timer.", mode = "advanced" })
key("marks", { type = "toggle", default = true, label = "+2 / +3 marks on the timer bar", tooltip = "Tick marks on the timer bar where +3 and +2 run out.", mode = "advanced" })
key("forcesFormat", { type = "select", default = "both", choices = { "percent", "count", "both" },
  choiceLabels = { percent = "78.4%", count = "312/398", both = "78.4% (312/398)" }, label = "Enemy forces text", tooltip = "How enemy forces are written.", mode = "advanced" })
key("paceTiers", { type = "select", default = "all", choices = { "all", "next" }, choiceLabels = { all = "+1, +2 and +3", next = "Only the best tier still possible" },
  label = "Pace for", tooltip = "Which tiers the pace line compares against.", mode = "advanced" })
key("splitsCompare", { type = "select", default = "level", choices = { "level", "map" }, choiceLabels = { level = "Best run at this level", map = "Best timed run on this dungeon" },
  label = "Compare splits with", tooltip = "Which of your runs boss splits are compared with.", mode = "advanced" })
key("kicks", { type = "toggle", default = true, label = "Party kicks", tooltip = "Shows interrupt counts for your group (from the Embers meter data).", mode = "advanced" })
key("deathLog", { type = "range", default = 3, min = 0, max = 10, step = 1, label = "Death log lines", tooltip = "Recent deaths listed under the timer; click one to open its Embers recap.", mode = "advanced" })
key("brLustPlacement", { type = "select", default = "block", choices = { "block", "standalone" }, choiceLabels = { block = "Inside the M+ block", standalone = "Its own movable widget" },
  label = "Battle res and Bloodlust placement", tooltip = "Docked inside the M+ block or as its own widget (also shown in raid boss fights).", mode = "advanced" })
key("tts", { type = "toggle", default = false, label = "Spoken warnings", tooltip = "Reads threshold warnings aloud with the game's text to speech.", mode = "advanced" })
key("notes", { type = "toggle", default = true, label = "Route notes", tooltip = "Shows your note for the dungeon under the timer (/pui ascent note <text>).", mode = "advanced" })
key("summaryHide", { type = "range", default = 0, min = 0, max = 120, step = 5, label = "Close summary after (seconds)", tooltip = "0 keeps the summary card open until you close it.", mode = "advanced" })
for _, c in ipairs({ { "sumDamage", "Damage column" }, { "sumHealing", "Healing column" }, { "sumKicks", "Kicks column" }, { "sumDeaths", "Deaths column" } }) do
  key(c[1], { type = "toggle", default = true, label = "Summary: " .. c[2], tooltip = "Shows the " .. c[2]:lower() .. " on the run summary card.", mode = "advanced" })
end
key("keysReply", { type = "toggle", default = true, label = "Answer !keys",
  tooltip = "When someone types !keys in party chat, your key is posted through Phoenix announcements (Keystones topic decides where).", mode = "advanced" })
key("keysShare", { type = "toggle", default = true, label = "Share my key with my group",
  tooltip = "Sends your key to group members who also use Phoenix, so /keys can list theirs.", mode = "advanced" })
key("forcesData", { type = "toggle", default = true, label = "Enemy forces for tooltips and nameplates",
  tooltip = "Lets the tooltip and nameplate forces texts show how much each enemy is worth.", mode = "advanced" })
schema["ascent.records"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Best runs", tooltip = "Best run per dungeon and level for each character.", apply = function() end }
schema["ascent.notes"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Route notes", tooltip = "Your notes per dungeon.", apply = function() end }
schema["ascent.keys"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Keystones on your characters", tooltip = "Last seen keystone per character.", apply = function() end }

local ckey, cdef = PUI.Coexist:Define("ascent", { module = OWNER, job = "Mythic+ timer", addons = { "WarpDeplete", "MythicPlusTimer", "AngryKeystones" } })
cdef.owner = OWNER
schema[ckey] = cdef
local fkey, fdef = PUI.Coexist:Define("ascent.forcestips", { module = OWNER, job = "Enemy forces in tooltips", soft = true, addons = { "MythicDungeonTools" } })
fdef.owner = OWNER
schema[fkey] = fdef

PUI.Slash:Register("ascent", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  local out = PUI.Slash.Print
  if word == "note" then
    local mapID = (AS.run and AS.run.mapID) or C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then return out("start or own a key to attach a note") end
    local notes = Schema:Get("ascent.notes")
    notes[tostring(mapID)] = arg ~= "" and arg or nil
    Schema:Set("ascent.notes", notes)
    out("note saved")
  elseif word == "best" then
    for _, r in ipairs(AS.Leaderboard()) do
      out(string.format("%s +%d  %s%s", (C_ChallengeMode.GetMapUIInfo(r.mapID)) or r.mapID, r.level, AS.Clock(r.time), r.onTime and "" or " (over)"))
    end
  elseif word == "summary" then
    if AS.last and ns.Summary then ns.Summary.Show(AS.last) else out("no finished run this session") end
  else
    out("/pui ascent note <text> | best | summary  (keys: /pui keys)")
  end
end, "Mythic+ block: route note, personal bests, last run summary")

AS.module = PUI:RegisterModule(OWNER, {
  label = "Ascent", tooltip = "Mythic+ block: timer with +2/+3 marks and pace, enemy forces, boss splits, deaths, battle res and Bloodlust, keystones and a run summary.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return not PUI.IS_FOREVER and PUI.Coexist:Allows("ascent") end,
})
for k, def in pairs(schema) do if def.type ~= "layout" and k:sub(1, 7) == "ascent." and not k:find("coexist") then def.apply(Schema:Get(k)) end end
