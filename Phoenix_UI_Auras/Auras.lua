local _, ns = ...
local Style, Secret, Skin = ns.Style, ns.Secret, ns.Skin

--[[ Auras v2 (plan v2 S9): the player's buffs, debuffs and weapon enchants on Phoenix-placed aura containers, with a
    Blizzard fallback.

    mode "phoenix"   Two Blizzard addon aura containers (CustomAuraContainerTemplate, new in 12.1.5; the old
                     SecureAuraHeaderTemplate only loads for the classic game type now), one HELPFUL and one HARMFUL
                     group: Blizzard's secure code filters, sorts, flows the buttons into rows and cancels a buff or a
                     weapon enchant on right-click, in combat too. Weapon enchants join the buff container or get a
                     container of their own. Private auras (boss mechanics the game hides from addons) are shown by
                     the game itself on anchors we place (C_UnitAuras.AddPrivateAuraAnchor). Blizzard's BuffFrame and
                     DebuffFrame are parked.
    mode "blizzard"  Blizzard keeps BuffFrame/DebuffFrame (Edit Mode layout); Phoenix only dresses them (Blizzard.lua).

    Files: Auras.lua (saved shape and pure helpers: flow, sort keys, slots, time formats; shared with the preview and
    the smoke test), Containers.lua (containers, buttons, enchants, private anchors, Test auras, movers), Blizzard.lua.

    Secret values (12.x): Phoenix never reads the aura data in this module. The container fills the widgets we give
    each button - icon texture, a DurationTextBinding with our formatter and colour curve, the cooldown swipe, the
    stack count, the dispel-type border lines - and keeps them secret-safe itself. ]]

local function header(o)
    return {
        enabled = true, size = o.size, perRow = o.perRow, rows = o.rows, hSpacing = 4, vSpacing = o.vSpacing or 16,
        growth = "LEFT", wrap = "DOWN", sort = "TIME", direction = "+", separateOwn = o.separateOwn or 0,
        point = "TOPRIGHT", x = o.x, y = o.y, scale = 1,
    }
end

local DEFAULTS = {
    mode = "phoenix",
    headers = {
        buffs = header({ size = 32, perRow = 12, rows = 3, x = -205, y = -12, separateOwn = 1 }),
        debuffs = header({ size = 40, perRow = 8, rows = 2, x = -205, y = -170 }),
    },
    enchants = "buffs",                 -- buffs | separate | hide
    enchant = { size = 32, spacing = 4, growth = "LEFT", point = "TOPRIGHT", x = -205, y = -130 },
    private = { enabled = true, count = 2, size = 40, spacing = 4, growth = "LEFT", point = "TOPRIGHT", x = -205, y = -260,
                countdown = true, numbers = false },
    -- look (style / iconZoom / border / duration / count are the 2.0 keys, Blizzard mode reads them too)
    style = true, iconZoom = 0.08, shape = "square",
    border = Style.Border({ style = "pixel" }),
    typeBorder = true, buffTypes = false, swipe = true, reverseSwipe = false, desaturate = false,
    duration = Style.Text(11, { outline = "OUTLINE", shadow = false, anchor = "BOTTOM", y = -13 }),
    durationFormat = "short", precise = 5, colorByTime = true,
    colors = { expiring = false, soon = false, normal = false },
    count = Style.Text(12, { outline = "OUTLINE", shadow = false, anchor = "BOTTOMRIGHT", x = 2, y = 1 }),
    cancel = true, tooltips = "always",           -- always | ooc
}
local M = ns:NewModule("Auras", {
    label = "AURAS", desc = "AURAS_DESC", category = "interface", order = 50, reloadOnToggle = true,
    defaults = DEFAULTS,
})
M.DEFAULTS = DEFAULTS
M.HEADERS = { "buffs", "debuffs" }
M.FILTER = { buffs = "HELPFUL", debuffs = "HARMFUL" }

local function plain(v) return not Secret.IsSecret(v) end
M.plain = plain

