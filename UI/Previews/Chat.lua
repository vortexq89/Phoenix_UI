local _, ns = ...
local L, P, Skin, Theme = ns.L, ns.Previews, ns.Skin, ns.Theme

-- A chat window with a few sample lines (channel colours from the game's chat settings), a link and the
-- copy button, styled by Chat.
local LINES = {
    { "GUILD", sample = "PREVIEW_CHAT_GUILD" }, { "WHISPER", sample = "PREVIEW_CHAT_WHISPER" },
    { "PARTY", sample = "PREVIEW_CHAT_PARTY", url = true },
    { "SYSTEM", sample = "PREVIEW_CHAT_SYSTEM" },
}
local TABS = { { sample = "PREVIEW_CHAT_TAB_GENERAL" }, { sample = "PREVIEW_CHAT_TAB_GUILD" }, { sample = "PREVIEW_CHAT_TAB_WHISPERS" } }

local function channelColor(kind)
    local info = ChatTypeInfo and ChatTypeInfo[kind]
    if info and info.r then return info.r, info.g, info.b end
    return Theme:Color("text.primary")
end

P:Register("chat", {
    module = "Chat",
    height = 150,
    build = function(stage, m)
        local win = CreateFrame("Frame", nil, stage)
        win:SetSize(430, 96)
        win:SetPoint("BOTTOM", 0, 12)
        win.tabs = {}
        for i, tab in ipairs(TABS) do
            local fs = P.Text(win)
            fs:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 8 + (i - 1) * 86, 6)
            fs.key = tab.sample
            win.tabs[i] = fs
        end
        win.text = CreateFrame("Frame", nil, win)
        win.text:SetAllPoints()
        win.lines = {}
        for i = 1, #LINES do
            local fs = P.Text(win.text)
            fs:SetPoint("BOTTOMLEFT", 8, 8 + (#LINES - i) * 20)
            fs:SetPoint("RIGHT", -28, 0)
            win.lines[i] = fs
        end
        win.copy = ns.Icons:Create(win, "copy", 14, "text.muted")
        win.copy:SetPoint("TOPRIGHT", -6, -6)
        return function()
            local db = m.db
            Skin:Backdrop(win, { alpha = 0.45 }, "bg.overlay")
            for i, fs in ipairs(win.tabs) do
                if db.styleText then m:StyleTab(fs) else Skin:Text(fs, "small") end
                fs:SetTextColor(Theme:Color(i == 1 and "text.primary" or "text.muted"))
                fs:SetText(L[fs.key])
            end
            for i, fs in ipairs(win.lines) do
                local line = LINES[i]
                fs:SetFont(Theme:Font("body", 14)) -- the "window" size, as set in Blizzard's chat menu
                if db.styleText then m:StyleMessages(fs) end
                fs:SetTextColor(channelColor(line[1]))
                local text = L[line.sample]
                if line.url then
                    local url = "phoenix-ui.gg/keys"
                    text = text .. " " .. (db.urls and m:Linkify(url) or url)
                end
                fs:SetText(text)
            end
            win.copy:SetShown(db.copyButton)
        end
    end,
})
