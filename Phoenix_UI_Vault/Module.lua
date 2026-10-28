local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault settings and module registration. Every look and behaviour is a
-- setting (Simple + Advanced) applied live; defaults per D-MOD-DEF2:
-- category view, junk auto-sell OFF.
local _, ns = ...
local VA, R, ST, BK = ns.VA, ns.Rules, ns.Store, ns.Bank
local Schema, Layout = PUI.Schema, PUI.Layout
local OWNER = "Vault"
local s = VA.settings

local function refresh() if VA.active and VA.open then VA.Rebuild() end end

local function onEnable(mod)
  VA.active = true
  VA.Hook()
  VA.Window()
  VA.EnsureButtons()
  VA.ctx = VA.Context()
  ST.RecordGold()
  ST.SnapshotBags()
  mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
    VA.EnsureButtons(); ST.SnapshotBags(); refresh()
    if BK.frame and BK.frame:IsShown() then BK.Render() end
  end)
  mod:RegisterEvent("INVENTORY_SEARCH_UPDATE", refresh)
  mod:RegisterEvent("ITEM_LOCK_CHANGED", function() if VA.open then VA.Refresh() end end)
  mod:RegisterEvent("PLAYER_MONEY", function() ST.RecordGold(); refresh() end)
  mod:RegisterEvent("CURRENCY_DISPLAY_UPDATE", refresh)
  mod:RegisterEvent("EQUIPMENT_SETS_CHANGED", refresh)
  mod:RegisterEvent("MERCHANT_SHOW", function()
    VA.atMerchant = true
    if s.autoSell then VA.SellJunk() end
    refresh()
  end)
  mod:RegisterEvent("MERCHANT_CLOSED", function() VA.atMerchant = false; refresh() end)
  mod:RegisterEvent("BANKFRAME_OPENED", BK.Opened)
  mod:RegisterEvent("BANKFRAME_CLOSED", BK.Closed)
  mod:RegisterEvent("GUILDBANKFRAME_OPENED", BK.GuildOpened)
  mod:RegisterEvent("GUILDBANKFRAME_CLOSED", BK.GuildClosed)
  mod:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED", function() if BK.frame and BK.frame:IsShown() then BK.Render() end end)
end

local function onDisable()
  VA.active = false
  VA.Close()
  BK.Disable()
  ns.Sort.Stop()
  VA.searchRule = nil
  if VA.frame and VA.frame.search then VA.frame.search:SetText("") end
end

Layout:RegisterElement("vault.window", { label = "Bags", owner = OWNER, size = { 470, 300 }, default = { point = "BOTTOMRIGHT", x = -60, y = 120 } })

local schema = {}
VA.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value)
    s[name] = value
    if VA.active then VA.ctx = VA.Context() end
    refresh()
    if BK.frame and BK.frame:IsShown() then BK.Render() end
  end
  schema["vault." .. name] = def
end

local function sectionDefault()
  local g = {}
  for _, c in ipairs(R.BUILTIN) do g[c.id] = { show = true, collapsed = false } end
  return g
end

-- Simple
key("view", { type = "select", default = "category", choices = { "category", "grid", "compact", "list" },
  choiceLabels = { category = "Categories", grid = "Grid", compact = "Compact grid", list = "List" }, label = "View",
  tooltip = "Categories group items by your rules; grid shows bags in order; compact uses smaller slots; list shows names.", mode = "simple" })
key("columns", { type = "range", default = 12, min = 6, max = 24, step = 1, label = "Columns", tooltip = "Slots per row.", mode = "simple" })
key("slotSize", { type = "range", default = 37, min = 28, max = 48, step = 1, label = "Slot size", tooltip = "Size of each slot.", mode = "simple" })
key("ilvl", { type = "toggle", default = true, label = "Item level on gear", tooltip = "Writes the item level on equippable items.", mode = "simple" })
key("qualityBorder", { type = "toggle", default = true, label = "Quality borders",
  tooltip = "Colours each slot's border by item quality, using the game's quality colours (your colour overrides apply).", mode = "simple" })
key("autoSell", { type = "toggle", default = false, label = "Sell junk automatically",
  tooltip = "Sells grey items and items you marked as junk when you open a vendor. Off at first install; the Sell junk button works either way.",
  mode = "simple", searchTags = { "junk", "sell", "vendor", "grey" } })
