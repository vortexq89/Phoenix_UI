local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Party cooldowns: a party cooldown and interrupt tracker. Phoenix's own
-- design. When a party member casts a tracked spell (UNIT_SPELLCAST_SUCCEEDED
-- on player/party1-4, from PUI.PartyCooldownData) its icon starts the base
-- cooldown. Icons attach to that member's Phoenix party frame or sit in a
-- standalone, movable list.
--   * Secret-safe: a spell ID or GUID the game hands over as a secret value is
--     never compared or looked up; that cast is simply not tracked.
--   * Cooldown times are Phoenix's own plain numbers (cast time + table
--     duration) and go to Cooldown widgets; no OnUpdate, no polling.
local Schema, Layout, Secret = PUI.Schema, PUI.Layout, PUI.Secret
local D = PUI.PartyCooldownData
local OWNER = "PartyCD"
local UNITS = { "player", "party1", "party2", "party3", "party4" }

local PCD = { active = false, rows = {}, state = {}, frames = {} }
PUI.PartyCD = PCD
local s = { cats = { interrupt = true, defensive = true, raid = true, offensive = false, brez = true, lust = true },
  size = 22, spacing = 2, attach = "frames", side = "RIGHT", offset = 2, showUnseen = true, includeSelf = false, max = 8 }
PCD.settings = s

-- Spell -> slot (ranks share one slot) and its data, or nil. Never compares a secret.
function PCD.Lookup(spellID)
  if spellID == nil or Secret.IsSecret(spellID) then return nil end
  local base = D.base[spellID]
  local info = base and D.spells[spellID]
  if not info or not s.cats[info.cat] then return nil end
  return base, info
end

local function keyFor(unit)
  local g = UnitGUID(unit)
  if g == nil or Secret.IsSecret(g) then return unit end
  return g
end

-- Called from UNIT_SPELLCAST_SUCCEEDED.
function PCD.OnCast(unit, spellID)
  if not PCD.active then return end
  local base, info = PCD.Lookup(spellID)
  if not base then return end
  local k = keyFor(unit)
  local st = PCD.state[k] or { seen = {}, cds = {} }
  PCD.state[k] = st
  local now = GetTime()
  st.seen[base] = true
  st.cds[base] = { start = now, duration = info.cd }
  PCD.Paint(unit)
end

-- Ordered slots for a unit: seen spells plus (option) the class interrupt.
function PCD.Slots(unit)
  local _, class = UnitClass(unit)
  local st = PCD.state[keyFor(unit)]
  local out = {}
  for _, id in ipairs(D.byClass[class] or {}) do
    local info = D.spells[id]
    local show = s.cats[info.cat] and ((st and st.seen[id]) or (s.showUnseen and D.ALWAYS[class] == id))
    if show and #out < s.max then out[#out + 1] = id end
  end
  return out
end

-- Rows -----------------------------------------------------------------------------
local function anchor()
  local a = PCD.anchor
  if not a then
    a = PUI:CreateFrame("Frame", "PhoenixUI_PartyCD", UIParent, nil, OWNER)
    a:SetSize(200, 20)
    PCD.anchor = a
  end
  Layout:Place(a, "pcd.list")
  return a
end

local function row(i)
  local r = PCD.rows[i]
  if r then return r end
  r = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
  r.icons = {}
  r.name = r:CreateFontString(nil, "OVERLAY")
  r.name:SetFontObject(PUI.Media:FontObject("small"))
  PCD.rows[i] = r
  return r
end

local function icon(r, j)
  local b = r.icons[j]
  if b then return b end
  b = PUI:CreateFrame("Frame", nil, r, nil, OWNER)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER)
  b.cd:SetAllPoints()
  r.icons[j] = b
  return b
end

-- The member's Phoenix party frame, if Raid Frames shows one.
function PCD.FrameFor(unit)
  local RF = PUI.RaidFrames
  if not (RF and RF.active and RF.byUnit) then return nil end
  local set = RF.byUnit[unit]
  if not set then return nil end
  for o in pairs(set) do if o.button and o.button:IsShown() then return o.button end end
  return nil
end

local SIDE = { RIGHT = { "LEFT", "RIGHT", 1, 0 }, LEFT = { "RIGHT", "LEFT", -1, 0 }, TOP = { "BOTTOM", "TOP", 0, 1 }, BOTTOM = { "TOP", "BOTTOM", 0, -1 } }

