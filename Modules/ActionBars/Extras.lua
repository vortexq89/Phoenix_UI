local _, ns = ...
local L, Skin = ns.L, ns.Skin
local M = ns:GetModule("ActionBars")

--[[ Extras: the extra action and zone ability buttons (skin, scale, artwork), Phoenix's vehicle exit button,
    the micro menu and bag bar modes, and the extra item bar (quest items and a custom item list on Phoenix's own
    secure item buttons). Blizzard's extra buttons and the menus stay Blizzard's: only textures, alpha, mouse
    and (out of combat) scale change. ]]

---------------------------------------------------------------- extra action / zone ability
local function skinExtraButton(button, icon)
    if not button or not icon then return end
    local db = M.db
    if db.extra.skin then
        Skin:IconZoom(icon, db.iconZoom)
        Skin:BorderSpec(button, db.border, "border.black")
        Skin:HideRegion(button.NormalTexture)
    end
end

local function zoneButtons()
    local z = ZoneAbilityFrame
    if not z or not M:IsEnabled() then return end
    local db = M.db
    if z.Style then
        if db.extra.hideArt then Skin:HideRegion(z.Style) elseif Skin:IsSkinned(z.Style) then Skin:Restore(z.Style) end
    end
    local c = z.SpellButtonContainer
    if c and c.EnumerateActive then
        for b in c:EnumerateActive() do skinExtraButton(b, b.Icon) end
    end
end

local function scaleExtras()
    local s = M.db.extra.scale
    for _, f in ipairs({ ExtraActionBarFrame, ZoneAbilityFrame }) do
        if f and f.SetScale and not f:IsForbidden() then f:SetScale(s) end
    end
end

local hookedZone
local function extras()
    local db = M.db
    local b = ExtraActionButton1
    if b then
        skinExtraButton(b, b.icon)
        if b.style then
            if db.extra.hideArt then Skin:HideRegion(b.style) elseif Skin:IsSkinned(b.style) then Skin:Restore(b.style) end
        end
        if b.HotKey then Skin:TextSpec(b.HotKey, db.hotkey, "number") end
    end
    if ZoneAbilityFrame and not hookedZone and ZoneAbilityFrame.UpdateDisplayedZoneAbilities then
        hookedZone = true
        hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", zoneButtons)
    end
    zoneButtons()
    ns.Combat:Run("ab.extraScale", scaleExtras)
end

---------------------------------------------------------------- vehicle exit (phoenix mode)
-- Blizzard's leave button lives on the main bar, which is parked; this one follows the same rules
-- (MainMenuBarVehicleLeaveButtonMixin): exit a vehicle while the main bar is up, or land early from a taxi.
local exit
local function exitShown()
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    if not (CanExitVehicle and CanExitVehicle()) then return false end
    local ab = C_ActionBar
    return not (ab and ((ab.HasOverrideActionBar and ab.HasOverrideActionBar()) or (ab.HasVehicleActionBar and ab.HasVehicleActionBar())))
end
M.VehicleExitShown = exitShown

local function updateExit()
    if not exit then return end
    local on = M.db.vehicle.enabled and exitShown()
    exit:SetShown(on)
    exit:Enable()
end

local function buildExit()
    exit = CreateFrame("Button", "PhoenixUI_VehicleExit", UIParent)
    exit:SetFrameStrata("MEDIUM")
    exit:SetPoint("BOTTOM", UIParent, "BOTTOM", 260, 26)
    exit:SetNormalTexture([[Interface\Vehicles\UI-Vehicles-Button-Exit-Up]])
    exit:SetPushedTexture([[Interface\Vehicles\UI-Vehicles-Button-Exit-Down]])
    exit:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")
    exit:RegisterForClicks("AnyUp")
    exit:SetScript("OnClick", function(self)
        if UnitOnTaxi("player") then
            TaxiRequestEarlyLanding()
            self:Disable()
        else
            VehicleExit()
        end
    end)
    exit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(UnitOnTaxi("player") and TAXI_CANCEL or LEAVE_VEHICLE)
        GameTooltip:Show()
    end)
    exit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    for _, ev in ipairs({ "UPDATE_BONUS_ACTIONBAR", "UPDATE_MULTI_CAST_ACTIONBAR", "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE", "VEHICLE_UPDATE", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
        "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD" }) do
        ns.Events:On(ev, exit, updateExit)
    end
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("ab.vehicle", exit, L.AB_VEHICLE_EXIT) end
    exit:Hide()
end

local function vehicle()
    if not M:IsPhoenix() then return end
    if not exit then buildExit() end
    local s = M.db.vehicle.size
    exit:SetSize(s, s)
    Skin:BorderSpec(exit, M.db.border, "border.black")
    updateExit()
end

---------------------------------------------------------------- micro menu and bag bar
-- "bar" Blizzard's · "mouseover" shows on hover · "hidden" invisible and click-through. Alpha and mouse only.
local MENUS = {
    micro = function() return MicroMenuContainer end,
    bags = function() return BagsBar end,
}
local menuTicker

local function setMouse(frame, on)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.EnableMouse and not child:IsForbidden() and not child:IsProtected() then child:EnableMouse(on) end
        if child == MicroMenu then setMouse(child, on) end
    end
