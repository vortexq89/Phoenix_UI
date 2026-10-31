local _, ns = ...
local L, Skin = ns.L, ns.Skin
local M = ns.modules.UnitFrames

--[[ Weapon imbues: one icon per weapon that carries a temporary enchant (poisons, oils, sharpening stones,
    shaman weapon spells), with the time left as a cooldown swipe and its count of charges. The icon is the
    weapon's own (GetInventoryItemTexture), never replaced. Plain frames, no secure code, so it can be placed in
    combat; it reads GetWeaponEnchantInfo on UNIT_INVENTORY_CHANGED / WEAPON_ENCHANT_CHANGED only (the swipe
    counts down by itself, no timer of ours runs). Movable in Layout mode. ]]

local SLOTS = { 16, 17 } -- main hand, off hand
local bar

-- { { slot, ms, charges }, … } from GetWeaponEnchantInfo's returns (main hand first).
function M.ImbueList(hasMain, mainMs, mainCharges, _, hasOff, offMs, offCharges)
    local out = {}
    if hasMain then out[#out + 1] = { slot = 16, ms = tonumber(mainMs) or 0, charges = tonumber(mainCharges) or 0 } end
    if hasOff then out[#out + 1] = { slot = 17, ms = tonumber(offMs) or 0, charges = tonumber(offCharges) or 0 } end
    return out
end

local function button(i)
    local b = CreateFrame("Frame", nil, bar)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b.cd:SetReverse(true)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOMRIGHT", -1, 2)
    b:SetScript("OnEnter", function(self)
        if not self.slot then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetInventoryItem("player", self.slot)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.buttons[i] = b
    return b
end

function M:UpdateImbues()
    if not bar then return end
    local s = self.db.imbues
    local read = _G.GetWeaponEnchantInfo
    local list = (self:IsEnabled() and s.show and type(read) == "function") and M.ImbueList(read()) or {}
    local now = GetTime()
    for i = 1, #SLOTS do
        local b = bar.buttons[i] or button(i)
        local e = list[i]
        b:SetShown(e ~= nil)
        if e then
            b.slot = e.slot
            b:SetSize(s.size, s.size)
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (s.size + s.spacing), 0)
            b.icon:SetTexture(GetInventoryItemTexture("player", e.slot))
            b.icon:SetTexCoord(s.zoom, 1 - s.zoom, s.zoom, 1 - s.zoom)
            Skin:Border(b, "border.strong")
            Skin:TextSpec(b.count, s.text, "number", "text.primary")
            b.count:SetText(e.charges > 0 and e.charges or "")
            if e.ms > 0 then b.cd:SetCooldown(now, e.ms / 1000) else b.cd:Clear() end
        end
    end
    bar:SetSize(math.max(1, #list) * (s.size + s.spacing), s.size)
    bar:ClearAllPoints()
    bar:SetPoint(s.point, UIParent, s.point, s.x, s.y)
    bar:SetShown(#list > 0)
end

local function store()
    return {
        active = function() return M:IsEnabled() and M.db.imbues.show end,
        get = function() local t = M.db.imbues; return { point = t.point, x = t.x, y = t.y } end,
        set = function(v) local t = M.db.imbues; t.point, t.x, t.y = v.point or t.point, v.x or t.x, v.y or t.y end,
        apply = function() M:UpdateImbues() end,
        reset = function()
            local d, t = M.DEFAULTS.imbues, M.db.imbues
            t.point, t.x, t.y = d.point, d.x, d.y
            M:UpdateImbues()
        end,
    }
end

function M:SpawnImbues()
    if bar then return end
    bar = CreateFrame("Frame", "PhoenixUI_Imbues", UIParent)
    bar.buttons = {}
    M.imbueBar = bar
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("uf.imbues", bar, L.UF_IMBUES, store()) end
    local function update() ns.SafeCall(M.UpdateImbues, M) end
    ns.Events:On("UNIT_INVENTORY_CHANGED", bar, function(_, _, unit) if unit == "player" then update() end end)
    ns.Events:On("WEAPON_ENCHANT_CHANGED", bar, update)
    ns.Events:On("PLAYER_ENTERING_WORLD", bar, update)
    update()
end
