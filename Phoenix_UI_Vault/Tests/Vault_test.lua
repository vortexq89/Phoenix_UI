local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Vault (bags, categories, junk, sort undo, bank, alts,
-- gold history over PUI.Wallet).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local VA, R, Sort = ns.VA, ns.Rules, ns.Sort

local function with(t, values)
  local keys = { "module.Vault" }
  for k in pairs(values or {}) do keys[#keys + 1] = k end
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    wipe(H.items); H.itemClass = nil; H.calls = {}; VA.atMerchant = false
  end)
  Schema:Set("module.Vault", true)
  for k, v in pairs(values or {}) do Schema:Set(k, v) end
end

local function stock()
  H.items["0:1"] = { iconFileID = 1, stackCount = 1, quality = 4, hyperlink = "x", itemID = 900 }
  H.items["0:2"] = { iconFileID = 2, stackCount = 1, quality = 4, itemID = 180653 }
  H.items["0:3"] = { iconFileID = 3, stackCount = 5, quality = 1, itemID = 2001 }
  H.items["1:2"] = { iconFileID = 4, stackCount = 5, quality = 0, itemID = 1 }
  H.itemClass = { [900] = { class = 4, loc = "INVTYPE_HEAD" }, [2001] = { class = 0 }, [1] = { class = 15 }, [180653] = { class = 13 } }
end

Tests:Add("Vault", "defaults: category view, auto-sell off; conflict entry; every setting live", function(t)
  t:eq(Schema:Def("module.Vault").default, false, "module defaults off")
  t:eq(Schema:Def("vault.view").default, "category", "category view first (D-MOD-DEF2)")
  t:eq(Schema:Def("vault.autoSell").default, false, "junk auto-sell off (D-MOD-DEF2)")
  t:ok(Schema:Def("core.coexist.vault") ~= nil, "Baganator/Bagnon/AdiBags conflict notice entry")
  for key, def in pairs(VA.schema) do t:eq(type(def.apply), "function", key .. " apply") end
end)

Tests:Add("Vault", "rules engine: expressions, errors, priority, grouping, search mode", function(t)
  local f = { id = 5, name = "Gladiator's Helm", quality = 4, ilvl = 645, classID = 4, sets = { "PvP" }, bound = true }
  local function m(src) local fn = assert(R.Compile(src)); return fn(f) end
  t:eq(m("type = Armor and ilvl >= 640"), true, "type + ilvl")
  t:eq(m("set ~ pvp"), true, "set contains")
  t:eq(m("set:PvP"), true, "field:value shorthand")
  t:eq(m("quality >= epic and not (ilvl < 600 or name ~ potion)"), true, "not / parentheses / names")
  t:eq(m("ilvl > 650 or quality = legendary"), false, "or")
  t:eq(m("helm"), true, "bare word searches the name")
  t:eq(select(2, R.Compile("ilvl >=")), "missing value after >=", "error: missing value")
  t:eq(select(2, R.Compile("colour = red")), "unknown field 'colour'", "error: unknown field")
  t:eq(R.Validate("PvP|set ~ PvP"), true, "list item validates")
  t:eq(R.Validate("no pipe here"), false, "list item needs Name|rule")
  local rule = R.ParseRule("PvP gear|set ~ PvP")
  t:eq(R.Classify(f, { rules = { rule } }), "rule:PvP gear", "user rule before built-ins")
  t:eq(R.Classify(f, { pins = { [5] = true }, rules = { rule } }), "pinned", "pin wins")
  t:eq(R.Classify(f, { assign = { [5] = "consumables" }, rules = { rule } }), "consumables", "manual assignment beats rules")
  t:eq(R.Builtin({ quality = 0 }), "junk", "grey is junk")
  t:eq(R.Builtin({ quality = 3, keystone = true }), "keystone", "keystone shelf")
  local groups = R.Group({ { facts = { quality = 0 } }, { facts = { quality = 1, classID = 0 } }, { facts = { quality = 3, keystone = true } } }, { hidden = { junk = true } })
  t:same({ groups[1].id, groups[2].id, groups[3] }, { "keystone", "consumables", nil }, "ordered, hidden category dropped")
  t:same({ R.SearchMode("potion"), R.SearchMode("ilvl>650"), R.SearchMode("set:PvP"), R.SearchMode("") }, { "plain", "rule", "rule", "none" }, "search modes")
end)

