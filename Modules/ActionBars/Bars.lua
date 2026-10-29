local _, ns = ...
local L, Skin, Theme = ns.L, ns.Skin, ns.Theme
local M = ns:GetModule("ActionBars")

--[[ Bars (phoenix mode): every bar is a SecureHandlerStateTemplate header Phoenix owns. Blizzard's buttons are
    handed to the headers, Blizzard's bar frames are parked in a hidden frame.

    Taint rule. A Blizzard action button re-reads its action whenever one of its attributes changes
    (OnAttributeChanged -> UpdateAction writes self.action). If addon code changed the attribute, that write is
    tainted and later secure updates in combat that read self.action are blocked. So Phoenix never calls
    SetAttribute, SetParent, SetPoint, Show or Hide on a Blizzard button from addon code: it stores the wanted
    layout as plain attributes on its own header and runs one restricted snippet (SecureHandlerExecute), which
    applies them through frame handles. The secure environment executes the snippet, so every button change and
    every OnAttributeChanged it triggers stays secure. Bar 1 pages the same way, in the header's _onstate-page
    snippet driven by a state driver. Layout itself only runs out of combat (ns.Combat:Run). ]]
local B = {}
M.BarsEngine = B

-- Show empty slots: the snippet sets bit 1024 of the button's showgrid mask (Blizzard uses 1, 2 and 4).
local headers, parking = {}, nil
function M.GetHeader(key) return headers[key] end

-- Pass 1 sets attributes on every button (each one makes Blizzard re-run its bar's UpdateShownButtons), pass 2
-- places and shows them, so the visibility we set last is the one that stays.
local LAYOUT = [[
    local total = self:GetAttribute("pb-total") or 0
    local shown = self:GetAttribute("pb-shown") or 0
    local w = self:GetAttribute("pb-w") or 36
    local h = self:GetAttribute("pb-h") or 36
    local pad = self:GetAttribute("pb-pad") or 0
    local page = self:GetAttribute("pb-page")
    local flyout = self:GetAttribute("pb-flyout")
    local empty = self:GetAttribute("pb-empty") and true or false
    local mouse = not self:GetAttribute("pb-through")
    local kind = self:GetAttribute("pb-kind")
    local layout = self:GetAttribute("pb-layout") or ""
    for i = 1, total do
        local b = self:GetFrameRef("b" .. i)
        if b then
            b:SetParent(self)
            if page then b:SetAttribute("actionpage", page) end
            if flyout then b:SetAttribute("flyoutDirection", flyout) end
            local g = b:GetAttribute("showgrid") or 0
            local has = floor(g / 1024) % 2 == 1
            if empty and not has then b:SetAttribute("showgrid", g + 1024)
            elseif has and not empty then b:SetAttribute("showgrid", g - 1024) end
            b:EnableMouse(mouse)
        end
    end
    local i = 0
    for x, y in gmatch(layout, "([%-%d%.]+),([%-%d%.]+);") do
        i = i + 1
        local b = self:GetFrameRef("b" .. i)
        if b then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self, "TOPLEFT", pad + tonumber(x), -(pad + tonumber(y)))
            b:SetScale(1) -- Blizzard's Edit Mode "icon size" scales its buttons; Phoenix sizes them itself
            b:SetWidth(w)
            b:SetHeight(h)
        end
    end
    for n = 1, total do
        local b = self:GetFrameRef("b" .. n)
        if b then
            if n > shown then
                b:Hide()
            elseif kind == "action" then
                local p = b:GetAttribute("actionpage") or self:GetAttribute("actionpage") or GetActionBarPage()
                local action = b:GetID() + (p - 1) * 12
                if empty or HasAction(action) then
                    b:Show()
                else
                    b:SetAttribute("statehidden", nil)
                    b:Hide(true)
                end
            else
                b:Show()
            end
        end
    end
]]
B.LAYOUT = LAYOUT