function PCD.Units()
  local out = {}
  for _, u in ipairs(UNITS) do
    if (u ~= "player" or s.includeSelf) and UnitExists(u) then out[#out + 1] = u end
  end
  return out
end

function PCD.Paint(onlyUnit)
  for _, r in ipairs(PCD.rows) do
    if r.unit and (not onlyUnit or r.unit == onlyUnit) then
      local st = PCD.state[keyFor(r.unit)]
      for j, id in ipairs(r.slots) do
        local b = r.icons[j]
        local cd = st and st.cds[id]
        b.cd:SetCooldown(cd and cd.start or 0, cd and cd.duration or 0)
      end
    end
  end
end

function PCD.Rebuild()
  for _, r in ipairs(PCD.rows) do r:Hide(); r.unit = nil end
  if not PCD.active then return end
  local list = anchor()
  local size, gap = s.size, s.spacing
  local standalone = 0
  for i, unit in ipairs(PCD.Units()) do
    local r = row(i)
    r.unit, r.slots = unit, PCD.Slots(unit)
    local n = #r.slots
    local side = SIDE[s.side] or SIDE.RIGHT
    local vertical = side[4] ~= 0
    r:SetSize(vertical and size or math.max(1, n * (size + gap) - gap), vertical and math.max(1, n * (size + gap) - gap) or size)
    for j, id in ipairs(r.slots) do
      local b = icon(r, j)
      b:SetSize(size, size)
      b:ClearAllPoints()
      if vertical then b:SetPoint("TOP", r, "TOP", 0, -(j - 1) * (size + gap)) else b:SetPoint("LEFT", r, "LEFT", (j - 1) * (size + gap), 0) end
      b.tex:SetTexture(C_Spell.GetSpellTexture(id))
      b:Show()
    end
    for j = n + 1, #r.icons do r.icons[j]:Hide() end
    r:ClearAllPoints()
    local frame = s.attach == "frames" and PCD.FrameFor(unit)
    if frame then
      r:SetPoint(side[1], frame, side[2], side[3] * s.offset, side[4] * s.offset)
      r.name:SetText("")
    else
      r:SetPoint("TOPLEFT", list, "TOPLEFT", 90, -standalone * (size + gap))
      r.name:ClearAllPoints()
      r.name:SetPoint("RIGHT", r, "LEFT", -4, 0)
      r.name:SetText(Secret.ToText(UnitName(unit)))
      standalone = standalone + 1
    end
    r:SetShown(n > 0)
  end
  list:SetSize(90 + s.max * (size + gap), math.max(1, standalone) * (size + gap))
  PCD.Paint()
end

-- A roster change re-reads frames one tick later (after the secure header
-- assigned units); one self-removing Ticker entry.
function PCD.Later()
  if PUI.Ticker:IsRegistered("pcd.later") then return end
  PUI.Ticker:Register("pcd.later", 0.2, function() PUI.Ticker:Unregister("pcd.later"); PCD.Rebuild() end, OWNER)
end

-- Test: fills every row with the player's class spells, half on cooldown.
function PCD.Test()
  local _, class = UnitClass("player")
  local now = GetTime()
  for _, unit in ipairs(PCD.Units()) do
    local st = { seen = {}, cds = {} }
    for k, id in ipairs(D.byClass[class] or {}) do
      if D.base[id] == id then
        st.seen[id] = true
        if k % 2 == 0 then st.cds[id] = { start = now, duration = D.spells[id].cd } end
      end
    end
    PCD.state[keyFor(unit)] = st
  end
  PCD.Rebuild()
end

local function onEnable(mod)
  PCD.active = true
  for i, pair in ipairs({ { "player", "party1" }, { "party2", "party3" }, { "party4" } }) do
    local f = PCD.frames[i] or PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
    PCD.frames[i] = f
    f:SetScript("OnEvent", function(_, _, unit, _, spellID) PCD.OnCast(unit, spellID) end)
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", pair[1], pair[2])
  end
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", PCD.Later)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", PCD.Later)
  mod:RegisterEvent("CHALLENGE_MODE_START", function() wipe(PCD.state); PCD.Rebuild() end)
  PCD.Rebuild()
