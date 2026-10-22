local _, ns = ...
local L = ns.L
local Skin = ns.Skin

--[[ SpellHistory: a strip of your most recent successful casts. Spell IDs may be secret in
    restricted content; then the icon is still shown (C_Spell.GetSpellTexture and
    Texture:SetTexture accept secrets) but filtering is skipped. Interrupted and failed casts can join the
    strip greyed out with a red cross (UNIT_SPELLCAST_INTERRUPTED / _FAILED, same spell ID rules). ]]
local M = ns:NewModule("SpellHistory", {
    label = "SPELLHISTORY", desc = "SPELLHISTORY_DESC", category = "combat", order = 40,
    defaults = { count = 6, size = 32, spacing = 4, grow = "RIGHT", fade = 8, inCombatOnly = false,
        border = ns.Style.Border({ style = "solid" }), zoom = 0.08, markFailed = false },
})

local IGNORE = { [6603] = true, [75] = true } -- spellIDs: Auto Attack (Forever: Attack), Auto Shot

local strip
local icons = {}

-- One history icon, real or preview: crop, the border spec, and the failed-cast cross (hidden).
function M:StyleIcon(f)
    Skin:IconZoom(f.tex, self.db.zoom)
    Skin:BorderSpec(f, self.db.border, "border.black")
    if not f.cross then
        f.cross = f:CreateFontString(nil, "OVERLAY")
        f.cross:SetPoint("CENTER")
        f.cross:SetText("×")
        f.cross:Hide()
    end
    Skin:Text(f.cross, "combat", "state.danger", math.max(12, math.floor(f:GetHeight() * 0.8)))
end

-- failed: draw the icon as an interrupted / failed cast
function M.MarkIcon(f, failed)
    f.tex:SetDesaturated(failed and true or false)
    f.tex:SetVertexColor(1, failed and 0.55 or 1, failed and 0.55 or 1)
    if f.cross then f.cross:SetShown(failed and true or false) end
end

local function newIcon(i)
    local f = CreateFrame("Frame", nil, strip)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
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
        M:StyleIcon(f)
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
            M.MarkIcon(f, entry.failed)
            f:SetAlpha(1)
            f:Show()
        else
            f:Hide()
        end
    end
end

local tick
-- The fade ticker only runs while an icon is waiting to fade (started by a cast, stopped by tick).
local function startTicker()
    if not M.ticker and M.db.fade > 0 then M.ticker = C_Timer.NewTicker(0.25, tick) end
end

local function push(texture, failed)
    local db = M.db
    table.insert(history, 1, { texture = texture, expires = GetTime() + db.fade, failed = failed })
    for i = #history, db.count + 1, -1 do history[i] = nil end
    render()
    startTicker()
end

local function record(spellID, failed)
    if M.db.inCombatOnly and not InCombatLockdown() then return end
    if ns.Secret.IsSecret(spellID) then
        push(C_Spell.GetSpellTexture(spellID), failed)
        return
    end
    if IGNORE[spellID] then return end
    local texture = C_Spell.GetSpellTexture(spellID)
    if texture then push(texture, failed) end
end

local function onCast(_, _, _, _, spellID) record(spellID, false) end

-- A failed attempt repeats while a key is held (out of range, not ready): one mark per cast GUID.
local lastFailed
local function onFailed(_, _, _, castGUID, spellID)
    if not M.db.markFailed then return end
    if castGUID and not ns.Secret.IsSecret(castGUID) then
        if castGUID == lastFailed then return end
        lastFailed = castGUID
    end
    record(spellID, true)
end

function tick()
    local now, waiting = GetTime(), false
    for i, entry in ipairs(history) do
        local f = icons[i]
        if f and f:IsShown() and now >= entry.expires and not f.fade:IsPlaying() then f.fade:Play() end
        if f and f:IsShown() and now < entry.expires then waiting = true end
    end
    if (not waiting or M.db.fade <= 0) and M.ticker then M.ticker:Cancel(); M.ticker = nil end
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
    ns.Events:OnUnit("UNIT_SPELLCAST_INTERRUPTED", self, onFailed, "player")
    ns.Events:OnUnit("UNIT_SPELLCAST_FAILED", self, onFailed, "player")
    startTicker()
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
    startTicker()
end

