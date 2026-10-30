local _, ns = ...

--[[ Ember Bevel chrome icons (t169): Phoenix's own framed, beveled icons for UI chrome only (micro menu, settings
    nav and tabs, module tiles, macro window controls, window controls, and the round panel medallions in window
    corners). Never used on class, spec, ability, spell, item, mount, pet or toy icons; those stay the game's art.

    Themes: ember, frost, fel and arcane have their own pre-rendered sheets; the class and custom accents use the
    neutral sheet tinted with the accent (SetVertexColor). Icons follow the theme live (PUI_THEME_CHANGED).
    Size: only the normal look ships per theme. Hover adds the glow overlay (theme glow colour) and a 12% lift;
    pressed adds the light burst and a 20% lift for a 0.25 s flash; disabled uses the shared grey sheet.
    Cells keep a 4 px (at 64) glow margin, so the frame is 56/64 of a cell: CB.CellFor(px) / CB.FrameIn(cell).
    Draws of 20 px or less use the simplified 16 px cells (3 px bevel, no rivets).
    Atlases come from tools/media/gen_chrome_bevel.py. ]]
local CB = {}
ns.ChromeBevel = CB

local I = "Interface\\AddOns\\Phoenix_UI\\Media\\Icons\\Chrome\\"
-- every sheet named in full, so the media checks can see each one is used
local SHEETS = {
    ember = { [64] = I .. "Ember_normal64", [16] = I .. "Ember_normal16", panel = I .. "Ember_normalPanel" },
    frost = { [64] = I .. "Frost_normal64", [16] = I .. "Frost_normal16", panel = I .. "Frost_normalPanel" },
    fel = { [64] = I .. "Fel_normal64", [16] = I .. "Fel_normal16", panel = I .. "Fel_normalPanel" },
    arcane = { [64] = I .. "Arcane_normal64", [16] = I .. "Arcane_normal16", panel = I .. "Arcane_normalPanel" },
    neutral = { [64] = I .. "Neutral_normal64", [16] = I .. "Neutral_normal16", panel = I .. "Neutral_normalPanel" },
    disabled = { [64] = I .. "Disabled64", [16] = I .. "Disabled16", panel = I .. "DisabledPanel" },
}
local GLOW_SQUARE, GLOW_ROUND, BURST = I .. "GlowSquare", I .. "GlowRound", I .. "Burst"
CB.STATES = { normal = true, hover = true, pressed = true, disabled = true }
local LIFT = { normal = 0, hover = 0.12, pressed = 0.2, disabled = 0 }

local function data() return ns.ChromeBevelData or { cells = {}, panels = {} } end
function CB.Has(name) return data().cells[name] ~= nil or data().panels[name] ~= nil end
function CB.CellFor(framePx) return math.ceil(framePx * 64 / 56) end
function CB.FrameIn(cellPx) return math.floor(cellPx * 56 / 64) end

-- The sheet family for the current theme, and the tint (class / custom accents tint the neutral sheet).
function CB.Family()
    local preset = ns.Theme and ns.Theme.settings and ns.Theme.settings.preset or "ember"
    if SHEETS[preset] and preset ~= "disabled" and preset ~= "neutral" then return preset end
    return "neutral", true
end

-- Sheet path and texcoords for a glyph: (path, l, r, t, b, round) or nil when the glyph has no cell.
function CB.Cell(name, drawPx, family)
    local d = data()
    local set = SHEETS[family or CB.Family()]
    local p = d.panels[name]
    if p and (drawPx or 64) > 24 then
        local col, row = p % 8, math.floor(p / 8)
        return set.panel, col / 8, (col + 1) / 8, row / 4, (row + 1) / 4, true
    end
    local i = d.cells[name]
    if not i then return nil end
    local col, row = i % 16, math.floor(i / 16)
    return set[(drawPx or 64) <= 20 and 16 or 64], col / 16, (col + 1) / 16, row / 8, (row + 1) / 8, false
end

local live = setmetatable({}, { __mode = "k" }) -- icons that follow the theme

