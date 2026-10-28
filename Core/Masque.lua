local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Masque: optional Masque support. With Masque loaded, Phoenix buttons
-- join "Phoenix UI" groups (one per action bar, special bar, auto item bar
-- and the Cooldown Manager) so the skin picked in Masque applies. Without
-- Masque every call is a no-op. Each area has its own on/off setting, applied
-- live: turning one off removes its buttons from Masque.
local Masque = { groups = {}, members = {}, cfg = { ab = true, special = true, items = true, cdm = true } }
PUI.Masque = Masque
local Schema = PUI.Schema

function Masque.Lib()
  local LS = rawget(_G, "LibStub")
  if type(LS) ~= "table" or not LS.GetLibrary then return nil end
  return LS:GetLibrary("Masque", true)
end
function Masque.Available() return Masque.Lib() ~= nil end

function Masque.Group(name)
  local g = Masque.groups[name]
  if g then return g end
  local lib = Masque.Lib()
  if not lib then return nil end
  g = lib:Group("Phoenix UI", name)
  Masque.groups[name] = g
  return g
end

-- Regions Masque should skin, from Phoenix's button fields (or a Blizzard
-- Cooldown Viewer item's fields).
local function regions(b)
  local r = {}
  r.Icon = rawget(b, "icon") or rawget(b, "Icon")
  r.Cooldown = rawget(b, "cooldown") or rawget(b, "Cooldown")
  r.Count = rawget(b, "count") or nil
  r.HotKey = rawget(b, "hotkey") or nil
  return r
end

-- Add(area, groupName, button): joins or leaves the group as the area's setting says.
function Masque.Add(area, name, b)
  local on = Masque.cfg[area]
  local cur = Masque.members[b]
  if on then
    local g = Masque.Group(name)
    if not g or (cur and cur.name == name) then return cur ~= nil end
    if cur then cur.group:RemoveButton(b) end
    g:AddButton(b, regions(b))
    Masque.members[b] = { area = area, name = name, group = g }
    if rawget(b, "puiMasque") ~= nil then b.puiMasque = true end -- Phoenix buttons only, never a field on Blizzard frames
    return true
  elseif cur then
    cur.group:RemoveButton(b)
    Masque.members[b] = nil
    if rawget(b, "puiMasque") ~= nil then b.puiMasque = false end
  end
  return false
end

function Masque.Skinned(b) return Masque.members[b] ~= nil end

-- Areas re-run their own Apply on a setting change (each module registers one).
Masque.reapply = {}
function Masque.OnArea(area, fn) Masque.reapply[area] = fn end
local function changed(area)
  if not Masque.cfg[area] then
    for b, m in pairs(Masque.members) do
      if m.area == area then m.group:RemoveButton(b); Masque.members[b] = nil; if rawget(b, "puiMasque") ~= nil then b.puiMasque = false end end
    end
  end
  local fn = Masque.reapply[area]
  if fn then fn() end
end

local LABELS = { ab = "Masque: action bars", special = "Masque: stance, pet, vehicle and item bar",
  items = "Masque: auto item bars", cdm = "Masque: Cooldown Manager icons" }
local TIPS = { ab = "With Masque installed, Phoenix action bars use the skin you pick for each \"Phoenix UI: Action bar\" group in Masque.",
  special = "With Masque installed, the stance, pet, vehicle exit and item bars use their Masque groups.",
  items = "With Masque installed, each auto item bar uses its own Masque group.",
  cdm = "With Masque installed, Cooldown Manager icons use the \"Phoenix UI: Cooldown Manager\" Masque group." }
for _, area in ipairs({ "ab", "special", "items", "cdm" }) do
  Schema:Register("masque." .. area, { type = "toggle", default = true, owner = "Core", page = "ActionBars",
    label = LABELS[area], tooltip = TIPS[area], mode = "advanced", searchTags = { "masque", "skin", "button" },
    apply = function(v) Masque.cfg[area] = v; changed(area) end })
end
for _, area in ipairs({ "ab", "special", "items", "cdm" }) do Schema:Def("masque." .. area).apply(Schema:Get("masque." .. area)) end
