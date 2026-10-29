local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix character window: our own character panel fed by the game's stat, reputation and currency API.
    Left: the equipped items in two columns (the items' own icons, quality as a 1px border, item level), with the
    game's tooltip, shift-click to link, click or drag to pick up and drop to equip (plain inventory calls, not
    protected). Right, three tabs: Stats (item level, health, primary stat, stamina, armor, secondary and tertiary
    stats), Reputation (headers expand / collapse, click a faction to track it) and Currency (headers expand /
    collapse, tooltip, shift-click link), Titles (click to wear one) and Sets (equip, save the gear you wear,
    delete with a second click, new set from a name), with a search box. The model and the set icon picker stay
    Blizzard's (the arrow button). Skins > "Phoenix character window" off: Blizzard's panel, reskinned, live. ]]

local SLOT, GAP, LIST_W, ROWS, ROW_H = 40, 6, 470, 12, 32
local MODEL_W, TAB_W = 210, 104 -- the player model sits between the two slot columns, as in Blizzard's panel
local LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
    "MainHandSlot" }
local RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
    "Trinket1Slot", "SecondaryHandSlot" }
local TABS = { "stats", "reputation", "currency", "titles", "sets" } -- the first three match Blizzard's tabs

local r, list
local mode, search = "stats", ""
local slots = {}
local armed -- equipment set ID waiting for the confirming second Delete click

local function pct(v) return ("%.2f%%"):format(tonumber(v) or 0) end

