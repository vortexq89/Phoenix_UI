local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Shared controls (skins v2): the Blizzard templates every window is built
-- from, restyled in Phoenix media and kept in Blizzard's own layout.
--   scroll bars (MinimalScrollBar, WowTrimScrollBar), dropdowns (WowStyle1 and
--   the old UIDropDownMenu), checkboxes and radios, edit and search boxes,
--   sliders (MinimalSliderWithSteppers and plain Slider), panel buttons and
--   item buttons (quality border).
-- Taint-safe: Phoenix only fades Blizzard textures (SetAlpha) and adds its own
-- textures on top; nothing is written into a Blizzard table, no method is
-- replaced, protected or forbidden frames are skipped, and every change is
-- undone exactly by the pack's revert list. Item quality colour is read from
-- Blizzard's own border texture and passed straight to Phoenix's, never compared.
local _, ns = ...
local SK = ns.SK
local Theme, Media = PUI.Theme, PUI.Media
local C = { done = setmetatable({}, { __mode = "k" }), over = setmetatable({}, { __mode = "k" }) }
SK.Controls = C
local s = { scrollBars = true, dropdowns = true, checks = true, edits = true, sliders = true, quality = true, buttons = true }
C.s = s

-- Phoenix_UI_Media skin texture by short name, or nil when the media child is off.
function C.Tex(name) return Media:Path("texture", "Skins/" .. name) end

local function K(obj, key)
  local v = obj and obj[key]
  if type(v) == "table" and v.GetObjectType then return v end
end
C.K = K

-- usable(f): skinnable at all (not forbidden, not protected).
function C.Usable(f)
  if not f or not f.GetObjectType then return false end
  if f.IsForbidden and f:IsForbidden() then return false end
  if f.IsProtected and f:IsProtected() then return false end
  return true
end

