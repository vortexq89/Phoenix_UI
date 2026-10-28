local _, ns = ...
local P, Skin, Media = ns.Previews, ns.Skin, ns.Media

--[[ The bar picked in the scope bar shows the spells really on that bar (GetActionTexture, the pet and
    stance info) at its real size; it is only scaled down to fit the panel, and the label says by how much.
    The bar picked in the scope bar, laid out by ActionBars.Layout (the function the real bars use) and dressed
    by the module's own Dress/StyleButton, with sample states: out of range, not enough power, unusable, on
    cooldown, a proc glow and the assisted-combat highlight. Slots past the samples are empty slots. ]]
local STAGE_W, STAGE_H = 440, 132

-- Retail has these in C_ActionBar, Forever as globals; looked up by name so both flavors lint clean.
local function api(name)
    local ns_ = _G["C_ActionBar"]
    local fn = (type(ns_) == "table" and ns_[name]) or _G[name]
    return type(fn) == "function" and fn or nil
end
local function apiPage() local fn = api("GetActionBarPage"); return fn and fn() end
local function apiTexture(slot) local fn = api("GetActionTexture"); return fn and fn(slot) end

-- What is really in slot i of a bar: { tex, key } or nil for an empty slot.
local function actionSlot(def, i)
    if not def then return nil end
    if def.kind == "pet" then
        if not GetPetActionInfo then return nil end
        local _, tex = GetPetActionInfo(i)
        return tex and { tex = tex } or nil
    elseif def.kind == "stance" then
        if not GetShapeshiftFormInfo or i > (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) then return nil end
        local tex = GetShapeshiftFormInfo(i)
        return tex and { tex = tex } or nil
    elseif def.kind == "items" then
        return nil
    end
    local page = def.page or (apiPage() or 1) or 1
    local slot = (page - 1) * 12 + i
    local tex = apiTexture(slot)
    if not tex then return nil end
    local real = def.prefix and _G[def.prefix .. i]
    local hk = real and real.HotKey and real.HotKey:GetText()
    if hk == RANGE_INDICATOR then hk = nil end
    return { tex = tex, real = true, keyText = hk }
end

local function button(parent, i)
    local b = P.Icon(parent, 36, i)
    b.hotkey, b.count, b.macro = P.Text(b), P.Text(b), P.Text(b)
    b.shade = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.shade:SetTexture(Media.textures.WHITE)
    b.shade:SetPoint("BOTTOMLEFT"); b.shade:SetPoint("BOTTOMRIGHT")
    return b
end

local function hotkeyText(m, key)
    if m.db.shortHotkeys then return m.ShortKey(key) end
    return (key:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("BUTTON", "M"))
end

local function dress(m, btn, s)
    local db = m.db
    if db.style then
        m:Dress(btn, btn.tex, nil, { btn.shade })
    else
        btn.tex:SetTexCoord(0, 1, 0, 1)
        Skin:BorderSpec(btn, { style = "none", shadow = "none" })
    end
    m:StyleButton(btn, btn.tex, btn.hotkey, btn.count, btn.macro, true)
    btn.tex:SetShown(s ~= nil)
    if s and s.tex then btn.tex:SetTexture(s.tex) end
    btn.hotkey:SetText(s and (s.keyText or (s.key and hotkeyText(m, s.key))) or "")
    btn.hotkey:SetShown(db.hotkeys)
    btn.count:SetText(s and s.count or "")
    btn.macro:SetText(s and s.macro or "")
    btn.macro:SetShown(db.macroText)
end

-- Range, power and unusable tints on the icon, the hotkey or both (power and unusable always tint the icon).
local function feedback(m, btn, s)
    local db = m.db
    local state = s and s.state
    if state == "range" and not db.rangeTint then state = nil end
    local r, g, b = 1, 1, 1
    if state then r, g, b = m:FeedbackColor(state) end
    local target = db.feedback.target
    local onIcon = target ~= "hotkey" or state == "power" or state == "unusable"
    if onIcon then btn.tex:SetVertexColor(r, g, b) else btn.tex:SetVertexColor(1, 1, 1) end
    if state and target ~= "icon" then btn.hotkey:SetTextColor(r, g, b) end
