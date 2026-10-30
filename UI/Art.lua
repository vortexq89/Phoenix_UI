-- Copyright (c) 2026 VortexQ8 (ABDULRAHMAN ALYOUSEF). All rights reserved. See Media/LICENSE.md.
local _, ns = ...

--[[ Phoenix art kit v7.1 (ns.Art): baked textures only, zero runtime effects.

    Media/Art/PhoenixWingsBG    the cinematic phoenix behind the settings window (cover-fit, top-anchored)
    Media/Art/PhoenixMeterBG    a wing crop behind meter windows (optional)
    Media/Art/PhoenixUILogo     the fire logo on Home and in empty states
    Media/Art/PhoenixUI_Atlas   9-slice card, buttons, toggle, slider, rail highlight, field, greyscale meter bar
    Media/Art/PhoenixUI_Icons   status icons (flame / ash / warning / error / info) and module icons

    Every texture is set once (build, resize, theme change). Hover / pressed swap coords from mouse events; nothing
    animates and there is no OnUpdate. Plugins change the look through tokens (THEME_API §7.0 / 7.00 / 7.01):
        local h = PhoenixUI:OverrideArt("MyPlugin", { ["background.image"] = "Interface/AddOns/MyPlugin/bg",
                                                     ["atlas.ui.card"] = { file = ..., coords = { l, r, t, b }, inset = 24 } })
        h:Set(path, value); h:Clear(path); h:Remove()
    The highest priority layer wins (default 100; ties: the newest). General > Phoenix art off draws the flat
    look; General > Chrome icons "flat" shows plain glyphs instead of the icon art. ]]

local A = {}
ns.Art = A

local ROOT = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\"
A.ROOT = ROOT

-- the UI atlas (512x512): coords l, r, t, b; inset = 9-slice margin (or left / right / top / bottom)
local UI = ROOT .. "PhoenixUI_Atlas"
local function cell(x, y, w, h, extra)
    local e = extra or {}
    e.file, e.w, e.h = UI, w, h
    e.coords = { x / 512, (x + w) / 512, y / 512, (y + h) / 512 }
    return e
end
A.ATLAS = {
    card = cell(0, 0, 96, 96, { inset = 24, alpha = 240 / 255 }), -- alpha: the fill's own baked opacity
    header = cell(98, 0, 128, 48, { left = 16, right = 16, top = 0, bottom = 6 }),
    btn_pri_normal = cell(228, 0, 144, 48, { inset = 12 }),
    btn_pri_hover = cell(0, 98, 144, 48, { inset = 12 }),
    btn_pri_pressed = cell(146, 98, 144, 48, { inset = 12 }),
    btn_pri_disabled = cell(292, 98, 144, 48, { inset = 12 }),
    btn_sec_normal = cell(0, 148, 144, 48, { inset = 12 }),
    btn_sec_hover = cell(146, 148, 144, 48, { inset = 12 }),
    toggle_on = cell(292, 148, 48, 32),
    toggle_off = cell(342, 148, 48, 32),
    rail_selected = cell(0, 198, 256, 32, { left = 8, right = 0, top = 0, bottom = 0 }),
    meter_bar = cell(0, 232, 256, 32),
    field = cell(258, 232, 32, 32, { inset = 6 }),
    slider_thumb = cell(292, 232, 24, 24),
    check_on = cell(318, 232, 24, 24),
    check_off = cell(344, 232, 24, 24),
    slider_track = cell(370, 232, 128, 12, { left = 4, right = 4, top = 0, bottom = 0 }),
    slider_fill = cell(0, 266, 128, 12, { left = 4, right = 4, top = 0, bottom = 0 }),
}

-- the icon atlas (512x512, 64 px cells on a 72 px pitch, 7 columns)
local ICONS = ROOT .. "PhoenixUI_Icons"
local ICON_ORDER = {
    "status_enabled", "status_disabled", "status_warning", "status_error", "status_info", "mod_home", "mod_action_bars",
    "mod_unit_frames", "mod_nameplates", "mod_auras", "mod_damage_meter", "mod_cast_bars", "mod_combat_text", "mod_chat",
    "mod_bags", "mod_minimap", "mod_tooltips", "mod_profiles", "mod_settings", "mod_plugins", "mod_health",
    "mod_move", "mod_wizard", "mod_bug",
}
A.ICONS = {}
for i, key in ipairs(ICON_ORDER) do
    local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
    local x, y = col * 72 + 4, row * 72 + 4
    A.ICONS[key] = { file = ICONS, coords = { x / 512, (x + 64) / 512, y / 512, (y + 64) / 512 } }
end

-- page / module key -> icon (modules without one keep their Ember Bevel or flat glyph)
A.MODULE_ICON = {
    home = "mod_home", ActionBars = "mod_action_bars", UnitFrames = "mod_unit_frames", GroupFrames = "mod_unit_frames",
    NamePlates = "mod_nameplates", Auras = "mod_auras", DamageMeter = "mod_damage_meter", CastBars = "mod_cast_bars",
    CombatText = "mod_combat_text", Chat = "mod_chat", Bags = "mod_bags", Minimap = "mod_minimap",
    Tooltip = "mod_tooltips", profiles = "mod_profiles", General = "mod_settings", plugins = "mod_plugins",
    diagnostics = "mod_health", Movers = "mod_move", installer = "mod_wizard", Bugs = "mod_bug",
}

