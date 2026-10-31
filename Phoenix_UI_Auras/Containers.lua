local _, ns = ...
local L, Skin = ns.L, ns.Skin
local M = ns.modules.Auras

--[[ Phoenix mode: the player's buffs and debuffs on Blizzard's 12.1.5 addon aura containers (CustomAuraContainerTemplate,
    Blizzard_AuraContainer), weapon enchants, private aura anchors, Test auras, movers.

    The old SecureAuraHeaderTemplate only loads for the classic game type now, so retail and Forever use the aura
    container: Blizzard's secure code reads the auras, filters, sorts, flows them into rows, creates the buttons and
    cancels a buff (or weapon enchant) on right-click - in combat too - and fills the widgets we hand it (icon,
    duration text binding with our formatter and colour curve, cooldown swipe, stack count, dispel-type border lines).
    We never read the aura data. Buttons we dress are only touched through pcall afterwards: the container denies
    addon access to them while auras are secret. The Test auras and the options preview use plain sample buttons
    built by the same Dress/Style code. ]]

local holders, containers = {}, {}
M.holders, M.containers = holders, containers
M.headers = containers -- (older name, kept for the smoke test and Layout code)
local buttons = setmetatable({}, { __mode = "k" }) -- every button we dressed -> kind ("buffs" | "debuffs" | "enchant")
M.buttons = buttons
local privateAnchors = {}
M.privateAnchors = privateAnchors
local parking, spawned
local tests = {}

local WHITE = ns.Media.textures.WHITE
local SIDES = { "top", "bottom", "left", "right" }
local TEXT_PROP = (Enum and Enum.DurationTextBindingProperty) or {}
local ENCHANT_SLOTS = { "MainHand", "OffHand" }

---------------------------------------------------------------- Blizzard parking
local function keepHidden(self)
    if spawned and M:IsEnabled() and M:IsPhoenix() then ns.Combat:Run("auras.park." .. tostring(self), self.Hide, self) end
end
local function parkBlizzard()
    if not parking then
        parking = CreateFrame("Frame", "PhoenixUI_AuraParking", UIParent)
        parking:Hide()
    end
    for _, fr in ipairs({ BuffFrame, DebuffFrame }) do
        if type(fr) == "table" and fr.Hide and not fr:IsForbidden() then
            fr:UnregisterAllEvents()
            fr:Hide()
            fr:HookScript("OnShow", keepHidden)
        end
    end
end

---------------------------------------------------------------- button look
local function lines(parent)
    local t = {}
    for _, side in ipairs(SIDES) do
        local tex = parent:CreateTexture(nil, "OVERLAY", nil, 6)
        tex:SetTexture(WHITE)
        t[side] = tex
    end
    t.top:SetPoint("TOPLEFT"); t.top:SetPoint("TOPRIGHT"); t.top:SetHeight(1)
    t.bottom:SetPoint("BOTTOMLEFT"); t.bottom:SetPoint("BOTTOMRIGHT"); t.bottom:SetHeight(1)
    t.left:SetPoint("TOPLEFT"); t.left:SetPoint("BOTTOMLEFT"); t.left:SetWidth(1)
    t.right:SetPoint("TOPRIGHT"); t.right:SetPoint("BOTTOMRIGHT"); t.right:SetWidth(1)
    return t
end

local function typeColor(b, r, g, bl, a)
    for _, side in ipairs(SIDES) do b.TypeLines[side]:SetVertexColor(r, g, bl, a or 1) end
end

local function showType(b, on)
    for _, side in ipairs(SIDES) do b.TypeLines[side]:SetShown(on) end
end

