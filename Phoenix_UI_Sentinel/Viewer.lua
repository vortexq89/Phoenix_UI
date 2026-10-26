local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Viewer: readable plain text for one incident or for every incident seen in
-- this session (BugSack-style). Fields are stored already converted to text by
-- Capture (secret values never reach here), so this only formats.
local S = PUI.Sentinel
local Viewer = {}
S.Viewer = Viewer

-- Incidents newest first; sessionOnly keeps those seen in the current session.
function Viewer:List(sessionOnly)
  local list = {}
  for _, inc in pairs(S.db.incidents) do
    if not sessionOnly or inc.lastSession == S.db.session or inc.session == S.db.session then
      list[#list + 1] = inc
    end
  end
  table.sort(list, function(a, b)
    if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
    return a.hash < b.hash
  end)
  return list
end

local function stamp(t) return t and date("%Y-%m-%d %H:%M:%S", t) or "?" end

function Viewer:Text(inc)
  if not inc then return "" end
  local ctx = inc.context or {}
  local lines = {
    string.format("[%s] %s in %s  x%d", inc.severity or "?", inc.kind or "?", inc.module or "?", inc.count or 0),
    "First seen: " .. stamp(inc.firstSeen) .. "   Last seen: " .. stamp(inc.lastSeen),
    "Phoenix " .. tostring(inc.addonVersion) .. "   Interface " .. tostring(inc.interface) .. "   Build " .. tostring(inc.build)
      .. "   " .. tostring(inc.locale) .. "   " .. tostring(inc.track),
    "In combat: " .. (ctx.combat and "yes" or "no") .. "   Hash: " .. tostring(inc.hash),
    "",
    "Message:",
    tostring(inc.message or ""),
    "",
    "Stack:",
    (inc.stack ~= nil and inc.stack ~= "") and inc.stack or "(none)",
    "",
    "Locals:",
    (inc.locals ~= nil and inc.locals ~= "") and inc.locals or "(none)",
  }
  return table.concat(lines, "\n")
end

function Viewer:SessionText()
  local list = self:List(true)
  if #list == 0 then return "No incidents in this session." end
  local parts = {}
  for i = 1, #list do parts[i] = string.format("#%d of %d\n%s", i, #list, self:Text(list[i])) end
  return table.concat(parts, "\n\n----------------------------------------\n\n")
end
