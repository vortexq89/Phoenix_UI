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

-- Window settings (D-SET-UI floating window). Every one applies live.
PUI.Schema:Register("options.scale", {
  type = "range", default = 1, min = 0.6, max = 1.5, step = 0.05, unit = "x",
  label = "Window scale", tooltip = "Size of this settings window. Independent of your UI scale.",
  mode = "simple", owner = "Options", searchTags = { "size", "zoom", "window", "scale" },
  apply = forward("Options", "OnWindowSettings"),
})

PUI.Schema:Register("options.tint", {
  type = "color", default = { r = 0.42, g = 0.16, b = 0.05, a = 0 },
  label = "Window tint", tooltip = "Colour wash over the settings window glass. Alpha sets how strong it is (0 = none). Glass opacity is in Theme & Media.",
  mode = "advanced", owner = "Options", searchTags = { "colour", "color", "background", "glass", "window" },
  apply = forward("Options", "OnWindowSettings"),
})

PUI.Schema:Register("options.openAnchor", {
  type = "anchor", default = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
  label = "Opens at", tooltip = "Where the window opens on screen. Dragging the window updates this.",
  mode = "advanced", owner = "Options", searchTags = { "position", "window", "anchor" },
  apply = forward("Options", "OnWindowSettings"),
})

PUI.Schema:Register("options.window", {
  type = "layout", default = { w = 1420, h = 860 },
  label = "Window size", tooltip = "Last size of the settings window.",
  mode = "advanced", owner = "Options",
  apply = forward("Options", "OnWindowSettings"),
})

