local _, ns = ...
local L, Skin, Theme, W, Secret = ns.L, ns.Skin, ns.Theme, ns.Widgets, ns.Secret
local M = ns.modules.DamageMeter

--[[ Group item levels (NaowhForever's group inspect window). A small Phoenix window: you and your group, highest
    item level first, in class colours, the group average in the title. Values come from the meter's inspect
    queue (Extras.lua: out of combat, one member every 1.5 s, cached by GUID); a member not inspected yet shows
    "...". Shown in a group (out of combat only, with "Hide in combat" on); movable in Layout mode. No timer of
    its own: it repaints on roster, inspect and combat events. Secret GUIDs are skipped, never compared. ]]

local OWNER = {}
local ROW_H, GAP = 16, 2
local win

local function members()
    local out = { "player" }
    local n = tonumber((GetNumGroupMembers())) or 0
    if IsInRaid() then
        out = {}
        for i = 1, n do out[#out + 1] = "raid" .. i end
    else
        for i = 1, math.max(0, n - 1) do out[#out + 1] = "party" .. i end
    end
    return out
end

-- Sorted rows { name, ilvl (nil = not inspected yet), class } and the average of the known values.
function M.GroupRows(list, ilvlOf, nameOf, classOf)
    local rows, sum, known = {}, 0, 0
    for _, u in ipairs(list) do
        local il = ilvlOf(u)
        if type(il) == "number" and Secret.IsSecret(il) then il = nil end
        rows[#rows + 1] = { name = nameOf(u), ilvl = il, class = classOf(u) }
        if il then sum, known = sum + il, known + 1 end
    end
    table.sort(rows, function(a, b) return (a.ilvl or -1) > (b.ilvl or -1) end)
    return rows, known > 0 and math.floor(sum / known) or nil
end

local function ilvlOf(u)
    if UnitIsUnit(u, "player") then
        local _, equipped = GetAverageItemLevel()
        return equipped and equipped > 0 and math.floor(equipped) or nil
    end
    local guid = UnitGUID(u)
    if guid == nil or Secret.IsSecret(guid) then return nil end
    return M.ilvlCache and M.ilvlCache[guid]
end
local function nameOf(u) return UnitName(u) end
local function classOf(u) local _, c = UnitClass(u); return c end

local function row(i)
    local r = CreateFrame("Frame", nil, win)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = W.Text(r, "small", "text.primary", "LEFT")
    r.name:SetPoint("LEFT", 4, 0)
    r.value = W.Text(r, "small", "text.primary", "RIGHT")
    r.value:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    win.rows[i] = r
    return r
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_GroupItemLevels", UIParent)
    win.rows = {}
    win.title = W.Text(win, "small", "text.secondary", "LEFT")
    win.title:SetPoint("TOPLEFT", 6, -5)
    Skin:Register(win, function(self) Skin:Panel(self, "base", { border = "border.subtle" }) end)
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("dm.group", win, L.DM_GROUP, {
            active = function() return M:IsEnabled() and M.db.group.enabled end,
            get = function() local t = M.db.group; return { point = t.point, x = t.x, y = t.y } end,
            set = function(v) local t = M.db.group; t.point, t.x, t.y = v.point or t.point, v.x or t.x, v.y or t.y end,
            apply = function() M:UpdateGroup() end,
            preview = function() M:UpdateGroup() end,
            reset = function()
                local d, t = M.defaults.group, M.db.group
                t.point, t.x, t.y = d.point, d.x, d.y
                M:UpdateGroup()
            end,
        })
    end
end

function M:GroupWindow() return win end

function M:UpdateGroup()
    local t = self.db.group
    if not (t and t.enabled and M:IsEnabled()) then if win then win:Hide() end return end
    if not win then build() end
    local fighting = InCombatLockdown() or UnitAffectingCombat("player")
    local want = IsInGroup() and not (t.combatHide and fighting)
    local movers = ns:GetModule("Movers")
    if not want and not (movers and movers:IsUnlocked()) then win:Hide() return end
    local rows, avg = M.GroupRows(members(), ilvlOf, nameOf, classOf)
    local shown = math.min(#rows, t.rows)
    win.title:SetText(avg and L.DM_GROUP_AVG:format(avg) or L.DM_GROUP)
    win:SetSize(t.width, 22 + math.max(1, shown) * (ROW_H + GAP))
    win:ClearAllPoints()
    win:SetPoint(t.point, UIParent, t.point, t.x, t.y)
    for i = 1, math.max(#win.rows, t.rows) do
        local r = win.rows[i] or (i <= t.rows and row(i))
        if r then
            local e = i <= shown and rows[i]
            r:SetShown(e and true or false)
            if e then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 4, -20 - (i - 1) * (ROW_H + GAP))
                r:SetPoint("RIGHT", -4, 0)
                r:SetHeight(ROW_H)
                r.bg:SetColorTexture(0, 0, 0, 0.35)
                local c = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
                if c then r.name:SetTextColor(c.r, c.g, c.b) else W.Color(r.name, "text.primary") end
                r.name:SetText(e.name or "?")
                if e.ilvl then
                    r.value:SetText(e.ilvl)
                    r.value:SetTextColor(M.ItemLevelColor(e.ilvl))
                else
                    r.value:SetText("...")
                    r.value:SetTextColor(Theme:Color("text.muted"))
                end
            end
        end
    end
    win:Show()
end

function M:SetupGroup()
    if self.groupHooked then return end
    self.groupHooked = true
    local function update() ns.SafeCall(M.UpdateGroup, M) end
    ns.Events:On("INSPECT_READY", OWNER, function(...)
        if M.OnInspectReady then ns.SafeCall(M.OnInspectReady, ...) end
        update()
    end)
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_EQUIPMENT_CHANGED" }) do
        ns.Events:On(e, OWNER, function()
            if e ~= "PLAYER_REGEN_DISABLED" and M.db.group.enabled then ns.SafeCall(M.ScanItemLevels, M) end
            update()
        end)
    end
    update()
end
