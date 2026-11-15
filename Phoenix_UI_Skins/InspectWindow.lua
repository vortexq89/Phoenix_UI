local _, ns = ...
local L, W, Skin, Secret = ns.L, ns.Widgets, ns.Skin, ns.Secret
local M = ns:GetModule("Skins")

--[[ The Phoenix inspect window: our own view of the player you inspect. Header: name in the class colour, level,
    specialization (with its icon) and guild, the average item level in the accent. Gear: every slot as a Phoenix
    item card (the item's real icon in its quality frame, name, item level, enchanted / gem marks), left and right
    of the player's own 3D model, the weapons underneath. Hover shows the game's tooltip; shift-click links,
    ctrl-click previews. Data from the inspect API after INSPECT_READY (the game's own NotifyInspect).
    Blizzard's InspectFrame stays open and tucked (its talent and PvP tabs: the arrow button). Out of combat only
    (Skin:Tuck). Skins > Phoenix inspect window off: the reskinned Blizzard window, live. ]]

local LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local BOTTOM = { "MainHand", "SecondaryHand" }
local CARD_W, CARD_H, GAP, MODEL_W, HEAD_H = 214, 38, 4, 150, 54
local r

-- Enchant and gem marks from an item link: "item:id:enchant:gem1:gem2:gem3:gem4:…".
function M.InspectLinkMarks(link)
    local body = type(link) == "string" and link:match("item:([%-%d:]*)")
    if not body then return false, 0 end
    local f = { strsplit(":", body) }
    local enchanted = (tonumber(f[2]) or 0) > 0
    local gems = 0
    for i = 3, 6 do if (tonumber(f[i]) or 0) > 0 then gems = gems + 1 end end
    return enchanted, gems
end

-- One gear slot of the inspected unit as plain card data.
function M.InspectSlotData(unit, slotName)
    local id, empty = C_PaperDollInfo.GetInventorySlotInfo(slotName .. "Slot")
    local link = id and GetInventoryItemLink(unit, id)
    local d = { slot = id, slotName = slotName }
    if type(link) ~= "string" then
        d.texture, d.dim, d.name = empty, true, _G[slotName:upper() .. "SLOT"] or L.INSPECTW_EMPTY
        return d
    end
    d.link = link
    local name, _, quality = C_Item.GetItemInfo(link)
    d.name = name or link:match("%[(.-)%]") or ""
    d.quality = quality or GetInventoryItemQuality(unit, id)
    d.texture = GetInventoryItemTexture(unit, id)
    local sub = {}
    local level = tonumber((C_Item.GetDetailedItemLevelInfo(link)))
    if level and level > 0 then sub[#sub + 1] = L.LOOTW_LEVEL:format(level) end
    local enchanted, gems = M.InspectLinkMarks(link)
    if enchanted then sub[#sub + 1] = L.INSPECTW_ENCHANTED end
    if gems > 0 then sub[#sub + 1] = L.INSPECTW_GEMS:format(gems) end
    d.sub = table.concat(sub, "  ·  ")
    return d
end

local function unit() local f = _G.InspectFrame; return f and rawget(f, "unit") or "target" end

local function onEnter(card)
    local d = card.data
    if not d then return end
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    if d.link then GameTooltip:SetInventoryItem(unit(), d.slot) else GameTooltip:SetText(d.name or "") end
    GameTooltip:Show()
end

local function onClick(card)
    local d = card.data
    if not (d and d.link) then return end
    if IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(d.link)
    elseif IsModifiedClick("DRESSUP") and DressUpLink then DressUpLink(d.link) end
end

local function newCard(key)
    local c = M.ReplaceCard(r.body, CARD_W, CARD_H)
    c:SetScript("OnEnter", onEnter)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnClick", onClick)
    r.cards[key] = c
    return c
end

local function build(rr)
    r = rr
    r.cards = {}
    local b = r.body
    r.spec = b:CreateTexture(nil, "ARTWORK")
    r.spec:SetSize(36, 36)
    r.spec:SetPoint("TOPLEFT", 0, -2)
    Skin:Icon(r.spec)
    r.name = W.Text(b, "heading", "text.primary", "LEFT")
    r.name:SetPoint("TOPLEFT", r.spec, "TOPRIGHT", 8, -1)
    r.info = W.Text(b, "small", "text.secondary", "LEFT")
    r.info:SetPoint("BOTTOMLEFT", r.spec, "BOTTOMRIGHT", 8, 1)
    r.ilvl = W.Text(b, "title", "accent.primary", "RIGHT")
    r.ilvl:SetPoint("TOPRIGHT", 0, -2)
    r.ilvlCaption = W.Text(b, "small", "text.muted", "RIGHT")
    r.ilvlCaption:SetPoint("TOPRIGHT", r.ilvl, "BOTTOMRIGHT", 0, -2)
    r.ilvlCaption:SetText(L.INSPECTW_ILVL)
    for i, s in ipairs(LEFT) do newCard(s):SetPoint("TOPLEFT", 0, -HEAD_H - (i - 1) * (CARD_H + GAP)) end
    for i, s in ipairs(RIGHT) do newCard(s):SetPoint("TOPRIGHT", 0, -HEAD_H - (i - 1) * (CARD_H + GAP)) end
    local bottomY = -HEAD_H - #LEFT * (CARD_H + GAP) - 4
    newCard(BOTTOM[1]):SetPoint("TOPRIGHT", b, "TOP", -GAP / 2, bottomY)
    newCard(BOTTOM[2]):SetPoint("TOPLEFT", b, "TOP", GAP / 2, bottomY)
    r.model = CreateFrame("PlayerModel", nil, b)
    r.model:SetPoint("TOP", 0, -HEAD_H)
    r.model:SetSize(MODEL_W, #LEFT * (CARD_H + GAP) - GAP)
end

local function layout()
    local u = unit()
    for _, list in ipairs({ LEFT, RIGHT, BOTTOM }) do
        for _, s in ipairs(list) do
            local c, d = r.cards[s], M.InspectSlotData(u, s)
            c.data = d
            M.PaintCard(c, d)
        end
    end
    r.name:SetText(UnitName(u) or "")
    local _, class = UnitClass(u)
    local cc = class and not Secret.IsSecret(class) and RAID_CLASS_COLORS[class]
    if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else Skin:Text(r.name, "heading", "text.primary") end
    local level = UnitLevel(u)
    local info = { (type(level) == "number" and not Secret.IsSecret(level) and level > 0) and L.INSPECTW_LEVEL:format(level) or nil }
    local SI = C_SpecializationInfo
    local specID = SI and SI.GetInspectSpecialization and SI.GetInspectSpecialization(u)
    local specName, icon
    if type(specID) == "number" and not Secret.IsSecret(specID) and specID > 0 then
        local _, n, _, ic = GetSpecializationInfoByID(specID)
        specName, icon = n, ic
    end
    if specName and not Secret.IsSecret(specName) then info[#info + 1] = specName end
    local guild = GetGuildInfo(u)
    if guild and not Secret.IsSecret(guild) then info[#info + 1] = "<" .. guild .. ">" end
    r.info:SetText(table.concat(info, "  ·  "))
    if icon then r.spec:SetTexture(icon) else SetPortraitTexture(r.spec, u) end
    local ilvl = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(u)
    ilvl = tonumber(ilvl)
    r.ilvl:SetText(ilvl and ilvl > 0 and ("%.1f"):format(ilvl) or "")
    r.ilvlCaption:SetShown(ilvl and ilvl > 0 or false)
    r.model:SetUnit(u)
end

local inspect = M.Replacement({ key = "ownInspect", frame = "InspectFrame", title = L.INSPECTW_TITLE,
    width = 2 * CARD_W + MODEL_W + 2 * 12 + 20, height = 34 + 20 + HEAD_H + (#LEFT + 1) * (CARD_H + GAP) + 10,
    build = build, layout = layout, close = function() HideUIPanel(InspectFrame) end,
    place = function(win)
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 0, 0)
    end })
M.InspectReplacement = inspect

function M:SetupInspectWindow()
    if inspect.listening then inspect:Sync(); return end
    if not M.ReplacementHook(inspect) then return end
    inspect.listening = true
    local function soon() if inspect.win and inspect.win:IsShown() then inspect:Soon() end end
    ns.Events:On("INSPECT_READY", inspect, soon)
    ns.Events:On("UNIT_INVENTORY_CHANGED", inspect, function(_, _, u) if u == unit() then soon() end end)
    ns.Events:On("GET_ITEM_INFO_RECEIVED", inspect, soon)
    inspect:Sync()
end
function M:SyncInspect() inspect:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupInspectWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncInspect"
