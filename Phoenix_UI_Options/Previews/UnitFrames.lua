local _, ns = ...
local P = ns.Previews

--[[ The unit frame picked in the scope bar, built by UnitFrames itself (M:Build / M:Layout / M:UpdateAll, the code
    that draws the real frames) as a plain, non-secure frame fed with the plain sample data the Test frames use.
    Nothing here reads a unit: the preview is safe in combat. States: low health, out of range, in combat. ]]
P:Register("unitframe", {
    module = "UnitFrames",
    width = 400,
    height = 170,
    states = {
        { key = "low", label = "PREVIEW_STATE_LOW", icon = "warning" },
        { key = "range", label = "PREVIEW_STATE_RANGE", icon = "opacity" },
        { key = "combat", label = "PREVIEW_STATE_COMBAT", icon = "cat-combat" },
    },
    build = function(_, m)
        local built = {}
        return function(view, unit)
            local key = m.TOKENS[unit] and unit or "player"
            for k, f in pairs(built) do if k ~= key then f:Hide() end end
            local f = built[key]
            if not f then
                f = m:Build(view, key, { sample = {} })
                f:EnableMouse(false)
                built[key] = f
            end
            local st = view.states
            local s = m.SampleData(key, 1)
            if st.low then s.hp = math.floor((s.hpMax or 1) * 0.16) end
            if st.range then s.far = true end
            s.combat = st.combat or s.combat
            f.sample = s
            m:Layout(f)
            f:ClearAllPoints()
            f:SetPoint("CENTER", view, "CENTER", 0, 4)
            m:UpdateAll(f)
            -- (the fading rows act on the real frames; the preview shows the range fade only when asked)
            if not st.range then f:SetAlpha(1) end
            f:Show()
        end
    end,
})
