local _, ns = ...
local M = ns.modules.UnitFrames

--[[ Arena II (plan v2 S18, sArena Reloaded parity; original code — sArena ships without a licence, so nothing of
    it is reused, only its feature list).

    DR      12.x sends diminishing returns only as UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED with a secret payload:
            an addon cannot read the category, the time or the immunity. The game's own arena frames
            (CompactArenaFrame) draw it securely in a SpellDiminishStatusTray per enemy, fed by that event. Phoenix
            takes those trays: each one is re-parented into its Phoenix arena frame's DR holder (out of combat), its
            items get our size, spacing, growth, border, zoom and countdown font (post-hooks of the tray's own
            layout and of each item's UpdateState), and the immunity border follows the secret flag through
            SetAlphaFromBoolean. Nothing is read, compared or written into the game's tables.
    Trinket The game's CcRemoverFrame (ARENA_CROWD_CONTROL_SPELL_UPDATE / ARENA_COOLDOWNS_UPDATE) works where
            C_PvP.GetArenaCrowdControlInfo is secret (rated play), so it is taken the same way into our trinket slot.
    Clicks  Left / right / middle click actions on arena (and arena pet) frames: target, focus, menu, a spell or a
            macro, as secure attributes set out of combat.
    Quick focus  A modifier + left click on any Phoenix unit frame sets focus (secure "focus" type), or, with a
            raid marker picked, runs "/focus" and "/tm" on that unit through a secure macro attribute.
    The game's arena frames are created on entering an arena (CompactArenaFrame_Generate): a post-hook parks them
    and takes their trays then. WoW Forever has no arenas (feature "arena"). ]]

local DR_CVAR = "spellDiminishPVPEnemiesEnabled"
local DR_MINE_CVAR = "spellDiminishPVPOnlyTriggerableByMe"

---------------------------------------------------------------- click actions
local CLICK_BUTTONS = { left = 1, right = 2, middle = 3 }
M.CLICK_ACTIONS = { "target", "focus", "togglemenu", "spell", "macro", "none" }

-- The secure attributes for one click: (type, extra key, extra value) — pure, shared with the smoke test.
function M.ClickAttributes(action, text, token)
    if action == "spell" then
        if type(text) ~= "string" or text == "" then return nil end
        return "spell", "spell", text
    elseif action == "macro" then
        if type(text) ~= "string" or text == "" then return nil end
        return "macro", "macrotext", (text:gsub("@unit", "@" .. (token or "target")))
    elseif action == "target" or action == "focus" or action == "togglemenu" then
        return action
    end
    return nil
end

-- The quick-focus macro for a unit token: focus it, and mark it when a marker (1-8) is picked.
function M.QuickFocusMacro(token, marker)
    marker = tonumber(marker) or 0
    if marker < 1 or marker > 8 then return nil end
    return ("/focus [@%s]\n/tm [@%s] %d"):format(token, token, marker)
end

local MODIFIERS = { shift = true, ctrl = true, alt = true }

-- Applies the click actions to one secure frame (out of combat: SetAttribute on a protected frame).
function M.ApplyClicks(f)
    if not (f and f.SetAttribute) or InCombatLockdown() then return end
    local token = f.token or f.unit
    local key = f.unitKey
    if key == "arena" or key == "arenapet" then
        local c = M:Unit("arena").click
        for name, n in pairs(CLICK_BUTTONS) do
            local kind, extraKey, extraValue = M.ClickAttributes(c[name], c[name .. "Text"], token)
            f:SetAttribute("*type" .. n, kind)
            f:SetAttribute("*spell" .. n, extraKey == "spell" and extraValue or nil)
            f:SetAttribute("*macrotext" .. n, extraKey == "macrotext" and extraValue or nil)
        end
    end
    -- quick focus: modifier + left click
    for mod in pairs(MODIFIERS) do
        f:SetAttribute(mod .. "-type1", nil)
        f:SetAttribute(mod .. "-macrotext1", nil)
    end
    local q = M.db.quickFocus
    if q and MODIFIERS[q.key] and token then
        local macro = M.QuickFocusMacro(token, q.marker)
        if macro then
            f:SetAttribute(q.key .. "-type1", "macro")
            f:SetAttribute(q.key .. "-macrotext1", macro)
        else
            f:SetAttribute(q.key .. "-type1", "focus")
        end
    end
end

function M.ApplyAllClicks()
    if InCombatLockdown() then return end
    for _, key in ipairs(M.UNITS) do
        for _, f in ipairs(M.frames[key] or {}) do M.ApplyClicks(f) end
    end
end

---------------------------------------------------------------- the game's DR trays and trinkets
local trays, removers = {}, {} -- our arena frame index -> the game's tray / CcRemoverFrame
-- (kept in our own weak tables: nothing is written into the game's frames)
local trayIndex, immuneEdge = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local hookedTray = setmetatable({}, { __mode = "k" })
M.adoptedTrays, M.adoptedRemovers = trays, removers

local function arenaFrame(i) return M.frames.arena and M.frames.arena[i] end

-- Re-anchors a tray's shown items in our holder with our look (runs after the tray's own layout).
local function relayoutTray(tray)
    local f = trayIndex[tray] and arenaFrame(trayIndex[tray])
    if not f then return end
    local dr = M:Unit("arena").dr
    local i = 0
    for _, item in ipairs({ tray:GetChildren() }) do
        if item:IsShown() and item.Icon then
            i = i + 1
            M.PlaceDRItem(item, f.DR, i, dr)
            M.StyleDRItem(item, dr)
        end
    end
end
M.RelayoutTray = relayoutTray

-- The immunity border of a game tray item follows its (secret) flag without being read.
function M.OnDRItemState(item, state)
    local edge = immuneEdge[item]
    if not (edge and type(state) == "table") then return end
    if M:Unit("arena").dr.immune then edge:SetAlphaFromBoolean(state.isImmune, 1, 0) else edge:SetAlpha(0) end
end

local function hookItems(tray)
    for _, item in ipairs({ tray:GetChildren() }) do
        if not immuneEdge[item] and item.UpdateState then
            -- our own child frame for the immunity border (the game's role-icon indicator is faded instead)
            local edge = CreateFrame("Frame", nil, item)
            edge:SetAllPoints()
            edge:SetFrameLevel(item:GetFrameLevel() + 4)
            edge:SetAlpha(0)
            immuneEdge[item] = edge
            ns.Skin:BorderSpec(edge, { style = "solid", size = 2, color = false, shadow = "none" }, "state.danger")
            hooksecurefunc(item, "UpdateState", function(self, state) ns.SafeCall(M.OnDRItemState, self, state) end)
            if item.ImmunityIndicator then item.ImmunityIndicator:SetAlpha(0) end
        end
    end
end

local function adoptTray(i, tray)
    local f = arenaFrame(i)
    if not (f and tray) or tray:IsForbidden() then return end
    trays[i] = tray
    trayIndex[tray] = i
    tray:SetParent(f.DR)
    tray:ClearAllPoints()
    tray:SetPoint("CENTER", f.DR, "CENTER")
    if not hookedTray[tray] then
        hookedTray[tray] = true
        hooksecurefunc(tray, "RefreshTrayLayout", function(self)
            ns.SafeCall(hookItems, self)
            ns.SafeCall(relayoutTray, self)
        end)
    end
    hookItems(tray)
    relayoutTray(tray)
end

local function adoptRemover(i, remover)
    local f = arenaFrame(i)
    if not (f and remover) or remover:IsForbidden() then return end
    removers[i] = remover
    f.trinketAdopted = true
    remover:SetParent(f.Trinket)
    remover:ClearAllPoints()
    remover:SetAllPoints(f.Trinket)
    if remover.Icon then ns.Skin:IconZoom(remover.Icon, M:Unit("arena").iconZoom or 0.08) end
    -- our own icon stays under it for the Test frames; the game's draws over it while it knows the spell
    f.Trinket.Icon:SetAlpha(0)
end

-- Takes the trays and trinkets of the game's arena frames (when they exist and Phoenix's arena frames are on).
local function adoptAll()
    if InCombatLockdown() or not ns:Supports("arena") then return end
    local u = M:Unit("arena")
    local blizzard = rawget(_G, "CompactArenaFrame")
    if not (u.enabled and type(blizzard) == "table" and blizzard.memberUnitFrames) then return end
    for i, member in ipairs(blizzard.memberUnitFrames) do
        if u.dr.show and member.SpellDiminishStatusTray then adoptTray(i, member.SpellDiminishStatusTray) end
        if u.trinket and member.CcRemoverFrame then adoptRemover(i, member.CcRemoverFrame) end
    end
end
M.AdoptArenaParts = adoptAll

-- The game's DR switches follow ours (out of combat): the tray only runs with its CVar on.
local function syncCVars()
    if InCombatLockdown() or not ns:Supports("arena") or not (C_CVar and C_CVar.SetCVar) then return end
    local u = M:Unit("arena")
    if not (u.enabled and u.dr.show) then return end
    if C_CVar.GetCVar(DR_CVAR) ~= "1" then C_CVar.SetCVar(DR_CVAR, "1") end
    local mine = u.dr.mineOnly and "1" or "0"
    if C_CVar.GetCVar(DR_MINE_CVAR) ~= nil and C_CVar.GetCVar(DR_MINE_CVAR) ~= mine then C_CVar.SetCVar(DR_MINE_CVAR, mine) end
end

local generated
function M:SetupArena()
    if not ns:Supports("arena") then return end
    syncCVars()
    adoptAll()
    if not generated and type(rawget(_G, "CompactArenaFrame_Generate")) == "function" then
        generated = true
        -- the game builds its arena frames on entering an arena: park them and take their trays then
        hooksecurefunc("CompactArenaFrame_Generate", function()
            if not (M:IsEnabled() and M:IsPhoenix() and M:Unit("arena").enabled) then return end
            ns.Combat:Run("uf.arena.adopt", function()
                local fr = rawget(_G, "CompactArenaFrame")
                if fr and fr.SetParent and not fr:IsForbidden() and M.ParkFrame then M.ParkFrame("CompactArenaFrame") end
                adoptAll()
            end)
        end)
    end
end

function M:RefreshArena()
    if not ns:Supports("arena") then return end
    ns.Combat:Run("uf.arena.cvars", syncCVars)
    ns.Combat:Run("uf.arena.adopt", adoptAll)
    for _, tray in pairs(trays) do ns.SafeCall(relayoutTray, tray) end
end