-- Builds the widgets on a button (an aura container button, or a plain test/preview button).
function M:Dress(b, kind, native)
    if b.puiDressed then return b end
    b.puiDressed = true
    b.puiNative = native or nil
    b.kind = kind
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAllPoints()
    b.Edge = CreateFrame("Frame", nil, b)
    b.Edge:SetAllPoints()
    b.Cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.Cooldown:SetAllPoints()
    b.Cooldown:SetDrawEdge(false)
    b.Cooldown:SetHideCountdownNumbers(true)
    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b.Cooldown:GetFrameLevel() + 2)
    b.Over = over
    b.TypeLines = lines(over)
    b.Duration = over:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.Count = over:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not native then
        b:HookScript("OnEnter", function(self) M:Tooltip(self) end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    buttons[b] = kind
    self:Style(b)
    return b
end

-- The look of one button (settings changes; no aura data).
function M:Style(b)
    local db = self.db
    local wide = db.shape == "wide"
    Skin:IconZoom(b.Icon, db.iconZoom)
    if wide then
        local z = db.iconZoom
        local crop = (1 - 2 * z) * 0.15
        b.Icon:SetTexCoord(z, 1 - z, z + crop, 1 - z - crop)
    end
    Skin:BorderSpec(b.Edge, db.border, "border.black")
    local size = math.max(1, (db.border.size or 1))
    for _, side in ipairs({ "top", "bottom" }) do b.TypeLines[side]:SetHeight(size) end
    for _, side in ipairs({ "left", "right" }) do b.TypeLines[side]:SetWidth(size) end
    b.Cooldown:SetDrawSwipe(db.swipe)
    b.Cooldown:SetReverse(db.reverseSwipe)
    Skin:TextSpec(b.Duration, db.duration, "number", "text.primary")
    Skin:Place(b.Duration, b.Over, db.duration)
    b.Duration:SetShown(db.duration.show ~= false)
    Skin:TextSpec(b.Count, db.count, "number", "text.primary")
    Skin:Place(b.Count, b.Over, db.count)
    b.Count:SetShown(db.count.show ~= false)
end

---------------------------------------------------------------- container buttons
-- What the container fills on a button we dressed, from the current settings (called again on settings changes).
local function dispelOptions(kind)
    local db = M.db
    local style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
    return { style = style, showWhenHarmful = kind ~= "buffs", showWhenHelpful = kind == "buffs" and db.buffTypes or false,
        showWithoutDispelType = kind == "debuffs" }
end

local function textOptions()
    local o = { textFormatter = M:Formatter() }
    local curve = M.db.colorByTime and M:TimeCurve()
    if curve and TEXT_PROP.RemainingDuration then o.textColor = { curve = curve, property = TEXT_PROP.RemainingDuration } end
    return o
end

local function hookUp(b, kind)
    local db = M.db
    b:SetIcon(b.Icon)
    if db.duration.show ~= false then b:SetDurationText(b.Duration, textOptions()) else b:ClearDurationText() end
    if db.swipe then b:SetDurationCooldown(b.Cooldown) else b:ClearDurationCooldown() end
    if db.count.show ~= false then b:SetApplicationCount(b.Count) else b:ClearApplicationCount() end
    b:ClearDispelTypeTextures()
    if db.typeBorder and kind ~= "enchant" and (kind == "debuffs" or db.buffTypes) then
        local o = dispelOptions(kind)
        for _, side in ipairs(SIDES) do b:AddDispelTypeTexture(b.TypeLines[side], o) end
    end
    b:SetCancelAuraButtons((db.cancel and kind ~= "debuffs") and "RightButtonUp" or nil)
    b:SetHideTooltipInCombat(db.tooltips == "ooc")
    b:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT")
    b.Icon:SetDesaturated(kind == "debuffs" and db.desaturate or false)
end

local function sizeOf(kind)
    if kind == "enchant" and M.db.enchants == "separate" then return M.db.enchant.size, M.db.enchant.size end
    local h = M:Header(kind == "debuffs" and "debuffs" or "buffs")
    return h.size, M.Height(h)
end

-- Runs (securecall) right after the container creates a button: our widgets, then the container's hooks.
local function initializer(kind)
    return function(b)
        M:Dress(b, kind, true)
        b:SetSize(sizeOf(kind))
        local ok, err = pcall(hookUp, b, kind)
        if not ok then ns:Debug("auras: " .. tostring(err)) end
    end
end

M.Initializer = initializer

local function restyle(b, kind)
    return pcall(function()
        M:Style(b)
        b:SetSize(sizeOf(kind))
        hookUp(b, kind)
    end)
end

-- Tooltip for the plain sample buttons (container buttons use Blizzard's own aura tooltip).
function M:Tooltip(b)
    if not b.sample or (self.db.tooltips == "ooc" and InCombatLockdown()) then return end
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(b.sample.name or "")
    GameTooltip:Show()
end

---------------------------------------------------------------- holders and movers
local function store(key, db)
    return {
        active = function()
            if not (M:IsEnabled() and M:IsPhoenix()) then return false end
            if key == "enchants" then return M.db.enchants == "separate" end
            if key == "private" then return M.db.private.enabled end
            return M:Header(key).enabled
        end,
        get = function() local s = db(); return { point = s.point, x = s.x, y = s.y, scale = s.scale } end,
        set = function(v)
            local s = db()
            s.point, s.x, s.y = v.point or s.point, v.x or s.x, v.y or s.y
            if v.scale and s.scale then s.scale = v.scale end
        end,
        apply = function() M:Place() end,
        reset = function()
            local d = key == "enchants" and M.DEFAULTS.enchant or key == "private" and M.DEFAULTS.private
                or M.DEFAULTS.headers[key]
            local s = db()
            s.point, s.x, s.y = d.point, d.x, d.y
            if s.scale then s.scale = d.scale end
            M:Place()
        end,
    }
end

local function placeHolder(holder, s, w, h)
    local scale = (s.scale and s.scale > 0) and s.scale or 1
    holder:SetScale(scale)
    holder:SetSize(math.max(w, 1), math.max(h, 1))
    holder:ClearAllPoints()
    holder:SetPoint(s.point, UIParent, s.point, s.x / scale, s.y / scale)
end

---------------------------------------------------------------- containers
local FLOW = AnchorUtil and AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }

local function enchantSlot(name) return AuraContainerItemEnchantmentSlot and AuraContainerItemEnchantmentSlot[name] end

local function flow(c, f, holder)
    c:SetFlowLayoutAnchorPoint(f.point)
    c:SetFlowLayoutGrowthDirection(FLOW[f.horizontal], FLOW[f.vertical])
    c:SetFlowLayoutMaximumLineSize(f.lineSize)
    c:ClearAllPoints()
    c:SetPoint(f.point, holder, f.point)
end

local function layoutOptions(h)
    return { elementSpacing = h.hSpacing, lineSpacing = h.vSpacing, elementWidth = h.size, elementHeight = M.Height(h) }
end

local function configure(key)
    local c, h = containers[key], M:Header(key)
    flow(c, M.Flow(h), holders[key])
    local method, direction = M.SortMethod(h)
    c:SetAuraGroupSortMethod(key, AuraContainerSortMethod[method], AuraContainerSortDirection[direction])
    c:SetAuraGroupMaxFrameCount(key, h.perRow * h.rows)
    c:SetAuraGroupLayout(key, layoutOptions(h))
    c:SetAuraGroupEnabled(key, h.enabled and true or false)
    c:SetShown(h.enabled and true or false)
    if key == "buffs" then
        local with = M.db.enchants == "buffs"
        for _, name in ipairs(ENCHANT_SLOTS) do
            local slot = enchantSlot(name)
            if slot then c:SetItemEnchantmentEnabled(slot, with) end
        end
        local o = layoutOptions(h)
        o.placement = CustomAuraContainerItemEnchantmentPlacement and CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups
        c:SetItemEnchantmentLayout(o)
    end
end

local function configureEnchants()
    local c, s = containers.enchants, M.db.enchant
    local n = #ENCHANT_SLOTS
    placeHolder(holders.enchants, s, n * s.size + (n - 1) * s.spacing, s.size)
    local right = s.growth == "RIGHT"
    flow(c, { point = right and "TOPLEFT" or "TOPRIGHT", horizontal = right and "Right" or "Left", vertical = "Down",
        lineSize = n * (s.size + s.spacing) }, holders.enchants)
    local on = M.db.enchants == "separate"
    for _, name in ipairs(ENCHANT_SLOTS) do
        local slot = enchantSlot(name)
        if slot then c:SetItemEnchantmentEnabled(slot, on) end
    end
    c:SetItemEnchantmentLayout({ elementSpacing = s.spacing, elementWidth = s.size, elementHeight = s.size })
    c:SetShown(on)
end

local function newContainer(key, holder)
    local c = CreateFrame("AuraContainer", "PhoenixUI_" .. key:gsub("^%l", string.upper), holder, "CustomAuraContainerTemplate")
    c:SetUnit("player")
    if c.SetEditModePreviewEnabled then c:SetEditModePreviewEnabled(false) end
    containers[key] = c
    return c
end

local function buildContainers()
    for _, key in ipairs(M.HEADERS) do
        local c = newContainer(key, holders[key])
        local h = M:Header(key)
        local method, direction = M.SortMethod(h)
        c:AddAuraGroup(key, M.FILTER[key], {
            maxFrameCount = h.perRow * h.rows, initializeFrame = initializer(key),
            sortMethod = AuraContainerSortMethod[method], sortDirection = AuraContainerSortDirection[direction],
            layout = layoutOptions(h),
        })
    end
    local e = newContainer("enchants", holders.enchants)
    for _, name in ipairs(ENCHANT_SLOTS) do
        local slot = enchantSlot(name)
        if slot then
            containers.buffs:AddItemEnchantment(slot, { initializeFrame = initializer("enchant") })
            e:AddItemEnchantment(slot, { initializeFrame = initializer("enchant") })
        end
    end
end

---------------------------------------------------------------- private auras
local function clearPrivate()
    for _, a in ipairs(privateAnchors) do
        if a.anchorID and C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor then
            pcall(C_UnitAuras.RemovePrivateAuraAnchor, a.anchorID)
        end
        a.anchorID = nil
        a:Hide()
    end
end

local function placePrivate()
    clearPrivate()
    local p = M.db.private
    local n = math.max(1, math.min(6, p.count))
    placeHolder(holders.private, p, n * p.size + (n - 1) * p.spacing, p.size)
    if not (p.enabled and C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then return end
    local step = (p.size + p.spacing) * (p.growth == "RIGHT" and 1 or -1)
    local start = p.growth == "RIGHT" and "TOPLEFT" or "TOPRIGHT"
    for i = 1, n do
        local a = privateAnchors[i] or CreateFrame("Frame", nil, holders.private)
        privateAnchors[i] = a
        a:ClearAllPoints()
        a:SetPoint(start, holders.private, start, (i - 1) * step, 0)
        a:SetSize(p.size, p.size)
        a:Show()
        local ok, id = pcall(C_UnitAuras.AddPrivateAuraAnchor, {
            unitToken = "player", auraIndex = i, parent = a,
            showCountdownFrame = p.countdown, showCountdownNumbers = p.numbers,
            iconInfo = { iconWidth = p.size, iconHeight = p.size,
                iconAnchor = { point = "CENTER", relativeTo = a, relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        })
        if ok then a.anchorID = id end
    end
end

---------------------------------------------------------------- placing
local function placeNow()
    for _, key in ipairs(M.HEADERS) do
        local h = M:Header(key)
        placeHolder(holders[key], h, M.HolderSize(h))
        local ok, err = pcall(configure, key)
        if not ok then ns:Debug("auras: " .. tostring(err)) end
    end
    local ok, err = pcall(configureEnchants)
    if not ok then ns:Debug("auras: " .. tostring(err)) end
    placePrivate()
end

function M:Place() ns.Combat:Run("auras.place", placeNow) end

---------------------------------------------------------------- spawning
local MOVER_LABEL = { buffs = "AURAS_BUFFS", debuffs = "AURAS_DEBUFFS", enchants = "AURAS_ENCHANTS", private = "AURAS_PRIVATE" }
local function spawn()
    if spawned then return end
    if not (C_AuraContainerUtil or AuraContainerSortMethod) then
        ns:Debug("auras: this client has no addon aura containers; Blizzard's buffs stay")
        return
    end
    spawned = true
    parkBlizzard()
    local movers = ns:GetModule("Movers")
    for _, key in ipairs({ "buffs", "debuffs", "enchants", "private" }) do
        holders[key] = CreateFrame("Frame", "PhoenixUI_Auras_" .. key, UIParent)
        holders[key]:SetSize(1, 1)
        local db
        if key == "enchants" then db = function() return M.db.enchant end
        elseif key == "private" then db = function() return M.db.private end
        else db = function() return M:Header(key) end end
        if movers then movers:Register("auras." .. key, holders[key], L[MOVER_LABEL[key]], store(key, db)) end
    end
    local ok, err = pcall(buildContainers)
    if not ok then ns:Debug("auras: " .. tostring(err)) end
    placeNow()
end

function M:EnablePhoenix() ns.Combat:Run("auras.spawn", spawn) end

function M:RefreshPhoenix()
    if not spawned then return end
    for b, kind in pairs(buttons) do
        if b.puiNative then restyle(b, kind) else self:Style(b) end
    end
    self:Place()
end

---------------------------------------------------------------- Test auras
local I = "Interface\\Icons\\"
local SAMPLES = {
    buffs = {
        { icon = I .. "Spell_Holy_PowerWordShield", left = 3400, total = 3600, name = L.PREVIEW_AURA_BUFF },
        { icon = I .. "Ability_Warrior_BattleShout", left = 840, total = 3600 },
        { icon = I .. "Spell_Holy_MagicalSentry", left = 125, total = 600, count = 3 },
        { icon = I .. "INV_Misc_PocketWatch_01", left = 28, total = 60 },
        { icon = I .. "Spell_Nature_Lightning", left = 4.2, total = 12 },
        { icon = I .. "Spell_Fire_Fireball02" },
    },
    debuffs = {
        { icon = I .. "Spell_Shadow_ShadowWordPain", left = 14, total = 18, dispel = "Magic", name = L.PREVIEW_AURA_DEBUFF },
        { icon = I .. "Spell_Frost_IceStorm", left = 3.1, total = 8, dispel = "Curse", count = 2 },
        { icon = I .. "Ability_Mage_LivingBomb", left = 45, total = 60, dispel = "Poison" },
    },
}
M.SAMPLES = SAMPLES
local SAMPLE_DISPEL = { Magic = "DEBUFF_TYPE_MAGIC_COLOR", Curse = "DEBUFF_TYPE_CURSE_COLOR",
    Disease = "DEBUFF_TYPE_DISEASE_COLOR", Poison = "DEBUFF_TYPE_POISON_COLOR" }

-- Draws a plain sample on a dressed button (the preview and Test auras).
function M:ShowSample(b, s, kind)
    b.sample = s
    b.Icon:SetTexture(s.icon)
    b.Count:SetText(s.count and s.count > 1 and s.count or "")
    b.Cooldown:Clear()
    if s.total and self.db.swipe then b.Cooldown:SetCooldown(GetTime() - (s.total - s.left), s.total) end
    if b.binding then pcall(b.binding.SetEnabled, b.binding, false) end
    b.Duration:SetText(self.FormatDuration(self.db.durationFormat, self.db.precise, s.left))
    b.Duration:SetTextColor(self:TimeColor(s.left))
    local col = s.dispel and rawget(_G, SAMPLE_DISPEL[s.dispel])
    local typed = self.db.typeBorder and (kind == "debuffs" or self.db.buffTypes)
    if typed and (col or kind == "debuffs") then
        typeColor(b, col and col.r or 0.8, col and col.g or 0, col and col.b or 0, 1)
        showType(b, true)
    else
        showType(b, false)
    end
    b.Icon:SetDesaturated(kind == "debuffs" and self.db.desaturate or false)
    b:Show()
end

local function testButtons(key)
    local t = tests[key]
    if not t then
        t = CreateFrame("Frame", nil, holders[key])
        t:SetAllPoints()
        t.buttons = {}
        tests[key] = t
    end
    return t
end

function M:ShowPhoenixTest(show)
    if not spawned then return show and false or true end
    for _, key in ipairs(M.HEADERS) do
        local h, hd = self:Header(key), containers[key]
        local t = testButtons(key)
        if show and h.enabled then
            pcall(hd.SetAlpha, hd, 0)
            local point = M.Layout(h)
            for i, off in ipairs(M.Slots(h, #SAMPLES[key])) do
                local b = t.buttons[i] or self:Dress(CreateFrame("Button", nil, t), key)
                t.buttons[i] = b
                self:Style(b)
                b:SetSize(h.size, M.Height(h))
                b:ClearAllPoints()
                b:SetPoint(point, holders[key], point, off[1], off[2])
                self:ShowSample(b, SAMPLES[key][i], key)
            end
            t:Show()
        else
            pcall(hd.SetAlpha, hd, 1)
            t:Hide()
        end
    end
    return true
end
