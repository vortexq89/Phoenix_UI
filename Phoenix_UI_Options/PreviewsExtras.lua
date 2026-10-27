local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for the deferred batch A settings (docs/DEFERRED.md). Each
-- extension draws on top of the page's own preview with sample values and the
-- module's real paint functions. Display only: no unit reads, no protected
-- frames. Every extension's widgets are hidden when the page changes.
local Options, Schema = PUI.Options, PUI.Schema
local Kit = Options.Kit
local Previews = Options.Previews
local PX = {}
Options.PreviewsExtras = PX

local extras = setmetatable({}, { __mode = "k" }) -- card -> { widgets }
local function bag(card) extras[card] = extras[card] or {}; return extras[card] end
local function hideExtras(card) for _, w in pairs(bag(card)) do w:Hide() end end
PX.Bag = bag

local baseUpdate = Previews.Update
function Previews.Update(owner, card, key)
  hideExtras(card)
  return baseUpdate(owner, card, key)
end
local function extend(owner, fn)
  local base = Previews[owner]
  if type(base) ~= "function" then return end
  Previews[owner] = function(card, tab)
    hideExtras(card)
    base(card, tab)
    fn(card, tab)
  end
end
PX.extend = extend

-- A small text line owned by the extension bag.
function PX.Line(card, id, role)
  local b = bag(card)
  local fs = b[id]
  if not fs then
    fs = Kit.Text(card, role or "small", "text.secondary")
    b[id] = fs
  end
  fs:Show()
  return fs
end

-- Nameplates: compact totem, interrupted-by, NPC title, hover, purge border,
-- and the drag-slot editor (drag a chip onto a side of the sample plate).
extend("Nameplates", function(card)
  local NP = PUI.Nameplates
  local X = NP and NP.Extras
  local st = Previews.State(card)
  if not (X and st.np and st.np[1]) then return end
  local S = NP.settings
  local f1, f2, f3, f4 = st.np[1], st.np[2], st.np[3], st.np[4]
  X.Ensure(f1); X.Ensure(f2); X.Ensure(f3); X.Ensure(f4)
  -- sample 4 is a totem: compact when the setting says so
  f4.kind = "totem"
  f4:SetScale(X.CompactFactor(f4))
  if X.CompactFactor(f4) < 1 and S.compact.hideName then f4.name:Hide() end
  f1.kind, f2.kind, f3.kind = nil, nil, nil
  X.ApplySlots(f1); X.ApplySlots(f2)
  -- interrupted by (sample 2), NPC title (sample 1), quest text when on
  f2.interruptText:SetShown(S.interrupt.enabled)
  f2.interruptText:SetText("Interrupted by Kael")
  if S.interrupt.classColor then f2.interruptText:SetTextColor(0.25, 0.78, 0.92) else f2.interruptText:SetTextColor(1, 1, 1) end
  if S.npc.quest then
    f1.npcText:SetText("Void Acolytes slain: 3/8")
    f1.npcText:SetTextColor(S.npc.questColor.r, S.npc.questColor.g, S.npc.questColor.b)
    f1.npcText:Show()
  elseif S.npc.subtitle then
    f1.npcText:SetText("<Herald of the Void>")
    f1.npcText:SetTextColor(0.75, 0.75, 0.75)
    f1.npcText:Show()
  else
    f1.npcText:Hide()
  end
  -- hover on sample 1, range fade on sample 3 (when on)
  f1.hoverTex:SetColorTexture(S.hover.color.r, S.hover.color.g, S.hover.color.b, 1)
  f1.hoverTex:SetAlpha(S.hover.enabled and S.hover.alpha or 0)
  if not f3.nameOnly then f3.health:SetAlpha(S.range.enabled and S.range.alpha or 1) end
  local note = PX.Line(card, "npNote")
  note:ClearAllPoints()
  note:SetPoint("TOPLEFT", st.npHolder, "BOTTOMLEFT", 0, -6)
  note:SetWidth(384)
  local parts = {}
  if S.auraGlow.important then parts[#parts + 1] = "important auras bordered" end
  if S.auraGlow.pandemic then parts[#parts + 1] = "pandemic timers coloured" end
  if S.auraGlow.purge then parts[#parts + 1] = "purgeable buffs bordered" end
  if S.click.friendlyThrough then parts[#parts + 1] = "friendly plates click-through" end
  note:SetText(#parts > 0 and ("Also on: " .. table.concat(parts, ", ") .. ".") or "Aura borders are off.")
  -- drag-slot editor
  local b = bag(card)
  local tray = b.npTray
  if not tray then
    tray = CreateFrame("Frame", nil, card)
    tray:SetSize(384, 24)
    tray.chips = {}
    for i, el in ipairs(X.SLOT_ELEMENTS) do
      local chip = Kit.Button(tray, X.SLOT_LABELS[el], 62, nil, "ghost")
      chip.element = el
      chip:SetMovable(true)
      chip:RegisterForDrag("LeftButton")
      chip:SetScript("OnDragStart", function(self) self:StartMoving() end)
      chip:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local zone = PX.DropZone(self, f1.health)
        if zone then Schema:Set("np.slots." .. self.element, zone) end
        PX.PlaceChips(tray)
      end)
      tray.chips[i] = chip
    end
    b.npTray = tray
  end
  tray:ClearAllPoints()
  tray:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -8)
  PX.PlaceChips(tray)
  tray:Show()
end)

function PX.PlaceChips(tray)
  for i, chip in ipairs(tray.chips) do
    chip:ClearAllPoints()
    chip:SetPoint("LEFT", tray, "LEFT", (i - 1) * 64, 0)
    local zone = Schema:Get("np.slots." .. chip.element)
    chip:SetAlpha(zone == "hidden" and 0.45 or 1)
  end
end

-- Which side of the sample bar a dropped chip landed on (nil: dropped elsewhere,
-- which resets the element to its standard place; far below the card hides it).
function PX.DropZone(chip, health)
  local cx, cy = chip:GetCenter()
  local l, r, t, bt = health:GetLeft(), health:GetRight(), health:GetTop(), health:GetBottom()
  if not (cx and l and r and t and bt) then return nil end
  local margin = 40
  if cx >= l and cx <= r and cy <= t and cy >= bt then return "inside" end
  if cx >= l - margin and cx <= r + margin then
    if cy > t and cy <= t + margin then return "top" end
    if cy < bt and cy >= bt - margin then return "bottom" end
  end
  if cy >= bt - margin and cy <= t + margin then
    if cx < l and cx >= l - margin * 2 then return "left" end
    if cx > r and cx <= r + margin * 2 then return "right" end
  end
  return "default"
end
