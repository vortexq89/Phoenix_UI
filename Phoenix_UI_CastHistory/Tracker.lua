local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cast History tracker (plan 1.O "Spell/cast history": Cast History owns it;
-- Embers only links here). One small state machine per unit, keyed by
-- castGUID when the game gives a plain one:
--   start / channel / empower -> icon added as "casting"
--   succeeded with the same cast -> done; succeeded with no cast -> instant
--   interrupted -> red cross; stop or failed after a start without success ->
--   cancelled cross (a failed press with no start never adds an icon, so a
--   spell that never began is not shown as cast)
-- A hidden (secret) spell ID or castGUID is never compared or used as a key:
-- blocklists are checked only on plain IDs, and the icon texture goes straight
-- from the game to the widget (mockup 17 note 3).
local _, ns = ...
local Secret = PUI.Secret
local T = { current = {}, history = {}, seen = {}, blockSpell = {}, blockItemSpell = {} }
ns.Tracker = T

T.BUILTIN = { [6603] = true, [75] = true, [5019] = true, [61304] = true, [836] = true }
T.TRINKETS = { [336126] = true, [42292] = true, [195710] = true, [208683] = true }
T.MAX_HISTORY = 30

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
T.Plain = plain

-- Blocked(spellID, s): plain IDs only.
function T.Blocked(spellID, s)
  if not plain(spellID) then return false end
  if s.builtIn and T.BUILTIN[spellID] then return true end
  return T.blockSpell[spellID] == true or T.blockItemSpell[spellID] == true
end
-- RebuildBlocks(spells, items): lists of strings (IDs) -> lookup sets; items map
-- to their use spell through the game.
function T.RebuildBlocks(spells, items)
  wipe(T.blockSpell); wipe(T.blockItemSpell)
  for _, v in ipairs(spells or {}) do local id = tonumber(v); if id then T.blockSpell[id] = true end end
  for _, v in ipairs(items or {}) do
    local id = tonumber(v)
    if id then
      local _, spellID = C_Item.GetItemSpell(id)
      if plain(spellID) then T.blockItemSpell[spellID] = true end
    end
  end
end

local function sameCast(cur, guid)
  if not cur then return false end
  if plain(cur.guid) and plain(guid) then return cur.guid == guid end
  return true -- one cast at a time per unit: a hidden GUID matches the current cast
end

local function remember(unit, spellID, state)
  local h = T.history[unit]
  if not h then h = {}; T.history[unit] = h end
  table.insert(h, 1, { id = plain(spellID) and spellID or nil, t = GetTime(), state = state })
  while #h > T.MAX_HISTORY do table.remove(h) end
  if plain(spellID) then T.seen[spellID] = true end
  return h[1]
end

-- On(event, unit, guid, spellID, sink, s): sink = { add(unit, spellID, kind) -> icon, mark(icon, state) }.
function T.On(event, unit, guid, spellID, sink, s)
  local cur = T.current[unit]
  if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
    if T.Blocked(spellID, s) then T.current[unit] = nil; return nil end
    local kind = (event == "UNIT_SPELLCAST_START" and "cast") or (event == "UNIT_SPELLCAST_CHANNEL_START" and "channel") or "empower"
    if kind == "channel" and not s.showChannel then return nil end
    local icon = sink.add(unit, spellID, kind)
    T.current[unit] = { guid = guid, icon = icon, kind = kind, entry = remember(unit, spellID, kind) }
    return icon
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if cur and sameCast(cur, guid) then
      cur.done = true
      if cur.kind == "cast" then sink.mark(cur.icon, "done"); cur.entry.state = "done" end
      return cur.icon
    end
    if T.Blocked(spellID, s) then return nil end
    local icon = sink.add(unit, spellID, "instant")
    remember(unit, spellID, "done")
    return icon
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
    if cur and sameCast(cur, guid) then
      if s.showInterrupted then sink.mark(cur.icon, "interrupted") end
      cur.entry.state = "interrupted"
      T.current[unit] = nil
    end
  elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_STOP" then
    if cur and sameCast(cur, guid) and cur.kind == "cast" then
      if not cur.done then
        if s.showCancelled then sink.mark(cur.icon, "cancelled") end
        cur.entry.state = "cancelled"
      end
      T.current[unit] = nil
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
    if cur and sameCast(cur, guid) then
      sink.mark(cur.icon, "done")
      cur.entry.state = "done"
      T.current[unit] = nil
    end
  end
  return nil
end

-- History(unit) -> newest first { id (nil when hidden), t, state } (read by Embers).
function T.History(unit) return T.history[unit] or {} end

-- Find(text): blocklist picker. Every seen spell whose name contains the text,
-- plus the game's own lookup for an exact name; numbers are taken as IDs.
function T.Find(text)
  local out, have = {}, {}
  local id = tonumber(text)
  if id then return { { id = id, name = C_Spell.GetSpellName(id) } } end
  local needle = tostring(text or ""):lower()
  if needle == "" then return out end
  for sid in pairs(T.seen) do
    local name = C_Spell.GetSpellName(sid)
    if plain(name) and name:lower():find(needle, 1, true) and not have[sid] then out[#out + 1] = { id = sid, name = name }; have[sid] = true end
  end
  local info = C_Spell.GetSpellInfo(text)
  if info and plain(info.spellID) and not have[info.spellID] then out[#out + 1] = { id = info.spellID, name = info.name } end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end
