local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Minimap button bin (plan 5.7 / mockup 14, upgraded t97u). Every addon
-- minimap button is gathered in one place:
--  * LibDBIcon buttons and other addons' own minimap buttons (named Buttons
--    on the Minimap / MinimapCluster that are not Blizzard's), including ones
--    created late: rescans on ADDON_LOADED and from a short Ticker job after
--    login (the job removes itself after SCAN_FOR seconds).
--  * Optional addon compartment entries, drawn as Phoenix proxy buttons.
--  * Layout: a popup grid opened from the bin button, or a docked bar along
--    the minimap edge or anywhere (Studio mover "mm.binbar"); grow direction,
--    A-Z or a custom drag order (saved), search, per-button hide / show / pin
--    from a right-click menu (Edit mode: Shift-click the bin button or press
--    Edit), theme skin (square / round icon mask, border, ring art stripped),
--    count badge, auto-close on leave after a delay, hide in combat, idle fade.
-- Taint: buttons are only re-parented and re-anchored out of combat
-- (CombatQueue); protected frames are never touched; their scripts are never
-- replaced, so tooltips and clicks stay the addon's own. Each button's
-- parent, points, size, shown state, stripped art and mask are recorded and
-- given back exactly when the bin (or the Minimap module) turns off.
local _, ns = ...
local Schema, CQ, Theme, Media, Ticker = PUI.Schema, PUI.CombatQueue, PUI.Theme, PUI.Media, PUI.Ticker
local L = PUI.L
local MM = ns.MM
local OWNER = "Minimap"

local Bin = { buttons = {}, original = {}, proxies = {}, skins = {}, overlays = {}, filter = "", SCAN_FOR = 30, SCAN_EVERY = 2 }
ns.Bin = Bin
PUI.ButtonBin = Bin

local s = { enabled = true, layout = "popup", dock = "minimap", columns = 6, size = 28, spacing = 4, grow = "right", open = "click",
  sort = "az", order = {}, hidden = {}, blacklist = {}, keep = {}, compartment = false, search = true,
  skin = true, shape = "square", border = true, strip = true, badge = true, binSkin = "phoenix",
  autoClose = true, closeDelay = 1, hideInCombat = true, fade = 1, mouseover = false }
Bin.settings = s

local function listHas(list, name)
  for i = 1, #(list or {}) do if list[i] == name then return true end end
  return false
end
local function listWithout(list, name)
  local out = {}
  for _, v in ipairs(list or {}) do if v ~= name then out[#out + 1] = v end end
  return out
end
Bin.listHas = listHas

-- Detection -----------------------------------------------------------------
local BLIZZARD = { MinimapZoomIn = true, MinimapZoomOut = true, MiniMapTrackingButton = true, GameTimeFrame = true,
  MinimapBackdrop = true, MiniMapMailFrame = true, QueueStatusButton = true, ExpansionLandingPageMinimapButton = true,
  AddonCompartmentFrame = true, MinimapCompassTexture = true, MiniMapWorldMapButton = true, MinimapZoneTextButton = true,
  TimeManagerClockButton = true, MiniMapInstanceDifficulty = true, GuildInstanceDifficulty = true, MiniMapChallengeMode = true,
  GarrisonLandingPageMinimapButton = true, MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, MiniMapVoiceChatFrame = true }
Bin.BLIZZARD = BLIZZARD
local BLIZZ_PREFIX = { "^PhoenixUI", "^Minimap[A-Z]", "^MiniMap[A-Z]", "^GameTime", "^Queue", "^Expansion", "^Garrison", "^HybridMinimap" }
-- An addon's minimap button: a named, unprotected, button-sized Button (or a
-- frame with a click script) that is not one of Blizzard's or Phoenix's.
function Bin.IsAddonButton(frame)
  if type(frame) ~= "table" or not frame.GetName then return false end
  local name = frame:GetName()
  if type(name) ~= "string" or BLIZZARD[name] then return false end
  if frame.IsProtected and frame:IsProtected() then return false end
  if name:find("^LibDBIcon10_") then return true end
  local mm = (name:find("MinimapButton") or name:find("MiniMapButton")) ~= nil
  if not mm then for _, p in ipairs(BLIZZ_PREFIX) do if name:find(p) then return false end end end
  if name:find("^PhoenixUI") then return false end
  local clickable = frame:GetObjectType() == "Button" or (frame.GetScript and (frame:GetScript("OnClick") or frame:GetScript("OnMouseUp")) ~= nil)
  if not clickable then return false end
  local w = frame.GetWidth and frame:GetWidth() or 0
  if w > 64 then return false end -- panels and bars are not buttons
  return true
end

