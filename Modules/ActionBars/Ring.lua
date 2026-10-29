local _, ns = ...

local W = ns.Widgets
local M = ns:GetModule("ActionBars")

--[[ Quick ring: a key opens a ring of secure buttons (spells, items, macros) in the middle of the screen; a click
    uses one and closes the ring, the key again closes it. Opening and closing run in the secure environment, so
    the ring works in combat; its contents and the key change only out of combat (ns.Combat:Run).
    List: spell IDs or names, item:ID, macro:Name, separated by commas (Action Bars > Quick ring). ]]
local MAX = 12
local header, ring, toggle
local buttons = {}

-- "133, item:5512, macro:PUI Heal, Fireball" -> { {type="spell",value=133}, {type="item",value="item:5512"}, … }
function M.ParseRing(text)
    local out = {}
    for part in tostring(text or ""):gmatch("[^,;\n]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        local item, macro = part:match("^[Ii]tem:(%d+)$"), part:match("^[Mm]acro:(.+)$")
        if item then out[#out + 1] = { type = "item", value = "item:" .. item }
        elseif macro then out[#out + 1] = { type = "macro", value = macro }
        elseif part:match("^%d+$") then out[#out + 1] = { type = "spell", value = tonumber(part) }
        elseif part ~= "" then out[#out + 1] = { type = "spell", value = part } end
        if #out >= MAX then break end
    end
    return out
end

-- Offsets of n buttons evenly on a circle of radius r, the first at the top.
function M.RingPoints(n, r)
    local pts = {}
    for i = 1, n do
        local a = math.pi / 2 - (i - 1) * 2 * math.pi / n
        pts[i] = { math.floor(math.cos(a) * r + 0.5), math.floor(math.sin(a) * r + 0.5) }
    end
    return pts
end

local function iconOf(e)
    if e.type == "item" then
        -- a typed item name has no ID; GetItemIconByID(nil) raises, so it simply shows no icon yet
        local id = tonumber(tostring(e.value or ""):match("%d+"))
        return id and C_Item.GetItemIconByID(id)
    end
    if e.type == "macro" then local _, icon = GetMacroInfo(e.value); return icon end
    local ok, info = pcall(C_Spell.GetSpellInfo, e.value)
    return ok and info and info.iconID
end

local function build()
    header = CreateFrame("Frame", "PhoenixUI_RingHeader", UIParent, "SecureHandlerBaseTemplate")
    ring = CreateFrame("Frame", "PhoenixUI_Ring", UIParent, "SecureHandlerShowHideTemplate")
    ring:SetSize(1, 1)
    ring:SetPoint("CENTER")
    ring:SetFrameStrata("DIALOG")
    ring:Hide()
    toggle = CreateFrame("Button", "PhoenixUI_RingToggle", UIParent, "SecureHandlerClickTemplate")
    SecureHandlerSetFrameRef(toggle, "ring", ring)
    toggle:SetAttribute("_onclick", [[ local r = self:GetFrameRef("ring"); if r:IsShown() then r:Hide() else r:Show() end ]])
    for i = 1, MAX do
        local b = CreateFrame("Button", "PhoenixUI_RingButton" .. i, ring, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        W.Texture(b, "BACKGROUND"):SetAllPoints()
        SecureHandlerWrapScript(b, "OnClick", header, "", [[ self:GetParent():Hide() ]])
        b:Hide()
        buttons[i] = b
    end
end

local owner
local function apply()
    local db = M.db.ring
    if not ring then build() end
    owner = owner or CreateFrame("Frame")
    ClearOverrideBindings(owner)
    ring:Hide()
    local list = (M:IsEnabled() and db.enabled) and M.ParseRing(db.list) or {}
    local pts = M.RingPoints(#list, db.radius)
    for i, b in ipairs(buttons) do
        local e = list[i]
        if e then
            b:SetSize(db.size, db.size)
            b:ClearAllPoints()
            b:SetPoint("CENTER", ring, "CENTER", pts[i][1], pts[i][2])
            b:SetAttribute("type", e.type)
            b:SetAttribute(e.type, e.value)
            b.icon:SetTexture(iconOf(e) or 134400)
            b:Show()
        else
            b:SetAttribute("type", nil)
            b:Hide()
        end
    end
    local key = M.NormalizeKey and M.NormalizeKey(db.key)
    if key and #list > 0 then SetOverrideBindingClick(owner, true, key, toggle:GetName(), "LeftButton") end
    M.ringCount, M.ringKey = #list, key
end

function M:RefreshRing() ns.Combat:Run("ab.ring", apply) end
