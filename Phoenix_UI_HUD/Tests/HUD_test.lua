local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Minimap (+ button bin), Tooltip (+ IDs), Data Bars and
-- the shared Queue and Wallet providers.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ, Ticker = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Ticker
local MM, TT, DB, IDs, Bin = ns.MM, ns.TT, ns.DataBars, ns.IDs, ns.Bin

local function enable(t, module, ...)
  local keys = { "module." .. module, ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module." .. module, true)
  CQ.Drain()
end

local function strip(text) return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function lines(tip)
  local out = {}
  for i, l in ipairs(rawget(tip, "lines") or {}) do out[i] = type(l) == "table" and (tostring(l[1]) .. " = " .. tostring(l[2])) or strip(l) end
  return out
end
local function newTip() return CreateFrame("GameTooltip") end

Tests:Add("HUD", "modules off by default and silent; every key applies live; 28 ID kinds in 4 groups", function(t)
  for _, m in ipairs({ "Minimap", "Tooltip", "DataBars" }) do t:eq(Schema:Def("module." .. m).default, false, m .. " defaults off") end
  if not Schema:Get("module.Minimap") then t:eq(Ticker:IsRegistered("mm.texts"), false, "no minimap ticker") end
  if not Schema:Get("module.DataBars") then
    t:eq(Ticker:IsRegistered("db.update"), false, "no data bar ticker")
    t:eq(next(DB.bars), nil, "no data bar frames while off")
  end
  for _, sc in ipairs({ MM.schema, TT.schema, DB.schema, IDs.schema, Bin.schema }) do
    for key, def in pairs(sc) do t:eq(type(def.apply), "function", key .. " apply") end
  end
  t:eq(#IDs.KINDS, 28, "28 ID kinds")
  local groups = {}
  for _, k in ipairs(IDs.KINDS) do groups[k[3]] = (groups[k[3]] or 0) + 1; t:ok(Schema:Def("tt.ids." .. k[1]), k[1] .. " has a setting") end
  t:same({ groups.items, groups.spells, groups.world, groups.collections }, { 7, 9, 8, 4 }, "four groups")
  t:eq(Schema:Def("tt.ids.bonus").default, false, "bonus IDs off by default")
  t:eq(Schema:Def("tt.ids.traitNode").default, false, "trait IDs off by default")
  t:eq(Schema:Def("tt.ids.gate").default, "off", "IDs always visible by default (D-MOD-DEF)")
  t:eq(Schema:Def("tt.ids").default, true, "IDs on when the tooltip module is on")
  t:eq(Schema:Def("mm.coords.owner").default, "ask", "coordinates: nothing changes until the user picks")
end)

Tests:Add("HUD", "minimap shape, size, border, parts and texts apply live; old layout restored", function(t)
  if not H then return end
  local w = Minimap:GetWidth()
  enable(t, "Minimap", "mm.shape", "mm.size", "mm.coords", "mm.borderSize", "mm.hide.zoom", "mm.text.clock24", "mm.captured")
  t:eq(Schema:Get("mm.captured").size[1], w, "first enable captured the old size")
  t:eq(Minimap.mask, MM.MASKS.square, "square mask")
  t:eq(Minimap:GetWidth(), 200, "size applied")
  t:eq(MinimapCluster.BorderTop:GetAlpha(), 0, "cluster border alpha-zeroed")
  t:ok(MM.border:IsShown(), "border host shown for the square map")
  Schema:Set("mm.borderSize", 0)
  t:eq(MM.border:IsShown(), false, "border 0 hides it live")
  t:ok(Ticker:IsRegistered("mm.texts"), "text ticker while texts shown")
  Schema:Set("mm.shape", "circle")
  t:eq(Minimap.mask, MM.MASKS.circle, "circle live")
  Schema:Set("mm.coords", true)
  t:eq(MM.texts.coords:GetText(), "50.0, 25.0", "coordinates text")
  Schema:Set("mm.text.clock24", false)
  t:ok(MM.texts.clock:GetText():find("[AP]M") ~= nil, "12-hour clock live")
  Schema:Set("mm.size", 260)
  CQ.Drain()
  t:eq(Minimap:GetWidth(), 260, "size live")
  Schema:Set("module.Minimap", false)
  CQ.Drain()
  t:eq(Minimap:GetWidth(), w, "old size restored")
  t:eq(MinimapCluster.BorderTop:GetAlpha(), 1, "cluster restored")
  t:eq(Ticker:IsRegistered("mm.texts"), false, "ticker gone")
end)

Tests:Add("HUD", "coordinates conflict: nothing changes until picked; Phoenix side turns Blizzard's off and back", function(t)
  if not H then return end
  local oldCVar = H.cvars.minimapShowPlayerCoords
  H.cvars.minimapShowPlayerCoords = "1"
  local asked
  local confirm = PUI.Dialogs.Confirm
  PUI.Dialogs.Confirm = function(_, spec) asked = spec end
  MM.coordsAsked = false
  t:cleanup(function() PUI.Dialogs.Confirm = confirm; H.cvars.minimapShowPlayerCoords = oldCVar; MM.coordsAsked = false end)
  enable(t, "Minimap", "mm.coords", "mm.coords.owner")
  Schema:Set("mm.coords", true)
  t:ok(asked and asked.title:find("coordinates"), "notice shown")
  t:eq(MM.CoordsAllowed(), false, "ask: Phoenix stays hidden while Blizzard's are on")
  t:eq(H.cvars.minimapShowPlayerCoords, "1", "Blizzard's coordinates untouched")
  asked.onAccept()
  t:eq(Schema:Get("mm.coords.owner"), "phoenix", "pick stored as a setting")
  t:eq(H.cvars.minimapShowPlayerCoords, "0", "Blizzard's turned off through the CVar ledger")
  t:ok(MM.CoordsAllowed(), "Phoenix coordinates shown")
  Schema:Set("mm.coords.owner", "blizzard")
  t:eq(H.cvars.minimapShowPlayerCoords, "1", "prior value restored when changed back")
  t:eq(MM.CoordsAllowed(), false, "Phoenix hides its own")
  t:eq(DB.BlockText({ name = "coords" }), "", "Data Bars coordinates block follows the owner")
end)

Tests:Add("HUD", "difficulty text, indicators, friends tooltip and micro menu", function(t)
  t:eq(MM.DifficultyText(8, 5, 16), "M+16", "keystone level")
  t:eq(MM.DifficultyText(16, 20, 0, true), "20M", "raid size on request")
  t:eq(MM.DifficultyText(7, 25, 0, true), "LFR", "LFR keeps its tag")
  t:eq(MM.DifficultyText(0), "", "open world is empty")
  if not H then return end
  local list, total = MM.FriendLines(1, true)
  t:eq(total, 2, "WoW and Battle.net friends online")
  t:eq(#list, 1, "tooltip capped")
  t:eq(list[1].note, "arena partner", "note kept for the second line")
  H.vaultReady, H.invites = true, 2
  t:cleanup(function() H.vaultReady, H.invites = nil, nil end)
  t:eq(MM.IndicatorText(), "Great Vault ready  -  2 calendar invites", "indicators")
  local opened
  rawset(_G, "ToggleCharacter", function(tab) opened = tab end)
  t:cleanup(function() rawset(_G, "ToggleCharacter", nil) end)
  t:ok(MM.RunMicro(1), "micro menu entry runs Blizzard's toggle")
  t:eq(opened, "PaperDollFrame", "character sheet")
  t:eq(MM.RunMicro(4), false, "missing Blizzard function is skipped, not an error")
  enable(t, "Minimap", "mm.middleClick")
  MM.OnMouseUp(Minimap, "MiddleButton")
  t:ok(MM.menu and MM.menu:IsShown(), "middle click opens the micro menu")
  MM.OnMouseUp(Minimap, "MiddleButton")
  Schema:Set("mm.middleClick", "none")
  MM.OnMouseUp(Minimap, "MiddleButton")
  t:eq(MM.menu:IsShown(), false, "middle click does nothing when set to nothing")
end)

Tests:Add("HUD", "queue provider: dungeon and battleground pops drive one countdown the minimap reads", function(t)
  if not H then return end
  enable(t, "Minimap", "mm.queue.eye")
  PUI.Queue:OnEvent("LFG_PROPOSAL_SHOW")
  t:eq(PUI.Queue:Pop().kind, "lfg", "dungeon pop")
  t:eq(math.floor(PUI.Queue:Remaining() + 0.5), 40, "40 s by default")
  t:ok(Ticker:IsRegistered("mm.queue"), "countdown ticker only while a pop is up")
  t:eq(MM.texts.queue:GetText(), "40", "minimap queue eye text")
  PUI.Queue:OnEvent("LFG_PROPOSAL_DONE")
  t:eq(PUI.Queue:Pop(), nil, "pop cleared")
  MM.QueueTick()
  t:eq(Ticker:IsRegistered("mm.queue"), false, "ticker gone")
  H.bf = { { status = "confirm", expires = 85 } }
  t:cleanup(function() H.bf = {}; PUI.Queue:OnEvent("UPDATE_BATTLEFIELD_STATUS") end)
  PUI.Queue:OnEvent("UPDATE_BATTLEFIELD_STATUS")
  t:eq(PUI.Queue:Pop().kind, "pvp", "battleground pop")
  t:eq(math.floor(PUI.Queue:Remaining() + 0.5), 85, "game's own expiry")
  t:ok(PUI.Queue:Status().pvp, "queued status")
  Schema:Set("mm.queue.eye", false)
  t:eq(MM.texts.queue:IsShown(), false, "queue eye off live")
end)

Tests:Add("HUD", "button bin collects addon buttons, searches, skips lists and gives them back", function(t)
  if not H then return end
  local a = CreateFrame("Button", "LibDBIcon10_Alpha", Minimap)
  local b = CreateFrame("Button", "LibDBIcon10_Beta", Minimap)
  local blizz = CreateFrame("Button", "GameTimeFrame", Minimap)
  for _, f in ipairs({ a, b, blizz }) do
    rawset(f, "GetName", function(self) return self == a and "LibDBIcon10_Alpha" or self == b and "LibDBIcon10_Beta" or "GameTimeFrame" end)
    rawset(f, "GetParent", function() return Minimap end)
    rawset(f, "GetObjectType", function() return "Button" end)
  end
  rawset(Minimap, "GetChildren", function() return a, b, blizz end)
  local parents = {}
  for _, f in ipairs({ a, b }) do rawset(f, "SetParent", function(self, p) parents[self] = p end) end
  t:cleanup(function() rawset(Minimap, "GetChildren", nil); rawset(_G, "GameTimeFrame", nil) end)
  enable(t, "Minimap", "mm.bin.enabled", "mm.bin.blacklist")
  CQ.Drain()
  t:eq(#Bin.buttons, 2, "two addon buttons collected, Blizzard's left alone")
  t:eq(parents[a], Bin.flyout, "button moved into the bin")
  Bin.filter = "bet"
  t:eq(#Bin.Visible(), 1, "search narrows the grid")
  Bin.filter = ""
  local cells, w = Bin.Grid(7, 6, 28, 4)
  t:same({ cells[7].x, cells[7].y }, { 8, -62 }, "grid wraps after the column count")
  t:eq(w, 16 + 6 * 32 - 4, "bin width from the solver")
  Schema:Set("mm.bin.blacklist", { "Beta" })
  CQ.Drain()
  t:eq(#Bin.buttons, 1, "never-collect list releases a button live")
  t:eq(parents[b], Minimap, "given back to its own parent")
  Schema:Set("module.Minimap", false)
  CQ.Drain()
  t:eq(#Bin.buttons, 0, "module off gives every button back")
end)

Tests:Add("HUD", "wallet: gold styles, session change and currencies", function(t)
  local W = PUI.Wallet
  t:eq(W:Money(1234567, "full"), "123g 45s 67c", "gold silver copper")
  t:eq(W:Money(123456789, "gold"), "12,345g", "gold only, grouped")
  t:eq(W:Money(-50000, "gold"), "-5g", "negative")
  if not H then return end
  t:eq(W:Currency(3008).name, "Valorstones", "currency info")
  t:eq(W:Currency(1), nil, "unknown currency")
  t:eq(#W:Watched(), 1, "backpack currencies")
end)

Tests:Add("HUD", "data bars: blocks, currency tokens, solver, style and the progress bar", function(t)
  local parsed = DB.Parse("clock, fps,nope,gold, currency:3008")
  t:same({ parsed[1].name, parsed[2].name, parsed[3].name, parsed[4].name, parsed[4].arg }, { "clock", "fps", "gold", "currency", "3008" }, "unknown blocks dropped, currency token parsed")
  local slots = DB.Solve(300, 3)
  t:same({ slots[2].x, slots[2].w }, { 100, 100 }, "equal-width solver")
  if not H then return end
  enable(t, "DataBars", "db.bar1.blocks", "db.bar2.blocks", "db.style.gold", "db.progress.enabled", "db.progress.mode", "db.bar1.fill")
  Schema:Set("db.bar1.blocks", "gold,durability,xp,bags,currency:3008,currencies,honor,guild")
  local b = DB.bars[1]
  t:eq(b.cells[1]:GetText(), "123g", "gold from the wallet")
  t:eq(b.cells[2]:GetText(), "Dur 30%", "lowest durability")
  t:eq(b.cells[3]:GetText(), "XP 25%", "xp")
  t:eq(b.cells[5]:GetText(), "Valorstones 2,410/3,000", "one currency with its cap")
  t:eq(b.cells[6]:GetText(), "2,410 Valorstones", "tracked currencies")
  t:eq(b.cells[7]:GetText(), "Honor 52 (30%)", "honor")
  t:eq(b.cells[8]:GetText(), "Guild 23", "guild online")
  Schema:Set("db.style.gold", "full")
  t:eq(b.cells[1]:GetText(), "123g 45s 67c", "gold style live")
  Schema:Set("db.bar1.fill", true)
  t:eq(b:GetWidth(), UIParent:GetWidth(), "full screen width live")
  t:ok(Ticker:IsRegistered("db.update"), "ticker while shown")
  Schema:Set("db.bar2.blocks", "clock")
  t:ok(DB.bars[2]:IsShown(), "second bar appears live")
  Schema:Set("db.progress.enabled", true)
  t:ok(DB.pbar:IsShown(), "progress bar on")
  t:eq(DB.ProgressKind(), "xp", "auto shows experience below max level")
  t:eq(DB.pbar.text:GetText(), "25%", "percent text")
  t:eq(DB.pbar:GetValue(), 50, "bar fed the raw value")
  Schema:Set("db.progress.mode", "honor")
  t:eq(DB.pbar.text:GetText(), "30%", "honor mode live")
  Schema:Set("module.DataBars", false)
  t:eq(Ticker:IsRegistered("db.update"), false, "ticker gone when off")
  t:eq(DB.bars[1]:IsShown(), false, "bars hidden when off")
  t:eq(DB.pbar:IsShown(), false, "progress bar hidden when off")
end)

Tests:Add("HUD", "tooltip anchor, scale, style and info lines; secrets skipped", function(t)
  if not H then return end
  enable(t, "Tooltip", "tt.anchor", "tt.combat", "tt.lines.bestRun")
  Schema:Set("tt.anchor", "cursor")
  local tip = newTip()
  GameTooltip_SetDefaultAnchor(tip, UIParent)
  t:eq(tip.anchor, "ANCHOR_CURSOR", "cursor anchor")
  Schema:Set("tt.anchor", "cursorRight")
  GameTooltip_SetDefaultAnchor(tip, UIParent)
  t:eq(tip.anchor, "ANCHOR_CURSOR_RIGHT", "right of the cursor")
  local u = TT.UnitLines(TT.SAMPLE_UNIT)
  t:eq(strip(u[1][1]), "<Phoenix Rising> Officer", "guild line")
  t:eq(strip(u[2][1]), "Target: you", "target line")
  t:eq(strip(u[3][1]), "Mythic+ score: 3,412  best +16 Ara-Kara", "score with best run")
  Schema:Set("tt.lines.bestRun", false)
  t:eq(strip(TT.UnitLines(TT.SAMPLE_UNIT)[3][1]), "Mythic+ score: 3,412", "best run off live")
  H.tooltipCalls[Enum.TooltipDataType.Unit](tip)
  local l = lines(tip)
  t:eq(l[1], "<Phoenix> Officer", "real guild line")
  t:eq(l[#l], "Mythic+ score: 2,500", "real M+ line")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  local tip2 = newTip()
  H.tooltipCalls[Enum.TooltipDataType.Unit](tip2)
  H.tooltipCalls[Enum.TooltipDataType.Spell](tip2, { id = H.secret(5) })
  t:eq(rawget(tip2, "lines"), nil, "no line built from a secret")
  H.secretMode = false
  H.auraSource = "party1"
  t:cleanup(function() H.auraSource = nil end)
  local tip3 = newTip()
  TT.OnAura(tip3, "player", 7)
  t:eq(lines(tip3)[1], "Cast by " .. UnitName("party1"), "aura caster line")
  Schema:Set("tt.combat", "hide")
  H.inCombat = true
  t:cleanup(function() H.inCombat = false end)
  local tip4 = newTip()
  tip4:Show()
  TT.OnShow(tip4)
  t:eq(tip4:IsShown(), false, "hidden in combat")
end)

Tests:Add("HUD", "tooltip IDs: kinds, derived IDs, merge, gate, pet battles, hyperlinks and copy", function(t)
  if not H then return end
  enable(t, "Tooltip", "tt.ids.bonus", "tt.ids.gate", "tt.ids.traitNode", "tt.ids.labels", "tt.ids.copyKey")
  local tip = newTip()
  H.tooltipCalls[Enum.TooltipDataType.Spell](tip, { id = 133 })
  local l = lines(tip)
  t:eq(l[1], "Spell ID: 133", "spell ID line")
  t:eq(l[2], "Icon ID: 100133", "derived icon ID")
  IDs.Add(tip, "spell", 133)
  t:eq(#lines(tip), 2, "an ID already shown is not added twice")
  IDs.Add(tip, "spell", 134)
  t:eq(lines(tip)[3], "Spell IDs: 133, 134", "repeats merged into one plural line")
  local it = newTip()
  IDs.FromItem(it, 19019, "|cffa335ee|Hitem:19019:7463:0:0:0:0:0:0:80:0:0:0:2:10356:12176|h[x]|h|r")
  local il = table.concat(lines(it), "|")
  t:ok(il:find("Item ID: 19019", 1, true), "item")
  t:ok(il:find("Enchant ID: 7463", 1, true), "enchant from the link")
  t:ok(not il:find("Bonus", 1, true), "bonus IDs off by default")
  t:ok(il:find("Transmog visual ID: 7463", 1, true) and il:find("Transmog source ID: 98765", 1, true), "transmog")
  t:ok(il:find("Expansion ID: 10", 1, true), "expansion")
  Schema:Set("tt.ids.bonus", true)
  local it2 = newTip()
  IDs.FromItem(it2, 19019, "item:19019:0:0:0:0:0:0:0:80:0:0:0:2:10356:12176")
  t:ok(table.concat(lines(it2), "|"):find("Bonus IDs: 10356, 12176", 1, true), "bonus IDs bounded by their count")
  local np = newTip()
  IDs.FromGUID(np, "Creature-0-1465-0-2105-221986-0000ABCDEF")
  t:eq(lines(np)[1], "NPC ID: 221986", "NPC from the GUID")
  IDs.FromGUID(np, H.secret("Creature-0-1-0-1-5-0"))
  t:eq(#lines(np), 1, "secret GUID skipped")
  local hl = newTip()
  IDs.OnHyperlink(hl, "|cffffff00|Hachievement:41533:Player-1:0:0:0:0|h[Keystone Hero]|h|r")
  t:eq(lines(hl)[1], "Achievement ID: 41533", "achievement from a chat link")
  local tal = newTip()
  local saved = rawget(GameTooltip, "lines")
  rawset(GameTooltip, "lines", nil)
  t:cleanup(function() rawset(GameTooltip, "lines", saved); IDs.Clear(GameTooltip) end)
  IDs.OnTalent({ GetNodeID = function() return 90313 end, GetEntryID = function() return 112137 end, GetSpellID = function() return 12294 end })
  t:eq(table.concat(lines(GameTooltip), "|"):find("Trait", 1, true), nil, "trait IDs off by default")
  Schema:Set("tt.ids.traitNode", true)
  IDs.Clear(GameTooltip)
  IDs.OnTalent({ GetNodeID = function() return 90313 end })
  t:ok(table.concat(lines(GameTooltip), "|"):find("Trait node ID: 90313", 1, true), "trait node when turned on")
  Schema:Set("tt.ids.labels", "short")
  t:eq(strip(IDs.Line("spell", { 1 })), "Spell: 1", "short labels live")
  Schema:Set("tt.ids.labels", "full")
  Schema:Set("tt.ids.gate", "shift")
  local gated = newTip()
  IDs.Add(gated, "spell", 1)
  t:eq(rawget(gated, "lines"), nil, "modifier gate holds IDs back")
  Schema:Set("tt.ids.gate", "off")
  IDs.petBattle = true
  IDs.Add(gated, "spell", 1)
  IDs.petBattle = false
  t:eq(rawget(gated, "lines"), nil, "nothing in pet battles")
  local copied
  local copy = PUI.Dialogs.Copy
  PUI.Dialogs.Copy = function(_, title, text) copied = text end
  t:cleanup(function() PUI.Dialogs.Copy = copy end)
  IDs.Remember(tip)
  t:ok(IDs.CopyLast(), "copy opens the shared copy box")
  t:eq(copied, "Spell: 133, 134\nIcon: 100133", "plain IDs copied")
  CQ.Drain()
  t:ok(H.overrideBindings["CTRL-C"], "copy key taken while IDs are on screen")
  IDs.Clear(tip)
  CQ.Drain()
  t:eq(H.overrideBindings["CTRL-C"], nil, "and given back after")
  H.blizzBindings = { ["CTRL-C"] = "TOGGLECHARACTER0" }
  t:cleanup(function() H.blizzBindings = nil end)
  IDs.Remember(tip)
  CQ.Drain()
  t:eq(H.overrideBindings["CTRL-C"], nil, "never over a key the player bound")
end)

Tests:Add("HUD", "previews draw with the modules' own paint code", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Minimap(card)
  P.Tooltip(card)
  P.DataBars(card)
  local st = P.State(card)
  t:ok(st.hud.mm and st.hud.tt and st.hud.db, "three HUD previews built")
  t:eq(st.hud.mm.texts.difficulty:GetText(), "M+16", "difficulty sample")
  t:eq(strip(st.hud.tt.rows[2][1]), "<Phoenix Rising> Officer", "tooltip sample uses the real line builder")
  t:eq(st.hud.db.bars[1].cells[1]:GetText(), "21:42", "data bar sample")
end)

-- t97u: the upgraded bin ------------------------------------------------------
local function fakeButtons(t, list)
  local made = {}
  for _, spec in ipairs(list) do
    local f = CreateFrame(spec.kind or "Button", spec.name, spec.parent or Minimap)
    rawset(f, "GetName", function() return spec.name end)
    rawset(f, "GetObjectType", function() return spec.kind or "Button" end)
    rawset(f, "GetParent", function(self) return rawget(self, "parent") or spec.parent or Minimap end)
    if spec.width then f:SetSize(spec.width, spec.width) end
    made[#made + 1] = f
  end
  rawset(Minimap, "GetChildren", function() return unpack(made) end)
  t:cleanup(function() rawset(Minimap, "GetChildren", nil) end)
  return made
end
local function binOn(t, ...)
  enable(t, "Minimap", "mm.bin.enabled", "mm.bin.layout", "mm.bin.sort", "mm.bin.order", "mm.bin.hidden", "mm.bin.keep", "mm.bin.blacklist",
    "mm.bin.compartment", "mm.bin.grow", "mm.bin.dock", "mm.bin.shape", "mm.bin.skin", "mm.bin.strip", "mm.bin.fade", "mm.bin.autoClose",
    "mm.bin.closeDelay", "mm.bin.badge", "mm.bin.binSkin", "mm.bin.hideInCombat", "mm.bin.columns", ...)
  t:cleanup(function() Bin.SetEditing(false, true); Bin.filter = ""; if Bin.flyout then Bin.flyout:Hide() end; if Bin.bar then Bin.bar:Hide() end end)
end

Tests:Add("HUD", "bin: non-LibDBIcon buttons and late ones are collected; Blizzard, protected and big frames are not", function(t)
  if not H then return end
  local made = fakeButtons(t, { { name = "LibDBIcon10_Alpha" }, { name = "RareScannerMinimapButton" }, { name = "WIM3MinimapButton" },
    { name = "MyAddon_Toggle" }, { name = "GameTimeFrame" }, { name = "MinimapZoomIn" }, { name = "BigPanel", width = 200 },
    { name = "SomeTexture", kind = "Frame" } })
  local secure = CreateFrame("Button", "SecureThing", Minimap)
  rawset(secure, "secure", true)
  t:eq(Bin.IsAddonButton(secure), false, "protected frames are never taken")
  binOn(t)
  CQ.Drain()
  local names = {}
  for _, b in ipairs(Bin.buttons) do names[#names + 1] = Bin.Label(b) end
  table.sort(names)
  t:same(names, { "Alpha", "MyAddon_Toggle", "RareScanner", "WIM3" }, "LibDBIcon and plain addon buttons; Blizzard, big and non-clickable frames left")
  t:ok(Ticker:IsRegistered("mm.bin.scan"), "short scan job after login")
  -- a button created later is picked up by the scan job and by ADDON_LOADED
  local late = CreateFrame("Button", "LateAddonMinimapButton", Minimap)
  rawset(late, "GetName", function() return "LateAddonMinimapButton" end)
  rawset(late, "GetObjectType", function() return "Button" end)
  made[#made + 1] = late
  Bin.ScanTick(GetTime())
  CQ.Drain()
  t:ok(Bin.original[late] ~= nil, "late button collected by the scan job")
  Bin.ScanTick(GetTime() + Bin.SCAN_FOR + 1)
  t:eq(Ticker:IsRegistered("mm.bin.scan"), false, "scan job removes itself")
  t:ok(Bin.events:IsEventRegistered("ADDON_LOADED"), "rescans on ADDON_LOADED")
  Schema:Set("mm.bin.enabled", false)
  CQ.Drain()
  t:eq(#Bin.buttons, 0, "off: every button given back")
  t:eq(late:GetParent(), Minimap, "original parent restored")
  t:eq(Bin.events:IsEventRegistered("ADDON_LOADED"), false, "no events while off")
end)

Tests:Add("HUD", "bin: compartment entries, sort A-Z or custom drag order, hide/show/pin menu, search", function(t)
  if not H then return end
  fakeButtons(t, { { name = "LibDBIcon10_Zeta" }, { name = "LibDBIcon10_Alpha" }, { name = "LibDBIcon10_Mid" } })
  local clicked
  local comp = rawget(_G, "AddonCompartmentFrame")
  local hadComp = comp ~= nil
  if not comp then comp = CreateFrame("Frame", "AddonCompartmentFrame", Minimap); rawset(_G, "AddonCompartmentFrame", comp) end
  local saved = rawget(comp, "registeredAddons")
  rawset(comp, "registeredAddons", { { text = "Bagger", icon = 1, func = function(name, button) clicked = name .. ":" .. button end }, { text = "Phoenix UI", icon = 2 } })
  t:cleanup(function() rawset(comp, "registeredAddons", saved); if not hadComp then rawset(_G, "AddonCompartmentFrame", nil) end end)
  binOn(t)
  CQ.Drain()
  local function order() local o = {}; for _, b in ipairs(Bin.Visible()) do o[#o + 1] = Bin.Name(b) end; return table.concat(o, ",") end
  t:eq(order(), "Alpha,Mid,Zeta", "A-Z, compartment off by default")
  Schema:Set("mm.bin.compartment", true)
  CQ.Drain()
  t:eq(order(), "Alpha,Bagger,Mid,Zeta", "compartment entries join (Phoenix's own left out)")
  Bin.proxies.Bagger:GetScript("OnClick")(Bin.proxies.Bagger, "LeftButton")
  t:eq(clicked, "Bagger:LeftButton", "proxy calls the addon's own compartment function")
  -- custom order by drag
  Bin.SetEditing(true)
  Bin.dragging, Bin.dropOn = "Zeta", "Alpha"
  t:ok(Bin.Drop(), "drop handled")
  t:eq(Schema:Get("mm.bin.sort"), "custom", "dragging switches to custom order")
  t:eq(order(), "Zeta,Alpha,Bagger,Mid", "drag order applied")
  t:same(Schema:Get("mm.bin.order"), { "Zeta", "Alpha", "Bagger", "Mid" }, "order saved")
  Bin.Act("Alpha", "last")
  t:eq(order(), "Zeta,Bagger,Mid,Alpha", "Move last")
  -- menu
  local zeta
  for _, b in ipairs(Bin.buttons) do if Bin.Name(b) == "Zeta" then zeta = b end end
  local acts = {}
  for _, e in ipairs(Bin.MenuEntries(zeta)) do if e.action then acts[#acts + 1] = e.action end end
  t:same(acts, { "hide", "pin", "never", "first", "last" }, "right-click menu")
  local pacts = {}
  for _, e in ipairs(Bin.MenuEntries(Bin.proxies.Bagger)) do if e.action then pacts[#pacts + 1] = e.action end end
  t:same(pacts, { "hide", "first", "last" }, "compartment entries cannot be pinned")
  Bin.Act("Zeta", "hide")
  t:ok(order():find("Zeta", 1, true) ~= nil, "Edit mode still shows hidden buttons")
  Bin.SetEditing(false)
  t:eq(order(), "Bagger,Mid,Alpha", "hidden live")
  t:eq(Bin.Count(), 3, "count excludes hidden")
  t:eq(Bin.toggle.badge:GetText(), "3", "badge shows the count")
  Bin.Act("Zeta", "show")
  t:eq(Bin.Count(), 4, "shown again")
  Bin.Act("Mid", "pin")
  CQ.Drain()
  t:eq(order(), "Zeta,Bagger,Alpha", "pinned button goes back to the minimap")
  Bin.filter = "ag"
  t:eq(order(), "Bagger", "search")
  Schema:Set("mm.bin.search", false)
  t:cleanup(function() Schema:Set("mm.bin.search", true) end)
  t:eq(#Bin.Visible(), 3, "search box off ignores the filter")
end)

Tests:Add("HUD", "bin: grid grows four ways, docked bar or Studio mover, popup side", function(t)
  local cells, w, h = Bin.Grid(3, 2, 10, 2, "right", 4, 4)
  t:same({ cells[2].x, cells[3].x, cells[3].y }, { 16, 4, -16 }, "right: rows")
  cells = Bin.Grid(3, 2, 10, 2, "left", 4, 4)
  t:same({ cells[1].x, cells[2].x }, { 16, 4 }, "left: mirrored")
  cells, w, h = Bin.Grid(3, 2, 10, 2, "down", 4, 4)
  t:same({ cells[2].y, cells[3].x }, { -16, 16 }, "down: columns")
  t:eq(w, 8 + 24 - 2, "down: width from lines")
  cells = Bin.Grid(3, 2, 10, 2, "up", 4, 4)
  t:same({ cells[1].y, cells[2].y }, { -16, -4 }, "up: mirrored")
  t:ok(PUI.Layout:Element("mm.binbar") ~= nil, "Studio mover element for the bar")
  if not H then return end
  fakeButtons(t, { { name = "LibDBIcon10_One" }, { name = "LibDBIcon10_Two" } })
  binOn(t)
  Schema:Set("mm.bin.layout", "bar")
  CQ.Drain()
  t:ok(Bin.bar:IsShown(), "bar shown")
  t:eq(Bin.buttons[1]:GetParent(), Bin.bar, "buttons live in the bar")
  t:same({ Bin.bar.point[1], Bin.bar.point[2], Bin.bar.point[3] }, { "TOPLEFT", Minimap, "BOTTOMLEFT" }, "docked under the minimap growing right")
  Schema:Set("mm.bin.grow", "down")
  CQ.Drain()
  t:same({ Bin.bar.point[1], Bin.bar.point[3] }, { "TOPRIGHT", "TOPLEFT" }, "docked on the left edge growing down")
  Schema:Set("mm.bin.dock", "free")
  CQ.Drain()
  t:eq(PUI.Layout:Frame("mm.binbar"), Bin.bar, "free: placed by the Studio mover")
  Schema:Set("mm.bin.layout", "popup")
  Schema:Set("mm.bin.grow", "right")
  CQ.Drain()
  t:eq(Bin.bar:IsShown(), false, "popup layout hides the bar")
  Bin.Toggle(true)
  t:same({ Bin.flyout.point[1], Bin.flyout.point[3] }, { "TOPLEFT", "TOPRIGHT" }, "popup opens on the grow side")
  t:eq(Bin.buttons[1]:GetParent(), Bin.flyout, "buttons moved to the popup live")
end)

Tests:Add("HUD", "bin: skin mask/border/ring strip restored, auto-close delay, idle fade, hide in combat", function(t)
  if not H then return end
  local made = fakeButtons(t, { { name = "LibDBIcon10_Ring" } })
  local b = made[1]
  local icon, ring = b:CreateTexture(), b:CreateTexture()
  rawset(b, "icon", icon)
  rawset(ring, "GetTexture", function() return "Interface\\Minimap\\MiniMap-TrackingBorder" end)
  rawset(b, "GetRegions", function() return icon, ring end)
  local origPoint = { "TOPLEFT", Minimap, "TOPLEFT", 10, -10 }
  rawset(b, "GetNumPoints", function() return 1 end)
  rawset(b, "GetPoint", function() return unpack(origPoint) end)
  binOn(t)
  CQ.Drain()
  Bin.Toggle(true)
  t:eq(ring:GetAlpha(), 0, "ring art stripped")
  t:ok(rawget(icon, "masks") and next(icon.masks) ~= nil, "icon masked")
  Schema:Set("mm.bin.shape", "round")
  CQ.Drain()
  t:eq(Bin.original[b].mask.texture, "Interface\\Masks\\CircleMaskScalable", "round mask live")
  Schema:Set("mm.bin.skin", false)
  CQ.Drain()
  t:eq(ring:GetAlpha(), 1, "skin off gives the ring back")
  t:eq(next(icon.masks), nil, "and removes the mask")
  Schema:Set("mm.bin.skin", true)
  CQ.Drain()
  -- auto-close
  Bin.Toggle(true)
  t:ok(Ticker:IsRegistered("mm.bin.mouse"), "mouse job only while open")
  Schema:Set("mm.bin.closeDelay", 1)
  Bin.MouseTick(100)
  t:ok(Bin.flyout:IsShown(), "still open inside the delay")
  Bin.MouseTick(101.1)
  t:eq(Bin.flyout:IsShown(), false, "closed after the delay")
  t:eq(Ticker:IsRegistered("mm.bin.mouse"), false, "job gone when closed")
  -- fade
  Schema:Set("mm.bin.layout", "bar")
  Schema:Set("mm.bin.fade", 0.3)
  CQ.Drain()
  t:ok(Ticker:IsRegistered("mm.bin.mouse"), "fade job while the bar fades")
  Bin.MouseTick(200)
  t:eq(Bin.bar:GetAlpha(), 0.3, "idle fade")
  rawset(Bin.bar, "mouseOver", true)
  Bin.MouseTick(201)
  t:eq(Bin.bar:GetAlpha(), 1, "hover shows it")
  rawset(Bin.bar, "mouseOver", nil)
  -- combat
  H.inCombat = true
  t:cleanup(function() H.inCombat = false end)
  Bin.events:GetScript("OnEvent")(Bin.events, "PLAYER_REGEN_DISABLED")
  t:eq(Bin.bar:IsShown(), false, "hidden in combat")
  H.inCombat = false
  CQ.Drain()
  t:ok(Bin.bar:IsShown(), "back after combat")
  -- restore
  Schema:Set("mm.bin.enabled", false)
  CQ.Drain()
  t:eq(b:GetParent(), Minimap, "parent restored")
  t:same(b.point, origPoint, "points restored")
  t:eq(ring:GetAlpha(), 1, "art restored")
end)

Tests:Add("HUD", "bin: bin button skin and badge follow settings live", function(t)
  if not H then return end
  fakeButtons(t, { { name = "LibDBIcon10_A" }, { name = "LibDBIcon10_B" } })
  binOn(t)
  CQ.Drain()
  t:eq(Bin.toggle.badge:GetText(), "2", "badge count")
  t:ok(Bin.toggle.badge:IsShown(), "badge shown")
  Schema:Set("mm.bin.badge", false)
  CQ.Drain()
  t:eq(Bin.toggle.badge:IsShown(), false, "badge off live")
  t:ok(tostring(Bin.toggle.tex.texture):find("PhoenixUI_Icon", 1, true), "Phoenix bin button")
  Schema:Set("mm.bin.binSkin", "blizzard")
  CQ.Drain()
  t:eq(Bin.toggle.tex.texture, "Interface\\Buttons\\UI-PlusButton-Up", "Blizzard look live")
end)
