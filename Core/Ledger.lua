local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ledgers (plan 1.20, 1.21, G4, G6): every CVar write, key binding and frame
-- takeover Phoenix makes is owner-tagged and recorded with the user's prior
-- state, so turning a feature off (or "Uninstall Phoenix") restores exactly
-- what the user had, and only where the value is still ours.
--
--   PUI.CVars:Set(owner, name, value)      remember prior once, then write
--   PUI.CVars:Restore(owner[, name])       put prior back if still ours
--   PUI.Bindings:Claim(owner, key, action) override binding (combat-deferred)
--   PUI.Bindings:Conflicts(key[, owner])   who else uses this key
--   PUI.FrameLedger:Take(owner, frame, id) record parent/points/shown/alpha
--   PUI.FrameLedger:Release(owner[, id])   restore recorded state
local DB, CQ = PUI.DB, PUI.CombatQueue

local function store()
  local sv = DB.sv
  sv.ledger = sv.ledger or {}
  local key = DB:CharKey()
  local l = sv.ledger[key]
  if not l then l = { cvars = {} }; sv.ledger[key] = l end
  l.cvars = l.cvars or {}
  return l
end

------------------------------------------------------------------------------
-- CVar ledger. A record is { prior = "x", ours = "y", owners = { [owner] = true } }.
-- Persistent CVars are written only on an explicit Set (never re-asserted at login).
local CVars = { excluded = {} }
PUI.CVars = CVars

local function getCVar(name)
  return C_CVar.GetCVar(name)
end

-- Names another addon owns (e.g. BigWigs encounter CVars) are refused.
function CVars:Exclude(name, why) self.excluded[name] = why or true end
function CVars:IsExcluded(name) return self.excluded[name] ~= nil end

function CVars:Set(owner, name, value)
  assert(type(owner) == "string" and owner ~= "", "CVars:Set needs an owner")
  assert(type(name) == "string" and name ~= "", "CVars:Set needs a CVar name")
  if self.excluded[name] then return false, "excluded" end
  value = tostring(value)
  local cur = getCVar(name)
  if cur == nil then return false, "unknown CVar" end
  local rec = store().cvars[name]
  if not rec then
    rec = { prior = cur, owners = {} }
    store().cvars[name] = rec
  elseif rec.ours ~= cur then
    rec.prior = cur -- the user changed it since our last write: their value is the new prior
  end
  rec.owners[owner] = true
  rec.ours = value
  if cur ~= value then C_CVar.SetCVar(name, value) end
  PUI:Log("cvar.set", name, value)
  return true
end

-- Restores one CVar (or every CVar) owned by owner. A CVar shared by several
-- owners is restored when its last owner lets go.
function CVars:Restore(owner, name)
  local list, restored = store().cvars, 0
  for n, rec in pairs(list) do
    if (name == nil or n == name) and rec.owners[owner] then
      rec.owners[owner] = nil
      if next(rec.owners) == nil then
        if getCVar(n) == rec.ours and rec.prior ~= rec.ours then C_CVar.SetCVar(n, rec.prior) end
        list[n] = nil
        restored = restored + 1
        PUI:Log("cvar.restore", n, rec.prior)
      end
    end
  end
  return restored
end