key("newGlow", { type = "toggle", default = true, label = "New item glow", tooltip = "Highlights items you just received.", mode = "simple" })
key("newCategory", { type = "toggle", default = true, label = "New items category", tooltip = "Puts items you just received in their own category at the top.", mode = "simple" })
key("rules", { type = "list", default = {}, maxItems = 40, itemValidate = R.Validate, label = "Category rules",
  tooltip = "Your own categories, one per line as Name|rule, checked before the built-in ones. Example: Sets: PvP|set ~ PvP and ilvl >= 640. Fields: type, subtype, ilvl, quality, name, id, bound, expansion, slot, count, set, keystone.",
  mode = "simple", searchTags = { "category", "rule", "filter" } })
key("sections", { type = "grid", default = sectionDefault(), rows = R.BUILTIN,
  columns = { { id = "show", label = "Show" }, { id = "collapsed", label = "Collapsed" } },
  label = "Categories", tooltip = "Show or collapse each built-in category (Pinned, New, Keystone shelf, Equipment sets, Junk and the rest).", mode = "simple" })
key("goldHistory", { type = "toggle", default = true, label = "Gold history",
  tooltip = "Records each character's gold once a day; hover the gold line to see every character and the last week.", mode = "simple" })
key("currencies", { type = "toggle", default = true, label = "Currencies in the footer", tooltip = "Shows the currencies you track on the backpack.", mode = "simple" })
key("alts", { type = "toggle", default = true, label = "Remember items for alts",
  tooltip = "Keeps a list of each character's bag and bank items so you can see them from any character (Bank > Alts).", mode = "simple" })
key("bankView", { type = "toggle", default = true, label = "Phoenix bank window",
  tooltip = "At the banker, shows the bank with Character, Warband, Reagents, Guild bank and Alts tabs beside your bags.", mode = "simple" })
-- Advanced
key("compactSize", { type = "range", default = 30, min = 22, max = 40, step = 1, label = "Compact slot size", tooltip = "Slot size in the compact view.", mode = "advanced" })
key("gap", { type = "range", default = 2, min = 0, max = 8, step = 1, label = "Slot spacing", tooltip = "Space between slots.", mode = "advanced" })
key("listColumns", { type = "range", default = 2, min = 1, max = 4, step = 1, label = "List columns", tooltip = "Columns in the list view.", mode = "advanced" })
key("hideEmpty", { type = "toggle", default = true, label = "Fold empty slots",
  tooltip = "In category and list views, shows one empty slot with the free count instead of every empty slot.", mode = "advanced" })
key("qualityMin", { type = "range", default = 2, min = 0, max = 8, step = 1, label = "Border from quality",
  tooltip = "Lowest quality that gets a coloured border (0 poor, 2 uncommon, 4 epic).", mode = "advanced" })
key("pins", { type = "list", default = {}, maxItems = 200, label = "Pinned items",
  tooltip = "Item IDs shown in the Pinned category and never sold as junk. Use Pin mode in the bags to add items by clicking.", mode = "advanced" })
key("junkList", { type = "list", default = {}, maxItems = 500, label = "Items marked as junk",
  tooltip = "Item IDs treated as junk. Use Junk mode in the bags to add items by clicking.", mode = "advanced" })
key("assign", { type = "list", default = {}, maxItems = 500, label = "Items moved to a category",
  tooltip = "One per line as itemID=Category (a built-in id such as consumables, or the name of one of your rules).", mode = "advanced" })
key("sortRightToLeft", { type = "toggle", default = false, label = "Sort right to left", tooltip = "Fills bags from the last slot when sorting.", mode = "advanced" })
key("goldStyle", { type = "select", default = "gold", choices = { "gold", "full", "icons" },
  choiceLabels = { gold = "12,345g", full = "12,345g 6s 7c", icons = "Coin icons" }, label = "Gold format", tooltip = "How gold is written in the footer.", mode = "advanced" })
key("bankColumns", { type = "range", default = 14, min = 6, max = 28, step = 1, label = "Bank columns", tooltip = "Slots per row in the bank window.", mode = "advanced" })

local ckey, cdef = PUI.Coexist:Define("vault", { module = OWNER, job = "Bags",
  addons = { "Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Combuctor", "LiteBag" } })
cdef.owner = OWNER
schema[ckey] = cdef

VA.module = PUI:RegisterModule(OWNER, {
  label = "Vault", tooltip = "Bags and bank in one window: categories with your own rules, junk, keystone shelf, undo sort, alts and gold history.",
  enabledByDefault = false, loadCondition = function() return PUI.Coexist:Allows("vault") end,
  schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if k:sub(1, 6) == "vault." then def.apply(Schema:Get(k)) end end
