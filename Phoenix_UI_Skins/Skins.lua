local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Skins engine (PUI_V2 5.11). A window pack names one or more Blizzard frames;
-- the engine applies the shell (art faded to alpha 0, Phoenix backdrop placed
-- one level below the window) and the primitives it finds by reading the
-- window's own keys: inset, close button, tabs, panel buttons and title font.
-- Nothing is written into Blizzard tables; every change is recorded in weak
-- side tables and reverted exactly when the window's toggle or the module is
-- turned off. Every pack runs through securecallfunction so one broken window never stops the
-- rest, and the work waits until out of combat. Windows from load-on-demand
-- Blizzard addons are skinned when their addon loads.
local _, ns = ...
local Schema, CQ, Theme, Media = PUI.Schema, PUI.CombatQueue, PUI.Theme, PUI.Media
local OWNER = "Skins"

local SK = { active = false, packs = {}, order = {}, applied = {}, errors = {} }
ns.SK = SK
PUI.Skins = SK
SK.alpha = setmetatable({}, { __mode = "k" })    -- region -> original alpha
SK.fonts = setmetatable({}, { __mode = "k" })    -- fontstring -> original font object
SK.backdrops = setmetatable({}, { __mode = "k" }) -- blizzard frame -> phoenix backdrop
SK.owned = {}                                   -- pack id -> list of touched objects

local SHELL_KEYS = { "NineSlice", "Bg", "Background", "TopTileStreaks", "PortraitContainer", "TitleBg", "BorderFrame" }
local INSET_KEYS = { "NineSlice", "Bg" }
local BUTTON_KEYS = { "Left", "Middle", "Right" }

local function field(obj, k)
  local v = obj[k]
  if type(v) == "table" and v.GetObjectType then return v end
end

local function fade(packId, obj)
  if not obj or SK.alpha[obj] then return end
  SK.alpha[obj] = obj:GetAlpha()
  obj:SetAlpha(0)
  table.insert(SK.owned[packId], obj)
end

local function backdrop(packId, frame, token)
  local bd = SK.backdrops[frame]
  if not bd then
    bd = PUI:CreateFrame("Frame", nil, frame, nil, OWNER)
    bd:SetAllPoints(frame)
    Theme:Backdrop(bd, token or "surface.1")
    Theme:Outline(bd, "accent", 0.6)
    SK.backdrops[frame] = bd
  end
  bd:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  bd:Show()
  table.insert(SK.owned[packId], bd)
  return bd
end

local function font(packId, fs, role)
  if not fs or SK.fonts[fs] then return end
  SK.fonts[fs] = fs:GetFontObject() or false
  fs:SetFontObject(Media:FontObject(role))
  table.insert(SK.owned[packId], fs)
end

-- Primitives -------------------------------------------------------------------
local P = {}
SK.primitives = P

function P.shell(id, frame)
  for _, k in ipairs(SHELL_KEYS) do fade(id, field(frame, k)) end
  backdrop(id, frame, "surface.1")
end

function P.inset(id, frame)
  local inset = field(frame, "Inset")
  if not inset then return end
  for _, k in ipairs(INSET_KEYS) do fade(id, field(inset, k)) end
  backdrop(id, inset, "surface.2")
end

function P.close(id, frame)
  local name = frame:GetName()
  local btn = field(frame, "CloseButton") or (name and rawget(_G, name .. "CloseButton"))
  if btn then backdrop(id, btn, "surface.2") end
end

function P.button(id, btn)
  local any = false
  for _, k in ipairs(BUTTON_KEYS) do
    local t = field(btn, k)
    if t then fade(id, t); any = true end
  end
  if any then backdrop(id, btn, "surface.2") end
end

