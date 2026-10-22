local _, ns = ...
local Skin, Secret = ns.Skin, ns.Secret

--[[ CooldownText: Blizzard draws the countdown numbers on every cooldown frame (it handles secret durations
    natively); Phoenix switches them on through the CVar and styles them: font, size (optionally scaled to the
    icon), outline, shadow, colour, decimals below a threshold, a minimum duration, and hiding them on aura icons.
    Every cooldown frame is reached through post-hooks on the Cooldown widget's SetCooldown family, so nothing
    is replaced and Blizzard's own calls stay secure.

    Colour by remaining time (action buttons): Phoenix shows its own number through a duration text binding
    (C_DurationUtil) fed the action's duration object, with a step colour curve (expiring / seconds / minutes).
    The game evaluates the secret remaining time itself; Phoenix never reads it. If the binding API is
    missing, Blizzard's own number stays. ]]
local M = ns:NewModule("CooldownText", {
    label = "COOLDOWNTEXT", desc = "COOLDOWNTEXT_DESC", category = "combat", order = 10,
    defaults = {
        font = "", size = 16, outline = "OUTLINE", shadow = false, color = { r = 1, g = 0.82, b = 0.35 },
        scale = true, decimals = 0, minDuration = 1.5, hideAuras = false,
        byRemaining = false, expiring = 3,
        colors = { expiring = false, seconds = false, minutes = false },
    },
})

local weak = { __mode = "k" }
local styled = setmetatable({}, weak)   -- cooldown -> its countdown FontString
local hidden = setmetatable({}, weak)   -- cooldown -> the hide-numbers value Blizzard had before we hid it
local bindings = setmetatable({}, weak) -- cooldown -> { fs, binding }
M.REFERENCE = 36 -- icon size the font size is set for when "scale with icon size" is on

---------------------------------------------------------------- style (shared with the options preview)
function M:SizeFor(width)
    local db = self.db
    local size = db.size
    if db.scale and type(width) == "number" and width > 0 then
        size = math.floor(db.size * width / self.REFERENCE + 0.5)
        size = math.max(8, math.min(db.size * 2, size))
    end
    return size
end

function M:ColorOf(which)
    local tokens = { expiring = "state.danger", seconds = "state.warning", minutes = "text.primary" }
    return Skin:SpecColor(self.db.colors[which], tokens[which])
end

local spec = {}
local function paint(fs, size)
    local db = M.db
    spec.font, spec.size, spec.outline, spec.shadow, spec.color = db.font, size or db.size, db.outline, db.shadow, db.color
    Skin:TextSpec(fs, spec, "combat")
end
M.PaintCountdown = paint

-- Action bars can ask for their own number size (Action Bars → Text → Cooldown numbers).
local function barSize(cd)
    local ab = ns.modules and ns.modules.ActionBars
    local parent = cd.GetParent and cd:GetParent()
    if ab and ab:IsEnabled() and ab.IsButton and parent and ab:IsButton(parent) then
        local s = ab.db.cooldown.size
        if type(s) == "number" and s > 0 then return s end
    end
end

local claimed = setmetatable({}, weak) -- cooldown -> true: another module paints these numbers (Cooldown Manager)

local function style(cd)
    if not cd or claimed[cd] or cd:IsForbidden() or not cd.GetCountdownFontString then return end
    local fs = cd:GetCountdownFontString()
    if not fs then return end
    local db = M.db
    styled[cd] = fs
    local aura = cd.GetUseAuraDisplayTime and cd:GetUseAuraDisplayTime()
    if db.hideAuras and aura == true then
        if hidden[cd] == nil then
            hidden[cd] = cd:GetHideCountdownNumbers() and true or false
            cd:SetHideCountdownNumbers(true)
        end
    elseif hidden[cd] ~= nil then
        cd:SetHideCountdownNumbers(hidden[cd])
        hidden[cd] = nil
    end
    local w = tonumber(cd:GetWidth())
    paint(fs, barSize(cd) or M:SizeFor(w))
    cd:SetCountdownMillisecondsThreshold(db.decimals)
    cd:SetMinimumCountdownDuration(math.floor(db.minDuration * 1000 + 0.5))
end
M.Style = style

-- One owner per number: a module that paints a cooldown's countdown itself claims it (on = true) and Cooldown Text
-- leaves it alone (restoring Blizzard's font if it had styled it); releasing it hands it back.
function M:Claim(cd, on)
    if not cd then return end
    if on then
        if claimed[cd] then return end
        claimed[cd] = true
        local fs = styled[cd]
        if fs then Skin:Restore(fs); styled[cd] = nil end
        if hidden[cd] ~= nil then cd:SetHideCountdownNumbers(hidden[cd]); hidden[cd] = nil end
    elseif claimed[cd] then
        claimed[cd] = nil
        if self:IsEnabled() then style(cd) end
    elseif self:IsEnabled() and not styled[cd] then
        style(cd)
    end
end

---------------------------------------------------------------- colour by remaining (action buttons)
local curve, formatter

local function buildCurve()
    curve, formatter = nil, nil
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding) then return end
    local ok = pcall(function()
        local db = M.db
        local c = C_CurveUtil.CreateColorCurve()
        c:SetType(Enum.LuaCurveType.Step)
        c:AddPoint(0, CreateColor(M:ColorOf("expiring")))
        c:AddPoint(math.max(0.1, db.expiring), CreateColor(M:ColorOf("seconds")))
        c:AddPoint(60, CreateColor(M:ColorOf("minutes")))
        local f = C_StringUtil.CreateSecondsFormatter()
        f:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
        f:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.StripIgnoreLocale)
        f:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
        f:SetDesiredUnitCount(1)
        if db.decimals > 0 then f:SetMillisecondsThreshold(db.decimals) end
        curve, formatter = c, f
    end)
    if not ok then curve, formatter = nil, nil end
end

local function release(cd)
    local b = bindings[cd]
    if not b then return end
    pcall(b.binding.SetEnabled, b.binding, false)
    b.fs:Hide()
    if b.restore ~= nil then cd:SetHideCountdownNumbers(b.restore); b.restore = nil end
end

local function bindingFor(cd)
    local b = bindings[cd]
    if b then return b end
    local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
    if not ok or not binding then return nil end
    b = { binding = binding, fs = cd:CreateFontString(nil, "OVERLAY") }
    b.fs:SetPoint("CENTER")
    bindings[cd] = b
    return b
end

local function remaining(cd, info)
    if not M.db.byRemaining or not curve then release(cd); return end
    local button = cd:GetParent()
    local action = button and button.action
    if type(action) ~= "number" or not C_ActionBar.GetActionCooldownDuration then return end
    local active, gcd = info and info.isActive, info and info.isOnGCD
    if Secret.IsSecret(active) or Secret.IsSecret(gcd) then return end
    local b = bindingFor(cd)
    if not b then return end
    if b.restore == nil then b.restore = cd:GetHideCountdownNumbers() and true or false end
    cd:SetHideCountdownNumbers(true)
    if active and not gcd then
        local ok = pcall(function()
            local binding = b.binding
            binding:SetFontString(b.fs)
            binding:SetFormatter(formatter)
            binding:SetTextColorCurve(curve, Enum.DurationTextBindingProperty.RemainingDuration)
            binding:SetDuration(C_ActionBar.GetActionCooldownDuration(action, true))
            binding:SetEnabled(true)
        end)
        paint(b.fs, barSize(cd) or M:SizeFor(tonumber(cd:GetWidth())))
        b.fs:SetShown(ok)
        if not ok then release(cd) end
    else
        pcall(b.binding.SetEnabled, b.binding, false)
        b.fs:Hide()
    end
end

---------------------------------------------------------------- hooks
local function onSet(cd)
    if M:IsEnabled() and cd and not styled[cd] then style(cd) end
end

local function onApply(normal, info)
    if not M:IsEnabled() or not normal or normal:IsForbidden() then return end
    if not styled[normal] then style(normal) end
    remaining(normal, info)
end

local hooked
local function hookAll()
    hooked = true
    hooksecurefunc("ActionButton_ApplyCooldown", onApply)
    -- every other cooldown frame: the widget's own setters (post-hooks only)
    local first = _G["ActionButton1"]
    local sample = (first and first.cooldown) or CreateFrame("Cooldown")
    local meta = getmetatable(sample)
    local index = meta and meta.__index
    if type(index) == "table" then
        for _, name in ipairs({ "SetCooldown", "SetCooldownDuration", "SetCooldownFromDurationObject",
            "SetCooldownFromExpirationTime", "SetCooldownUNIX" }) do
            if type(index[name]) == "function" then hooksecurefunc(index, name, onSet) end
        end
    end
end

function M:OnEnable()
    if not hooked then hookAll() end
    buildCurve()
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() self:Refresh() end)
end

function M:OnDisable()
    for cd, fs in pairs(styled) do
        Skin:Restore(fs)
        if hidden[cd] ~= nil then cd:SetHideCountdownNumbers(hidden[cd]); hidden[cd] = nil end
        release(cd)
        styled[cd] = nil
    end
end

function M:Refresh()
    buildCurve()
    for cd in pairs(styled) do style(cd) end
    if not self.db.byRemaining then for cd in pairs(bindings) do release(cd) end end
end
