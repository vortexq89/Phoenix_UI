local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Data packs (PUI_V2 Section 9): plain tables, no logic, each stamped with a
-- packVersion (date) and the gameBuild it was checked against. A pack older
-- than the running client's major.minor build is flagged once, so stale data
-- is visible instead of silently wrong. Community PRs only touch packs.
local Packs = { list = {}, warned = {} }
PUI.Packs = Packs

local function majorMinor(build)
  local a, b = tostring(build or ""):match("^(%d+)%.(%d+)")
  if not a then return nil end
  return tonumber(a) * 100 + tonumber(b)
end
Packs.MajorMinor = majorMinor

-- Register(name, { packVersion = "2026-10-26", gameBuild = "12.1.5", flavor = "retail"|"forever"|"any", data = {...} })
function Packs:Register(name, pack)
  assert(type(name) == "string" and type(pack) == "table" and type(pack.data) == "table", "pack needs a name and data")
  assert(type(pack.packVersion) == "string" and type(pack.gameBuild) == "string", "pack needs packVersion and gameBuild")
  pack.name = name
  pack.flavor = pack.flavor or "any"
  self.list[name] = pack
  return pack.data
end

function Packs:Get(name)
  local p = self.list[name]
  return p and p.data
end

-- True when the pack was checked against an older major.minor than the client.
function Packs:IsStale(name)
  local p = self.list[name]
  if not p then return false end
  local mine, theirs = majorMinor((GetBuildInfo())), majorMinor(p.gameBuild)
  if not mine or not theirs then return false end
  if p.flavor == "forever" and not PUI.IS_FOREVER then return false end
  if p.flavor == "retail" and PUI.IS_FOREVER then return false end
  if PUI.IS_FOREVER then return false end -- Forever builds are versioned separately (1.x)
  return theirs < mine
end

function Packs:WarnStale()
  for name in pairs(self.list) do
    if self:IsStale(name) and not self.warned[name] then
      self.warned[name] = true
      PUI.Slash.Print("data pack '" .. name .. "' was checked against " .. self.list[name].gameBuild .. "; some values may be out of date.")
    end
  end
end

PUI.Slash:Register("packs", function()
  for name, p in pairs(Packs.list) do
    PUI.Slash.Print(string.format("%s  v%s  build %s%s", name, p.packVersion, p.gameBuild, Packs:IsStale(name) and "  (stale)" or ""))
  end
end, "list the data packs and their versions")
