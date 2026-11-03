local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

--[[ W:IconPicker(): one shared Phoenix popup that picks a game icon (equipment sets, bank tabs). The icons are
    the game's own macro icon lists (GetMacroIcons / GetMacroItemIcons fill a table with file IDs), shown as they
    are, never replaced; 8 x 6 per page, the mouse wheel pages. picker:Open(current, onPick) shows it with the
    current icon outlined; a click calls onPick(fileID) and closes it. ]]

local COLS, ROWS, SIZE, GAP = 8, 6, 34, 4
local picker

-- The game's icon list (file IDs or paths), the current one first; cached after the first open.
local icons
function W.IconList(fill, fillItems)
    if icons then return icons end
    local t = {}
    if type(fill) == "function" then pcall(fill, t) end
    if type(fillItems) == "function" then pcall(fillItems, t) end
    icons = t
    return t
end
function W.ResetIconList() icons = nil end

local function build()
    local p = W:Popup(ns.L.ICON_PICK, COLS * (SIZE + GAP) + 28, ROWS * (SIZE + GAP) + 66, "grid")
    p.cells = {}
    for i = 1, COLS * ROWS do
        local b = CreateFrame("Button", nil, p)
        b:SetSize(SIZE, SIZE)
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % COLS) * (SIZE + GAP), -44 - math.floor((i - 1) / COLS) * (SIZE + GAP))
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b:SetScript("OnClick", function(self)
            if self.value and p.onPick then p.onPick(self.value) end
            p:Hide()
        end)
        p.cells[i] = b
    end
    p.page = W.Text(p, "small", "text.secondary")
    p.page:SetPoint("BOTTOM", 0, 10)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(self, d) self.offset = (self.offset or 0) - d * COLS; self:Draw() end)
    function p:Draw()
        local list = self.list or {}
        local per = COLS * ROWS
        self.offset = math.max(0, math.min(self.offset or 0, math.max(0, #list - per)))
        for i, b in ipairs(self.cells) do
            local v = list[self.offset + i]
            b.value = v
            b:SetShown(v ~= nil)
            if v then
                b.icon:SetTexture(v)
                Skin:Border(b, v == self.current and "accent.primary" or "border.subtle")
            end
        end
        self.page:SetFormattedText("%d / %d", math.floor(self.offset / per) + 1, math.max(1, math.ceil(#list / per)))
    end
    return p
end

function W:IconPicker()
    picker = picker or build()
    function picker:Open(current, onPick)
        local base = W.IconList(_G.GetMacroIcons, _G.GetMacroItemIcons)
        local list = {}
        if current then list[1] = current end
        for _, v in ipairs(base) do if v ~= current then list[#list + 1] = v end end
        self.list, self.current, self.onPick, self.offset = list, current, onPick, 0
        self:Draw()
        self:Show()
        self:Raise()
    end
    return picker
end
