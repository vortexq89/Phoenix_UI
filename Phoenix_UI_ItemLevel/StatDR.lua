local _, ns = ...
local L = ns.L
local M = ns:GetModule("ItemLevel")

--[[ Diminishing returns in the character sheet's secondary stat tooltips (EllesmereUI reference: character sheet
    rework). For crit, haste, mastery, versatility, leech, avoidance and speed the tooltip gains how much of the
    stat the rating would give without diminishing returns that you do not get, and, when the game's rating
    conversion already includes them, what the next 100 rating would add. Everything comes from the game's own
    rating functions (GetCombatRatingBonus, GetCombatRatingBonusForCombatRatingValue), no formulas or tables of
    ours. Stat values can be secret while unit stats are restricted: a secret value shows nothing extra.
    Which row is which stat is recorded by post-hooks of Blizzard's setters during PaperDollFrame_UpdateStats
    (rows are pooled, so a mark is only trusted from the latest update). ]]

M.STAT_DR = {
    PaperDollFrame_SetCritChance = "CR_CRIT_MELEE", PaperDollFrame_SetHaste = "CR_HASTE_MELEE",
    PaperDollFrame_SetMastery = "CR_MASTERY", PaperDollFrame_SetVersatility = "CR_VERSATILITY_DAMAGE_DONE",
    PaperDollFrame_SetLifesteal = "CR_LIFESTEAL", PaperDollFrame_SetAvoidance = "CR_AVOIDANCE",
    PaperDollFrame_SetSpeed = "CR_SPEED",
}
M.STAT_DR_STEP = 100

local marks = setmetatable({}, { __mode = "k" }) -- [stat row] = { cr = rating index, gen = update number }
local gen = 0

local function plain(v) return type(v) == "number" and not (ns.Secret.IsSecret and ns.Secret.IsSecret(v)) end

local function bonusFor(cr, value)
    if type(GetCombatRatingBonusForCombatRatingValue) ~= "function" then return nil end
    local ok, v = pcall(GetCombatRatingBonusForCombatRatingValue, cr, value)
    return ok and plain(v) and v or nil
end

-- Pure numbers, testable offline. rating: your rating, actual: the bonus you get, slope: bonus per rating point
-- before any diminishing returns, atRating / atNext: the game's conversion of rating and rating + step.
-- Returns lost (>= 0) and, only when the conversion matches what you get, the gain of the next step.
function M.StatDRMath(rating, actual, slope, atRating, atNext)
    if not (plain(rating) and plain(actual) and plain(slope)) or rating <= 0 then return nil end
    local lost = math.max(0, slope * rating - actual)
    local nextGain
    if plain(atRating) and plain(atNext) and math.abs(atRating - actual) < 0.01 then nextGain = math.max(0, atNext - atRating) end
    return lost, nextGain
end

-- Lines for one rating index (nil when there is nothing to say or a value is secret).
function M.StatDRLines(cr)
    if type(GetCombatRating) ~= "function" or type(GetCombatRatingBonus) ~= "function" then return nil end
    local okR, rating = pcall(GetCombatRating, cr)
    local okB, actual = pcall(GetCombatRatingBonus, cr)
    if not (okR and okB and plain(rating) and plain(actual)) or rating <= 0 then return nil end
    local step = M.STAT_DR_STEP
    local small = bonusFor(cr, step)
    if not small then return nil end
    local coeff = 1
    if cr == rawget(_G, "CR_MASTERY") and type(GetMasteryEffect) == "function" then
        local _, c = GetMasteryEffect()
        if not plain(c) then return nil end
        coeff = c
    end
    local lost, nextGain = M.StatDRMath(rating, actual, small / step, bonusFor(cr, rating), bonusFor(cr, rating + step))
    if not lost then return nil end
    local out = {}
    if lost * coeff >= 0.01 then
        out[1] = L.ITEMLEVEL_DR_LOST:format(lost * coeff)
    else
        out[1] = L.ITEMLEVEL_DR_NONE
    end
    if nextGain then out[2] = L.ITEMLEVEL_DR_NEXT:format(step, nextGain * coeff) end
    return out
end

local function addLines(row)
    if not (M:IsEnabled() and M.db.statDR) then return end
    local mark = marks[row]
    if not (mark and mark.gen == gen) or GameTooltip:GetOwner() ~= row then return end
    local lines = M.StatDRLines(mark.cr)
    if not lines then return end
    local r, g, b = ns.Theme:Color("text.secondary")
    for _, text in ipairs(lines) do GameTooltip:AddLine(text, r, g, b, true) end
    GameTooltip:Show()
end

local hookedRows = setmetatable({}, { __mode = "k" })
local masteryCR
function M:SetupStatDR()
    if self.statDRHooked or type(PaperDollFrame_UpdateStats) ~= "function" then return end
    self.statDRHooked = true
    masteryCR = rawget(_G, "CR_MASTERY")
    for fn, crName in pairs(self.STAT_DR) do
        local cr = rawget(_G, crName)
        if type(rawget(_G, fn)) == "function" and type(cr) == "number" then
            hooksecurefunc(fn, function(row)
                if type(row) ~= "table" then return end
                marks[row] = { cr = cr, gen = gen + 1 }
                if not hookedRows[row] and row.HookScript then
                    hookedRows[row] = true
                    -- mastery's tooltip is rebuilt by Mastery_OnEnter (also its UpdateTooltip), hooked below
                    row:HookScript("OnEnter", function(self)
                        local m = marks[self]
                        if m and m.cr ~= masteryCR then addLines(self) end
                    end)
                end
            end)
        end
    end
    hooksecurefunc("PaperDollFrame_UpdateStats", function() gen = gen + 1 end)
    if type(rawget(_G, "Mastery_OnEnter")) == "function" then hooksecurefunc("Mastery_OnEnter", addLines) end
end
