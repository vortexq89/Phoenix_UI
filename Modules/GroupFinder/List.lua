local _, ns = ...
local L = ns.L
local Skin, Theme, Util = ns.Skin, ns.Theme, ns.Util
local M = ns:GetModule("GroupFinder")
local plain = M.Plain

--[[ Decorations on Blizzard's group list and applicant list, all from post-hooks:
      * LFGListSearchEntry_Update      dims groups that fail the Phoenix filters (entry alpha), outlines the
                                       matches, adds the leader's score / best key and a class strip
      * LFGListUtil_SetSearchEntryTooltip  adds score, best key, PvP rating, lockout hint and why a group is dimmed
      * LFGListApplicationViewer_UpdateApplicantMember  best key in your listing's dungeon, spec icon, a
                                       highlight for applicants over your score line
    Our regions live on child frames we create, tracked in weak tables; nothing is written onto Blizzard's
    entries or read back by Blizzard code. ]]
local entryDeco = setmetatable({}, { __mode = "k" })
local memberDeco = setmetatable({}, { __mode = "k" })
local liveEntries = setmetatable({}, { __mode = "k" })

local function scoreColor(score)
    local c = type(score) == "number" and C_ChallengeMode.GetDungeonScoreRarityColor(score)
    if c and c.GetRGB then return c:GetRGB() end
    return Theme:Color("text.primary")
end
M.ScoreColor = scoreColor

local function decoFor(entry)
    local d = entryDeco[entry]
    if d then return d end
    d = CreateFrame("Frame", nil, entry)
    d:SetAllPoints()
    d:EnableMouse(false)
    d.edge = CreateFrame("Frame", nil, d)
    d.edge:SetPoint("TOPLEFT", 3, -2)
    d.edge:SetPoint("BOTTOMRIGHT", -3, 0)
    d.score = d:CreateFontString(nil, "OVERLAY")
    d.key = d:CreateFontString(nil, "OVERLAY")
    d.bars = {}
    for i = 1, 5 do
        local t = d:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ns.Media.textures.WHITE)
        t:SetHeight(3)
        d.bars[i] = t
    end
    entryDeco[entry] = d
    return d
end

local function placeDeco(entry, d)
    local anchor = entry.DataDisplay
    d.score:ClearAllPoints()
    d.key:ClearAllPoints()
    if anchor then
        d.score:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -6, 6)
        d.key:SetPoint("BOTTOMRIGHT", d.score, "TOPRIGHT", 0, 2)
    else
        d.score:SetPoint("RIGHT", -90, -6)
        d.key:SetPoint("BOTTOMRIGHT", d.score, "TOPRIGHT", 0, 2)
    end
    for i, t in ipairs(d.bars) do
        t:ClearAllPoints()
        t:SetWidth(14)
        if anchor then
            t:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -4 - (5 - i) * 16, 2)
        else
            t:SetPoint("BOTTOMRIGHT", -8 - (5 - i) * 16, 4)
        end
    end
end

-- Paints one Blizzard entry from its record and match state.
function M:DecorateEntry(entry)
    local id = entry.resultID
    local d = decoFor(entry)
    liveEntries[entry] = true
    local r = type(id) == "number" and self:Record(id)
    local db = self.db
    if not r or not self:IsEnabled() then
        d:Hide()
        entry:SetAlpha(1)
        return
    end
    d:Show()
    placeDeco(entry, d)
    local applied = r.status ~= nil and r.status ~= "none"
    local ok = applied or self:Match(r)
    -- dim what fails a Phoenix filter (never your own applications)
    entry:SetAlpha((not ok and db.nonMatch == "dim") and db.dimAlpha or 1)
    -- outline: the matches (ember accent) and, with the Ember look, a thin theme line on every entry
    local active = (self.expressionFn ~= nil) or self:HasFilters()
    if db.highlight and ok and active and not applied then
        Skin:BorderSpec(d.edge, { style = "ember", size = 1, color = db.highlightColor, shadow = "none" }, "accent.primary")
        d.edge:Show()
    elseif db.skinEntries then
        Skin:BorderSpec(d.edge, { style = "theme", size = 1, color = false, shadow = "none" }, "border.subtle")
        d.edge:Show()
    else
        d.edge:Hide()
    end
    -- leader's score (dungeons) or rating (PvP), and best key in this dungeon
    Skin:Text(d.score, "number", nil, 11, "OUTLINE")
    Skin:Text(d.key, "small", nil, 10, "OUTLINE")
    d.score:SetText("")
    d.key:SetText("")
    if db.entryScore then
        if r.pvpactivity and r.pvp > 0 then
            d.score:SetText(r.pvp)
            d.score:SetTextColor(Theme:Color("text.primary"))
        elseif r.score > 0 then
            d.score:SetText(r.score)
            d.score:SetTextColor(scoreColor(r.score))
        end
        if r.mythicplus and r.bestkey and r.bestkey > 0 then
            d.key:SetText(L.LFG_BEST_KEY:format(r.bestkey))
            d.key:SetTextColor(Theme:Color(r.timed and "state.success" or "text.muted"))
        end
    end
    -- class strip under the role icons (five-player groups)
    for i, t in ipairs(d.bars) do
        local c = db.classBars and r.max == 5 and r.classes[i]
        if c then
            t:SetVertexColor(Util.ClassColor(c.class))
            t:Show()
        else
            t:Hide()
        end
    end
