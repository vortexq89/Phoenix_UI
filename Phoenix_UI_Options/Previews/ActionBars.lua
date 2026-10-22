local _, ns = ...
local P, Skin = ns.Previews, ns.Skin

-- A sample bar of eight buttons: hotkeys, charges, a macro name and one button out of range.
local BUTTONS = {
    { key = "1" }, { key = "2", count = "3" }, { key = "3" }, { key = "4", range = true },
    { key = "S-E", macro = "Burst" }, { key = "Q" }, { key = "F", count = "12" }, { key = "C-2" },
}
local SIZE, GAP, SCALE = 38, 4, 1.15

P:Register("actionbar", {
    module = "ActionBars",
    width = 400,
    height = 96,
    build = function(stage, m)
        local row = CreateFrame("Frame", nil, stage)
        row:SetSize(#BUTTONS * (SIZE + GAP) - GAP, SIZE)
        row:SetScale(SCALE)
        row:SetPoint("CENTER")
        local buttons = {}
        for i, def in ipairs(BUTTONS) do
            local b = P.Icon(row, SIZE, i)
            b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
            b.hotkey = P.Text(b)
            b.count = P.Text(b)
            b.macro = P.Text(b)
            b.def = def
            buttons[i] = b
        end
        return function()
            local db = m.db
            for _, b in ipairs(buttons) do
                if db.style then
                    m:StyleButton(b, b.tex, b.hotkey, b.count, b.macro, true)
                else
                    b.tex:SetTexCoord(0, 1, 0, 1)
                    Skin:BorderSpec(b, { style = "none" })
                    m:StyleButton(b, b.tex, b.hotkey, b.count, b.macro, true)
                end
                b.hotkey:SetText(b.def.key)
                b.hotkey:SetShown(db.hotkeys)
                b.count:SetText(b.def.count or "")
                b.macro:SetText(b.def.macro or "")
                b.macro:SetShown(db.macroText)
                if b.def.range and db.rangeTint then b.tex:SetVertexColor(m:RangeColor()) else b.tex:SetVertexColor(1, 1, 1) end
            end
        end
    end,
})
