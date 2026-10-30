local _, ns = ...
local L, Skin = ns.L, ns.Skin

--[[ Data bar: experience below the level cap (with rested XP as a second fill); at the cap your honor level
    progress (when chosen) or the watched reputation, as a slim Edit Mode movable bar under the data text panel.
    Text: percent, current / max, remaining, only on mouseover, or none. Texture, fill direction, smooth fill and
    a shading gradient are the page's. Values are plain numbers from UnitXP / UnitXPMax / GetXPExhaustion,
    UnitHonor / UnitHonorMax and C_Reputation.GetWatchedFactionData; nothing here is secret. ]]
local INTERP = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local M = ns:GetModule("DataTexts")

local bar

-- XP waiting in finished quests (shown as a third fill on the XP bar). Plain numbers, retail quest log only.
function M.PendingQuestXP()
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.IsComplete and GetQuestLogRewardXP) then return 0 end
    local total = 0
    for i = 1, tonumber((QL.GetNumQuestLogEntries())) or 0 do
        local info = QL.GetInfo(i)
        if info and info.questID and not info.isHeader and QL.IsComplete(info.questID) then
            local ok, xp = pcall(GetQuestLogRewardXP, info.questID)
            if ok and type(xp) == "number" then total = total + xp end
        end
    end
    return total
end

-- What the bar shows now: { kind = "xp"|"rep", cur, max, rested, name } or nil (nothing to show).
function M:BarData()
    local db = self.db
    local atCap = IsXPUserDisabled() or (UnitLevel("player") or 0) >= (GetMaxLevelForPlayerExpansion() or 0)
    if not atCap then
        local max = UnitXPMax("player") or 0
        if max > 0 then return { kind = "xp", cur = UnitXP("player") or 0, max = max, rested = GetXPExhaustion() or 0,
            quest = db.questXP and M.PendingQuestXP() or 0 } end
    end
    if db.barHonor then
        local cur, max = UnitHonor("player"), UnitHonorMax("player")
        if type(cur) == "number" and type(max) == "number" and max > 0 then
            return { kind = "honor", cur = cur, max = max, name = L.DT_HONOR_LEVEL:format(UnitHonorLevel("player") or 0) }
        end
    end
    if db.xpRep then
        local f = C_Reputation.GetWatchedFactionData()
        if f and f.name then
            local min, max, cur = f.currentReactionThreshold or 0, f.nextReactionThreshold or 0, f.currentStanding or 0
            if max <= min then max = min + 1 end
            return { kind = "rep", cur = cur - min, max = max - min, name = f.name }
        end
    end
    return nil
end

-- The text for a mode: "percent", "current", "remaining", "mouseover" (percent while hovered) or "none".
function M.BarText(d, mode, hovered)
    if not d or mode == "none" or (mode == "mouseover" and not hovered) then return "" end
    local pct = d.max > 0 and math.floor(d.cur / d.max * 1000 + 0.5) / 10 or 0
    local prefix = d.name and (d.name .. "  ") or ""
    if mode == "current" then
        return prefix .. ("%s / %s"):format(BreakUpLargeNumbers(d.cur), BreakUpLargeNumbers(d.max))
    elseif mode == "remaining" then
        return prefix .. L.DT_BAR_REMAINING:format(BreakUpLargeNumbers(d.max - d.cur))
    end
    local text = prefix .. pct .. "%"
    if (d.quest or 0) > 0 and hovered then
        text = text .. "  " .. L.DT_QUEST_XP_PENDING:format((math.floor(d.quest / d.max * 1000 + 0.5) / 10) .. "%")
    end
    return text
end

function M:NewDataBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(520, 10)
    f.rested = CreateFrame("StatusBar", nil, f)
    f.rested:SetAllPoints()
    f.quest = CreateFrame("StatusBar", nil, f)
    f.quest:SetAllPoints()
    f.quest:SetFrameLevel(f.rested:GetFrameLevel() + 1)
    f.fill = CreateFrame("StatusBar", nil, f)
    f.fill:SetAllPoints()
    f.fill:SetFrameLevel(f.quest:GetFrameLevel() + 1)
    f.text = f.fill:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    return f
end

M.BAR_TOKENS = { xp = "accent.primary", rep = "state.success", honor = "state.warning" }

local function paintQuest(f, d, max, texture, reverse)
    Skin:StatusBar(f.quest, { background = false, texture = texture })
    f.quest:SetReverseFill(reverse and true or false)
    f.quest:GetStatusBarTexture():SetVertexColor(ns.Theme:Color("state.warning"))
    f.quest:SetAlpha(0.7)
    f.quest:SetMinMaxValues(0, max)
    f.quest:SetValue(d and (d.quest or 0) > 0 and math.min(max, d.cur + d.quest) or 0)
end

-- d: BarData() or a preview sample; hovered: show the mouseover text; sample: the preview (never animates).
function M:PaintDataBar(f, d, hovered, sample)
    local db = self.db
    f:SetSize(db.barWidth, db.barHeight)
    local texture = db.barTexture ~= "" and ns.Media:Bar(db.barTexture) or nil
    Skin:StatusBar(f.fill, { border = "border.black", texture = texture })
    Skin:StatusBar(f.rested, { background = false, texture = texture })
    f.fill:SetReverseFill(db.barReverse and true or false)
    f.rested:SetReverseFill(db.barReverse and true or false)
    Skin:FillGradient(f.fill, db.barGradient)
    local token = M.BAR_TOKENS[d and d.kind or "xp"] or "accent.primary"
    f.fill:GetStatusBarTexture():SetVertexColor(ns.Theme:Color(token))
    f.rested:GetStatusBarTexture():SetVertexColor(ns.Theme:Color("accent.secondary"))
    f.rested:SetAlpha(0.45)
    local max = d and d.max or 1
    f.fill:SetMinMaxValues(0, max)
    local smooth = db.barSmooth and INTERP and not sample and f.kind == (d and d.kind)
    if smooth then f.fill:SetValue(d and d.cur or 0, INTERP) else f.fill:SetValue(d and d.cur or 0) end
    f.kind = d and d.kind
    f.rested:SetMinMaxValues(0, max)
    f.rested:SetValue(d and db.rested and d.rested and math.min(max, d.cur + d.rested) or 0)
    paintQuest(f, d, max, texture, db.barReverse)
    Skin:TextSpec(f.text, db.barText, "number")
    Skin:Place(f.text, f.fill, db.barText)
    f.text:SetText(M.BarText(d, db.barTextMode, hovered))
end

local function update()
    if not bar then return end
    local d = M:BarData()
    bar:SetShown(M.db.xpBar and d ~= nil)
    if d then M:PaintDataBar(bar, d, bar:IsMouseOver()) end
end
M.UpdateDataBar = update

function M:EnableBar()
    if not self.db.xpBar then return end
    if not bar then
        bar = self:NewDataBar(UIParent)
        bar:EnableMouse(true)
        bar:SetScript("OnEnter", update)
        bar:SetScript("OnLeave", update)
        ns.EditMode:Register(bar, { key = "DataTextsXP", name = ns.title .. " – " .. L.DT_XP_BAR,
            default = { point = "BOTTOM", x = 0, y = 64 } })
    end
    for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "HONOR_XP_UPDATE",
        "HONOR_LEVEL_UPDATE", "QUEST_LOG_UPDATE" }) do
        ns.Events:On(event, bar, update)
    end
    update()
end

function M:DisableBar()
    if bar then bar:Hide(); ns.Events:OffAll(bar) end
end

function M:RefreshBar()
    if self.db.xpBar then self:EnableBar() elseif bar then self:DisableBar() end
end
