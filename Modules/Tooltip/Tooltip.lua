local _, ns = ...
local L = ns.L
local Skin, Secret, Style, Media, Theme = ns.Skin, ns.Secret, ns.Style, ns.Media, ns.Theme

--[[ Tooltip: Phoenix skin, anchoring (default, cursor or a Layout-mode mover) and scale, class/quality borders,
    name colours, extra lines (target, targeted by, role, guild rank, realm, item level and specialization from
    inspect, mount, Mythic+ rating, Sim result, item counts) and IDs of every kind. Tooltip.lua owns the skin and
    the hooks; Extras.lua builds the lines.
    All data comes from TooltipDataProcessor post-calls; anything secret is skipped, never compared. ]]
local M = ns:NewModule("Tooltip", {
    label = "TOOLTIP", desc = "TOOLTIP_DESC", category = "interface", order = 60, reloadOnToggle = true,
    defaults = {
        skin = true, anchor = "DEFAULT", hideInCombat = false, target = true, role = true, ids = false,
        classBorder = true, qualityBorder = true, healthBar = true, mplusRating = true, simLine = true, bisList = "",
        backdrop = Style.Background({ alpha = 0.97 }),
        border = Style.Border(),
        fonts = true,
        header = Style.Text(14), body = Style.Text(12),
        barTexture = "", barHeight = 4,
        -- position
        cursorX = 16, cursorY = 16, scale = 1, mover = { point = "BOTTOMRIGHT", x = -60, y = 220 },
        combatModifier = "ANY", combatScope = "units",
        -- unit info
        classNames = true, reactionNames = true, guildRank = true, realm = true, targetedBy = true, inspect = true,
        mount = true, hidePvP = false, healthText = false,
        -- IDs and extras
        idKinds = { spell = true, item = true, unit = true, aura = true, currency = true, quest = true,
            achievement = true, mount = true },
        itemCount = true,
        vendorPrice = true, collected = true, keystone = true, gathering = true,     -- S17 item extras
    },
})

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }
local isOurs = {}
local skinned = setmetatable({}, { __mode = "k" })
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

---------------------------------------------------------------- style (shared with the options preview)
function M:StyleFrame(frame)
    Skin:Backdrop(frame, self.db.backdrop, "bg.raised")
    Skin:BorderSpec(frame, self.db.border, "border.strong")
end

function M:BorderColor() return Skin:SpecColor(self.db.border.color, "border.strong") end

-- Line fonts; the line colours stay whatever the tooltip gives them.
function M:StyleLines(header, body)
    if not self.db.fonts then return end
    if header then Skin:TextSpec(header, self.db.header, "body") end
    for _, fs in ipairs(body or {}) do Skin:TextSpec(fs, self.db.body, "desc") end
end

function M:StyleHealthBar(bar)
    bar:SetStatusBarTexture(self.db.barTexture ~= "" and Media:Bar(self.db.barTexture) or Theme:Bar())
    bar:SetHeight(self.db.barHeight)
end

local function border(tt, r, g, b)
    if not skinned[tt] then return end
    if r then Skin:SetBorderColor(tt, r, g, b, 1) else Skin:SetBorderColor(tt, M:BorderColor()) end
end

local function skin(tt)
    if not M.db.skin or tt.IsEmbedded then return end
    Skin:HideRegion(tt.NineSlice)
    if not skinned[tt] then
        skinned[tt] = true
        Skin:Register(tt, function(self) M:StyleFrame(self) end)
        tt:HookScript("OnTooltipCleared", function(self) border(self) end)
    end
end

