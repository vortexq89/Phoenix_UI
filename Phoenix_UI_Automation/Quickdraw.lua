-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local M = ns:GetModule("Automation")

--[[ Quickdraw (specs/004 T012): macros without the game's windows. Drop a spell or item on the Quickdraw button
    and a character macro for it is made ("#showtooltip" + /cast or /use); pick any macro and press a key to bind
    it. Out of combat only, through the game's macro and binding API; bindings are saved to the set in use. ]]

-- The macro text for what is on the cursor: kind is "spell" or "item" (GetCursorInfo), id its spell / item id.
function M.QuickBody(kind, id)
    if kind == "spell" then
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        local name = info and info.name
        if not name then return nil end
        return "#showtooltip\n/cast " .. name, name, info.iconID
    elseif kind == "item" then
        local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
        if not name then return nil end
        return "#showtooltip\n/use " .. name, name, icon
    end
end

-- Makes (or updates) the macro for the spell / item on the cursor. Returns its name, or nil and a reason key.
function M:QuickMakeFromCursor()
    if InCombatLockdown() then return nil, "AUTO_MACROS_COMBAT" end
    local kind, a, b, c = GetCursorInfo()
    local id = kind == "spell" and (c or b) or kind == "item" and a or nil
    local body, name = self.QuickBody(kind, id)
    if not body then return nil, "QUICKDRAW_NOTHING" end
    ClearCursor()
    local macro = name:sub(1, 16)
    local idx = GetMacroIndexByName and GetMacroIndexByName(macro) or 0
    local entry = idx and idx > 0 and { index = idx } or nil
    -- icon 134400: the question mark, so #showtooltip shows the spell or item itself
    if not self:SaveMacro(entry, macro, 134400, body, true) then return nil, "QUICKDRAW_FULL" end
    return macro
end

-- Every macro (account, then character) for the bind list.
function M.QuickMacros()
    local out = {}
    for _, perChar in ipairs({ false, true }) do
        for _, e in ipairs(M.MacroList(perChar)) do out[#out + 1] = { value = e.name, label = e.name, icon = e.icon } end
    end
    return out
end

-- The keys bound to a macro, joined ("" when none).
function M.QuickKeys(name)
    if not (name and GetBindingKey) then return "" end
    local keys = { GetBindingKey("MACRO " .. name) }
    return table.concat(keys, ", ")
end

-- Binds key (a GetBindingText-style key such as "SHIFT-F") to the macro and saves the set in use.
function M:QuickBind(name, key)
    if InCombatLockdown() then return false, "AUTO_MACROS_COMBAT" end
    if not (name and key and key ~= "") then return false end
    if not SetBinding(key, "MACRO " .. name) then return false end
    SaveBindings(GetCurrentBindingSet())
    return true
end

-- A key press as a binding string with its modifiers ("ALT-CTRL-SHIFT-X"); nil for a lone modifier.
local MODS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
function M.QuickKeyString(key)
    if not key or MODS[key] then return nil end
    local s = ""
    if IsAltKeyDown() then s = s .. "ALT-" end
    if IsControlKeyDown() then s = s .. "CTRL-" end
    if IsShiftKeyDown() then s = s .. "SHIFT-" end
    return s .. key
end
