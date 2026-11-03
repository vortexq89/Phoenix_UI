-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns:GetModule("Automation")

--[[ Macro editor: Phoenix's own window for the game's macros. Account and character tabs, a list, name, icon (the
    shared icon picker), body with a live 255-character count, a conditionals helper that inserts common
    [conditions] at the cursor, and New / Save / Delete / Pick up. Writes go through the game's macro API, never in
    combat. Nothing here needs the game's /macro window. ]]

local MAX_BODY, ROWS = 255, 14
local ACCOUNT_MAX = _G.MAX_ACCOUNT_MACROS or 120

-- The helper's snippets: plain macro conditionals (game syntax, inserted as typed).
M.MACRO_SNIPPETS = {
    { value = "#showtooltip\n", label = "#showtooltip" },
    { value = "[@mouseover,help,nodead][] ", label = "[@mouseover,help,nodead][]" },
    { value = "[@mouseover,harm,nodead][] ", label = "[@mouseover,harm,nodead][]" },
    { value = "[@focus,exists,harm,nodead][] ", label = "[@focus,exists,harm,nodead][]" },
    { value = "[@cursor] ", label = "[@cursor]" },
    { value = "[@player] ", label = "[@player]" },
    { value = "[mod:shift] ", label = "[mod:shift]" },
    { value = "[mod:ctrl] ", label = "[mod:ctrl]" },
    { value = "[mod:alt] ", label = "[mod:alt]" },
    { value = "[combat] ", label = "[combat]" },
    { value = "[nocombat] ", label = "[nocombat]" },
    { value = "[spec:1] ", label = "[spec:1]" },
    { value = "[spec:2] ", label = "[spec:2]" },
    { value = "[flyable] ", label = "[flyable]" },
    { value = "[swimming] ", label = "[swimming]" },
    { value = "[stealth] ", label = "[stealth]" },
    { value = "/stopcasting\n", label = "/stopcasting" },
    { value = "/startattack\n", label = "/startattack" },
    { value = "/cancelaura ", label = "/cancelaura" },
}

-- macros of one scope: { index, name, icon, body }
function M.MacroList(perChar)
    local out = {}
    if not (GetNumMacros and GetMacroInfo) then return out end
    local account, char = GetNumMacros()
    local first, count = 1, account or 0
    if perChar then first, count = ACCOUNT_MAX + 1, char or 0 end
    for i = first, first + count - 1 do
        local name, icon, body = GetMacroInfo(i)
        if name then out[#out + 1] = { index = i, name = name, icon = icon, body = body or "" } end
    end
    return out
end

-- remaining-characters label value (negative when too long)
function M.MacroRoom(body) return MAX_BODY - #(body or "") end

-- insert text at a cursor position: returns the new body and cursor
function M.InsertSnippet(body, pos, text)
    body = body or ""
    pos = math.max(0, math.min(tonumber(pos) or #body, #body))
    return body:sub(1, pos) .. text .. body:sub(pos + 1), pos + #text
end

function M:SaveMacro(entry, name, icon, body, perChar)
    if InCombatLockdown() then ns:Print(L.AUTO_MACROS_COMBAT); return nil end
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then return nil end
    body = (body or ""):sub(1, MAX_BODY)
    icon = icon or 134400
    if entry and entry.index then
        local ok, idx = pcall(EditMacro, entry.index, name, icon, body)
        return ok and idx or nil
    end
    local ok, idx = pcall(CreateMacro, name, icon, body, perChar and true or nil)
    return ok and idx or nil
end

function M:DeleteMacroEntry(entry)
    if InCombatLockdown() or not (entry and entry.index) then return false end
    return pcall(DeleteMacro, entry.index)
end

local win
local function editor() return win end
M.MacroEditorFrame = editor

local function fill(sel)
    local list = M.MacroList(win.perChar)
    win.list = list
    win.selected = sel and list[sel] or nil
    for i = 1, ROWS do
        local r, e = win.rows[i], list[i + win.offset]
        if e then
            r.icon:SetTexture(e.icon); r.label:SetText(e.name); r.entry = e
            r.mark:SetShown(win.selected and win.selected.index == e.index or false)
            r:Show()
        else
            r:Hide()
        end
    end
    local e = win.selected
    win.name:SetValue(e and e.name or "")
    win.body:SetValue(e and e.body or "")
    win.iconTex = e and e.icon or 134400
    win.iconBtn.tex:SetTexture(win.iconTex)
    win.room:SetText(L.MACRO_ROOM:format(M.MacroRoom(e and e.body or "")))
    win.scope:SetText(win.perChar and L.MACRO_CHARACTER or L.MACRO_ACCOUNT)
end

local function selectedIndex()
    if not win.selected then return nil end
    for i, e in ipairs(win.list) do if e.index == win.selected.index then return i end end
end

function M:ShowMacroEditor()
    local W = ns.Widgets
    if not win then
        win = W:Popup(L.MACRO_EDITOR, 640, 520, "terminal")
        win.perChar, win.offset = false, 0
        win.scope = W:Button(win, L.MACRO_ACCOUNT, "ghost", "user", 150)
        win.scope:SetPoint("TOPLEFT", 16, -44)
        win.scope.onClick = function() win.perChar = not win.perChar; win.offset = 0; fill(nil) end
        win.rows = {}
        for i = 1, ROWS do
            local r = CreateFrame("Button", nil, win)
            r:SetSize(200, 26); r:SetPoint("TOPLEFT", 16, -76 - (i - 1) * 28)
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT")
            r.label = W.Text(r, "body", "text.primary"); r.label:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            r.label:SetWidth(170)
            r.mark = r:CreateTexture(nil, "BACKGROUND"); r.mark:SetAllPoints(); r.mark:SetColorTexture(1, 0.6, 0.2, 0.18)
            r:SetScript("OnClick", function(self)
                for j, e in ipairs(win.list) do if e == self.entry then fill(j) end end
            end)
            win.rows[i] = r
        end
        win:EnableMouseWheel(true)
        win:SetScript("OnMouseWheel", function(_, d)
            win.offset = math.max(0, math.min(math.max(0, #win.list - ROWS), win.offset - d))
            fill(selectedIndex())
        end)
        local x = 236
        win.iconBtn = CreateFrame("Button", nil, win)
        win.iconBtn:SetSize(40, 40); win.iconBtn:SetPoint("TOPLEFT", x, -44)
        win.iconBtn.tex = win.iconBtn:CreateTexture(nil, "ARTWORK"); win.iconBtn.tex:SetAllPoints()
        win.iconBtn:SetScript("OnClick", function()
            W:IconPicker():Open(win.iconTex, function(icon) win.iconTex = icon; win.iconBtn.tex:SetTexture(icon) end)
        end)
        win.name = W:Input(win, 330, L.MACRO_NAME); win.name:SetPoint("LEFT", win.iconBtn, "RIGHT", 10, 0)
        win.body = W:TextArea(win, 388, 260); win.body:SetPoint("TOPLEFT", x, -96)
        win.body.edit:HookScript("OnTextChanged", function(self)
            win.room:SetText(L.MACRO_ROOM:format(M.MacroRoom(self:GetText())))
        end)
        win.room = W.Text(win, "small", "text.secondary"); win.room:SetPoint("TOPRIGHT", win.body, "BOTTOMRIGHT", 0, -6)
        win.helper = W:Dropdown(win, function() return M.MACRO_SNIPPETS end, nil, 240)
        win.helper:SetPoint("TOPLEFT", win.body, "BOTTOMLEFT", 0, -28)
        win.helper.onChange = function(_, v)
            local e = win.body.edit
            local text, cur = M.InsertSnippet(e:GetText(), e:GetCursorPosition(), v)
            e:SetText(text); e:SetCursorPosition(cur); e:SetFocus()
        end
        win.helperLabel = W.Text(win, "small", "text.secondary")
        win.helperLabel:SetPoint("BOTTOMLEFT", win.helper, "TOPLEFT", 0, 4); win.helperLabel:SetText(L.MACRO_HELPER)
        local function button(key, icon, after, fn)
            local label = ({ MACRO_SAVE = L.MACRO_SAVE, MACRO_PICKUP = L.MACRO_PICKUP, MACRO_DELETE = L.MACRO_DELETE,
                MACRO_NEW = L.MACRO_NEW })[key]
            local b = W:Button(win, label, key == "MACRO_SAVE" and "primary" or "ghost", icon, 92)
            if after then b:SetPoint("RIGHT", after, "LEFT", -6, 0) else b:SetPoint("BOTTOMRIGHT", -16, 14) end
            b.onClick = fn
            return b
        end
        win.save = button("MACRO_SAVE", "check", nil, function()
            local idx = M:SaveMacro(win.selected, win.name:GetValue(), win.iconTex, win.body:GetValue(), win.perChar)
            if idx then fill(nil); for j, e in ipairs(win.list) do if e.index == idx then fill(j) end end end
        end)
        win.pick = button("MACRO_PICKUP", "arrow-up", win.save, function()
            if win.selected and not InCombatLockdown() then PickupMacro(win.selected.index) end
        end)
        win.del = button("MACRO_DELETE", "delete", win.pick, function()
            if M:DeleteMacroEntry(win.selected) then fill(nil) end
        end)
        win.new = button("MACRO_NEW", "add", win.del, function() win.selected = nil; fill(nil); win.name:SetFocus() end)
    end
    win:Show()
    fill(nil)
    return win
end
