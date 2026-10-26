local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Oracle (PUI_V2 6.3): a keyboard-first command palette. Providers turn a
-- query into results; a result either runs plain code (settings, commands,
-- profiles, mounts out of combat, plugin results) or is a secure action
-- (macros, game panels) carried out by ONE SecureActionButton whose
-- attributes are set out of combat when the result is chosen. In combat only
-- plain results are offered and the palette says so. Nothing is built until
-- the palette first opens. Off by default.
local _, ns = ...
local Schema, CQ = PUI.Schema, PUI.CombatQueue
local OWNER = "Oracle"

local OR = { active = false, providers = {}, order = {} }
ns.OR = OR
PUI.Oracle = OR
local s = { key = "CTRL-K", maxResults = 10, recent = true }
OR.settings = s

-- Fuzzy score: every query letter must appear in order; consecutive letters,
-- word starts and an early first hit score higher. nil = no match.
function OR.Score(text, query)
  if query == "" then return 0 end
  local t, q = text:lower(), query:lower()
  local score, pos, last = 0, 1, 0
  for i = 1, #q do
    local c = q:sub(i, i)
    if c ~= " " then
      local at = t:find(c, pos, true)
      if not at then return nil end
      score = score + 1
      if at == last + 1 then score = score + 3 end
      if at == 1 or t:sub(at - 1, at - 1):match("[%s%p]") then score = score + 2 end
      last, pos = at, at + 1
    end
  end
  local exact = t:find(q, 1, true)
  if exact then score = score + 10 - math.min(exact, 9) end
  return score - #t * 0.01
end