Tests:Add("Vault", "category view: sections, keystone shelf, junk, empty fold; other views", function(t)
  if not H then return end
  stock()
  with(t, { ["vault.view"] = "category", ["vault.hideEmpty"] = true, ["vault.columns"] = 12 })
  VA.Open()
  local ids = {}
  for _, sec in ipairs(VA.sections) do ids[#ids + 1] = sec.id end
  t:same(ids, { "keystone", "equipment", "consumables", "junk" }, "sections in order")
  t:eq(VA.buttons[0][1].template, "ContainerFrameItemButtonTemplate", "Blizzard's secure slot template")
  t:same({ VA.count, VA.free }, { 4, 2 }, "used and free slots")
  t:eq(VA.ilvlText[VA.buttons[0][1]]:GetText(), "645", "item level on gear")
  t:eq(VA.buttons[0][4]:IsShown(), true, "one empty slot shown")
  t:eq(VA.buttons[1][1]:IsShown(), false, "other empty slots folded")
  Schema:Set("vault.view", "grid")
  Schema:Set("vault.columns", 6)
  t:eq(VA.frame:GetWidth(), 20 + 6 * 39 - 2, "grid view and columns apply live")
  Schema:Set("vault.view", "list")
  t:eq(VA.nameText[VA.buttons[0][3]]:GetText(), "5x Item 2001", "list view writes names and counts")
  local saved = rawget(_G, "ColorManager")
  rawset(_G, "ColorManager", { GetColorDataForItemQuality = function() return { color = { GetRGB = function() return 0.1, 0.2, 0.3 end } } end })
  t:same({ VA.QualityColor(4) }, { 0.1, 0.2, 0.3 }, "quality colours from ColorManager")
  rawset(_G, "ColorManager", saved)
  Schema:Set("module.Vault", false)
  t:eq(VA.frame:IsShown(), false, "closed when turned off")
end)

Tests:Add("Vault", "junk: auto-sell off by default, marked junk, pins protect, Flow defers", function(t)
  if not H then return end
  stock()
  with(t, { ["vault.autoSell"] = false, ["vault.junkList"] = {}, ["vault.pins"] = {} })
  local function called(name) for _, c in ipairs(H.calls) do if c[1] == name then return true end end return false end
  H.calls = {}
  VA.Open()
  H.fire("MERCHANT_SHOW")
  t:eq(called("SellAllJunkItems"), false, "nothing sold with auto-sell off")
  t:eq(VA.JunkCount(), 1, "grey counted")
  VA.SetMode("junk")
  t:ok(VA.buttons[0][3].puiOverlay:IsShown(), "mode overlay over items (secure button never clicked)")
  VA.ModeClick(VA.buttons[0][3])
  VA.SetMode("use")
  t:same(Schema:Get("vault.junkList"), { "2001" }, "junk mode marks the item")
  t:eq(VA.JunkCount(), 2, "marked item counts as junk")
  Schema:Set("vault.pins", { "2001" })
  t:eq(VA.JunkCount(), 1, "pinned items are never junk")
  Schema:Set("vault.pins", {})
  H.calls = {}
  Schema:Set("vault.autoSell", true)
  H.fire("MERCHANT_CLOSED"); H.fire("MERCHANT_SHOW")
  t:ok(called("SellAllJunkItems") and called("UseContainerItem"), "greys through sell-all, marked items one by one")
  t:eq(VA.OwnsJunk(), true, "Flow's sell junk stands down while Vault is on")
end)

Tests:Add("Vault", "sort undo: snapshot, plan, ticker steps, merged stacks reported", function(t)
  if not H then return end
  local slots = { "0:1", "0:2", "0:3" }
  local moves, missing = Sort.Plan(slots, { ["0:1"] = "b", ["0:2"] = "a" }, { ["0:1"] = "a", ["0:2"] = "b", ["0:3"] = "c" })
  t:same(moves, { { from = "0:2", to = "0:1" } }, "one swap restores a and b")
  t:eq(missing, 1, "item that no longer exists reported")
  stock()
  with(t)
  VA.Open()
  t:eq(Sort.CanUndo(), false, "nothing to undo before a sort")
  VA.Sort()
  t:ok(Sort.CanUndo(), "snapshot taken before sorting")
  local a, b = H.items["0:1"], H.items["0:3"]
  H.items["0:1"], H.items["0:3"] = b, a
  H.picks = {}
  local n = VA.UndoSort()
  t:eq(n, 1, "one move planned")
  t:ok(PUI.Ticker:IsRegistered("vault.undo"), "moves run on a Ticker entry")
  Sort.Step()
  t:same(H.picks, { "0:3", "0:1" }, "picked up and dropped back")
  t:ok(not PUI.Ticker:IsRegistered("vault.undo"), "ticker removed when done")
end)

Tests:Add("Vault", "alts, gold history over PUI.Wallet, footer", function(t)
  if not H then return end
  stock()
  with(t, { ["vault.alts"] = true, ["vault.goldHistory"] = true })
  local W, ST = PUI.Wallet, ns.Store
  local before = PUI.DB.sv.wallet and Schema.Copy(PUI.DB.sv.wallet)
  local vbefore = PUI.DB.sv.vault and Schema.Copy(PUI.DB.sv.vault)
  t:cleanup(function() PUI.DB.sv.wallet = before; PUI.DB.sv.vault = vbefore end)
  PUI.DB.sv.wallet = nil
  W:Record("Alt-Realm", 50000, "MAGE", os.time() - 86400)
  W:Record(nil, 1234567, "MAGE")
  t:eq(#W:Characters(), 2, "two characters known")
  t:eq(W:Total(), 1284567, "total gold")
  t:eq(#W:History(), 1, "one day recorded for this character")
  local days = { [20260101] = 1, [20260102] = 2, [20260103] = 3 }
  t:eq(W.Trim(days, 2), 1, "history trimmed to the newest days")
  ST.SnapshotBags()
  PUI.DB.sv.vault.chars["Alt-Realm"] = { class = "MAGE", updated = 1, bags = { [2001] = 7 }, bank = { [2001] = 3 } }
  local total, rows = ST.Where(2001)
  t:eq(total, 15, "item counted across characters")
  t:eq(rows[1].key, "Alt-Realm", "biggest holder first")
  t:ok(ST.FooterText():find("Gold 123g", 1, true) ~= nil, "footer gold")
end)

Tests:Add("Vault", "bank: Phoenix bank at the banker, tabs, Blizzard bank restored", function(t)
  if not H then return end
  with(t, { ["vault.bankView"] = true })
  local BK = ns.Bank
  BankFrame:Show(); BankFrame:SetAlpha(1)
  H.fire("BANKFRAME_OPENED")
  t:ok(BK.frame and BK.frame:IsShown(), "bank window shown")
  t:eq(BankFrame:GetAlpha(), 0, "Blizzard bank faded (kept open for the bank session)")
  for _, tab in ipairs(BK.TABS) do BK.Select(tab); t:eq(BK.tab, tab, tab .. " tab renders") end
  BK.Select("character")
  H.calls = {}
  t:eq(BK.Deposit(), true, "deposit reagents at the banker")
  H.fire("BANKFRAME_CLOSED")
  t:eq(BankFrame:GetAlpha(), 1, "Blizzard bank restored")
  t:eq(BK.Deposit(), false, "no deposit away from the banker")
end)

Tests:Add("Vault", "bag keys toggle the Vault and hide Blizzard bags; rule search", function(t)
  if not H then return end
  stock()
  with(t)
  ContainerFrameCombinedBags:Show()
  ToggleAllBags()
  H.step()
  t:eq(VA.open, true, "opened")
  t:eq(ContainerFrameCombinedBags:IsShown(), false, "Blizzard bags hidden")
  VA.SetSearch("ilvl>=640")
  t:ok(VA.searchRule ~= nil, "operator search uses the rules engine")
  VA.SetSearch("")
  ToggleBackpack(); CloseAllBags()
  H.step()
  t:eq(VA.open, false, "toggle closes even when Blizzard calls CloseAllBags inside")
end)

Tests:Add("Vault", "live preview groups sample items with the real rules engine", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = { Schema:Get("vault.view"), Schema:Get("vault.rules") }
  t:cleanup(function() Schema:Set("vault.view", saved[1]); Schema:Set("vault.rules", saved[2]) end)
  Schema:Set("vault.view", "category")
  Schema:Set("vault.rules", { "PvP|set ~ PvP" })
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Vault(card)
  local h = P.State(card).hud.vault
  t:eq(h.heads[1]:GetText(), "PVP  1", "user rule category first")
  t:ok(h.tiles[8] and h.tiles[8]:IsShown(), "every sample item drawn")
end)
