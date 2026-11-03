local _, ns = ...
local W, Skin, Theme, Media = ns.Widgets, ns.Skin, ns.Theme, ns.Media

--[[ ns.Previews — live mock-ups at the top of module option pages.
    A preview is built from plain Frames, Textures, FontStrings and StatusBars (no secure templates, no
    Blizzard frames, no unit queries) filled with fixed sample data, so it is safe in combat and never
    touches a secret value. It is styled by the module's own style methods, the same code that dresses
    the real frames, and redrawn on every PUI_SETTING_CHANGED of its module, on theme changes and when
    the page's unit selector moves.

    ns.Previews:Register(kind, { height = px, width = px?, states = { {key, label, icon} }?,
        build = function(stage, m) -> redraw(stage, unit) })
    width is the room the mock needs; a narrower slot (the preview dock) scales the whole stage down to fit
    instead of clipping it (stage:Fit). ]]
local P = { kinds = {} }
ns.Previews = P

function P:Register(kind, def) self.kinds[kind] = def end

-- Every fit-to-panel scale goes through this: a 0 or not-yet-laid-out panel gives 0 or NaN, which
-- Frame:SetScale rejects. Clamped to [0.05, ...]; anything that is not a usable number becomes 1.
P.MIN_SCALE = 0.05
function P.ClampScale(s)
    if type(s) ~= "number" or s ~= s or s == math.huge then return 1 end
    return math.max(P.MIN_SCALE, s)
end

-- def.states = { { key, label, icon }, ... }: sample states the page can switch on (low health, casting …).
-- The draw function reads them from stage.states[key].
function P:States(kind)
    local def = self.kinds[kind]
    return def and def.states and #def.states > 0 and def.states or nil
end

-- Sample data shared by the previews (spell and item icons are stock game art).
P.SAMPLE = {
    icons = {
        "Interface\\Icons\\Spell_Fire_Fireball02", "Interface\\Icons\\Spell_Fire_FlameBolt",
        "Interface\\Icons\\Spell_Fire_SelfDestruct", "Interface\\Icons\\Spell_Holy_MagicalSentry",
        "Interface\\Icons\\Spell_Frost_IceStorm", "Interface\\Icons\\Ability_Mage_LivingBomb",
        "Interface\\Icons\\Spell_Nature_Lightning", "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
        "Interface\\Icons\\Ability_Warrior_BattleShout", "Interface\\Icons\\Spell_Holy_PowerWordShield",
        "Interface\\Icons\\INV_Misc_PocketWatch_01", "Interface\\Icons\\Spell_Arcane_TeleportDalaran",
    },
}

---------------------------------------------------------------- building blocks
-- A status bar for previews: fixed value, our texture, a background region.
function P.Bar(parent, value, w, h)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetMinMaxValues(0, 1)
    b:SetValue(value or 1)
    b:SetSize(w or 160, h or 14)
    b:SetStatusBarTexture(Media.textures.WHITE)
    return b
end

