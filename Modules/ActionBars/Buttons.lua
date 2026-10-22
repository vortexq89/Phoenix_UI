local _, ns = ...
local Skin, Theme, Media, Secret = ns.Skin, ns.Theme, ns.Media, ns.Secret
local M = ns:GetModule("ActionBars")

--[[ Buttons: how every action, pet and stance button looks and reacts, in both modes. Only textures, font
    strings, alpha, vertex colours and Phoenix's own child regions are touched, never attributes or scripts, and
    region anchors only change out of combat. Feedback follows Blizzard's own updates through post-hooks
    (UpdateUsable, ActionButton_UpdateRangeIndicator, ActionButton_ApplyCooldown, the spell alert manager and
    the assisted-combat highlight), so Phoenix never calls a secure button's methods itself. ]]
local WHITE = Media.textures.WHITE
local textures = Media.textures

M.SHAPES = {
    square = {},
    rounded = { mask = textures.MASK_ROUNDED, ring = textures.RING_ROUNDED },
    circle = { mask = textures.MASK_CIRCLE, ring = textures.RING_CIRCLE, circular = true },
    hexagon = { mask = textures.MASK_HEX, ring = textures.RING_HEX },
}

local list, known = {}, {}
local weak = { __mode = "k" }
local outOfRange = setmetatable({}, weak)
local tinted = setmetatable({}, weak)
local parts = setmetatable({}, weak) -- button -> { mask, ring, slot, masked = { [region] = true }, atlas = {} }

local function partsOf(button)
    local p = parts[button]
    if not p then p = { masked = {}, atlas = {} }; parts[button] = p end
    return p
end

---------------------------------------------------------------- colours (shared with the preview)
local BLIZZ_POWER, BLIZZ_UNUSABLE = { 0.5, 0.5, 1 }, { 0.4, 0.4, 0.4 }

-- state: "range" | "power" | "unusable" -> r, g, b (Phoenix's colour when the feedback is on, Blizzard's if not)
function M:FeedbackColor(state)
    local db, fb = self.db, self.db.feedback
    if state == "range" then return Skin:SpecColor(db.rangeColor, "state.danger") end
    if state == "power" then
        if fb.power then return Skin:SpecColor(fb.powerColor, "state.info") end
        return unpack(BLIZZ_POWER)
    end
    if state == "unusable" then
        if fb.unusable and type(fb.unusableColor) == "table" then return Skin:SpecColor(fb.unusableColor) end
        return unpack(BLIZZ_UNUSABLE)
    end
    return 1, 1, 1
end
function M:RangeColor() return self:FeedbackColor("range") end

function M:BorderColor()
    local b = self.db.border
    if b.style == "ember" and type(b.color) ~= "table" then return Theme:Color("accent.primary") end
    return Skin:SpecColor(b.color, "border.black")
end

local STATE_TOKEN = { pushed = "accent.primary", highlight = "accent.glow", checked = "accent.primary" }
local STATE_ALPHA = { pushed = 0.35, highlight = 0.22, checked = 0.4 }

---------------------------------------------------------------- shape (also used by the preview)
local function mask(p, region)
    if region and p.mask and not p.masked[region] then
        region:AddMaskTexture(p.mask)
        p.masked[region] = true
    end
end

local function unmask(p)
    for region in pairs(p.masked) do region:RemoveMaskTexture(p.mask) end
    wipe(p.masked)
end

--[[ Dress one button. frame, icon and cooldown are its parts; state textures are masked to the shape. Used for
    Blizzard buttons and the preview's own buttons alike. ]]
function M:Dress(frame, icon, cooldown, extra)
    local db = self.db
    local shape = M.SHAPES[db.shape] or M.SHAPES.square
    local p = partsOf(frame)
    Skin:IconZoom(icon, db.iconZoom)
    -- the slot behind the icon (empty slots show it), drawn by us so it follows the shape
    if not p.slot then
        p.slot = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        p.slot:SetTexture(WHITE)
        p.slot:SetAllPoints(icon)
    end
    local r, g, b = Theme:Color("bg.sunken")
    p.slot:SetVertexColor(r, g, b, db.emptyAlpha)
    p.slot:Show()
    if shape.mask then
        if not p.mask then
            p.mask = frame:CreateMaskTexture(nil, "ARTWORK")
            p.mask:SetAllPoints(icon)
        end
        p.mask:SetTexture(shape.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask(p, icon)
        mask(p, p.slot)
        for _, region in ipairs(extra or {}) do mask(p, region) end
        if not p.ring then
            p.ring = frame:CreateTexture(nil, "OVERLAY", nil, 6)
            p.ring:SetAllPoints(icon)
        end
        p.ring:SetTexture(shape.ring)
        p.ring:SetVertexColor(self:BorderColor())
        p.ring:SetShown(db.border.style ~= "none")
        Skin:BorderSpec(frame, { style = "none", shadow = "none" })
        if cooldown then
            cooldown:SetSwipeTexture(shape.mask)
            cooldown:SetUseCircularEdge(shape.circular == true)
        end
    else
        if p.mask then unmask(p) end
        if p.ring then p.ring:Hide() end
        Skin:BorderSpec(frame, db.border, "border.black")
        if cooldown then
            cooldown:SetSwipeTexture(WHITE)
            cooldown:SetUseCircularEdge(false)
        end
    end
    return p
end

-- The 2.0 entry point, kept for the preview: art plus texts.
function M:StyleButton(frame, icon, hotkey, count, name, place, cooldown)
    local db = self.db
    if db.style then self:Dress(frame, icon, cooldown) end
    if hotkey then Skin:TextSpec(hotkey, db.hotkey, "number") end
    if count then Skin:TextSpec(count, db.count, "number") end
    if name then Skin:TextSpec(name, db.macro, "small") end
    if place then
        if hotkey then Skin:Place(hotkey, frame, db.hotkey) end
        if count then Skin:Place(count, frame, db.count) end
        if name then Skin:Place(name, frame, db.macro) end
    end
end

---------------------------------------------------------------- state textures
local function stateTexture(button, which, tex)
    if not tex then return end
    local mode = M.db.feedback[which]
    local p = partsOf(button)
    if p.atlas[which] == nil then p.atlas[which] = tex:GetAtlas() or false end
    if mode == "none" then
        tex:SetAlpha(0)
        return
    end
    tex:SetAlpha(1)
    if mode == "accent" then
        local r, g, b = Theme:Color(STATE_TOKEN[which])
        tex:SetColorTexture(r, g, b, STATE_ALPHA[which])
        tex:SetBlendMode("ADD")
    elseif p.atlas[which] then
        tex:SetAtlas(p.atlas[which])
        tex:SetBlendMode(which == "pushed" and "BLEND" or "ADD")
    end
    if M.db.style then mask(p, tex) end
end

-- Template art is drawn at fixed 45 px sizes; filling the button keeps it right at any size.
local FILL = { "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Flash", "SpellHighlightTexture",
    "NewActionTexture", "Border" }

local function place(button)
    local db = M.db
    for _, key in ipairs(FILL) do
        local r = button[key]
        if r and r.SetAllPoints then r:ClearAllPoints(); r:SetAllPoints(button) end
    end
    if button.HotKey then
        Skin:Place(button.HotKey, button, db.hotkey)
        button.HotKey:SetHeight(db.hotkey.size + 4)
    end
    if button.Count then Skin:Place(button.Count, button, db.count) end
    if button.Name then Skin:Place(button.Name, button, db.macro) end
end

---------------------------------------------------------------- feedback
local function hotkeyNormal()
    local spec = M.db.hotkey
    if type(spec.color) == "table" then return Skin:SpecColor(spec.color) end
    local c = ACTIONBAR_HOTKEY_FONT_COLOR
    if c and c.GetRGB then return c:GetRGB() end
    return 0.6, 0.6, 0.6
end

-- The usable state of an action button, read the way Blizzard's UpdateUsable reads it.
local function usableState(button)
    local action = button.action
    if type(action) ~= "number" or not C_ActionBar.IsUsableAction then return nil end
    local usable, noMana = C_ActionBar.IsUsableAction(action)
    if Secret.IsSecret(usable) or Secret.IsSecret(noMana) then return "secret" end
    if usable then return nil end
    return noMana and "power" or "unusable"
end

local function paint(button)
    if not M:IsEnabled() or not known[button] then return end
    local db, fb = M.db, M.db.feedback
    local kind = known[button].kind
    local state = (outOfRange[button] and db.rangeTint) and "range" or nil
    local usable = (kind == nil) and usableState(button) or nil
    if usable == "secret" then return end -- Blizzard's own colours stay
    state = state or usable
    local icon, hotkey = button.icon, button.HotKey
    local onIcon = fb.target ~= "hotkey"
    local onKey = fb.target ~= "icon"
    if icon then
        if state and (onIcon or state ~= "range") then
            icon:SetVertexColor(M:FeedbackColor(state))
            tinted[button] = true
        elseif kind == nil or tinted[button] then
            -- back to Blizzard's: usable (kind == nil) or the pet slot's own dimming
            local id = button.GetID and button:GetID()
            if kind == "pet" and id and GetPetActionSlotUsable and not GetPetActionSlotUsable(id) then
                icon:SetVertexColor(unpack(BLIZZ_UNUSABLE))
            else
                icon:SetVertexColor(1, 1, 1)
            end
            tinted[button] = nil
        end
    end
    if hotkey and onKey then
        if state then hotkey:SetVertexColor(M:FeedbackColor(state)) else hotkey:SetVertexColor(hotkeyNormal()) end
    end
end
M.Paint = paint

local function onRange(button, checksRange, inRange)
    if not known[button] then return end
    if Secret.IsSecret(checksRange) or Secret.IsSecret(inRange) then return end
    local out = (checksRange and not inRange) or nil
    if out == outOfRange[button] then return end
    outOfRange[button] = out
    paint(button)
end

-- Pet range: Blizzard's pet bar runs its range timer in OnUpdate, which stops once the bar is parked.
function M:TickPetRange()
    if not self:IsPhoenix() or not self.db.rangeTint or not GetPetActionInfo then return end
    for i = 1, 10 do
        local b = _G["PetActionButton" .. i]
        if b and known[b] and b:IsVisible() then
            local _, _, _, _, _, _, _, checksRange, inRange = GetPetActionInfo(i)
            onRange(b, checksRange, inRange)
        end
    end
end

local function onCooldown(normal, info)
    local button = normal and normal.GetParent and normal:GetParent()
    if not button or not known[button] or not M:IsEnabled() then return end
    local db = M.db
    local active, gcd = info and info.isActive, info and info.isOnGCD
    if Secret.IsSecret(active) or Secret.IsSecret(gcd) then return end
    local real = active and not gcd
    if button.icon then
        button.icon:SetDesaturated(db.desatCooldown and real or false)
        button.icon:SetAlpha(real and db.cooldownAlpha or 1)
    end
    normal:SetDrawSwipe(not (gcd and not db.feedback.gcd))
end

---------------------------------------------------------------- proc and assist glows
local function glowColor(spec, token)
    local r, g, b = Skin:SpecColor(spec, token)
    return r, g, b, 1
end

local function onAlert(_, button)
    if not known[button] or not M:IsEnabled() then return end
    local style = M.db.feedback.proc
    local manager = ActionButtonSpellAlertManager
    local has = manager and manager.HasAlert and manager:HasAlert(button)
    local alert = button.SpellActivationAlert
    if alert then
        alert:SetAlpha(style == "blizzard" and 1 or 0)
        if style == "blizzard" and not InCombatLockdown() then
            alert:SetSize((tonumber(button:GetWidth()) or 45) * 1.4, (tonumber(button:GetHeight()) or 45) * 1.4)
        end
    end
    if has and style ~= "blizzard" and style ~= "none" then
        ns.Glow:Show(button, style, glowColor(M.db.feedback.procColor, "accent.glow"))
    else
        ns.Glow:Hide(button)
    end
end

local function onAssist(_, button, shown)
    if not known[button] or not M:IsEnabled() then return end
    local style = M.db.feedback.assist
    local frame = button.AssistedCombatHighlightFrame
    if frame then frame:SetAlpha(style == "blizzard" and 1 or 0) end
    if shown and style ~= "blizzard" and style ~= "none" then
        ns.Glow:Show(button, style, glowColor(nil, "accent.secondary"), "assist")
    else
        ns.Glow:Hide(button, "assist")
    end
end

---------------------------------------------------------------- hotkeys
local function bindingKey(button)
    local action = button.bindingAction or button.commandName
    if not action and known[button] and known[button].kind == "pet" then action = "BONUSACTIONBUTTON" .. button:GetID() end
    local key = action and GetBindingKey(action)
    if not key and button.GetName and button:GetName() then key = GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton") end
    return key
end
M.BindingKey = bindingKey

local function hotkeys(button)
    if not known[button] or not M:IsEnabled() then return end
    local hk = button.HotKey
    if not hk then return end
    local db = M.db
    hk:SetAlpha(db.hotkeys and 1 or 0)
    if db.shortHotkeys then
        local key = bindingKey(button)
        if key then hk:SetText(M.ShortKey(key)) end
    end
    if not InCombatLockdown() then
        Skin:Place(hk, button, db.hotkey)
        hk:SetHeight(db.hotkey.size + 4)
    end
end

---------------------------------------------------------------- per-button style
local CAST = { "SpellCastAnimFrame", "TargetReticleAnimFrame", "InterruptDisplay" }

local function quality(button)
    local db = M.db
    if not db.style then return end
    local p = partsOf(button)
    local r, g, b = M:BorderColor()
    local action = button.action
    if db.qualityBorder and type(action) == "number" and GetActionInfo then
        local kind, id = GetActionInfo(action)
        if kind == "item" and not Secret.IsSecret(id) and C_Item and C_Item.GetItemQualityByID then
            local q = C_Item.GetItemQualityByID(id)
            if type(q) == "number" and q >= 2 and C_Item.GetItemQualityColor then
                r, g, b = C_Item.GetItemQualityColor(q)
            end
        end
    end
    if p.ring and p.ring:IsShown() then p.ring:SetVertexColor(r, g, b) else Skin:SetBorderColor(button, r, g, b, 1) end
end

local function style(button)
    local db, fb = M.db, M.db.feedback
    if db.style then
        Skin:HideRegion(button.NormalTexture)
        Skin:HideRegion(button.SlotArt)
        Skin:HideRegion(button.SlotBackground)
        local p = partsOf(button)
        if button.IconMask and not p.blizzMaskOff then
            button.icon:RemoveMaskTexture(button.IconMask)
            p.blizzMaskOff = true
        end
        M:Dress(button, button.icon, button.cooldown, { button.HighlightTexture, button.CheckedTexture, button.PushedTexture })
        if button.Border then button.Border:SetAlpha(db.equippedBorder and 1 or 0) end
    end
    stateTexture(button, "pushed", button.PushedTexture)
    stateTexture(button, "highlight", button.HighlightTexture)
    stateTexture(button, "checked", button.CheckedTexture)
    if button.HotKey then Skin:TextSpec(button.HotKey, db.hotkey, "number") end
    if button.Count then Skin:TextSpec(button.Count, db.count, "number") end
    if button.Name then
        Skin:TextSpec(button.Name, db.macro, "small")
        button.Name:SetAlpha(db.macroText and 1 or 0)
    end
    local cd = button.cooldown
    if cd then
        cd:SetSwipeColor(0, 0, 0, fb.swipeAlpha)
        cd:SetDrawBling(fb.bling)
    end
    if button.chargeCooldown then button.chargeCooldown:SetHideCountdownNumbers(not db.cooldown.charges) end
    for _, key in ipairs(CAST) do
        local f = button[key]
        if f then
            if fb.hideCast then Skin:HideRegion(f) elseif Skin:IsSkinned(f) then Skin:Restore(f) end
        end
    end
    if InCombatLockdown() then M.placeAfterCombat = true else place(button) end
    hotkeys(button)
    quality(button)
    onAlert(nil, button)
    if button.AssistedCombatHighlightFrame then onAssist(nil, button, button.AssistedCombatHighlightFrame:IsShown()) end
    paint(button)
end

local function tooltip()
    local mode = M:IsEnabled() and M.db.feedback.hideTooltips
    if mode == "always" or (mode == "combat" and InCombatLockdown()) then GameTooltip:Hide() end
end

---------------------------------------------------------------- lifecycle
local function collect()
    for _, def in ipairs(M.BARS) do
        if def.prefix then
            for i = 1, def.count do
                local b = _G[def.prefix .. i]
                if type(b) == "table" and b.GetObjectType and not known[b] then
                    known[b] = def
                    list[#list + 1] = b
                end
            end
        end
    end
end

function M:Buttons() return list end
function M:IsButton(b) return known[b] ~= nil end

local function hookMethod(b, name, fn)
    if type(b[name]) == "function" then hooksecurefunc(b, name, fn) end
end

function M:EnableButtons()
    collect()
    for _, b in ipairs(list) do
        Skin:Register(b, style)
        hookMethod(b, "UpdateUsable", paint)
        hookMethod(b, "UpdateHotkeys", hotkeys)
        hookMethod(b, "SetHotkeys", hotkeys)
        hookMethod(b, "UpdateButtonArt", style)
        hookMethod(b, "Update", quality)
        b:HookScript("OnEnter", tooltip)
    end
    hooksecurefunc("ActionButton_UpdateRangeIndicator", onRange)
    hooksecurefunc("ActionButton_ApplyCooldown", onCooldown)
    if ActionButtonSpellAlertManager then
        hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", onAlert)
        hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", onAlert)
    end
    if AssistedCombatManager and AssistedCombatManager.SetAssistedHighlightFrameShown then
        hooksecurefunc(AssistedCombatManager, "SetAssistedHighlightFrameShown", onAssist)
    end
    ns.Events:On("UPDATE_BINDINGS", self, function() for _, b in ipairs(list) do hotkeys(b) end end)
    ns.Events:Listen("PUI_COMBAT_END", self, function()
        if self.placeAfterCombat then
            self.placeAfterCombat = nil
            for _, b in ipairs(list) do place(b) end
        end
    end)
end

function M:RefreshButtons()
    if not self:IsEnabled() then return end
    for _, b in ipairs(list) do style(b) end
end
