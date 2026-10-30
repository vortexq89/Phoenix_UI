-- Sample Phoenix UI plugin: a themed panel that shows your name and is movable in Layout mode.
local P = PhoenixUI
if not (P and P:Supports(1, 0)) then return end

local panel, text
local plugin = P:RegisterPlugin("Hello_Sample", {
    label = "Hello", desc = "Sample plugin: a themed greeting panel.", category = "utility",
    defaults = { enabled = true, message = "Hello", width = 180 },
    OnEnable = function(self)
        if not panel then
            panel = CreateFrame("Frame", "PhoenixUIHelloPanel", UIParent, "BackdropTemplate")
            panel:SetPoint("CENTER", 0, 200)
            P:StylePanel(panel, "raised")
            text = P:CreateText(panel, "body", "text", "CENTER")
            text:SetPoint("CENTER")
            P:RegisterMover("Hello_Sample", panel, "Hello")
        end
        panel:Show(); self:Refresh()
    end,
    OnDisable = function() if panel then panel:Hide() end end,
    Refresh = function(self)
        if not panel then return end
        panel:SetSize(self.db.width, 28)
        text:SetText(self.db.message .. ", " .. UnitName("player"))
    end,
})

P:RegisterSettings("Hello_Sample", {
    { type = "header", label = "Hello" },
    { type = "input", label = "Message", key = "message" },
    { type = "range", label = "Width", key = "width", min = 100, max = 400, step = 10 },
})
P:Listen("PUI_THEME_CHANGED", plugin, function() plugin:Refresh() end)