function M:IsPhoenix() return self.db.mode == "phoenix" end
function M:Header(key) return self.db.headers[key] or self.db.headers.buffs end

---------------------------------------------------------------- colours
local TOKEN = { expiring = "state.danger", soon = "state.warning", normal = "text.primary" }
M.COLOR_TOKENS = TOKEN
function M:Color(which) return Skin:SpecColor(self.db.colors[which], TOKEN[which]) end

-- The timer colour for a plain number of seconds left (the curve below does the same for secret ones).
function M:TimeColor(seconds)
    if not self.db.colorByTime or type(seconds) ~= "number" then return self:Color("normal") end
    if seconds < self.db.precise then return self:Color("expiring") end
    if seconds < 60 then return self:Color("soon") end
    return self:Color("normal")
end

local timeCurve
function M:TimeCurve()
    if timeCurve ~= nil then return timeCurve or nil end
    timeCurve = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType) then return nil end
    local ok, c = pcall(function()
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, CreateColor(self:Color("expiring")))
        curve:AddPoint(math.max(0.1, self.db.precise), CreateColor(self:Color("soon")))
        curve:AddPoint(60, CreateColor(self:Color("normal")))
        return curve
    end)
    if ok and c then timeCurve = c end
    return timeCurve or nil
end
function M:ResetCurves() timeCurve = nil; self.formatter = nil end