---------------------------------------------------------------- tokens and override layers
A.DEFAULTS = {
    ["background.image"] = ROOT .. "PhoenixWingsBG", ["background.fit"] = "cover", ["background.anchor"] = "TOP",
    ["background.tint"] = { r = 1, g = 1, b = 1 }, ["background.alpha"] = 1, ["background.aspect"] = 2,
    ["logo.enabled"] = true, ["logo.image"] = ROOT .. "PhoenixUILogo", ["logo.alpha"] = 1,
    ["panel.alpha.card"] = 0.86, ["panel.alpha.rail"] = 0.86, ["panel.alpha.header"] = 0.80,
    ["panel.alpha.preview"] = 0.76, ["panel.alpha.footer"] = 0.90, ["panel.alpha.meter"] = 0.80,
    ["texture.meterBG"] = ROOT .. "PhoenixMeterBG", ["meter.barTintScale"] = 0.46,
    ["icon.status.enabled"] = "status_enabled", ["icon.status.disabled"] = "status_disabled",
    ["icon.status.warning"] = "status_warning", ["icon.status.error"] = "status_error", ["icon.status.info"] = "status_info",
    ["icon.size.status"] = 16, ["icon.size.rail"] = 18,
}
local layers, seq = {}, 0

local function resolve(path)
    local best
    for _, l in ipairs(layers) do
        local v = l.values[path]
        if v ~= nil and (not best or l.priority > best.priority or (l.priority == best.priority and l.seq > best.seq)) then
            best = l
        end
    end
    if best then return best.values[path], best.owner end
    return nil
end

function A:Token(path)
    local v = resolve(path)
    if v ~= nil then return v end
    return A.DEFAULTS[path]
end

-- an atlas piece, after "atlas.ui" / "atlas.ui.<key>" overrides
function A:Piece(key)
    return resolve("atlas.ui." .. key) or (resolve("atlas.ui") or A.ATLAS)[key] or A.ATLAS[key]
end
function A:IconEntry(key)
    return resolve("atlas.icons." .. key) or (resolve("atlas.icons") or A.ICONS)[key] or A.ICONS[key]
end

local function changed()
    if ns.Events and ns.Events.Fire then ns.Events:Fire("PUI_THEME_CHANGED") end
end

-- texture / number / bool / table checks: a plugin cannot set an effect token or a wrong type
local KIND = { ["background.alpha"] = "number", ["logo.alpha"] = "number", ["meter.barTintScale"] = "number",
    ["logo.enabled"] = "boolean", ["icon.size.status"] = "number", ["icon.size.rail"] = "number" }
function A.Valid(path, v)
    if type(path) ~= "string" then return false end
    if path:find("^effects%.") or path:find("^ash%.") or path:find("^wings%.") then return false end
    if path:find("^atlas%.") then
        return type(v) == "table" and (path:find("^atlas%.%a+$") ~= nil or (type(v.file) == "string" and type(v.coords) == "table"))
    end
    if path:find("^panel%.alpha%.") then return type(v) == "number" and v >= 0.5 and v <= 1 end
    local want = KIND[path] or type(A.DEFAULTS[path] or "")
    return type(v) == want or v == false
end

