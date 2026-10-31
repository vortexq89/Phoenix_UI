local _, ns = ...
local L, Skin, Theme = ns.L, ns.Skin, ns.Theme
local M = ns:GetModule("Encounters")

--[[ BigWigs bridge: registers a "Phoenix" bar style through BigWigs' public bar-style API
    (BigWigsAPI:RegisterBarStyle, api version 1), so BigWigs and LittleWigs bars wear Phoenix's texture,
    colours, fonts and border. Nothing of BigWigs is copied or changed: the player picks the style in
    BigWigs → Bars → Style, and everything we change on a bar is put back in BarStopped before BigWigs reuses
    it. If BigWigs moves to a new style API version the registration fails quietly and the options say so. ]]
local BW = {}
M.BigWigs = BW
BW.status = "absent" -- "absent" | "registered" | "failed"

local API_VERSION, STYLE_VERSION = 1, 1
local saved = setmetatable({}, { __mode = "k" }) -- candy bar -> what we changed, to restore

local function styleOn() return M.active and M.db.bigwigs end

local function applyStyle(bar)
    if not styleOn() then return end
    local sb, label, duration = bar.candyBarBar, bar.candyBarLabel, bar.candyBarDuration
    if not sb then return end
    local s = saved[bar] or {}
    saved[bar] = s
    local tex = sb:GetStatusBarTexture()
    s.texture = s.texture or (tex and tex:GetTexture())
    if label and not s.label then s.label = { label:GetFont() } end
    if duration and not s.duration then s.duration = { duration:GetFont() } end
    sb:SetStatusBarTexture(M:BarTexture())
    if bar.candyBarBackground then
        bar.candyBarBackground:SetTexture(M:BarTexture())
        bar.candyBarBackground:SetVertexColor(Theme:Color("bg.sunken"))
    end
    local db = M.db.timeline
    if label then Skin:TextSpec(label, db.name, "unit") end
    if duration then Skin:TextSpec(duration, db.time, "number") end
    if bar.candyBarIconFrame then Skin:IconZoom(bar.candyBarIconFrame, 0.08) end
    s.edge = s.edge or CreateFrame("Frame", nil, bar)
    s.edge:SetAllPoints(bar)
    s.edge:SetFrameLevel(sb:GetFrameLevel() + 2)
    Skin:BorderSpec(s.edge, db.border, "border.black")
    s.edge:Show()
end

local function barStopped(bar)
    local s = saved[bar]
    if not s then return end
    local sb = bar.candyBarBar
    if sb and s.texture then sb:SetStatusBarTexture(s.texture) end
    if s.label and bar.candyBarLabel then bar.candyBarLabel:SetFont(unpack(s.label)) end
    if s.duration and bar.candyBarDuration then bar.candyBarDuration:SetFont(unpack(s.duration)) end
    if bar.candyBarIconFrame then bar.candyBarIconFrame:SetTexCoord(0, 1, 0, 1) end
    if s.edge then s.edge:Hide() end
    s.texture, s.label, s.duration = nil, nil, nil
end

local STYLE = {
    apiVersion = API_VERSION,
    version = STYLE_VERSION,
    GetSpacing = function(bar) return bar:GetHeight() + M.db.timeline.spacing end,
    ApplyStyle = applyStyle,
    BarStopped = barStopped,
    GetStyleName = function() return "Phoenix" end,
}

local function register()
    if BW.status == "registered" then return end
    local api = rawget(_G, "BigWigsAPI")
    if type(api) ~= "table" or type(api.RegisterBarStyle) ~= "function" then return end
    local ok = pcall(api.RegisterBarStyle, api, "Phoenix", STYLE)
    BW.status = ok and "registered" or "failed"
end

function BW:Enable()
    register()
    if BW.status == "absent" then
        ns.Events:On("ADDON_LOADED", BW, function(_, _, name)
            if name == "BigWigs" or name == "BigWigs_Core" then register() end
            if BW.status ~= "absent" then ns.Events:Off("ADDON_LOADED", BW) end
        end)
    end
end

-- Text for the options page.
function BW:StatusText()
    if self.status == "registered" then return L.ENC_BW_READY end
    if self.status == "failed" then return L.ENC_BW_FAILED end
    return L.ENC_BW_ABSENT
end
