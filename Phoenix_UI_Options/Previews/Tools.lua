local _, ns = ...
local L, P = ns.L, ns.Previews
local W, Skin = ns.Widgets, ns.Skin

--[[ Previews for the last three pages that had none: Automation (what runs for you, as on / off pills),
    Movers (the layout grid at its real size with a frame snapped to it) and Bugs (the minimap indicator and
    the chat notice). Each reads its module's saved settings, so every change shows at once. ]]

---------------------------------------------------------------- automation
local AUTOMATIONS = { "sellJunk", "acceptInvites", "declineDuels", "declinePetDuels", "declineGuild", "acceptResurrect",
    "fastLoot", "confirmBoP", "gossip", "lowHealth" }
local LABELS = { sellJunk = "AUTO_SELL_JUNK", acceptInvites = "AUTO_ACCEPT_INVITES", declineDuels = "AUTO_DECLINE_DUELS",
    declinePetDuels = "AUTO_DECLINE_PET_DUELS", declineGuild = "AUTO_DECLINE_GUILD", acceptResurrect = "AUTO_ACCEPT_RES",
    fastLoot = "AUTO_FAST_LOOT", confirmBoP = "AUTO_CONFIRM_BOP", gossip = "AUTO_GOSSIP", lowHealth = "AUTO_LOW_HEALTH" }
local PILL_W, PILL_H, COLS = 196, 24, 3

P:Register("automation", {
    module = "Automation",
    height = 40 + 4 * (PILL_H + 6),
    width = COLS * (PILL_W + 8) + 24,
    build = function(stage, m)
        local pills = {}
        local function pill(i)
            local b = CreateFrame("Frame", nil, stage)
            b:SetSize(PILL_W, PILL_H)
            b:SetPoint("TOPLEFT", 12 + ((i - 1) % COLS) * (PILL_W + 8), -14 - math.floor((i - 1) / COLS) * (PILL_H + 6))
            b.dot = W.Texture(b, "ARTWORK", 1); b.dot:SetSize(6, 6); b.dot:SetPoint("LEFT", 8, 0)
            b.text = W.Text(b, "small", "text.primary"); b.text:SetPoint("LEFT", 20, 0); b.text:SetPoint("RIGHT", -6, 0)
            b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(false)
            pills[i] = b
            return b
        end
        for i = 1, #AUTOMATIONS + 1 do pill(i) end
        return function()
            local db = m.db
            local rows = { { on = db.repair ~= "off", label = L.AUTO_REPAIR } }
            for _, key in ipairs(AUTOMATIONS) do rows[#rows + 1] = { on = db[key] and true or false, label = L[LABELS[key]] } end
            for i, b in ipairs(pills) do
                local r = rows[i]
                Skin:Panel(b, r.on and "raised" or "sunken", { border = r.on and "accent.primary" or "border.subtle" })
                W.Color(b.dot, r.on and "state.success" or "text.muted", 1)
                b.text:SetText(r.label or "")
                Skin:Text(b.text, "small", r.on and "text.primary" or "text.muted")
            end
        end
    end,
})

---------------------------------------------------------------- movers
P:Register("movers", {
    module = "Movers",
    height = 150,
    width = 420,
    build = function(stage, m)
        local grid = CreateFrame("Frame", nil, stage)
        grid:SetPoint("TOPLEFT", 12, -12); grid:SetPoint("BOTTOMRIGHT", -12, 12)
        grid:SetClipsChildren(true)
        local lines = {}
        local box = CreateFrame("Frame", nil, grid)
        box.text = W.Text(box, "small", "text.primary", "CENTER"); box.text:SetPoint("CENTER")
        box.text:SetText(L.MOVERS_SNAP)
        return function()
            local db = m.db
            local g = math.max(4, tonumber(db.gridSize) or 32)
            local w, h = 396, 126
            local n = 0
            for x = g, w, g do
                n = n + 1
                local t = lines[n] or W.Texture(grid, "ARTWORK", 0)
                lines[n] = t
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, 0); t:SetPoint("BOTTOMLEFT", x, 0); t:SetWidth(1)
            end
            for y = g, h, g do
                n = n + 1
                local t = lines[n] or W.Texture(grid, "ARTWORK", 0)
                lines[n] = t
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", 0, -y); t:SetPoint("TOPRIGHT", 0, -y); t:SetHeight(1)
            end
            for i, t in ipairs(lines) do
                t:SetShown(i <= n and db.grid and true or false)
                W.Color(t, "border.subtle", 0.9)
            end
            -- a frame dropped at (37, 29): on the grid it lands on the nearest line
            local x, y = 37, 29
            if db.snap and g > 0 then x, y = math.floor(x / g + 0.5) * g, math.floor(y / g + 0.5) * g end
            box:SetSize(math.max(120, g * 3), math.max(36, g))
            box:ClearAllPoints(); box:SetPoint("TOPLEFT", x, -y)
            Skin:Panel(box, "raised", { border = "accent.primary" })
            box.text:SetText(db.snap and L.MOVERS_SNAP or L.MOVERS_GRID)
            Skin:Panel(grid, "sunken", { border = "border.subtle" })
        end
    end,
})

---------------------------------------------------------------- bugs
P:Register("bugs", {
    module = "Bugs",
    height = 110,
    width = 420,
    build = function(stage, m)
        local ind = CreateFrame("Frame", nil, stage)
        ind:SetSize(34, 34); ind:SetPoint("TOPLEFT", 18, -18)
        ind.icon = W.Icon(ind, "bugs", 18, "state.danger"); ind.icon:SetPoint("CENTER")
        ind.count = W.Text(ind, "small", "text.primary"); ind.count:SetPoint("BOTTOMRIGHT", 4, -4)
        ind.caption = P.Caption(stage, L.BUGS_INDICATOR); ind.caption:SetPoint("TOP", ind, "BOTTOM", 0, -6)
        local chat = W.Text(stage, "body", "text.primary")
        chat:SetPoint("TOPLEFT", 90, -22); chat:SetPoint("RIGHT", -16, 0); chat:SetJustifyH("LEFT"); chat:SetWordWrap(false)
        local sound = W.Text(stage, "small", "text.muted")
        sound:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", 0, -10)
        return function()
            local db = m.db
            ind:SetShown(db.indicator ~= "never")
            Skin:Panel(ind, "raised", { border = db.flash and "state.danger" or "border.subtle" })
            ind.count:SetText("3")
            chat:SetText(db.chat and ("|cffff5555Phoenix:|r " .. L.BUGS_INDICATOR_TIP:format(3, 5):match("^[^\n]*")) or "")
            sound:SetText(L.BUGS_SOUND .. ": " .. (L["BUGS_SOUND_" .. tostring(db.sound):upper()] or L.BUGS_SOUND_NONE))
        end
    end,
})
