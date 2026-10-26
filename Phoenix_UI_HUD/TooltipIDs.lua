local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Tooltip IDs (plan 5.7, mockup 13; owner of tooltip IDs per 1.O: the only
-- place IDs are added - Cast History, Vault, Group Finder never add ID lines).
-- 27 ID kinds in four groups (Items, Spells, World, Collections), derived IDs
-- (icon, use-spell, enchant, bonus, gems, expansion, set, mount, transmog),
-- repeats merged into one plural line per kind, bonus and trait IDs off by
-- default, an optional modifier gate, colours per group, short or full labels,
-- and a copy key that puts the IDs into the shared copy box. Every value is
-- checked with Secret.IsSecret before it is compared or formatted; a secret
-- value is skipped, never an error. Nothing is added during pet battles.
-- Hooks are post-hooks installed once on first enable; they test one boolean
-- when the module or the feature is off.
local _, ns = ...
local Schema, Secret, Theme = PUI.Schema, PUI.Secret, PUI.Theme
local OWNER = "Tooltip"

local IDs = { enabled = true, state = setmetatable({}, { __mode = "k" }), hooked = false, petBattle = false, last = nil }
ns.IDs = IDs
PUI.TooltipIDs = IDs

-- { id, label, group, default }
IDs.KINDS = {
  { "item", "Item", "items", true }, { "icon", "Icon", "items", true }, { "enchant", "Enchant", "items", true },
  { "bonus", "Bonus", "items", false }, { "gem", "Gem", "items", true }, { "expansion", "Expansion", "items", true },
  { "equipmentSet", "Equipment set", "items", true },
  { "spell", "Spell", "spells", true }, { "talent", "Talent", "spells", true }, { "traitNode", "Trait node", "spells", false },
  { "traitEntry", "Trait entry", "spells", false }, { "traitDefinition", "Trait definition", "spells", false },
  { "artifactPower", "Artifact power", "spells", true }, { "petAbility", "Pet ability", "spells", true }, { "macro", "Macro", "spells", true },
  { "npc", "NPC", "world", true }, { "object", "Object", "world", true }, { "quest", "Quest", "world", true },
  { "achievement", "Achievement", "world", true }, { "criteria", "Criteria", "world", true }, { "currency", "Currency", "world", true },
  { "areaPoi", "Area POI", "world", true }, { "vignette", "Vignette", "world", true },
  { "mount", "Mount", "collections", true }, { "visual", "Transmog visual", "collections", true },
  { "source", "Transmog source", "collections", true }, { "species", "Battle pet species", "collections", true },
}
IDs.GROUPS = { items = "Items", spells = "Spells", world = "World", collections = "Collections" }
IDs.GROUP_ORDER = { "items", "spells", "world", "collections" }
local KIND = {}
for i, k in ipairs(IDs.KINDS) do KIND[k[1]] = { label = k[2], group = k[3], default = k[4], order = i } end
IDs.KIND = KIND

local s = { kinds = {}, gate = "off", labels = "full", colorMode = "group", copyKey = "CTRL-C",
  labelColor = { r = 0.6, g = 0.6, b = 0.65, a = 1 }, valueColor = { r = 1, g = 1, b = 1, a = 1 },
  groupColor = { items = { r = 0.55, g = 0.8, b = 1, a = 1 }, spells = { r = 0.75, g = 0.6, b = 1, a = 1 },
    world = { r = 1, g = 0.82, b = 0.4, a = 1 }, collections = { r = 0.5, g = 0.9, b = 0.6, a = 1 } } }
IDs.settings = s
for k, v in pairs(KIND) do s.kinds[k] = v.default end

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local function num(v)
  if not plain(v) then return nil end
  v = tonumber(v)
  if not v or v <= 0 then return nil end
  return v
end
IDs.Num = num

function IDs.GateOpen()
  if s.gate == "shift" then return IsShiftKeyDown() end
  if s.gate == "ctrl" then return IsControlKeyDown() end
  if s.gate == "alt" then return IsAltKeyDown() end
  return true
end

function IDs.Active()
  local TT = ns.TT
  return TT and TT.active and IDs.enabled and not IDs.petBattle and IDs.GateOpen()
end

local function hex(c) return string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end