-- Label shown in search and lists: the LibDBIcon data object name when present.
function Bin.Label(frame)
  local name = frame.GetName and frame:GetName() or frame.label or ""
  return (name:gsub("^LibDBIcon10_", ""):gsub("_?Mini[mM]ap[bB]utton$", ""))
end
function Bin.Name(b) return rawget(b, "binLabel") or Bin.Label(b) end

function Bin.Scan()
  local found, seen = {}, {}
  local function take(parent)
    if not (parent and parent.GetChildren) then return end
    for _, child in ipairs({ parent:GetChildren() }) do
      if not seen[child] and Bin.IsAddonButton(child) then seen[child] = true; found[#found + 1] = child end
    end
  end
  take(Minimap)
  take(rawget(_G, "MinimapBackdrop"))
  take(rawget(_G, "MinimapCluster"))
  table.sort(found, function(a, b) return Bin.Label(a):lower() < Bin.Label(b):lower() end)
  return found
end

-- Addon compartment entries (Blizzard's list of { text, icon, func, ... }).
function Bin.CompartmentEntries()
  local f = rawget(_G, "AddonCompartmentFrame")
  local list = f and rawget(f, "registeredAddons")
  local out = {}
  if type(list) ~= "table" then return out end
  for _, e in ipairs(list) do
    if type(e) == "table" and type(e.text) == "string" and not e.text:find("Phoenix", 1, true) then out[#out + 1] = e end
  end
  return out
end
local function resolve(fn) if type(fn) == "string" then return rawget(_G, fn) end return fn end
function Bin.Proxy(entry)
  local p = Bin.proxies[entry.text]
  if not p then
    p = PUI:CreateFrame("Button", nil, Bin.Holder(), nil, OWNER)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    p:RegisterForClicks("AnyUp")
    p:SetScript("OnClick", function(self, button)
      if button == "RightButton" and Bin.editing then return Bin.OpenMenu(self) end
      local fn = resolve(self.entry.func)
      if type(fn) == "function" then fn(self.entry.text, button, nil, self) end
    end)
    p:SetScript("OnEnter", function(self)
      local fn = resolve(self.entry.funcOnEnter)
      if type(fn) == "function" then fn(self, self.entry) return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(self.entry.text)
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function(self)
      local fn = resolve(self.entry.funcOnLeave)
      if type(fn) == "function" then fn(self, self.entry) end
      GameTooltip:Hide()
    end)
    p.proxy = true
    Bin.proxies[entry.text] = p
  end
  p.entry, p.binLabel = entry, entry.text
  p.icon:SetTexture(entry.icon or 134400)
  return p
end

-- Containers ----------------------------------------------------------------
local flyout, bar, toggle
function Bin.Holder()
  if s.layout == "bar" then return Bin.BuildBar() end
  return Bin.BuildFlyout()
end
function Bin.BuildFlyout()
  if flyout then return flyout end
  flyout = PUI:CreateFrame("Frame", "PhoenixUI_ButtonBin", UIParent, "BackdropTemplate", OWNER)
  Theme:Backdrop(flyout, "surface.1")
  Theme:Outline(flyout, "line")
  flyout:SetFrameStrata("DIALOG")
  flyout.title = flyout:CreateFontString(nil, "OVERLAY")
  flyout.title:SetFontObject(Media:FontObject("label"))
  flyout.title:SetPoint("TOPLEFT", 8, -8)
  flyout.search = CreateFrame("EditBox", nil, flyout, "InputBoxTemplate")
  flyout.search:SetSize(90, 18)
  flyout.search:SetPoint("TOPRIGHT", -44, -5)
  flyout.search:SetAutoFocus(false)
  flyout.search:SetScript("OnTextChanged", function(self) Bin.filter = self:GetText() or ""; Bin.Layout() end)
  flyout.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  flyout.edit = PUI:CreateFrame("Button", nil, flyout, nil, OWNER)
  flyout.edit:SetSize(34, 18)
  flyout.edit:SetPoint("TOPRIGHT", -6, -5)
  Theme:Backdrop(flyout.edit, "surface.2")
  flyout.edit.text = flyout.edit:CreateFontString(nil, "OVERLAY")
  flyout.edit.text:SetFontObject(Media:FontObject("small"))
  flyout.edit.text:SetPoint("CENTER")
  flyout.edit:SetScript("OnClick", function() Bin.SetEditing(not Bin.editing) end)
  flyout:Hide()
  Bin.flyout = flyout
  return flyout
end
PUI.Layout:RegisterElement("mm.binbar", { label = "Minimap button bar", owner = OWNER, size = { 200, 36 }, keys = "mm.bin",
  default = { point = "TOPRIGHT", x = -20, y = -250 } })
function Bin.BuildBar()
  if bar then return bar end
  bar = PUI:CreateFrame("Frame", "PhoenixUI_ButtonBar", UIParent, "BackdropTemplate", OWNER)
  bar.bg = Theme:Backdrop(bar, "surface.1")
  bar:SetFrameStrata("MEDIUM")
  bar:Hide()
  Bin.bar = bar
  return bar
end
function Bin.BuildToggle()
  if toggle then return toggle end
  toggle = PUI:CreateFrame("Button", "PhoenixUI_BinButton", Minimap, nil, OWNER)
  toggle:SetSize(18, 18)
  toggle:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -2)
  toggle:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  toggle.bg = toggle:CreateTexture(nil, "BACKGROUND")
  toggle.bg:SetAllPoints()
  toggle.tex = toggle:CreateTexture(nil, "ARTWORK")
  toggle.badge = toggle:CreateFontString(nil, "OVERLAY")
  toggle.badge:SetFontObject(Media:FontObject("small"))
  toggle.badge:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", 4, -4)
  toggle:RegisterForClicks("AnyUp")
  toggle:SetScript("OnClick", function(_, button)
    if IsShiftKeyDown() or button == "RightButton" then Bin.Toggle(true); Bin.SetEditing(not Bin.editing) return end
    if s.layout == "bar" then Bin.SetBarShown(not (bar and bar:IsShown())) return end
    if s.open == "click" then Bin.Toggle() end
  end)
  toggle:SetScript("OnEnter", function(self)
    if s.open == "hover" and s.layout == "popup" then Bin.Toggle(true) end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(string.format(L["Addon buttons  %d collected"], Bin.Count()))
    GameTooltip:AddLine(L["Shift-click: edit (drag to reorder, right-click to hide or pin)"], 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Bin.toggle = toggle
  return toggle
end
function Bin.PaintToggle()
  local t = toggle
  if not t then return end
  if s.binSkin == "phoenix" then
    Theme:Paint(t.bg, "surface.1"); t.bg:Show()
    t.tex:ClearAllPoints(); t.tex:SetPoint("TOPLEFT", 3, -3); t.tex:SetPoint("BOTTOMRIGHT", -3, 3)
    t.tex:SetTexture("Interface\\AddOns\\Phoenix_UI\\Media\\Logo\\PhoenixUI_Icon_64")
  else
    t.bg:Hide()
    t.tex:ClearAllPoints(); t.tex:SetAllPoints()
    t.tex:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
  end
  local n = Bin.Count()
  t.badge:SetText(n > 0 and tostring(n) or "")
  t.badge:SetShown(s.badge and n > 0)
end

-- Order, filter, layout -------------------------------------------------------
function Bin.All()
  local out = {}
  for _, b in ipairs(Bin.buttons) do out[#out + 1] = b end
  if s.compartment then for _, e in ipairs(Bin.CompartmentEntries()) do out[#out + 1] = Bin.Proxy(e) end end
  return out
end
function Bin.Count()
  local n = 0
  for _, b in ipairs(Bin.All()) do if not listHas(s.hidden, Bin.Name(b)) then n = n + 1 end end
  return n
end
-- Sorted list: A-Z, or the saved custom order first then any new ones A-Z.
function Bin.Sorted(list)
  local rank = {}
  if s.sort == "custom" then for i, name in ipairs(s.order) do rank[name] = i end end
  table.sort(list, function(a, b)
    local na, nb = Bin.Name(a), Bin.Name(b)
    local ra, rb = rank[na] or math.huge, rank[nb] or math.huge
    if ra ~= rb then return ra < rb end
    return na:lower() < nb:lower()
  end)
  return list
end
function Bin.Visible()
  local out, q = {}, (s.search and Bin.filter or ""):lower()
  for _, b in ipairs(Bin.All()) do
    local name = Bin.Name(b)
    local hidden = listHas(s.hidden, name) and not Bin.editing
    if not hidden and (q == "" or name:lower():find(q, 1, true)) then out[#out + 1] = b end
  end
  return Bin.Sorted(out)
end

-- Grid solver: n cells, `columns` per line, growing toward `grow`. Returns the
-- TOPLEFT offsets and the container size. padX / padTop default to the popup's.
function Bin.Grid(n, columns, size, spacing, grow, padX, padTop)
  grow, padX, padTop = grow or "right", padX or 8, padTop or 30
  local step, out = size + spacing, {}
  local lines = math.max(1, math.ceil(n / columns))
  local per = math.min(math.max(n, 1), columns)
  local vertical = grow == "down" or grow == "up"
  for i = 1, n do
    local along, line = (i - 1) % columns, math.floor((i - 1) / columns)
    local col, row
    if grow == "right" then col, row = along, line
    elseif grow == "left" then col, row = per - 1 - along, line
    elseif grow == "down" then col, row = line, along
    else col, row = line, per - 1 - along end
    out[i] = { x = padX + col * step, y = -padTop - row * step }
  end
  local cols, rows = per, lines
  if vertical then cols, rows = lines, per end
  return out, 2 * padX + cols * step - spacing, padTop + 8 + rows * step - spacing
end

function Bin.Skin(b)
  local rec = Bin.original[b]
  if not rec or rawget(b, "proxy") then return end
  rec.stripped = rec.stripped or {}
  if s.skin and s.strip and b.GetRegions then
    for _, r in ipairs({ b:GetRegions() }) do
      local tex = r.GetTexture and r:GetTexture()
      if type(tex) == "string" and (tex:find("TrackingBorder", 1, true) or tex:find("UI%-Minimap%-Background") or tex:find("MiniMap-TrackingBorder", 1, true))
        and rec.stripped[r] == nil then
        rec.stripped[r] = r:GetAlpha()
        r:SetAlpha(0)
      end
      if type(tex) == "number" and (tex == 136430 or tex == 136467) and rec.stripped[r] == nil then rec.stripped[r] = r:GetAlpha(); r:SetAlpha(0) end
    end
  else
    for r, a in pairs(rec.stripped) do r:SetAlpha(a) end
    wipe(rec.stripped)
  end
  local icon = rawget(b, "icon") or rawget(b, "Icon")
  if icon and icon.AddMaskTexture then
    if not rec.mask then rec.mask = b:CreateMaskTexture(); rec.mask:SetAllPoints(icon) end
    rec.mask:SetTexture(s.shape == "round" and "Interface\\Masks\\CircleMaskScalable" or "Interface\\Buttons\\WHITE8X8")
    if s.skin and not rec.masked then icon:AddMaskTexture(rec.mask); rec.masked = icon
    elseif not s.skin and rec.masked then icon:RemoveMaskTexture(rec.mask); rec.masked = nil end
  end
end
-- Phoenix border frame behind a cell (ours; never a child of the addon's button).
function Bin.Cell(i, holder)
  local c = Bin.skins[i]
  if not c then
    c = CreateFrame("Frame", nil, holder)
    c.bg = Theme:Backdrop(c, "surface.0")
    c.edges = Theme:Outline(c, "line")
    Bin.skins[i] = c
  end
  if c:GetParent() ~= holder then c:SetParent(holder) end
  return c
end

function Bin.Overlay(i, holder)
  local o = Bin.overlays[i]
  if not o then
    o = PUI:CreateFrame("Button", nil, holder, nil, OWNER)
    o.hl = o:CreateTexture(nil, "OVERLAY")
    o.hl:SetAllPoints()
    o.hl:SetColorTexture(1, 0.48, 0.1, 0.25)
    o.mark = o:CreateFontString(nil, "OVERLAY")
    o.mark:SetFontObject(Media:FontObject("small"))
    o.mark:SetPoint("BOTTOM", 0, 1)
    o:RegisterForClicks("AnyUp")
    o:RegisterForDrag("LeftButton")
    o:SetScript("OnClick", function(self, button) if button == "RightButton" then Bin.OpenMenu(self.target) end end)
    o:SetScript("OnDragStart", function(self) Bin.dragging = Bin.Name(self.target) end)
    o:SetScript("OnEnter", function(self) if Bin.dragging then Bin.dropOn = Bin.Name(self.target) end end)
    o:SetScript("OnDragStop", function() Bin.Drop() end)
    Bin.overlays[i] = o
  end
  if o:GetParent() ~= holder then o:SetParent(holder) end
  return o
end

function Bin.Layout()
  local holder = (s.layout == "bar") and bar or flyout
  for _, b in ipairs(Bin.All()) do b:Hide() end
  for _, c in pairs(Bin.skins) do c:Hide() end
  for _, o in pairs(Bin.overlays) do o:Hide() end
  Bin.PaintToggle()
  if not holder then return end
  local vis = Bin.Visible()
  local isBar = s.layout == "bar"
  local cells, w, h = Bin.Grid(#vis, s.columns, s.size, s.spacing, s.grow, isBar and 4 or 8, isBar and 4 or 30)
  if isBar then h = h - 8 + 4 end
  for i, b in ipairs(vis) do
    if b:GetParent() ~= holder then b:SetParent(holder) end
    b:ClearAllPoints()
    b:SetSize(s.size, s.size)
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", cells[i].x, cells[i].y)
    b:SetFrameLevel((holder:GetFrameLevel() or 1) + 3)
    b:Show()
    Bin.Skin(b)
    local c = Bin.Cell(i, holder)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", holder, "TOPLEFT", cells[i].x - 1, cells[i].y + 1)
    c:SetSize(s.size + 2, s.size + 2)
    c:SetFrameLevel((holder:GetFrameLevel() or 1) + 1)
    for _, e in ipairs(c.edges) do e:SetShown(s.border) end
    c:SetShown(s.skin)
    if Bin.editing then
      local o = Bin.Overlay(i, holder)
      o.target = b
      o:ClearAllPoints()
      o:SetAllPoints(b)
      o:SetFrameLevel((holder:GetFrameLevel() or 1) + 6)
      local name = Bin.Name(b)
      o.mark:SetText(listHas(s.hidden, name) and L["hidden"] or "")
      o:Show()
    end
  end
  if holder == flyout then
    flyout:SetSize(math.max(w, 200), h)
    flyout.title:SetText(string.format(L["Addon buttons  %d collected"], Bin.Count()))
    flyout.search:SetShown(s.search)
    flyout.edit.text:SetText(Bin.editing and L["Done"] or L["Edit"])
  else
    bar:SetSize(math.max(w, s.size + 8), math.max(h, s.size + 8))
    Bin.PlaceBar()
  end
end

-- Popup: anchored beside the bin button on the side the grid grows toward.
local POPUP = { right = { "TOPLEFT", "TOPRIGHT", 6, 0 }, left = { "TOPRIGHT", "TOPLEFT", -6, 0 },
  down = { "TOPRIGHT", "TOPLEFT", -6, 0 }, up = { "BOTTOMRIGHT", "BOTTOMLEFT", -6, 0 } }
-- Docked bar: along the minimap edge the grid grows along.
local DOCK = { right = { "TOPLEFT", "BOTTOMLEFT", 0, -4 }, left = { "TOPRIGHT", "BOTTOMRIGHT", 0, -4 },
  down = { "TOPRIGHT", "TOPLEFT", -4, 0 }, up = { "BOTTOMLEFT", "BOTTOMRIGHT", 4, 0 } }
Bin.POPUP, Bin.DOCK = POPUP, DOCK
function Bin.PlaceBar()
  if not bar then return end
  if s.dock == "minimap" then
    local a = DOCK[s.grow] or DOCK.right
    bar:ClearAllPoints()
    bar:SetPoint(a[1], Minimap, a[2], a[3], a[4])
  else
    PUI.Layout:Place(bar, "mm.binbar")
  end
end

function Bin.Toggle(show)
  if s.layout == "bar" then return Bin.SetBarShown(show ~= false) end
  local f = Bin.BuildFlyout()
  if show == nil then show = not f:IsShown() end
  if show and s.hideInCombat and InCombatLockdown() then show = false end
  if show then
    local a = s.open == "hover" and POPUP.left or (POPUP[s.grow] or POPUP.left)
    f:ClearAllPoints()
    f:SetPoint(a[1], Minimap, a[2], a[3], a[4])
    Bin.Layout()
  else
    Bin.SetEditing(false, true)
  end
  f:SetShown(show)
  Bin.WatchMouse()
end
function Bin.SetBarShown(show)
  local b = Bin.BuildBar()
  if show and s.hideInCombat and InCombatLockdown() then show = false end
  b:SetShown(show)
  if show then Bin.Layout() end
  Bin.WatchMouse()
end
function Bin.SetEditing(on, quiet)
  if Bin.editing == on then return end
  Bin.editing = on and true or false
  Bin.dragging, Bin.dropOn = nil, nil
  if not quiet then Bin.Layout() end
end

-- One Ticker job, alive only while the popup is open (auto-close) or the bar
-- fades when idle: hover keeps it, leaving starts the delay.
function Bin.Hovered()
  for _, f in ipairs({ flyout, bar, toggle }) do if f and f:IsShown() and f:IsMouseOver() then return true end end
  return Bin.editing == true and flyout ~= nil and flyout:IsShown()
end
function Bin.MouseTick(now)
  now = now or GetTime()
  local hovered = Bin.Hovered()
  if hovered then Bin.leftAt = nil else Bin.leftAt = Bin.leftAt or now end
  if s.layout == "popup" and flyout and flyout:IsShown() and s.autoClose and Bin.leftAt and now - Bin.leftAt >= s.closeDelay then
    Bin.Toggle(false)
    return
  end
  if s.layout == "bar" and bar then bar:SetAlpha(hovered and 1 or s.fade) end
end
function Bin.WatchMouse()
  local popupOpen = s.layout == "popup" and flyout and flyout:IsShown() and s.autoClose
  local barFade = s.layout == "bar" and bar and bar:IsShown() and s.fade < 1
  if popupOpen or barFade then
    Bin.leftAt = nil
    if not Ticker:IsRegistered("mm.bin.mouse") then Ticker:Register("mm.bin.mouse", 0.2, function() Bin.MouseTick() end, OWNER) end
  else
    if Ticker:IsRegistered("mm.bin.mouse") then Ticker:Unregister("mm.bin.mouse") end
    if bar then bar:SetAlpha(1) end
  end
end

-- Right-click menu actions (Edit mode) -------------------------------------
function Bin.Act(name, action)
  if action == "hide" then Schema:Set("mm.bin.hidden", (function() local l = listWithout(s.hidden, name); l[#l + 1] = name; return l end)())
  elseif action == "show" then Schema:Set("mm.bin.hidden", listWithout(s.hidden, name))
  elseif action == "pin" then local l = listWithout(s.keep, name); l[#l + 1] = name; Schema:Set("mm.bin.keep", l)
  elseif action == "never" then local l = listWithout(s.blacklist, name); l[#l + 1] = name; Schema:Set("mm.bin.blacklist", l)
  elseif action == "first" or action == "last" then Bin.Move(name, action == "first" and 1 or math.huge)
  else return false end
  return true
end
function Bin.MenuEntries(target)
  local name = Bin.Name(target)
  local out = { { text = name, title = true } }
  out[#out + 1] = listHas(s.hidden, name) and { text = L["Show in the bin"], action = "show" } or { text = L["Hide from the bin"], action = "hide" }
  if not rawget(target, "proxy") then
    out[#out + 1] = { text = L["Pin to the minimap"], action = "pin" }
    out[#out + 1] = { text = L["Never collect"], action = "never" }
  end
  out[#out + 1] = { text = L["Move first"], action = "first" }
  out[#out + 1] = { text = L["Move last"], action = "last" }
  return out
end
function Bin.OpenMenu(target)
  local MU = rawget(_G, "MenuUtil")
  if not (target and MU and MU.CreateContextMenu) then return false end
  local name = Bin.Name(target)
  MU.CreateContextMenu(target, function(_, root)
    for _, e in ipairs(Bin.MenuEntries(target)) do
      if e.title then root:CreateTitle(e.text) else root:CreateButton(e.text, function() Bin.Act(name, e.action) end) end
    end
  end)
  return true
end

-- Custom order: Move(name, index) saves the full order and switches to it.
function Bin.Move(name, index)
  local names = {}
  for _, b in ipairs(Bin.Sorted(Bin.All())) do names[#names + 1] = Bin.Name(b) end
  names = listWithout(names, name)
  index = math.max(1, math.min(index, #names + 1))
  table.insert(names, index, name)
  if s.sort ~= "custom" then Schema:Set("mm.bin.sort", "custom") end
  Schema:Set("mm.bin.order", names)
  return names
end
function Bin.Drop()
  local from, to = Bin.dragging, Bin.dropOn
  Bin.dragging, Bin.dropOn = nil, nil
  if not (from and to) or from == to then return false end
  local idx
  for i, b in ipairs(Bin.Sorted(Bin.All())) do if Bin.Name(b) == to then idx = i end end
  Bin.Move(from, idx or math.huge)
  return true
end

-- Collect / release -----------------------------------------------------------
local function release(b)
  local o = Bin.original[b]
  if not o then return end
  if o.stripped then for r, a in pairs(o.stripped) do r:SetAlpha(a) end end
  if o.masked then o.masked:RemoveMaskTexture(o.mask) end
  b:SetParent(o.parent)
  b:ClearAllPoints()
  for _, p in ipairs(o.points) do b:SetPoint(unpack(p)) end
  if o.size then b:SetSize(o.size[1], o.size[2]) end
  if o.level then b:SetFrameLevel(o.level) end
  b:SetShown(o.shown)
  Bin.original[b] = nil
end
Bin.Release = release

function Bin.Collect()
  CQ.Defer("mm.bin", function()
    local on = MM.active and s.enabled
    for i = #Bin.buttons, 1, -1 do
      local b = Bin.buttons[i]
      local name = Bin.Label(b)
      if not on or listHas(s.blacklist, name) or listHas(s.keep, name) then release(b); table.remove(Bin.buttons, i) end
    end
    for _, p in pairs(Bin.proxies) do p:Hide() end
    local t = Bin.BuildToggle()
    t:SetShown(on)
    if not on then
      if flyout then flyout:Hide() end
      if bar then bar:Hide() end
      Bin.SetEditing(false, true)
      Bin.WatchMouse()
      if Ticker:IsRegistered("mm.bin.scan") then Ticker:Unregister("mm.bin.scan") end
      return
    end
    local holder = Bin.Holder()
    if s.layout == "bar" then if flyout then flyout:Hide() end else if bar then bar:Hide() end end
    for _, b in ipairs(Bin.Scan()) do
      local name = Bin.Label(b)
      if not Bin.original[b] and not listHas(s.blacklist, name) and not listHas(s.keep, name) then
        local points = {}
        for i = 1, b:GetNumPoints() do points[i] = { b:GetPoint(i) } end
        local w, h = b:GetWidth(), b:GetHeight()
        Bin.original[b] = { parent = b:GetParent(), points = points, shown = b:IsShown(), size = (w > 0 and h > 0) and { w, h } or nil,
          level = b.GetFrameLevel and b:GetFrameLevel() or nil }
        b:SetParent(holder)
        Bin.buttons[#Bin.buttons + 1] = b
      end
    end
    if s.layout == "bar" and not (s.hideInCombat and InCombatLockdown()) then bar:Show() end
    Bin.Layout()
    Bin.WatchMouse()
  end)
end

-- Late buttons: a scan every SCAN_EVERY s for SCAN_FOR s after the bin turns on.
function Bin.StartScanJob(now)
  Bin.scanUntil = (now or GetTime()) + Bin.SCAN_FOR
  if Ticker:IsRegistered("mm.bin.scan") then return end
  Ticker:Register("mm.bin.scan", Bin.SCAN_EVERY, function() Bin.ScanTick() end, OWNER)
end
function Bin.ScanTick(now)
  if (now or GetTime()) >= (Bin.scanUntil or 0) or not (MM.active and s.enabled) then Ticker:Unregister("mm.bin.scan") return end
  for _, b in ipairs(Bin.Scan()) do
    local name = Bin.Label(b)
    if not Bin.original[b] and not listHas(s.blacklist, name) and not listHas(s.keep, name) then Bin.Collect() return end
  end
end

local events = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
Bin.events = events
events:SetScript("OnEvent", function(_, event)
  if not (MM.active and s.enabled) then return end
  if event == "ADDON_LOADED" then Bin.Collect()
  elseif event == "PLAYER_REGEN_DISABLED" and s.hideInCombat then
    local wasOpen = flyout and flyout:IsShown()
    if flyout then flyout:Hide() end
    if bar then bar:Hide() end
    CQ.Defer("mm.bin.combat", function()
      if not (MM.active and s.enabled) then return end
      if s.layout == "bar" then Bin.SetBarShown(true) elseif wasOpen then Bin.Toggle(true) end
    end)
  end
end)
function Bin.Watch(on)
  if on then
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    Bin.StartScanJob()
  else
    events:UnregisterAllEvents()
  end
end

PUI.Kernel:On("MINIMAP_APPLIED", function() Bin.Watch(MM.active and s.enabled); Bin.Collect() end)

-- Settings --------------------------------------------------------------------
local schema = {}
Bin.schema = schema
local LAYOUT_KEYS = { layout = true, dock = true, grow = true }
local function key(k, field, def)
  def.owner = OWNER
  def.apply = function(v)
    s[field] = v
    if LAYOUT_KEYS[field] then if flyout then flyout:Hide() end if bar then bar:Hide() end end
    if MM.active then Bin.Watch(s.enabled); Bin.Collect() end
  end
  def.searchTags = { "minimap", "buttons", "bin", "libdbicon", "addon", "icons", "collector" }
  schema[k] = def
end
-- Simple
key("mm.bin.enabled", "enabled", { type = "toggle", default = true, label = "Collect addon buttons",
  tooltip = "Gathers every addon's minimap button (LibDBIcon and the rest, even ones made late) into one bin; turning it off puts every button back exactly where it was.", mode = "simple" })
key("mm.bin.layout", "layout", { type = "select", default = "popup", choices = { "popup", "bar" },
  choiceLabels = { popup = "Popup grid from the bin button", bar = "Docked bar" }, label = "Bin layout",
  tooltip = "A popup grid that opens from the bin button, or a bar that is always shown along the minimap or wherever you move it.", mode = "simple" })
key("mm.bin.open", "open", { type = "select", default = "click", choices = { "click", "hover" },
  choiceLabels = { click = "Click the bin button", hover = "Hover the bin button" }, label = "Open the bin by",
  tooltip = "How the popup bin opens.", mode = "simple" })
key("mm.bin.sort", "sort", { type = "select", default = "az", choices = { "az", "custom" },
  choiceLabels = { az = "A-Z", custom = "My order (drag in Edit mode)" }, label = "Button order",
  tooltip = "Alphabetical, or the order you drag them into (Shift-click the bin button to edit).", mode = "simple" })
key("mm.bin.compartment", "compartment", { type = "toggle", default = false, label = "Include addon compartment entries",
  tooltip = "Also shows the addons listed in Blizzard's addon compartment as buttons in the bin.", mode = "simple" })
key("mm.bin.skin", "skin", { type = "toggle", default = true, label = "Skin the buttons",
  tooltip = "Draws each button on a Phoenix tile with an icon mask; turn off to keep each addon's own look.", mode = "simple" })
key("mm.bin.hideInCombat", "hideInCombat", { type = "toggle", default = true, label = "Hide the bin in combat",
  tooltip = "The popup closes and the bar hides when combat starts; the bar comes back after combat.", mode = "simple" })
-- Advanced
key("mm.bin.dock", "dock", { type = "select", default = "minimap", choices = { "minimap", "free" },
  choiceLabels = { minimap = "Along the minimap edge", free = "Anywhere (Studio mover)" }, label = "Bar position",
  tooltip = "Docks the bar on the minimap edge the bar grows along, or lets you place it with the Studio mover.", mode = "advanced" })
key("mm.bin.grow", "grow", { type = "select", default = "right", choices = { "right", "left", "down", "up" },
  choiceLabels = { right = "Right", left = "Left", down = "Down", up = "Up" }, label = "Grow direction",
  tooltip = "Which way buttons fill a line; the popup opens and the bar docks on that side.", mode = "advanced" })
key("mm.bin.columns", "columns", { type = "range", default = 6, min = 1, max = 24, step = 1, label = "Bin columns",
  tooltip = "Buttons per line before a new line starts.", mode = "advanced" })
key("mm.bin.size", "size", { type = "range", default = 28, min = 16, max = 44, step = 1, label = "Bin button size",
  tooltip = "Size of each button in the bin.", mode = "advanced" })
key("mm.bin.spacing", "spacing", { type = "range", default = 4, min = 0, max = 12, step = 1, label = "Bin spacing",
  tooltip = "Gap between buttons in the bin.", mode = "advanced" })
key("mm.bin.shape", "shape", { type = "select", default = "square", choices = { "square", "round" },
  choiceLabels = { square = "Square", round = "Round" }, label = "Icon shape", tooltip = "Mask applied to each skinned button's icon.", mode = "advanced" })
key("mm.bin.border", "border", { type = "toggle", default = true, label = "Button borders", tooltip = "A 1 px theme border around each skinned button.", mode = "advanced" })
key("mm.bin.strip", "strip", { type = "toggle", default = true, label = "Strip the round button ring",
  tooltip = "Hides the gold ring and dark disc minimap buttons draw; given back when skinning is off.", mode = "advanced" })
key("mm.bin.badge", "badge", { type = "toggle", default = true, label = "Count badge on the bin button", tooltip = "How many buttons the bin holds.", mode = "advanced" })
key("mm.bin.binSkin", "binSkin", { type = "select", default = "phoenix", choices = { "phoenix", "blizzard" },
  choiceLabels = { phoenix = "Phoenix", blizzard = "Blizzard plus" }, label = "Bin button look", tooltip = "The look of the button on the minimap that opens the bin.", mode = "advanced" })
key("mm.bin.search", "search", { type = "toggle", default = true, label = "Search box", tooltip = "A search box in the popup that narrows the buttons by name.", mode = "advanced" })
key("mm.bin.autoClose", "autoClose", { type = "toggle", default = true, label = "Close when the mouse leaves", tooltip = "The popup closes after the delay below once the mouse leaves it.", mode = "advanced" })
key("mm.bin.closeDelay", "closeDelay", { type = "range", default = 1, min = 0, max = 5, step = 0.25, label = "Close delay", tooltip = "Seconds before the popup closes after the mouse leaves.", mode = "advanced" })
key("mm.bin.fade", "fade", { type = "range", default = 1, min = 0, max = 1, step = 0.05, label = "Bar opacity when idle",
  tooltip = "The docked bar fades to this while the mouse is away; 1 never fades.", mode = "advanced" })
key("mm.bin.hidden", "hidden", { type = "list", default = {}, label = "Hidden from the bin",
  tooltip = "Collected but not shown (right-click a button in Edit mode to hide or show it).", mode = "advanced" })
key("mm.bin.order", "order", { type = "list", default = {}, label = "Saved button order", tooltip = "Your drag order (Edit mode).", mode = "advanced" })
key("mm.bin.blacklist", "blacklist", { type = "list", default = {}, label = "Never collect",
  tooltip = "Buttons listed here are left alone exactly where their addon put them.", mode = "advanced" })
key("mm.bin.keep", "keep", { type = "list", default = {}, label = "Always on the minimap",
  tooltip = "Buttons listed here stay on the minimap instead of going into the bin (Pin in the right-click menu).", mode = "advanced" })
for k, def in pairs(schema) do PUI.Schema:Register(k, def); def.apply(Schema:Get(k)) end
