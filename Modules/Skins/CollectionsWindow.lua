local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns:GetModule("Skins")

--[[ The Phoenix collections window (mounts): our own mount list fed by C_MountJournal. Search, All / Collected
    / Not collected chips (the journal's own filter settings), the mounts as Phoenix rows (the mount's own
    icon, name, source line, favourite star in the accent, missing ones greyed), and Summon / Favourite for
    the picked mount. Summoning is the journal's own call on your click. Pets, toys, heirlooms and
    appearances stay in Blizzard's window: it shows whenever another tab is picked (or with the arrow).
    Skins > "Phoenix collections window" off: Blizzard's collections, reskinned, live. ]]

local W_LIST, ROWS, ROW_H = 420, 11, 38
local r, list
local picked

function M.MountRecord(i)
    local name, spellID, icon, isActive, isUsable, _, isFavorite, _, _, hidden, isCollected, mountID =
        C_MountJournal.GetDisplayedMountInfo(i)
    if not name or hidden then return nil end
    return { index = i, name = tostring(name), spellID = spellID, icon = icon, active = isActive and true or false,
        usable = isUsable and true or false, favorite = isFavorite and true or false,
        collected = isCollected and true or false, mountID = mountID }
end

local function mounts()
    local out = {}
    for i = 1, (tonumber(C_MountJournal.GetNumDisplayedMounts()) or 0) do
        local m = M.MountRecord(i)
        if m then out[#out + 1] = m end
    end
    return out
end

local function layout()
    local all = mounts()
    local have = 0
    for _, m in ipairs(all) do if m.collected then have = have + 1 end end
    r.count:SetText(L.COLLW_COUNT:format(have, #all))
    local pick
    list.Set(all, function(b, m)
        b.icon:SetTexture(m.icon)
        b.icon:SetDesaturated(not m.collected)
        b.title:SetText(m.name)
        b.sub:SetText(m.active and L.COLLW_ACTIVE or "")
        b.right:SetText(m.favorite and "|A:PetJournal-FavoritesIcon:14:14|a" or "")
        if m.mountID == picked then pick = m; list.Mark(b, "accent.primary", 0.25) end
        if m.favorite then list.Bar(b, "accent.primary") end
    end)
    r.pick = pick
    r.summon:SetShown(pick ~= nil and pick.collected and pick.usable)
    r.fav:SetShown(pick ~= nil and pick.collected)
end

local function build(rr)
    r = rr
    r.search = W:Input(r.body, 200, SEARCH or "")
    r.search:SetPoint("TOPLEFT", 0, 0)
    r.search.onTextChanged = function(_, text) C_MountJournal.SetSearch(text or "") end
    r.chips = {}
    local prev = r.search
    for _, key in ipairs({ "all", "collected", "missing" }) do
        local label = ({ all = L.SKINS_CHIP_ALL, collected = L.SKINS_CHIP_COLLECTED, missing = L.SKINS_CHIP_MISSING })[key]
        local b = W:Button(r.body, label, "secondary", nil, 96)
        b:SetHeight(22)
        b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        b.onClick = function()
            local collected, missing = M.MountChipFilters(key)
            local fc, fn = _G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, _G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED
            if type(fc) ~= "number" or type(fn) ~= "number" then return end
            C_MountJournal.SetCollectedFilterSetting(fc, collected)
            C_MountJournal.SetCollectedFilterSetting(fn, missing)
            r:Soon()
        end
        r.chips[#r.chips + 1], prev = b, b
    end
    r.count = W.Text(r.body, "small", "text.muted")
    r.count:SetPoint("TOPRIGHT", 0, -6)
    list = M.ReplaceList(r.body, ROWS, ROW_H, W_LIST + 140, 30)
    list:SetPoint("TOPLEFT", 0, -32)
    list.onClick = function(m, button)
        if IsModifiedClick("CHATLINK") and m.spellID then
            ChatFrameUtil.InsertLink(C_Spell.GetSpellLink(m.spellID))
            return
        end
        picked = m.mountID
        if button == "RightButton" and m.collected and m.usable then C_MountJournal.SummonByID(m.mountID) end
        r:Layout()
    end
    list.onEnter = function(m, b)
        if not m.spellID then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(C_Spell.GetSpellLink(m.spellID))
        GameTooltip:Show()
    end
    r.summon = W:Button(r.body, L.COLLW_SUMMON, "primary", "play", 120)
    r.summon:SetPoint("BOTTOMLEFT", 0, 0)
    r.summon.onClick = function() if r.pick then C_MountJournal.SummonByID(r.pick.mountID) end end
    r.fav = W:Button(r.body, L.COLLW_FAVOURITE, "secondary", "heart", 120)
    r.fav:SetPoint("LEFT", r.summon, "RIGHT", 6, 0)
    r.fav.onClick = function() if r.pick then C_MountJournal.SetIsFavorite(r.pick.index, not r.pick.favorite) end end
end

local function mountsTab()
    local f = _G.CollectionsJournal
    local t = f and PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(f)
    return tonumber(t) == nil or tonumber(t) == 1
end

local coll = M.Replacement({ key = "ownCollections", frame = "CollectionsJournal", title = L.COLLW_TITLE,
    width = W_LIST + 160, height = 34 + 32 + ROWS * ROW_H + 50, build = build, layout = layout, ready = mountsTab,
    close = function() if CollectionsJournal then HideUIPanel(CollectionsJournal) end end })
M.CollectionsReplacement = coll

local tabHooked
function M:SetupCollectionsWindow()
    if not M.ReplacementHook(coll) then return end
    if not tabHooked and type(CollectionsJournal_SetTab) == "function" then
        tabHooked = true
        hooksecurefunc("CollectionsJournal_SetTab", function() coll:Sync() end)
    end
    for _, event in ipairs({ "MOUNT_JOURNAL_SEARCH_UPDATED", "COMPANION_UPDATE", "NEW_MOUNT_ADDED" }) do
        ns.Events:On(event, coll, function() coll:Soon() end)
    end
    coll:Sync()
end
function M:SyncCollections() coll:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupCollectionsWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncCollections"
