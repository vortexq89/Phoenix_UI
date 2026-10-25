local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Drift: at load, every Blizzard API listed in Data/ApiManifest.lua (generated
-- by .tools/manifest.py) must exist. A missing API raises a drift incident
-- and puts the owning module in safe mode before it can call it.
local S = PUI.Sentinel
local Drift = {}
S.Drift = Drift

local UNSTOPPABLE = { Core = true, Sentinel = true, Tests = true }

function Drift.Resolve(path, root)
  local node = root or _G
  for part in path:gmatch("[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

function Drift:Check(manifest, root)
  local missing = {}
  for api, info in pairs(manifest.apis or {}) do
    local applies = not (PUI.IS_FOREVER and info.retailOnly) and not (not PUI.IS_FOREVER and info.foreverOnly)
    if applies and Drift.Resolve(api, root) == nil then
      missing[#missing + 1] = { api = api, owners = info.owners }
    end
  end
  table.sort(missing, function(a, b) return a.api < b.api end)
  return missing
end

function Drift:Run(manifest, root)
  manifest = manifest or PUI.ApiManifest
  if not manifest then return {} end
  local missing = self:Check(manifest, root)
  for i = 1, #missing do
    local m = missing[i]
    for j = 1, #m.owners do
      local owner = m.owners[j]
      S.Capture:Report("drift", owner, { message = "API missing at login: " .. m.api, extra = { api = m.api, build = PUI.BUILD } })
      if not UNSTOPPABLE[owner] then PUI.Kernel:SetSafeMode(owner, true, "drift: " .. m.api) end
    end
  end
  return missing
end
