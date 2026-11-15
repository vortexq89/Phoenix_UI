-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L, Skin = ns.L, ns.Skin
local M = ns.modules.Automation

--[[ Gear swap bar (NaowhForever's gear and trinkets bar): one button per equipment set (the set's own icon,
    a glow on the one you wear; click equips it through the game's C_EquipmentSet.UseEquipmentSet) and your two
    trinkets as secure item buttons (click uses the trinket, with its cooldown). Buttons are made and placed out
    of combat only; changes made in combat wait for PLAYER_REGEN_ENABLED. Cooldown values go to the cooldown
    widget as they are, never compared. Movable in Layout mode. No timer: events only. ]]

local OWNER = {}
local bar
local TRINKETS = { 13, 14 }

-- The bar's entries as plain records: sets { id, name, icon, equipped } then trinket slots.
function M.GearBarEntries(trinkets)
    local out = {}
    local E = C_EquipmentSet
    if E and E.GetEquipmentSetIDs then
        for _, id in ipairs(E.GetEquipmentSetIDs() or {}) do
            local name, icon, _, equipped = E.GetEquipmentSetInfo(id)
            if name then out[#out + 1] = { set = id, name = name, icon = icon, equipped = equipped and true or false } end
        end
    end
    if trinkets then
        for _, slot in ipairs(TRINKETS) do out[#out + 1] = { slot = slot } end
    end
    return out
end

local function button(i)
    local b = bar.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetPoint("TOPLEFT", -2, 2)
    b.glow:SetPoint("BOTTOMRIGHT", 2, -2)
    b.glow:SetColorTexture(1, 0.82, 0, 0.35)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.slot then GameTooltip:SetInventoryItem("player", self.slot)
        else GameTooltip:AddLine(self.setName or "", 1, 1, 1); GameTooltip:AddLine(L.GEARBAR_CLICK, 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:HookScript("OnClick", function(self, _, down)
        if down or not self.setID or InCombatLockdown() then return end
        if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then pcall(C_EquipmentSet.UseEquipmentSet, self.setID) end
    end)
    Skin:Register(b, function(self) Skin:Panel(self, "raised", { border = "border.subtle" }) end)
    bar.buttons[i] = b
    return b
end

local function build()
    bar = CreateFrame("Frame", "PhoenixUI_GearBar", UIParent)
    bar.buttons = {}
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("auto.gearBar", bar, L.GEARBAR, {
            active = function() return M:IsEnabled() and M.db.gearBar end,
            get = function() local d = M.db; return { point = d.gearBarPoint, x = d.gearBarX, y = d.gearBarY } end,
            set = function(v)
                local d = M.db
                d.gearBarPoint, d.gearBarX, d.gearBarY = v.point or d.gearBarPoint, v.x or d.gearBarX, v.y or d.gearBarY
            end,
            apply = function() M:UpdateGearBar() end,
            preview = function() M:UpdateGearBar() end,
            reset = function()
                local d, f = M.db, M.defaults
                d.gearBarPoint, d.gearBarX, d.gearBarY = f.gearBarPoint, f.gearBarX, f.gearBarY
                M:UpdateGearBar()
            end,
        })
    end
end

-- Cooldowns and the worn-set glow (safe in combat: no secure changes).
local function paint()
    for _, b in ipairs(bar.buttons) do
        if b:IsShown() then
            if b.slot then
                b.icon:SetTexture(GetInventoryItemTexture and GetInventoryItemTexture("player", b.slot) or 134400)
                local start, dur, on
                if GetInventoryItemCooldown then start, dur, on = GetInventoryItemCooldown("player", b.slot) end
                if start and dur then b.cd:SetCooldown(start, dur, on) end
                b.glow:Hide()
            else
                local _, icon, _, equipped = C_EquipmentSet.GetEquipmentSetInfo(b.setID)
                b.icon:SetTexture(icon or 134400)
                b.glow:SetShown(equipped and true or false)
            end
        end
    end
end

function M:UpdateGearBar()
    local d = self.db
    if not (d.gearBar and self:IsEnabled()) then
        if bar and not InCombatLockdown() then bar:Hide() end
        return
    end
    if InCombatLockdown() then if bar then paint() end return end
    if not bar then build() end
    local list = M.GearBarEntries(d.gearBarTrinkets)
    local size, gap = d.gearBarSize, 4
    for i, e in ipairs(list) do
        local b = button(i)
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("LEFT", (i - 1) * (size + gap), 0)
        b.slot, b.setID, b.setName = e.slot, e.set, e.name
        if e.slot then
            b:SetAttribute("type", "item"); b:SetAttribute("item", tostring(e.slot))
        else
            b:SetAttribute("type", nil); b:SetAttribute("item", nil)
        end
        b:Show()
    end
    for i = #list + 1, #bar.buttons do bar.buttons[i]:Hide() end
    bar:SetSize(math.max(1, #list) * (size + gap) - gap, size)
    bar:ClearAllPoints()
    bar:SetPoint(d.gearBarPoint, UIParent, d.gearBarPoint, d.gearBarX, d.gearBarY)
    bar:SetShown(#list > 0)
    paint()
end
function M:GearBar() return bar end

function M:SetupGearBar()
    if self.gearHooked then return end
    self.gearHooked = true
    local function update() ns.SafeCall(M.UpdateGearBar, M) end
    for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED",
        "EQUIPMENT_SWAP_FINISHED" }) do
        ns.Events:On(e, OWNER, update)
    end
    update()
end

-- live: a changed gear bar setting applies at once (out of combat; in combat it waits for the end of the fight)
local previous = M.OnSettingChanged
function M:OnSettingChanged(key, ...)
    if previous then previous(self, key, ...) end
    if type(key) == "string" and key:find("^gearBar") then ns.SafeCall(M.UpdateGearBar, self) end
end
