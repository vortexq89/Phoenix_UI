local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Skins page preview (skins v2 mockups): a sample Blizzard-layout window in
-- the current theme - title bar with the gear cog, a dropdown, a checkbox, a
-- scroll bar and quality-framed item slots - drawn with the same Phoenix_UI_Media
-- skin textures the real windows use, and each control family follows its
-- switch live. Display only: sample art, no Blizzard frame is touched.
local Options = PUI.Options
local PX, Previews = Options.PreviewsExtras, Options.Previews
local Theme, Schema = PUI.Theme, PUI.Schema
local function T(name) return PUI.Media:Path("texture", "Skins/" .. name) end
local QUALITY = { { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }

local function on(key) return not Schema:Def(key) or Schema:Get(key) ~= false end
local function tex(card, id, layer)
  local b = PX.Bag(card)
  if not b[id] then b[id] = card:CreateTexture(nil, layer or "ARTWORK") end
  b[id]:ClearAllPoints(); b[id]:Show()
  return b[id]
end

function Previews.Skins(card)
  for _, w in pairs(PX.Bag(card)) do w:Hide() end
  local skins = on("module.Skins") and Schema:Get("module.Skins")
  local win = tex(card, "skWin", "BACKGROUND")
  win:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
  win:SetSize(300, 150)
  win:SetTexture(T("Panel_EmberGlass"))
  local bar = tex(card, "skBar", "BORDER")
  bar:SetPoint("TOPLEFT", win); bar:SetPoint("TOPRIGHT", win); bar:SetHeight(22)
  bar:SetTexture(T("TitleBar_Ember"))
  local title = PX.Line(card, "skTitle", "label")
  title:ClearAllPoints(); title:SetPoint("TOP", win, "TOP", 0, -4)
  title:SetText("Character  (Blizzard layout, Phoenix theme)")
  local cog = tex(card, "skCog", "OVERLAY")
  cog:SetPoint("TOPRIGHT", win, "TOPRIGHT", -26, -3); cog:SetSize(16, 16)
  cog:SetTexture(PUI.Media:Path("icon", "Skins/menu"))
  Theme:Paint(cog, "accent", 1, "vertex")
  cog:SetShown(on("skins.gear"))
  local dd = tex(card, "skDrop")
  dd:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -34); dd:SetSize(130, 22)
  dd:SetTexture(T("Border_R10_1px"))
  Theme:Paint(dd, on("skins.controls.dropdowns") and "accent" or "line", 1, "vertex")
  local cb = tex(card, "skCheck")
  cb:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -66); cb:SetSize(16, 16)
  cb:SetTexture(T("Check_Box"))
  local mark = tex(card, "skMark", "OVERLAY")
  mark:SetAllPoints(cb)
  mark:SetTexture(T("Check_Mark"))
  Theme:Paint(mark, "accent", 1, "vertex")
  cb:SetShown(on("skins.controls.checks")); mark:SetShown(on("skins.controls.checks"))
  local thumb = tex(card, "skThumb")
  thumb:SetPoint("TOPRIGHT", win, "TOPRIGHT", -8, -32); thumb:SetSize(4, 48)
  thumb:SetTexture(T("Scroll_Thumb"))
  Theme:Paint(thumb, "accent", 0.9, "vertex")
  thumb:SetShown(on("skins.controls.scrollBars"))
  for i, c in ipairs(QUALITY) do
    local slot = tex(card, "skSlot" .. i)
    slot:SetPoint("TOPLEFT", win, "TOPLEFT", 12 + (i - 1) * 40, -94); slot:SetSize(34, 34)
    slot:SetTexture(T("Slot_QualityFrame"))
    if on("skins.controls.quality") then slot:SetVertexColor(c[1], c[2], c[3], 1) else slot:SetVertexColor(0.5, 0.5, 0.5, 1) end
  end
  local xOn, xAll = 0, 0
  local SKX = PUI.Skins
  for name, def in pairs(SKX and SKX.EXTRA_DEFS or {}) do
    xAll = xAll + 1
    if def.type ~= "toggle" or SKX.Extras.s[name] ~= false then xOn = xOn + 1 end
  end
  local n, total = 0, 0
  for _, w in ipairs(PUI.Skins and PUI.Skins.WINDOWS or {}) do total = total + 1; if on("skins." .. w[1]) then n = n + 1 end end
  PX.Gaps.Lines(card, "skins", {
    "Skins " .. (skins and "on" or "off (turn on above or in the setup wizard)"),
    n .. " of " .. total .. " windows and surfaces skinned",
    "Menus " .. (on("skins.menus") and "on" or "off") .. ", toasts " .. (on("skins.toasts") and "on" or "off") .. ", tooltips " .. (on("skins.tooltips") and "on" or "off"),
    xOn .. " of " .. xAll .. " window extras on (item level, upgrade hints, junk, have/need, vault glow...)",
    "Gear cog in title bars: " .. (on("skins.gear") and "on" or "off"),
  })
end