-- Line(kind, list) -> the coloured text for one kind ("Spell IDs: 1, 2").
function IDs.Line(kind, list)
  local k = KIND[kind]
  local label = k.label
  if s.labels == "short" then label = label:gsub("%s.*$", "") end
  local plural = #list > 1
  local head = label .. (s.labels == "full" and (plural and " IDs" or " ID") or (plural and "s" or ""))
  local lc = s.colorMode == "group" and s.groupColor[k.group] or s.labelColor
  local vals = {}
  for i = 1, #list do vals[i] = tostring(list[i]) end
  return string.format("|cff%s%s:|r |cff%s%s|r", hex(lc), head, hex(s.valueColor), table.concat(vals, ", "))
end

local function leftLine(tooltip, n)
  local name = tooltip.GetName and tooltip:GetName()
  return type(name) == "string" and rawget(_G, name .. "TextLeft" .. n) or nil
end

-- Add(tooltip, kind, id): the one entry point. Repeats of a kind are merged into
-- that kind's line (the line's own FontString is updated when the tooltip has
-- one); an ID already on the tooltip is never added twice.
function IDs.Add(tooltip, kind, id)
  if not IDs.Active() or not KIND[kind] or not s.kinds[kind] then return false end
  id = num(id)
  if not id or not tooltip then return false end
  local st = IDs.state[tooltip]
  if not st then st = { kinds = {}, order = {} }; IDs.state[tooltip] = st end
  local e = st.kinds[kind]
  if e then
    for i = 1, #e.ids do if e.ids[i] == id then return false end end
    e.ids[#e.ids + 1] = id
    if e.fs then e.fs:SetText(IDs.Line(kind, e.ids)); IDs.Remember(tooltip); return true end
  else
    e = { ids = { id } }
    st.kinds[kind] = e
    st.order[#st.order + 1] = kind
  end
  tooltip:AddLine(IDs.Line(kind, e.ids))
  local n = tooltip.NumLines and tooltip:NumLines()
  e.fs = n and leftLine(tooltip, n) or nil
  IDs.Remember(tooltip)
  if tooltip.Show and tooltip.IsShown and tooltip:IsShown() then tooltip:Show() end
  return true
end

-- Plain text of every ID on a tooltip ("Spell IDs: 1, 2\nIcon ID: 3").
function IDs.PlainText(tooltip)
  local st = IDs.state[tooltip]
  if not st then return "" end
  local out = {}
  for _, kind in ipairs(st.order) do
    local e = st.kinds[kind]
    local vals = {}
    for i = 1, #e.ids do vals[i] = tostring(e.ids[i]) end
    out[#out + 1] = KIND[kind].label .. ": " .. table.concat(vals, ", ")
  end
  return table.concat(out, "\n")
end

function IDs.Remember(tooltip)
  IDs.last = tooltip
  IDs.ClaimCopy(true)
end

function IDs.Clear(tooltip)
  IDs.state[tooltip] = nil
  if IDs.last == tooltip then IDs.ClaimCopy(false) end
end

function IDs.CopyLast()
  local text = IDs.last and IDs.PlainText(IDs.last) or ""
  if text == "" then return false end
  PUI.Dialogs:Copy("Tooltip IDs", text, "Ctrl+C to copy, Escape to close.")
  return true
end

-- Copy key: claimed through the binding ledger only while a tooltip shows IDs,
-- and never over a key the player bound themselves.
local copyButton
IDs.copyClaimed = false
function IDs.ClaimCopy(on)
  local key = s.copyKey
  if on and (key == "" or not IDs.Active()) then on = false end
  if on and IDs.copyClaimed then return end
  if not on and not IDs.copyClaimed then return end
  if on then
    for _, c in ipairs(PUI.Bindings:Conflicts(key, OWNER)) do if c.kind == "blizzard" then return end end
    if not copyButton then
      copyButton = PUI:CreateFrame("Button", "PhoenixUI_IDCopyButton", UIParent, nil, OWNER)
      copyButton:SetScript("OnClick", function() IDs.CopyLast() end)
    end
    PUI.Bindings:Claim(OWNER, key, { click = "PhoenixUI_IDCopyButton" })
  else
    PUI.Bindings:Release(OWNER)
  end
  IDs.copyClaimed = on
end

------------------------------------------------------------------------------
-- Derived IDs
-- item:ID:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:spec:upgrade:context:numBonus:bonus...
function IDs.ParseItemLink(link)
  if not plain(link) or type(link) ~= "string" then return nil end
  local body = link:match("item:([%-%d:]+)")
  if not body then return nil end
  local f = {}
  for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = tonumber(v) end
  local out = { item = f[1], enchant = f[2], gems = {}, bonus = {} }
  for i = 3, 6 do if f[i] and f[i] > 0 then out.gems[#out.gems + 1] = f[i] end end
  local n = f[13] or 0
  for i = 1, math.min(n, 16) do local b = f[13 + i]; if b then out.bonus[#out.bonus + 1] = b end end
  return out
end

function IDs.FromItem(tooltip, id, link)
  id = num(id)
  if not id then return end
  IDs.Add(tooltip, "item", id)
  IDs.Add(tooltip, "icon", C_Item.GetItemIconByID(id))
  local _, spellID = C_Item.GetItemSpell(id)
  IDs.Add(tooltip, "spell", spellID)
  local p = IDs.ParseItemLink(link)
  if p then
    IDs.Add(tooltip, "enchant", p.enchant)
    for _, gem in ipairs(p.gems) do IDs.Add(tooltip, "gem", gem) end
    for _, b in ipairs(p.bonus) do IDs.Add(tooltip, "bonus", b) end
  end
  local info = { C_Item.GetItemInfo(link or id) }
  local expac, setID = info[15], info[16]
  if num(expac) ~= 254 then IDs.Add(tooltip, "expansion", expac) end
  IDs.Add(tooltip, "equipmentSet", setID)
  IDs.Add(tooltip, "mount", C_MountJournal.GetMountFromItem(id))
  if plain(link) and link then
    local visual, source = C_TransmogCollection.GetItemInfo(link)
    IDs.Add(tooltip, "visual", visual)
    IDs.Add(tooltip, "source", source)
  end
end

function IDs.FromSpell(tooltip, id)
  id = num(id)
  if not id then return end
  IDs.Add(tooltip, "spell", id)
  IDs.Add(tooltip, "icon", C_Spell.GetSpellTexture(id))
  IDs.Add(tooltip, "mount", C_MountJournal.GetMountFromSpell(id))
end

-- "Creature-0-1465-0-2105-221986-000..." -> 221986 ; GameObject the same.
function IDs.FromGUID(tooltip, guid)
  if not plain(guid) or type(guid) ~= "string" then return end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if kind == "Creature" or kind == "Vehicle" or kind == "Pet" then IDs.Add(tooltip, "npc", id)
  elseif kind == "GameObject" then IDs.Add(tooltip, "object", id) end
end

-- Tooltip data type name -> handler(tooltip, data).
IDs.BY_TYPE = {
  Item = function(tt, d) local link = tt.GetItem and select(2, tt:GetItem()); IDs.FromItem(tt, d.id, d.hyperlink or link) end,
  Toy = function(tt, d) IDs.FromItem(tt, d.id) end,
  Spell = function(tt, d) IDs.FromSpell(tt, d.id) end,
  UnitAura = function(tt, d) IDs.FromSpell(tt, d.id) end,
  PetAction = function(tt, d) IDs.FromSpell(tt, d.id) end,
  Totem = function(tt, d) IDs.FromSpell(tt, d.id) end,
  RecipeRankInfo = function(tt, d) IDs.FromSpell(tt, d.id) end,
  Unit = function(tt, d) IDs.FromGUID(tt, d.guid) end,
  Corpse = function(tt, d) IDs.FromGUID(tt, d.guid) end,
  Object = function(tt, d) IDs.FromGUID(tt, d.guid) end,
  Currency = function(tt, d) IDs.Add(tt, "currency", d.id) end,
  BattlePet = function(tt, d) IDs.Add(tt, "species", d.id) end,
  CompanionPet = function(tt, d) IDs.Add(tt, "species", d.id) end,
  Mount = function(tt, d) IDs.Add(tt, "mount", d.id) end,
  Achievement = function(tt, d) IDs.Add(tt, "achievement", d.id) end,
  Quest = function(tt, d) IDs.Add(tt, "quest", d.id) end,
  EquipmentSet = function(tt, d) IDs.Add(tt, "equipmentSet", d.id) end,
  Macro = function(tt, d) IDs.Add(tt, "macro", d.id) end,
}

function IDs.OnData(tooltip, data, typeName)
  if not IDs.Active() or type(data) ~= "table" then return end
  local name = typeName
  if not name then
    local kind = data.type
    if not plain(kind) then return end
    name = IDs.typeName[kind]
  end
  local fn = name and IDs.BY_TYPE[name]
  if fn then fn(tooltip, data) end
end

-- Hyperlinks: chat links and ItemRefTooltip carry kinds tooltip data may not.
IDs.LINK_KIND = { achievement = "achievement", quest = "quest", enchant = "enchant", talent = "talent", currency = "currency",
  spell = "spell", item = "item", mount = "mount", battlepet = "species", trade = "spell", apower = "artifactPower" }
function IDs.OnHyperlink(tooltip, link)
  if not IDs.Active() or not plain(link) or type(link) ~= "string" then return end
  local lt, id = link:match("^%|?H?(%a+):(%d+)")
  if not lt then lt, id = link:match("|H(%a+):(%d+)") end
  local kind = lt and IDs.LINK_KIND[lt]
  if not kind then return end
  if kind == "item" then IDs.FromItem(tooltip, id, link)
  elseif kind == "spell" then IDs.FromSpell(tooltip, id)
  else IDs.Add(tooltip, kind, id) end
end

function IDs.OnAction(tooltip, slot)
  if not IDs.Active() then return end
  local kind, id = GetActionInfo(slot)
  if kind == "macro" then IDs.Add(tooltip, "macro", id) end
end

-- Talent buttons (Blizzard_PlayerSpells, load-on-demand): trait node, entry, definition.
function IDs.OnTalent(button)
  if not IDs.Active() then return end
  local tt = GameTooltip
  local function field(getter, key)
    local f = button[getter]
    if type(f) == "function" then return f(button) end
    return button[key]
  end
  IDs.Add(tt, "traitNode", field("GetNodeID", "nodeID"))
  IDs.Add(tt, "traitEntry", field("GetEntryID", "entryID"))
  IDs.Add(tt, "traitDefinition", field("GetDefinitionID", "definitionID"))
  local spell = field("GetSpellID", "spellID")
  if spell then IDs.FromSpell(tt, spell) end
end

function IDs.OnPin(pin)
  if not IDs.Active() then return end
  IDs.Add(GameTooltip, "areaPoi", pin.areaPoiID)
  IDs.Add(GameTooltip, "vignette", pin.vignetteID)
end

local lateHooks = {}
local function hookMixin(mixinName, method, fn)
  if lateHooks[mixinName] then return end
  local m = rawget(_G, mixinName)
  if type(m) == "table" and type(m[method]) == "function" then
    hooksecurefunc(m, method, fn)
    lateHooks[mixinName] = true
  end
end
function IDs.HookLate()
  hookMixin("TalentDisplayMixin", "SetTooltipInternal", IDs.OnTalent)
  hookMixin("AreaPOIPinMixin", "OnMouseEnter", IDs.OnPin)
  hookMixin("VignettePinMixin", "OnMouseEnter", IDs.OnPin)
end

function IDs.Hook()
  if IDs.hooked then return end
  IDs.hooked = true
  IDs.typeName = {}
  for name, v in pairs(Enum.TooltipDataType or {}) do IDs.typeName[v] = name end
  if TooltipDataProcessor then
    local all = rawget(TooltipDataProcessor, "AllTypes")
    if all ~= nil then
      TooltipDataProcessor.AddTooltipPostCall(all, IDs.OnData)
    else
      for name in pairs(IDs.BY_TYPE) do
        local v = Enum.TooltipDataType[name]
        if v ~= nil then TooltipDataProcessor.AddTooltipPostCall(v, function(tt, d) IDs.OnData(tt, d, name) end) end
      end
    end
  end
  for _, tipName in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
    local tip = rawget(_G, tipName)
    if tip then
      hooksecurefunc(tip, "SetHyperlink", IDs.OnHyperlink)
      tip:HookScript("OnTooltipCleared", IDs.Clear)
      tip:HookScript("OnHide", function(self) IDs.Clear(self) end)
    end
  end
  hooksecurefunc(GameTooltip, "SetAction", IDs.OnAction)
  IDs.HookLate()
  local f = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  f:RegisterEvent("ADDON_LOADED")
  f:RegisterEvent("PET_BATTLE_OPENING_START")
  f:RegisterEvent("PET_BATTLE_CLOSE")
  f:RegisterEvent("MODIFIER_STATE_CHANGED")
  f:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then IDs.HookLate()
    elseif event == "PET_BATTLE_OPENING_START" then IDs.petBattle = true
    elseif event == "PET_BATTLE_CLOSE" then IDs.petBattle = false
    elseif event == "MODIFIER_STATE_CHANGED" and s.gate ~= "off" and GameTooltip:IsShown() and GameTooltip.RefreshData then
      GameTooltip:RefreshData()
    end
  end)
  IDs.events = f
end

------------------------------------------------------------------------------
-- Settings: tab "Tooltip IDs" (tt.ids.*); the master switch keeps its old key.
local schema = {}
IDs.schema = schema
local function key(k, def, apply)
  def.owner = OWNER
  def.apply = apply
  def.searchTags = def.searchTags or { "id", "ids", "idtip", "tooltip" }
  schema[k] = def
end
key("tt.ids", { type = "toggle", default = true, label = "Tooltip IDs",
  tooltip = "Adds ID lines (spell, item, NPC, quest and 23 more kinds) to tooltips. Phoenix is the only place IDs are added.", mode = "simple" },
  function(v) IDs.enabled = v; if not v then IDs.ClaimCopy(false) end end)
for _, k in ipairs(IDs.KINDS) do
  local id = k[1]
  key("tt.ids." .. id, { type = "toggle", default = k[4], label = IDs.GROUPS[k[3]] .. ": " .. k[2] .. " ID",
    tooltip = "Shows the " .. k[2]:lower() .. " ID on tooltips." .. (k[4] and "" or " Off by default because it is long or rarely needed."),
    mode = "advanced", searchTags = { "id", "ids", "idtip", k[2]:lower(), IDs.GROUPS[k[3]]:lower() } },
    function(v) s.kinds[id] = v end)
end
key("tt.ids.gate", { type = "select", default = "off", choices = { "off", "shift", "ctrl", "alt" },
  choiceLabels = { off = "Always show", shift = "While Shift is held", ctrl = "While Ctrl is held", alt = "While Alt is held" },
  label = "Show IDs", tooltip = "Show IDs all the time, or only while a modifier key is held.", mode = "simple" },
  function(v) s.gate = v end)
key("tt.ids.labels", { type = "select", default = "full", choices = { "full", "short" },
  choiceLabels = { full = "Full (Spell ID: 12294)", short = "Short (Spell: 12294)" }, label = "ID label style",
  tooltip = "How each ID line is labelled.", mode = "advanced" }, function(v) s.labels = v end)
key("tt.ids.colorMode", { type = "select", default = "group", choices = { "group", "single" },
  choiceLabels = { group = "One colour per group", single = "One label colour" }, label = "ID label colours",
  tooltip = "Colour labels by group (Items, Spells, World, Collections) or all the same.", mode = "advanced" }, function(v) s.colorMode = v end)
key("tt.ids.labelColor", { type = "color", default = { r = 0.6, g = 0.6, b = 0.65, a = 1 }, label = "ID label colour",
  tooltip = "Label colour when one label colour is used.", mode = "advanced" }, function(v) s.labelColor = v end)
key("tt.ids.valueColor", { type = "color", default = { r = 1, g = 1, b = 1, a = 1 }, label = "ID number colour",
  tooltip = "Colour of the ID numbers.", mode = "advanced" }, function(v) s.valueColor = v end)
for _, gid in ipairs(IDs.GROUP_ORDER) do
  local cap = gid:gsub("^%l", string.upper)
  key("tt.ids.color" .. cap, { type = "color", default = s.groupColor[gid], label = IDs.GROUPS[gid] .. " label colour",
    tooltip = "Label colour for " .. IDs.GROUPS[gid]:lower() .. " IDs.", mode = "advanced" }, function(v) s.groupColor[gid] = v end)
end
key("tt.ids.copyKey", { type = "keybind", default = "CTRL-C", label = "Copy IDs key",
  tooltip = "While a tooltip shows IDs, this key opens them in the copy box. It is only taken while IDs are on screen, and never over a key you bound yourself. Empty turns it off.",
  mode = "advanced" }, function(v) IDs.ClaimCopy(false); s.copyKey = v end)
for k, def in pairs(schema) do Schema:Register(k, def); def.apply(Schema:Get(k)) end

PUI.Slash:Register("ids", function(rest)
  if rest == "copy" then
    if not IDs.CopyLast() then PUI.Slash.Print("No tooltip IDs to copy yet.") end
    return
  end
  PUI.OptionsHost:OpenOptions("Tooltip")
  local v = PUI.Options and PUI.Options.views and PUI.Options.views.page
  if v and PUI.Options.Render then v.tab = "ids"; PUI.Options:Render() end
end, "[copy]: open the Tooltip IDs page, or copy the IDs of the last tooltip")
