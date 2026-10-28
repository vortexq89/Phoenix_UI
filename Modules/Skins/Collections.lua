local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Warband collections, skins plan window 16: mount and pet lists as Phoenix rows, toys and heirlooms as
    sunken grid cells, the mount display and pet card on Phoenix cards, Mount / Summon as primary buttons.
    Every mount, pet, toy and heirloom icon is the game's own; favourites, filters and summons stay Blizzard's.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.collections and true or false end

M.COLLECTION_LISTS = { { "MountJournal", "ScrollBox" }, { "PetJournal", "ScrollBox" } }
M.COLLECTION_GRIDS = { { "ToyBox", "iconsFrame" }, { "HeirloomsJournal", "iconsFrame" } }

-- Grid cells (toys, heirlooms): every child button on a sunken Phoenix cell.
function M.GridCells(grid, isOn)
    if type(grid) ~= "table" or not grid.GetChildren then return 0 end
    local n = 0
    for _, child in ipairs({ grid:GetChildren() }) do
        if type(child) == "table" and child.GetObjectType and child:GetObjectType() == "Button" then
            n = n + 1
            M.KitCard(child, isOn, "sunken", false)
        end
    end
    return n
end

function M:SkinCollections()
    if not _G.CollectionsJournal then return end
    local isOn = on()
    for _, path in ipairs(self.COLLECTION_LISTS) do
        M.KitScrollBox(M.FramePath(_G, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.45 }) end)
    end
    for _, path in ipairs(self.COLLECTION_GRIDS) do M.GridCells(M.FramePath(_G, path), isOn) end
    local mj = _G.MountJournal
    if mj then M.KitCard(rawget(mj, "MountDisplay"), isOn, "sunken", false) end
    local pj = _G.PetJournal
    if pj then M.KitCard(rawget(pj, "PetCard") or _G.PetJournalPetCard, isOn, "raised", false) end
    M.SkinPopupButton(_G.MountJournalMountButton, "primary", isOn)
    M.SkinPopupButton(_G.PetJournalSummonButton, "primary", isOn)
end

local collectionsHooked
function M:SetupCollections()
    self:SkinCollections()
    local root = _G.CollectionsJournal
    if collectionsHooked or not root then return end
    collectionsHooked = true
    root:HookScript("OnShow", function() M:SkinCollections() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupCollections"
M.RESKINS[#M.RESKINS + 1] = "SkinCollections"