-- Bar 1's page, in Blizzard's own order (ActionBarController_UpdateAll). Bonus bars only apply on page 1,
-- which the driver guarantees: manual [bar:N] states come first.
local PAGE = [[
    local page
    if newstate == "vehicle" then
        if HasVehicleActionBar() then page = GetVehicleBarIndex() end
    elseif newstate == "override" then
        if HasOverrideActionBar() then page = GetOverrideBarIndex() end
    elseif newstate == "temp" then
        if HasTempShapeshiftActionBar() then page = GetTempShapeshiftBarIndex() end
    elseif newstate == "possess" then
        if HasOverrideActionBar() then page = GetOverrideBarIndex()
        elseif HasBonusActionBar() then page = GetBonusBarIndex() end
    elseif strsub(newstate, 1, 1) == "b" then
        if HasBonusActionBar() and GetActionBarPage() == 1 then page = GetBonusBarIndex() end
    elseif strsub(newstate, 1, 1) ~= "p" then
        page = tonumber(newstate)
    end
    if not page or page < 1 then page = GetActionBarPage() end
    self:SetAttribute("actionpage", page)
    local total = self:GetAttribute("pb-total") or 0
    for i = 1, total do
        local b = self:GetFrameRef("b" .. i)
        if b then b:SetAttribute("actionpage", page) end
    end
]]
B.PAGE = PAGE

---------------------------------------------------------------- helpers
local function blizzardButton(def, i)
    local b = def.prefix and _G[def.prefix .. i]
    if type(b) == "table" and b.GetObjectType and not b:IsForbidden() then return b end
end

