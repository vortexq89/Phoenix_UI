local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- OptionsHost: the core side of the options window and Studio. Both live in
-- the load-on-demand child Phoenix_UI_Options; this file owns their settings
-- (so they exist and apply before the child loads) and the /pui entry points.
local Host = { CHILD = "Phoenix_UI_Options" }
PUI.OptionsHost = Host

function Host:Load()
  if C_AddOns.IsAddOnLoaded(self.CHILD) then return true end
  local loaded, reason = C_AddOns.LoadAddOn(self.CHILD)
  if not loaded then
    self.loadError = reason
    PUI.Slash.Print("options unavailable: " .. tostring(reason) .. " (is Phoenix_UI_Options enabled?)")
  end
  return loaded
end

local function forward(target, method)
  return function(value)
    local t = PUI[target]
    if t and t[method] then t[method](t, value) end
  end
end

PUI.Schema:Register("options.mode", {
  type = "select", default = "simple", choices = { "simple", "advanced" },
  label = "Options mode", tooltip = "Simple shows the curated settings; Advanced shows every setting.",
  mode = "simple", owner = "Options", searchTags = { "advanced", "simple" },
  apply = forward("Options", "OnModeChanged"),
})

PUI.Schema:Register("studio.gridSize", {
  type = "range", default = 16, min = 4, max = 64, step = 4,
  label = "Studio grid size", tooltip = "Spacing of the Studio pixel grid, in UI pixels.",
  mode = "advanced", owner = "Studio", searchTags = { "grid", "editor", "layout" },
  apply = forward("Studio", "OnGridChanged"),
})

PUI.Schema:Register("studio.showGrid", {
  type = "toggle", default = true,
  label = "Show Studio grid", tooltip = "Draw the pixel grid while Studio is open.",
  mode = "simple", owner = "Studio", searchTags = { "grid", "editor" },
  apply = forward("Studio", "OnGridChanged"),
})

PUI.Schema:Register("studio.snap", {
  type = "toggle", default = true,
  label = "Snap to grid", tooltip = "Dragged elements snap to the Studio grid.",
  mode = "simple", owner = "Studio", searchTags = { "snap", "grid", "editor" },
  apply = forward("Studio", "OnSnapChanged"),
})

function Host:OpenOptions(target)
  if self:Load() then PUI.Options:Toggle(target) end
end

function Host:OpenStudio()
  if PUI.CombatQueue.InCombat() then return PUI.Slash.Print("Studio cannot open in combat.") end
  if self:Load() then PUI.Studio:Open() end
end

PUI.Slash.default = function() Host:OpenOptions() end
PUI.Slash:Register("options", function(rest) Host:OpenOptions(rest ~= "" and rest or nil) end, "[page or search]: open the options window")
PUI.Slash:Register("studio", function() Host:OpenStudio() end, "open Studio, the layout editor (not in combat)")
