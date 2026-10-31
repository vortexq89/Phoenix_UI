local _, ns = ...
local L, P, Theme = ns.L, ns.Previews, ns.Theme

-- the item tooltip beside the unit one
local function drawItem(item, m, db)
    if db.skin then m:StyleFrame(item) else ns.Skin:Panel(item, "raised", { border = "border.strong" }) end
    local epic = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4]
    if db.skin and db.qualityBorder and epic then ns.Skin:SetBorderColor(item, epic.r, epic.g, epic.b, 1) end
    local ibody = {}
    for i, fs in ipairs(item.lines) do ibody[i] = fs end
    if db.fonts then m:StyleLines(item.header, ibody) else
        ns.Skin:Text(item.header, "body", nil, 14)
        for _, fs in ipairs(ibody) do ns.Skin:Text(fs, "desc", nil, 12) end
    end
    item.header:SetText(L.PREVIEW_TT_ITEM)
    if epic then item.header:SetTextColor(epic.r, epic.g, epic.b) end
    local keyed = db.keystone and ns:Supports("mythicplus")
    local ilines = {
        { L.PREVIEW_TT_ITEM_LEVEL, "text.primary" },
        db.collected and { L.TOOLTIP_NOT_COLLECTED, "text.muted" } or false,
        db.itemCount and { m.CountLine(3, 13, 15), "text.muted" } or false,
        db.vendorPrice and { L.TOOLTIP_VENDOR_PRICE:format(tostring(C_CurrencyInfo.GetCoinTextureString(184520))), "text.primary" }
            or false,
        keyed and { L.TOOLTIP_KEY_TIMER:format(12, m.Clock(1980)), "text.primary" } or false,
    }
    local ishown, iheight = 0, 20 + item.header:GetStringHeight()
    for _, line in ipairs(ilines) do
        if line then
            ishown = ishown + 1
            local fs = item.lines[ishown]
            fs:SetText(line[1])
            fs:SetTextColor(Theme:Color(line[2]))
            fs:Show()
            iheight = iheight + fs:GetStringHeight() + 3
        end
    end
    for i = ishown + 1, #item.lines do item.lines[i]:Hide() end
    item:SetHeight(iheight)
    item:SetScale(ns.Previews.ClampScale(db.scale or 1))
end

-- A unit tooltip with the extra lines Tooltip adds (guild rank, realm, inspect, mount, targeted by...), a
-- class-coloured border and name, and the health bar with its percent text; beside it an item tooltip with the
-- item lines (count, collected, vendor price, keystone timer).
P:Register("tooltip", {
    module = "Tooltip",
    width = 540,
    height = 270,
    build = function(stage, m)
        local tt = CreateFrame("Frame", nil, stage)
        tt:SetSize(250, 120)
        tt:SetPoint("LEFT", 14, 8)
        local item = CreateFrame("Frame", nil, stage)
        item:SetSize(250, 60)
        item:SetPoint("TOPRIGHT", -14, -24)
        item.header = P.Text(item)
        item.header:SetPoint("TOPLEFT", 10, -10)
        item.lines = {}
        for i = 1, 5 do
            local fs = P.Text(item)
            fs:SetPoint("TOPLEFT", i == 1 and item.header or item.lines[i - 1], "BOTTOMLEFT", 0, -3)
            item.lines[i] = fs
        end
        tt.header = P.Text(tt)
        tt.header:SetPoint("TOPLEFT", 10, -10)
        tt.lines = {}
        for i = 1, 11 do
            local fs = P.Text(tt)
            fs:SetPoint("TOPLEFT", i == 1 and tt.header or tt.lines[i - 1], "BOTTOMLEFT", 0, -3)
            tt.lines[i] = fs
        end
        tt.bar = P.Bar(tt, 0.82, 230, 4)
        tt.bar:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 2, -3)
        tt.bar:SetPoint("TOPRIGHT", tt, "BOTTOMRIGHT", -2, -3)
        tt.hp = P.Text(tt.bar)
        tt.hp:SetPoint("CENTER", tt.bar, "CENTER", 0, 0)
        return function()
            local db = m.db
            local mage = { ns.Util.ClassColor("MAGE") }
            if db.skin then
                m:StyleFrame(tt)
                if db.classBorder then ns.Skin:SetBorderColor(tt, mage[1], mage[2], mage[3], 1)
                else ns.Skin:SetBorderColor(tt, m:BorderColor()) end
            else
                ns.Skin:Panel(tt, "raised", { border = "border.strong" })
            end
            local body = {}
            for i, fs in ipairs(tt.lines) do body[i] = fs end
            if db.fonts then m:StyleLines(tt.header, body) else
                ns.Skin:Text(tt.header, "body", nil, 14)
                for _, fs in ipairs(body) do ns.Skin:Text(fs, "desc", nil, 12) end
            end
            tt.header:SetText(L.PREVIEW_UNIT_PLAYER)
            if db.classNames then tt.header:SetTextColor(mage[1], mage[2], mage[3])
            else tt.header:SetTextColor(Theme:Color("text.primary")) end
            local guild = L.PREVIEW_TT_GUILD
            if db.guildRank then guild = guild .. " " .. Theme:Wrap("(" .. L.PREVIEW_TT_RANK .. ")", "text.muted") end
            local targeters = ns.Util.WrapClass("PRIEST", L.PREVIEW_TT_HEALER) .. ", " .. L.PREVIEW_TT_TARGETERS
            local lines = {
                { guild, "state.success" }, { L.PREVIEW_TT_LEVEL, "text.primary" },
                db.realm and { L.TOOLTIP_REALM_LINE:format(L.PREVIEW_TT_REALM), "text.primary" } or false,
                db.role and { L.PREVIEW_TT_ROLE, "text.primary" } or false,
                db.inspect and { L.TOOLTIP_ILVL_LINE:format("684"), "text.primary" } or false,
                db.inspect and { L.TOOLTIP_SPEC_LINE:format(L.PREVIEW_TT_SPEC), "text.primary" } or false,
                db.mount and { L.TOOLTIP_MOUNT_LINE:format(L.PREVIEW_TT_MOUNT), "text.primary" } or false,
                db.mplusRating and { L.TOOLTIP_MPLUS_LINE:format(Theme:Wrap("3,105", "accent.secondary")), "text.primary" } or false,
                db.target and { L.TOOLTIP_TARGET_LINE:format(Theme:Wrap(L.PREVIEW_MOB_HOSTILE, "state.danger")), "text.primary" } or false,
                db.targetedBy and { L.TOOLTIP_TARGETED_BY:format(2, targeters), "text.primary" } or false,
            }
            local shown, height = 0, 20 + tt.header:GetStringHeight()
            for _, line in ipairs(lines) do
                if line then
                    shown = shown + 1
                    local fs = tt.lines[shown]
                    fs:SetText(line[1])
                    fs:SetTextColor(Theme:Color(line[2]))
                    fs:Show()
                    height = height + fs:GetStringHeight() + 3
                end
            end
            for i = shown + 1, #tt.lines do tt.lines[i]:Hide() end
            tt:SetHeight(height)
            tt.bar:SetShown(db.healthBar)
            m:StyleHealthBar(tt.bar)
            tt.bar:SetStatusBarColor(Theme:Color("state.success"))
            ns.Skin:Text(tt.hp, "small")
            tt.hp:SetText("82%")
            tt.hp:SetShown(db.healthBar and db.healthText)
            tt:SetScale(ns.Previews.ClampScale(db.scale or 1))
            drawItem(item, m, db)
            ns.Skin:Backdrop(tt.bar, { alpha = 0.9 }, "bg.sunken")
        end
    end,
})