function A:Override(owner, values, priority)
    seq = seq + 1
    local l = { owner = tostring(owner), values = {}, priority = tonumber(priority) or 100, seq = seq }
    for k, v in pairs(values or {}) do if A.Valid(k, v) then l.values[k] = v end end
    layers[#layers + 1] = l
    changed()
    local h = {}
    function h:Set(path, v) if A.Valid(path, v) then l.values[path] = v; changed() end end
    function h:Clear(path) l.values[path] = nil; changed() end
    function h:Remove()
        for i, x in ipairs(layers) do if x == l then table.remove(layers, i); break end end
        changed()
    end
    return h
end

-- a plugin's own module icon (shown in the rail and on Home): entry = { file =, coords = { l, r, t, b } }
function A:RegisterIcon(key, entry)
    if type(key) ~= "string" or type(entry) ~= "table" or type(entry.file) ~= "string" then return false end
    A.ICONS[key] = { file = entry.file, coords = entry.coords or { 0, 1, 0, 1 } }
    return true
end
function A:SetModuleIcon(moduleKey, iconKey) A.MODULE_ICON[moduleKey] = iconKey end

---------------------------------------------------------------- switches
local function general() return ns.modules and ns.modules.General and ns.modules.General.db end
-- textured cards, buttons, toggles, background and logo (General > Phoenix art)
function A.Enabled()
    local g = general()
    return not (g and g.artKit == false)
end
-- the icon art in the rail, on Home and for status (General > Chrome icons: anything but "flat")
function A.IconsEnabled()
    local g = general()
    return not (g and g.chromeStyle == "flat")
end

---------------------------------------------------------------- painting (all one-shot)
local SLICE = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched

-- tex shows atlas piece `key`; 9-slice margins when the piece has them and the client can slice
function A:Paint(tex, key)
    local p = self:Piece(key)
    if not (tex and p) then return false end
    tex:SetTexture(p.file)
    tex:SetTexCoord(unpack(p.coords))
    local l, r, t, b = p.left or p.inset, p.right or p.inset, p.top or p.inset, p.bottom or p.inset
    if tex.SetTextureSliceMargins then
        if l then
            tex:SetTextureSliceMargins(l, t or 0, r or 0, b or 0)
            if SLICE and tex.SetTextureSliceMode then tex:SetTextureSliceMode(SLICE) end
        elseif tex.ClearTextureSlice then
            tex:ClearTextureSlice()
        end
    end
    tex:SetVertexColor(1, 1, 1, 1)
    return true
end

function A:Icon(tex, key)
    local e = key and self:IconEntry(key)
    if not (tex and e) then return false end
    tex:SetTexture(e.file)
    tex:SetTexCoord(unpack(e.coords))
    tex:SetVertexColor(1, 1, 1, 1)
    return true
end

-- the status icon key for a module: errored > needs reload > on > off
function A:StatusKey(m)
    if not m then return nil end
    if m.state == "errored" then return self:Token("icon.status.error") end
    if m.needsReload then return self:Token("icon.status.warning") end
    return self:Token(m:IsEnabled() and "icon.status.enabled" or "icon.status.disabled")
end

-- pure: texcoords that cover a w x h frame with an image of aspect `aspect` (w / h), anchored TOP / CENTER
function A.CoverCoords(w, h, aspect, anchor)
    if not (w and h) or w <= 0 or h <= 0 then return 0, 1, 0, 1 end
    local fa = w / h
    if fa >= aspect then -- wider frame: crop the image's height
        local vis = aspect / fa
        local top = anchor == "TOP" and 0 or (1 - vis) / 2
        return 0, 1, top, top + vis
    end
    local vis = fa / aspect -- taller frame: crop the sides
    local left = (1 - vis) / 2
    return left, left + vis, 0, 1
end

-- The background art behind a window: one texture, cover-fit on size changes only; released while hidden.
function A:Background(frame, layer, sub)
    local t = frame.phoenixArt
    if not t then
        t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -7)
        t:SetAllPoints()
        frame.phoenixArt = t
        frame:HookScript("OnSizeChanged", function(f) A:FitBackground(f) end)
        frame:HookScript("OnHide", function(f) if f.phoenixArt then f.phoenixArt:SetTexture(nil) end end)
        frame:HookScript("OnShow", function(f) A:FitBackground(f) end)
    end
    self:FitBackground(frame)
    return t
end

function A:FitBackground(frame)
    local t = frame.phoenixArt
    if not t then return end
    if not self.Enabled() then t:Hide(); return end
    t:SetTexture(self:Token("background.image"))
    local fit = self:Token("background.fit")
    if fit == "stretch" then
        t:SetTexCoord(0, 1, 0, 1)
    else
        t:SetTexCoord(A.CoverCoords(frame:GetWidth(), frame:GetHeight(), self:Token("background.aspect"),
            self:Token("background.anchor")))
    end
    local c = self:Token("background.tint")
    t:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, self:Token("background.alpha"))
    t:Show()
end

-- The logo (Home, empty states). Returns the texture; size w (height w / 2).
function A:Logo(parent, w, layer)
    local t = parent.phoenixLogo or parent:CreateTexture(nil, layer or "ARTWORK")
    parent.phoenixLogo = t
    t:SetSize(w, w / 2)
    local on = self.Enabled() and self:Token("logo.enabled")
    t:SetTexture(on and self:Token("logo.image") or nil)
    t:SetAlpha(self:Token("logo.alpha"))
    t:SetShown(on and true or false)
    return t
end

-- Puts the module icon art over a flat glyph (fades the flat one); with "flat" or no art for the key the flat
-- glyph stays. Returns the art texture or nil.
function A:AttachModuleIcon(flat, key, px)
    local iconKey = key and A.MODULE_ICON[key]
    if not (flat and iconKey and self:IconEntry(iconKey)) then return nil end
    local t = flat:GetParent():CreateTexture(nil, "ARTWORK", nil, 2)
    t:SetSize(px or self:Token("icon.size.rail"), px or self:Token("icon.size.rail"))
    t:SetPoint("CENTER", flat, "CENTER")
    t.flat, t.iconKey = flat, iconKey
    self:SyncModuleIcon(t)
    return t
end
function A:SyncModuleIcon(t)
    if not t then return end
    local on = self.IconsEnabled()
    if on then self:Icon(t, t.iconKey) end
    t:SetShown(on)
    t.flat:SetAlpha(on and 0 or 1)
end

-- the meter bar: the greyscale bar texture tinted by class colour x barTintScale (text stays at 4.5:1)
function A:MeterTint(r, g, b)
    local s = self:Token("meter.barTintScale")
    return r * s, g * s, b * s
end
