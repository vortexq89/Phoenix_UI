local _, ns = ...
local L = ns.L
local W, Secret = ns.Widgets, ns.Secret
local M = ns:GetModule("ItemLevel")

--[[ Upgrade planner: every equipped item's upgrade track and level ("Hero 3/6") read from the game's own tooltip
    line, the steps left per item and per track. the button on the Item Level page. ]]
local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }

-- Lua pattern from the game's format "Upgrade Level: %s %d/%d" -> captures track, level, max.
function M.UpgradePattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

-- { track, level, max } from tooltip data, or nil.
function M.ReadUpgrade(data, pattern)
    if not (pattern and type(data) == "table" and type(data.lines) == "table") then return nil end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not Secret.IsSecret(text) then
            local track, level, max = text:match(pattern)
            if track then return { track = track, level = tonumber(level), max = tonumber(max) } end
        end
    end
end

function M:UpgradeRows()
    local pattern = M.UpgradePattern(_G.ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
    local rows, left = {}, {}
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return rows, left end
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
            local u = ok and M.ReadUpgrade(data, pattern)
            if u then
                rows[#rows + 1] = { slot = slot, link = link, track = u.track, level = u.level, max = u.max }
                left[u.track] = (left[u.track] or 0) + math.max(0, u.max - u.level)
            end
        end
    end
    return rows, left
end

-- Calculator: steps left per track -> crests needed and the average item level gained over all slots.
function M.UpgradeCalc(left, crestCost, stepIlvl)
    crestCost, stepIlvl = tonumber(crestCost) or 15, tonumber(stepIlvl) or 3
    local out = { tracks = {}, steps = 0, crests = 0, gain = 0 }
    for track, n in pairs(left or {}) do
        out.tracks[#out.tracks + 1] = { track = track, steps = n, crests = n * crestCost }
        out.steps = out.steps + n
    end
    table.sort(out.tracks, function(a, b) return a.track < b.track end)
    out.crests = out.steps * crestCost
    out.gain = math.floor(out.steps * stepIlvl / 16 * 10 + 0.5) / 10
    return out
end

local win
function M:RefreshUpgrades() if win and win:IsShown() then self:ShowUpgrades() end end
function M:ShowUpgrades()
    if not win then
        win = W:Popup(L.ITEMLEVEL_UPGRADES, 420, 420, "itemlevel")
        win.text = W.Text(win, "body", "text.primary")
        win.text:SetPoint("TOPLEFT", 16, -44); win.text:SetPoint("RIGHT", -16, 0)
        win.text:SetJustifyH("LEFT"); win.text:SetSpacing(3)
    end
    local rows, left = self:UpgradeRows()
    local lines = {}
    for _, r in ipairs(rows) do
        local done = r.level >= r.max
        lines[#lines + 1] = ("%s  |cff%s%s %d/%d|r"):format(r.link, done and "7fd17f" or "ffd15a", r.track, r.level, r.max)
    end
    if #lines == 0 then lines[1] = L.ITEMLEVEL_UPGRADES_NONE end
    lines[#lines + 1] = " "
    local calc = M.UpgradeCalc(left, self.db and self.db.crestCost, self.db and self.db.stepIlvl)
    for _, t in ipairs(calc.tracks) do
        lines[#lines + 1] = L.ITEMLEVEL_UPGRADES_LEFT:format(t.track, t.steps)
            .. "  " .. L.ITEMLEVEL_UPGRADES_CRESTS:format(t.crests)
    end
    if calc.steps > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = L.ITEMLEVEL_UPGRADES_TOTAL:format(calc.steps, calc.crests, calc.gain)
    end
    win.text:SetText(table.concat(lines, "\n"))
    win:Show()
    return win, rows
end
