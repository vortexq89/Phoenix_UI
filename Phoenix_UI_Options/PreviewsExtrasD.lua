local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live preview for the Forever page (deferred batch D): a sample flight bar
-- line and the pet badge as the settings draw them. Sample values only.
local Options = PUI.Options
local PX = Options.PreviewsExtras
local Previews = Options.Previews

Previews.Forever = Previews.Forever or function() end
PX.extend("Forever", function(card)
  local FV = PUI.Forever
  local s = FV and FV.settings
  if not s then return end
  local rows = { "Forever" }
  if s.flightTimer then
    local text = FV.Flight.Text({ name = "Stormwind", t0 = 0, known = 150 }, 45)
    rows[#rows + 1] = "Flight bar: " .. text .. string.format("  (size %.0f%%)", (s.flightScale or 1) * 100)
  else rows[#rows + 1] = "Flight timer off" end
  if s.petHappiness then rows[#rows + 1] = "Pet: Happy  +20" .. (s.petWarn and "   (chat line when unhappy)" or "")
  else rows[#rows + 1] = "Pet happiness badge off" end
  if not PUI.IS_FOREVER then rows[#rows + 1] = "Turns on in the Forever client only." end
  PX.Foot(card, "fv", rows)
end)
