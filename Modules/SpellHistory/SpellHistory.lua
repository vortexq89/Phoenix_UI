local _, ns = ...
local L = ns.L
local Skin = ns.Skin

--[[ SpellHistory: a strip of your most recent successful casts. Spell IDs may be secret in
    restricted content; then the icon is still shown (C_Spell.GetSpellTexture and
    Texture:SetTexture accept secrets) but filtering is skipped. ]]
local M = ns:NewModule("SpellHistory", {
    label = "SPELLHISTORY", desc = "SPELLHISTORY_DESC", category = "combat", order = 40,
    defaults = { count = 6, size = 32, spacing = 4, grow = "RIGHT", fade = 8, inCombatOnly = false },
})

-- Auto Attack and Auto Shot
local IGNORE = { [6603] = true, [75] = true }

local strip
local icons = {}

local function newIcon(i)
    local f = CreateFrame("Frame", nil, strip)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    Skin:Icon(f.tex)
    Skin:Border(f, "border.black")
    Skin:Shadow(f, 4, nil, 0.45)
    f.fade = f:CreateAnimationGroup()
    local a = f.fade:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(0.6)
    f.fade:SetScript("OnFinished", function() f:Hide() end)
    icons[i] = f
    return f
end

local function layout()
    local db = M.db
    local horiz = db.grow == "RIGHT" or db.grow == "LEFT"
    local sign = (db.grow == "RIGHT" or db.grow == "UP") and 1 or -1
    local span = db.count * db.size + (db.count - 1) * db.spacing
    if horiz then strip:SetSize(span, db.size) else strip:SetSize(db.size, span) end
    for i = 1, db.count do
        local f = icons[i] or newIcon(i)
        f:SetSize(db.size, db.size)
        f:ClearAllPoints()
        local offset = (i - 1) * (db.size + db.spacing) * sign
        local anchor = sign > 0 and (horiz and "LEFT" or "BOTTOM") or (horiz and "RIGHT" or "TOP")
        f:SetPoint(anchor, strip, anchor, horiz and offset or 0, horiz and 0 or offset)
    end
    for i = db.count + 1, #icons do icons[i]:Hide() end
end

-- history[1] is the newest cast. Textures are kept here rather than read back from the icons: a
-- texture from a secret spell ID is itself secret, so it may be passed to SetTexture but never tested.
local history = {}

local function render()
    local db = M.db
    local now = GetTime()
    for i = 1, db.count do
        local f, entry = icons[i], history[i]
        f.fade:Stop()
        if entry and (db.fade <= 0 or now < entry.expires) then
            f.tex:SetTexture(entry.texture)
            f:SetAlpha(1)
            f:Show()
        else
            f:Hide()
        end
    end
end

local function push(texture)
    local db = M.db
    table.insert(history, 1, { texture = texture, expires = GetTime() + db.fade })
    for i = #history, db.count + 1, -1 do history[i] = nil end
    render()
end

local function onCast(_, _, _, _, spellID)
    if M.db.inCombatOnly and not InCombatLockdown() then return end
    if ns.Secret.IsSecret(spellID) then
        push(C_Spell.GetSpellTexture(spellID))
        return
    end
    if IGNORE[spellID] then return end
    local texture = C_Spell.GetSpellTexture(spellID)
    if texture then push(texture) end
end

local function tick()
    if M.db.fade <= 0 then return end
    local now = GetTime()
    for i, entry in ipairs(history) do
        local f = icons[i]
        if f and f:IsShown() and now >= entry.expires and not f.fade:IsPlaying() then f.fade:Play() end
    end
end

function M:OnEnable()
    if not strip then
        strip = CreateFrame("Frame", nil, UIParent)
        strip:SetFrameStrata("MEDIUM")
        strip:SetClampedToScreen(true)
        layout()
        for _, f in ipairs(icons) do f:Hide() end
        ns.EditMode:Register(strip, { key = "SpellHistory", name = ns.title .. " – " .. L.SPELLHISTORY,
            default = { point = "CENTER", x = 0, y = -180 } })
    end
    strip:Show()
    ns.Events:OnUnit("UNIT_SPELLCAST_SUCCEEDED", self, onCast, "player")
    self.ticker = C_Timer.NewTicker(0.25, tick)
end

function M:OnDisable()
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    if strip then strip:Hide() end
end

function M:Refresh()
    if not strip then return end
    layout()
    for i = #history, self.db.count + 1, -1 do history[i] = nil end
    render()
end

