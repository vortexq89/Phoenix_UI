local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Auras (plan F1, B7.1, 1.O "Aura display"): the one aura engine. It owns
-- Blizzard's CustomAuraContainer (Blizzard_AuraContainer, 12.1); Unit Frames,
-- Raid, Nameplates, Arena, player aura bars and weapon enchants only describe
-- what they want and this engine builds and updates the container.
--   Auras.Filter("HARMFUL", "PLAYER")    canonical, validated, cached filter text
--   Auras:Create(owner, parent, unit, layout) -> container handle
--   handle:Configure(groups)             add-only groups; removed ones get cap 0
--   handle:SetLayout(layout)             flow layout (anchor, growth, padding, line size, axis)
--   Auras:AddPrivateAnchor(owner, frame, unit, opts)  raid-frame option (private auras)
-- Lua never reads aura values here: the engine renders them, so secret auras
-- (C_Secrets.ShouldAurasBeSecret) need no special path except the restyle
-- queue, which waits until auras are no longer restricted.
local Auras = { handles = {}, privateAnchors = {}, restyleQueue = {}, filterCache = {} }
PUI.Auras = Auras

-- Filter tokens Blizzard accepts (AuraUtil.AuraFilters, 12.1).
local TOKENS = { HELPFUL = 1, HARMFUL = 1, PLAYER = 1, RAID = 1, CANCELABLE = 1, INCLUDE_NAME_PLATE_ONLY = 1, MAW = 1,
  EXTERNAL_DEFENSIVE = 1, CROWD_CONTROL = 1, RAID_IN_COMBAT = 1, RAID_PLAYER_DISPELLABLE = 1, BIG_DEFENSIVE = 1,
  IMPORTANT = 1, DISPELLABLE = 1 }
local NOT_NEGATABLE = { INCLUDE_NAME_PLATE_ONLY = true, MAW = true }
Auras.TOKENS = TOKENS

