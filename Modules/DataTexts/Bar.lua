local _, ns = ...
local L, Skin = ns.L, ns.Skin

--[[ Data bar: experience below the level cap (with rested XP as a second fill), the watched reputation at the
    cap (or when you choose it), as a slim Edit Mode movable bar under the data text panel. Text: percent,
    current / max, remaining, only on mouseover, or none. Values are plain numbers from UnitXP / UnitXPMax /
    GetXPExhaustion and C_Reputation.GetWatchedFactionData; nothing here is secret. ]]
local M = ns:GetModule("DataTexts")

local bar

-- What the bar shows now: { kind = "xp"|"rep", cur, max, rested, name } or nil (nothing to show).
function M:BarData()
    local db = self.db
    local atCap = IsXPUserDisabled() or (UnitLevel("player") or 0) >= (GetMaxLevelForPlayerExpansion() or 0)
    if not atCap then
        local max = UnitXPMax("player") or 0
        if max > 0 then return { kind = "xp", cur = UnitXP("player") or 0, max = max, rested = GetXPExhaustion() or 0 } end
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
    return prefix .. pct .. "%"
end

function M:NewDataBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(520, 10)
    f.rested = CreateFrame("StatusBar", nil, f)
    f.rested:SetAllPoints()
    f.fill = CreateFrame("StatusBar", nil, f)
    f.fill:SetAllPoints()
    f.fill:SetFrameLevel(f.rested:GetFrameLevel() + 1)
    f.text = f.fill:CreateFontString(nil, "OVERLAY")
    return f
end

-- d: BarData() or a preview sample; hovered: show the mouseover text.
function M:PaintDataBar(f, d, hovered)
    local db = self.db
    f:SetSize(db.barWidth, db.barHeight)
    Skin:StatusBar(f.fill, { border = "border.black" })
    Skin:StatusBar(f.rested, { background = false })
    local token = d and d.kind == "rep" and "state.success" or "accent.primary"
    f.fill:GetStatusBarTexture():SetVertexColor(ns.Theme:Color(token))
    f.rested:GetStatusBarTexture():SetVertexColor(ns.Theme:Color("accent.secondary"))
    f.rested:SetAlpha(0.45)
    local max = d and d.max or 1
    f.fill:SetMinMaxValues(0, max)
    f.fill:SetValue(d and d.cur or 0)
    f.rested:SetMinMaxValues(0, max)
    f.rested:SetValue(d and db.rested and d.rested and math.min(max, d.cur + d.rested) or 0)
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
    for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION" }) do
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
