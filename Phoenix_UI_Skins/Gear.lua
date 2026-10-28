local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Per-window gear (skins v2 mockups): a cog in the title bar of every skinned
-- window, left of Blizzard's close button. It opens one inline flyout with
-- the window's Phoenix extras as live settings (the same schema keys as the
-- Skins page) and a "Full settings" link to /pui -> Skins. Phoenix-owned
-- frames only: the cog is a Phoenix child of the window, never a Blizzard
-- button, and it is not made on protected windows.
local _, ns = ...
local SK = ns.SK
local Schema, Theme, Media = PUI.Schema, PUI.Theme, PUI.Media
local OWNER = "Skins"
local G = { cogs = setmetatable({}, { __mode = "k" }), rows = {} }
SK.Gear = G
local ROW_H, W = 24, 236

local function tex(name) return SK.Controls.Tex(name) end

function G.Cog(id, frame)
  local cog = G.cogs[frame]
  if not cog then
    cog = PUI:CreateFrame("Button", nil, frame, nil, OWNER)
    cog:SetSize(18, 18)
    local close = SK.Controls.K(frame, "CloseButton") or (frame:GetName() and rawget(_G, frame:GetName() .. "CloseButton"))
    if close then cog:SetPoint("RIGHT", close, "LEFT", -4, 0) else cog:SetPoint("TOPRIGHT", -30, -4) end
    cog:SetFrameLevel(frame:GetFrameLevel() + 20)
    cog.icon = cog:CreateTexture(nil, "ARTWORK")
    cog.icon:SetAllPoints()
    cog.icon:SetTexture(Media:Path("icon", "Skins/menu") or "Interface\\AddOns\\Phoenix_UI\\Media\\Logo\\PhoenixUI_Icon_64")
    Theme:Paint(cog.icon, "accent", 1, "vertex")
    cog:SetScript("OnClick", function(self) G.Toggle(self.packId, self) end)
    cog:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Phoenix: " .. (SK.packs[self.packId] and SK.packs[self.packId].label or ""))
      GameTooltip:AddLine("Window options (live). Everything is also on /pui -> Skins.", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
    G.cogs[frame] = cog
  end
  cog.packId = id
  cog:SetShown(G.Wanted())
  table.insert(SK.owned[id], function() cog:Hide(); if G.flyout and G.flyout.packId == id then G.flyout:Hide() end end)
  return cog
end

function G.Wanted() return Schema:Get("skins.gear") ~= false end

-- Flyout ---------------------------------------------------------------------------------
local function build()
  if G.flyout then return G.flyout end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_SkinsFlyout", UIParent, nil, OWNER)
  f:SetFrameStrata("DIALOG")
  f:SetWidth(W)
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  local panel = tex("Panel_EmberGlass")
  if panel then bg:SetTexture(panel) else Theme:Paint(bg, "surface.1", nil, "panel") end
  Theme:Outline(f, "accent", 0.9)
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(Media:FontObject("header"))
  f.title:SetPoint("TOPLEFT", 10, -8)
  Theme:Paint(f.title, "accent", 1, "text")
  f.link = PUI:CreateFrame("Button", nil, f, nil, OWNER)
  f.link:SetSize(W - 20, 18)
  f.link.text = f.link:CreateFontString(nil, "OVERLAY")
  f.link.text:SetFontObject(Media:FontObject("small"))
  f.link.text:SetPoint("LEFT")
  f.link.text:SetText("Full settings: /pui -> Skins >")
  Theme:Paint(f.link.text, "accent", 1, "text")
  f.link:SetScript("OnClick", function() f:Hide(); PUI.OptionsHost:OpenOptions("Skins") end)
  f:Hide()
  G.flyout = f
  return f
end

local function valueText(def, v)
  if def.type == "toggle" then return v and "On" or "Off" end
  if def.type == "select" then return (def.choiceLabels and def.choiceLabels[v]) or tostring(v) end
  return tostring(v)
end

-- Step(key): the flyout control for one setting (toggle flips, select cycles,
-- range steps); live through the schema like the Skins page.
function G.Step(key, dir)
  local def = Schema:Def(key)
  if not def then return end
  local v = Schema:Get(key)
  if def.type == "toggle" then Schema:Set(key, not v)
  elseif def.type == "select" then
    local list, idx = def.choices, 1
    for i, c in ipairs(list) do if c == v then idx = i end end
    Schema:Set(key, list[(idx - 1 + (dir or 1)) % #list + 1])
  elseif def.type == "range" then
    Schema:Set(key, math.max(def.min, math.min(def.max, v + (dir or 1) * (def.step or 1))))
  end
  if G.flyout and G.flyout:IsShown() then G.Fill(G.flyout.packId) end
end

local function row(f, i)
  local r = G.rows[i]
  if r then return r end
  r = PUI:CreateFrame("Button", nil, f, nil, OWNER)
  r:SetSize(W - 20, ROW_H)
  r:SetPoint("TOPLEFT", 10, -28 - (i - 1) * ROW_H)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.label = r:CreateFontString(nil, "OVERLAY")
  r.label:SetFontObject(Media:FontObject("small"))
  r.label:SetPoint("LEFT")
  r.label:SetWidth(W - 90)
  r.label:SetJustifyH("LEFT")
  r.value = r:CreateFontString(nil, "OVERLAY")
  r.value:SetFontObject(Media:FontObject("small"))
  r.value:SetPoint("RIGHT")
  r.line = r:CreateTexture(nil, "BACKGROUND")
  r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT"); r.line:SetHeight(1)
  r.line:SetColorTexture(1, 1, 1, 0.06)
  r:SetScript("OnClick", function(self, button) G.Step(self.key, button == "RightButton" and -1 or 1) end)
  G.rows[i] = r
  return r
end

function G.Fill(id)
  local f = build()
  local pack = SK.packs[id]
  f.packId = id
  f.title:SetText("PHOENIX - " .. ((pack and pack.label) or id):upper())
  local keys = (pack and pack.extras) or {}
  local n = 0
  for _, key in ipairs(keys) do
    local def = Schema:Def(key)
    if def then
      n = n + 1
      local r = row(f, n)
      r.key = key
      r.label:SetText(def.label)
      r.value:SetText(valueText(def, Schema:Get(key)))
      if def.type == "toggle" and Schema:Get(key) then Theme:Paint(r.value, "accent", 1, "text") else Theme:Paint(r.value, "text.secondary", 1, "text") end
      r:Show()
    end
  end
  for i = n + 1, #G.rows do G.rows[i]:Hide() end
  f.link:ClearAllPoints()
  f.link:SetPoint("TOPLEFT", 10, -32 - n * ROW_H)
  f:SetHeight(60 + n * ROW_H)
  return n
end

function G.Toggle(id, anchor)
  local f = build()
  if f:IsShown() and f.packId == id then f:Hide() return false end
  G.Fill(id)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT", 4, -2)
  f:Show()
  return true
end

SK.primitives.gear = function(id, frame)
  local pack = SK.packs[id]
  if not (pack and pack.extras and #pack.extras > 0) then return end
  if not SK.Controls.Usable(frame) then return end
  G.Cog(id, frame)
end

Schema:Register("skins.gear", {
  type = "toggle", default = true, owner = OWNER, mode = "simple", label = "Window gear button",
  tooltip = "A cog in the title bar of every skinned window opens its Phoenix options in place.",
  apply = function(on) for _, cog in pairs(G.cogs) do cog:SetShown(on and SK.applied[cog.packId] == true) end end,
})
