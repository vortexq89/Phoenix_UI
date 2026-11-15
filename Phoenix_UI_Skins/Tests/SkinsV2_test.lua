local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for skins v2: shared controls, the gear flyout, menus,
-- toasts, tooltips and the window extras.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local SK = ns.SK
local C = SK.Controls

local function enable(t, ...)
  local keys = { "module.Skins", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module.Skins", true)
  CQ.Drain()
end

local function region(parent, otype)
  local r = CreateFrame("Frame", nil, parent)
  rawset(r, "otype", otype)
  return r
end
-- One of each Blizzard control template, as children of CharacterFrame.
local function controls(t)
  local root = CharacterFrame
  local scroll = CreateFrame("Frame", nil, root)
  scroll.Track = CreateFrame("Frame", nil, scroll); scroll.Track.Thumb = CreateFrame("Frame", nil, scroll.Track)
  scroll.Track.Begin = region(scroll.Track, "Texture")
  scroll.Back = CreateFrame("Button", nil, scroll); scroll.Forward = CreateFrame("Button", nil, scroll)
  local edit = CreateFrame("EditBox", nil, root); rawset(edit, "otype", "EditBox")
  edit.Left, edit.Middle, edit.Right = region(edit, "Texture"), region(edit, "Texture"), region(edit, "Texture")
  local check = CreateFrame("CheckButton", nil, root); rawset(check, "otype", "CheckButton")
  local normal, checked = region(check, "Texture"), region(check, "Texture")
  rawset(check, "GetNormalTexture", function() return normal end)
  rawset(check, "GetCheckedTexture", function() return checked end)
  local dd = CreateFrame("Button", nil, root); rawset(dd, "otype", "DropdownButton")
  dd.Background, dd.Arrow, dd.Text = region(dd, "Texture"), region(dd, "Texture"), region(dd, "FontString")
  local item = CreateFrame("Button", nil, root)
  item.IconBorder = region(item, "Texture")
  rawset(item.IconBorder, "GetVertexColor", function() return 0.64, 0.21, 0.93, 1 end)
  local slider = CreateFrame("Slider", nil, root); rawset(slider, "otype", "Slider")
  local kids = { scroll, edit, check, dd, item, slider }
  rawset(root, "kids", kids)
  t:cleanup(function() rawset(root, "kids", nil) end)
  return { scroll = scroll, edit = edit, check = check, normal = normal, checked = checked, dd = dd, item = item, slider = slider }
end

Tests:Add("Skins", "shared controls: classified, skinned in Phoenix media, reverted exactly", function(t)
  if not H then return end
  local c = controls(t)
  t:eq(C.Classify(c.scroll), "scroll", "scroll bar")
  t:eq(C.Classify(c.edit), "edit", "edit box")
  t:eq(C.Classify(c.check), "check", "checkbox")
  t:eq(C.Classify(c.dd), "dropdown", "dropdown")
  t:eq(C.Classify(c.item), "item", "item button")
  t:eq(C.Classify(c.slider), "slider", "slider")
  enable(t, "skins.character")
  t:ok(SK.applied.character, "window skinned")
  t:eq(c.scroll.Track.Begin:GetAlpha(), 0, "scroll track art faded")
  t:ok(C.over[c.scroll.Track.Thumb].thumb:IsShown(), "Phoenix thumb")
  t:eq(c.edit.Left:GetAlpha(), 0, "edit box art faded")
  t:eq(c.normal:GetAlpha(), 0, "checkbox art faded")
  t:eq(c.dd.Background:GetAlpha(), 0, "dropdown art faded")
  t:eq(c.item.IconBorder:GetAlpha(), 0, "quality border faded")
  local q = C.over[c.item].quality
  t:eq(q.vertex[1], 0.64, "Phoenix frame takes Blizzard's quality colour")
  SetItemButtonQuality(c.item, 4)
  t:ok(q:IsShown(), "re-synced after Blizzard's update")
  Schema:Set("skins.character", false)
  CQ.Drain()
  t:eq(c.edit.Left:GetAlpha(), 1, "edit restored")
  t:eq(c.item.IconBorder:GetAlpha(), 1, "border restored")
  t:eq(q:IsShown(), false, "Phoenix frame hidden")
  t:eq(C.done[c.dd], nil, "walk state cleared")
end)

Tests:Add("Skins", "control families switch off live", function(t)
  if not H then return end
  local c = controls(t)
  enable(t, "skins.character", "skins.controls.edits")
  Schema:Set("skins.controls.edits", false)
  CQ.Drain()
  t:eq(c.edit.Left:GetAlpha(), 1, "edit boxes left alone")
  t:eq(c.dd.Background:GetAlpha(), 0, "others still skinned")
end)

Tests:Add("Skins", "gear cog on every skinned window opens a live flyout", function(t)
  if not H then return end
  enable(t, "skins.character")
  local cog = SK.Gear.cogs[CharacterFrame]
  t:ok(cog and cog:IsShown(), "cog in the title bar")
  t:ok(SK.Gear.Toggle("character", cog), "flyout opens")
  t:ok(SK.Gear.Fill("character") >= 1, "window switch listed")
  t:eq(SK.packs.character.extras[1], "skins.character", "first row is the window switch")
  t:eq(SK.Gear.Toggle("character", cog), false, "second click closes")
  Schema:Set("skins.gear", false)
  t:eq(cog:IsShown(), false, "gear button can be turned off")
  Schema:Set("skins.gear", true)
end)

Tests:Add("Skins", "menus: post-hook on the menu manager skins the open menu", function(t)
  if not H then return end
  local menu = CreateFrame("Frame", nil, UIParent)
  local bg = region(menu, "Texture")
  rawset(menu, "GetRegions", function() return bg end)
  local entry = CreateFrame("Button", nil, menu)
  entry.fontString = region(entry, "FontString")
  rawset(menu, "kids", { entry })
  local mgr = { GetOpenMenu = function() return menu end, OpenMenu = function() end, OpenContextMenu = function() end }
  rawset(_G, "Menu", { GetManager = function() return mgr end })
  t:cleanup(function() rawset(_G, "Menu", nil); SK.Menus.hooked = false end)
  SK.Menus.hooked = false
  enable(t, "skins.menus")
  SK.Revert("menus"); SK.Apply("menus")
  mgr:OpenMenu(UIParent, {})
  t:eq(bg:GetAlpha(), 0, "Blizzard menu background faded")
  t:ok(C.over[menu].panel:IsShown(), "Phoenix panel")
  t:ok(entry.fontString:GetFontObject() ~= nil, "entry font themed")
  SK.Revert("menus")
  t:eq(bg:GetAlpha(), 1, "reverted")
end)