-- Canonical filter: upper-case, de-duplicated, sorted tokens joined by "|", so
-- equal filters share one string and the engine batches its parse. Raises on
-- an unknown token or a contradiction (HELPFUL with HARMFUL).
function Auras.Filter(...)
  local key = table.concat({ ... }, "|")
  local cached = Auras.filterCache[key]
  if cached then return cached end
  local seen, list = {}, {}
  for i = 1, select("#", ...) do
    local part = select(i, ...)
    for tok in tostring(part):gmatch("[^|%s]+") do
      tok = tok:upper()
      local bare = tok:gsub("^!", "")
      if not TOKENS[bare] then error("unknown aura filter token '" .. tok .. "'", 2) end
      if tok:sub(1, 1) == "!" and NOT_NEGATABLE[bare] then error("aura filter token '" .. bare .. "' cannot be negated", 2) end
      if not seen[tok] then seen[tok] = true; list[#list + 1] = tok end
    end
  end
  if seen.HELPFUL and seen.HARMFUL then error("aura filter cannot be both HELPFUL and HARMFUL", 2) end
  if not (seen.HELPFUL or seen.HARMFUL) then error("aura filter needs HELPFUL or HARMFUL", 2) end
  table.sort(list)
  local out = table.concat(list, "|")
  Auras.filterCache[key] = out
  return out
end

-- Engine availability: Blizzard_AuraContainer is load-on-demand on 12.1.
function Auras:Available()
  if self.available ~= nil then return self.available end
  local loaded = C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer")
  if not loaded then loaded = C_AddOns.LoadAddOn("Blizzard_AuraContainer") end
  self.available = loaded == true
  return self.available
end

Auras.LAYOUT_DEFAULT = { anchor = "TOPLEFT", growX = "RIGHT", growY = "DOWN", padding = 2, lineSize = 8, axis = "horizontal",
  size = 26 }
Auras.SORTS = { "default", "expiration", "name", "bigDefensive", "unitFrameDebuff", "important" }
local SORT_ENUM = { default = "Default", expiration = "Expiration", name = "Name", bigDefensive = "BigDefensive",
  unitFrameDebuff = "UnitFrameDebuff", important = "ImportantOnly" }

local function sortMethod(name)
  local enum = _G.AuraContainerSortMethod
  return enum and enum[SORT_ENUM[name or "default"] or "Default"]
end
local function sortDir(reverse)
  local enum = _G.AuraContainerSortDirection
  return enum and (reverse and enum.Reverse or enum.Normal)
end

local Handle = {}
Handle.__index = Handle

-- Flow layout through whichever setter generation the client has.
function Handle:SetLayout(layout)
  local l = self.layout
  for k, v in pairs(layout or {}) do l[k] = v end
  local c = self.container
  if not c then return end
  local FD = AnchorUtil and AnchorUtil.FlowDirection
  local AX = AnchorUtil and AnchorUtil.FlowLayoutAxis
  if c.SetFlowLayoutAnchorPoint then
    c:SetFlowLayoutAnchorPoint(l.anchor)
    if FD then c:SetFlowLayoutGrowthDirection(l.growX == "LEFT" and FD.Left or FD.Right, l.growY == "UP" and FD.Up or FD.Down) end
    c:SetFlowLayoutPadding(l.padding, l.padding, l.padding, l.padding)
    c:SetFlowLayoutMaximumLineSize(l.lineSize > 0 and l.lineSize or math.huge)
    if AX then c:SetFlowLayoutAxis(l.axis == "vertical" and AX.Vertical or AX.Horizontal) end
  end
end

-- groups: array of { key = "debuffs", filter = "HARMFUL|PLAYER", max = 8, sort = "expiration", reverse = false,
--   size = 26, enabled = true }. Groups are add-only (a removed group is capped
-- at 0, which also stops the engine parsing it); order is kept by key (G24).
function Handle:Configure(groups)
  local c = self.container
  local wanted = {}
  for i = 1, #groups do
    local g = groups[i]
    assert(type(g.key) == "string" and g.key ~= "", "aura group needs a key")
    local filter = Auras.Filter(g.filter)
    local cap = (g.enabled == false) and 0 or (g.max or 40)
    wanted[g.key] = true
    local known = self.groups[g.key]
    if not known then
      if c then
        c:AddAuraGroup(g.key, filter, { maxFrameCount = cap, sortMethod = sortMethod(g.sort), sortDirection = sortDir(g.reverse) })
      end
      self.groups[g.key] = { filter = filter, cap = cap, sort = g.sort, reverse = g.reverse }
      self.order[#self.order + 1] = g.key
    else
      if known.filter ~= filter then
        if c then c:SetAuraGroupFilterString(g.key, filter) end
        known.filter = filter
      end
      if known.cap ~= cap then
        if c then c:SetAuraGroupMaxFrameCount(g.key, cap) end
        known.cap = cap
      end
      if known.sort ~= g.sort or known.reverse ~= g.reverse then
        if c then c:SetAuraGroupSortMethod(g.key, sortMethod(g.sort), sortDir(g.reverse)) end
        known.sort, known.reverse = g.sort, g.reverse
      end
    end
  end
  for key, known in pairs(self.groups) do
    if not wanted[key] and known.cap ~= 0 then
      if c then c:SetAuraGroupMaxFrameCount(key, 0) end
      known.cap = 0
    end
  end
end

-- Spell IDs one surface leaves to another (Player Aura Bars <-> CDM buff
-- bars dedupe, plan 1.O "Buff bars"). Stored always; handed to the engine only
-- when the client exposes a per-group exclusion setter (checked, never assumed).
function Handle:SetExclusions(list)
  self.exclusions = {}
  for i = 1, #(list or {}) do self.exclusions[i] = list[i] end
  local c = self.container
  if c and c.SetAuraGroupExcludedSpellIDs then
    for _, key in ipairs(self.order) do c:SetAuraGroupExcludedSpellIDs(key, self.exclusions) end
    return true
  end
  return false
end

function Handle:GroupState(key) local g = self.groups[key]; return g and { filter = g.filter, cap = g.cap } end
function Handle:Groups() return self.order end

function Handle:SetUnit(unit)
  self.unit = unit
  if self.container then self.container:SetUnit(unit) end
end

-- Restyle callbacks touch button visuals; while auras are restricted they wait.
function Handle:Restyle(fn)
  Auras:QueueRestyle(self, fn)
end

function Handle:Release()
  if self.container then
    for key, g in pairs(self.groups) do
      if g.cap ~= 0 then self.container:SetAuraGroupMaxFrameCount(key, 0); g.cap = 0 end
    end
    self.container:Hide()
  end
  Auras.handles[self] = nil
end

function Auras:Create(owner, parent, unit, layout)
  assert(type(owner) == "string" and owner ~= "", "Auras:Create needs an owner")
  local h = setmetatable({ owner = owner, unit = unit, groups = {}, order = {}, layout = PUI.Schema.Copy(self.LAYOUT_DEFAULT) }, Handle)
  if self:Available() then
    -- The container auto-sizes from engine content; surfaces anchor to their own
    -- fixed-size frame, never to the container (G36).
    local c = CreateFrame("AuraContainer", nil, parent or UIParent, "CustomAuraContainerTemplate")
    c:SetUnit(unit)
    h.container = c
  end
  self.handles[h] = true
  h:SetLayout(layout)
  return h
end

------------------------------------------------------------------------------
-- Restyle queue (one owned Ticker entry, armed only while work waits).
function Auras:QueueRestyle(handle, fn)
  self.restyleQueue[#self.restyleQueue + 1] = { h = handle, fn = fn }
  self:FlushRestyles()
end

function Auras:FlushRestyles()
  if C_Secrets.ShouldAurasBeSecret() then
    if not PUI.Ticker:IsRegistered("auras.restyle") then
      PUI.Ticker:Register("auras.restyle", 0.5, function() Auras:FlushRestyles() end, "Core")
    end
    return false
  end
  PUI.Ticker:Unregister("auras.restyle")
  local q = self.restyleQueue
  self.restyleQueue = {}
  for i = 1, #q do
    if self.handles[q[i].h] then securecallfunction(q[i].fn, q[i].h) end
  end
  return true
end

------------------------------------------------------------------------------
-- Private aura anchors (raid-frame option). opts: { index, size, max, showCountdown, showNumbers }.
function Auras:AddPrivateAnchor(owner, frame, unit, opts)
  opts = opts or {}
  local size = opts.size or 24
  local id = C_UnitAuras.AddPrivateAuraAnchor({
    unitToken = unit, auraIndex = opts.index or 1, parent = frame,
    showCountdownFrame = opts.showCountdown ~= false, showCountdownNumbers = opts.showNumbers == true,
    iconInfo = { iconWidth = size, iconHeight = size,
      iconAnchor = { point = "CENTER", relativeTo = frame, relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
  })
  if id then self.privateAnchors[id] = owner end
  return id
end

function Auras:RemovePrivateAnchors(owner)
  local n = 0
  for id, o in pairs(self.privateAnchors) do
    if o == owner then C_UnitAuras.RemovePrivateAuraAnchor(id); self.privateAnchors[id] = nil; n = n + 1 end
  end
  return n
end

PUI.Kernel:On("MODULE_DISABLED", function(name)
  if type(name) ~= "string" then return end
  Auras:RemovePrivateAnchors(name)
  for h in pairs(Auras.handles) do if h.owner == name then h:Release() end end
end)
