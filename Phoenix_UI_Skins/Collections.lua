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

-- Favourite star on a mount / pet row in the accent (Phoenix chrome tint on the star only, white again off).
function M.FavouriteStar(row, isOn)
    local star = type(row) == "table" and (rawget(row, "Favorite") or rawget(row, "favorite"))
    if type(star) ~= "table" or not star.SetVertexColor then return end
    if isOn then
        local r, g, b = ns.Theme:Color("accent.primary")
        star:SetVertexColor(r, g, b, 1)
    else
        star:SetVertexColor(1, 1, 1, 1)
    end
end

-- Mount filter chips: All / Collected / Not collected, through the journal's own filter settings.
M.MOUNT_CHIPS = { "all", "collected", "missing" }
function M.MountChipFilters(key)
    if key == "collected" then return true, false end
    if key == "missing" then return false, true end
    return true, true
end

local mountChips
function M:MountFilterChips(isOn)
    local mj = _G.MountJournal
    local api = C_MountJournal
    local fc, fn = _G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, _G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED
    if not (mj and api and api.SetCollectedFilterSetting and type(fc) == "number" and type(fn) == "number") then return end
    if not isOn then if mountChips then mountChips:Hide() end; return end
    local W = ns.Widgets
    if not mountChips then
        mountChips = CreateFrame("Frame", nil, mj)
        mountChips:SetSize(220, 18)
        local anchor = rawget(mj, "SearchBox") or mj
        mountChips:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        mountChips.chips = {}
        local prev
        for _, key in ipairs(self.MOUNT_CHIPS) do
            local c = CreateFrame("Button", nil, mountChips)
            c.key = key
            c.label = W.Text(c, "small", "text.secondary", "CENTER")
            c.label:SetPoint("CENTER")
            c.label:SetText(ns.L["SKINS_CHIP_" .. key:upper()])
            c:SetSize(math.max(40, (c.label:GetStringWidth() or 30) + 12), 18)
            if prev then c:SetPoint("LEFT", prev, "RIGHT", 3, 0) else c:SetPoint("LEFT") end
            c:SetScript("OnClick", function(self)
                local a, b = M.MountChipFilters(self.key)
                api.SetCollectedFilterSetting(fc, a)
                api.SetCollectedFilterSetting(fn, b)
                M:MountFilterChips(true)
            end)
            mountChips.chips[#mountChips.chips + 1] = c
            prev = c
        end
    end
    local a, b = api.GetCollectedFilterSetting(fc), api.GetCollectedFilterSetting(fn)
    local current = (a and not b) and "collected" or ((b and not a) and "missing" or "all")
    for _, c in ipairs(mountChips.chips) do
        local sel = c.key == current
        ns.Skin:Panel(c, sel and "raised" or "sunken", { border = sel and "accent.primary" or "border.subtle" })
        ns.Skin:Text(c.label, "small", sel and "accent.text" or "text.secondary")
    end
    mountChips:Show()
end

function M:SkinCollections()
    if not _G.CollectionsJournal then return end
    local isOn = on()
    for _, path in ipairs(self.COLLECTION_LISTS) do
        M.KitScrollBox(M.FramePath(_G, path), on, function(row, o)
            M.KitRow(row, o, { alpha = 0.45 })
            M.FavouriteStar(row, o)
        end)
    end
    for _, path in ipairs(self.COLLECTION_GRIDS) do M.GridCells(M.FramePath(_G, path), isOn) end
    local mj = _G.MountJournal
    if mj then M.KitCard(rawget(mj, "MountDisplay"), isOn, "sunken", false) end
    local pj = _G.PetJournal
    if pj then M.KitCard(rawget(pj, "PetCard") or _G.PetJournalPetCard, isOn, "raised", false) end
    self:MountFilterChips(isOn)
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