-- Tooltip lines use these shared font objects; restyling them reaches every tooltip line.
local FONT_OBJECTS = { header = { "GameTooltipHeaderText" }, body = { "GameTooltipText", "GameTooltipTextSmall" } }
local fontsStyled
local function styleFonts()
    if not (M:IsEnabled() and M.db.fonts) then
        -- live off: the shared tooltip fonts go back to Blizzard's
        if fontsStyled then
            fontsStyled = nil
            for _, list in pairs(FONT_OBJECTS) do
                for _, name in ipairs(list) do if _G[name] then Skin:Restore(_G[name]) end end
            end
        end
        return
    end
    fontsStyled = true
    local header = _G[FONT_OBJECTS.header[1]]
    local body = {}
    for _, name in ipairs(FONT_OBJECTS.body) do body[#body + 1] = _G[name] end
    M:StyleLines(header, body)
end

local function onBackdrop(tt)
    if not (M:IsEnabled() and M.db.skin) then return end
    if isOurs[tt] then skin(tt) end
end

local function plain(...)
    for i = 1, select("#", ...) do
        if Secret.IsSecret((select(i, ...))) then return false end
    end
    return true
end
M.Plain = plain

local function addRole(tt, unit)
    local role = UnitGroupRolesAssigned(unit)
    if plain(role) and ROLE_ATLAS[role] then
        GameTooltip_AddNormalLine(tt, CreateAtlasMarkup(ROLE_ATLAS[role], 14, 14) .. " " .. _G[role])
    end
end

-- C_PlayerInfo.GetPlayerMythicPlusRatingSummary carries no Secret* return flags; guarded all the same.
local function addRating(tt, unit)
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if not (plain(summary) and type(summary) == "table") then return end
    local score = summary.currentSeasonScore
    if not (plain(score) and type(score) == "number" and score > 0) then return end
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR
    GameTooltip_AddNormalLine(tt, L.TOOLTIP_MPLUS_LINE:format(color:WrapTextInColorCode(BreakUpLargeNumbers(score))))
end

local function addTarget(tt, unit)
    local target = unit .. "target"
    local exists = UnitExists(target)
    if not (plain(exists) and exists) then return end
    local name = UnitName(target)
    if not (plain(name) and name) then return end
    local _, classFile = UnitClass(target)
    local shown = (plain(classFile) and classFile) and ns.Util.WrapClass(classFile, name) or name
    GameTooltip_AddNormalLine(tt, L.TOOLTIP_TARGET_LINE:format(shown))
end

-- Post-calls run for every tooltip that shows unit/item/spell data, including embedded and third-party
-- tooltips that are not GameTooltips. In-game report (BugGrabber, 43x): "Tooltip.lua: attempt to call a
-- nil value" from tt:GetItem() on such a frame. Only real GameTooltips are touched.
local function usable(tt)
    return tt and tt.IsForbidden and not tt:IsForbidden() and tt.AddLine and tt.GetUnit and tt.GetItem
end

-- Combat hiding: the modifier you hold to see a tooltip anyway.
local MODIFIER = { ANY = "IsModifierKeyDown", SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }
function M:CombatHidden()
    if not (self.db.hideInCombat and InCombatLockdown()) then return false end
    local held = MODIFIER[self.db.combatModifier] and _G[MODIFIER[self.db.combatModifier]]
    return not (held and held())
end

local function onUnit(tt, data)
    if not M:IsEnabled() or not usable(tt) then return end
    local _, unit = tt:GetUnit()
    if not plain(unit) or not unit then return end
    if tt == GameTooltip and M:CombatHidden() then
        tt:Hide()
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if not plain(isPlayer) then return end
    if isPlayer and M.db.classBorder then
        local _, classFile = UnitClass(unit)
        if plain(classFile) then border(tt, ns.Util.ClassColor(classFile)) end
    end
    M:UnitLines(tt, unit, isPlayer, data)
    if M.db.role then addRole(tt, unit) end
    if isPlayer and M.db.mplusRating and ns:Supports("mythicplus") then addRating(tt, unit) end
    if M.db.target then addTarget(tt, unit) end
    M:UnitExtras(tt, unit, isPlayer, data)
end

-- The Sim module's result for this exact item (same item ID and bonus IDs), when you simmed it lately.
local function addSim(tt, data)
    local Sim = ns.modules.Sim
    if not (Sim and Sim.active) then return end
    local link = data and data.hyperlink
    if not (plain(link) and link) then link = select(2, tt:GetItem()) end
    if not (plain(link) and link) then return end
    local r = Sim:ItemResult(link)
    if r then
        GameTooltip_AddNormalLine(tt, L.TOOLTIP_SIM_LINE:format(Sim:Describe(r), Sim:Age(r.finished)))
    end
end

local function onItem(tt, data)
    if not M:IsEnabled() or not usable(tt) then return end
    if M.db.qualityBorder then
        local link = data and data.hyperlink
        if not (plain(link) and link) then link = select(2, tt:GetItem()) end
        local quality = plain(link) and link and C_Item.GetItemQualityByID(link)
        if plain(quality) and type(quality) == "number" and quality > 1 then
            local color = ITEM_QUALITY_COLORS[quality]
            if color then border(tt, color.r, color.g, color.b) end
        end
    end
    if M.db.simLine then addSim(tt, data) end
    if M.db.bisList ~= "" then M:AddBiS(tt, data) end
    if M.db.itemCount then M:AddItemCount(tt, data) end
    M:ItemExtras(tt, data)
    M:AddID(tt, "item", data)
end

-- Best in slot from your own list (Tooltip > BiS list): pasted item IDs, or a "PUI-BIS:" share string. No
-- third-party data ships with Phoenix; the list is whatever you import.
local bisCache, bisText = {}, nil
function M.ParseBiS(text)
    local set = {}
    text = tostring(text or ""):gsub("^%s*PUI%-BIS:", "")
    for id in text:gmatch("%d+") do set[tonumber(id)] = true end
    return set
end
function M:AddBiS(tt, data)
    if bisText ~= self.db.bisList then bisCache, bisText = M.ParseBiS(self.db.bisList), self.db.bisList end
    local id = data and data.id
    if not (plain(id) and type(id) == "number" and bisCache[id]) then return end
    tt:AddLine(L.TOOLTIP_BIS_LINE, 0.4, 0.85, 1)
end

-- IDs for the other tooltip kinds (spell, aura, currency, quest, achievement, mount).
local function idOnly(kind)
    return function(tt, data)
        if M:IsEnabled() and usable(tt) then M:AddID(tt, kind, data) end
    end
end

-- anchor: DEFAULT (Blizzard's corner), CURSOR / CURSOR_LEFT (beside the pointer, with offsets), CURSOR_TOP
-- (centred above it) or MOVER (the Layout-mode "Tooltip" mover).
local CURSOR = { CURSOR = "ANCHOR_CURSOR_RIGHT", CURSOR_LEFT = "ANCHOR_CURSOR_LEFT", CURSOR_TOP = "ANCHOR_CURSOR" }
local moverFrame
local function onAnchor(tt, parent)
    if not (M:IsEnabled() and tt and tt.IsForbidden and not tt:IsForbidden() and tt.SetOwner) then return end
    local how = M.db.anchor
    if CURSOR[how] then
        local x = how == "CURSOR_LEFT" and -M.db.cursorX or M.db.cursorX
        tt:SetOwner(parent, CURSOR[how], how == "CURSOR_TOP" and 0 or x, how == "CURSOR_TOP" and 0 or M.db.cursorY)
    elseif how == "MOVER" and moverFrame then
        tt:SetOwner(parent, "ANCHOR_NONE")
        tt:ClearAllPoints()
        tt:SetPoint("BOTTOMRIGHT", moverFrame, "BOTTOMRIGHT")
    end
end

local function moverStore()
    return {
        active = function() return M:IsEnabled() and M.db.anchor == "MOVER" end,
        get = function() local p = M.db.mover; return { point = p.point, x = p.x, y = p.y } end,
        set = function(v) local p = M.db.mover; p.point, p.x, p.y = v.point or p.point, v.x or p.x, v.y or p.y end,
        apply = function() M:PlaceMover() end,
        reset = function()
            local p, d = M.db.mover, M.defaults.mover
            p.point, p.x, p.y = d.point, d.x, d.y
            M:PlaceMover()
        end,
    }
end

function M:PlaceMover()
    if not moverFrame then
        moverFrame = CreateFrame("Frame", "PhoenixUI_TooltipAnchor", UIParent)
        moverFrame:SetSize(200, 80)
        local movers = ns:GetModule("Movers")
        if movers then movers:Register("tooltip", moverFrame, L.TOOLTIP, moverStore()) end
    end
    local p = self.db.mover
    moverFrame:ClearAllPoints()
    moverFrame:SetPoint(p.point or "BOTTOMRIGHT", UIParent, p.point or "BOTTOMRIGHT", p.x or 0, p.y or 0)
end

-- "Hide in combat" for every tooltip, not only units (hold the modifier to see one).
local function onShow(tt)
    if M:IsEnabled() and M.db.combatScope == "all" and M:CombatHidden() then tt:Hide() end
end

-- Hooks run inside Blizzard's tooltip code for every tooltip in the game. A fault in one must not break the
-- tooltip or repeat on every hover: it is reported once per session (to the bug catcher) and then skipped.
local function guarded(fn)
    local reported = false
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and not reported then
            reported = true
            local handler = geterrorhandler()
            if handler then handler(err) end
        end
    end
end

-- reloadOnToggle: OnEnable runs at most once per session, so the hooks are installed once.
function M:OnEnable()
    hooksecurefunc("SharedTooltip_SetBackdropStyle", guarded(onBackdrop))
    hooksecurefunc("GameTooltip_SetDefaultAnchor", guarded(onAnchor))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, guarded(onUnit))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, guarded(onItem))
    local T = Enum.TooltipDataType
    TooltipDataProcessor.AddTooltipPostCall(T.Spell, guarded(idOnly("spell")))
    TooltipDataProcessor.AddTooltipPostCall(T.UnitAura, guarded(idOnly("aura")))
    TooltipDataProcessor.AddTooltipPostCall(T.Currency, guarded(idOnly("currency")))
    TooltipDataProcessor.AddTooltipPostCall(T.Quest, guarded(idOnly("quest")))
    TooltipDataProcessor.AddTooltipPostCall(T.Achievement, guarded(idOnly("achievement")))
    TooltipDataProcessor.AddTooltipPostCall(T.Mount, guarded(idOnly("mount")))
    GameTooltip:HookScript("OnShow", guarded(onShow))
    self:PlaceMover()
    self:EnableExtras()
    for _, name in ipairs(TOOLTIPS) do
        local tt = _G[name]
        if tt then
            isOurs[tt] = true
            skin(tt)
        end
    end
    self:SyncHealthBar()
    styleFonts()
    self:ApplyScale()
end

-- The unit tooltip's health bar in the Phoenix look; switching it off hands Blizzard's bar back, live.
function M:SyncHealthBar()
    local bar = GameTooltip.StatusBar
    if not bar then return end
    if self:IsEnabled() and self.db.healthBar then
        if not self.hbOn then
            self.hbOn = true
            self.hbHeight = self.hbHeight or bar:GetHeight()
            Skin:Register(bar, function(b)
                Skin:StatusBar(b, { border = true })
                M:StyleHealthBar(b)
            end)
        end
    elseif self.hbOn then
        self.hbOn = nil
        Skin:Restore(bar)
        if self.hbHeight then bar:SetHeight(self.hbHeight) end
    end
end

function M:ApplyScale()
    for _, name in ipairs(TOOLTIPS) do
        local tt = _G[name]
        if tt and tt.SetScale and not tt.IsEmbedded then tt:SetScale(self.db.scale or 1) end
    end
end

function M:Refresh()
    self:ApplyScale()
    self:PlaceMover()
    for tt in pairs(skinned) do self:StyleFrame(tt); border(tt) end
    self:SyncHealthBar()
    if self.hbOn then
        self:StyleHealthBar(GameTooltip.StatusBar)
    end
    styleFonts()
end
