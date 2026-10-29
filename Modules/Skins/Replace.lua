local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ Shared shell for the Phoenix replacement windows (mail has its own older copy of the same idea): a Phoenix
    window that stands in for a Blizzard window while that window is open. The Blizzard window keeps its open
    state (Escape, its events, bag right-clicks and "is it open" checks behave as usual); Skin:Tuck only makes
    it see-through and parks its children on a hidden holder. Each replacement has its own Skins switch (off:
    the reskinned Blizzard window, live) and an arrow button for Blizzard's window for the rest of this visit.
    opts: key (db switch), frame (global name), title, width, height, build(r) (fills r.body), layout(r),
    close() (how our close button closes the Blizzard window), ready() (optional: false = show Blizzard's). ]]

local PAD, HEAD = 10, 34

function M.Replacement(opts)
    local r = { opts = opts, visit = false }

    function r.On() return M:IsEnabled() and M.db[opts.key] and true or false end
    function r.Blizzard() return _G[opts.frame] end
    function r.Open() local f = r.Blizzard(); return f and f:IsShown() and true or false end

    local function build()
        local win = CreateFrame("Frame", "PhoenixUI_" .. opts.frame, UIParent)
        win:SetSize(opts.width, opts.height)
        win:SetFrameStrata("MEDIUM")
        win:SetToplevel(true)
        win:SetClampedToScreen(true)
        win:EnableMouse(true)
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -110)
        win:Hide()
        win.title = W.Text(win, "heading", "accent.primary")
        win.title:SetPoint("TOPLEFT", PAD, -PAD - 2)
        win.title:SetText(opts.title)
        win.close = W:IconButton(win, "close", 22, CLOSE)
        win.close:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 4)
        win.close.onClick = function() opts.close() end
        win.blizz = W:IconButton(win, "link", 22, ns.L.SKINS_OWN_BLIZZARD)
        win.blizz:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
        win.blizz.onClick = function() r.visit = true; r:Sync() end
        win.body = CreateFrame("Frame", nil, win)
        win.body:SetPoint("TOPLEFT", PAD, -PAD - HEAD)
        win.body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        r.win, r.body = win, win.body
        opts.build(r)
        win:SetScript("OnShow", function() r:Layout() end)
        Skin:Register(win, function(self)
            Skin:Panel(self, "base", { border = "border.strong" })
            r:Layout()
        end)
        local movers = ns:GetModule("Movers")
        if movers then movers:Register(opts.key, win, opts.title) end
    end

    function r:Layout()
        if self.win and self.win:IsShown() then opts.layout(self) end
    end

    local pending
    function r:Soon()
        if pending then return end
        pending = true
        C_Timer.After(0.05, function() pending = nil; r:Layout() end)
    end

    function r:Sync()
        local want = r.On() and not r.visit and r.Open() and (not opts.ready or opts.ready())
        if want then
            if not r.win then build() end
            if not Skin:Tuck(r.Blizzard()) then want = false end
        end
        if not want then
            if r.win then r.win:Hide() end
            if r.Blizzard() then Skin:Untuck(r.Blizzard()) end
            return
        end
        r.win:Show()
        r:Layout()
    end

    -- Call when the Blizzard window opens (resets the this-visit arrow) and closes.
    function r:Opened() r.visit = false; C_Timer.After(0, function() r:Sync() end) end
    function r:Closed() r.visit = false; r:Sync() end
    return r
end
