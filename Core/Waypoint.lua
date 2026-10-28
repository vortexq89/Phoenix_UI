local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Waypoint: a free waypoint arrow for the game's user waypoint (set by
-- /way from the Quest Tracker, a map pin click or any addon). Phoenix's own
-- design. The arrow turns toward the point and shows the distance in yards
-- (plain map math from C_Map); it updates on one Ticker entry only while a
-- waypoint exists, and clears the waypoint on arrival. Positions the game
-- hands over as secret values (or none, in instances) are never used for
-- maths: the arrow dims and shows "?". Right-click the arrow to clear.
-- Also: the spell queue window setting (SpellQueueWindow CVar).
local Schema, Layout, Secret = PUI.Schema, PUI.Layout, PUI.Secret
local W = { cfg = { on = true, size = 48, arrive = 10 } }
PUI.Waypoint = W

-- The current user waypoint as { map, x, y } (0..1), or nil.
function W.Point()
  if not C_Map.HasUserWaypoint() then return nil end
  local p = C_Map.GetUserWaypoint()
  if type(p) ~= "table" then return nil end
  local map = p.uiMapID
  local x, y
  if p.position and p.position.GetXY then x, y = p.position:GetXY() end
  if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
  return { map = map, x = x, y = y }
end

-- Distance (yards) and bearing (radians, counter-clockwise from north) to the
-- point, or nil when the player's map position is unknown or secret.
function W.Vector(pt)
  local map = C_Map.GetBestMapForUnit("player")
  if Secret.IsSecret(map) or map ~= pt.map then return nil end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local px, py = pos:GetXY()
  if Secret.IsSecret(px) or Secret.IsSecret(py) or type(px) ~= "number" or type(py) ~= "number" then return nil end
  local w, h = C_Map.GetMapWorldSize(map)
  if type(w) ~= "number" or w <= 0 then return nil end
  local dx, dy = (pt.x - px) * w, (pt.y - py) * h
  return math.sqrt(dx * dx + dy * dy), math.atan2(-dx, -dy)
end

local function frame()
  local f = W.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_WaypointArrow", UIParent, nil, "Core")
  f.arrow = f:CreateTexture(nil, "ARTWORK")
  f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.arrow:SetPoint("CENTER")
  f.dist = f:CreateFontString(nil, "OVERLAY")
  f.dist:SetFontObject(PUI.Media:FontObject("number"))
  f.dist:SetPoint("TOP", f, "BOTTOM", 0, -2)
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then C_Map.ClearUserWaypoint(); W.Sync() end end)
  f:Hide()
  W.frame = f
  return f
end

function W.Look()
  local f = frame()
  local s = W.cfg.size
  f:SetSize(s, s)
  f.arrow:SetSize(s, s)
  Layout:Place(f, "way.arrow")
end

function W.Update()
  local f, pt = W.frame, W.point
  if not (f and pt) then return end
  local dist, bearing = W.Vector(pt)
  if not dist then
    f.arrow:SetAlpha(0.3)
    f.dist:SetText("?")
    return
  end
  if dist <= W.cfg.arrive then
    C_Map.ClearUserWaypoint()
    W.Sync()
    return
  end
  f.arrow:SetAlpha(1)
  local facing = GetPlayerFacing()
  if type(facing) == "number" and not Secret.IsSecret(facing) then f.arrow:SetRotation(bearing - facing) end
  f.dist:SetText(string.format("%d yd", math.floor(dist + 0.5)))
end

-- Shows or hides the arrow for the current user waypoint (event-driven).
function W.Sync()
  W.point = W.cfg.on and W.Point() or nil
  local on = PUI.Ticker:IsRegistered("way.arrow")
  if W.point then
    W.Look()
    W.frame:Show()
    if not on then PUI.Ticker:Register("way.arrow", 0.05, W.Update, "Core") end
    W.Update()
  else
    if W.frame then W.frame:Hide() end
    if on then PUI.Ticker:Unregister("way.arrow") end
  end
end

local ev = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
ev:RegisterEvent("USER_WAYPOINT_UPDATED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() W.Sync() end)

local function key(name, def, field)
  def.owner = "Core"
  def.searchTags = { "waypoint", "arrow", "way", "tomtom", "coordinates" }
  def.apply = function(v) W.cfg[field] = v; if W.frame or field == "on" then W.Sync() end end
  Schema:Register("way." .. name, def)
end
key("enabled", { type = "toggle", default = true, label = "Waypoint arrow",
  tooltip = "An arrow with the distance toward your map waypoint (/way, or a pin placed on the map). Right-click it to clear the waypoint.", mode = "simple" }, "on")
key("size", { type = "range", default = 48, min = 24, max = 96, step = 2, label = "Waypoint arrow size",
  tooltip = "Size of the waypoint arrow.", mode = "simple" }, "size")
key("arrive", { type = "range", default = 10, min = 3, max = 50, step = 1, label = "Waypoint arrival distance",
  tooltip = "The waypoint clears itself when you are this many yards from it.", mode = "advanced" }, "arrive")
Layout:RegisterElement("way.arrow", { label = "Waypoint arrow", owner = "Core", size = { 48, 48 }, default = { point = "TOP", x = 0, y = -120 } })

-- Spell queue window (SpellQueueWindow CVar) through the CVar ledger, out of combat.
Schema:Register("core.spellQueue", { type = "range", default = 0, min = 0, max = 400, step = 10, owner = "Core",
  label = "Spell queue window", tooltip = "How early (milliseconds) a spell can be queued before the current cast or global cooldown ends. 0 leaves the game's own value; Phoenix restores your old value when set back to 0.",
  mode = "advanced", searchTags = { "spell queue", "latency", "cvar", "SpellQueueWindow" },
  apply = function(v)
    if not (PUI.DB and PUI.DB.sv) then return end -- saved settings not loaded yet; applied again once they are
    if v == 0 and not W.queueTouched then return end
    W.queueTouched = true
    PUI.CombatQueue.Defer("core.spellQueue", function()
      if v > 0 then PUI.CVars:Set("Core", "SpellQueueWindow", tostring(v)) else PUI.CVars:Restore("Core", "SpellQueueWindow") end
    end)
  end })
