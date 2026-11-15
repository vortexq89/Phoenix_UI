local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Right-click and dropdown menus (Blizzard_Menu, 11.0+): every context menu,
-- unit popup and dropdown list, including the damage meter's type, session
-- and settings dropdowns. Post-hooks on the menu manager's OpenMenu and
-- OpenContextMenu read the open menu afterwards and restyle it: Blizzard's
-- style background is faded, a Phoenix panel, border and theme font go on.
-- Entries keep Blizzard's own buttons, order and handlers (some unit popup
-- entries are protected): Phoenix never adds, removes or calls an entry.
local _, ns = ...
local SK = ns.SK
local C = SK.Controls
local Theme, Media = PUI.Theme, PUI.Media
local M = { menus = setmetatable({}, { __mode = "k" }), entered = setmetatable({}, { __mode = "k" }), hooked = false }
SK.Menus = M
local ID = "menus"

local function manager()
  local menu = rawget(_G, "Menu")
  return type(menu) == "table" and type(menu.GetManager) == "function" and menu.GetManager() or nil
end
M.Manager = manager

-- Skin(menu): Phoenix look on one menu frame and its entries (once per frame,
-- entries again on every open because they are pooled).
function M.Skin(menu)
  if not (menu and SK.applied[ID] and C.Usable(menu)) then return false end
  if not M.menus[menu] then
    M.menus[menu] = true
    for _, r in ipairs({ menu:GetRegions() }) do
      if r.GetObjectType and r:GetObjectType() == "Texture" then C.Fade(ID, r) end
    end
    local panel = C.Over(ID, menu, "panel", "BACKGROUND", "Panel_EmberGlass", -8)
    panel:ClearAllPoints(); panel:SetAllPoints()
    local edge = C.Over(ID, menu, "edge", "BORDER", "Border_R10_1px")
    edge:ClearAllPoints(); edge:SetAllPoints()
    Theme:Paint(edge, "accent", 0.7, "vertex")
    C.Own(ID, function() M.menus[menu] = nil end)
  end
  local n = 0
  for _, child in ipairs({ menu:GetChildren() }) do
    if not M.entered[child] and child.HookScript then
      M.entered[child] = true
      child:HookScript("OnEnter", function() if SK.applied[ID] then securecallfunction(M.Sub, menu) end end)
    end
    local fs = C.K(child, "fontString")
    if fs then SK.Font(ID, fs, "body"); n = n + 1 end
    local hl = C.K(child, "highlight")
    if hl and not C.done[hl] then C.done[hl] = ID; C.Tint(ID, hl, "accent", 0.35) end
  end
  return n
end

-- Sub(menu): the submenu a hovered entry opened gets the same look (and its
-- own entries hook further levels the same way).
function M.Sub(menu)
  local sub = (menu.GetSubmenu and menu:GetSubmenu()) or C.K(menu, "submenu")
  if sub and sub ~= menu then return M.Skin(sub) end
  return false
end

local function afterOpen()
  local mgr = manager()
  local menu = mgr and mgr.GetOpenMenu and mgr:GetOpenMenu()
  if menu then M.Skin(menu) end
end
M.AfterOpen = afterOpen

function M.Hook()
  if M.hooked then return true end
  local mgr = manager()
  if not mgr then return false end
  for _, name in ipairs({ "OpenMenu", "OpenContextMenu" }) do
    if type(mgr[name]) == "function" then hooksecurefunc(mgr, name, afterOpen) end
  end
  M.hooked = true
  return true
end

SK.Register(ID, { label = "Right-click and dropdown menus", global = true, parts = {}, extra = function() M.Hook() end })
