local _, ns = ...
local P = ns.Previews

--[[ The unit frame picked in the scope bar, built by UnitFrames itself (M:Build / M:Layout / M:UpdateAll, the code
    that draws the real frames) as a plain, non-secure frame fed with the plain sample data the Test frames use.
    Nothing here reads a unit: the preview is safe in combat. States: low health, out of range, in combat, and
    (S18) the detached resource block with the totem bar.
    Arena (S18): the whole stack - as many frames as the Test frame count - with their sample class icon auras,
    trinket, racial, DR icons, spec, focus and targeted-by marks, scaled down to fit the stage. ]]
local W, H = 400, 200
local MAX_STACK = 5

-- Rough reach of an arena row: frame, icon chain on one side, DR icons on the other.
local function arenaWidth(u)
    local icons = ((u.classIcon and 1 or 0) + (u.trinket and 1 or 0) + (u.racial and 1 or 0)) * (u.height + 2)
    local dr = u.dr and u.dr.show and (3 * (u.dr.size + u.dr.spacing) + u.dr.gap) or 0
    return u.width + icons + dr + 8
end

-- The scale that fits a w x h block in the stage (never above 1).
local function fit(w, h)
    return math.min(1, (W - 16) / math.max(1, w), (H - 16) / math.max(1, h))
end

local function drawResources(m, view, built, st)
    local r = m.db.resources
    local f = built.resources
    if not f then
        f = m:BuildResources(view, { sample = {} })
        f:EnableMouse(false)
        built.resources = f
        built.totems = {}
        for slot = 1, 4 do built.totems[slot] = m:BuildTotemButton(view, slot, false) end
    end
    local class = r.previewClass ~= "" and r.previewClass or select(2, UnitClass("player"))
    local s = m.ResourceSample(class)
    if st.low then s.hp = math.floor(s.hpMax * 0.16) end
    f.sample, f.activeSig = s, nil
    m:LayoutResources(f)
    m:UpdateResources(f)
    f:SetScale(1)
    local t = m.db.totems
    local showTotems = t.style == "phoenix"
    -- (the preview lays the four slots in a row under the block, in the growth order)
    local slots = m.TotemSlots(4, t.size, t.spacing, t.growth == "LEFT" and "LEFT" or "RIGHT")
    local tw = showTotems and (t.size * 4 + t.spacing * 3) or 0
    local th = showTotems and (t.size + 8) or 0
    local scale = fit(math.max(r.width, tw), f:GetHeight() + th)
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", view, "CENTER", 0, (th / 2 + 4) / scale)
    f:Show()
    local icons = m.SAMPLE_ICONS or {}
    local list = { icons.fireball, icons.storm, icons.sentry, icons.bomb }
    for slot, b in ipairs(built.totems) do
        m:StyleTotemButton(b)
        b.Icon:SetTexture(list[slot])
        b:SetScale(scale)
        b:ClearAllPoints()
        local x0 = t.growth == "LEFT" and (tw / 2 - t.size / 2) or (t.size / 2 - tw / 2)
        b:SetPoint("TOP", f, "BOTTOM", x0 + slots[slot][1], -6)
        b:SetShown(showTotems)
    end
end

-- The real unit when it exists: its own name, class, level and reaction, and no made-up auras.
local function applyReal(m, key, s)
    local token = type(m.TOKENS[key]) == "string" and m.TOKENS[key] or key
    local real = P.RealUnit(token)
    if not real then return end
    s.name, s.level = real.name or s.name, real.level or s.level
    if real.class then s.class = real.class end
    if real.reaction then s.reaction = real.reaction end
    s.buffs, s.debuffs = nil, nil
end