end

local function cooldown(m, btn, part, h)
    local db = m.db
    if part then
        btn.shade:SetHeight(math.max(1, h * part))
        btn.shade:SetVertexColor(0, 0, 0, db.feedback.swipeAlpha)
        btn.shade:Show()
        btn.tex:SetDesaturated(db.desatCooldown)
        btn.tex:SetAlpha(db.cooldownAlpha)
    else
        btn.shade:Hide()
        btn.tex:SetDesaturated(false)
        btn.tex:SetAlpha(1)
    end
end

-- Proc and assist glows; Blizzard's own art is drawn as the closest Phoenix glow in the mock.
local function glows(m, btn, s)
    local fb = m.db.feedback
    if s and s.proc and fb.proc ~= "none" then
        local r, g, b = Skin:SpecColor(fb.procColor, "accent.glow")
        ns.Glow:Show(btn, fb.proc == "blizzard" and "button" or fb.proc, r, g, b, 1)
    else
        ns.Glow:Hide(btn)
    end
    if s and s.assist and fb.assist ~= "none" then
        local r, g, b = Skin:SpecColor(nil, "accent.secondary")
        ns.Glow:Show(btn, fb.assist == "blizzard" and "pixel" or fb.assist, r, g, b, 1, "assist")
    else
        ns.Glow:Hide(btn, "assist")
    end
end

P:Register("actionbar", {
    module = "ActionBars",
    width = STAGE_W,
    height = STAGE_H,
    states = {
        { key = "cooldown", label = "PREVIEW_STATE_COOLDOWN", icon = "clock" },
        { key = "empty", label = "PREVIEW_STATE_EMPTY", icon = "grid" },
    },
    build = function(stage, m)
        local holder = CreateFrame("Frame", nil, stage)
        holder:SetPoint("CENTER")
        local buttons = {}
        for i = 1, 12 do buttons[i] = button(holder, i) end
        local scaleText = ns.Widgets.Text(stage, "small", "text.muted", "RIGHT")
        scaleText:SetPoint("BOTTOMRIGHT", -6, 4)
        return function(self, bar)
            local db = m.db
            local b = db.bars[bar or "bar1"] or db.bars.bar1
            local showEmpty = b.showEmpty or self.states.empty
            local def = m.BAR_BY_KEY and m.BAR_BY_KEY[bar or "bar1"]
            local n = math.min(b.buttons, 12)
            local points, W, H, w, h = m.Layout(b, n)
            local pad = b.backdrop.show and b.backdrop.padding or 0
            holder:SetSize(W + pad * 2, H + pad * 2)
            local fit = math.min(1, (STAGE_W - 24) / math.max(1, W + pad * 2), (STAGE_H - 20) / math.max(1, H + pad * 2))
            fit = math.max(0.2, fit)
            holder:SetScale(fit)
            scaleText:SetText(fit < 1 and string.format("%d%%", math.floor(fit * 100 + 0.5)) or "1:1")
            Skin:Backdrop(holder, { alpha = b.backdrop.show and b.backdrop.alpha or 0, color = b.backdrop.color,
                style = b.backdrop.style }, "bg.sunken")
            Skin:BorderSpec(holder, b.border, "border.black")
            holder:SetAlpha(b.vis.alpha)
            for i, btn in ipairs(buttons) do
                local sample = actionSlot(def, i)
                local p = points[i]
                btn:SetShown(p ~= nil and (sample ~= nil or showEmpty))
                if p then
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", holder, "TOPLEFT", pad + p[1], -(pad + p[2]))
                    btn:SetSize(w, h)
                end
                dress(m, btn, sample)
                feedback(m, btn, sample)
                cooldown(m, btn, sample and (sample.cooldown or (self.states.cooldown and i == 1 and 0.35)), h)
                glows(m, btn, sample)
            end
        end
    end,
})
