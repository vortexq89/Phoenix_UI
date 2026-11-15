local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns:GetModule("Skins")

--[[ The Phoenix collections window: our own collections fed by the journal APIs, one tab each for mounts,
    pets, toys, heirlooms and appearances. Every tab: search, All / Collected / Not collected chips (the
    journal's own filter settings), Phoenix rows with the game's own icons (missing ones greyed, favourites
    with the star and an accent bar), and the tab's action for the picked entry: summon a mount or pet, use a
    toy, create an heirloom, favourite. Appearances: the slot categories with collected / total and a progress
    fill; pick one to list its appearances. Using a toy goes through a secure button of ours (type "toy"),
    set up out of combat only; every other action is the journal's own call on your click.
    Skins > "Phoenix collections window" off: Blizzard's collections, reskinned, live. ]]

local W_LIST, ROWS, ROW_H = 560, 11, 38
local r, list
local mode, picked, appCategory = "mounts", nil, nil
local STAR = "|A:PetJournal-FavoritesIcon:14:14|a"

function M.MountRecord(i)
    local name, spellID, icon, isActive, isUsable, _, isFavorite, _, _, hidden, isCollected, mountID =
        C_MountJournal.GetDisplayedMountInfo(i)
    if not name or hidden then return nil end
    return { key = "m" .. tostring(mountID), index = i, name = tostring(name), spellID = spellID, icon = icon,
        active = isActive and true or false, usable = isUsable and true or false, favorite = isFavorite and true or false,
        collected = isCollected and true or false, mountID = mountID }
end

local MODES = {}

MODES.mounts = {
    list = function()
        local out = {}
        for i = 1, (tonumber(C_MountJournal.GetNumDisplayedMounts()) or 0) do out[#out + 1] = M.MountRecord(i) end
        return out
    end,
    search = function(t) C_MountJournal.SetSearch(t) end,
    filter = function(collected, missing)
        local fc, fn = _G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, _G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED
        if type(fc) ~= "number" or type(fn) ~= "number" then return end
        C_MountJournal.SetCollectedFilterSetting(fc, collected)
        C_MountJournal.SetCollectedFilterSetting(fn, missing)
    end,
    act = function(e) if e.collected and e.usable then C_MountJournal.SummonByID(e.mountID) end end,
    canAct = function(e) return e.collected and e.usable end, actLabel = function() return L.COLLW_SUMMON end,
    fav = function(e) C_MountJournal.SetIsFavorite(e.index, not e.favorite) end,
    link = function(e) return e.spellID and C_Spell.GetSpellLink(e.spellID) end,
    sub = function(e) return e.active and L.COLLW_ACTIVE or "" end,
}

MODES.pets = {
    list = function()
        local out = {}
        for i = 1, (tonumber((C_PetJournal.GetNumPets())) or 0) do
            local petID, _, owned, customName, level, favorite, _, speciesName, icon = C_PetJournal.GetPetInfoByIndex(i)
            if speciesName then
                out[#out + 1] = { key = "p" .. tostring(petID or i), petID = petID, name = tostring(customName or speciesName),
                    icon = icon, collected = owned and true or false, favorite = favorite and true or false,
                    level = tonumber(level) or 0 }
            end
        end
        return out
    end,
    search = function(t) C_PetJournal.SetSearchFilter(t) end,
    filter = function(collected, missing)
        local fc, fn = _G.LE_PET_JOURNAL_FILTER_COLLECTED, _G.LE_PET_JOURNAL_FILTER_NOT_COLLECTED
        if type(fc) ~= "number" or type(fn) ~= "number" then return end
        C_PetJournal.SetFilterChecked(fc, collected)
        C_PetJournal.SetFilterChecked(fn, missing)
    end,
    act = function(e) if e.collected and e.petID then C_PetJournal.SummonPetByGUID(e.petID) end end,
    canAct = function(e) return e.collected and e.petID ~= nil end, actLabel = function() return L.COLLW_SUMMON end,
    fav = function(e) if e.petID then C_PetJournal.SetFavorite(e.petID, e.favorite and 0 or 1) end end,
    link = function(e) return e.petID and C_PetJournal.GetBattlePetLink(e.petID) end,
    sub = function(e) return e.collected and e.level > 0 and L.COLLW_LEVEL:format(e.level) or "" end,
}

MODES.toys = {
    list = function()
        local out = {}
        for i = 1, (tonumber(C_ToyBox.GetNumFilteredToys()) or 0) do
            local itemID = C_ToyBox.GetToyFromIndex(i)
            if itemID and itemID > 0 then
                local _, name, icon, favorite = C_ToyBox.GetToyInfo(itemID)
                out[#out + 1] = { key = "t" .. itemID, itemID = itemID, name = tostring(name or itemID), icon = icon,
                    favorite = favorite and true or false, collected = PlayerHasToy(itemID) and true or false }
            end
        end
        return out
    end,
    search = function(t) C_ToyBox.SetFilterString(t) end,
    filter = function(collected, missing) C_ToyBox.SetCollectedShown(collected); C_ToyBox.SetUncollectedShown(missing) end,
    secure = true, -- used through the row's secure toy button
    fav = function(e) C_ToyBox.SetIsFavorite(e.itemID, not e.favorite) end,
    link = function(e) return C_ToyBox.GetToyLink(e.itemID) end,
    sub = function(e) return e.collected and L.COLLW_USE_HINT or "" end,
}

MODES.heirlooms = {
    list = function()
        local out = {}
        for i = 1, (tonumber(C_Heirloom.GetNumDisplayedHeirlooms()) or 0) do
            local itemID = C_Heirloom.GetHeirloomItemIDFromDisplayedIndex(i)
            if itemID then
                local name, _, _, icon, upgrade = C_Heirloom.GetHeirloomInfo(itemID)
                out[#out + 1] = { key = "h" .. itemID, itemID = itemID, name = tostring(name or itemID), icon = icon,
                    collected = C_Heirloom.PlayerHasHeirloom(itemID) and true or false, upgrade = tonumber(upgrade) or 0,
                    max = tonumber(C_Heirloom.GetHeirloomMaxUpgradeLevel(itemID)) or 0 }
            end
        end
        return out
    end,
    search = function(t) C_Heirloom.SetSearch(t) end,
    filter = function(collected, missing)
        C_Heirloom.SetCollectedHeirloomFilter(collected); C_Heirloom.SetUncollectedHeirloomFilter(missing)
    end,
    act = function(e) if e.collected then C_Heirloom.CreateHeirloom(e.itemID) end end,
    canAct = function(e) return e.collected end, actLabel = function() return L.COLLW_CREATE end,
    link = function(e) return C_Heirloom.GetHeirloomLink(e.itemID) end,
    sub = function(e) return e.collected and L.COLLW_UPGRADE:format(e.upgrade, e.max) or "" end,
}

-- Appearance categories with collected / total (plain numbers).
function M.AppearanceCategories()
    local out = {}
    for cat = 1, 40 do
        local name = C_TransmogCollection.GetCategoryInfo(cat)
        if name then
            local have = tonumber(C_TransmogCollection.GetCategoryCollectedCount(cat)) or 0
            local total = tonumber(C_TransmogCollection.GetCategoryTotal(cat)) or 0
            if total > 0 then
                out[#out + 1] = { key = "c" .. cat, category = cat, name = tostring(name), have = have, total = total,
                    collected = have >= total }
            end
        end
    end
    return out
end

local function appearances(cat)
    local out = {}
    local all = C_TransmogCollection.GetCategoryAppearances(cat)
    for _, a in ipairs(type(all) == "table" and all or {}) do
        if type(a) == "table" and a.visualID then
            out[#out + 1] = { key = "a" .. a.visualID, visualID = a.visualID, collected = a.isCollected and true or false,
                favorite = a.isFavorite and true or false }
        end
    end
    return out
end

-- An appearance's first source: its icon and item name (looked up only for rows on screen).
local function appearanceSource(e)
    if e.source ~= nil then return end
    e.source = false
    local sources = C_TransmogCollection.GetAppearanceSources(e.visualID)
    local s = type(sources) == "table" and sources[1]
    if type(s) == "table" and s.sourceID then
        e.source = s.sourceID
        e.icon = C_TransmogCollection.GetSourceIcon(s.sourceID)
        local info = C_TransmogCollection.GetSourceInfo(s.sourceID)
        e.name = type(info) == "table" and info.name and tostring(info.name) or ""
        e.link = type(info) == "table" and info.itemLink or nil
    end
end

MODES.appearances = {
    list = function()
        if not appCategory then return M.AppearanceCategories() end
        return appearances(appCategory)
    end,
    search = function() end,
    filter = function(collected, missing)
        C_TransmogCollection.SetCollectedShown(collected); C_TransmogCollection.SetUncollectedShown(missing)
    end,
    fav = function(e) if e.visualID then C_TransmogCollection.SetIsAppearanceFavorite(e.visualID, not e.favorite) end end,
    link = function(e) return e.link end,
    sub = function(e)
        if e.category then return ("%d / %d"):format(e.have, e.total) end
        return ""
    end,
}

---------------------------------------------------------------- secure toy buttons (ours, one per row)
-- Parented to UIParent and only anchored over the row's icon out of combat; when combat starts every toy
-- button is hidden and un-anchored, so no Phoenix frame is ever tied to a protected one in combat.
local toyButtons = {}
local function toyButton(row, e)
    if InCombatLockdown() then return end
    local b = toyButtons[row]
    if not e or not e.collected or not row:IsVisible() then if b then b:Hide(); b:ClearAllPoints() end; return end
    if not b then
        b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "toy")
        b:SetScript("OnEnter", function() local h = row:GetScript("OnEnter"); if h then h(row) end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        toyButtons[row] = b
    end
    b:SetAttribute("toy", e.itemID)
    b:ClearAllPoints()
    b:SetAllPoints(row.icon or row)
    b:SetFrameStrata(r.win:GetFrameStrata())
    b:SetFrameLevel(row:GetFrameLevel() + 5)
    b:Show()
end
function M.HideToyButtons()
    if InCombatLockdown() then return end
    for _, b in pairs(toyButtons) do b:Hide(); b:ClearAllPoints() end
end

local function paint(b, e)
    local m = MODES[mode]
    if mode == "appearances" and e.visualID then appearanceSource(e) end
    if b.icon then
        b.icon:SetTexture(e.icon or (e.category and 132649) or nil)
        b.icon:SetDesaturated(not e.collected)
    end
    b.title:SetText(e.name or "")
    b.sub:SetText(m.sub(e))
    b.right:SetText(e.favorite and STAR or "")
    if e.category then list.Progress(b, e.total > 0 and e.have / e.total or 0) end
    if e.key == picked then list.Mark(b, "accent.primary", 0.25) end
    if e.favorite then list.Bar(b, "accent.primary") end
    toyButton(b, mode == "toys" and e or nil)
end

local function layout()
    r.tabs.Paint(mode)
    local m = MODES[mode]
    local all = m.list()
    local have = 0
    for _, e in ipairs(all) do if e.collected then have = have + 1 end end
    r.count:SetText(L.COLLW_COUNT:format(have, #all))
    r.back:SetShown(mode == "appearances" and appCategory ~= nil)
    local pick
    for _, e in ipairs(all) do if e.key == picked then pick = e end end
    if mode ~= "toys" and not InCombatLockdown() then M.HideToyButtons() end
    list.Set(all, paint)
    for _, row in ipairs(list.rows) do if not row:IsShown() then toyButton(row, nil) end end
    r.pick = pick
    r.action:SetShown(pick ~= nil and m.act ~= nil and m.canAct(pick))
    if m.actLabel then r.action:SetText(m.actLabel()) end
    r.fav:SetShown(pick ~= nil and m.fav ~= nil and pick.collected and not pick.category)
end

local function build(rr)
    r = rr
    r.tabs = M.ReplaceTabs(r.body, {
        { key = "mounts", label = L.COLLW_TITLE }, { key = "pets", label = L.COLLW_PETS }, { key = "toys", label = L.COLLW_TOYS },
        { key = "heirlooms", label = L.COLLW_HEIRLOOMS }, { key = "appearances", label = L.COLLW_APPEARANCES } }, 104,
        function(key)
            mode, picked, appCategory, list.offset = key, nil, nil, 0
            r.search:SetValue("")
            r:Layout()
        end)
    r.search = W:Input(r.body, 200, SEARCH or "")
    r.search:SetPoint("TOPLEFT", 0, -28)
    r.search.onTextChanged = function(_, text) MODES[mode].search(text or ""); r:Soon() end
    local prev = r.search
    for _, key in ipairs({ "all", "collected", "missing" }) do
        local label = ({ all = L.SKINS_CHIP_ALL, collected = L.SKINS_CHIP_COLLECTED, missing = L.SKINS_CHIP_MISSING })[key]
        local b = W:Button(r.body, label, "secondary", nil, 96)
        b:SetHeight(22)
        b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        b.onClick = function() MODES[mode].filter(M.MountChipFilters(key)); r:Soon() end
        prev = b
    end
    r.count = W.Text(r.body, "small", "text.muted")
    r.count:SetPoint("TOPRIGHT", 0, -34)
    list = M.ReplaceList(r.body, ROWS, ROW_H, W_LIST, 30)
    list:SetPoint("TOPLEFT", 0, -58)
    list.onClick = function(e, button)
        local m = MODES[mode]
        if IsModifiedClick("CHATLINK") and m.link then
            local link = m.link(e)
            if link then ChatFrameUtil.InsertLink(link) end
            return
        end
        if e.category then appCategory, list.offset = e.category, 0; r:Layout(); return end
        picked = e.key
        if button == "RightButton" and m.act and m.canAct(e) then m.act(e) end
        r:Layout()
    end
    list.onEnter = function(e, b)
        local link = MODES[mode].link and MODES[mode].link(e)
        if not link then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
    r.action = W:Button(r.body, L.COLLW_SUMMON, "primary", "play", 120)
    r.action:SetPoint("BOTTOMLEFT", 0, 0)
    r.action.onClick = function() local m = MODES[mode]; if r.pick and m.act then m.act(r.pick) end end
    r.fav = W:Button(r.body, L.COLLW_FAVOURITE, "secondary", "heart", 120)
    r.fav:SetPoint("LEFT", r.action, "RIGHT", 6, 0)
    r.fav.onClick = function() local m = MODES[mode]; if r.pick and m.fav then m.fav(r.pick) end; r:Soon() end
    r.back = W:Button(r.body, BACK or "<", "secondary", nil, 90)
    r.back:SetPoint("BOTTOMRIGHT", 0, 0)
    r.back.onClick = function() appCategory, list.offset = nil, 0; r:Layout() end
    r.win:HookScript("OnHide", function() M.HideToyButtons() end)
end

local coll = M.Replacement({ key = "ownCollections", frame = "CollectionsJournal", title = L.COLLW_WINDOW,
    width = W_LIST + 20, height = 34 + 58 + ROWS * ROW_H + 50, build = build, layout = layout,
    close = function() if CollectionsJournal then HideUIPanel(CollectionsJournal) end end })
M.CollectionsReplacement = coll
function M.CollectionsMode(m) if m then mode, picked, appCategory = m, nil, nil end; return mode end

function M:SetupCollectionsWindow()
    if not M.ReplacementHook(coll) then return end
    for _, event in ipairs({ "MOUNT_JOURNAL_SEARCH_UPDATED", "COMPANION_UPDATE", "NEW_MOUNT_ADDED", "PET_JOURNAL_LIST_UPDATE",
        "TOYS_UPDATED", "HEIRLOOMS_UPDATED", "TRANSMOG_COLLECTION_UPDATED" }) do
        ns.Events:On(event, coll, function() coll:Soon() end)
    end
    -- combat begins: un-anchor and hide every toy button (PLAYER_REGEN_DISABLED fires just before lockdown)
    ns.Events:On("PLAYER_REGEN_DISABLED", coll, function() for _, b in pairs(toyButtons) do b:Hide(); b:ClearAllPoints() end end)
    coll:Sync()
end
function M:SyncCollections() coll:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupCollectionsWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncCollections"
