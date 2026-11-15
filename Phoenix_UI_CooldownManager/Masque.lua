local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Masque group "Cooldown Manager" for the restyled Cooldown Viewer icons and
-- the custom item bar (PUI.Masque, no-op without Masque). Bar-style items
-- are left alone; Phoenix's own border is hidden while Masque skins an icon.
local _, ns = ...
local CDM = ns.CDM
local M = PUI.Masque

local skin = CDM.Skin
function CDM.Skin(f, bars)
  skin(f, bars)
  if bars then return end
  M.Add("cdm", "Cooldown Manager", f)
  local sk = CDM.skins[f]
  if sk and M.Skinned(f) then for i = 1, 4 do sk[i]:Hide() end end
end
M.OnArea("cdm", function() if CDM.active then CDM.Refresh() end end)
