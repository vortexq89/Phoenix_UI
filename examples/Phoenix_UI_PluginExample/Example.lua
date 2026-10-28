local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Example plugin: a small clock badge in the Phoenix theme, size setting live.

local frame
PUI.Plugins:Register("Example", {
  api = 1,
  label = "Example clock",
  tooltip = "A clock badge drawn with Phoenix theme tokens (plugin API example).",
  enabledByDefault = false,
  schema = {
    ["plugin.Example.scale"] = { type = "range", min = 0.5, max = 2, step = 0.1, default = 1, label = "Clock size",
      tooltip = "Scale of the example clock.", mode = "simple",
      apply = function(v) if frame then frame:SetScale(v) end end },
  },
  onEnable = function(h)
    if not frame then
      frame = h:Frame("Frame", "PhoenixPluginExampleClock")
      frame:SetSize(90, 22)
      frame:SetPoint("TOP", 0, -40)
      h:Backdrop(frame, "surface.1")
      frame.text = frame:CreateFontString(nil, "OVERLAY")
      frame.text:SetFontObject(h:Font("body"))
      frame.text:SetPoint("CENTER")
    end
    frame:SetScale(h:Get("plugin.Example.scale"))
    frame:Show()
    h:Every("clock", 1, function() frame.text:SetText(date("%H:%M:%S")) end)
  end,
  onDisable = function() if frame then frame:Hide() end end,
})
