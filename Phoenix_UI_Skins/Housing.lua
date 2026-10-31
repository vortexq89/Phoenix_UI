local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Housing dashboard, skins plan window 22: the dashboard in the Phoenix window look, its lists (catalogue,
    plots, neighbourhood) as Phoenix rows and its panels on cards. Housing is new and changes often: every list is
    looked up by path, and a path that is not there shows up as skin-missing in the dev self-test. Decor and
    house art are the game's own; teleport, visit and place stay Blizzard's clicks. ]]

local function on() return M:IsEnabled() and M.db.housing and true or false end

M.HOUSING_LISTS = { { "CatalogContent", "ScrollBox" }, { "HouseInfoContent", "ScrollBox" },
    { "NeighborhoodContent", "ScrollBox" } }

function M:SkinHousing()
    local hd = _G.HousingDashboardFrame
    if not hd then return end
    local isOn = on()
    for _, path in ipairs(self.HOUSING_LISTS) do
        M.KitScrollBox(M.FramePath(hd, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.45 }) end)
    end
    for _, key in ipairs({ "CatalogContent", "HouseInfoContent", "NeighborhoodContent" }) do
        M.KitCard(rawget(hd, key), isOn, "sunken", false)
    end
end

local housingHooked
function M:SetupHousing()
    self:SkinHousing()
    local root = _G.HousingDashboardFrame
    if housingHooked or not root then return end
    housingHooked = true
    root:HookScript("OnShow", function() M:SkinHousing() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupHousing"
M.RESKINS[#M.RESKINS + 1] = "SkinHousing"
