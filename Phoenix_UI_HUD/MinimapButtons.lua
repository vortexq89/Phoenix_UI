local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Minimap, deferred batch B: Phoenix-drawn tracking, calendar and mail
-- buttons in place of Blizzard's (which are faded out by alpha only, so their
-- secure parents never change). Tracking opens Blizzard's own tracking menu,
-- the calendar button carries a pending-invites badge, the mail button shows
-- only while there is new mail and lists the latest senders.
local _, ns = ...
local MM = ns.MM
local Schema, Media, Theme = PUI.Schema, PUI.Media, PUI.Theme
local OWNER = "Minimap"

local B = { buttons = {}, s = { style = "blizzard", corner = "BOTTOMRIGHT", size = 20, grow = "left", spacing = 4 } }
MM.Buttons = B
local s = B.s
B.ORDER = { "tracking", "calendar", "mail" }
B.ICONS = { tracking = "Interface\\Minimap\\Tracking\\None", calendar = "Interface\\Calendar\\UI-Calendar-Button",
  mail = "Interface\\Minimap\\Tracking\\Mailbox" }
B.LABELS = { tracking = "Tracking", calendar = "Calendar", mail = "New mail" }
local GROW = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, 1 }, down = { 0, -1 } }
B.GROW = GROW

function B.Phoenix() return MM.active and s.style == "phoenix" end

function B.OnClick(name)
  if InCombatLockdown() then return false end
  if name == "tracking" then
    local t = MM.Child(MM.Child(rawget(_G, "MinimapCluster"), "Tracking"), "Button")
    if t and type(t.OpenMenu) == "function" then t:OpenMenu(); return true end
  elseif name == "calendar" then
    local fn = MM.Resolve("ToggleCalendar")
    if type(fn) == "function" then fn(); return true end
  elseif name == "mail" then
    return true
  end
  return false
end

function B.Tooltip(name)
  if name == "mail" then
    local out = { "New mail" }
    local senders = { GetLatestThreeSenders() }
    for _, who in ipairs(senders) do if who then out[#out + 1] = "  " .. tostring(who) end end
    return out
  elseif name == "calendar" then
    local n = C_Calendar.GetNumPendingInvites()
    if n and n > 0 then return { "Calendar", string.format("%d pending invite%s", n, n == 1 and "" or "s") } end
    return { "Calendar" }
  end
  return { "Tracking", "Click to choose what the minimap tracks." }
end

local function build(name)
  local b = B.buttons[name]
  if b then return b end
  b = PUI:CreateFrame("Button", "PhoenixUI_Minimap_" .. name, Minimap, nil, OWNER)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(B.ICONS[name])
  b.badge = b:CreateFontString(nil, "OVERLAY")
  b.badge:SetFontObject(Media:FontObject("small"))
  b.badge:SetPoint("TOPRIGHT", 3, 3)
  b:RegisterForClicks("AnyUp")
  b:SetScript("OnClick", function() B.OnClick(name) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    for i, l in ipairs(B.Tooltip(name)) do
      if i == 1 then GameTooltip:SetText(l) else GameTooltip:AddLine(l, 0.8, 0.8, 0.8) end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b.name = name
  B.buttons[name] = b
  return b
end

-- Visible list in order (mail only while there is new mail).
function B.Visible()
  local out = {}
  for _, name in ipairs(B.ORDER) do
    if name ~= "mail" or HasNewMail() then out[#out + 1] = name end
  end
  return out
end

-- Offsets of the n-th button from the chosen corner (pure, for the preview too).
function B.Offset(i, size, spacing, corner, grow)
  local g = GROW[grow] or GROW.left
  local inX = corner:find("LEFT") and 4 or (corner:find("RIGHT") and -4 or 0)
  local inY = corner:find("TOP") and -4 or (corner:find("BOTTOM") and 4 or 0)
  local step = (i - 1) * (size + spacing)
  return inX + g[1] * step, inY + g[2] * step
end

function B.Refresh()
  local on = B.Phoenix()
  for _, name in ipairs(B.ORDER) do MM.replaced[name] = on or nil end
  if not on then
    for _, b in pairs(B.buttons) do b:Hide() end
    return
  end
  local ar, ag, ab = Theme:Color("accent")
  local shown = {}
  for i, name in ipairs(B.Visible()) do
    local b = build(name)
    b:SetSize(s.size, s.size)
    b:ClearAllPoints()
    local x, y = B.Offset(i, s.size, s.spacing, s.corner, s.grow)
    b:SetPoint(s.corner, Minimap, s.corner, x, y)
    b.bg:SetColorTexture(0, 0, 0, 0.55)
    if name == "calendar" then
      local n = C_Calendar.GetNumPendingInvites()
      b.badge:SetText(n and n > 0 and tostring(n) or "")
      b.badge:SetTextColor(ar, ag, ab)
    else
      b.badge:SetText("")
    end
    b:Show()
    shown[name] = true
  end
  for name, b in pairs(B.buttons) do if not shown[name] then b:Hide() end end
end

-- Minimap.Apply fades Blizzard's parts using MM.replaced, so set it first and
-- re-apply; MINIMAP_APPLIED then draws ours.
local function apply()
  for _, name in ipairs(B.ORDER) do MM.replaced[name] = B.Phoenix() or nil end
  if MM.active then MM.Apply() else B.Refresh() end
end
PUI.Kernel:On("MINIMAP_APPLIED", function() B.Refresh() end)

B.events = CreateFrame("Frame")
for _, ev in ipairs({ "UPDATE_PENDING_MAIL", "CALENDAR_UPDATE_PENDING_INVITES", "MAIL_CLOSED" }) do B.events:RegisterEvent(ev) end
B.events:SetScript("OnEvent", function() if B.Phoenix() then B.Refresh() end end)

local function key(k, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; apply() end
  def.searchTags = { "minimap", "tracking", "calendar", "mail", "buttons" }
  MM.schema[k] = def
  Schema:Register(k, def)
  s[field] = Schema:Get(k)
end
key("mm.buttons", "style", { type = "select", default = "blizzard", choices = { "blizzard", "phoenix" },
  choiceLabels = { blizzard = "Blizzard's buttons", phoenix = "Phoenix buttons" }, label = "Tracking, calendar and mail buttons",
  tooltip = "Keep Blizzard's buttons, or use Phoenix's matching set (Blizzard's are faded out, never moved).", mode = "simple" })
key("mm.buttons.corner", "corner", { type = "select", default = "BOTTOMRIGHT", choices = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
  choiceLabels = { TOPLEFT = "Top left", TOPRIGHT = "Top right", BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right" },
  label = "Buttons corner", tooltip = "Which minimap corner the Phoenix buttons start from.", mode = "advanced" })
key("mm.buttons.grow", "grow", { type = "select", default = "left", choices = { "left", "right", "up", "down" },
  choiceLabels = { left = "Left", right = "Right", up = "Up", down = "Down" }, label = "Buttons grow",
  tooltip = "Direction the row of buttons grows from the corner.", mode = "advanced" })
key("mm.buttons.size", "size", { type = "range", default = 20, min = 14, max = 32, step = 1, label = "Button size",
  tooltip = "Size of the Phoenix minimap buttons.", mode = "advanced" })
key("mm.buttons.spacing", "spacing", { type = "range", default = 4, min = 0, max = 12, step = 1, label = "Button spacing",
  tooltip = "Gap between the Phoenix minimap buttons.", mode = "advanced" })
apply()