---------------------------------------------------------------- pure helpers
-- Plain seconds as text: "short" 2h / 14m / 28 / 4.2, "clock" 1:02:03 / 4:05 / 28 / 4.2, "seconds" 845 / 4.2.
function M.FormatDuration(kind, precise, s)
    if type(s) ~= "number" or s <= 0 then return "" end
    precise = precise or 0
    if s < precise then return ("%.1f"):format(s) end
    if kind == "seconds" then return ("%d"):format(math.ceil(s)) end
    if kind == "clock" then
        if s >= 3600 then return ("%d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s % 3600 / 60), math.floor(s % 60)) end
        if s >= 60 then return ("%d:%02d"):format(math.floor(s / 60), math.floor(s % 60)) end
        return ("%d"):format(math.ceil(s))
    end
    if s >= 86400 then return ("%dd"):format(math.ceil(s / 86400)) end
    if s >= 3600 then return ("%dh"):format(math.ceil(s / 3600)) end
    if s >= 60 then return ("%dm"):format(math.ceil(s / 60)) end
    return ("%d"):format(math.ceil(s))
end

-- The same formats as NumericRuleFormatter breakpoints, for secret durations (DurationTextBinding).
function M.Breakpoints(kind, precise)
    local R = Enum.NumericRuleFormatRounding or { Nearest = 0, Up = 1, Down = 2 }
    local out = {}
    if (precise or 0) > 0 then out[#out + 1] = { threshold = 0, format = "%.1f", rounding = R.Nearest } end
    out[#out + 1] = { threshold = precise or 0, step = 1, rounding = R.Up, format = "%d" }
    if kind == "seconds" then return out end
    if kind == "clock" then
        out[#out + 1] = { threshold = 60, format = "%d:%02d", rounding = R.Down,
            components = { { div = 60, step = 1, rounding = R.Down }, { mod = 60, step = 1, rounding = R.Down } } }
        out[#out + 1] = { threshold = 3600, format = "%d:%02d:%02d", rounding = R.Down,
            components = { { div = 3600, step = 1, rounding = R.Down }, { div = 60, mod = 60, step = 1, rounding = R.Down },
                           { mod = 60, step = 1, rounding = R.Down } } }
        return out
    end
    out[#out + 1] = { threshold = 60, format = "%dm", rounding = R.Up, components = { { div = 60, step = 1, rounding = R.Up } } }
    out[#out + 1] = { threshold = 3600, format = "%dh", rounding = R.Up, components = { { div = 3600, step = 1, rounding = R.Up } } }
    out[#out + 1] = { threshold = 86400, format = "%dd", rounding = R.Up, components = { { div = 86400, step = 1, rounding = R.Up } } }
    return out
end

function M:Formatter()
    if self.formatter ~= nil then return self.formatter or nil end
    self.formatter = false
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    local ok, f = pcall(function()
        local fmt = C_StringUtil.CreateNumericRuleFormatter()
        fmt:SetBreakpoints(M.Breakpoints(self.db.durationFormat, self.db.precise))
        return fmt
    end)
    if ok and f then self.formatter = f end
    return self.formatter or nil
end

-- Where the header puts the first button and which way the next one and the next row go.
-- Button height: "wide" buttons are 70 % as tall as they are wide (the icon is cropped to fit).
function M.Height(h)
    if M.db and M.db.shape == "wide" then return math.floor(h.size * 0.7 + 0.5) end
    return h.size
end

local START = { LEFT = { DOWN = "TOPRIGHT", UP = "BOTTOMRIGHT" }, RIGHT = { DOWN = "TOPLEFT", UP = "BOTTOMLEFT" } }
function M.Layout(h)
    local growth = h.growth == "RIGHT" and "RIGHT" or "LEFT"
    local wrap = h.wrap == "UP" and "UP" or "DOWN"
    local step = h.size + h.hSpacing
    local rowStep = M.Height(h) + h.vSpacing
    return START[growth][wrap], growth == "LEFT" and -step or step, wrap == "DOWN" and -rowStep or rowStep
end

-- The aura container's flow for a header: where the first button sits, which way rows grow and wrap, line length.
function M.Flow(h)
    local point = M.Layout(h)
    return {
        point = point,
        horizontal = h.growth == "RIGHT" and "Right" or "Left",
        vertical = h.wrap == "UP" and "Up" or "Down",
        lineSize = h.perRow * h.size + (h.perRow - 1) * h.hSpacing,
    }
end

-- AuraContainerSortMethod / AuraContainerSortDirection keys for a header's sort settings. "Own first" uses the
-- methods that put auras you cast (or can cast) before the others.
local SORT = { TIME = { "Expiration", "ExpirationOnly" }, NAME = { "Name", "NameOnly" }, INDEX = { "Default", "AuraInstanceIDOnly" } }
function M.SortMethod(h)
    local pair = SORT[h.sort] or SORT.TIME
    return pair[(h.separateOwn == 1) and 1 or 2], h.direction == "-" and "Reverse" or "Normal"
end

-- The holder size a header can fill (Layout mode box, Test auras).
function M.HolderSize(h)
    local w = h.perRow * h.size + (h.perRow - 1) * h.hSpacing
    local ht = h.rows * M.Height(h) + (h.rows - 1) * h.vSpacing
    return w, ht
end

-- Offsets of the first n buttons from the header's start point (the secure code does the same).
function M.Slots(h, n)
    local _, xOff, wrapY = M.Layout(h)
    local out = {}
    local limit = h.perRow * h.rows
    for i = 1, math.min(n, limit) do
        local col, row = (i - 1) % h.perRow, math.floor((i - 1) / h.perRow)
        out[i] = { col * xOff, row * wrapY }
    end
    return out
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    if self:IsPhoenix() then
        self:EnablePhoenix() -- Containers.lua
    else
        self:EnableBlizzard() -- Blizzard.lua
    end
    -- borders that follow Appearance & General restyle with it
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() M:Refresh() end)
end

function M:OnDisable() self:ShowTest(false) end

function M:Refresh()
    self:ResetCurves()
    if self:IsPhoenix() then self:RefreshPhoenix() else self:RefreshBlizzard() end
    if self.testShown then self:ShowTest(true) end
end

function M:OnSettingChanged() self:Refresh() end

-- Test auras: sample buttons where the containers sit (the containers only ever show real auras).
function M:ShowTest(show)
    self.testShown = show and true or nil
    if not self:IsPhoenix() then return true end
    return self:ShowPhoenixTest(show)
end
