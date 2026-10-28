local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Auto item bars: up to five bars that fill themselves from your bags and
-- gear by category (flasks, food, potions, healthstones, augment runes,
-- weapon oils, on-use trinkets and gear, quest items, a custom list) plus a
-- class battle-res button with the shared charges. Phoenix's own design.
--   * Buttons are SecureActionButtonTemplate children of a
--     SecureHandlerStateTemplate header: "item:ID" for bag items, the
--     inventory slot for gear, "spell" for the battle res.
--   * The button set is rebuilt only out of combat through the CombatQueue
--     (bag changes in combat are queued until combat ends); counts and
--     cooldowns repaint in combat. Cooldown and charge values go straight to
--     widgets, never compared.
--   * Category detection: the curated PUI.ItemBarData table first, then the
--     item's class and consumable subclass from C_Item.GetItemInfoInstant.
local _, ns = ...
local Schema, Layout, CQ, Secret = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Secret
local Btn = ns.Buttons
local D = PUI.ItemBarData
local OWNER = "ActionBars"
local NUM = 5

local IB = { bars = {}, NUM = NUM, buttons = {} }
ns.ItemBars = IB

-- Categories, in their default order. retail = false: hidden on WoW Forever.
IB.CATEGORIES = {
  { id = "healing", label = "Healing potions & healthstones" },
  { id = "combat", label = "Combat potions" },
  { id = "flask", label = "Flasks, phials & elixirs" },
  { id = "food", label = "Food & drink" },
  { id = "rune", label = "Augment runes", retail = true },
  { id = "oil", label = "Weapon oils & stones" },
  { id = "trinket", label = "On-use trinkets" },
  { id = "gear", label = "On-use gear (engineering)" },
  { id = "quest", label = "Quest items" },
  { id = "custom", label = "Custom item list" },
  { id = "brez", label = "Battle res (your class)" },
}
function IB.Categories()
  local out = {}
  for _, c in ipairs(IB.CATEGORIES) do if not (c.retail and not PUI.IS_RETAIL) then out[#out + 1] = c end end
  return out
end
local function columns()
  local out = {}
  for i = 1, NUM do out[i] = { id = "bar" .. i, label = "Bar " .. i } end
  return out
end

local DEFAULT_ON = { [1] = true, [2] = true, [3] = true }
local DEFAULT_CATS = {
  bar1 = { flask = true, food = true, rune = true, oil = true },
  bar2 = { healing = true, combat = true, trinket = true, gear = true, brez = true },
  bar3 = { quest = true },
  bar4 = { custom = true },
}
local function defaultGrid()
  local g = {}
  for _, c in ipairs(IB.Categories()) do
    local row = {}
    for i = 1, NUM do row["bar" .. i] = (DEFAULT_CATS["bar" .. i] or {})[c.id] == true end
    g[c.id] = row
  end
  return g
end
IB.DEFAULT_GRID = defaultGrid

local POS = { { "BOTTOM", -330, 176 }, { "BOTTOM", 330, 176 }, { "BOTTOM", 0, 214 }, { "BOTTOM", -330, 214 }, { "BOTTOM", 330, 214 } }
local BASE_VIS = "[petbattle][vehicleui][overridebar][possessbar] hide; show"
local MACRO_HIDE = { vehicle = "[vehicleui]", petBattle = "[petbattle]", mounted = "[mounted]", skyriding = "[bonusbar:5]" }

local cfg = { grid = defaultGrid(), custom = { "5512" }, brezCharges = true }
IB.cfg = cfg
for i = 1, NUM do
  cfg[i] = { on = DEFAULT_ON[i] == true, size = 32, spacing = 2, perRow = 12, grow = "RIGHT", sort = "category",
    mouseover = false, fadeAlpha = 0.3, show = { mode = "always" }, hideMissing = true, count = true, cooldown = true }
end

local function AB() return ns.AB end

-- Category detection ----------------------------------------------------------------
function IB.Classify(id)
  local cat = D.byId[id]
  if cat then return cat end
  local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
  if classID == D.CLASS_CONSUMABLE then return D.CONSUMABLE[subID] end
  if classID == D.CLASS_QUEST and C_Item.GetItemSpell(id) then return "quest" end
  return nil
end

-- Unique item IDs in the backpack and bags (plain data), in bag order.
function IB.BagItems()
  local out, seen = {}, {}
  local last = PUI.IS_RETAIL and 5 or 4
  for bag = 0, last do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID
      if id and not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
  end
  return out
end

local function spellKnown(id)
  if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
  return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- The class battle-res spell the player knows, or nil.
function IB.BrezSpell()
  local _, class = UnitClass("player")
  for _, id in ipairs(D.BREZ[class] or {}) do if spellKnown(id) then return id end end
  return nil
end

-- Shared battle-res charges (Ascent's reading when it is loaded).
function IB.BrezCharges()
  if PUI.Ascent and PUI.Ascent.BattleRes then return PUI.Ascent.BattleRes() end
  if not (C_Spell and C_Spell.GetSpellCharges) then return nil end
  local c = C_Spell.GetSpellCharges(D.BREZ_SHARED)
  if not c then return nil end
  return { charges = c.currentCharges, max = c.maxCharges, start = c.cooldownStartTime, duration = c.cooldownDuration }
end

local function count(id) return C_Item.GetItemCount(id, false, true) or 0 end

-- Entries for bar i: { kind = "item"|"slot"|"spell", id, slot?, cat }.
function IB.Entries(i)
  local c = cfg[i]
  local wants, order = {}, {}
  for _, cat in ipairs(IB.Categories()) do
    local row = cfg.grid[cat.id]
    if row and row["bar" .. i] then wants[cat.id] = true; order[#order + 1] = cat.id end
  end
  local buckets = {}
  for _, id in ipairs(order) do buckets[id] = {} end
  if wants.trinket or wants.gear then
    for slot = 1, 19 do
      local id = GetInventoryItemID("player", slot)
      local cat = (slot == 13 or slot == 14) and "trinket" or "gear"
      if id and wants[cat] and C_Item.GetItemSpell(id) then table.insert(buckets[cat], { kind = "slot", slot = slot, id = id, cat = cat }) end
    end
  end
  local bagWanted = false
  for _, k in ipairs({ "healing", "combat", "flask", "food", "rune", "oil", "quest" }) do if wants[k] then bagWanted = true end end
  if bagWanted then
    for _, id in ipairs(IB.BagItems()) do
      local cat = IB.Classify(id)
      if cat and wants[cat] then table.insert(buckets[cat], { kind = "item", id = id, cat = cat }) end
    end
  end
  if wants.custom then
    for _, id in ipairs(PUI.ItemList.Parse(cfg.custom)) do
      if not c.hideMissing or count(id) > 0 then table.insert(buckets.custom, { kind = "item", id = id, cat = "custom" }) end
    end
  end
  if wants.brez then
    local sp = IB.BrezSpell()
    if sp then table.insert(buckets.brez, { kind = "spell", id = sp, cat = "brez" }) end
  end
  local out = {}
  for _, cat in ipairs(order) do for _, e in ipairs(buckets[cat]) do out[#out + 1] = e end end
  if c.sort == "id" then
    table.sort(out, function(a, b) if a.id ~= b.id then return a.id < b.id end return (a.slot or 0) < (b.slot or 0) end)
  elseif c.sort == "count" then
    local n = {}
    for _, e in ipairs(out) do n[e] = e.kind == "item" and count(e.id) or 0 end
    local rank = {}
    for k, e in ipairs(out) do rank[e] = k end
    table.sort(out, function(a, b) if n[a] ~= n[b] then return n[a] > n[b] end return rank[a] < rank[b] end)
  end
  return out
end

-- Buttons ---------------------------------------------------------------------------
local function header(i)
  local bar = IB.bars[i]
  if bar then return bar end
  local h = PUI:CreateFrame("Frame", "PhoenixUI_AutoItemBar" .. i, UIParent, "SecureHandlerStateTemplate", OWNER)
  bar = { index = i, header = h, buttons = {}, n = 0, entries = {}, ruleShown = true }
  IB.bars[i] = bar
  return bar
end

local function hover(bar, on)
  local c = cfg[bar.index]
  if c.mouseover then bar.header:SetAlpha(on and 1 or c.fadeAlpha) end
end

local function button(bar, j)
  local b = bar.buttons[j]
  if b then return b end
  b = PUI:CreateFrame("Button", bar.header:GetName() .. "Button" .. j, bar.header, "SecureActionButtonTemplate", OWNER)
  b:RegisterForClicks("AnyUp", "AnyDown")
  Btn.Skin(b)
  b:SetScript("OnEnter", function(self)
    hover(bar, true)
    if not Btn.S.tooltips or not self.entry then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    local e = self.entry
    if e.kind == "slot" then GameTooltip:SetInventoryItem("player", e.slot)
    elseif e.kind == "spell" then GameTooltip:SetSpellByID(e.id)
    else GameTooltip:SetItemByID(e.id) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() hover(bar, false); GameTooltip:Hide() end)
  bar.buttons[j] = b
  IB.buttons[#IB.buttons + 1] = b
  return b
end

local function configure(b, e)
  b.entry = e
  if e.kind == "spell" then
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", e.id)
    b:SetAttribute("item", nil)
  else
    b:SetAttribute("type", "item")
    b:SetAttribute("item", e.kind == "slot" and tostring(e.slot) or ("item:" .. e.id))
    b:SetAttribute("spell", nil)
  end
end

-- Offset of button j for a grow direction (plain layout math).
function IB.Offset(j, perRow, size, gap, grow)
  local major, minor = (j - 1) % perRow, math.floor((j - 1) / perRow)
  local step = size + gap
  local function neg(v) return v == 0 and 0 or -v end
  if grow == "LEFT" then return "TOPRIGHT", neg(major * step), neg(minor * step) end
  if grow == "DOWN" then return "TOPLEFT", minor * step, neg(major * step) end
  if grow == "UP" then return "BOTTOMLEFT", minor * step, major * step end
  return "TOPLEFT", major * step, neg(minor * step)
end

local function layout(bar)
  local c = cfg[bar.index]
  local n = bar.n
  local perRow = math.max(1, math.min(c.perRow, math.max(n, 1)))
  local lines = math.max(1, math.ceil(n / perRow))
  local size, gap = c.size, c.spacing
  local w, h = perRow * size + (perRow - 1) * gap, lines * size + (lines - 1) * gap
  if c.grow == "UP" or c.grow == "DOWN" then w, h = h, w end
  bar.header:SetSize(math.max(w, 1), math.max(h, 1))
  for j, b in ipairs(bar.buttons) do
    b:ClearAllPoints()
    b:SetSize(size, size)
    if j <= n then
      local point, x, y = IB.Offset(j, perRow, size, gap, c.grow)
      b:SetPoint(point, bar.header, point, x, y)
      b:Show()
      b.live = true
    else
      b:Hide()
      b.live = false
      b.entry = false
    end
  end
  local id = "ab.ibar" .. bar.index
  local el = Layout:Element(id)
  if el then el.size = { bar.header:GetWidth(), bar.header:GetHeight() } end
  Layout:Place(bar.header, id)
end

-- Secure visibility driver: the parts of the rule a driver can test.
function IB.Driver(i)
  local bar = IB.bars[i]
  if bar and (bar.n == 0 or bar.ruleShown == false) then return "hide" end
  local rule = cfg[i].show or {}
  if rule.mode == "never" then return "hide" end
  local conds = {}
  if rule.mode == "when" then
    for _, h in ipairs({ "vehicle", "petBattle", "mounted", "skyriding" }) do
      if rule.hide and rule.hide[h] then conds[#conds + 1] = MACRO_HIDE[h] end
    end
    if rule.combat == "in" then conds[#conds + 1] = "[nocombat]" end
    if rule.combat == "out" then conds[#conds + 1] = "[combat]" end
  end
  if #conds == 0 then return BASE_VIS end
  return table.concat(conds) .. " hide; " .. BASE_VIS
end

-- The out-of-combat part of the rule, for PUI.Visibility.
function IB.WatchedRule(i)
  local rule = cfg[i].show or {}
  if rule.mode ~= "when" then return { mode = "always" } end
  local out = { mode = "when", content = rule.content, group = rule.group, specs = rule.specs, combat = "any" }
  if rule.hide and rule.hide.resting then out.hide = { resting = true } end
  return out
end

local function watch(bar)
  local i = bar.index
  PUI.Visibility:Watch("ab.ibar" .. i, IB.WatchedRule(i), function(shown)
    if bar.ruleShown == shown then return end
    bar.ruleShown = shown
    CQ.Defer("ab.ibarvis" .. i, function()
      local ab = AB()
      if ab and ab.active and cfg[i].on then RegisterStateDriver(bar.header, "visibility", IB.Driver(i)) end
    end)
  end)
end

-- Visual refresh (safe in combat): icon, count, cooldown.
function IB.Paint(i)
  local bar = IB.bars[i]
  if not bar then return end
  local c = cfg[i]
  for j = 1, bar.n do
    local b, e = bar.buttons[j], bar.entries[j]
    if b and e then
      b.count:SetShown(c.count)
      b.cooldown:SetShown(c.cooldown)
      if e.kind == "spell" then
        b.icon:SetTexture(C_Spell.GetSpellTexture(e.id))
        local br = cfg.brezCharges and IB.BrezCharges()
        if br then
          b.count:SetText(Secret.ToText(br.charges))
          b.cooldown:SetCooldown(br.start or 0, br.duration or 0)
        else
          b.count:SetText("")
          local cd = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(e.id)
          b.cooldown:SetCooldown(cd and cd.startTime or 0, cd and cd.duration or 0)
        end
      else
        b.icon:SetTexture(PUI.ItemList.Icon(e))
        b.count:SetText(PUI.ItemList.Count(e))
        PUI.ItemList.ApplyCooldown(b.cooldown, e)
        b.icon:SetDesaturated(e.kind == "item" and count(e.id) == 0)
      end
      Btn.UpdateHotkey(b)
    end
  end
end

function IB.Apply(i)
  local ab = AB()
  if not (ab and ab.active) then return end
  CQ.Defer("ab.ibar" .. i, function()
    if not ab.active then return end
    local c, bar = cfg[i], IB.bars[i]
    if not c.on then
      if bar then
        PUI.Visibility:Unwatch("ab.ibar" .. i)
        UnregisterStateDriver(bar.header, "visibility")
        bar.header:Hide()
        for _, b in ipairs(bar.buttons) do b.live = false end
      end
      return
    end
    bar = header(i)
    local entries = IB.Entries(i)
    local n = math.min(#entries, 24)
    bar.entries, bar.n = entries, n
    for j = 1, n do
      local b = button(bar, j)
      configure(b, entries[j])
      Btn.ApplyLook(b)
    end
    layout(bar)
    watch(bar)
    RegisterStateDriver(bar.header, "visibility", IB.Driver(i))
    bar.header:SetAlpha(c.mouseover and c.fadeAlpha or 1)
    if ns.KB then ns.KB.Apply() end
    IB.Paint(i)
  end)
end

function IB.ApplyAll() for i = 1, NUM do IB.Apply(i) end end
function IB.Refresh() for i = 1, NUM do IB.Paint(i) end end
function IB.Off()
  for i, bar in pairs(IB.bars) do
    PUI.Visibility:Unwatch("ab.ibar" .. i)
    UnregisterStateDriver(bar.header, "visibility")
    bar.header:Hide()
    for _, b in ipairs(bar.buttons) do b.live = false end
  end
end

-- A module keeps one handler per event, so these chain after the ones the
-- other Action Bars parts registered first.
local function chain(mod, event, fn)
  local prev = mod.handlers[event]
  mod:RegisterEvent(event, function(m, e, ...)
    if prev then prev(m, e, ...) end
    fn()
  end)
end
function IB.Wire(mod)
  local rebuild = function() IB.ApplyAll() end
  chain(mod, "BAG_UPDATE_DELAYED", rebuild)
  chain(mod, "PLAYER_EQUIPMENT_CHANGED", rebuild)
  chain(mod, "SPELLS_CHANGED", rebuild)
  chain(mod, "BAG_UPDATE_COOLDOWN", IB.Refresh)
  chain(mod, "SPELL_UPDATE_CHARGES", IB.Refresh)
  chain(mod, "SPELL_UPDATE_COOLDOWN", IB.Refresh)
end

PUI.ItemList:OnChange("ab.ibars", function() IB.ApplyAll() end)

-- Schema ------------------------------------------------------------------------------
local schema = {}
IB.schema = schema
local function key(name, def, set, which)
  def.owner = OWNER
  def.apply = function(v)
    set(v)
    if which then IB.Apply(which) else IB.ApplyAll() end
  end
  schema[name] = def
end

key("ab.ibars.categories", { type = "grid", default = defaultGrid(), rows = IB.Categories, columns = columns,
  label = "Auto item bars: what each bar shows",
  tooltip = "Tick the categories each auto item bar fills itself with, from your bags and gear. Rows run top to bottom in the order the buttons appear.",
  mode = "simple", searchTags = { "flask", "food", "potion", "healthstone", "rune", "oil", "trinket", "quest", "battle res", "consumable", "windtools" } },
  function(v) cfg.grid = v end)
key("ab.ibars.custom", { type = "list", default = { "5512" }, maxItems = 24, label = "Auto item bars: custom items",
  tooltip = "Item IDs for the Custom item list category, in order.", mode = "simple",
  itemValidate = function(v) return tonumber(v) ~= nil, "an item ID" end }, function(v) cfg.custom = v end)
key("ab.ibars.brezCharges", { type = "toggle", default = true, label = "Auto item bars: battle res charges",
  tooltip = "The battle res button shows the group's shared charges and recharge timer (keys and boss fights) instead of the spell's own cooldown.",
  mode = "advanced", searchTags = { "battle res", "brez", "rebirth" } }, function(v) cfg.brezCharges = v end)

local GROW = { "RIGHT", "LEFT", "DOWN", "UP" }
local GROW_LABELS = { RIGHT = "Right", LEFT = "Left", DOWN = "Down", UP = "Up" }
local SORTS = { "category", "count", "id" }
local SORT_LABELS = { category = "By category", count = "Most carried first", id = "By item ID" }
for i = 1, NUM do
  local c = cfg[i]
  local L = "Auto item bar " .. i
  local function bk(name, def, set) key("ab.ibar" .. i .. "." .. name, def, function(v) set(c, v) end, i) end
  bk("enabled", { type = "toggle", default = c.on, label = L,
    tooltip = "Turns auto item bar " .. i .. " on. It fills itself with the categories ticked for it.", mode = "simple",
    searchTags = { "consumable", "flask", "potion", "item bar" } }, function(t, v) t.on = v end)
  bk("size", { type = "range", default = 32, min = 16, max = 64, step = 1, label = L .. " button size",
    tooltip = "Button size of auto item bar " .. i .. " in pixels.", mode = "simple" }, function(t, v) t.size = v end)
  bk("spacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = L .. " spacing",
    tooltip = "Gap between buttons of auto item bar " .. i .. ".", mode = "advanced" }, function(t, v) t.spacing = v end)
  bk("perRow", { type = "range", default = 12, min = 1, max = 24, step = 1, label = L .. " buttons per row",
    tooltip = "Buttons in each row (or column) of auto item bar " .. i .. ".", mode = "advanced" }, function(t, v) t.perRow = v end)
  bk("grow", { type = "select", default = "RIGHT", choices = GROW, choiceLabels = GROW_LABELS, label = L .. " grow direction",
    tooltip = "Which way auto item bar " .. i .. " adds buttons.", mode = "advanced" }, function(t, v) t.grow = v end)
  bk("sort", { type = "select", default = "category", choices = SORTS, choiceLabels = SORT_LABELS, label = L .. " order",
    tooltip = "Order of the buttons on auto item bar " .. i .. ".", mode = "advanced" }, function(t, v) t.sort = v end)
  bk("count", { type = "toggle", default = true, label = L .. " item counts",
    tooltip = "Shows how many of each item you carry on auto item bar " .. i .. ".", mode = "advanced" }, function(t, v) t.count = v end)
  bk("cooldown", { type = "toggle", default = true, label = L .. " cooldowns",
    tooltip = "Shows cooldown swipes on auto item bar " .. i .. ".", mode = "advanced" }, function(t, v) t.cooldown = v end)
  bk("hideMissing", { type = "toggle", default = true, label = L .. " hides missing custom items",
    tooltip = "Custom items you do not carry are left off auto item bar " .. i .. " (otherwise shown greyed out).", mode = "advanced" }, function(t, v) t.hideMissing = v end)
  bk("mouseover", { type = "toggle", default = false, label = L .. " fade until mouse-over",
    tooltip = "Auto item bar " .. i .. " stays faded until you point at it.", mode = "advanced" }, function(t, v) t.mouseover = v end)
  bk("fadeAlpha", { type = "range", default = 0.3, min = 0, max = 1, step = 0.05, label = L .. " fade opacity",
    tooltip = "Opacity of auto item bar " .. i .. " while faded.", mode = "advanced" }, function(t, v) t.fadeAlpha = v end)
  bk("show", { type = "visibility", default = { mode = "always" }, label = L .. ": where to show",
    tooltip = "Show auto item bar " .. i .. " everywhere, never, or only in the content, combat state, group and specialization you pick.",
    mode = "simple", watchId = "ab.ibar" .. i }, function(t, v)
      t.show = v
      local bar = IB.bars[i]
      if bar then bar.ruleShown = true; PUI.Visibility:SetRule("ab.ibar" .. i, IB.WatchedRule(i)) end
    end)
  Layout:RegisterElement("ab.ibar" .. i, { label = L, owner = OWNER, size = { 6 * 34, 32 },
    default = { point = POS[i][1], x = POS[i][2], y = POS[i][3] } })
end