end
local function onDisable()
  PCD.active = false
  for _, f in ipairs(PCD.frames) do f:UnregisterAllEvents() end
  if PUI.Ticker:IsRegistered("pcd.later") then PUI.Ticker:Unregister("pcd.later") end
  PCD.Rebuild()
end

-- Schema -----------------------------------------------------------------------------
local schema = {}
PCD.schema = schema
local function key(name, def, set)
  def.owner = OWNER
  def.apply = function(v) set(v); PCD.Rebuild() end
  schema["pcd." .. name] = def
end
local CAT_LABEL = { interrupt = "Interrupts", defensive = "Personal defensives", raid = "Group defensives",
  offensive = "Big damage cooldowns", brez = "Battle res", lust = "Bloodlust / Heroism" }
local CAT_TIP = { interrupt = "Tracks party interrupts (Kick, Pummel, Counterspell, Wind Shear and the rest).",
  defensive = "Tracks personal defensives such as Ice Block, Divine Shield and Cloak of Shadows.",
  raid = "Tracks group defensives such as Rallying Cry, Spirit Link Totem and Darkness.",
  offensive = "Tracks big damage cooldowns such as Combustion, Avatar and Celestial Alignment.",
  brez = "Tracks battle res spells (Rebirth, Raise Ally, Soulstone, Intercession).",
  lust = "Tracks Bloodlust, Heroism, Time Warp and Fury of the Aspects." }
for _, cat in ipairs(D.CATEGORIES) do
  key("cat." .. cat, { type = "toggle", default = s.cats[cat], label = CAT_LABEL[cat], tooltip = CAT_TIP[cat], mode = "simple",
    searchTags = { "omnicd", "party", "cooldown", "interrupt" } }, function(v) s.cats[cat] = v end)
end
key("attach", { type = "select", default = "frames", choices = { "frames", "list" },
  choiceLabels = { frames = "On Phoenix party frames", list = "Standalone list" }, label = "Where icons go",
  tooltip = "Attach each member's icons to their Phoenix party frame, or show one movable list. Without Phoenix party frames the list is used.", mode = "simple" },
  function(v) s.attach = v end)
key("side", { type = "select", default = "RIGHT", choices = { "RIGHT", "LEFT", "TOP", "BOTTOM" },
  choiceLabels = { RIGHT = "Right", LEFT = "Left", TOP = "Above", BOTTOM = "Below" }, label = "Side of the party frame",
  tooltip = "Which side of the party frame the icons sit on.", mode = "simple" }, function(v) s.side = v end)
key("size", { type = "range", default = 22, min = 12, max = 48, step = 1, label = "Icon size",
  tooltip = "Size of the party cooldown icons.", mode = "simple" }, function(v) s.size = v end)
key("spacing", { type = "range", default = 2, min = 0, max = 10, step = 1, label = "Icon spacing",
  tooltip = "Gap between party cooldown icons.", mode = "advanced" }, function(v) s.spacing = v end)
key("offset", { type = "range", default = 2, min = 0, max = 30, step = 1, label = "Gap from the frame",
  tooltip = "Distance between the party frame and its icons.", mode = "advanced" }, function(v) s.offset = v end)
key("max", { type = "range", default = 8, min = 1, max = 16, step = 1, label = "Icons per member",
  tooltip = "Most icons shown for one party member.", mode = "advanced" }, function(v) s.max = v end)
key("showUnseen", { type = "toggle", default = true, label = "Show interrupts before first use",
  tooltip = "Each member's class interrupt shows from the start; other spells appear once that member casts them.", mode = "advanced" },
  function(v) s.showUnseen = v end)
key("includeSelf", { type = "toggle", default = false, label = "Include yourself",
  tooltip = "Also track your own cooldowns.", mode = "advanced" }, function(v) s.includeSelf = v end)
Layout:RegisterElement("pcd.list", { label = "Party cooldowns", owner = OWNER, size = { 260, 120 },
  default = { point = "LEFT", x = 360, y = 0 } })

PCD.module = PUI:RegisterModule(OWNER, {
  label = "Party cooldowns",
  tooltip = "Party interrupts, defensives, group cooldowns, battle res and Bloodlust as icons on the party frames or in a list (an OmniCD-style tracker).",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
PUI.Slash:Register("pcdtest", function() if PCD.active then PCD.Test() else PUI.Slash.Print("turn on Party cooldowns first") end end,
  "fill the party cooldown icons with sample cooldowns")
