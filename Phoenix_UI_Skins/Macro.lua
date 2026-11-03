local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Macro window controls in Ember Bevel (t169): New, Delete, Save, Change name/icon and the General / Character
    tabs get Phoenix's framed chrome icons, left of their labels. Only Phoenix's own control glyphs: the macros'
    icons (the game's spell and item art) are never touched. Buttons, scripts and secure behaviour stay Blizzard's;
    the icons are plain textures on the buttons. General > Chrome icons "flat" hides them. ]]
M.MACRO_CONTROLS = {
    { "MacroNewButton", "macro-new" }, { "MacroDeleteButton", "macro-delete" }, { "MacroSaveButton", "macro-save" },
    { "MacroEditButton", "macro-rename" }, { "MacroFrameTab1", "macro-general" }, { "MacroFrameTab2", "macro-character" },
}
local done = setmetatable({}, { __mode = "k" })

function M:SetupMacro()
    local CB = ns.ChromeBevel
    if not (CB and rawget(_G, "MacroFrame")) then return end
    for _, entry in ipairs(self.MACRO_CONTROLS) do
        local b = rawget(_G, entry[1])
        if b and b.CreateTexture and not done[b] then
            -- an empty anchor for the icon at the button's left; the label keeps its place
            local slot = b:CreateTexture(nil, "ARTWORK")
            slot:SetSize(14, 14)
            slot:SetPoint("LEFT", 4, 0)
            slot:SetColorTexture(0, 0, 0, 0)
            local ic = CB:Attach(slot, entry[2], 14, "OVERLAY")
            done[b] = ic or true
            if ic then
                b:HookScript("OnEnter", function() CB:State(ic, "hover") end)
                b:HookScript("OnLeave", function() CB:State(ic, "normal") end)
                b:HookScript("OnMouseDown", function() CB:Flash(ic, function() CB:State(ic, "normal") end) end)
            end
        end
    end
end
M.SETUPS[#M.SETUPS + 1] = "SetupMacro"
