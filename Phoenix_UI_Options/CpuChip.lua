local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Per-page CPU chip (deferred batch C, Diagnostics): while the developer
-- profiler has samples, the settings header shows the time the open page's
-- module spent in Phoenix's registered entry points. Hidden on the
-- Dashboard, with no samples, or when the setting is off.
local Options, Schema = PUI.Options, PUI.Schema
local Chip = {}
Options.CpuChip = Chip

Schema:Register("sentinel.cpuChip", { type = "toggle", default = true, owner = "Sentinel", mode = "advanced",
  label = "CPU chip on settings pages", tooltip = "While the developer profiler has samples, each module page shows how much time that module took.",
  apply = function() if Options.frame then Chip.Paint() end end })

function Chip.Text(page)
  local P = PUI.Profiler
  if not (P and page and page ~= "Dashboard" and Schema:Get("sentinel.cpuChip")) then return nil end
  local ms = P:OwnerTotal(page)
  if ms <= 0 then return nil end
  return string.format("CPU %s %.2f ms%s", page, ms, P.running and "" or " (stopped)")
end

function Chip.Paint()
  local f = Options.frame
  if not f then return end
  local fs = rawget(f, "cpuChip")
  if not fs then
    fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(PUI.Media:FontObject("small"))
    fs:SetPoint("RIGHT", f.mode, "LEFT", -12, 0)
    rawset(f, "cpuChip", fs)
  end
  local text = Chip.Text(Options.page)
  fs:SetText(text or "")
  if text then fs:Show() else fs:Hide() end
end

local render = Options.Render
function Options:Render()
  local r = render(self)
  Chip.Paint()
  return r
end
