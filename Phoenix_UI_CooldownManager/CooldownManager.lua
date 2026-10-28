local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cooldown Manager (PUI_V2 5.7): Phoenix never draws a cooldown icon itself.
-- The game's Cooldown Viewer item frames (Essential, Utility, Buff Icons, Buff
-- Bars) are re-anchored into Phoenix rows after Blizzard's own layout pass
-- (post-hooks on each viewer's Layout and RefreshLayout). Only positions and
-- sizes change; the frames keep their engine-fed cooldown and aura data, so
-- secret values never pass through Phoenix. A viewer Phoenix does not claim is
-- left to Blizzard. Presets (Minimal / Standard / Everything) and a
-- CDM-only share string (!PUI_CDM) cover Simple mode. Off by default.
-- Step 6 (plan 5.5, 13.6, mockup 05):
--   * restyle: icon zoom, border (textures kept in a weak side table, never
--     as fields on Blizzard frames), cooldown numbers on/off and size;
--   * layouts: right / left / centred rows; every layout key can be set per
--     specialization (overrides);
--   * "on your bars" dedupe: a cooldown already on a Phoenix action bar can
--     be left out of the rows (alpha 0, never Hide/SetParent, G4);
--   * "missing from my bars": tracked cooldowns not on any bar, listed after
--     a talent or spec change and with /pui cdm missing;
--   * tracked buffs feed the Player Aura Bars dedupe (TrackedBuffSpellIDs);
--   * a display-only custom bar for the shared item list (PUI.ItemList; the
--     clickable item bar belongs to Action Bars).
local _, ns = ...
local Schema, Layout, Slash, Secret = PUI.Schema, PUI.Layout, PUI.Slash, PUI.Secret
local OWNER = "CooldownManager"

local CDM = { active = false, hooked = {}, anchors = {}, skins = setmetatable({}, { __mode = "k" }),
  hidden = setmetatable({}, { __mode = "k" }), custom = {} }
ns.CDM = CDM
PUI.CooldownManager = CDM

local VIEWERS = {
  essential = { global = "EssentialCooldownViewer", label = "Essential cooldowns", size = 40, perRow = 8, pos = { "CENTER", 0, -215 } },
  utility = { global = "UtilityCooldownViewer", label = "Utility cooldowns", size = 32, perRow = 8, pos = { "CENTER", 0, -146 } },
  buffIcon = { global = "BuffIconCooldownViewer", label = "Buff icons", size = 32, perRow = 8, pos = { "CENTER", 0, -60 } },
  buffBar = { global = "BuffBarCooldownViewer", label = "Buff bars", size = 200, perRow = 1, pos = { "CENTER", 260, -60 }, bars = true },
}
local ORDER = { "essential", "utility", "buffIcon", "buffBar" }
CDM.VIEWERS, CDM.ORDER = VIEWERS, ORDER
local PRESETS = {
  minimal = { essential = true, utility = false, buffIcon = false, buffBar = false },
  standard = { essential = true, utility = true, buffIcon = true, buffBar = false },
  everything = { essential = true, utility = true, buffIcon = true, buffBar = true },
}
CDM.PRESETS = PRESETS
local BAR_HEIGHT = 20

local cfg = {}
CDM.cfg = cfg
for v, d in pairs(VIEWERS) do cfg[v] = { enabled = true, size = d.size, perRow = d.perRow, spacing = 2, growth = "right" } end
local look = { zoom = 0.08, border = 1, borderColor = { r = 0, g = 0, b = 0, a = 1 }, cdText = true, cdTextSize = 14,
  hideOnBars = false, missingNotice = true }
CDM.look = look
local custom = { on = false, size = 32, perRow = 8, spacing = 2 }
CDM.customCfg = custom

local function anchor(v)
  local a = CDM.anchors[v]
  if not a then
    a = PUI:CreateFrame("Frame", "PhoenixUI_CDM_" .. v, UIParent, nil, OWNER)
    a:SetSize(VIEWERS[v].size, VIEWERS[v].bars and BAR_HEIGHT or VIEWERS[v].size)
    CDM.anchors[v] = a
  end
  return a
end

-- Spell shown by a viewer item (plain data from the cooldown info; a secret
-- value is treated as unknown and never compared).
function CDM.SpellOf(f)
  local id
  local info = f.GetCooldownInfo and f:GetCooldownInfo()
  if type(info) == "table" then id = info.overrideSpellID or info.spellID end
  if id == nil and f.GetSpellID then id = f:GetSpellID() end
  if Secret.IsSecret(id) or type(id) ~= "number" then return nil end
  return id
end

-- True when a spell sits on a shown action slot (a live Phoenix button when
-- Phoenix bars are on, any slot otherwise).
function CDM.OnBars(spell)
  local slots = C_ActionBar.FindSpellActionButtons(spell)
  if not slots or #slots == 0 then return false end
  local AB = PUI.ActionBars
  if not (AB and AB.active) then return true end
  for _, slot in ipairs(slots) do
    local set = AB.Buttons.bySlot[slot]
    if set then for b in pairs(set) do if b.live then return true end end end
  end
  return false
end

-- Item frames of a viewer in Blizzard's order (layoutIndex is a plain number),
-- without the ones the "on your bars" dedupe leaves out.
function CDM.Items(viewer, all)
  local items = viewer:GetItemFrames()
  if type(items) ~= "table" then return {} end
  local list = {}
  local dedupe = look.hideOnBars and not all and (viewer == _G.EssentialCooldownViewer or viewer == _G.UtilityCooldownViewer)
  for _, f in ipairs(items) do
    local spell = dedupe and CDM.SpellOf(f)
    if spell and CDM.OnBars(spell) then
      CDM.hidden[f] = true
      f:SetAlpha(0)
    else
      if CDM.hidden[f] and not all then CDM.hidden[f] = nil; f:SetAlpha(1) end
      list[#list + 1] = f
    end
  end
  table.sort(list, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
  return list
end

-- Restyle one item: zoom, border and cooldown numbers.
function CDM.Skin(f, bars)
  if bars then return end
  local icon = f.Icon
  if type(icon) == "table" and icon.SetTexCoord then
    local z = look.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
  end
  local sk = CDM.skins[f]
  if not sk then
    sk = {}
    for i = 1, 4 do sk[i] = f:CreateTexture(nil, "OVERLAY", nil, 7) end
    CDM.skins[f] = sk
  end
  local px, c = look.border, look.borderColor
  local w = math.max(px, 0.01)
  sk[1]:ClearAllPoints(); sk[1]:SetPoint("TOPLEFT"); sk[1]:SetPoint("TOPRIGHT"); sk[1]:SetHeight(w)
  sk[2]:ClearAllPoints(); sk[2]:SetPoint("BOTTOMLEFT"); sk[2]:SetPoint("BOTTOMRIGHT"); sk[2]:SetHeight(w)
  sk[3]:ClearAllPoints(); sk[3]:SetPoint("TOPLEFT"); sk[3]:SetPoint("BOTTOMLEFT"); sk[3]:SetWidth(w)
  sk[4]:ClearAllPoints(); sk[4]:SetPoint("TOPRIGHT"); sk[4]:SetPoint("BOTTOMRIGHT"); sk[4]:SetWidth(w)
  for i = 1, 4 do sk[i]:SetColorTexture(c.r, c.g, c.b, c.a or 1); sk[i]:SetShown(px > 0) end
  local cd = f.Cooldown
  if type(cd) == "table" and cd.SetHideCountdownNumbers then
    cd:SetHideCountdownNumbers(not look.cdText)
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if type(fs) == "table" and fs.GetFont then
      local path, _, flags = fs:GetFont()
      if path then fs:SetFont(path, look.cdTextSize, flags) end
    end
  end
end

-- Unskin: borders hidden, zoom reset (Blizzard redraws the rest on its pass).
function CDM.Unskin()
  for f, sk in pairs(CDM.skins) do
    for i = 1, 4 do sk[i]:Hide() end
    if type(f.Icon) == "table" and f.Icon.SetTexCoord then f.Icon:SetTexCoord(0, 1, 0, 1) end
  end
  for f in pairs(CDM.hidden) do f:SetAlpha(1); CDM.hidden[f] = nil end
end

-- Grid position of item i (1-based) for a viewer config.
function CDM.Offset(c, i, bars, n)
  local w = c.size
  local h = bars and BAR_HEIGHT or c.size
  local col, row = (i - 1) % c.perRow, math.floor((i - 1) / c.perRow)
  local x = col * (w + c.spacing)
  if c.growth == "left" then x = -x end
  if c.growth == "center" and n then
    -- each row is centred on the anchor (the last row may be shorter)
    local inRow = math.min(c.perRow, n - row * c.perRow)
    x = x - (inRow * (w + c.spacing) - c.spacing) / 2
  end
  return x, -(row * (h + c.spacing))
end

function CDM.Place(v)
  if not CDM.active or not cfg[v].enabled then return end
  local viewer = _G[VIEWERS[v].global]
  if not viewer then return end
  local c, bars, a = cfg[v], VIEWERS[v].bars, anchor(v)
  if look.skinOnly then
    -- W11 skin only: Blizzard keeps every position, size and item; Phoenix only restyles.
    for _, f in ipairs(CDM.Items(viewer, true)) do
      if CDM.hidden[f] then CDM.hidden[f] = nil; f:SetAlpha(1) end
      CDM.Skin(f, bars)
    end
    return
  end
  local point = c.growth == "left" and "TOPRIGHT" or c.growth == "center" and "TOP" or "TOPLEFT"
  local items = CDM.Items(viewer)
  for i, f in ipairs(items) do
    local x, y = CDM.Offset(c, i, bars, #items)
    f:ClearAllPoints()
    f:SetPoint(point, a, point, math.floor(x + 0.5), y)
    f:SetSize(c.size, bars and BAR_HEIGHT or c.size)
    CDM.Skin(f, bars)
  end
  local cols = math.min(c.perRow, math.max(1, #items))
  a:SetSize(cols * (c.size + c.spacing), bars and BAR_HEIGHT or c.size)
  if v == "buffIcon" or v == "buffBar" then CDM.TrackedChanged() end
end

-- Spell IDs the tracked buff icons and bars show (Player Aura Bars dedupe).
function CDM.TrackedBuffSpellIDs()
  local out = {}
  if not CDM.active then return out end
  for _, v in ipairs({ "buffIcon", "buffBar" }) do
    local viewer = _G[VIEWERS[v].global]
    if viewer then
      for _, f in ipairs(CDM.Items(viewer, true)) do
        local id = CDM.SpellOf(f)
        if id then out[#out + 1] = id end
      end
    end
  end
  table.sort(out)
  return out
end

function CDM.TrackedChanged()
  local sig = table.concat(CDM.TrackedBuffSpellIDs(), ",")
  if sig == CDM.trackedSig then return end
  CDM.trackedSig = sig
  PUI.Kernel:Fire("CDM_TRACKED_CHANGED")
end

-- Tracked cooldowns (essential + utility) that are on no action bar.
function CDM.MissingFromBars()
  local out = {}
  for _, v in ipairs({ "essential", "utility" }) do
    local viewer = _G[VIEWERS[v].global]
    if viewer then
      for _, f in ipairs(CDM.Items(viewer, true)) do
        local id = CDM.SpellOf(f)
        if id and not CDM.OnBars(id) then out[#out + 1] = id end
      end
    end
  end
  return out
end

function CDM.ReportMissing(force)
  local list = CDM.MissingFromBars()
  if #list == 0 then
    if force then Slash.Print("every tracked cooldown is on your bars") end
    return list
  end
  local names = {}
  for _, id in ipairs(list) do names[#names + 1] = C_Spell.GetSpellName(id) or tostring(id) end
  Slash.Print("missing from your bars: " .. table.concat(names, ", ") .. " (drag them to a bar, or turn this notice off in Cooldown Manager)")
  return list
end

-- Custom bar (display only): icons for the shared item list.
function CDM.Custom()
  local frame = CDM.customFrame
  if not (CDM.active and custom.on) then
    if frame then frame:Hide() end
    return
  end
  if not frame then
    frame = PUI:CreateFrame("Frame", "PhoenixUI_CDM_custom", UIParent, nil, OWNER)
    CDM.customFrame = frame
  end
  local list = PUI.ItemList:Items()
  for i, e in ipairs(list) do
    local b = CDM.custom[i]
    if not b then
      b = PUI:CreateFrame("Frame", nil, frame, nil, OWNER)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetAllPoints()
      PUI.Look.Shape(b.icon, b)
      b.cd = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER)
      b.cd:SetAllPoints()
      b.count = b:CreateFontString(nil, "OVERLAY")
      b.count:SetFontObject(PUI.Media:FontObject("number"))
      b.count:SetPoint("BOTTOMRIGHT", -2, 2)
      CDM.custom[i] = b
      CDM.Skin(b, false)
    end
    b.Icon, b.Cooldown = b.icon, b.cd
    local x, y = CDM.Offset(custom, i, false)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    b:SetSize(custom.size, custom.size)
    b.icon:SetTexture(PUI.ItemList.Icon(e))
    b.count:SetText(PUI.ItemList.Count(e))
    PUI.ItemList.ApplyCooldown(b.cd, e)
    CDM.Skin(b, false)
    b:Show()
  end
  for i = #list + 1, #CDM.custom do CDM.custom[i]:Hide() end
  local cols = math.min(custom.perRow, math.max(1, #list))
  local rows = math.max(1, math.ceil(#list / custom.perRow))
  frame:SetSize(cols * (custom.size + custom.spacing), rows * (custom.size + custom.spacing))
  Layout:Place(frame, "cdm.custom")
  frame:Show()
end
PUI.ItemList:OnChange("cdm.custom", function() CDM.Custom() end)

local function hook(v)
  if CDM.hooked[v] then return end
  local viewer = _G[VIEWERS[v].global]
  if not viewer then return end
  local after = function() CDM.Place(v) end
  hooksecurefunc(viewer, "RefreshLayout", after)
  if viewer.Layout then hooksecurefunc(viewer, "Layout", after) end
  CDM.hooked[v] = true
end

function CDM.Refresh(v)
  if not CDM.active then return end
  for _, k in ipairs(v and { v } or ORDER) do
    Layout:Place(anchor(k), "cdm." .. k)
    if cfg[k].enabled then hook(k); CDM.Place(k) end
  end
  if not v then CDM.Custom() end
end

-- Share string: "!PUI_CDM" + base64(compressed "key=value" lines of cdm.* keys).
CDM.PREFIX = "!PUI_CDM"
function CDM.Export()
  local lines = {}
  for _, key in ipairs(Schema.keys) do
    local def = Schema:Def(key)
    if key:find("^cdm%.") and not Schema.TABLE_TYPES[def.type] then lines[#lines + 1] = key .. "=" .. tostring(Schema:Get(key)) end
  end
  return CDM.PREFIX .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(table.concat(lines, "\n")))
end

-- Returns the number of settings applied, or nil and a reason. Unknown keys and
-- invalid values are skipped; nothing outside cdm.* is ever written.
function CDM.Import(text)
  if type(text) ~= "string" or text:sub(1, #CDM.PREFIX) ~= CDM.PREFIX then return nil, "not a !PUI_CDM string" end
  local raw = C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(text:sub(#CDM.PREFIX + 1)))
  if type(raw) ~= "string" then return nil, "unreadable string" end
  local n = 0
  for line in raw:gmatch("[^\n]+") do
    local key, value = line:match("^(cdm%.[%w%.]+)=(.*)$")
    local def = key and Schema:Def(key)
    if def then
      local v = value
      if def.type == "toggle" then v = value == "true"
      elseif def.type == "range" then v = tonumber(value) end
      if v ~= nil and Schema:Validate(def, v) then Schema:Set(key, v); n = n + 1 end
    end
  end
  return n
end

Slash:Register("cdm", function(rest)
  local cmd, arg = (rest or ""):match("^(%S*)%s*(.*)$")
  if cmd == "export" then
    Slash.Print(CDM.Export())
  elseif cmd == "missing" then
    CDM.ReportMissing(true)
  elseif cmd == "import" then
    local n, why = CDM.Import(arg)
    Slash.Print(n and ("imported " .. n .. " cooldown manager settings") or ("not imported: " .. why))
  else
    Slash.Print("usage: /pui cdm export | import <!PUI_CDM string> | missing")
  end
end, "export | import <string> | missing: share settings, list tracked cooldowns missing from your bars")

-- Lifecycle ---------------------------------------------------------------------
local function onEnable(mod)
  CDM.active = true
  CDM.Refresh()
  local talents = function()
    if not look.missingNotice then return end
    C_Timer.After(1.5, function() if CDM.active and look.missingNotice then CDM.ReportMissing(false) end end)
  end
  mod:RegisterEvent("TRAIT_CONFIG_UPDATED", talents)
  mod:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", talents)
  mod:RegisterEvent("ACTIONBAR_SLOT_CHANGED", function() if look.hideOnBars then CDM.Refresh("essential"); CDM.Refresh("utility") end end)
  mod:RegisterEvent("BAG_UPDATE_COOLDOWN", function() if custom.on then CDM.Custom() end end)
end

local function onDisable()
  CDM.active = false
  CDM.Unskin()
  if CDM.customFrame then CDM.customFrame:Hide() end
  CDM.TrackedChanged()
  -- Blizzard lays its frames out again on its next pass; ask for one now.
  for _, v in ipairs(ORDER) do
    local viewer = _G[VIEWERS[v].global]
    if viewer and viewer.RefreshLayout then viewer:RefreshLayout() end
  end
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
CDM.schema = schema
local function key(name, def, set, v)
  def.owner = OWNER
  def.apply = function(value) set(value); CDM.Refresh(v) end
  schema["cdm." .. name] = def
end

key("preset", { type = "select", default = "custom", choices = { "custom", "minimal", "standard", "everything" },
  label = "Cooldown manager preset", tooltip = "Minimal: essential cooldowns only. Standard: adds utility cooldowns and buff icons. Everything: adds buff bars. Custom keeps your own choices.",
  mode = "simple" }, function(value)
  local p = PRESETS[value]
  if not p then return end
  for v, on in pairs(p) do if Schema:Get("cdm." .. v .. ".enabled") ~= on then Schema:Set("cdm." .. v .. ".enabled", on) end end
end)
for _, v in ipairs(ORDER) do
  local d = VIEWERS[v]
  key(v .. ".enabled", { type = "toggle", default = true, label = d.label .. ": Phoenix layout",
    tooltip = "Phoenix positions the game's " .. d.label:lower() .. " in its own rows; off leaves them to the game.", mode = "simple" },
    function(value) cfg[v].enabled = value end, v)
  schema["cdm." .. v .. ".enabled"].overridable = true
  key(v .. ".size", { type = "range", default = d.size, min = d.bars and 80 or 16, max = d.bars and 400 or 80, step = 1,
    label = d.label .. (d.bars and ": width" or ": icon size"), tooltip = "Size of each " .. (d.bars and "bar" or "icon") .. ".", mode = d.bars and "advanced" or "simple", overridable = true },
    function(value) cfg[v].size = value end, v)
  key(v .. ".perRow", { type = "range", default = d.perRow, min = 1, max = 20, step = 1, label = d.label .. ": per row",
    tooltip = "How many fit in one row before wrapping (overflow goes to the next row).", mode = "advanced", overridable = true },
    function(value) cfg[v].perRow = value end, v)
  key(v .. ".spacing", { type = "range", default = 2, min = 0, max = 20, step = 1, label = d.label .. ": spacing",
    tooltip = "Gap between items.", mode = "advanced", overridable = true }, function(value) cfg[v].spacing = value end, v)
  key(v .. ".growth", { type = "select", default = "right", choices = { "right", "left", "center" },
    choiceLabels = { right = "From the left edge", left = "From the right edge", center = "Centred" }, label = d.label .. ": growth",
    tooltip = "Rows start at the anchor's left edge, its right edge, or are centred on it.", mode = "advanced", overridable = true },
    function(value) cfg[v].growth = value end, v)
  Layout:RegisterElement("cdm." .. v, { label = d.label, owner = OWNER, size = { d.size, d.bars and BAR_HEIGHT or d.size },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

local function lookKey(name, def, set)
  def.owner = OWNER
  def.apply = function(value) set(value); CDM.Refresh() end
  schema["cdm." .. name] = def
end
lookKey("zoom", { type = "range", default = 0.08, min = 0, max = 0.2, step = 0.01, label = "Cooldown icon zoom",
  tooltip = "Crops the icon edge so the artwork fills the square.", mode = "advanced" }, function(v) look.zoom = v end)
lookKey("border", { type = "range", default = 1, min = 0, max = 4, step = 1, label = "Cooldown icon border",
  tooltip = "Border thickness in pixels (0 hides it).", mode = "simple" }, function(v) look.border = v end)
lookKey("borderColor", { type = "color", default = { r = 0, g = 0, b = 0, a = 1 }, label = "Cooldown icon border colour",
  tooltip = "Colour of the icon border.", mode = "advanced" }, function(v) look.borderColor = v end)
lookKey("cdText", { type = "toggle", default = true, label = "Cooldown numbers on icons",
  tooltip = "Shows the time left as numbers on each cooldown icon (the game's own countdown).", mode = "simple" },
  function(v) look.cdText = v end)
lookKey("cdTextSize", { type = "range", default = 14, min = 8, max = 32, step = 1, label = "Cooldown number size",
  tooltip = "Font size of the cooldown numbers on icons.", mode = "advanced" }, function(v) look.cdTextSize = v end)
lookKey("skinOnly", { type = "toggle", default = false, label = "Skin only (keep Blizzard's layout)",
  tooltip = "Phoenix only restyles the cooldown icons and bars; their places, sizes and which ones show stay as Blizzard's Cooldown Manager sets them (from the game's next layout pass). The safest mode for testing.",
  mode = "simple", searchTags = { "skin", "blizzard layout" } }, function(v) look.skinOnly = v end)
lookKey("hideOnBars", { type = "toggle", default = false, label = "Leave out cooldowns already on your bars",
  tooltip = "An essential or utility cooldown that is on one of your shown action bars is left out of these rows, so it appears once.",
  mode = "simple", overridable = true, searchTags = { "duplicate", "dedupe", "action bars" } }, function(v) look.hideOnBars = v end)
lookKey("missingNotice", { type = "toggle", default = true, label = "Tell me what is missing from my bars",
  tooltip = "After a talent or specialization change, lists tracked cooldowns that are on none of your action bars.",
  mode = "advanced", searchTags = { "missing", "talents" } }, function(v) look.missingNotice = v end)
local function customKey(name, def, set)
  def.owner = OWNER
  def.apply = function(value) set(value); CDM.Custom() end
  schema["cdm.custom." .. name] = def
end
customKey("enabled", { type = "toggle", default = false, label = "Custom bar: item cooldowns",
  tooltip = "Shows the items from the shared item list (potions, healthstones, on-use trinkets) with their cooldowns. Display only: the clickable item bar is part of Action Bars.",
  mode = "simple", searchTags = { "potion", "trinket", "items" } }, function(v) custom.on = v end)
customKey("size", { type = "range", default = 32, min = 16, max = 80, step = 1, label = "Custom bar: icon size",
  tooltip = "Size of each custom bar icon.", mode = "advanced", overridable = true }, function(v) custom.size = v end)
customKey("perRow", { type = "range", default = 8, min = 1, max = 20, step = 1, label = "Custom bar: per row",
  tooltip = "Icons per row on the custom bar.", mode = "advanced" }, function(v) custom.perRow = v end)
customKey("spacing", { type = "range", default = 2, min = 0, max = 20, step = 1, label = "Custom bar: spacing",
  tooltip = "Gap between custom bar icons.", mode = "advanced" }, function(v) custom.spacing = v end)
Layout:RegisterElement("cdm.custom", { label = "Custom cooldown bar", owner = OWNER, size = { 8 * 34, 32 },
  default = { point = "CENTER", x = -260, y = -215 } })

local Coexist = PUI.Coexist
local ckey, cdef = Coexist:Define("cooldownmanager", { module = OWNER, job = "Cooldown manager",
  addons = { "EllesmereUICooldownManager", "BetterCooldownManager", "CooldownManagerCentered" } })
cdef.owner = OWNER
schema[ckey] = cdef

CDM.module = PUI:RegisterModule(OWNER, {
  loadCondition = function() return Coexist:Allows("cooldownmanager") end,
  label = "Cooldown manager",
  tooltip = "Lays out the game's Cooldown Viewer icons and bars in Phoenix rows (the game still draws every cooldown).",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
for k, def in pairs(schema) do if k ~= "cdm.preset" and k ~= ckey then def.apply(Schema:Get(k)) end end
