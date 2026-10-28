local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ticker: the registry for every periodic callback in Phoenix UI.
-- Register(key, interval, fn, owner): interval > 0 uses a looping AnimationGroup
-- (sleeps in C between loops); interval == 0 means every frame and uses the one
-- shared driver frame below, which is the only OnUpdate script in the addon.
-- Audit() flags any Phoenix-owned frame that carries an OnUpdate script.
local Ticker = { entries = {}, perFrame = {}, perFrameCount = 0 }
PUI.Ticker = Ticker

local driver = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
local call = securecallfunction

local function onUpdate(_, elapsed)
  for key, entry in pairs(Ticker.perFrame) do call(entry.fn, elapsed, key) end
end

local function onLoop(group)
  local entry = Ticker.byGroup[group]
  if entry then call(entry.fn, entry.interval, entry.key) end
end
Ticker.byGroup = setmetatable({}, { __mode = "k" })

function Ticker:Register(key, interval, fn, owner)
  assert(type(key) == "string" and key ~= "", "Ticker:Register needs a key")
  assert(type(interval) == "number" and interval >= 0, "Ticker:Register needs an interval >= 0 (seconds)")
  assert(type(fn) == "function", "Ticker:Register needs a function")
  self:Unregister(key)
  local entry = { key = key, interval = interval, fn = fn, rawFn = fn, owner = owner or "Core" }
  -- Profiler (1.32): only while it runs does a new job get a timed wrapper.
  if self.probe then entry.fn = self.probe(entry) end
  if interval == 0 then
    self.perFrame[key] = entry
    self.perFrameCount = self.perFrameCount + 1
    if self.perFrameCount == 1 then driver:SetScript("OnUpdate", onUpdate) end
  else
    local holder = PUI:CreateFrame("Frame", nil, nil, nil, entry.owner)
    local group = holder:CreateAnimationGroup()
    local anim = group:CreateAnimation("Animation")
    anim:SetDuration(interval)
    group:SetLooping("REPEAT")
    group:SetScript("OnLoop", onLoop)
    self.byGroup[group] = entry
    entry.holder, entry.group = holder, group
    group:Play()
  end
  self.entries[key] = entry
  PUI:Log("ticker.register", key, interval)
  return entry
end

function Ticker:Unregister(key)
  local entry = self.entries[key]
  if not entry then return false end
  if entry.group then
    entry.group:Stop()
    self.byGroup[entry.group] = nil
    entry.group, entry.holder = nil, nil
  else
    self.perFrame[key] = nil
    self.perFrameCount = self.perFrameCount - 1
    if self.perFrameCount == 0 then driver:SetScript("OnUpdate", nil) end
  end
  self.entries[key] = nil
  PUI:Log("ticker.unregister", key)
  return true
end

function Ticker:UnregisterOwner(owner)
  for key, entry in pairs(self.entries) do
    if entry.owner == owner then self:Unregister(key) end
  end
end

function Ticker:IsRegistered(key) return self.entries[key] ~= nil end

-- Returns a list of { frame = f, owner = tag } for Phoenix frames that have an
-- OnUpdate script outside the registry. frames: optional { [frame] = owner }.
function Ticker:Audit(frames)
  local stray = {}
  for f, owner in pairs(frames or PUI.Kernel.owned) do
    if f ~= driver and f.GetScript and f:GetScript("OnUpdate") then
      stray[#stray + 1] = { frame = f, owner = owner }
    end
  end
  return stray
end