end

function M:HasFilters()
    local db = self.db
    for _, c in ipairs(self.CHECKS) do
        local v = db[c[1]]
        if c[1] ~= "hideDeclined" and v ~= self.defaults[c[1]] then return true end
    end
    return false
end

function M:RefreshEntries()
    for entry in pairs(liveEntries) do
        if entry:IsShown() then self:DecorateEntry(entry) end
    end
end

---------------------------------------------------------------- tooltip
function M:AddTooltipLines(tt, resultID)
    local r = self:Record(resultID)
    if not r or not self.db.tooltip then return end
    tt:AddLine(" ")
    if r.score > 0 then
        local cr, cg, cb = scoreColor(r.score)
        tt:AddDoubleLine(L.LFG_TIP_SCORE, r.score, 0.8, 0.8, 0.8, cr, cg, cb)
    end
    if r.mythicplus and r.bestkey and r.bestkey > 0 then
        tt:AddDoubleLine(L.LFG_TIP_BEST, L.LFG_BEST_KEY:format(r.bestkey) .. (r.timed and "" or (" " .. L.LFG_TIP_UNTIMED)),
            0.8, 0.8, 0.8, 1, 1, 1)
    end
    if r.pvpactivity and r.pvp > 0 then tt:AddDoubleLine(L.LFG_TIP_PVP, r.pvp, 0.8, 0.8, 0.8, 1, 1, 1) end
    if r.dungeon then
        local bits = {}
        if r.lust then bits[#bits + 1] = L.LFG_LUST end
        if r.brez then bits[#bits + 1] = L.LFG_BREZ end
        if #bits > 0 then tt:AddLine(table.concat(bits, " · "), 0.5, 0.8, 1) end
    end
    if self.db.lockout and r.raid and r.lock then
        local need, lost = 0, 0
        local down = {}
        for _, name in ipairs(r.bossNames) do down[name] = true end
        for name in pairs(r.lock.killed) do if not down[name] then lost = lost + 1 end end
        for _, name in ipairs(r.bossNames) do if not r.lock.killed[name] then need = need + 1 end end
        tt:AddLine(L.LFG_TIP_SAVED:format(r.lock.down, r.lock.total), 1, 0.6, 0.2)
        if lost > 0 then tt:AddLine(L.LFG_TIP_LOCK_LOST:format(lost), 1, 0.3, 0.3, true) end
        if need > 0 then tt:AddLine(L.LFG_TIP_LOCK_SKIP:format(need), 0.8, 0.8, 0.8, true) end
    end
    local state = self.why and self.why[resultID]
    if type(state) == "string" then tt:AddLine(L.LFG_TIP_FILTERED:format(L[state]), 0.6, 0.6, 0.6, true) end
    tt:Show()
end

---------------------------------------------------------------- applicants (your own listing)
local function memberDecoFor(member)
    local d = memberDeco[member]
    if d then return d end
    d = CreateFrame("Frame", nil, member)
    d:SetAllPoints()
    d:EnableMouse(false)
    d.tint = d:CreateTexture(nil, "BACKGROUND")
    d.tint:SetTexture(ns.Media.textures.WHITE)
    d.tint:SetAllPoints()
    d.best = d:CreateFontString(nil, "OVERLAY")
    d.spec = d:CreateTexture(nil, "OVERLAY")
    d.spec:SetSize(14, 14)
    memberDeco[member] = d
    return d
end

function M:DecorateApplicant(member, appID, memberIdx)
    if not self:IsEnabled() then return end
    local db = self.db
    local d = memberDecoFor(member)
    d:Show()
    local entry = C_LFGList.GetActiveEntryInfo()
    local activityID = type(entry) == "table" and type(entry.activityIDs) == "table" and entry.activityIDs[1]
    local _, class, _, _, _, _, _, _, _, _, _, score, _, _, _, specID = C_LFGList.GetApplicantMemberInfo(appID, memberIdx)
    score, specID, class = plain(score), plain(specID), plain(class)
    -- best key in the dungeon you listed
    d.best:ClearAllPoints()
    d.best:SetPoint("RIGHT", member, "RIGHT", -4, 0)
    Skin:Text(d.best, "small", "text.secondary", 10, "OUTLINE")
    d.best:SetText("")
    if db.applicantBest and type(activityID) == "number" then
        local best = C_LFGList.GetApplicantDungeonScoreForListing(appID, memberIdx, activityID)
        local level = type(best) == "table" and plain(best.bestRunLevel)
        if type(level) == "number" and level > 0 then
            d.best:SetText(L.LFG_BEST_KEY:format(level))
            d.best:SetTextColor(Theme:Color(plain(best.finishedSuccess) and "state.success" or "text.muted"))
        end
    end
    -- spec icon left of the name
    local icon = db.applicantSpec and type(specID) == "number" and select(4, GetSpecializationInfoByID(specID))
    if icon and member.Name then
        d.spec:SetTexture(icon)
        Skin:IconZoom(d.spec, 0.08)
        d.spec:ClearAllPoints()
        d.spec:SetPoint("RIGHT", member.Name, "LEFT", -2, 0)
        d.spec:Show()
    else
        d.spec:Hide()
    end
    -- highlight applicants at or over your score line
    if db.applicantMinScore > 0 and type(score) == "number" and score >= db.applicantMinScore then
        local cr, cg, cb
        if type(class) == "string" then cr, cg, cb = Util.ClassColor(class) else cr, cg, cb = Theme:Color("accent.primary") end
        d.tint:SetVertexColor(cr, cg, cb, 0.12)
        d.tint:Show()
    else
        d.tint:Hide()
    end
end

---------------------------------------------------------------- hooks
local hooked
function M:EnableList()
    if hooked then return end
    hooked = true
    local function guard(fn)
        return function(...)
            if not M:IsEnabled() then return end
            local ok, err = pcall(fn, ...)
            if not ok and not M.listError then M.listError = true; geterrorhandler()(err) end
        end
    end
    hooksecurefunc("LFGListSearchEntry_Update", guard(function(entry) M:DecorateEntry(entry) end))
    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", guard(function(tt, resultID)
        if type(resultID) == "number" and tt and not tt:IsForbidden() then M:AddTooltipLines(tt, resultID) end
    end))
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", guard(function(member, appID, memberIdx)
        M:DecorateApplicant(member, appID, memberIdx)
    end))
end

-- Pulses the Blizzard entry of a result when it is on screen (the match list's click: you sign up there).
function M:FlashEntry(resultID)
    for entry in pairs(liveEntries) do
        if entry:IsVisible() and entry.resultID == resultID then
            local d = entryDeco[entry]
            if d then
                Skin:BorderSpec(d.edge, { style = "ember", size = 2, color = false, shadow = "none" }, "accent.primary")
                d.edge:Show()
                ns.Anim:FadeIn(d.edge, 0.4)
            end
            return true
        end
    end
    return false
end

-- Class and role of each member (tooltips we draw ourselves).
function M:AddMembers(tt, resultID)
    local r = self:Record(resultID)
    if not r then return end
    for _, c in ipairs(r.classes) do
        local cr, cg, cb = Util.ClassColor(c.class)
        local roleText = c.role == "TANK" and L.LFG_TANK or c.role == "HEALER" and L.LFG_HEALER or L.LFG_DAMAGE
        local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]
        if type(name) ~= "string" then name = c.class end
        tt:AddLine(("%s  %s%s"):format(roleText, name, c.leader and ("  " .. L.LFG_LEADER) or ""), cr, cg, cb)
    end
end