-- How many buttons a bar shows right now (stance: the forms the character has).
function B.Shown(def, b)
    local n = math.min(b.buttons, def.count)
    if def.kind == "stance" then n = math.min(n, tonumber(GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0) end
    if def.kind == "items" then n = math.min(n, #M.itemIDs) end
    return n
end

-- Flyouts open away from the nearest screen edge, along the bar's cross axis.
function B.Flyout(b, cx, cy, sw, sh)
    local horizontal = b.grow == "RIGHT" or b.grow == "LEFT"
    if horizontal then return (cy or 0) < (sh or 768) / 2 and "UP" or "DOWN" end
    return (cx or 0) > (sw or 1024) / 2 and "LEFT" or "RIGHT"
end

-- "x,y;x,y;" for the restricted snippet (it has no table access to ours).
function B.Encode(points)
    local out = {}
    for i, p in ipairs(points) do out[i] = ("%.2f,%.2f;"):format(p[1], p[2]) end
    return table.concat(out)
end

---------------------------------------------------------------- header
local function header(def)
    local h = headers[def.key]
    if h then return h end
    h = CreateFrame("Frame", "PhoenixUI_ActionBar_" .. def.key, UIParent, "SecureHandlerStateTemplate")
    h.def = def
    h:SetSize(1, 1)
    h:SetClampedToScreen(true)
    if def.kind ~= "items" then
        for i = 1, def.count do
            local b = blizzardButton(def, i)
            if b then
                SecureHandlerSetFrameRef(h, "b" .. i, b)
                -- Edit Mode re-applies its icon size by scaling the button: that shrank Phoenix bars (24 px
                -- buttons, bars bunched together). Undo it whenever it happens out of combat; the layout
                -- snippet also resets it in combat.
                if b.SetScale and not b.puiScaleHook then
                    b.puiScaleHook = true
                    hooksecurefunc(b, "SetScale", function(self, s)
                        if s ~= 1 and h.def and M:IsPhoenix() and not InCombatLockdown() then self:SetScale(1) end
                    end)
                end
                if not InCombatLockdown() and b.SetScale then b:SetScale(1) end
            end
        end
    end
    h:SetAttribute("pb-total", def.count)
    h:SetAttribute("pb-kind", (def.kind == nil) and "action" or def.kind)
    if def.page then h:SetAttribute("actionpage", def.page) end
    if def.key == "bar1" then h:SetAttribute("_onstate-page", PAGE) end
    headers[def.key] = h
    return h
end
function B.Header(key) return headers[key] end
function B.Headers() return headers end

local function park()
    if parking then return end
    parking = CreateFrame("Frame", "PhoenixUI_ActionBarParking", UIParent)
    parking:Hide()
    for _, def in ipairs(M.BARS) do
        local bar = def.blizzard and _G[def.blizzard]
        if type(bar) == "table" and bar.SetParent and not bar:IsForbidden() then
            bar:SetParent(parking)
        end
    end
end

---------------------------------------------------------------- layout (out of combat)
local function layoutNow(key)
    local def, b = M.BAR_BY_KEY[key], M.db.bars[key]
    if not def or not b then return end
    local h = header(def)
    if not b.enabled then
        UnregisterStateDriver(h, "visibility")
        h:Hide()
        return
    end
    local n = B.Shown(def, b)
    local points, W, H, w, hh = M.Layout(b, n)
    local pad = b.backdrop.show and b.backdrop.padding or 0
    local scale = b.scale > 0 and b.scale or 1
    h:SetScale(scale)
    h:SetFrameStrata(b.strata)
    h:SetSize(math.max(1, W + pad * 2), math.max(1, H + pad * 2))
    h:ClearAllPoints()
    h:SetPoint(b.point, UIParent, b.point, b.x / scale, b.y / scale)
    local cx, cy = h:GetCenter()
    cx, cy = tonumber(cx), tonumber(cy)
    if not cy then -- not resolved yet: judge by the anchor
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        cx = b.point:find("LEFT") and 0 or b.point:find("RIGHT") and sw or sw / 2
        cy = b.point:find("BOTTOM") and 0 or b.point:find("TOP") and sh or sh / 2
    end
    if def.kind == "items" then
        M:LayoutItems(h, points, w, hh, pad, n) -- Extras.lua: Phoenix's own buttons, plain frame calls
    else
        h:SetAttribute("pb-shown", n)
        h:SetAttribute("pb-w", w)
        h:SetAttribute("pb-h", hh)
        h:SetAttribute("pb-pad", pad)
        h:SetAttribute("pb-layout", B.Encode(points))
        h:SetAttribute("pb-empty", b.showEmpty or nil)
        h:SetAttribute("pb-through", b.clickThrough or nil)
        h:SetAttribute("pb-flyout", B.Flyout(b, cx, cy, UIParent:GetWidth(), UIParent:GetHeight()))
        if def.page then h:SetAttribute("pb-page", def.page) end
        SecureHandlerExecute(h, LAYOUT)
    end
    -- backdrop and border are Phoenix textures on Phoenix's header
    local bd = b.backdrop
    Skin:Backdrop(h, { alpha = (bd.show and n > 0) and bd.alpha or 0, color = bd.color, style = bd.style }, "bg.sunken")
    Skin:BorderSpec(h, n > 0 and b.border or { style = "none", shadow = "none" }, "border.black")
    RegisterStateDriver(h, "visibility", M.VisibilityDriver(b, def.kind))
    if key == "bar1" then B.Paging() end
    B.Fade(h, true)
end

function M:RefreshBar(key)
    if not self:IsEnabled() or not self:IsPhoenix() or not headers[key] then return end
    ns.Combat:Run("ab.layout." .. key, layoutNow, key)
end

-- Bar 1 paging: state driver plus the optional page arrows.
function B.Paging()
    local h = headers.bar1
    if not h then return end
    local sky = ns:Supports("skyriding")
    RegisterStateDriver(h, "page", M.PageDriver(M.db.paging, sky))
    M:UpdateArrows()
end

function M:RefreshPaging()
    if not self:IsEnabled() or not self:IsPhoenix() then return end
    ns.Combat:Run("ab.paging", B.Paging)
end

---------------------------------------------------------------- page arrows (bar 1)
-- /changeactionbar is a secure slash command, so the arrows are secure macro buttons that work in combat.
local function pageMacro(step)
    local parts = {}
    for page = 1, 6 do
        local to = (page - 1 + step) % 6 + 1
        parts[#parts + 1] = page == 6 and tostring(to) or ("[bar:%d] %d"):format(page, to)
    end
    -- the last clause has no condition: bar 6
    return "/changeactionbar " .. table.concat(parts, "; ")
end
B.PageMacro = pageMacro

local arrows
local function arrow(parent, step, label)
    local a = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    a:SetSize(16, 16)
    a:RegisterForClicks("AnyUp", "AnyDown")
    a:SetAttribute("type", "macro")
    a:SetAttribute("macrotext", pageMacro(step))
    a.text = a:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    a.text:SetPoint("CENTER")
    a.text:SetText(label)
    a:SetScript("OnEnter", function(self) self.text:SetTextColor(Theme:Color("accent.primary")) end)
    a:SetScript("OnLeave", function(self) self.text:SetTextColor(Theme:Color("text.secondary")) end)
    return a
end

function M:UpdateArrows()
    local h = headers.bar1
    if not h then return end
    if not arrows then
        arrows = CreateFrame("Frame", nil, h)
        arrows:SetSize(18, 44)
        arrows.up = arrow(arrows, 1, "+")
        arrows.down = arrow(arrows, -1, "-")
        arrows.up:SetPoint("TOP")
        arrows.down:SetPoint("BOTTOM")
        arrows.page = arrows:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        arrows.page:SetPoint("CENTER")
        ns.Events:On("ACTIONBAR_PAGE_CHANGED", arrows, function() M:UpdateArrows() end)
    end
    for _, fs in ipairs({ arrows.up.text, arrows.down.text, arrows.page }) do Skin:Text(fs, "number", "text.secondary", 12, "OUTLINE") end
    arrows.page:SetText(tostring(C_ActionBar.GetActionBarPage() or 1))
    if not InCombatLockdown() then
        arrows:ClearAllPoints()
        arrows:SetPoint("LEFT", h, "RIGHT", 4, 0)
        arrows:SetShown(M.db.paging.arrows and M.db.bars.bar1.enabled)
    end
end

---------------------------------------------------------------- fading
-- One 0.1 s ticker for every bar: hover (with linked bars), reveal (dragging something, spellbook open), combat.
local fading, ticker = {}, nil
local STEP = 0.2

local function cursorReveals()
    local kind = GetCursorInfo and GetCursorInfo()
    return kind == "spell" or kind == "item" or kind == "macro" or kind == "petaction" or kind == "mount"
        or kind == "flyout" or kind == "companion" or kind == "battlepet"
end

local function hovered(h)
    if h:IsMouseOver() then return true end
    local fly = SpellFlyout
    return fly and fly:IsShown() and fly:IsMouseOver() and fly:GetParent() and fly:GetParent():GetParent() == h or false
end

function B.State(h, linkedHover)
    local b = M.db.bars[h.def.key]
    local spellbook = PlayerSpellsFrame and PlayerSpellsFrame:IsShown()
    return {
        combat = InCombatLockdown() or UnitAffectingCombat("player"),
        hover = linkedHover or hovered(h),
        reveal = (b.vis.drag and cursorReveals()) or (b.vis.spellbook and spellbook) or M.keybindMode or false,
    }
end

local function tick()
    local db = M.db
    local anyLinked = false
    for key, h in pairs(headers) do
        if db.bars[key].vis.linked and h:IsVisible() and hovered(h) then anyLinked = true end
    end
    local reduce = ns.Anim and ns.Anim.ReduceMotion and ns.Anim:ReduceMotion()
    for h in pairs(fading) do
        local b = db.bars[h.def.key]
        local target = M.TargetAlpha(b.vis, B.State(h, b.vis.linked and anyLinked))
        local a = h:GetAlpha()
        if reduce or math.abs(a - target) <= STEP then a = target elseif a < target then a = a + STEP else a = a - STEP end
        h:SetAlpha(a)
    end
    M:TickPetRange() -- Buttons.lua: the parked pet bar no longer runs its own range timer
end

-- Bars that never fade leave the ticker; their alpha is set once.
function B.Fade(h, reset)
    local b = M.db.bars[h.def.key]
    local v = b.vis
    if v.fade or v.mouseover or v.linked then
        fading[h] = true
        if reset then h:SetAlpha(M.TargetAlpha(v, B.State(h))) end
    else
        fading[h] = nil
        h:SetAlpha(v.alpha)
    end
    if not ticker then ticker = C_Timer.NewTicker(0.1, function() ns.SafeCall(tick) end) end
end

---------------------------------------------------------------- Layout mode (Movers)
-- The bars being edited together in the settings (multi-select / Edit all), or nil.
function M.EditTargets()
    local C = ns.Config
    local page = C and C.pages and C.pages[M.key]
    if not (page and page.Targets) then return nil end
    local t = page:Targets()
    return type(t) == "table" and #t > 1 and t or nil
end

-- Layout mode drag of one bar of a multi-selection: the other selected bars move by the same offset, so the
-- group keeps its shape. Only plain offsets are shifted (each bar keeps its own anchor).
function M.MoveWithSelection(key, dx, dy)
    if (dx == 0 and dy == 0) or not (tonumber(dx) and tonumber(dy)) then return end
    local targets = M.EditTargets()
    if not targets then return end
    local inGroup = false
    for _, k in ipairs(targets) do if k == key then inGroup = true end end
    if not inGroup then return end
    local movers = ns:GetModule("Movers")
    for _, k in ipairs(targets) do
        local b = k ~= key and M.db.bars[k]
        if b then
            b.x, b.y = b.x + dx, b.y + dy
            M:RefreshBar(k)
            if movers and movers.SyncOverlay then movers:SyncOverlay("ab." .. k) end
        end
    end
end

local function store(def)
    local key = def.key
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M.db.bars[key].enabled end,
        get = function()
            local b = M.db.bars[key]
            return { point = b.point, x = b.x, y = b.y, scale = b.scale, alpha = b.vis.alpha }
        end,
        set = function(s)
            local b = M.db.bars[key]
            local ox, oy, opoint, oscale = b.x, b.y, b.point, b.scale
            b.point, b.x, b.y = s.point or b.point, s.x or b.x, s.y or b.y
            if s.scale then b.scale = s.scale end
            -- a move (not a rescale, which re-derives the offsets) carries the rest of the selection along
            if b.point == opoint and b.scale == oscale then M.MoveWithSelection(key, b.x - ox, b.y - oy) end
            if s.alpha then b.vis.alpha = s.alpha end
        end,
        apply = function() M:RefreshBar(key) end,
        reset = function()
            local d, b = M.DEFAULTS.bars[key], M.db.bars[key]
            b.point, b.x, b.y, b.scale, b.vis.alpha = d.point, d.x, d.y, d.scale, d.vis.alpha
            M:RefreshBar(key)
        end,
    }
end

---------------------------------------------------------------- lifecycle
local function adopt()
    park()
    for _, def in ipairs(M.BARS) do
        local h = header(def)
        local movers = ns:GetModule("Movers")
        if movers then movers:Register("ab." .. def.key, h, L[def.label], store(def)) end
        layoutNow(def.key)
    end
end

function M:EnableBars()
    ns.Combat:Run("ab.adopt", adopt)
    -- forms appear and disappear (talents, level ups): the stance bar follows, out of combat
    ns.Events:On("UPDATE_SHAPESHIFT_FORMS", self, function() self:RefreshBar("stance") end)
    -- an action placed on an empty slot must appear when empty slots are hidden
    -- (debounced: logging in or swapping specs changes every slot at once)
    local pending
    ns.Events:On("ACTIONBAR_SLOT_CHANGED", self, function()
        if pending then return end
        pending = true
        C_Timer.After(0.2, function()
            pending = nil
            for _, def in ipairs(M.BARS) do
                if def.kind == nil and not M.db.bars[def.key].showEmpty then self:RefreshBar(def.key) end
            end
        end)
    end)
    ns.Events:On("PLAYER_SPECIALIZATION_CHANGED", self, function() self:Refresh() end)
end
