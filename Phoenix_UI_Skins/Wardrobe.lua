local _, ns = ...
local L = ns.L
local W = ns.Widgets
local M = ns:GetModule("Skins")

--[[ Transmog set list: every set the game knows with how many of its pieces you own, the closest to complete
    first, with a search box. Read-only (C_TransmogSets); opened from the Skins page or /pui skins sets. ]]
local SHOW = 22

-- Owned / total pieces of a set from its primary appearances ({ collected = bool } each).
function M.SetProgress(appearances)
    local have, total = 0, 0
    for _, a in ipairs(appearances or {}) do
        total = total + 1
        if a.collected then have = have + 1 end
    end
    return have, total
end

-- Incomplete sets first by share owned (then name); complete ones last. `filter` matches the name (plain text).
function M.SortSets(rows, filter)
    local out = {}
    filter = tostring(filter or ""):lower()
    for _, r in ipairs(rows) do
        if filter == "" or tostring(r.name):lower():find(filter, 1, true) then out[#out + 1] = r end
    end
    table.sort(out, function(a, b)
        local da, db = a.have >= a.total, b.have >= b.total
        if da ~= db then return db end
        local sa, sb = a.have / math.max(1, a.total), b.have / math.max(1, b.total)
        if sa ~= sb then return sa > sb end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

function M:SetRows()
    local rows = {}
    if not (C_TransmogSets and C_TransmogSets.GetAllSets) then return rows end
    for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
        local ok, list = pcall(C_TransmogSets.GetSetPrimaryAppearances, set.setID)
        local have, total = M.SetProgress(ok and list or nil)
        if total > 0 then
            local label = set.label or set.description
            rows[#rows + 1] = { name = set.name .. (label and label ~= "" and (" (" .. label .. ")") or ""), have = have, total = total }
        end
    end
    return rows
end

local win
local function paint()
    local rows = M.SortSets(M:SetRows(), win.search:GetText())
    local lines = {}
    for i = 1, math.min(SHOW, #rows) do
        local r = rows[i]
        local color = r.have >= r.total and "7fd17f" or (r.have > 0 and "ffd15a" or "9a9a9a")
        lines[i] = ("|cff%s%d/%d|r  %s"):format(color, r.have, r.total, r.name)
    end
    if #lines == 0 then lines[1] = L.SKINS_SETS_NONE end
    win.text:SetText(table.concat(lines, "\n"))
    win.count:SetText(L.SKINS_SETS_COUNT:format(#rows))
end

function M:ShowSets()
    if not win then
        win = W:Popup(L.SKINS_SETS, 460, 470, "palette")
        win.search = W:Input(win, 428, L.SEARCH_PLACEHOLDER)
        win.search:SetPoint("TOPLEFT", 16, -40)
        win.search.onTextChanged = paint
        win.text = W.Text(win, "body", "text.primary")
        win.text:SetPoint("TOPLEFT", 16, -76); win.text:SetPoint("RIGHT", -16, 0)
        win.text:SetJustifyH("LEFT"); win.text:SetSpacing(3)
        win.count = W.Text(win, "small", "text.muted")
        win.count:SetPoint("BOTTOMLEFT", 16, 12)
    end
    win.search:SetValue("")
    paint()
    win:Show()
    return win
end