local function drawArena(m, view, built, key, st)
    local u = m:Unit(key)
    local holder = built["holder:" .. key]
    if not holder then
        holder = CreateFrame("Frame", nil, view)
        holder:SetSize(1, 1)
        built["holder:" .. key] = holder
    end
    local list = built[key]
    if not list then
        list = {}
        for i = 1, MAX_STACK do
            local f = m:Build(holder, key, { sample = {} })
            f:EnableMouse(false)
            list[i] = f
        end
        built[key] = list
    end
    local n = math.max(1, math.min(MAX_STACK, m:Unit("arena").testCount or 3))
    local pitch = u.height + (u.spacing or 0)
    local total = n * u.height + (n - 1) * (u.spacing or 0)
    local scale = fit(key == "arena" and arenaWidth(u) or u.width, total)
    holder:SetScale(scale)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", view, "CENTER", 0, 0)
    holder:Show()
    local up = u.growth == "UP"
    for i, f in ipairs(list) do
        if i <= n then
            local s = m.SampleData(key, i)
            if st.low and i == 1 then s.hp = math.floor((s.hpMax or 1) * 0.16) end
            if st.range and i == 2 then s.far = true end
            s.combat = st.combat or s.combat
            f.sample = s
            m:Layout(f)
            f:ClearAllPoints()
            local y = total / 2 - (i - 1) * pitch
            if up then y = -total / 2 + (i - 1) * pitch + u.height end
            f:SetPoint("TOP", holder, "CENTER", 0, y)
            m:UpdateAll(f)
            if not (st.range and i == 2) then f:SetAlpha(1) end
            f:Show()
        else
            f:Hide()
        end
    end
end

P:Register("unitframe", {
    module = "UnitFrames",
    width = W,
    height = H,
    states = {
        { key = "low", label = "PREVIEW_STATE_LOW", icon = "warning" },
        { key = "range", label = "PREVIEW_STATE_RANGE", icon = "opacity" },
        { key = "combat", label = "PREVIEW_STATE_COMBAT", icon = "cat-combat" },
        { key = "resources", label = "PREVIEW_STATE_RESOURCES", icon = "speed" },
    },
    build = function(_, m)
        local built = {}
        return function(view, unit)
            local st = view.states
            local key = m.TOKENS[unit] and unit or "player"
            local stack = (key == "arena" or key == "arenapet") and m.BuildResources ~= nil
            local show = st.resources and m.BuildResources and "resources" or key
            -- hide whatever this view does not show
            for k, f in pairs(built) do
                if k ~= show and k ~= "totems" and k ~= "scaleText" and k ~= "holder:" .. show then
                    if type(f) == "table" and f.Hide then f:Hide()
                    elseif type(f) == "table" then for _, x in ipairs(f) do x:Hide() end end
                end
            end
            if show == "resources" then
                drawResources(m, view, built, st)
                return
            end
            for _, b in ipairs(built.totems or {}) do b:Hide() end
            if stack then drawArena(m, view, built, key, st); return end
            local f = built[key]
            if not f then
                f = m:Build(view, key, { sample = {} })
                f:EnableMouse(false)
                built[key] = f
            end
            local s = m.SampleData(key, 1)
            applyReal(m, key, s)
            if st.low then s.hp = math.floor((s.hpMax or 1) * 0.16) end
            if st.range then s.far = true end
            s.combat = st.combat or s.combat
            f.sample = s
            m:Layout(f)
            f:ClearAllPoints()
            -- true size; only scaled down when the frame is wider or taller than the panel
            local u = m:Unit(key)
            local scale = fit(u.width or 1, u.height or 1)
            f:SetScale(scale)
            f:SetPoint("CENTER", view, "CENTER", 0, 4 / scale)
            built.scaleText = built.scaleText or P.ScaleLabel(view)
            built.scaleText:Set(scale)
            built.scaleText:Show()
            m:UpdateAll(f)
            P.Hot(view, f, "units.@.width", ns.L.UF_WIDTH)
            -- (the fading rows act on the real frames; the preview shows the range fade only when asked)
            if not st.range then f:SetAlpha(1) end
            f:Show()
        end
    end,
})
