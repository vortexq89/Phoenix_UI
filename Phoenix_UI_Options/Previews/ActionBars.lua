local _, ns = ...
local P, Skin, Media = ns.Previews, ns.Skin, ns.Media

--[[ The bar picked in the scope bar, laid out by ActionBars.Layout (the function the real bars use) and dressed
    by the module's own Dress/StyleButton, with sample states: out of range, not enough power, unusable, on
    cooldown, a proc glow and the assisted-combat highlight. Slots past the samples are empty slots. ]]
local SAMPLES = {
    { key = "1" }, { key = "2", count = "3", proc = true }, { key = "3", cooldown = 0.6 }, { key = "4", state = "range" },
    { key = "SHIFT-E", macro = "Burst", assist = true }, { key = "Q", state = "power" }, { key = "BUTTON4", count = "12" },
    { key = "CTRL-2", state = "unusable" }, { key = "F" },
}
local STAGE_W, STAGE_H = 440, 132

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
    btn.hotkey:SetText(s and hotkeyText(m, s.key) or "")
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
        return function(self, bar)
            local db = m.db
            local b = db.bars[bar or "bar1"] or db.bars.bar1
            local showEmpty = b.showEmpty or self.states.empty
            local samples = (bar == "pet" or bar == "stance") and 6 or #SAMPLES
            local n = math.min(b.buttons, 12)
            local points, W, H, w, h = m.Layout(b, n)
            local pad = b.backdrop.show and b.backdrop.padding or 0
            holder:SetSize(W + pad * 2, H + pad * 2)
            local fit = math.min(1.25, (STAGE_W - 24) / math.max(1, W + pad * 2), (STAGE_H - 20) / math.max(1, H + pad * 2))
            holder:SetScale(math.max(0.3, fit))
            Skin:Backdrop(holder, { alpha = b.backdrop.show and b.backdrop.alpha or 0, color = b.backdrop.color,
                style = b.backdrop.style }, "bg.sunken")
            Skin:BorderSpec(holder, b.border, "border.black")
            holder:SetAlpha(b.vis.alpha)
            for i, btn in ipairs(buttons) do
                local sample = SAMPLES[i] and i <= samples and SAMPLES[i] or nil
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
