local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Surfaces without a window of their own (skins v2): alert toasts (loot,
-- achievement, mount, currency, world quest, renown...) and every tooltip
-- Phoenix's HUD Tooltip does not own (item references, comparison, embedded,
-- battle pet). Toasts are pooled: a post-hook on AlertFrame:AddAlertFrame
-- skins each one as Blizzard shows it. Only background-layer art is faded, so
-- icons, names and counts stay exactly as Blizzard draws them.
local _, ns = ...
local SK = ns.SK
local C = SK.Controls
local Theme = PUI.Theme
local SF = { toasts = setmetatable({}, { __mode = "k" }), hooked = false }
SK.Surfaces = SF

-- Toasts ----------------------------------------------------------------------------------
function SF.Toast(frame)
  if not (frame and SK.applied.toasts and C.Usable(frame)) then return false end
  if SF.toasts[frame] then return true end
  SF.toasts[frame] = true
  for _, r in ipairs({ frame:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" and r.GetDrawLayer and r:GetDrawLayer() == "BACKGROUND" then C.Fade("toasts", r) end
  end
  local wash = C.Over("toasts", frame, "wash", "BACKGROUND", "Toast_Wash", -8)
  wash:ClearAllPoints(); wash:SetPoint("TOPLEFT", 6, -6); wash:SetPoint("BOTTOMRIGHT", -6, 6)
  local edge = C.Over("toasts", frame, "edge", "BORDER", "Border_R10_1px")
  edge:ClearAllPoints(); edge:SetAllPoints(wash)
  Theme:Paint(edge, "accent", 0.8, "vertex")
  C.Own("toasts", function() SF.toasts[frame] = nil end)
  return true
end
local function hookToasts()
  if SF.hooked then return end
  local af = rawget(_G, "AlertFrame")
  if type(af) == "table" and type(af.AddAlertFrame) == "function" then
    hooksecurefunc(af, "AddAlertFrame", function(_, frame) SF.Toast(frame) end)
    SF.hooked = true
  end
end
SK.Register("toasts", { label = "Alert toasts", global = true, parts = {}, extra = hookToasts })

-- Tooltips ----------------------------------------------------------------------------------
SF.TOOLTIPS = { "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
  "EmbeddedItemTooltip", "BattlePetTooltip", "FloatingBattlePetTooltip", "FloatingPetBattleAbilityTooltip", "PetJournalPrimaryAbilityTooltip" }
function SF.Tooltip(id, tip)
  if not C.Usable(tip) then return false end
  C.Fade(id, C.K(tip, "NineSlice"))
  local bg = C.Over(id, tip, "panel", "BACKGROUND", "Panel_EmberGlass", -8)
  bg:ClearAllPoints(); bg:SetAllPoints()
  local edge = C.Over(id, tip, "edge", "BORDER", "Border_R10_1px")
  edge:ClearAllPoints(); edge:SetAllPoints()
  Theme:Paint(edge, "line", 1, "vertex")
  local close = C.K(tip, "CloseButton")
  if close then SK.Backdrop(id, close, "surface.2") end
  return true
end
SK.Register("tooltips", { label = "Other tooltips", frames = SF.TOOLTIPS, parts = {}, extra = function(f, _, id) SF.Tooltip(id, f) end })

SK.SURFACES = {
  { "toasts", "Alert toasts", "Loot, achievement, mount, currency and other toasts in Phoenix style." },
  { "tooltips", "Other tooltips", "Item reference, comparison, embedded and battle pet tooltips (Phoenix HUD Tooltip owns the main tooltip)." },
}