-- WoW Forever's simplified stats: the five attributes, then the numbers a level-60 character plays by (attack
-- power, spell power, hit, crits, avoidance); retail's haste / mastery / versatility rows mean nothing there.
-- Each API is looked up and skipped when the client lacks it.
function M.ForeverStats()
    local out = {}
    local function add(label, value) if label and value ~= nil then out[#out + 1] = { label = tostring(label), value = value } end end
    local function call(name, ...)
        local fn = _G[name]
        if type(fn) ~= "function" then return nil end
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
    end
    local _, equipped = GetAverageItemLevel()
    add(STAT_AVERAGE_ITEM_LEVEL, ("%.1f"):format(tonumber(equipped) or 0))
    add(HEALTH, UnitHealthMax("player"))
    for i = 1, 5 do add(_G["SPELL_STAT" .. i .. "_NAME"], (UnitStat("player", i))) end
    add(STAT_ARMOR, (UnitArmor("player")))
    local base, plus, minus = call("UnitAttackPower", "player")
    if tonumber(base) then add(_G.STAT_ATTACK_POWER or _G.ATTACK_POWER, base + (tonumber(plus) or 0) + (tonumber(minus) or 0)) end
    local sp = call("GetSpellBonusDamage", 2)
    if tonumber(sp) then add(_G.STAT_SPELLDAMAGE or _G.STAT_SPELLPOWER, sp) end
    local heal = call("GetSpellBonusHealing")
    if tonumber(heal) then add(_G.STAT_SPELLHEALING, heal) end
    local hit = call("GetHitModifier")
    if tonumber(hit) then add(_G.STAT_HIT_CHANCE, pct(hit)) end
    add(_G.MELEE_CRIT_CHANCE or STAT_CRITICAL_STRIKE, pct(call("GetCritChance")))
    local sc = call("GetSpellCritChance", 2)
    if tonumber(sc) then add(_G.SPELL_CRIT_CHANCE, pct(sc)) end
    add(_G.STAT_DODGE, tonumber((call("GetDodgeChance"))) and pct(call("GetDodgeChance")) or nil)
    add(_G.STAT_PARRY, tonumber((call("GetParryChance"))) and pct(call("GetParryChance")) or nil)
    add(_G.STAT_BLOCK, tonumber((call("GetBlockChance"))) and pct(call("GetBlockChance")) or nil)
    return out
end

-- The stat rows: { label, value } with values as the game reports them.
function M.CharacterStats()
    if ns.flavor == "forever" then return M.ForeverStats() end
    local out = {}
    local function add(label, value) out[#out + 1] = { label = tostring(label or ""), value = value } end
    local _, equipped = GetAverageItemLevel()
    add(STAT_AVERAGE_ITEM_LEVEL, ("%.1f"):format(tonumber(equipped) or 0))
    add(HEALTH, UnitHealthMax("player"))
    local SI = _G.C_SpecializationInfo or {}
    local getSpec, getInfo = SI.GetSpecialization or _G.GetSpecialization, SI.GetSpecializationInfo or _G.GetSpecializationInfo
    local spec = getSpec and getSpec()
    local primary = spec and getInfo and select(6, getInfo(spec))
    if tonumber(primary) then add(_G["SPELL_STAT" .. primary .. "_NAME"], (UnitStat("player", primary))) end
    add(_G.SPELL_STAT3_NAME, (UnitStat("player", 3)))
    add(STAT_ARMOR, (UnitArmor("player")))
    add(STAT_CRITICAL_STRIKE, pct(GetCritChance()))
    add(STAT_HASTE, pct(GetHaste()))
    add(STAT_MASTERY, pct((GetMasteryEffect())))
    local vers = _G.CR_VERSATILITY_DAMAGE_DONE
    if vers then add(STAT_VERSATILITY, pct((tonumber(GetCombatRatingBonus(vers)) or 0) + (tonumber(GetVersatilityBonus(vers)) or 0))) end
    if GetLifesteal then add(STAT_LIFESTEAL, pct(GetLifesteal())) end
    if GetAvoidance then add(STAT_AVOIDANCE, pct(GetAvoidance())) end
    if GetSpeed then add(STAT_SPEED, pct(GetSpeed())) end
    return out
end

local function matches(name) return search == "" or name:lower():find(search:lower(), 1, true) ~= nil end

local function friendship(id)
    local G = _G.C_GossipInfo
    local f = G and G.GetFriendshipReputation and G.GetFriendshipReputation(id)
    if type(f) ~= "table" or (tonumber(f.friendshipFactionID) or 0) <= 0 then return nil end
    local lo, hi = tonumber(f.reactionThreshold) or 0, tonumber(f.nextThreshold) or 0
    local have = (tonumber(f.standing) or 0) - lo
    return tostring(f.reaction or ""), hi > lo and have / (hi - lo) or 1, hi > lo and ("%d / %d"):format(have, hi - lo) or ""
end

local function standing(d)
    local id = d.factionID
    local C = _G.C_MajorFactions
    if C and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(id) then
        local m = C.GetMajorFactionData(id) or {}
        local earned, need = tonumber(m.renownReputationEarned) or 0, tonumber(m.renownLevelThreshold) or 0
        return L.EJW_RENOWN:format(tonumber(m.renownLevel) or 0), need > 0 and earned / need or 0, ("%d / %d"):format(earned, need)
    end
    local text, progress, count = friendship(id)
    if text then return text, progress, count end
    local lo, hi = tonumber(d.currentReactionThreshold) or 0, tonumber(d.nextReactionThreshold) or 0
    local have = (tonumber(d.currentStanding) or 0) - lo
    return tostring(_G["FACTION_STANDING_LABEL" .. tostring(d.reaction)] or ""), hi > lo and have / (hi - lo) or 1,
        hi > lo and ("%d / %d"):format(have, hi - lo) or ""
end

-- Reputation rows in the game's order (headers included so they can open and close).
function M.CharacterReputation()
    local out = {}
    local R = _G.C_Reputation
    if not (R and R.GetFactionDataByIndex) then return out end
    for i = 1, tonumber(R.GetNumFactions()) or 0 do
        local d = R.GetFactionDataByIndex(i)
        if type(d) == "table" and d.name then
            local rec = { index = i, name = tostring(d.name), header = d.isHeader and true or false, open = not d.isCollapsed,
                watched = d.isWatched and true or false, id = d.factionID }
            if not rec.header or d.isHeaderWithRep then rec.text, rec.progress, rec.count = standing(d) end
            if rec.header or matches(rec.name) then out[#out + 1] = rec end
        end
    end
    return out
end

-- Currency rows in the game's order (headers included).
function M.CharacterCurrency()
    local out = {}
    local C = C_CurrencyInfo
    if not (C and C.GetCurrencyListSize) then return out end
    for i = 1, tonumber(C.GetCurrencyListSize()) or 0 do
        local d = C.GetCurrencyListInfo(i)
        if type(d) == "table" and d.name then
            local rec = { index = i, name = tostring(d.name), header = d.isHeader and true or false, open = d.isHeaderExpanded,
                icon = d.iconFileID, quantity = tonumber(d.quantity) or 0, max = tonumber(d.maxQuantity) or 0 }
            if rec.header or matches(rec.name) then out[#out + 1] = rec end
        end
    end
    return out
end

-- Known titles ("no title" first), the one you wear marked.
function M.CharacterTitles()
    local out = { { id = -1, name = tostring(_G.NONE or "None"), current = (tonumber(GetCurrentTitle()) or -1) <= 0 } }
    local current = tonumber(GetCurrentTitle()) or -1
    for i = 1, tonumber(GetNumTitles()) or 0 do
        if IsTitleKnown(i) then
            local name = GetTitleName(i)
            if name and matches(tostring(name)) then
                out[#out + 1] = { id = i, name = (tostring(name):gsub("^%s+", ""):gsub("%s+$", "")), current = i == current }
            end
        end
    end
    return out
end

-- Equipment sets: name, icon, equipped flag and how many of its items are missing.
function M.CharacterSets()
    local out = {}
    local E = _G.C_EquipmentSet
    if not (E and E.GetEquipmentSetIDs) then return out end
    for _, id in ipairs(E.GetEquipmentSetIDs() or {}) do
        local name, icon, setID, equipped, items, _, _, lost = E.GetEquipmentSetInfo(id)
        if name then
            out[#out + 1] = { id = setID or id, name = tostring(name), icon = icon, equipped = equipped and true or false,
                items = tonumber(items) or 0, lost = tonumber(lost) or 0 }
        end
    end
    return out
end

local function paintSlot(b)
    local tex = GetInventoryItemTexture("player", b.slot)
    b.icon:SetTexture(tex or b.empty)
    b.icon:SetDesaturated(tex == nil)
    -- the game's empty-slot art is near black: drawn additively over the slot fill it reads as a clear outline
    b.icon:SetBlendMode(tex and "BLEND" or "ADD")
    b.icon:SetAlpha(tex and 1 or 0.7)
    local q = tex and GetInventoryItemQuality("player", b.slot)
    local color = type(q) == "number" and q >= 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    Skin:IconFrame(b, b.icon, color and { color = { r = color.r, g = color.g, b = color.b } } or {}, 0.08, "border.subtle")
    local ilvl = tex and ItemLocation and C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(b.slot))
    b.level:SetText(tonumber(ilvl) and tostring(ilvl) or "")
end

local function paintRows()
    if mode == "stats" then
        list.Set(M.CharacterStats(), function(b, s)
            if b.icon then b.icon:SetTexture(nil) end -- rows are pooled: no icon left over from another tab
            b.title:SetText(s.label); b.sub:SetText(""); b.right:SetText(s.value)
        end)
        return
    end
    if mode == "titles" then
        list.Set(M.CharacterTitles(), function(b, t)
            if b.icon then b.icon:SetTexture(nil) end
            b.title:SetText(t.name); b.sub:SetText(""); b.right:SetText("")
            if t.current then list.Mark(b, "accent.primary", 0.25); list.Bar(b, "accent.primary") end
        end)
        return
    end
    if mode == "sets" then
        list.Set(M.CharacterSets(), function(b, e)
            if b.icon then b.icon:SetTexture(e.icon) end
            b.title:SetText(e.name)
            b.sub:SetText(e.lost > 0 and L.CHARW_SET_MISSING:format(e.lost) or "")
            b.right:SetText(e.equipped and L.CHARW_SET_EQUIPPED or "")
            if e.id == r.pickSet then list.Mark(b, "accent.primary", 0.25) end
            if e.equipped then list.Bar(b, "state.success") end
        end)
        return
    end
    local items = mode == "reputation" and M.CharacterReputation() or M.CharacterCurrency()
    list.Set(items, function(b, e)
        if b.icon then b.icon:SetTexture(e.icon) end
        if e.header then
            b.title:SetText((e.open and "- " or "+ ") .. e.name)
            list.Mark(b, "bg.hover", 0.8)
        else
            b.title:SetText(e.name)
        end
        if mode == "reputation" then
            b.sub:SetText(e.text or "")
            b.right:SetText(e.count or "")
            if e.progress then list.Progress(b, e.progress) end
            if e.watched then list.Bar(b, "accent.primary") end
        else
            b.sub:SetText("")
            b.right:SetText(e.header and "" or (e.max > 0 and ("%d / %d"):format(e.quantity, e.max) or tostring(e.quantity)))
        end
    end)
end

local function layout()
    r.tabs.Paint(mode)
    for _, b in ipairs(slots) do paintSlot(b) end
    if r.model and r.model:IsVisible() then r.model:RefreshUnit() end
    r.search:SetShown(mode ~= "stats" and mode ~= "sets")
    local sets = mode == "sets"
    for _, w in ipairs(r.setTools) do w:SetShown(sets) end
    r.who:SetShown(not sets)
    if sets then
        local picked = r.pickSet ~= nil
        for _, w in ipairs({ r.equip, r.saveSet, r.deleteSet }) do w:SetEnabled(picked) end
        r.deleteSet:SetText(armed and armed == r.pickSet and L.FRIENDW_REMOVE_CONFIRM or (_G.DELETE or "Delete"))
    end
    local name = UnitName("player")
    r.who:SetText(("%s  %s %s"):format(tostring(name or ""), LEVEL or "Level", tostring(UnitLevel("player") or "")))
    paintRows()
end

local function slotButton(name, col, i)
    local id, empty = _G.GetInventorySlotInfo(name)
    local b = CreateFrame("Button", nil, r.body)
    b:SetSize(SLOT, SLOT)
    b:SetPoint("TOPLEFT", (col - 1) * (SLOT + GAP + MODEL_W), -30 - (i - 1) * (SLOT + GAP))
    b.slot, b.empty = id, empty
    b.fill = b:CreateTexture(nil, "BACKGROUND"); b.fill:SetAllPoints()
    W.Color(b.fill, "bg.raised")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
    b.level = W.Text(b, "small", "text.primary"); b.level:SetPoint("BOTTOMRIGHT", -2, 2)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(self)
        local link = GetInventoryItemLink("player", self.slot)
        if link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(link); return end
        PickupInventoryItem(self.slot)
    end)
    b:SetScript("OnDragStart", function(self) PickupInventoryItem(self.slot) end)
    b:SetScript("OnReceiveDrag", function(self) PickupInventoryItem(self.slot) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", self.slot)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slots[#slots + 1] = b
end

local function rowClick(e)
    if mode == "titles" then SetCurrentTitle(e.id); r:Layout(); return end
    if mode == "sets" then r.pickSet, armed = e.id, nil; r:Layout(); return end
    if mode == "stats" or not e.index then return end
    if mode == "reputation" then
        if e.header then
            if e.open then C_Reputation.CollapseFactionHeader(e.index) else C_Reputation.ExpandFactionHeader(e.index) end
        elseif C_Reputation.SetWatchedFactionByIndex then
            C_Reputation.SetWatchedFactionByIndex(e.watched and 0 or e.index)
        end
    elseif e.header then
        C_CurrencyInfo.ExpandCurrencyList(e.index, not e.open)
    elseif IsModifiedClick("CHATLINK") and C_CurrencyInfo.GetCurrencyListLink then
        ChatFrameUtil.InsertLink(C_CurrencyInfo.GetCurrencyListLink(e.index))
    end
    r:Layout()
end

local function build(rr)
    r = rr
    for i, name in ipairs(LEFT) do slotButton(name, 1, i) end
    for i, name in ipairs(RIGHT) do slotButton(name, 2, i) end
    -- the player in their current gear (a plain PlayerModel: not protected, refreshed when the gear changes)
    r.model = CreateFrame("PlayerModel", nil, r.body)
    r.model:SetPoint("TOPLEFT", SLOT + GAP, -30)
    r.model:SetSize(MODEL_W - GAP, #LEFT * (SLOT + GAP) - GAP)
    r.model:SetUnit("player")
    r.model.bg = r.model:CreateTexture(nil, "BACKGROUND"); r.model.bg:SetAllPoints()
    W.Color(r.model.bg, "bg.sunken")
    local x = 2 * (SLOT + GAP) + MODEL_W + 10
    list = M.ReplaceList(r.body, ROWS, ROW_H, LIST_W, 22)
    list:SetPoint("TOPLEFT", x, -30)
    list.onClick = rowClick
    list.onEnter = function(e, b)
        if mode ~= "currency" or e.header then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyToken(e.index)
        GameTooltip:Show()
    end
    local defs = {}
    for _, key in ipairs(TABS) do defs[#defs + 1] = { key = key, label = L["CHARW_" .. key:upper()] } end
    r.tabs = M.ReplaceTabs(r.body, defs, TAB_W, function(key) mode, list.offset, armed = key, 0, nil; r:Layout() end)
    r.search = W:Input(r.body, 120, SEARCH or "")
    r.search:SetPoint("TOPRIGHT", 0, 0)
    r.search.onTextChanged = function(_, text) search = text or ""; list.offset = 0; r:Layout() end
    r.who = W.Text(r.body, "small", "text.secondary")
    r.who:SetPoint("BOTTOMLEFT", 0, 2)
    M.BuildSetTools(x)
end

-- Equipment set tools under the list: equip, save the gear you wear into the set, delete (second click), and
-- a name box that creates a new set from what you wear (Enter). Out of combat only, like Blizzard's.
function M.BuildSetTools(x)
    local E = _G.C_EquipmentSet
    local function ready() return E and not InCombatLockdown() end
    r.equip = W:Button(r.body, L.CHARW_SET_EQUIP, "primary", nil, 90)
    r.equip:SetHeight(24); r.equip:SetPoint("BOTTOMLEFT", x, 0)
    r.equip.onClick = function() if ready() and r.pickSet then E.UseEquipmentSet(r.pickSet) end end
    r.saveSet = W:Button(r.body, _G.SAVE or "Save", "secondary", nil, 80)
    r.saveSet:SetHeight(24); r.saveSet:SetPoint("LEFT", r.equip, "RIGHT", 6, 0)
    r.saveSet.onClick = function() if ready() and r.pickSet then E.SaveEquipmentSet(r.pickSet); r:Layout() end end
    r.deleteSet = W:Button(r.body, "", "danger", nil, 110)
    r.deleteSet:SetHeight(24); r.deleteSet:SetPoint("LEFT", r.saveSet, "RIGHT", 6, 0)
    r.deleteSet.onClick = function()
        if not (ready() and r.pickSet) then return end
        if armed ~= r.pickSet then armed = r.pickSet; r:Layout(); return end
        E.DeleteEquipmentSet(r.pickSet)
        armed, r.pickSet = nil, nil
        r:Layout()
    end
    r.newSet = W:Input(r.body, 150, L.CHARW_SET_NEW)
    r.newSet:SetPoint("BOTTOMRIGHT", 0, 0)
    r.newSet.onChange = function(box, name)
        name = tostring(name or "")
        if name == "" or not ready() then return end
        E.CreateEquipmentSet(name, r.newIcon or 134400) -- the picked icon, else the question mark
        box:SetValue("")
        r:Layout()
    end
    -- the icon of the picked set (or of the next new one): the shared Phoenix icon picker
    r.setIcon = W:Button(r.body, L.ICON_PICK, "secondary", "grid", 80)
    r.setIcon:SetHeight(24); r.setIcon:SetPoint("RIGHT", r.newSet, "LEFT", -6, 0)
    r.setIcon.onClick = function()
        if not ready() then return end
        local current
        if r.pickSet then current = select(2, E.GetEquipmentSetInfo(r.pickSet)) else current = r.newIcon end
        W:IconPicker():Open(current, function(icon)
            if InCombatLockdown() then return end
            if r.pickSet then
                local name = E.GetEquipmentSetInfo(r.pickSet)
                E.ModifyEquipmentSet(r.pickSet, name, icon)
            else
                r.newIcon = icon
            end
            r:Layout()
        end)
    end
    r.setTools = { r.equip, r.saveSet, r.deleteSet, r.newSet, r.setIcon }
end

-- Which tab Blizzard's panel opened on (U opens reputation, the currency key opens currency).
local function openedTab()
    local f = _G.CharacterFrame
    local t = f and PanelTemplates_GetSelectedTab and tonumber(PanelTemplates_GetSelectedTab(f))
    if t then mode = TABS[t] or "stats" end
end

local char = M.Replacement({ key = "ownCharacter", frame = "CharacterFrame", title = L.CHARW_TITLE,
    width = 2 * (SLOT + GAP) + MODEL_W + 10 + LIST_W + 20, height = 34 + 30 + ROWS * ROW_H + 40, build = build, layout = layout,
    close = function() local f = _G.CharacterFrame; if f then HideUIPanel(f) end end })
char.onOpen = openedTab
M.CharacterReplacement = char
function M.CharacterMode(m) if m then mode = m; char:Layout() end; return mode end

function M:SetupCharacterWindow()
    if not M.ReplacementHook(char) then return end
    for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_STATS", "COMBAT_RATING_UPDATE", "UPDATE_FACTION",
        "CURRENCY_DISPLAY_UPDATE", "PLAYER_AVG_ITEM_LEVEL_UPDATE", "KNOWN_TITLES_UPDATE", "EQUIPMENT_SETS_CHANGED" }) do
        ns.Events:On(event, char, function() char:Soon() end)
    end
    char:Sync()
end
function M:SyncCharacterWindow() char:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupCharacterWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncCharacterWindow"
