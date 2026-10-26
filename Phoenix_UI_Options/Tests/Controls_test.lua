local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Options, Schema = PUI.Tests, PUI.Options, PUI.Schema
local Widgets, Model = Options.Widgets, Options.Model

Tests:Add("Controls", "every schema type has a widget and every visible key builds a row", function(t)
  for ty in pairs(Schema.TYPES) do
    if ty ~= "layout" then t:ok(Widgets.build[ty] ~= nil, "widget for " .. ty) end
  end
  local parent = CreateFrame("Frame")
  for _, key in ipairs({ "options.tint", "options.toggleKey", "options.openAnchor", "options.pinned", "core.autoProfile.where" }) do
    local row = Widgets.Row(parent, key)
    t:ok(row.control ~= nil, key .. " row built")
    t:ok(Model.Format(Schema:Def(key), Schema:Get(key)) ~= nil, key .. " formats")
  end
end)

Tests:Add("Controls", "list, grid and key helpers", function(t)
  Tests.Keep(t, "options.pinned", "core.autoProfile.where", "options.toggleKey")
  local l = Widgets.ListMove({ "a", "b", "c" }, 1, 1)
  t:eq(l[1] .. l[2] .. l[3], "bac", "move down")
  t:eq(Widgets.ListMove({ "a", "b" }, 1, -1)[1], "a", "top stays")
  t:ok(Model.Commit("options.pinned", { "Theme", "Profiles" }), "pinned commit")
  t:eq(Schema:Get("options.pinned")[2], "Profiles", "stored in order")
  local def = Schema:Def("core.autoProfile.where")
  local v = Widgets.GridFlip(def, Schema:Get("core.autoProfile.where"), "switch", "raid")
  t:eq(v.switch.raid, false, "cell flipped")
  v = Widgets.GridFlip(def, v, nil, "raid")
  t:eq(v.switch.raid and v.announce.raid, true, "column mostly off -> all on")
  t:eq(Widgets.KeyCombo("LSHIFT"), nil, "bare modifier ignored")
  t:eq(Widgets.KeyCombo("K"), "K", "plain key")
  t:ok(Model.Commit("options.toggleKey", "CTRL-K"), "key commit")
  t:ok(Model.Commit("options.toggleKey", ""), "key cleared")
end)

Tests:Add("Controls", "window scale, tint and anchor apply live", function(t)
  Tests.Keep(t, "options.scale", "options.tint", "options.openAnchor")
  local f = Options.frame or Options:Build()
  Model.Commit("options.scale", 1.2)
  t:eq(f:GetScale(), 1.2, "scale live")
  Model.Commit("options.tint", { r = 1, g = 0, b = 0, a = 1 })
  t:eq(f.glassTint.color[1], 1, "tint live")
  Model.Commit("options.openAnchor", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -40 })
  t:eq(f.point[1], "TOPLEFT", "anchor live")
end)

Tests:Add("Controls", "profiles page builds and refreshes", function(t)
  local f = Options.frame or Options:Build()
  Options.ProfilesPage:Show(f.host)
  t:ok(Options.views.profiles ~= nil, "view built")
  Options.ProfilesPage:Refresh()
  t:ok(#Options.views.profiles.content == #PUI.Profiles.CONTENT, "one picker per content")
end)
