local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Tooltip, deferred batch B: other players' item level and spec (inspected
-- once, cached by GUID, never in combat or while the Inspect window is open),
-- appearance collected, upgrade track and set pieces equipped on items, and
-- the last ID sources: achievement criteria rows, artifact powers, garrison
-- follower abilities and pet battle abilities. Secret values are never
-- compared: anything not plain is simply not shown.
local _, ns = ...
local TT, IDs = ns.TT, ns.IDs
local Schema = PUI.Schema
local OWNER = "Tooltip"
local plain = TT.Plain
local s = TT.settings
s.inspect, s.transmog, s.upgrade, s.setPieces = true, true, true, true

local X = { cache = {}, pending = nil, lastAsk = 0, TTL = 300, THROTTLE = 1.5, hooked = {} }
TT.Extras = X

-- Inspect lines ------------------------------------------------------------------------
function X.InspectLine(e)
  local parts = {}
  if e.ilvl and e.ilvl > 0 then parts[#parts + 1] = string.format("Item level %.0f", e.ilvl) end
  if e.spec and e.spec ~= "" then parts[#parts + 1] = e.spec end
  return #parts > 0 and table.concat(parts, "  -  ") or nil
end
local function inspectWindowOpen()
  local f = rawget(_G, "InspectFrame")
  return f ~= nil and f:IsShown()
end
function X.Fresh(guid)
  local e = guid and X.cache[guid]
  return e and (GetTime() - e.at) < X.TTL and e or nil
end
function X.Ask(unit, guid)
  if InCombatLockdown() or inspectWindowOpen() then return false end
  local now = GetTime()
  if now - X.lastAsk < X.THROTTLE then return false end
  local ok = CanInspect(unit)
  if not (plain(ok) and ok) then return false end
  X.lastAsk = now
  X.pending = { guid = guid, unit = unit }
  X.events:RegisterEvent("INSPECT_READY")
  NotifyInspect(unit)
  return true
end
function X.OnInspectReady(guid)
  local p = X.pending
  if not (p and plain(guid) and guid == p.guid) then return end
  X.pending = nil
  X.events:UnregisterEvent("INSPECT_READY")
  local unit = p.unit
  local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
  local specID = C_SpecializationInfo.GetInspectSpecialization(unit)
  local spec = ""
  if plain(specID) and specID > 0 then
    local _, name = GetSpecializationInfoByID(specID)
    if plain(name) and name then spec = name end
  end
  local e = { ilvl = plain(ilvl) and ilvl or nil, spec = spec, at = GetTime() }
  X.cache[guid] = e
  -- still pointing at them: add the line now
  local _, shown = GameTooltip:GetUnit()
  if plain(shown) and shown and GameTooltip:IsShown() then
    local g = UnitGUID(shown)
    if plain(g) and g == guid then
      local line = X.InspectLine(e)
      if line then GameTooltip:AddLine(line, 0.85, 0.85, 0.85); GameTooltip:Show() end
    end
  end
end

local onUnit = TT.OnUnit
function TT.OnUnit(tooltip)
  onUnit(tooltip)
  if not (TT.active and s.inspect) then return end
  local _, unit = tooltip:GetUnit()
  if not plain(unit) or not unit then return end
  local isPlayer, isMe = UnitIsPlayer(unit), UnitIsUnit(unit, "player")
  if not (plain(isPlayer) and isPlayer) or not plain(isMe) or isMe then return end
  local guid = UnitGUID(unit)
  if not plain(guid) or not guid then return end
  local e = X.Fresh(guid)
  if e then
    local line = X.InspectLine(e)
    if line then tooltip:AddLine(line, 0.85, 0.85, 0.85) end
  elseif not (X.pending and X.pending.guid == guid) then
    X.Ask(unit, guid)
  end
end

-- Item lines -----------------------------------------------------------------------------
local SLOTS = 19
function X.SetPiecesEquipped(setID)
  local n = 0
  for slot = 1, SLOTS do
    local id = GetInventoryItemID("player", slot)
    if id then
      local sid = select(16, C_Item.GetItemInfo(id))
      if plain(sid) and sid == setID then n = n + 1 end
    end
  end
  return n
end
function X.ItemLines(id, link)
  local out = {}
  local ref = link or id
  if s.transmog then
    local _, sourceID = C_TransmogCollection.GetItemInfo(ref)
    if plain(sourceID) and sourceID then
      local has = C_TransmogCollection.PlayerHasTransmogByItemInfo(ref)
      if plain(has) then
        out[#out + 1] = has and { "Appearance collected", 0.4, 0.9, 0.4 } or { "Appearance not collected", 1, 0.5, 0.4 }
      end
    end
  end
  if s.upgrade and link then
    local u = C_Item.GetItemUpgradeInfo(link)
    if type(u) == "table" and plain(u.trackString) and u.trackString and plain(u.currentLevel) and plain(u.maxLevel) then
      local line = string.format("Track: %s %d/%d", u.trackString, u.currentLevel, u.maxLevel)
      if plain(u.maxItemLevel) and u.maxItemLevel and u.maxItemLevel > 0 then line = line .. string.format("  (up to %d)", u.maxItemLevel) end
      out[#out + 1] = { line, 0.95, 0.75, 0.3 }
    end
  end
  if s.setPieces then
    local setID = select(16, C_Item.GetItemInfo(ref))
    if plain(setID) and setID and setID > 0 then
      out[#out + 1] = { string.format("Set pieces equipped: %d", X.SetPiecesEquipped(setID)), 0.6, 0.8, 1 }
    end
  end
  return out
end
local onItem = TT.OnItem
function TT.OnItem(tooltip, data)
  onItem(tooltip, data)
  if not TT.active then return end
  local id = type(data) == "table" and data.id
  if not plain(id) or type(id) ~= "number" then return end
  local link = tooltip.GetItem and select(2, tooltip:GetItem())
  if not plain(link) then link = nil end
  for _, l in ipairs(X.ItemLines(id, link)) do tooltip:AddLine(l[1], l[2], l[3], l[4]) end
end

-- ID sources on custom tooltip frames (no AddLine): one ID line of our own.
local idText = setmetatable({}, { __mode = "k" })
function X.FrameID(frame, kind, id)
  if not (frame and IDs.KIND[kind]) then return false end
  local fs = idText[frame]
  local on = TT.active and IDs.enabled and IDs.settings.kinds[kind] and IDs.GateOpen() and plain(id) and type(id) == "number"
  if not on then if fs then fs:Hide() end return false end
  if not fs then
    fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(PUI.Media:FontObject("small"))
    fs:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
    idText[frame] = fs
  end
  fs:SetText(IDs.Line(kind, { id }))
  fs:Show()
  return true
end
X.idText = idText

-- Achievement criteria rows: the criteria ID on mouse-over of each text row.
local criteriaOf = setmetatable({}, { __mode = "k" })
X.criteriaOf = criteriaOf
local function criteriaEnter(row)
  local id = criteriaOf[row]
  if not (id and IDs.Active()) then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  IDs.Add(GameTooltip, "criteria", id)
  GameTooltip:Show()
end
function X.OnCriteria(objectives, achievementID)
  if not (objectives and objectives.GetCriteria and plain(achievementID)) then return end
  local text = 0
  for i = 1, GetAchievementNumCriteria(achievementID) do
    local _, ctype, _, _, _, _, flags, assetID, _, criteriaID = GetAchievementCriteriaInfo(achievementID, i)
    local meta = ctype == CRITERIA_TYPE_ACHIEVEMENT and assetID
    local bar = type(flags) == "number" and bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR
    if not meta and not bar then
      text = text + 1
      local row = objectives:GetCriteria(text)
      if row then
        if criteriaOf[row] == nil then
          row:EnableMouse(true)
          row:HookScript("OnEnter", criteriaEnter)
          row:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        criteriaOf[row] = plain(criteriaID) and criteriaID or false
      end
    end
  end
end

function X.HookLate()
  local h = X.hooked
  if not h.criteria and type(rawget(_G, "AchievementObjectives_DisplayCriteria")) == "function" then
    hooksecurefunc("AchievementObjectives_DisplayCriteria", X.OnCriteria); h.criteria = true
  end
  if not h.garrison and type(rawget(_G, "GarrisonFollowerAbilityTooltipTemplate_SetAbility")) == "function" then
    hooksecurefunc("GarrisonFollowerAbilityTooltipTemplate_SetAbility", function(frame, abilityID) X.FrameID(frame, "garrisonAbility", abilityID) end)
    h.garrison = true
  end
  if not h.pet and type(rawget(_G, "SharedPetBattleAbilityTooltip_SetAbility")) == "function" then
    hooksecurefunc("SharedPetBattleAbilityTooltip_SetAbility", function(frame, info)
      local id = type(info) == "table" and info.GetAbilityID and info:GetAbilityID()
      X.FrameID(frame, "petAbility", id)
    end)
    h.pet = true
  end
  if not h.artifact and type(GameTooltip.SetArtifactPowerByID) == "function" then
    hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(tt, powerID) IDs.Add(tt, "artifactPower", powerID) end)
    h.artifact = true
  end
end

X.events = CreateFrame("Frame")
X.events:RegisterEvent("ADDON_LOADED")
X.events:SetScript("OnEvent", function(_, event, a1)
  if event == "INSPECT_READY" then X.OnInspectReady(a1)
  elseif IDs.hooked then X.HookLate() end
end)
local idsHook = IDs.Hook
function IDs.Hook()
  idsHook()
  X.HookLate()
end

-- Settings ------------------------------------------------------------------------------
local function key(name, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v end
  def.searchTags = { "tooltip" }
  TT.schema["tt." .. name] = def
  Schema:Register("tt." .. name, def)
  def.apply(Schema:Get("tt." .. name))
end
key("lines.inspect", "inspect", { type = "toggle", default = true, label = "Item level and spec of players",
  tooltip = "Other players' item level and specialization (asked from the server once, then remembered for 5 minutes; never in combat).",
  mode = "simple" })
key("lines.transmog", "transmog", { type = "toggle", default = true, label = "Appearance collected",
  tooltip = "Gear says whether you have collected its appearance.", mode = "simple" })
key("lines.upgrade", "upgrade", { type = "toggle", default = true, label = "Upgrade track",
  tooltip = "Gear shows its upgrade track and level (for example Hero 3/6) and the item level it can reach.", mode = "advanced" })
key("lines.setPieces", "setPieces", { type = "toggle", default = true, label = "Set pieces equipped",
  tooltip = "Set items (such as tier) show how many pieces of that set you are wearing.", mode = "advanced" })
