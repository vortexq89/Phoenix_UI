local _, ns = ...
local Skin = ns.Skin
local M = ns:GetModule("Skins")

--[[ Professions, skins plan window 11 (window chrome and tabs: shared skin): the recipe list as Phoenix rows
    (category headers in the accent, the selected recipe outlined), the schematic as a raised card, the craft
    buttons in Phoenix style (Craft primary), and the customer orders list as rows. Reagent and recipe icons
    and quality pips are the game's own; crafting stays Blizzard's click. Live with Skins > Professions. ]]

local function on() return M:IsEnabled() and M.db.professions and true or false end

local function recipeRow(row, isOn)
    local data = row.GetElementData and select(2, pcall(row.GetElementData, row))
    local node = type(data) == "table" and data.GetData and select(2, pcall(data.GetData, data))
    local header = type(node) == "table" and node.categoryInfo ~= nil
    M.KitRow(row, isOn, { alpha = header and 0 or 0.45 })
    local label = row.Label or row.Name
    if label and label.SetTextColor then
        if isOn and header then Skin:Text(label, "heading", "accent.primary") elseif not isOn then Skin:Restore(label) end
    end
end

function M:SkinProfessions()
    local pf = _G.ProfessionsFrame
    local isOn = on()
    if pf then
        local page = pf.CraftingPage
        if page then
            M.KitScrollBox(M.FramePath(pf, { "CraftingPage", "RecipeList", "ScrollBox" }), on, recipeRow)
            M.KitCard(page.SchematicForm, isOn, "raised", false)
            M.SkinPopupButton(page.CreateButton, "primary", isOn)
            M.SkinPopupButton(page.CreateAllButton, "secondary", isOn)
        end
        local orders = pf.OrdersPage
        if orders then M.KitScrollBox(M.FramePath(pf, { "OrdersPage", "BrowseFrame", "OrderList", "ScrollBox" }), on, M.KitRow) end
    end
    local co = _G.ProfessionsCustomerOrdersFrame
    if co then
        M.KitScrollBox(M.FramePath(co, { "BrowseOrders", "RecipeList", "ScrollBox" }), on, M.KitRow)
        if isOn then M.SkinWindow(co, false) else M.UnskinWindow(co) end
    end
end

local profHooked
function M:SetupProfessions()
    self:SkinProfessions()
    local pf = _G.ProfessionsFrame
    if profHooked or not pf then return end
    profHooked = true
    pf:HookScript("OnShow", function() M:SkinProfessions() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupProfessions"
M.RESKINS[#M.RESKINS + 1] = "SkinProfessions"
