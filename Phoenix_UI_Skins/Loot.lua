local _, ns = ...
local Skin = ns.Skin
local M = ns:GetModule("Skins")

--[[ Loot and rolls, skins plan window 9 (window chrome: shared skin; toasts: the Alerts switch): every loot
    row as a compact Phoenix row with a left bar in the item's quality colour, and each group roll frame on a
    slim Phoenix card outlined in the item's quality colour. Item icons and the Need / Greed / Transmog dice
    are the game's own and unchanged; looting and rolling stay Blizzard's clicks. Live with Skins > Loot. ]]

local function on() return M:IsEnabled() and M.db.loot and true or false end

-- { r, g, b } for an item quality (nil below uncommon: the row keeps the accent-free look).
function M.QualityBar(quality)
    if type(quality) ~= "number" or quality < 2 then return nil end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return c and { r = c.r, g = c.g, b = c.b } or nil
end

local function lootRow(row, isOn)
    local data = row.GetElementData and select(2, pcall(row.GetElementData, row))
    local slot = type(data) == "table" and data.slotIndex
    local quality = slot and GetLootSlotInfo and select(5, GetLootSlotInfo(slot))
    local color = M.QualityBar(quality)
    M.KitRow(row, isOn, { alpha = 0.6, bar = color ~= nil, barColor = color })
end

-- v9.1 roll icons over Blizzard's dice (an overlay, so turning the look off gives the dice back); greed is the gold coin
local ROLLS = { NeedButton = "roll_need", GreedButton = "roll_greed", TransmogButton = "roll_transmog", PassButton = "roll_pass" }
function M.RollArt(f)
    local A = ns.Art
    if not (A and A.Dress) then return end
    for field, piece in pairs(ROLLS) do
        local b = f[field]
        if b then A:Dress(b, "v9", piece, { slot = "roll", level = 2 }) end
    end
end

function M:SkinLoot()
    local isOn = on()
    local lf = _G.LootFrame
    if lf and lf.ScrollBox then M.KitScrollBox(lf.ScrollBox, on, lootRow) end
    for i = 1, 4 do
        local f = _G["GroupLootFrame" .. i]
        if f then
            local card = M.KitCard(f, isOn, "raised", false)
            if card and isOn then
                local quality = f.rollID and GetLootRollItemInfo and select(4, GetLootRollItemInfo(f.rollID))
                local c = M.QualityBar(quality)
                if c then Skin:SetBorderColor(card, c.r, c.g, c.b, 1) end
            end
            M.RollArt(f)
        end
    end
end

local lootHooked
function M:SetupLoot()
    self:SkinLoot()
    if lootHooked then return end
    lootHooked = true
    ns.Events:On("LOOT_OPENED", self, function() M:SkinLoot() end)
    ns.Events:On("START_LOOT_ROLL", self, function() if C_Timer then C_Timer.After(0, function() M:SkinLoot() end) end end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupLoot"
M.RESKINS[#M.RESKINS + 1] = "SkinLoot"
