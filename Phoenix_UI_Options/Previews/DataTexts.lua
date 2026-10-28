local _, ns = ...
local L, P = ns.L, ns.Previews

-- The data bar with fixed sample readings, built and styled by DataTexts itself.
P:Register("datatexts", {
    module = "DataTexts",
    height = 120,
    build = function(stage, m)
        local o = m:NewBar(stage, false)
        o.frame:SetPoint("CENTER", 0, 26)
        local o2 = m:NewBar(stage, false)
        o2.frame:SetPoint("TOP", o.frame, "BOTTOM", 0, -8)
        local xp = m:NewDataBar(stage)
        xp:SetPoint("BOTTOM", 0, 10)
        local XP = { kind = "xp", cur = 61250, max = 98000, rested = 21000 }
        local HONOR = { kind = "honor", cur = 1450, max = 2800, name = L.DT_HONOR_LEVEL:format(42) }
        local SAMPLE = {
            fps = { 144, "FPS", "state.success" }, latency = { 38, "ms", "state.success" }, speed = { 100, "%" },
            durability = { 42, L.DT_DURABILITY_UNIT, "state.warning" }, gold = { "18,240", L.DT_GOLD_UNIT },
            bugs = { 0, L.DT_BUGS_UNIT, "state.success" }, bags = { 24, L.DT_BAGS_UNIT, "state.success" },
            itemlevel = { "712.4", L.DT_ITEMLEVEL_UNIT }, friends = { 7, L.DT_ONLINE_UNIT }, guild = { 31, L.DT_ONLINE_UNIT },
            mail = { L.DT_MAIL_NEW, "", "state.success" }, spec = { L.DT_SAMPLE_SPEC, "" },
            keystone = { "+12", L.DT_SAMPLE_KEY }, coords = { "45.2, 61.8", "" }, volume = { 80, "%" },
            currency = { ns.Icons:Markup("gold", 12) .. " 1,250  " .. ns.Icons:Markup("mythicplus", 12) .. " 34", "" },
        }
        return function()
            local db = m.db
            local values = {}
            for _, key in ipairs(m.ORDER) do
                if db[key] then values[key] = SAMPLE[key] end
            end
            for key in pairs(m.FEATURE) do if not ns:Supports(m.FEATURE[key]) then values[key] = nil end end
            if db.clock then values.clock = { db.clock24 and "21:48" or "9:48", db.clock24 and "" or TIMEMANAGER_PM } end
            if db.gold and db.goldCopper then values.gold = { C_CurrencyInfo.GetCoinTextureString(182404567), "" } end
            local scale = math.min(db.scale * 1.05, 1.4)
            m:StyleBar(o)
            m:FillBar(o, values, m:Order1())
            o.frame:SetScale(ns.Previews.ClampScale(scale))
            o.frame:SetAlpha(db.mouseover and 0.35 or 1)
            o2.frame:SetShown(db.panel2)
            if db.panel2 then
                m:StyleBar(o2)
                m:FillBar(o2, values, m:Order2())
                o2.frame:SetScale(ns.Previews.ClampScale(scale))
                o2.frame:SetAlpha(db.mouseover and 0.35 or 1)
            end
            xp:SetShown(db.xpBar)
            if db.xpBar then
                m:PaintDataBar(xp, db.barHonor and HONOR or XP, true, true)
                xp:SetWidth(math.min(db.barWidth, 560))
            end
        end
    end,
})
