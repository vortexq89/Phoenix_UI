local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Options, Schema = PUI.Tests, PUI.Options, PUI.Schema
local Model = Options.Model

local function has(list, v)
  for i = 1, #list do if list[i] == v then return true end end
  return false
end

Tests:Add("Options", "pages follow Simple/Advanced and hide layout keys", function(t)
  local simple, advanced = Model.Pages("simple"), Model.Pages("advanced")
  t:eq(simple[1].name, "Core", "Core first")
  local nSimple, nAdv = 0, 0
  for i = 1, #simple do
    nSimple = nSimple + #simple[i].keys
    for _, k in ipairs(simple[i].keys) do t:eq(Schema:Def(k).mode, "simple", k .. " is simple") end
  end
  for i = 1, #advanced do
    nAdv = nAdv + #advanced[i].keys
    t:ok(not has(advanced[i].keys, "layout.positions"), "layout hidden")
  end
  t:ok(nAdv > nSimple, "advanced shows more")
  t:ok(has(Model.Page("advanced", "Theme").keys, "theme.panelAlpha"), "advanced key on its page")
  t:ok(not has(Model.Page("simple", "Theme").keys, "theme.panelAlpha"), "advanced key absent in simple")
end)

Tests:Add("Options", "search matches labels, tags and fuzzy text", function(t)
  t:eq(Model.Search("accent")[1], "theme.accent", "label hit first")
  t:ok(has(Model.Search("transparency"), "theme.panelAlpha"), "search tag hit")
  t:ok(has(Model.Search("acnt colr"), "theme.accent"), "fuzzy hit")
  t:eq(#Model.Search(""), 0, "empty query")
  t:ok(not has(Model.Search("element positions"), "layout.positions"), "hidden keys never match")
end)

Tests:Add("Options", "commit is live, validated and quantized; reset clears", function(t)
  Tests.Keep(t, "theme.panelAlpha", "options.mode")
  t:ok(Model.Commit("theme.panelAlpha", 0.73), "commit")
  t:eq(Schema:Get("theme.panelAlpha"), 0.75, "snapped to step")
  t:eq(PUI.Theme.panelAlpha, 0.75, "applied live")
  t:ok(Model.IsChanged("theme.panelAlpha"), "changed dot")
  t:eq(Model.Commit("theme.panelAlpha", 5) and Schema:Get("theme.panelAlpha"), 1, "clamped to max")
  t:ok(not Model.Commit("options.mode", "expert"), "invalid select refused")
  Schema:Reset("theme.panelAlpha")
  t:ok(not Model.IsChanged("theme.panelAlpha"), "reset to default")
  t:eq(Model.Cycle(Schema:Def("options.mode"), "advanced", 1), "simple", "cycle wraps")
  t:eq(Model.Format(Schema:Def("theme.panelAlpha"), 0.95), "0.95", "format by step")
end)

Tests:Add("Options", "window renders, switches mode and refreshes rows live", function(t)
  Tests.Keep(t, "options.mode", "studio.snap")
  Options:Toggle("Studio")
  t:cleanup(function() Options.frame:Hide() end)
  t:ok(Options.frame:IsShown(), "opened")
  t:eq(Options.page, "Studio", "deep link to a page")
  Schema:Set("options.mode", "advanced")
  t:ok(Options.rows["studio.gridSize"] and Options.rows["studio.gridSize"]:IsShown(), "advanced row shown after switch")
  Schema:Set("options.mode", "simple")
  t:ok(not Options.rows["studio.gridSize"]:IsShown(), "advanced row hidden in simple")
  local row = Options.rows["studio.snap"]
  Schema:Set("studio.snap", false)
  t:ok(row.dot:IsShown(), "changed dot after a change from anywhere")
  row:GetScript("OnMouseUp")(row, "RightButton")
  t:eq(Schema:Get("studio.snap"), true, "right-click resets")
  t:ok(not row.dot:IsShown(), "dot cleared")
  Options.frame.search:SetText("grid")
  Options:Render()
  t:ok(Options.rows["studio.gridSize"]:IsShown(), "search shows advanced matches too")
end)

Tests:Add("Options", "dashboard, module pages, previews and theme page render live", function(t)
  Options:Open("Dashboard")
  t:ok(Options.views.dashboard:IsShown(), "dashboard is the home page")
  local mods = Options.Dashboard.Modules()
  t:ok(#mods > 5, "module cards listed")
  local tabs = Options.PageView.Tabs({ "uf.player.width", "uf.player.height", "uf.target.width", "uf.target.height", "uf.absorbs" })
  t:eq(#tabs, 3, "general + player + target tabs")
  t:eq(tabs[2].label, "Player", "tab label")
  for _, page in ipairs({ "UnitFrames", "ActionBars", "ResourceBars" }) do
    if Model.Page(Model.Mode(), page) then
      Options:Open(page)
      t:ok(Options.views.page:IsShown(), page .. " page shown")
      t:ok(Options.views.page.previewCard:IsShown(), page .. " has a live preview")
      Schema:Set("bars.texture", "Phoenix Smooth")
      Schema:Set("bars.texture", "flat")
    end
  end
  Options:Open("Theme")
  t:ok(Options.views.theme:IsShown(), "theme page shown")
  Model.Commit("theme.accent", "frost")
  t:eq(Schema:Get("theme.accent"), "frost", "accent swatch commits")
  Model.Commit("theme.accent", "ember")
  Options.frame.search:SetText("font")
  Options:Render()
  t:ok(not Options.views.theme:IsShown(), "search replaces the page")
  Options.frame.search:SetText("")
  Options.frame:Hide()
end)

Tests:Add("Options", "Sentinel viewer lists, filters, resolves and copies incidents", function(t)
  local S = PUI.Sentinel
  if not (S and S.Capture and S.db) then return end
  local saved = {}
  for k, v in pairs(S.db.incidents) do saved[k] = v end
  t:cleanup(function()
    wipe(S.db.incidents)
    for k, v in pairs(saved) do S.db.incidents[k] = v end
    if S.Panel.copy then S.Panel.copy:Hide() end
    if Options.frame then Options.frame:Hide() end
    Options.SentinelPage.tab, Options.SentinelPage.selected = "session", nil
  end)
  wipe(S.db.incidents)
  S.Capture:Report("secret", "Nameplates", { message = "attempt to compare a secret number value",
    stack = "Phoenix_UI_Nameplates/Auras.lua:212: in function 'Update'" })
  S.Capture:Report("taint", "ActionBars", { message = "ADDON_ACTION_BLOCKED", stack = "" })
  Options:Open("Sentinel")
  local v = Options.views.sentinel
  t:ok(v and v:IsShown(), "Sentinel page is a custom view")
  local SP = Options.SentinelPage
  t:eq(#SP.Items("session", ""), 2, "two incidents this session")
  t:eq(#SP.Items("session", "auras"), 1, "filter by file")
  local inc = SP.Items("session", "auras")[1]
  SP.selected = inc.hash
  SP:Refresh(v)
  t:eq(SP.current, inc, "selected incident in the detail pane")
  t:ok(v.detail.hint:IsShown(), "secret incidents carry a hint")
  v.detail.resolve:GetScript("OnClick")()
  t:eq(#SP.Items("resolved", ""), 1, "marked resolved")
  t:eq(#SP.Items("session", ""), 1, "resolved leaves the session tab")
  SP.tab, SP.selected = "all", inc.hash
  SP:Refresh(v)
  v.detail.copy:GetScript("OnClick")()
  t:ok(S.Panel.copy:IsShown(), "copy window opens")
end)

-- Foundations leftovers: where-to-show picker, Editing as / overrides, ledger ----------
Tests:Add("Options", "where-to-show helpers build rules and explain them", function(t)
  local W = Options.Widgets
  local r = W.VisFlip({ mode = "always" }, "content", "raid")
  t:eq(r.mode, "when", "picking a chip switches to 'only when'")
  t:ok(r.content.raid, "chip added")
  t:eq(W.VisFlip(r, "content", "raid").content, nil, "second click removes it")
  t:eq(W.VisSet(nil, "combat", "in").combat, "in", "combat choice set")
  local text, kind = W.VisReadout({}, { mode = "never" })
  t:eq(kind, "warn", "never: hidden readout")
  t:ok(text:find("Hidden right now", 1, true) ~= nil, "readout says why")
  t:eq(select(2, W.VisReadout({}, { mode = "always" })), "ok", "always: shown readout")
end)

Tests:Add("Options", "overrides page lists, promotes and removes", function(t)
  local Ov = PUI.Overrides
  local key
  for k, def in pairs(PUI.Schema.defs or {}) do if def.overridable and def.type == "range" then key = k break end end
  if not key then return end
  Tests.Keep(t, key)
  local def = Schema:Def(key)
  local v = math.min(def.max, def.default + def.step)
  t:cleanup(function() Ov:Clear("spec", 1, key); Options.frame:Hide() end)
  Ov:Set("spec", 1, key, v)
  Options:Open("Overrides")
  t:ok(Options.views.overrides and Options.views.overrides.count >= 1, "override listed")
  t:ok(Ov:Get("spec", 1, key) ~= nil, "stored")
  Ov:Promote("spec", 1, key)
  t:eq(Ov:Get("spec", 1, key), nil, "promote moves it to the profile")
  t:eq(PUI.DB:GetRaw(key), v, "profile now holds the value")
end)

Tests:Add("Options", "ledger page lists changes and uninstall gives them back", function(t)
  local CV = PUI.CVars
  local saved = C_CVar.GetCVar("taintLog")
  local on = {}
  for _, name in ipairs(PUI.Kernel.order or {}) do
    if Schema:Def("module." .. name) and Schema:Get("module." .. name) then on[#on + 1] = name end
  end
  t:cleanup(function()
    C_CVar.SetCVar("taintLog", saved)
    for _, name in ipairs(on) do Schema:Set("module." .. name, true) end
    Options.frame:Hide()
  end)
  CV:Set("OptionsTest", "taintLog", saved == "1" and "0" or "1")
  Options:Open("Ledger")
  local entries = Options.LedgerPage.Entries()
  local found
  for _, e in ipairs(entries) do if e.title == "taintLog" then found = e end end
  t:ok(found ~= nil, "CVar change listed with who changed it")
  t:ok(Options.views.ledger.count >= 1, "page shows it")
  local r = PUI.Ledger.Uninstall()
  t:ok(r.cvars >= 1, "uninstall restored the CVar")
  t:eq(C_CVar.GetCVar("taintLog"), saved, "your value is back")
end)

Tests:Add("Options", "unit frame preview follows the look and offers test frames", function(t)
  local UF = PUI.UnitFrames
  if not UF then return end
  Tests.Keep(t, "uf.style")
  t:cleanup(function() Options.frame:Hide() end)
  Options:Open("UnitFrames")
  Schema:Set("uf.style", "glass")
  t:eq(UF.Styles.Resolve(UF.settings.style, {}).portrait, "class", "preview reads the same look table")
  t:ok(Options.frame:IsShown(), "page still open after a live look switch")
end)

Tests:Add("Options", "raid preview draws the tier grid; click-cast composer validates and adds", function(t)
  local RF, CC = PUI.RaidFrames, PUI.ClickCast
  if not (RF and CC) then return end
  Tests.Keep(t, "rf.corners")
  Tests.Keep(t, "cc.list")
  t:cleanup(function() Options.frame:Hide() end)
  local card = CreateFrame("Frame")
  Options.Previews.RaidFrames(card, "party")
  Options.Previews.RaidFrames(card, "large")
  Options.Previews.RaidFrames(card, "debuffs")
  t:ok(RF.Elements and RF.Indicators, "module exports its builder for the preview")
  t:ok(RF.Indicators.PresetFor("DRUID"), "druid heal preset exists")
  Options:Open("RaidFrames")
  t:ok(Options.frame:IsShown(), "raid page renders")
  local Widgets = Options.Widgets
  local added
  local parent = CreateFrame("Frame")
  local c = Widgets.composers.clickcast(parent, {}, function(v) added = v; return true end)
  c.value:SetText("Rejuvenation")
  c.add:GetScript("OnClick")(c.add)
  t:eq(added, "1:spell:Rejuvenation", "composer builds a binding line")
  t:ok(CC.ValidateOne(added), "composed line validates")
end)

Tests:Add("Options", "action bar, cooldown manager and resource bar previews follow the settings", function(t)
  Tests.Keep(t, "ab.rangeMode")
  Tests.Keep(t, "ab.keyAbbrev")
  Tests.Keep(t, "cdm.border")
  Tests.Keep(t, "rb.power.text")
  t:cleanup(function() Options.frame:Hide() end)
  local card = CreateFrame("Frame")
  Schema:Set("ab.keyAbbrev", true)
  Schema:Set("ab.rangeMode", "overlay")
  Options.Previews.ActionBars(card, "bar1")
  local st = Options.Previews.State(card)
  if PUI.ActionBars then
    t:eq(st.icons[6].hotkey:GetText(), "S1", "sample keybind uses the short-text setting")
    t:eq(PUI.Glow:IsGlowing(st.icons[3]), true, "proc sample glows with the real glow")
    t:eq(st.icons[6].range:GetAlpha(), 1, "out-of-range sample")
    Schema:Set("ab.rangeMode", "off")
    Options.Previews.ActionBars(card, "bar1")
    t:eq(st.icons[6].range:GetAlpha(), 0, "range off shows no overlay")
  end
  Options.Previews.CooldownManager(card)
  t:eq(st.cdm[1].edge[1]:IsShown(), true, "cooldown sample border")
  Schema:Set("cdm.border", 0)
  Options.Previews.CooldownManager(card)
  t:eq(st.cdm[1].edge[1]:IsShown(), false, "border 0 in the preview")
  Schema:Set("rb.power.text", "percent")
  Options.Previews.ResourceBars(card)
  t:eq(st.rbPower:GetText(), "64%", "power text sample")
  Options:Open("ActionBars")
  t:ok(Options.frame:IsShown(), "action bars page renders")
  Options:Open("CooldownManager")
  t:ok(Options.frame:IsShown(), "cooldown manager page renders")
  Options:Open("ResourceBars")
  t:ok(Options.frame:IsShown(), "resource bars page renders")
end)

Tests:Add("Options", "batch A extras show in the action bar, cooldown manager and resource bar previews", function(t)
  local AB, CDM, RB = PUI.ActionBars, PUI.CooldownManager, PUI.ResourceBars
  if not (AB and AB.Extras and CDM and CDM.Extras and RB and RB.Extras) then return end
  for _, k in ipairs({ "ab.micro.mode", "ab.cdColors", "cdm.glow.mode", "cdm.assist", "cdm.focusKick", "rb.cast.latency", "rb.power.thresholds", "rb.aura.enabled" }) do Tests.Keep(t, k) end
  local card = CreateFrame("Frame")
  local bag = Options.PreviewsExtras.Bag
  Schema:Set("ab.micro.mode", "hide")
  Schema:Set("ab.cdColors", true)
  Options.Previews.ActionBars(card, "bar1")
  t:ok(bag(card).abMicro:GetAlpha() < 0.2, "micro menu strip follows the mode")
  t:ok(bag(card).abExtrasNote:GetText():find("hide", 1, true), "note names the mode")
  Schema:Set("cdm.glow.mode", "proc"); Schema:Set("cdm.assist", true); Schema:Set("cdm.focusKick", true)
  Options.Previews.CooldownManager(card)
  t:eq(bag(card).cdmGlow:IsShown(), true, "glow sample")
  t:eq(bag(card).cdmAssist:IsShown(), true, "assist icon sample")
  t:eq(bag(card).cdmKick:IsShown(), true, "focus kick sample")
  Schema:Set("cdm.glow.mode", "off")
  Options.Previews.CooldownManager(card)
  t:eq(bag(card).cdmGlow:IsShown(), false, "glow off")
  Schema:Set("rb.cast.latency", true); Schema:Set("rb.aura.enabled", true); Schema:Set("rb.power.thresholds", true)
  Options.Previews.ResourceBars(card)
  t:eq(bag(card).rbAura:IsShown(), true, "aura stack sample")
  t:ok(bag(card).rbNote:GetText():find("aura stacks", 1, true), "note explains the samples")
  t:eq(Options.Previews.State(card).rb[2].barColor[1], RB.Extras.settings.midColor.r, "power sample in the middle colour")
end)

Tests:Add("Options", "a key can show on another module's page: queue pop time on Group Finder", function(t)
  local Model = PUI.Options.Model
  local def = PUI.Schema:Def("queue.lfgSeconds")
  t:eq(def.owner, "Core", "still owned by Core")
  t:eq(def.page, "GroupFinder", "shown on the Group Finder page")
  local found, onCore = false, false
  for _, k in ipairs(Model.Page("advanced", "GroupFinder").keys) do if k == "queue.lfgSeconds" then found = true end end
  for _, p in ipairs(Model.Pages("advanced")) do
    if p.name == "Core" then for _, k in ipairs(p.keys) do if k == "queue.lfgSeconds" then onCore = true end end end
  end
  t:ok(found, "listed on Group Finder")
  t:ok(not onCore, "not on the Core page any more")
  local hits = Model.Search("group finder queue")
  local hit = false
  for _, k in ipairs(hits) do if k == "queue.lfgSeconds" then hit = true end end
  t:ok(hit, "search finds it under the page name")
end)

Tests:Add("Options", "batch B HUD extras show in the minimap, tooltip, data bar and group finder previews", function(t)
  if not (PUI.Minimap and PUI.Minimap.Buttons and PUI.Tooltip and PUI.Tooltip.Extras) then return end
  for _, k in ipairs({ "mm.buttons", "tt.lines.upgrade", "db.spec.on", "skins.queueTimer", "queue.lfgSeconds" }) do Tests.Keep(t, k) end
  local card = CreateFrame("Frame")
  local bag = Options.PreviewsExtras.Bag
  Schema:Set("mm.buttons", "phoenix")
  Options.Previews.Minimap(card)
  t:ok(bag(card).mmBtn1:IsShown() and bag(card).mmBtn3:IsShown(), "Phoenix buttons drawn")
  Schema:Set("mm.buttons", "blizzard")
  Options.Previews.Minimap(card)
  t:eq(bag(card).mmBtn1:IsShown(), false, "hidden for Blizzard's buttons")
  Options.Previews.Tooltip(card)
  t:eq(bag(card).ttExtra1:GetText(), "Item level 678  -  Arms", "inspect sample line")
  Schema:Set("tt.lines.upgrade", false)
  Options.Previews.Tooltip(card)
  t:eq(bag(card).ttExtra3:GetText(), "Set pieces equipped: 2", "upgrade line drops out live")
  Schema:Set("db.spec.on", true)
  Options.Previews.DataBars(card)
  t:ok(bag(card).dbExtrasNote:GetText():find("Per-spec blocks on", 1, true), "per-spec state shown")
  Schema:Set("queue.lfgSeconds", 50)
  Options.Previews.GroupFinder(card)
  t:ok(bag(card).gfQueueText:GetText():find("30 of 50", 1, true), "queue timer sample follows queue.lfgSeconds")
  Schema:Set("skins.queueTimer", false)
  Options.Previews.GroupFinder(card)
  t:eq(bag(card).gfQueue:IsShown(), false, "timer off live")
end)

Tests:Add("Options", "batch C extras show live on every module preview", function(t)
  local bag = Options.PreviewsExtras.Bag
  local pages = { QuestTracker = "qt", Reminders = "rm", Embers = "em", Ascent = "as", Flow = "fl", GroupFinder = "gf", RaidTools = "rt",
    Pulse = "pl", Arena = "ar", Spark = "sp", CastHistory = "ch", PvP = "pv", Friends = "fr", Sentinel = "sn" }
  for _, k in ipairs({ "pulse.nextHud", "arena.pets", "flow.gg" }) do Tests.Keep(t, k) end
  for owner, id in pairs(pages) do
    local card = CreateFrame("Frame")
    Options.Previews[owner](card)
    local first = bag(card)[id .. "C1"]
    t:ok(first and first:IsShown(), owner .. ": batch C lines drawn")
  end
  local card = CreateFrame("Frame")
  Schema:Set("pulse.nextHud", true)
  Options.Previews.Pulse(card)
  t:ok(bag(card).plC2:GetText():find("Devouring Cosmos", 1, true), "next abilities sample")
  Schema:Set("pulse.nextHud", false)
  Options.Previews.Pulse(card)
  t:ok(bag(card).plC1:GetText():find("(off)", 1, true), "setting change shows live")
  Schema:Set("arena.pets", false)
  Options.Previews.Arena(card)
  t:ok(bag(card).arC2:GetText():find("Pet frames off", 1, true), "arena pets off in the preview")
end)

Tests:Add("Options", "CPU chip shows the open page's profiler time live", function(t)
  local Chip, P = Options.CpuChip, PUI.Profiler
  Tests.Keep(t, "sentinel.cpuChip")
  local saved = P.stats
  P.stats = { a = { owner = "Embers", self = 1.5 }, b = { owner = "Arena", self = 9 } }
  t:cleanup(function() P.stats = saved end)
  t:ok(Chip.Text("Embers"):find("1.50 ms", 1, true), "page total")
  t:eq(Chip.Text("Dashboard"), nil, "not on the Dashboard")
  t:eq(Chip.Text("Flow"), nil, "nothing without samples")
  Schema:Set("sentinel.cpuChip", false)
  t:eq(Chip.Text("Embers"), nil, "off")
end)

Tests:Add("Options", "Diagnostics page: own System entry, report lines, developer settings on it", function(t)
  local Page = Options.DiagPage
  local found = false
  for _, g in ipairs(Options.Nav.GROUPS) do if g[1] == "System" then for _, n in ipairs(g[2]) do if n == "Diagnostics" then found = true end end end end
  t:ok(found, "listed under System")
  t:eq(Schema:Def("sentinel.recorder").page, "Diagnostics", "recorder setting on the page")
  local p = Model.Page("advanced", "Diagnostics")
  t:eq(p.name, "Diagnostics", "page exists")
  local lines = Page.Lines(80)
  t:eq(lines[1], "Phoenix UI diagnostics", "report first line")
  local self = false
  for _, l in ipairs(lines) do if l:find("Self-measurement", 1, true) then self = true end end
  t:ok(self, "self-measurement in the report")
  local host = CreateFrame("Frame")
  Page:Show(host)
  t:eq(Options.views.diagnostics.lines[1]:GetText(), "Phoenix UI diagnostics", "drawn")
end)
