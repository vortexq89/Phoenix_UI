local _, ns = ...

--[[ Ember Bevel chrome icons (t169): Phoenix's own framed, beveled ember icons for UI chrome only (micro menu,
    settings nav and tabs, macro window controls, window controls, panel corner icons, drawn as round medallions). Never used on class,
    spec, ability, spell, item, mount, pet or toy icons; those stay the game's own art.
    Atlases come from tools/media/gen_chrome_bevel.py. Every cell keeps a 4 px (at 64) glow margin, so the frame
    is 56/64 of the cell: CB.CellFor(px) gives the texture size that shows a px-wide frame, and CB.FrameIn(cell)
    the frame width a cell shows. Draws of 20 px or less use the simplified 16 px cells (3 px bevel, no rivets).
    States: "normal", "hover", "pressed" (the light burst; CB:Flash plays it for 0.25 s), "disabled". ]]
local CB = {}
ns.ChromeBevel = CB

local I = "Interface\\AddOns\\Phoenix_UI\\Media\\Icons\\"
-- every atlas named in full, so the media checks can see each one is used
local SHEETS = {
    [64] = { normal = I .. "Bevel64_normal",
        hover = I .. "Bevel64_hover",
        pressed = I .. "Bevel64_pressed",
        disabled = I .. "Bevel64_disabled" },
    [16] = { normal = I .. "Bevel16_normal",
        hover = I .. "Bevel16_hover",
        pressed = I .. "Bevel16_pressed",
        disabled = I .. "Bevel16_disabled" },
    panel = { normal = I .. "Panel128_normal",
        hover = I .. "Panel128_hover",
        pressed = I .. "Panel128_pressed",
        disabled = I .. "Panel128_disabled" },
}
CB.STATES = { normal = true, hover = true, pressed = true, disabled = true }
CB.MARGIN = 4 / 64
local function data() return ns.ChromeBevelData or { cells = {}, panels = {} } end

function CB.Has(name) return data().cells[name] ~= nil end
function CB.CellFor(framePx) return math.ceil(framePx * 64 / 56) end
function CB.FrameIn(cellPx) return math.floor(cellPx * 56 / 64) end

-- tex: a texture; name: a chrome glyph ("micro-character", "win-close", "panel-bags" ...); drawPx: its drawn size.
-- Returns false when the glyph has no Ember Bevel cell (the caller keeps its flat glyph).
function CB:Apply(tex, name, state, drawPx)
    state = CB.STATES[state] and state or "normal"
    local d = data()
    local panel = d.panels[name]
    if panel and (drawPx or 64) > 48 then
        local col, row = panel % 8, math.floor(panel / 8)
        tex:SetTexture(SHEETS.panel[state])
        tex:SetTexCoord(col / 8, (col + 1) / 8, row / 4, (row + 1) / 4)
        return true
    end
    local i = d.cells[name]
    if not i then return false end
    local col, row = i % 16, math.floor(i / 16)
    tex:SetTexture(SHEETS[(drawPx or 64) <= 20 and 16 or 64][state])
    tex:SetTexCoord(col / 16, (col + 1) / 16, row / 8, (row + 1) / 8)
    return true
end

-- The pressed look as a short flash, then back to whatever paint() draws (hover, normal ...).
function CB:Flash(tex, name, drawPx, paint)
    self:Apply(tex, name, "pressed", drawPx)
    tex.puiFlash = (tex.puiFlash or 0) + 1
    local id = tex.puiFlash
    C_Timer.After(0.25, function() if tex.puiFlash == id and paint then paint() end end)
end
