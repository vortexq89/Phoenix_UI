local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Queue-popup timer (deferred batch B): a countdown bar under Blizzard's
-- dungeon and battleground ready pop-ups. It only reads PUI.Queue (Group
-- Finder owns the countdown), so the minimap queue eye and this bar always
-- agree. One Ticker entry exists only while a pop is open.
local _, ns = ...
local SK = ns.SK
local Schema, Ticker, Theme, Media = PUI.Schema, PUI.Ticker, PUI.Theme, PUI.Media
local OWNER = "Skins"

local Q = { s = { on = true, height = 8, text = true, warn = 10, gap = 4 } }
SK.QueueTimer = Q
local s = Q.s
Q.DIALOGS = { lfg = "LFGDungeonReadyDialog", pvp = "PVPReadyDialog" }

function Q.Dialog(kind)
  local f = rawget(_G, Q.DIALOGS[kind] or "")
  return type(f) == "table" and f or nil
end

local function build()
  if Q.bar then return Q.bar end
  local b = PUI:CreateFrame("StatusBar", "PhoenixUI_QueueTimer", UIParent, nil, OWNER)
  b:SetFrameStrata("DIALOG")
  b:SetStatusBarTexture(PUI.Bars:TexturePath())
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFontObject(Media:FontObject("small"))
  b.text:SetPoint("CENTER")
  b:Hide()
  Q.bar = b
  return b
end

-- Fill (0..1), text and colour for a pop; pure so the preview uses it too.
function Q.State(left, total, warn)
  local frac = total and total > 0 and math.max(0, math.min(1, left / total)) or 0
  local r, g, b = Theme:Color("accent")
  if left <= warn then r, g, b = 0.95, 0.3, 0.25 end
  return frac, string.format("%d", math.ceil(left)), r, g, b
end

function Q.Update()
  local b = Q.bar
  local pop = PUI.Queue:Pop()
  local left = PUI.Queue:Remaining()
  if not (b and pop and left) then return Q.Refresh() end
  local frac, text, r, g, bl = Q.State(left, pop.total, s.warn)
  b:SetMinMaxValues(0, 1)
  b:SetValue(frac)
  b:SetStatusBarColor(r, g, bl)
  b.text:SetText(s.text and text or "")
end

function Q.Refresh()
  local pop = SK.active and s.on and PUI.Queue:Pop()
  local dialog = pop and Q.Dialog(pop.kind)
  if not (dialog and dialog:IsShown()) then
    if Q.bar then Q.bar:Hide() end
    if Ticker:IsRegistered("skins.queueTimer") then Ticker:Unregister("skins.queueTimer") end
    return false
  end
  local b = build()
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 8, -s.gap)
  b:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", -8, -s.gap)
  b:SetHeight(s.height)
  local r, g, bl = Theme:Color("surface.1")
  b.bg:SetColorTexture(r, g, bl, 0.9)
  b:Show()
  if not Ticker:IsRegistered("skins.queueTimer") then Ticker:Register("skins.queueTimer", 0.1, Q.Update, OWNER) end
  Q.Update()
  return true
end

PUI.Kernel:On("QUEUE_CHANGED", function() Q.Refresh() end)
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then Q.Refresh() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then Q.Refresh() end end)

local function key(k, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; Q.Refresh() end
  def.searchTags = { "queue", "pop", "countdown", "timer", "lfg", "battleground" }
  SK.schema[k] = def
  Schema:Register(k, def)
  s[field] = Schema:Get(k)
end
key("skins.queueTimer", "on", { type = "toggle", default = true, label = "Queue pop-up timer",
  tooltip = "A countdown bar under the dungeon and battleground ready pop-ups (same countdown as the minimap queue eye).", mode = "simple" })
key("skins.queueTimer.height", "height", { type = "range", default = 8, min = 4, max = 24, step = 1, label = "Queue timer height",
  tooltip = "Height of the queue pop-up countdown bar.", mode = "advanced" })
key("skins.queueTimer.text", "text", { type = "toggle", default = true, label = "Queue timer seconds",
  tooltip = "Shows the seconds left on the bar.", mode = "advanced" })
key("skins.queueTimer.warn", "warn", { type = "range", default = 10, min = 3, max = 30, step = 1, label = "Queue timer warning (seconds)",
  tooltip = "The bar turns red when this many seconds are left.", mode = "advanced" })
