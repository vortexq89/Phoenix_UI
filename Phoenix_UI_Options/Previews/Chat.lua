local _, ns = ...
local L, P, Skin, Theme = ns.L, ns.Previews, ns.Skin, ns.Theme

-- A chat window with sample lines (channel colours from the game's chat settings) showing what Chat does to
-- messages: timestamps, role icons, a shortened channel, an item link with its level, a highlighted mention and
-- a link; above it the tabs, below it the edit box, beside it the chat bar. Styled by Chat itself.
local LINES = {
    { "GUILD", sample = "PREVIEW_CHAT_GUILD", role = "TANK" },
    { "CHANNEL", trade = true },
    { "WHISPER", sample = "PREVIEW_CHAT_WHISPER" },
    { "PARTY", sample = "PREVIEW_CHAT_PARTY", url = true, role = "HEALER" },
    { "PARTY", mention = true, role = "DAMAGER" },
    { "SYSTEM", sample = "PREVIEW_CHAT_SYSTEM" },
}
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
-- The guild tab is flashing (new messages); the third is a whisper window.
local TABS = { { sample = "PREVIEW_CHAT_TAB_GENERAL" }, { sample = "PREVIEW_CHAT_TAB_GUILD", alerting = true },
    { sample = "PREVIEW_CHAT_TAB_WHISPERS", chatType = "WHISPER" } }
local BAR = { "SAY", "PARTY", "INSTANCE_CHAT", "RAID", "GUILD" }
local SAMPLE_TIME = time({ year = 2026, month = 10, day = 22, hour = 15, min = 27, sec = 32 })

local function channelColor(kind)
    local info = ChatTypeInfo and ChatTypeInfo[kind]
    if info and info.r then return info.r, info.g, info.b end
    return Theme:Color("text.primary")
end

-- the game's timestamp format with this page's colour (none: the muted text colour the preview always used)
local function timestamp(m)
    local fmt = m.TimestampFormat(C_CVar and C_CVar.GetCVar("showTimestamps"))
    if type(fmt) ~= "string" or fmt == "none" or fmt == "" then return "" end
    local ok, text = pcall(date, fmt, SAMPLE_TIME)
    if not ok or type(text) ~= "string" then return "" end
    local c = m.db.timestampColor
    if type(c) == "table" then return "|cff" .. ns.Util.Hex(c.r or 1, c.g or 1, c.b or 1) .. text .. "|r" end
    return Theme:Wrap(text, "text.muted")
end

local function lineText(m, line)
    local db = m.db
    local text
    if line.trade then
        local channel = L.PREVIEW_CHAT_TRADE_CHANNEL
        if db.shortChannels then channel = m.ShortChannel(channel) end
        local item = L.PREVIEW_CHAT_ITEM
        if db.itemLevels then item = item .. " (684)" end
        text = L.PREVIEW_CHAT_TRADE:format(channel, ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4]
            and ITEM_QUALITY_COLORS[4].hex and (ITEM_QUALITY_COLORS[4].hex .. "[" .. item .. "]|r") or "[" .. item .. "]")
    elseif line.mention then
        text = L.PREVIEW_CHAT_MENTION:format(L.PREVIEW_UNIT_PLAYER)
    else
        text = L[line.sample]
    end
    if line.url then
        local url = "phoenix-ui.gg/keys"
        text = text .. " " .. (db.urls and m:Linkify(url) or url)
    end
    local words = m.ParseKeywords(db.keywords, db.keywordOwnName and L.PREVIEW_UNIT_PLAYER or nil)
    if line.mention or line[1] == "GUILD" then
        local hex = ns.Util.Hex(Skin:SpecColor(db.keywordColor, "accent.primary"))
        text = m.Highlight(text, words, hex)
    end
    if db.roleIcons and line.role and CreateAtlasMarkup then
        text = CreateAtlasMarkup(ROLE_ATLAS[line.role], 12, 12) .. text
    end
    local ts = timestamp(m)
    return ts ~= "" and (ts .. " " .. text) or text
end

