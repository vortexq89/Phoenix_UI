local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.ItemList (plan 1.O "Extra item bar"): the one list of usable items
-- (potions, healthstones, quest items, toys, on-use trinkets) that feeds both
-- the clickable Action Bars item bar (owner) and the display-only Cooldown
-- Manager custom bar. The list is plain data in two Core settings:
--   items.list      { "5512", "211880", ... } item IDs, in order
--   items.trinkets  add equipped on-use trinkets (inventory slots 13 and 14)
--   items.hideMissing  skip items you do not carry
-- Items() returns { { kind = "item", id = n } | { kind = "slot", slot = 13, id = n } }.
-- Item counts and IDs are plain data (not secret); cooldowns go straight to
-- Cooldown widgets.
local ItemList = { cfg = { list = {}, trinkets = true, hideMissing = true }, listeners = {} }
PUI.ItemList = ItemList
local Schema = PUI.Schema

ItemList.TRINKET_SLOTS = { 13, 14 }

function ItemList.Parse(list)
  local out, seen = {}, {}
  for _, v in ipairs(list or {}) do
    local id = tonumber(v)
    if id and id > 0 and not seen[id] then seen[id] = true; out[#out + 1] = id end
  end
  return out
end

function ItemList:Items()
  local c, out = self.cfg, {}
  if c.trinkets then
    for _, slot in ipairs(self.TRINKET_SLOTS) do
      local id = GetInventoryItemID("player", slot)
      if id and C_Item.GetItemSpell(id) then out[#out + 1] = { kind = "slot", slot = slot, id = id } end
    end
  end
  for _, id in ipairs(self.Parse(c.list)) do
    if not c.hideMissing or C_Item.GetItemCount(id, false, true) > 0 then out[#out + 1] = { kind = "item", id = id } end
  end
  return out
end

-- Icon, count text and cooldown for one entry (cooldown values go to a widget).
function ItemList.Icon(e) return C_Item.GetItemIconByID(e.id) end
function ItemList.Count(e)
  if e.kind == "slot" then return "" end
  local n = C_Item.GetItemCount(e.id, false, true)
  return n > 1 and tostring(n) or ""
end
function ItemList.ApplyCooldown(cd, e)
  if e.kind == "slot" then
    local start, dur = GetInventoryItemCooldown("player", e.slot)
    cd:SetCooldown(start or 0, dur or 0)
  else
    local start, dur = C_Item.GetItemCooldown(e.id)
    cd:SetCooldown(start or 0, dur or 0)
  end
end

-- Listeners (Action Bars item bar, CDM custom bar) re-read on a list change.
function ItemList:OnChange(id, fn) self.listeners[id] = fn end
function ItemList:Changed() for _, fn in pairs(self.listeners) do fn() end end

local function key(name, def, set)
  def.owner = "Core"
  def.apply = function(v) set(v); ItemList:Changed() end
  Schema:Register(name, def)
end
key("items.list", { type = "list", default = { "5512" }, maxItems = 24, label = "Item bar items",
  tooltip = "Item IDs shown on the Action Bars item bar and the Cooldown Manager custom bar, in order (for example Healthstone 5512, healing potions, quest items, toys).",
  mode = "simple", itemValidate = function(v) return tonumber(v) ~= nil, "an item ID" end,
  searchTags = { "potion", "healthstone", "item bar", "trinket", "quest item" } }, function(v) ItemList.cfg.list = v end)
key("items.trinkets", { type = "toggle", default = true, label = "Add on-use trinkets",
  tooltip = "Adds your equipped trinkets that have a use effect to the item bars.", mode = "simple",
  searchTags = { "trinket" } }, function(v) ItemList.cfg.trinkets = v end)
key("items.hideMissing", { type = "toggle", default = true, label = "Hide items you do not carry",
  tooltip = "Items with a count of zero are left off the item bars.", mode = "advanced" }, function(v) ItemList.cfg.hideMissing = v end)
for _, k in ipairs({ "items.list", "items.trinkets", "items.hideMissing" }) do Schema:Def(k).apply(Schema:Get(k)) end
