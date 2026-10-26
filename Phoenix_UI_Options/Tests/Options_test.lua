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