-- Providers -----------------------------------------------------------------------
-- provider(query, inCombat) -> list of { text, kind, run = fn | secure = { attr = value } }
function OR.AddProvider(name, fn)
  if not OR.providers[name] then OR.order[#OR.order + 1] = name end
  OR.providers[name] = fn
end

local function each(list, query, out, kind, make)
  for _, item in ipairs(list) do
    local text = item.text
    local sc = OR.Score(text, query)
    if sc then
      local r = make and make(item) or item
      r.text, r.kind, r.score = text, kind, sc
      out[#out + 1] = r
    end
  end
end

OR.AddProvider("settings", function(query, _, out)
  if query == "" then return end
  local list = {}
  for _, key in ipairs(Schema.keys) do
    local def = Schema.defs[key]
    if not def.hidden then list[#list + 1] = { text = "Setting: " .. PUI.L[def.label], key = key } end
  end
  each(list, query, out, "setting", function(item)
    return { run = function() PUI.OptionsHost:OpenOptions(item.key) end }
  end)
end)

OR.AddProvider("commands", function(query, _, out)
  local list = {}
  for word, cmd in pairs(PUI.Slash.commands) do list[#list + 1] = { text = "/pui " .. word .. " - " .. (cmd.help or ""), word = word } end
  table.sort(list, function(a, b) return a.text < b.text end)
  each(list, query, out, "command", function(item) return { run = function() PUI.Slash.commands[item.word].fn("") end } end)
end)

OR.AddProvider("profiles", function(query, _, out)
  local list = {}
  for _, name in ipairs(PUI.DB:ProfileNames()) do list[#list + 1] = { text = "Profile: " .. name, name = name } end
  each(list, query, out, "profile", function(item) return { run = function() PUI.DB:SetProfile(item.name) end } end)
end)

-- Game panels through their micro buttons (secure click; names checked at runtime).
OR.PANELS = {
  { "Character", "CharacterMicroButton" }, { "Spellbook and talents", "PlayerSpellsMicroButton" }, { "Spellbook", "SpellbookMicroButton" },
  { "Talents", "TalentMicroButton" }, { "Professions", "ProfessionMicroButton" }, { "Achievements", "AchievementMicroButton" },
  { "Quest log", "QuestLogMicroButton" }, { "Guild and communities", "GuildMicroButton" }, { "Group finder", "LFDMicroButton" },
  { "Collections", "CollectionsMicroButton" }, { "Adventure guide", "EJMicroButton" }, { "Game menu", "MainMenuMicroButton" },
  { "Housing", "HousingMicroButton" },
}
OR.AddProvider("panels", function(query, inCombat, out)
  if inCombat then return end
  local list = {}
  for _, p in ipairs(OR.PANELS) do
    local b = rawget(_G, p[2])
    if b then list[#list + 1] = { text = "Open: " .. p[1], button = b } end
  end
  each(list, query, out, "panel", function(item) return { secure = { type = "click", clickbutton = item.button } } end)
end)

OR.AddProvider("macros", function(query, inCombat, out)
  if inCombat or query == "" then return end
  local list = {}
  local general, char = GetNumMacros()
  for i = 1, general do local name = GetMacroInfo(i); if name then list[#list + 1] = { text = "Macro: " .. name, index = i } end end
  for i = 1, char do local name = GetMacroInfo(120 + i); if name then list[#list + 1] = { text = "Macro: " .. name, index = 120 + i } end end
  each(list, query, out, "macro", function(item) return { secure = { type = "macro", macro = item.index } } end)
end)

OR.AddProvider("mounts", function(query, inCombat, out)
  if inCombat or query == "" then return end
  local list = {}
  for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
    local name, _, icon, _, usable, _, _, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(id)
    if name and collected and usable and not hidden then list[#list + 1] = { text = "Mount: " .. name, id = id, icon = icon } end
  end
  each(list, query, out, "mount", function(item) return { icon = item.icon, run = function() if not InCombatLockdown() then C_MountJournal.SummonByID(item.id) end end } end)
end)

-- Plugin providers (PUI.API.RegisterOracleProvider): plain results only.
OR.AddProvider("plugins", function(query, _, out)
  for pid, fn in pairs(PUI.APIRegistry.oracle) do
    local res
    securecallfunction(function() res = fn(query) end)
    for _, r in ipairs(type(res) == "table" and res or {}) do
      if type(r.text) == "string" and type(r.run) == "function" then
        out[#out + 1] = { text = r.text, kind = "plugin:" .. pid, run = r.run, icon = r.icon, score = OR.Score(r.text, query) or 0 }
      end
    end
  end
end)

-- Recent picks first when the query is empty.
function OR.Recent() return Schema:Get("oracle.recent") end
function OR.Remember(text)
  if not s.recent then return end
  local list, out = OR.Recent(), { text }
  for _, t in ipairs(list) do if t ~= text and #out < 10 then out[#out + 1] = t end end
  Schema:Set("oracle.recent", out)
end

function OR.Search(query)
  query = query or ""
  local inCombat = InCombatLockdown()
  local out = {}
  for _, name in ipairs(OR.order) do OR.providers[name](query, inCombat, out) end
  if query == "" then
    local rank = {}
    for i, t in ipairs(OR.Recent()) do rank[t] = 100 - i end
    for _, r in ipairs(out) do r.score = rank[r.text] or -1 end
  end
  table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.text < b.text end)
  local trimmed = {}
  for i = 1, math.min(#out, s.maxResults) do trimmed[i] = out[i] end
  return trimmed, inCombat
end

-- The hotkey: an override binding on a plain button, set out of combat.
local toggle
function OR.Bind()
  CQ.Defer("oracle.bind", function()
    if not toggle then
      toggle = PUI:CreateFrame("Button", "PhoenixUI_OracleToggle", UIParent, nil, OWNER)
      toggle:SetScript("OnClick", function() ns.Palette.Toggle() end)
    end
    ClearOverrideBindings(toggle)
    if OR.active and s.key ~= "" then SetOverrideBindingClick(toggle, false, s.key, "PhoenixUI_OracleToggle") end
  end)
end

local function onEnable() OR.active = true; OR.Bind() end
local function onDisable() OR.active = false; OR.Bind(); if ns.Palette.frame then ns.Palette.Close() end end

local schema = {}
OR.schema = schema
schema["oracle.key"] = { type = "select", default = "CTRL-K", choices = { "CTRL-K", "CTRL-SPACE", "ALT-K", "CTRL-P", "SHIFT-SPACE" }, owner = OWNER,
  label = "Palette key", tooltip = "Key that opens the Oracle palette.", mode = "simple",
  apply = function(v) s.key = v; if OR.active then OR.Bind() end end }
schema["oracle.maxResults"] = { type = "range", default = 10, min = 5, max = 15, step = 1, owner = OWNER, label = "Results shown",
  tooltip = "How many results the palette lists.", mode = "advanced", apply = function(v) s.maxResults = v end }
schema["oracle.recent"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Recent picks",
  tooltip = "Your last ten picks, listed first.", apply = function() end }
schema["oracle.remember"] = { type = "toggle", default = true, owner = OWNER, label = "Remember recent picks",
  tooltip = "Lists what you picked recently first when the search is empty.", mode = "advanced", apply = function(v) s.recent = v end }

PUI.Slash:Register("oracle", function() if OR.active then ns.Palette.Toggle() else PUI.Slash.Print("Oracle is off (/pui set module.Oracle on)") end end, "open the command palette")

OR.module = PUI:RegisterModule(OWNER, {
  label = "Oracle", tooltip = "Command palette: search settings, panels, macros, mounts, profiles and commands from one box.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