-- Read-only view for the ledger page: { name, prior, ours, current, stillOurs, owners = {...} }.
function CVars:List()
  local out = {}
  for n, rec in pairs(store().cvars) do
    local owners = {}
    for o in pairs(rec.owners) do owners[#owners + 1] = o end
    table.sort(owners)
    local cur = getCVar(n)
    out[#out + 1] = { name = n, prior = rec.prior, ours = rec.ours, current = cur, stillOurs = cur == rec.ours, owners = owners }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function CVars:RestoreAll()
  local n = 0
  for name, rec in pairs(store().cvars) do
    for o in pairs(rec.owners) do n = n + self:Restore(o, name) end
  end
  return n
end

------------------------------------------------------------------------------
-- Binding ledger. Phoenix never edits the user's saved bindings: it uses
-- override bindings owned by one hidden frame per owner, applied out of combat.
local Bindings = { claims = {}, owners = {} }
PUI.Bindings = Bindings

local function ownerFrame(owner)
  local f = Bindings.owners[owner]
  if not f then
    f = PUI:CreateFrame("Frame", nil, nil, nil, owner)
    Bindings.owners[owner] = f
  end
  return f
end

local function normalise(key)
  if type(key) ~= "string" then return nil end
  key = key:upper():gsub("%s+", "")
  if key == "" then return nil end
  -- canonical modifier order: ALT-CTRL-SHIFT-<key>
  local mods, base = {}, key
  for _, m in ipairs({ "ALT", "CTRL", "SHIFT", "META" }) do
    local pat = "%f[%w]" .. m .. "%-"
    if base:find(pat) then mods[#mods + 1] = m; base = base:gsub(pat, "") end
  end
  if base == "" then return nil end
  mods[#mods + 1] = base
  return table.concat(mods, "-")
end
Bindings.Normalise = normalise

local function reapply(owner)
  CQ.Defer("bindings." .. owner, function()
    local f = ownerFrame(owner)
    ClearOverrideBindings(f)
    for key, c in pairs(Bindings.claims) do
      for o, action in pairs(c) do
        if o == owner then
          if action.click then SetOverrideBindingClick(f, action.priority == true, key, action.click, action.button)
          else SetOverrideBinding(f, action.priority == true, key, action.command) end
        end
      end
    end
  end)
end

-- action: "COMMAND" or { command = "..." } or { click = "ButtonName", button = "LeftButton" }.
function Bindings:Claim(owner, key, action)
  assert(type(owner) == "string" and owner ~= "", "Bindings:Claim needs an owner")
  local k = normalise(key)
  if not k then return false, "not a key" end
  if type(action) == "string" then action = { command = action } end
  assert(type(action) == "table" and (action.command or action.click), "Bindings:Claim needs a command or click target")
  self.claims[k] = self.claims[k] or {}
  self.claims[k][owner] = action
  reapply(owner)
  return true, k
end

-- Reserve(owner, key, label): records a key Phoenix uses without an override
-- binding (click-cast hovercast keys bound by a secure snippet on mouse-over).
-- It shows in List and Conflicts so every key Phoenix touches is in one place,
-- and is never applied. Unreserve(owner) clears all of one owner's reservations.
Bindings.reserved = {}
function Bindings:Reserve(owner, key, label)
  assert(type(owner) == "string" and owner ~= "", "Bindings:Reserve needs an owner")
  local k = normalise(key)
  if not k then return false, "not a key" end
  self.reserved[k] = self.reserved[k] or {}
  self.reserved[k][owner] = label or "hover"
  return true, k
end

function Bindings:Unreserve(owner, key)
  local k = key and normalise(key)
  for rk, r in pairs(self.reserved) do
    if (k == nil or rk == k) and r[owner] then
      r[owner] = nil
      if next(r) == nil then self.reserved[rk] = nil end
    end
  end
end

function Bindings:Release(owner, key)
  local k = key and normalise(key)
  for ck, c in pairs(self.claims) do
    if (k == nil or ck == k) and c[owner] then
      c[owner] = nil
      if next(c) == nil then self.claims[ck] = nil end
    end
  end
  reapply(owner)
end

-- Every other user of key: Phoenix owners from the ledger plus the Blizzard
-- binding the user saved. Used by the keybind capture widget at capture time.
function Bindings:Conflicts(key, owner)
  local k = normalise(key)
  local out = {}
  if not k then return out end
  local c = self.claims[k]
  if c then
    local names = {}
    for o in pairs(c) do if o ~= owner then names[#names + 1] = o end end
    table.sort(names)
    for _, o in ipairs(names) do out[#out + 1] = { kind = "phoenix", owner = o, action = c[o].command or c[o].click } end
  end
  local r = self.reserved[k]
  if r then
    local names = {}
    for o in pairs(r) do if o ~= owner then names[#names + 1] = o end end
    table.sort(names)
    for _, o in ipairs(names) do out[#out + 1] = { kind = "phoenix", owner = o, action = r[o], reserved = true } end
  end
  local blizz = GetBindingAction and GetBindingAction(k, false)
  if blizz and blizz ~= "" then out[#out + 1] = { kind = "blizzard", action = blizz } end
  return out
end

function Bindings:List()
  local out = {}
  for k, c in pairs(self.claims) do
    for o, a in pairs(c) do out[#out + 1] = { key = k, owner = o, action = a.command or a.click } end
  end
  for k, r in pairs(self.reserved) do
    for o, label in pairs(r) do out[#out + 1] = { key = k, owner = o, action = label, reserved = true } end
  end
  table.sort(out, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.owner < b.owner end)
  return out
end

------------------------------------------------------------------------------
-- FrameLedger. Approved takeovers only. State lives in this table, never as
-- fields on the Blizzard frame (G4). Restore is combat-deferred.
local FrameLedger = { entries = {} }
PUI.FrameLedger = FrameLedger

local function snapshot(frame)
  local points = {}
  for i = 1, (frame:GetNumPoints() or 0) do
    local p, rel, rp, x, y = frame:GetPoint(i)
    points[i] = { p, rel, rp, x, y }
  end
  return { parent = frame:GetParent(), points = points, shown = frame:IsShown(), alpha = frame:GetAlpha(),
    scale = frame:GetScale(), strata = frame.GetFrameStrata and frame:GetFrameStrata() or nil,
    level = frame.GetFrameLevel and frame:GetFrameLevel() or nil,
    mouse = frame.IsMouseEnabled and frame:IsMouseEnabled(), movable = frame.IsMovable and frame:IsMovable() }
end

function FrameLedger:Take(owner, frame, id)
  assert(type(owner) == "string" and owner ~= "", "FrameLedger:Take needs an owner")
  assert(type(id) == "string" and id ~= "", "FrameLedger:Take needs a stable id (G24)")
  local e = self.entries[id]
  if e then
    if e.owner ~= owner then return false, "owned by " .. e.owner end
    return true
  end
  self.entries[id] = { owner = owner, frame = frame, state = snapshot(frame) }
  PUI:Log("frame.take", id, owner)
  return true
end

function FrameLedger:Owner(id) local e = self.entries[id]; return e and e.owner end

local function restore(e)
  local f, s = e.frame, e.state
  if f:GetParent() ~= s.parent then f:SetParent(s.parent) end
  f:ClearAllPoints()
  for i = 1, #s.points do local p = s.points[i]; f:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
  f:SetAlpha(s.alpha)
  f:SetScale(s.scale)
  if s.strata and f.SetFrameStrata then f:SetFrameStrata(s.strata) end
  if s.level and f.SetFrameLevel then f:SetFrameLevel(s.level) end
  if type(s.mouse) == "boolean" and f.EnableMouse then f:EnableMouse(s.mouse) end
  if type(s.movable) == "boolean" and f.SetMovable then f:SetMovable(s.movable) end
  if s.shown then f:Show() else f:Hide() end
end

function FrameLedger:Release(owner, id)
  local n = 0
  for eid, e in pairs(self.entries) do
    if e.owner == owner and (id == nil or eid == id) then
      self.entries[eid] = nil
      n = n + 1
      if e.frame:IsProtected() then CQ.Defer("frameledger." .. eid, function() restore(e) end) else restore(e) end
      PUI:Log("frame.restore", eid, owner)
    end
  end
  return n
end

function FrameLedger:List()
  local out = {}
  for id, e in pairs(self.entries) do out[#out + 1] = { id = id, owner = e.owner } end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

function FrameLedger:ReleaseAll()
  local owners, n = {}, 0
  for _, e in pairs(self.entries) do owners[e.owner] = true end
  for o in pairs(owners) do n = n + self:Release(o) end
  return n
end

function Bindings:ReleaseAll()
  local owners, n = {}, 0
  for _, c in pairs(self.claims) do for o in pairs(c) do owners[o] = true; n = n + 1 end end
  for o in pairs(owners) do self:Release(o) end
  return n
end

-- Restores one CVar for every owner at once (ledger page "Restore" button).
function CVars:RestoreName(name)
  local rec = store().cvars[name]
  if not rec then return 0 end
  local n = 0
  local owners = {}
  for o in pairs(rec.owners) do owners[#owners + 1] = o end
  for _, o in ipairs(owners) do n = n + self:Restore(o, name) end
  return n
end

------------------------------------------------------------------------------
-- "Uninstall Phoenix" (plan 1.22, G6): give back every CVar (to the user's
-- prior value, only where the value is still ours), every override binding and
-- every frame takeover, then turn every module off so nothing re-asserts.
-- Settings and profiles are kept (the user may come back); the summary says
-- what was restored and that the addon can now be disabled in the AddOns list.
local Ledger = {}
PUI.Ledger = Ledger

function Ledger.Summary()
  local cv, kept = 0, 0
  for _, r in ipairs(CVars:List()) do if r.stillOurs then cv = cv + 1 else kept = kept + 1 end end
  return { cvars = cv, cvarsChanged = kept, bindings = #Bindings:List(), frames = #FrameLedger:List() }
end

function Ledger.Uninstall()
  local before = Ledger.Summary()
  local modules = 0
  for _, name in ipairs(PUI.Kernel.order or {}) do
    local key = "module." .. name
    if PUI.Schema:Def(key) and PUI.Schema:Get(key) then PUI.Schema:Set(key, false); modules = modules + 1 end
  end
  local cvars = CVars:RestoreAll()
  local binds = Bindings:ReleaseAll()
  local frames = FrameLedger:ReleaseAll()
  PUI:Log("ledger.uninstall", cvars, binds, frames)
  PUI.Kernel:Fire("LEDGER_UNINSTALLED")
  return { cvars = cvars, bindings = binds, frames = frames, modules = modules, untouched = before.cvarsChanged }
end

-- A module that turns off gives back everything it held.
PUI.Kernel:On("MODULE_DISABLED", function(name)
  if type(name) ~= "string" then return end
  CVars:Restore(name)
  Bindings:Release(name)
  Bindings:Unreserve(name)
  FrameLedger:Release(name)
end)
