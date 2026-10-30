local _, ns = ...
local M = ns:GetModule("GroupFrames")

--[[ Click casting on Phoenix group frames (original code; EllesmereUI Raid Frames / Clique studied for the idea).
    Up to SLOTS bindings, each a modifier (none, Shift, Ctrl, Alt), a mouse button (1-5) and an action: cast a spell
    on the clicked unit, run a macro (`@unit` becomes `@mouseover`, the button's unit), target, focus, assist or open
    the unit menu. They are plain secure attributes on the SecureUnitButtons ("shift-type2", "shift-spell2" ...),
    written out of combat only (ns.Combat:Run); in combat the last set stays and any change waits for combat to end.
    No unit data is read or compared, so nothing here touches secret values.
    Off by default. Blizzard's own Click Casting (Unit Frames > Click casting) keeps working on top; when Clique is
    loaded Phoenix writes nothing so Clique owns the clicks. Buttons fall back to left = target, right = menu. ]]
local SLOTS = 6
M.CLICK_SLOTS = SLOTS
M.CLICK_MODS = { "", "shift", "ctrl", "alt" }
M.CLICK_ACTIONS = { "none", "spell", "macro", "target", "focus", "assist", "togglemenu" }

local written = setmetatable({}, { __mode = "k" }) -- button -> { attribute names Phoenix set }

local function cliqueLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Clique") and true or false
end
M.CliqueLoaded = cliqueLoaded

--[[ The attributes one binding writes: { [name] = value } (pure, shared with the smoke test).
    An unmodified binding uses the exact form ("type1"), so it beats the template's "*type1" for that click only. ]]
function M.ClickBindingAttributes(slot)
    if type(slot) ~= "table" then return nil end
    local n = tonumber(slot.button)
    if not n or n < 1 or n > 5 or n % 1 ~= 0 then return nil end
    local mod = slot.mod or ""
    if mod ~= "" and mod ~= "shift" and mod ~= "ctrl" and mod ~= "alt" then return nil end
    local action, text = slot.action, slot.text
    local prefix = mod == "" and "" or (mod .. "-")
    local out = {}
    if action == "spell" then
        if type(text) ~= "string" or text:match("^%s*$") then return nil end
        out[prefix .. "type" .. n], out[prefix .. "spell" .. n] = "spell", (text:gsub("^%s+", ""):gsub("%s+$", ""))
    elseif action == "macro" then
        if type(text) ~= "string" or text:match("^%s*$") then return nil end
        out[prefix .. "type" .. n], out[prefix .. "macrotext" .. n] = "macro", (text:gsub("@unit", "@mouseover"))
    elseif action == "target" or action == "focus" or action == "assist" or action == "togglemenu" then
        out[prefix .. "type" .. n] = action
    else
        return nil
    end
    return out
end

-- Every attribute the enabled bindings write, later slots winning on the same click.
function M:ClickAttributeSet()
    local cc = self.db.clickCast
    local set = {}
    if not (cc and cc.enabled) or cliqueLoaded() then return set end
    for i = 1, SLOTS do
        local attrs = M.ClickBindingAttributes(cc.bindings[i])
        if attrs then
            -- a new action on a click replaces the old one's extra value too
            for name in pairs(attrs) do
                local click = name:match("^(.-)type(%d)$")
                if click then
                    local n = name:match("(%d)$")
                    set[click .. "spell" .. n], set[click .. "macrotext" .. n] = false, false
                end
            end
            for name, value in pairs(attrs) do set[name] = value end
        end
    end
    return set
end

-- Writes the bindings on one button (out of combat): clears what Phoenix wrote before, then sets the new ones.
function M:ApplyClickCast(b, set)
    if not (b and b.SetAttribute) or InCombatLockdown() then return false end
    set = set or self:ClickAttributeSet()
    local old = written[b]
    if old then for name in pairs(old) do b:SetAttribute(name, nil) end end
    local mine = {}
    for name, value in pairs(set) do
        if value then b:SetAttribute(name, value); mine[name] = true end
    end
    written[b] = next(mine) and mine or nil
    return true
end

function M:ApplyAllClickCast()
    ns.Combat:Run("groupframes.clickcast", function()
        local set = M:ClickAttributeSet()
        for _, b in ipairs(M.buttons) do M:ApplyClickCast(b, set) end
    end)
end

-- What a button currently has from Phoenix (smoke test / diagnostics).
function M:ClickCastWritten(b) return written[b] end