-- A chrome icon on parent: the base cell plus its glow, burst and lift layers. Returns the icon (a table);
-- icon.tex is the base texture to anchor or size (CB:SetSize sizes all layers).
function CB:Create(parent, layer, sublevel)
    layer, sublevel = layer or "ARTWORK", sublevel or 1
    local ic = { parent = parent }
    ic.glow = parent:CreateTexture(nil, layer, nil, sublevel - 1)
    ic.burst = parent:CreateTexture(nil, layer, nil, sublevel)
    ic.tex = parent:CreateTexture(nil, layer, nil, math.min(7, sublevel + 1))
    ic.lift = parent:CreateTexture(nil, layer, nil, math.min(7, sublevel + 2))
    ic.burst:SetTexture(BURST)
    for _, t in ipairs({ ic.glow, ic.burst, ic.lift }) do
        t:SetPoint("TOPLEFT", ic.tex, "TOPLEFT"); t:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT")
        t:SetBlendMode("ADD"); t:Hide()
    end
    live[ic] = true
    return ic
end

function CB:SetSize(ic, px) ic.tex:SetSize(px, px); ic.size = px end
function CB:SetShown(ic, on)
    ic.shown = on and true or false
    ic.tex:SetShown(ic.shown)
    if not ic.shown then ic.glow:Hide(); ic.burst:Hide(); ic.lift:Hide() end
end

-- Paints ic as glyph `name` in `state` at `drawPx` (defaults to its size's frame width). Returns false when
-- the glyph has no Ember Bevel cell (the caller keeps its flat glyph).
function CB:Set(ic, name, state, drawPx)
    state = CB.STATES[state] and state or "normal"
    ic.name, ic.state, ic.drawPx = name, state, drawPx
    local family, tinted = CB.Family()
    local path, l, r, t, b, round = CB.Cell(name, drawPx or CB.FrameIn(ic.size or 32), state == "disabled" and "disabled" or family)
    if not path then CB:SetShown(ic, false); return false end
    if ic.shown == nil then ic.shown = true end
    ic.tex:SetTexture(path); ic.tex:SetTexCoord(l, r, t, b)
    local ar, ag, ab = 1, 1, 1
    if tinted and state ~= "disabled" then ar, ag, ab = ns.Theme:Color("accent.primary") end
    ic.tex:SetVertexColor(ar, ag, ab, 1)
    ic.tex:SetAlpha(state == "disabled" and 0.6 or 1)
    if not ic.shown then return true end
    -- hover / pressed: the glow in the margin (theme glow colour), a lift, and the burst when pressed
    local glowing = state == "hover" or state == "pressed"
    ic.glow:SetShown(glowing)
    if glowing then
        ic.glow:SetTexture(round and GLOW_ROUND or GLOW_SQUARE)
        local gr, gg, gb = ns.Theme:Color("accent.glow")
        ic.glow:SetVertexColor(gr, gg, gb, state == "pressed" and 1 or 0.8)
    end
    ic.burst:SetShown(state == "pressed")
    if state == "pressed" then
        local sr, sg, sb = ns.Theme:Color("accent.secondary")
        ic.burst:SetVertexColor(sr, sg, sb, 0.5)
    end
    ic.lift:SetShown(LIFT[state] > 0)
    if LIFT[state] > 0 then
        ic.lift:SetTexture(path); ic.lift:SetTexCoord(l, r, t, b)
        ic.lift:SetVertexColor(ar, ag, ab, LIFT[state])
    end
    return true
end

-- The pressed look as a short flash, then back to whatever paint() draws (hover, normal ...).
function CB:Flash(ic, paint)
    self:Set(ic, ic.name, "pressed", ic.drawPx)
    ic.flash = (ic.flash or 0) + 1
    local id = ic.flash
    ic.flashing = true
    C_Timer.After(0.25, function()
        if ic.flash == id then ic.flashing = nil; if paint then paint() end end
    end)
end

-- live theme swap: every icon repaints in the new family
function CB:Refresh()
    for ic in pairs(live) do
        if ic.name and not ic.flashing then self:Set(ic, ic.name, ic.state, ic.drawPx) end
    end
end
if ns.Events then ns.Events:Listen("PUI_THEME_CHANGED", CB, function() CB:Refresh() end) end