function P.Text(parent, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
    fs:SetWordWrap(false)
    return fs
end

function P.Icon(parent, size, index)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size or 32, size or 32)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexture(P.SAMPLE.icons[((index or 1) - 1) % #P.SAMPLE.icons + 1])
    return f
end

-- Small caption under a sample ("Target", "Focus", …).
function P.Caption(parent, text)
    local fs = W.Text(parent, "small", "text.muted", "CENTER")
    fs:SetText(text:upper())
    return fs
end

---------------------------------------------------------------- stage
P.MAX_ZOOM = 1.6
P.MAX_HEIGHT = 320 -- tallest a preview gets on the page; bigger content scales down
P.MARGIN = 6 -- even space above and below the sample
function P:Create(kind, parent, m, page)
    local def = self.kinds[kind]
    local stage = CreateFrame("Frame", nil, parent)
    stage:SetHeight(def and def.height or 120)
    -- No box of its own and no clipping (t228, EllesmereUI's way): the real sample is drawn straight onto the
    -- preview card and the stage is sized to what it holds, so nothing is squeezed or cut and no empty band is left.
    stage:SetClipsChildren(false)
    stage.states = {}
    stage.kind = kind
    -- every stage built, for the developer diagnostics' "preview fit" check (Core/DevDiag.lua)
    self.stages = self.stages or {}
    self.stages[#self.stages + 1] = stage
    stage.designWidth = def and def.width or 0
    -- Scales the stage so its design width fits `width`; returns the scale (1 when it already fits).
    -- The preview keeps one footprint on the page (its design height) whatever the settings do: content
    -- that grows wider or taller scales the stage down instead of pushing the page (and the rows) around.
    -- Scales the stage so its content fits `width` and sets its height to the content (innerH, measured after
    -- each draw) with a small even margin. Small samples are zoomed up to MAX_ZOOM so they fill the width.
    function stage:Fit(width)
        local scale = 1
        if self.designWidth > 0 and width and width > 0 and width < self.designWidth then scale = width / self.designWidth end
        local cw, ch = self.contentW, self.contentH
        if scale == 1 and cw and ch and cw > 0 and ch > 0 and width and width > 0 then
            local zoom = math.min(P.MAX_ZOOM, (width * 0.85) / cw, P.MAX_HEIGHT / ch)
            if zoom > 1.05 then scale = zoom end
        end
        local inner = self.innerH or self.baseHeight or 120
        if inner * scale > P.MAX_HEIGHT then scale = P.MAX_HEIGHT / inner end
        scale = ns.Previews.ClampScale(scale)
        if math.abs((self:GetScale() or 1) - scale) > 0.001 then
            self:SetScale(scale)
            ns.Skin:Reapply() -- 1px borders inside the stage are re-measured at the new scale
        end
        self:SetHeight(inner)
        return scale
    end
    local draw = def and def.build(stage, m)
    local baseWidth, baseHeight = stage.designWidth, def and def.height or 120
    stage.baseHeight = baseHeight
    local measureQueued = false
    -- Fit to content: settings can make a sample bigger than the room it was designed for (a 400 px wide
    -- frame, a 40 px font). After each redraw the stage measures what it holds; wider content raises the
    -- design width (the whole stage scales down), taller content raises the height. Nothing is clipped.
    local function measure()
        measureQueued = false
        local l0, r0, t0, b0 = stage:GetLeft(), stage:GetRight(), stage:GetTop(), stage:GetBottom()
        if not (l0 and r0 and t0 and b0) then return end
        local l, r, t, b
        local function grow(obj)
            if obj.puiGrip or obj.puiNoMeasure or not obj:IsShown() then return end
            local ol, or_, ot, ob = obj:GetLeft(), obj:GetRight(), obj:GetTop(), obj:GetBottom()
            if not (ol and or_ and ot and ob) or or_ - ol <= 0 then return end
            local s = (obj.GetEffectiveScale and obj:GetEffectiveScale() or stage:GetEffectiveScale()) / stage:GetEffectiveScale()
            ol, or_, ot, ob = ol * s, or_ * s, ot * s, ob * s
            l, r = math.min(l or ol, ol), math.max(r or or_, or_)
            t, b = math.max(t or ot, ot), math.min(b or ob, ob)
        end
        for _, c in ipairs({ stage:GetChildren() }) do grow(c) end
        for _, g in ipairs({ stage:GetRegions() }) do if g:GetObjectType() == "FontString" and g ~= stage.emptyHint then grow(g) end end
        -- nothing drew (the sample failed or the module has nothing to show): say so instead of an empty panel,
        -- and note it for Bugs › Diagnostics (specs/004 T001)
        if not l then
            stage.empty = true
            if not stage.emptyHint then
                stage.emptyHint = W.Text(stage, "desc", "text.muted", "CENTER")
                stage.emptyHint:SetPoint("CENTER")
                stage.emptyHint:SetWidth(math.max(160, baseWidth - 40))
                stage.emptyHint:SetText(ns.L.PREVIEW_EMPTY)
            end
            stage.emptyHint:Show()
            ns:Debug("preview empty: %s", tostring(m.key))
            return
        end
        stage.empty = false
        if stage.emptyHint then stage.emptyHint:Hide() end
        local pad, mid = 8, (l0 + r0) / 2
        local needW = math.max(r - mid, mid - l) * 2 + pad
        local cw, ch = needW, t - b
        -- height from the content: centred samples get the margin on both sides; top-anchored ones keep their
        -- top and lose the empty band below (t228: no gaps)
        local h0 = t0 - b0
        local gapT, gapB = t0 - t, b - b0
        local inner
        if math.abs(gapT - gapB) < 2 then inner = ch + P.MARGIN * 2 else inner = h0 - gapB + P.MARGIN end
        inner = math.max(24, math.ceil(inner))
        local changed = not stage.contentW or math.abs(cw - stage.contentW) > 2 or math.abs(ch - stage.contentH) > 2
            or math.abs(inner - (stage.innerH or 0)) > 1
        stage.contentW, stage.contentH, stage.innerH = cw, ch, inner
        local width = math.max(baseWidth, math.ceil(needW))
        stage.needHeight = inner
        if width ~= stage.designWidth then stage.designWidth = width; changed = true end
        if changed and page.Layout then
            page:Layout()
            -- the new height moves centred content: measure once more until it settles
            stage.settle = (stage.settle or 0) + 1
            if stage.settle < 4 and not measureQueued then
                measureQueued = true
                C_Timer.After(0, function() ns.SafeCall(measure) end)
            end
        else
            stage.settle = 0
        end
    end
    local retry
    function stage:Redraw()
        -- not laid out yet (0 width or height): skip and try again on the next frame
        local w, h = tonumber((self:GetWidth())) or 0, tonumber((self:GetHeight())) or 0
        if not (w > 0 and h > 0) then
            if not retry and self:IsVisible() then
                retry = true
                C_Timer.After(0, function() retry = false; if stage:IsVisible() then stage:Redraw() end end)
            end
            return
        end
        -- third argument: every element being edited (multi-select / Edit all), the picked one first
        if draw then ns.SafeCall(draw, self, page.scope and page.scope.unit, page.Targets and page:Targets() or nil) end
        -- self-fitting previews (selfFit) scale their own content to the stage: measuring them as well stacked
        -- the two scales and shrank the sample on every visit (t213 #1)
        if not (def and def.selfFit) and not measureQueued and self:IsVisible() then
            measureQueued = true
            C_Timer.After(0, function() ns.SafeCall(measure) end)
        end
    end
    stage.MeasureContent = measure
    local function onChange(_, _, moduleKey)
        if stage:IsVisible() and (moduleKey == m.key or moduleKey == "General") then stage:Redraw() end
    end
    ns.Events:Listen("PUI_SETTING_CHANGED", stage, onChange)
    ns.Events:Listen("PUI_THEME_CHANGED", stage, function() if stage:IsVisible() then stage:Redraw() end end)
    stage:SetScript("OnShow", stage.Redraw)
    stage:Redraw()
    return stage
end

-- The colour a sample bar would get from the theme (healthy friendly unit, hostile mob, …).
function P.Token(token) return Theme:Color(token) end

---------------------------------------------------------------- real data for the previews
--[[ The previews show the player's own things where the game has them: the spells on the main action bar, the
    real name, class and level of a unit that exists. Looked up by name so both flavors run the same code; values
    are only handed to widgets (never compared), and nothing is read in combat. ]]
local function api(name, space)
    local t = space and _G[space]
    local fn = (type(t) == "table" and t[name]) or _G[name]
    return type(fn) == "function" and fn or nil
end
P.API = api

-- Up to n { name, icon } from the main action bar (first page), skipping empty slots and non-spells.
function P.RealSpells(n)
    local out = {}
    if InCombatLockdown() then return out end
    local info, tex = api("GetActionInfo", "C_ActionBar"), api("GetActionTexture", "C_ActionBar")
    local spellName = api("GetSpellName", "C_Spell")
    if not (info and tex) then return out end
    for slot = 1, 12 do
        local kind, id = info(slot)
        if kind == "spell" and id then
            local name = spellName and spellName(id)
            local icon = tex(slot)
            if name and icon then out[#out + 1] = { name = name, icon = icon } end
        end
        if #out >= n then break end
    end
    return out
end

-- name, class token, level and reaction of a unit that exists (out of combat), else nil.
function P.RealUnit(token)
    if InCombatLockdown() or not UnitExists(token) then return nil end
    local _, class = UnitClass(token)
    return { name = UnitName(token), class = UnitIsPlayer(token) and class or nil, level = UnitLevel(token),
        reaction = UnitReaction(token, "player") }
end

-- A small "1:1" / "64%" label in a stage corner telling how much the preview is scaled down to fit.
function P.ScaleLabel(stage)
    local fs = W.Text(stage, "small", "text.muted", "RIGHT")
    fs.puiNoMeasure = true -- a corner note, not the sample: the stage height follows the sample only
    fs:SetPoint("BOTTOMRIGHT", -6, 4)
    function fs:Set(scale)
        self:SetText(scale < 0.995 and string.format("%d%%", math.floor(scale * 100 + 0.5)) or "1:1")
    end
    return fs
end

-- Click-to-setting: a transparent button over a preview part; hovering outlines it in the accent and a click
-- asks the page to jump to and flash the setting `key` (stage.onHot, set by the renderer). One per part, reused.
function P.Hot(stage, part, key, tip)
    if not (stage and part) then return end
    local hot = part.puiHot
    if not hot then
        hot = CreateFrame("Button", nil, stage)
        hot:RegisterForClicks("LeftButtonUp")
        hot.edge = CreateFrame("Frame", nil, hot)
        hot.edge:SetAllPoints()
        hot.edge:Hide()
        hot:SetScript("OnEnter", function(self)
            self.edge:Show()
            if self.tip then W.ShowTooltip(self, self.tip, ns.L.PREVIEW_CLICK_HINT) end
        end)
        hot:SetScript("OnLeave", function(self) self.edge:Hide(); W.HideTooltip() end)
        hot:SetScript("OnClick", function(self) if stage.onHot then stage.onHot(self.key, self) end end)
        Skin:Register(hot.edge, function(e) Skin:Border(e, "accent.primary") end)
        part.puiHot = hot
        stage.hots = stage.hots or {}
        stage.hots[#stage.hots + 1] = hot
        if stage.attachHot then stage.attachHot(hot) end
    end
    hot.key, hot.tip = key, tip
    hot:ClearAllPoints()
    hot:SetAllPoints(part)
    hot:SetFrameLevel((part:GetFrameLevel() or 1) + 20)
    hot:SetShown(part:IsShown())
    return hot
end
