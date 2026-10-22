local _, ns = ...
local L = ns.L
local Skin, Secret, Style, Media, Theme = ns.Skin, ns.Secret, ns.Style, ns.Media, ns.Theme

--[[ Tooltip: Phoenix skin, cursor anchoring, class/quality borders and extra lines.
    All data comes from TooltipDataProcessor post-calls; anything secret is skipped, never compared. ]]
local M = ns:NewModule("Tooltip", {
    label = "TOOLTIP", desc = "TOOLTIP_DESC", category = "interface", order = 60, reloadOnToggle = true,
    defaults = {
        skin = true, anchor = "DEFAULT", hideInCombat = false, target = true, role = true, ids = false,
        classBorder = true, qualityBorder = true, healthBar = true, mplusRating = true, simLine = true,
        backdrop = Style.Background({ alpha = 0.97 }),
        border = Style.Border(),
        fonts = true,
        header = Style.Text(14), body = Style.Text(12),
        barTexture = "", barHeight = 4,
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
local function styleFonts()
    if not M.db.fonts then return end
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

local function addRole(tt, unit)
    local role = UnitGroupRolesAssigned(unit)
    if plain(role) and ROLE_ATLAS[role] then
        GameTooltip_AddNormalLine(tt, CreateAtlasMarkup(ROLE_ATLAS[role], 14, 14) .. " " .. _G[role])
    end
end

-- C_PlayerInfo.GetPlayerMythicPlusRatingSummary carries no Secret* return flags; guarded all the same.
local function addRating(tt, unit)
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    local score = summary and summary.currentSeasonScore
    if not (plain(score) and score and score > 0) then return end
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR
    GameTooltip_AddNormalLine(tt, L.TOOLTIP_MPLUS_LINE:format(color:WrapTextInColorCode(BreakUpLargeNumbers(score))))
end

local function addTarget(tt, unit)
    local target = unit .. "target"
    local name = UnitExists(target) and UnitName(target)
    if not (plain(name) and name) then return end
    local _, classFile = UnitClass(target)
    local color = (plain(classFile) and classFile) and C_ClassColor.GetClassColor(classFile)
    GameTooltip_AddNormalLine(tt, L.TOOLTIP_TARGET_LINE:format(color and color:WrapTextInColorCode(name) or name))
end

-- Post-calls run for every tooltip that shows unit/item/spell data, including embedded and third-party
-- tooltips that are not GameTooltips. In-game report (BugGrabber, 43x): "Tooltip.lua: attempt to call a
-- nil value" from tt:GetItem() on such a frame. Only real GameTooltips are touched.
local function usable(tt)
    return tt and tt.IsForbidden and not tt:IsForbidden() and tt.AddLine and tt.GetUnit and tt.GetItem
end

local function onUnit(tt, data)
    if not M:IsEnabled() or not usable(tt) then return end
    local _, unit = tt:GetUnit()
    if not plain(unit) or not unit then return end
    if M.db.hideInCombat and InCombatLockdown() and not IsModifierKeyDown() and tt == GameTooltip then
        tt:Hide()
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if not plain(isPlayer) then return end
    if isPlayer and M.db.classBorder then
        local _, classFile = UnitClass(unit)
        if plain(classFile) then border(tt, ns.Util.ClassColor(classFile)) end
    end
    if M.db.role then addRole(tt, unit) end
    if isPlayer and M.db.mplusRating and ns:Supports("mythicplus") then addRating(tt, unit) end
    if M.db.target then addTarget(tt, unit) end
    if M.db.ids and data and plain(data.id) and data.id then
        GameTooltip_AddColoredLine(tt, L.TOOLTIP_ID:format(data.id), GRAY_FONT_COLOR)
    end
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
        local color = quality and ITEM_QUALITY_COLORS[quality]
        if color and quality > 1 then border(tt, color.r, color.g, color.b) end
    end
    if M.db.simLine then addSim(tt, data) end
    if M.db.ids and data and plain(data.id) and data.id then
        GameTooltip_AddColoredLine(tt, L.TOOLTIP_ID:format(data.id), GRAY_FONT_COLOR)
    end
end

local function onSpell(tt, data)
    if M:IsEnabled() and M.db.ids and usable(tt) and data and plain(data.id) and data.id then
        GameTooltip_AddColoredLine(tt, L.TOOLTIP_SPELL_ID:format(data.id), GRAY_FONT_COLOR)
    end
end

local function onAnchor(tt, parent)
    if M:IsEnabled() and M.db.anchor == "CURSOR" and not tt:IsForbidden() then
        tt:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 16, 16)
    end
end

-- reloadOnToggle: OnEnable runs at most once per session, so the hooks are installed once.
function M:OnEnable()
    hooksecurefunc("SharedTooltip_SetBackdropStyle", onBackdrop)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", onAnchor)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnit)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, onSpell)
    for _, name in ipairs(TOOLTIPS) do
        local tt = _G[name]
        if tt then
            isOurs[tt] = true
            skin(tt)
        end
    end
    if self.db.healthBar and GameTooltip.StatusBar then
        Skin:Register(GameTooltip.StatusBar, function(bar)
            Skin:StatusBar(bar, { border = true })
            M:StyleHealthBar(bar)
        end)
    end
    styleFonts()
end

function M:Refresh()
    for tt in pairs(skinned) do self:StyleFrame(tt); border(tt) end
    if self.db.healthBar and GameTooltip.StatusBar and Skin:IsSkinned(GameTooltip.StatusBar) then
        self:StyleHealthBar(GameTooltip.StatusBar)
    end
    styleFonts()
end