-- Revert bookkeeping ------------------------------------------------------------------
local function own(id, fn) local list = SK.owned[id]; if list then list[#list + 1] = fn end end
C.Own = own
function C.Fade(id, region)
  if not region or not region.SetAlpha or SK.alpha[region] then return end
  SK.alpha[region] = region:GetAlpha()
  region:SetAlpha(0)
  table.insert(SK.owned[id], region)
end
-- Over(id, frame, key, layer, name): a Phoenix texture on frame, shown while skinned.
function C.Over(id, frame, key, layer, texName, sub)
  local bag = C.over[frame]
  if not bag then bag = {}; C.over[frame] = bag end
  local t = bag[key]
  if not t then
    t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    bag[key] = t
  end
  local path = texName and C.Tex(texName)
  if path then t:SetTexture(path) else t:SetColorTexture(Theme:Color("surface.2")) end
  t:Show()
  own(id, function() t:Hide() end)
  return t
end

-- Tint(id, region, token): vertex colour in a theme token, original restored on revert.
function C.Tint(id, region, token, alpha)
  if not region or not region.SetVertexColor then return end
  local r, g, b, a = region:GetVertexColor()
  Theme:Paint(region, token, alpha, "vertex")
  own(id, function()
    Theme.painted[region] = nil
    if r then region:SetVertexColor(r, g, b, a) else region:SetVertexColor(1, 1, 1, 1) end
  end)
end

local function fadeKeys(id, obj, keys) for _, k in ipairs(keys) do C.Fade(id, K(obj, k)) end end

-- Controls -----------------------------------------------------------------------------
function C.ScrollBar(id, bar)
  if not s.scrollBars then return false end
  local track = K(bar, "Track")
  if not track then return false end
  local thumb = K(track, "Thumb")
  fadeKeys(id, bar, { "Background", "Backplate" })
  fadeKeys(id, track, { "Begin", "Middle", "End" })
  local rail = C.Over(id, track, "rail", "BACKGROUND")
  rail:ClearAllPoints(); rail:SetPoint("TOP"); rail:SetPoint("BOTTOM"); rail:SetWidth(3)
  rail:SetColorTexture(1, 1, 1, 0.08)
  if thumb then
    fadeKeys(id, thumb, { "Begin", "Middle", "End" })
    local t = C.Over(id, thumb, "thumb", "ARTWORK", "Scroll_Thumb")
    t:SetAllPoints()
    C.Tint(id, t, "accent", 0.9)
  end
  for _, k in ipairs({ "Back", "Forward" }) do
    local b = K(bar, k)
    if b then
      for _, r in ipairs({ b:GetRegions() }) do if r.GetObjectType and r:GetObjectType() == "Texture" then C.Fade(id, r) end end
      local a = C.Over(id, b, "arrow", "ARTWORK")
      a:ClearAllPoints(); a:SetPoint("CENTER"); a:SetSize(6, 6)
      Theme:Paint(a, "text.secondary", 0.8)
    end
  end
  return true
end

function C.Dropdown(id, dd)
  if not s.dropdowns then return false end
  local bg, arrow = K(dd, "Background"), K(dd, "Arrow")
  local legacy = K(dd, "Left") and K(dd, "Middle") and K(dd, "Right") and K(dd, "Button")
  if not (bg or legacy) then return false end
  if bg then C.Fade(id, bg) end
  if legacy then fadeKeys(id, dd, { "Left", "Middle", "Right" }) end
  local box = C.Over(id, dd, "box", "BACKGROUND", "Border_R10_1px")
  box:ClearAllPoints()
  if legacy then box:SetPoint("TOPLEFT", 16, -2); box:SetPoint("BOTTOMRIGHT", -16, 4) else box:SetAllPoints() end
  Theme:Paint(box, "line", 1, "vertex")
  local fill = C.Over(id, dd, "fill", "BACKGROUND", nil, -1)
  fill:ClearAllPoints(); fill:SetPoint("TOPLEFT", box, 1, -1); fill:SetPoint("BOTTOMRIGHT", box, -1, 1)
  Theme:Paint(fill, "bg2")
  if arrow then C.Tint(id, arrow, "accent") end
  local text = K(dd, "Text")
  if text and text.SetFontObject then SK.Font(id, text, "body") end
  return true
end

function C.Check(id, cb)
  if not s.checks then return false end
  local n, p, h, c = cb:GetNormalTexture(), cb:GetPushedTexture(), cb:GetHighlightTexture(), cb:GetCheckedTexture()
  if not (n or c) then return false end
  C.Fade(id, n); C.Fade(id, p)
  local radio = (cb.GetObjectType and cb:GetObjectType() == "CheckButton") and K(cb, "RadioTexture") ~= nil
  local box = C.Over(id, cb, "box", "BACKGROUND", radio and "Radio" or "Check_Box")
  box:ClearAllPoints(); box:SetPoint("CENTER"); box:SetSize(16, 16)
  if h then C.Tint(id, h, "accent", 0.25) end
  if c then C.Tint(id, c, "accent") end
  return true
end

local EDIT_KEYS = { "Left", "Middle", "Right", "Mid" }
function C.Edit(id, eb)
  if not s.edits then return false end
  local any = false
  for _, k in ipairs(EDIT_KEYS) do if K(eb, k) then C.Fade(id, K(eb, k)); any = true end end
  local ns9 = K(eb, "NineSlice")
  if ns9 then C.Fade(id, ns9); any = true end
  if not any then return false end
  local box = C.Over(id, eb, "box", "BACKGROUND", "Border_R10_1px")
  box:ClearAllPoints(); box:SetPoint("TOPLEFT", -5, 0); box:SetPoint("BOTTOMRIGHT", 0, 0)
  Theme:Paint(box, "line", 1, "vertex")
  local fill = C.Over(id, eb, "fill", "BACKGROUND", nil, -1)
  fill:ClearAllPoints(); fill:SetPoint("TOPLEFT", box, 1, -1); fill:SetPoint("BOTTOMRIGHT", box, -1, 1)
  Theme:Paint(fill, "bg1")
  local icon = K(eb, "searchIcon") or K(eb, "SearchIcon")
  if icon then C.Tint(id, icon, "text.secondary") end
  return true
end

function C.Slider(id, sl)
  if not s.sliders then return false end
  local inner = K(sl, "Slider") or sl
  local thumb = K(inner, "Thumb") or (inner.GetThumbTexture and inner:GetThumbTexture())
  fadeKeys(id, inner, { "Left", "Middle", "Right" })
  local rail = C.Over(id, inner, "rail", "BACKGROUND")
  rail:ClearAllPoints(); rail:SetPoint("LEFT"); rail:SetPoint("RIGHT"); rail:SetHeight(3)
  rail:SetColorTexture(1, 1, 1, 0.12)
  if thumb then C.Tint(id, thumb, "accent") end
  for _, k in ipairs({ "Back", "Forward" }) do local b = K(sl, k); if b then C.Tint(id, b.GetNormalTexture and b:GetNormalTexture(), "text.secondary") end end
  return true
end

local BUTTON_KEYS = { "Left", "Middle", "Right" }
function C.Button(id, btn)
  if not s.buttons then return false end
  if not (K(btn, "Left") and K(btn, "Middle")) then return false end
  fadeKeys(id, btn, BUTTON_KEYS)
  local t = C.Over(id, btn, "face", "BACKGROUND", "Button_Normal")
  t:ClearAllPoints(); t:SetAllPoints()
  local text = btn.GetFontString and btn:GetFontString()
  if text then SK.Font(id, text, "body") end
  return true
end

-- Item buttons: Phoenix quality frame in Blizzard's own quality colour.
function C.Item(id, btn)
  local border = K(btn, "IconBorder")
  if not (border and s.quality) then return false end
  local q = C.Over(id, btn, "quality", "OVERLAY", "Slot_QualityFrame", 2)
  q:ClearAllPoints(); q:SetAllPoints(border)
  C.Fade(id, border)
  C.SyncItem(btn)
  local slot = C.Over(id, btn, "slot", "BACKGROUND", "Slot_Empty", -2)
  slot:ClearAllPoints(); slot:SetAllPoints()
  return true
end
function C.SyncItem(btn)
  local bag, border = C.over[btn], K(btn, "IconBorder")
  local q = bag and bag.quality
  if not (q and border) then return end
  local r, g, b = border:GetVertexColor()
  if r then q:SetVertexColor(r, g, b, 1) end
  q:SetShown(SK.active and s.quality and border:IsShown())
end

-- Walk -------------------------------------------------------------------------------
-- Classify(f) -> control kind for a frame (by object type and parent keys).
function C.Classify(f)
  local kind = f.GetObjectType and f:GetObjectType()
  if kind == "CheckButton" then return "check" end
  if kind == "EditBox" then return "edit" end
  if kind == "Slider" then return "slider" end
  if K(f, "Slider") and K(f, "Back") and K(f, "Forward") then return "slider" end
  if K(f, "Track") and (K(f, "Back") or K(f, "Forward")) then return "scroll" end
  if K(f, "Arrow") and K(f, "Text") and (kind == "DropdownButton" or K(f, "Background")) then return "dropdown" end
  if K(f, "Left") and K(f, "Middle") and K(f, "Right") and K(f, "Button") then return "dropdown" end
  if K(f, "IconBorder") then return "item" end
  if kind == "Button" and K(f, "Left") and K(f, "Middle") then return "button" end
end
local APPLY = { check = C.Check, edit = C.Edit, slider = C.Slider, scroll = C.ScrollBar, dropdown = C.Dropdown, item = C.Item, button = C.Button }
C.APPLY = APPLY

-- Walk(id, frame, depth): skins every control under frame once per apply.
function C.Walk(id, frame, depth, counts)
  counts = counts or {}
  depth = depth or 0
  if depth > 8 or not frame.GetChildren then return counts end
  for _, child in ipairs({ frame:GetChildren() }) do
    if C.Usable(child) and C.done[child] ~= id then
      local kind = C.Classify(child)
      if kind and APPLY[kind](id, child) then
        C.done[child] = id
        own(id, function() C.done[child] = nil end)
        counts[kind] = (counts[kind] or 0) + 1
      end
      if kind ~= "slider" and kind ~= "dropdown" then C.Walk(id, child, depth + 1, counts) end
      local box = K(child, "ScrollTarget") and child
      if box then C.HookScrollBox(id, box) end
    end
  end
  return counts
end

-- Pooled rows: a ScrollBox re-acquires rows as it scrolls; skin them after
-- Blizzard's own Update (post-hook, once per ScrollBox, active only while skinned).
C.boxes = setmetatable({}, { __mode = "k" })
function C.HookScrollBox(id, box)
  if C.boxes[box] == nil and type(box.Update) == "function" then
    hooksecurefunc(box, "Update", function(self)
      local owner = C.boxes[self]
      if owner and SK.applied[owner] then C.Walk(owner, K(self, "ScrollTarget") or self, 0) end
    end)
  end
  C.boxes[box] = id
  own(id, function() C.boxes[box] = false end)
end

-- Item buttons everywhere: Blizzard re-colours borders on every update; follow it.
if type(rawget(_G, "SetItemButtonQuality")) == "function" then
  hooksecurefunc("SetItemButtonQuality", function(btn) if C.over[btn] then C.SyncItem(btn) end end)
end

SK.primitives.controls = function(id, frame) C.Walk(id, frame) end