end

local function menus()
    local any = false
    for key, get in pairs(MENUS) do
        local f = get()
        if f and not f:IsForbidden() then
            local mode = M.db[key]
            f:SetAlpha(mode == "hidden" and 0 or (mode == "mouseover" and (f:IsMouseOver() and 1 or 0)) or 1)
            setMouse(f, mode ~= "hidden")
            if mode == "mouseover" then any = true end
        end
    end
    if any and not menuTicker then
        menuTicker = C_Timer.NewTicker(0.15, function()
            for key, get in pairs(MENUS) do
                local f = get()
                if f and M.db[key] == "mouseover" then f:SetAlpha(f:IsMouseOver(8, -8, -8, 8) and 1 or 0) end
            end
        end)
    elseif not any and menuTicker then
        menuTicker:Cancel()
        menuTicker = nil
    end
end

---------------------------------------------------------------- extra item bar (phoenix mode)
M.itemIDs = {}
local itemButtons = {}

-- "6948, 5512 ; 211880" -> { 6948, 5512, 211880 } (anything that is not a number is ignored)
function M.ParseItems(text)
    local out, seen = {}, {}
    for id in tostring(text or ""):gmatch("%d+") do
        id = tonumber(id)
        if id and id > 0 and not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
    return out
end

local function usableItem(id)
    return C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(id) ~= nil
end

local function scanItems()
    local ids, seen = {}, {}
    local db = M.db.items
    if db.quest and C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, (NUM_BAG_SLOTS or 4) + 1 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local id = info and info.itemID
                if id and not seen[id] and C_Container.GetContainerItemQuestInfo then
                    local q = C_Container.GetContainerItemQuestInfo(bag, slot)
                    if q and (q.isQuestItem or q.questID) and usableItem(id) then seen[id] = true; ids[#ids + 1] = id end
                end
            end
        end
    end
    for _, id in ipairs(M.ParseItems(db.list)) do
        if not seen[id] and (C_Item.GetItemCount(id) or 0) > 0 then seen[id] = true; ids[#ids + 1] = id end
    end
    M.itemIDs = ids
end

local function paintItem(btn)
    local id = btn.itemID
    if not id then return end
    btn.icon:SetTexture(C_Item.GetItemIconByID(id))
    local n = C_Item.GetItemCount(id, false, true) or 0
    btn.count:SetText(n > 1 and n or "")
    local start, duration, enable = C_Container.GetItemCooldown(id)
    if enable and duration and duration > 0 then btn.cooldown:SetCooldown(start, duration) else btn.cooldown:Clear() end
end

local function itemButton(parent, i)
    local btn = itemButtons[i]
    if btn then return btn end
    btn = CreateFrame("Button", "PhoenixUI_ItemButton" .. i, parent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "item")
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.count = btn:CreateFontString(nil, "OVERLAY")
    btn:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemID)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    itemButtons[i] = btn
    return btn
end

-- Called by the bar engine (out of combat) with the shared layout.
function M:LayoutItems(h, points, w, hh, pad, n)
    for i, btn in ipairs(itemButtons) do if i > n then btn:Hide(); btn.itemID = nil end end
    for i = 1, n do
        local btn = itemButton(h, i)
        local id = M.itemIDs[i]
        btn.itemID = id
        btn:SetAttribute("item", "item:" .. id)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", h, "TOPLEFT", pad + points[i][1], -(pad + points[i][2]))
        btn:SetSize(w, hh)
        self:Dress(btn, btn.icon, btn.cooldown)
        Skin:TextSpec(btn.count, self.db.count, "number")
        Skin:Place(btn.count, btn, self.db.count)
        btn:EnableMouse(not self.db.bars.items.clickThrough)
        btn:Show()
        paintItem(btn)
    end
end

local function itemsNow()
    scanItems()
    M:RefreshBar("items")
end

function M:RefreshItems()
    if not self:IsEnabled() or not self:IsPhoenix() or not self.db.bars.items.enabled then return end
    ns.Combat:Run("ab.items", itemsNow)
end

---------------------------------------------------------------- lifecycle
function M:RefreshExtras()
    if not self:IsEnabled() then return end
    extras()
    vehicle()
    menus()
end

function M:EnableExtras()
    self:RefreshExtras()
    ns.Events:On("UPDATE_EXTRA_ACTIONBAR", self, extras)
    ns.Events:On("ADDON_LOADED", self, function(_, _, name) if name == "Blizzard_ZoneAbility" then extras() end end)
    if self:IsPhoenix() then
        local pending
        local function soon()
            if pending then return end
            pending = true
            C_Timer.After(0.3, function() pending = nil; self:RefreshItems() end)
        end
        ns.Events:On("BAG_UPDATE_DELAYED", self, soon)
        ns.Events:On("QUEST_ACCEPTED", self, soon)
        ns.Events:On("QUEST_REMOVED", self, soon)
        local function repaint() for _, b in ipairs(itemButtons) do if b:IsShown() then paintItem(b) end end end
        ns.Events:On("BAG_UPDATE_COOLDOWN", self, repaint)
        ns.Events:On("ITEM_COUNT_CHANGED", self, repaint)
        self:RefreshItems()
    end
end
