local _, ns = ...
local L, P = ns.L, ns.Previews

-- The data bar with fixed sample readings, built and styled by DataTexts itself.
P:Register("datatexts", {
    module = "DataTexts",
    height = 76,
    build = function(stage, m)
        local o = m:NewBar(stage, false)
        o.frame:SetPoint("CENTER")
        local SAMPLE = {
            fps = { 144, "FPS", "state.success" }, latency = { 38, "ms", "state.success" }, speed = { 100, "%" },
            durability = { 42, L.DT_DURABILITY_UNIT, "state.warning" }, gold = { "18,240", L.DT_GOLD_UNIT },
            bugs = { 0, L.DT_BUGS_UNIT, "state.success" },
        }
        return function()
            local db = m.db
            local values = {}
            for _, key in ipairs(m.ORDER) do
                if db[key] then values[key] = SAMPLE[key] end
            end
            if db.clock then values.clock = { db.clock24 and "21:48" or "09:48", db.clock24 and "" or "PM" } end
            m:StyleBar(o)
            m:FillBar(o, values)
            o.frame:SetScale(math.min(db.scale * 1.15, 1.6))
        end
    end,
})