PUI.Schema:Register("options.pinned", {
  type = "list", default = {}, maxItems = 8, itemChoices = function()
    local out = {}
    if PUI.Options and PUI.Options.Model then
      for _, p in ipairs(PUI.Options.Model.Pages("advanced")) do out[#out + 1] = p.name end
    end
    return out
  end,
  label = "Pinned pages", tooltip = "Pages shown at the top of the sidebar, in this order.",
  mode = "simple", owner = "Options", searchTags = { "favourite", "favorite", "pin", "sidebar" },
  apply = forward("Options", "OnPinned"),
})

PUI.Schema:Register("options.motion", {
  type = "toggle", default = true,
  label = "Window animations", tooltip = "Fade and slide the window and its pages. Turn off for reduced motion.",
  mode = "advanced", owner = "Options", searchTags = { "animation", "motion", "accessibility", "fade" },
  apply = forward("Options", "OnWindowSettings"),
})

-- Key that opens and closes the window (an override binding owned by Phoenix,
-- set out of combat, cleared when emptied; your own key bindings are untouched).
local toggleButton = PUI:CreateFrame("Button", "PhoenixUIOptionsToggleButton", UIParent, nil, "Options")
toggleButton:Hide()
toggleButton:SetScript("OnClick", function() Host:OpenOptions() end)
PUI.Schema:Register("options.toggleKey", {
  type = "keybind", default = "",
  label = "Open key", tooltip = "Press this key to open or close Phoenix settings. Empty means no key.",
  mode = "simple", owner = "Options", searchTags = { "keybind", "hotkey", "shortcut", "bind" },
  apply = function(key)
    PUI.CombatQueue.Defer("options.toggleKey", function()
      ClearOverrideBindings(toggleButton)
      if key ~= "" then SetOverrideBindingClick(toggleButton, false, key, "PhoenixUIOptionsToggleButton") end
    end)
  end,
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

local function studioKey(id, def) def.owner = "Studio"; def.apply = def.apply or forward("Studio", "OnSettingsChanged"); PUI.Schema:Register(id, def) end
studioKey("studio.snapMode", { type = "select", default = "both", choices = { "grid", "elements", "both" },
  label = "Snap to", tooltip = "What dragged elements snap to while Snap is on: the grid, other elements' edges and centres, or both.",
  mode = "simple", searchTags = { "snap", "align", "edges" } })
studioKey("studio.snapDistance", { type = "range", default = 8, min = 2, max = 32, step = 1,
  label = "Snap distance", tooltip = "How close (in UI pixels) an edge must come before it snaps.",
  mode = "advanced", searchTags = { "snap", "magnet" } })
studioKey("studio.centerGuides", { type = "toggle", default = true,
  label = "Centre guides", tooltip = "Draw the screen's centre lines while Studio is open.",
  mode = "simple", searchTags = { "guides", "centre", "center" } })
studioKey("studio.safeZone", { type = "toggle", default = false,
  label = "HUD safe-zone guides", tooltip = "Shade the screen edges and the centre area where your character stands, to keep frames out of the way.",
  mode = "advanced", searchTags = { "guides", "safe", "zone" } })
studioKey("studio.distanceLabels", { type = "toggle", default = true,
  label = "Distance labels", tooltip = "Show the gap to the nearest element on each side of the selected one.",
  mode = "simple", searchTags = { "distance", "gap", "measure" } })
studioKey("studio.labels", { type = "select", default = "hover", choices = { "hover", "always", "selected" },
  label = "Element names", tooltip = "When Studio shows each mover's name.",
  mode = "simple", searchTags = { "labels", "names" } })
studioKey("studio.overlayAlpha", { type = "range", default = 0.72, min = 0, max = 0.95, step = 0.05,
  label = "Overlay darkness", tooltip = "How dark the screen gets behind the movers.",
  mode = "advanced", searchTags = { "overlay", "dim", "dark" } })
studioKey("studio.nudgeShift", { type = "range", default = 10, min = 2, max = 50, step = 1,
  label = "Shift nudge step", tooltip = "Pixels moved per arrow press while holding Shift (1 without a modifier).",
  mode = "advanced", searchTags = { "nudge", "arrow" } })
studioKey("studio.nudgeCtrl", { type = "range", default = 100, min = 20, max = 400, step = 10,
  label = "Ctrl nudge step", tooltip = "Pixels moved per arrow press while holding Ctrl.",
  mode = "advanced", searchTags = { "nudge", "arrow" } })
studioKey("studio.wheelCycle", { type = "toggle", default = true,
  label = "Mouse wheel cycles overlaps", tooltip = "Scroll over stacked movers to pick the one underneath.",
  mode = "advanced", searchTags = { "overlap", "wheel", "stacked" } })
studioKey("studio.groupDrag", { type = "toggle", default = true,
  label = "Drag the whole selection", tooltip = "With several elements selected, dragging one moves them all.",
  mode = "advanced", searchTags = { "multi", "group", "selection" } })
studioKey("studio.editModeBadge", { type = "toggle", default = true,
  label = "Show Edit Mode badges", tooltip = "Mark Blizzard elements that Edit Mode owns, with a button to open Edit Mode for them.",
  mode = "advanced", searchTags = { "edit mode", "badge", "blizzard" } })
studioKey("studio.templates", { type = "layout", default = {},
  label = "Saved layouts", tooltip = "Layouts you saved as templates in Studio.", mode = "advanced" })

-- Key that opens and closes Studio, through the binding ledger (owner Studio).
local studioButton = PUI:CreateFrame("Button", "PhoenixUIStudioToggleButton", UIParent, nil, "Studio")
studioButton:Hide()
studioButton:SetScript("OnClick", function()
  if PUI.Studio and PUI.Studio.IsOpen and PUI.Studio:IsOpen() then PUI.Studio:Exit() else Host:OpenStudio() end
end)
studioKey("studio.toggleKey", { type = "keybind", default = "",
  label = "Studio key", tooltip = "Press this key to open or close Studio. Empty means no key. Your own key bindings are untouched.",
  mode = "simple", searchTags = { "keybind", "hotkey", "studio", "layout", "move" },
  apply = function(key)
    if not PUI.Bindings then return end
    PUI.Bindings:Release("Studio")
    if key ~= "" then PUI.Bindings:Claim("Studio", key, { click = "PhoenixUIStudioToggleButton" }) end
  end })

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

-- Blizzard Settings entry (Esc > Options > AddOns > Phoenix UI): a launcher
-- canvas with one button that opens the Phoenix window. Blizzard's own
-- settings tables are never touched.
function Host:RegisterBlizzardSettings()
  if self.category or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local canvas = PUI:CreateFrame("Frame", "PhoenixUIBlizzardSettings", UIParent, nil, "Options")
  canvas:Hide()
  local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Phoenix UI")
  local note = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  note:SetText("Every Phoenix setting lives in its own window with live previews. Type /pui any time.")
  local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
  open:SetSize(220, 30)
  open:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -16)
  open:SetText("Open Phoenix UI settings")
  open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    Host:OpenOptions()
  end)
  local category = Settings.RegisterCanvasLayoutCategory(canvas, "Phoenix UI")
  Settings.RegisterAddOnCategory(category)
  self.category = category
end
PUI.Kernel:On("LOGIN", function() Host:RegisterBlizzardSettings() end)