function P.tabs(id, frame)
  local tabs = field(frame, "Tabs")
  local list = {}
  if type(tabs) == "table" and not tabs.GetObjectType then
    for _, t in ipairs(tabs) do list[#list + 1] = t end
  else
    local name = frame:GetName()
    for i = 1, 12 do
      local t = name and rawget(_G, name .. "Tab" .. i)
      if not t then break end
      list[#list + 1] = t
    end
  end
  for _, tab in ipairs(list) do
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do fade(id, field(tab, k)) end
    backdrop(id, tab, "surface.2")
  end
end

function P.buttons(id, frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    if child:GetObjectType() == "Button" and field(child, "Left") and field(child, "Middle") then P.button(id, child) end
  end
end

function P.title(id, frame)
  local container = field(frame, "TitleContainer")
  local title = container and field(container, "TitleText")
  if title then font(id, title, "header") end
end

local DEFAULT_PARTS = { "shell", "inset", "close", "tabs", "buttons", "title", "controls", "gear" }
SK.DEFAULT_PARTS = DEFAULT_PARTS
SK.Font = font
SK.Backdrop = backdrop
SK.Fade = fade

-- Post-hooks a pack asks for ({ "GlobalFunction" } or { table, "method" }):
-- installed once, they re-run the pack's update while it is applied, so
-- pooled or refreshed Blizzard content keeps the Phoenix look.
SK.hooked = {}
local function installHooks(id, pack)
  for _, h in ipairs(pack.hooks or {}) do
    local tbl, name = h[1], h[2]
    if type(tbl) == "string" then tbl, name = _G, tbl end
    if type(tbl) == "string" then tbl = rawget(_G, tbl) end
    local tag = id .. ":" .. tostring(name)
    local target = type(tbl) == "table" and (tbl == _G and rawget(_G, name) or (tbl ~= _G and tbl[name]))
    if type(target) == "function" and not SK.hooked[tag] then
      SK.hooked[tag] = true
      hooksecurefunc(tbl, name, function(...)
        if SK.applied[id] and pack.update then securecallfunction(pack.update, ...) end
      end)
    end
  end
end
SK.InstallHooks = installHooks

-- Apply / revert -----------------------------------------------------------------
function SK.Register(id, pack)
  assert(type(id) == "string" and (pack.global or type(pack.frames) == "table"), "skin needs an id and frames")
  if not SK.packs[id] then SK.order[#SK.order + 1] = id end
  pack.id = id
  SK.packs[id] = pack
end

function SK.Frames(pack)
  local list = {}
  if pack.global then return { UIParent } end
  for _, name in ipairs(pack.frames) do
    local f = rawget(_G, name)
    if type(f) == "table" and f.GetObjectType then list[#list + 1] = f end
  end
  return list
end

function SK.Apply(id)
  local pack = SK.packs[id]
  if not pack or SK.applied[id] then return SK.applied[id] end
  local frames = SK.Frames(pack)
  if #frames == 0 then return false end
  SK.owned[id] = SK.owned[id] or {}
  -- securecallfunction isolates the pack: an error goes to the error handler
  -- (and Sentinel) and the rest of the packs still run; `done` stays false.
  local done = false
  securecallfunction(function()
    for _, f in ipairs(frames) do
      for _, part in ipairs(pack.parts or DEFAULT_PARTS) do
        if part ~= "gear" or f == frames[1] then P[part](id, f) end
      end
      if pack.extra then pack.extra(f, P, id) end
    end
    installHooks(id, pack)
    done = true
  end)
  if not done then
    SK.errors[id] = true
    PUI:Log("skin.error", id)
    SK.Revert(id)
    return false
  end
  SK.applied[id] = true
  return true
end

function SK.Revert(id)
  local list = SK.owned[id] or {}
  for i = #list, 1, -1 do
    local obj = list[i]
    if type(obj) == "function" then obj()
    elseif SK.alpha[obj] then obj:SetAlpha(SK.alpha[obj]); SK.alpha[obj] = nil
    end
    if type(obj) == "table" and SK.fonts[obj] ~= nil then
      if SK.fonts[obj] then obj:SetFontObject(SK.fonts[obj]) end
      SK.fonts[obj] = nil
    end
    if type(obj) == "table" and obj.Hide and not SK.alpha[obj] and SK.IsBackdrop(obj) then obj:Hide() end
  end
  if SK.packs[id] and SK.packs[id].revert then SK.packs[id].revert() end
  SK.owned[id] = nil
  SK.applied[id] = nil
end

function SK.IsBackdrop(obj)
  for _, bd in pairs(SK.backdrops) do if bd == obj then return true end end
  return false
end

function SK.Wanted(id)
  if not SK.active then return false end
  return not Schema:Def("skins." .. id) or Schema:Get("skins." .. id) ~= false
end

function SK.Refresh()
  CQ.Defer("skins.refresh", function()
    for _, id in ipairs(SK.order) do
      if SK.Wanted(id) then SK.Apply(id) elseif SK.applied[id] then SK.Revert(id) end
    end
  end)
end

-- Public API for third-party skins (PUI_V2 10): PUI.API.RegisterSkin lives in
-- Core/API.lua so plugins can register before this child loads; packs that
-- arrive at any time are picked up here.
local Reg = PUI.APIRegistry
local function adopt(skinId)
  SK.Register("addon." .. skinId, Reg.skins[skinId])
  if SK.active then SK.Refresh() end
end
for skinId in pairs(Reg.skins) do adopt(skinId) end
Reg.Listen("skin", adopt)