P:Register("chat", {
    module = "Chat",
    width = 500,
    height = 230,
    build = function(stage, m)
        local win = CreateFrame("Frame", nil, stage)
        win:SetSize(430, 132)
        win:SetPoint("BOTTOM", 14, 44)
        win.tabs = {}
        for i, tab in ipairs(TABS) do
            local fs = P.Text(win)
            fs:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 8 + (i - 1) * 86, 6)
            fs.key, fs.def = tab.sample, tab
            fs.holder = { glow = win:CreateTexture(nil, "BACKGROUND") }
            fs.holder.glow:SetTexture(ns.Media.textures.FADE_V)
            fs.holder.glow:SetPoint("BOTTOMLEFT", fs, "BOTTOMLEFT", -6, -6)
            fs.holder.glow:SetPoint("TOPRIGHT", fs, "TOPRIGHT", 6, 4)
            win.tabs[i] = fs
        end
        win.text = CreateFrame("Frame", nil, win)
        win.text:SetAllPoints()
        win.lines = {}
        for i = 1, #LINES do
            local fs = P.Text(win.text)
            fs:SetPoint("BOTTOMLEFT", 8, 6 + (#LINES - i) * 20)
            fs:SetPoint("RIGHT", -28, 0)
            fs:SetWordWrap(false)
            win.lines[i] = fs
        end
        win.copy = ns.Icons:Create(win, "copy", 14, "text.muted")
        win.copy:SetPoint("TOPRIGHT", -6, -6)
        win.jump = ns.Icons:Create(win, "arrow-down", 14, "accent.primary")
        win.jump:SetPoint("BOTTOMRIGHT", -6, 6)
        -- edit box under (or above) the window
        local box = CreateFrame("Frame", nil, stage)
        box:SetSize(430, 24)
        box.text = P.Text(box)
        box.text:SetPoint("LEFT", 8, 0)
        -- chat bar
        local bar = CreateFrame("Frame", nil, stage)
        bar.buttons = {}
        for i, chatType in ipairs(BAR) do
            local b = CreateFrame("Frame", nil, bar)
            b:SetSize(20, 20)
            b.text = P.Text(b)
            b.text:SetPoint("CENTER")
            b.chatType = chatType
            bar.buttons[i] = b
        end
        -- the emote picker button and its open grid (a few of the game's emotes)
        local emote = CreateFrame("Frame", nil, bar)
        emote:SetSize(20, 20)
        emote.icon = ns.Icons:Create(emote, "user", 12)
        emote.icon:SetPoint("CENTER")
        local grid = CreateFrame("Frame", nil, stage)
        grid.cells = {}
        for i = 1, 8 do
            local c = CreateFrame("Frame", nil, grid)
            c:SetSize(56, 16)
            c.text = P.Text(c)
            c.text:SetPoint("LEFT", 4, 0)
            grid.cells[i] = c
        end
        return function()
            local db = m.db
            if db.skinWindows then
                Skin:Backdrop(win, db.background, "bg.sunken")
                Skin:BorderSpec(win, db.border, "border.default")
            else
                Skin:Backdrop(win, { alpha = 0.45 }, "bg.overlay")
                Skin:BorderSpec(win, { style = "none", shadow = "none" })
            end
            for i, fs in ipairs(win.tabs) do
                if db.styleText then m:StyleTab(fs) else Skin:Text(fs, "small") end
                local selected = i == 1
                fs:SetTextColor(Theme:Color(selected and "text.primary" or "text.muted"))
                if selected and db.selectedTabColor then fs:SetTextColor(Skin:SpecColor(db.selectedTabColor, "accent.primary")) end
                fs:SetAlpha((db.fadeTabs and not selected) and 0.6 or 1)
                fs:SetText(L[fs.key])
                -- Blizzard's own flash glow is white until a colour is applied
                fs.holder.glow:SetVertexColor(1, 1, 1, 0.5)
                fs.holder.glow:SetShown(fs.def.alerting == true)
                m:StyleTabState(fs.holder, fs, fs.def.chatType, fs.def.alerting)
            end
            for i, fs in ipairs(win.lines) do
                local line = LINES[i]
                fs:SetFont(Theme:Font("body", 14)) -- the "window" size, as set in Blizzard's chat menu
                if db.styleText then m:StyleMessages(fs) end
                fs:SetTextColor(channelColor(line[1]))
                fs:SetText(lineText(m, line))
            end
            win.copy:SetShown(db.copyButton)
            win.jump:SetShown(db.scrollButton)
            box:ClearAllPoints()
            if db.editBoxTop then box:SetPoint("BOTTOM", win, "TOP", 0, 26)
            else box:SetPoint("TOP", win, "BOTTOM", 0, -4) end
            if db.skinEditBox then
                Skin:Backdrop(box, db.background, "bg.sunken")
                Skin:BorderSpec(box, db.border, "border.default")
            else
                Skin:Panel(box, "sunken", { border = "border.subtle" })
            end
            if db.styleText then Skin:TextSpec(box.text, db.editBox, "body") else Skin:Text(box.text, "body") end
            box.text:SetText(L.PREVIEW_CHAT_EDITBOX)
            bar:SetShown(db.chatBar)
            local n = #bar.buttons + (db.emotes and 1 or 0)
            local pts, w, h = m.BarLayout(n, db.chatBarSide)
            bar:SetSize(w, h)
            bar:ClearAllPoints()
            if db.chatBarSide == "LEFT" then bar:SetPoint("TOPRIGHT", win, "TOPLEFT", -6, 0)
            else bar:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 270, 4) end
            for i, b in ipairs(bar.buttons) do
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", pts[i][1], pts[i][2])
                Skin:Panel(b, "raised", { border = "border.default" })
                Skin:Text(b.text, "small")
                b.text:SetText(m.Initial(_G[b.chatType] or b.chatType))
                b.text:SetTextColor(channelColor(b.chatType))
            end
            emote:SetShown(db.emotes)
            grid:SetShown(db.chatBar and db.emotes)
            if db.emotes then
                local p = pts[n]
                emote:ClearAllPoints()
                emote:SetPoint("TOPLEFT", p[1], p[2])
                Skin:Panel(emote, "raised", { border = "border.default" })
                ns.Icons:Tint(emote.icon, "text.primary")
                local list = m.EmoteChoices()
                local gp, gw, gh = m.EmoteGrid(math.min(#list, #grid.cells))
                grid:SetSize(math.min(gw, 240), gh)
                grid:ClearAllPoints()
                grid:SetPoint("BOTTOMLEFT", emote, "TOPLEFT", 0, 4)
                Skin:Panel(grid, "raised", { border = "border.default", shadow = true })
                for i, c in ipairs(grid.cells) do
                    local e = list[i]
                    c:SetShown(e ~= nil)
                    if e then
                        c:ClearAllPoints()
                        c:SetPoint("TOPLEFT", 6 + ((i - 1) % 4) * 58, gp[i][2])
                        Skin:Text(c.text, "small", "text.primary", 10)
                        c.text:SetText(e.label)
                    end
                end
            end
        end
    end,
})
