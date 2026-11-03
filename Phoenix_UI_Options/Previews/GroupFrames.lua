local _, ns = ...
local L, P, Theme = ns.L, ns.Previews, ns.Theme

--[[ Phoenix mode: the profile picked in the scope bar drawn by GroupFrames itself (DrawSampleGroup: Unit Frames'
    build code with the group parts, the code behind the real buttons and the Test frames) as a fake party of 5,
    raid of 20 or raid of 40, scaled to fit. Nothing here reads a unit: the preview is safe in combat.
    Blizzard mode: a party of five as Blizzard's compact frames draw it, dressed by GroupFrames:StyleFrame. ]]
local PARTY = {
    { sample = "PREVIEW_PARTY_TANK", class = "WARRIOR", health = 0.92, power = 0.35 },
    { sample = "PREVIEW_PARTY_HEALER", class = "PRIEST", health = 0.78, power = 0.81 },
    { sample = "PREVIEW_UNIT_PLAYER", class = "MAGE", health = 0.55, power = 0.64 },
    { sample = "PREVIEW_PARTY_DPS1", class = "HUNTER", health = 0.31, power = 0.9 },
    { sample = "PREVIEW_PARTY_DPS2", class = "ROGUE", health = 0, power = 0, status = "PREVIEW_PARTY_DEAD" },
}
local W_, H_, POWER_H, GAP, SCALE = 84, 40, 6, 6, 1.3
local VIEW_W, VIEW_H = 600, 250

local function blizzardRow(stage)
    local row = CreateFrame("Frame", nil, stage)
    row:SetSize(#PARTY * W_ + (#PARTY - 1) * GAP, H_)
    row:SetScale(ns.Previews.ClampScale(SCALE))
    row:SetPoint("CENTER")
    row.frames = {}
    for i in ipairs(PARTY) do
        local f = CreateFrame("Frame", nil, row)
        f:SetSize(W_, H_)
        f:SetPoint("LEFT", (i - 1) * (W_ + GAP), 0)
        f.health = P.Bar(f, PARTY[i].health, W_, H_ - POWER_H)
        f.health:SetPoint("TOPLEFT")
        f.power = P.Bar(f, PARTY[i].power, W_, POWER_H)
        f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT")
        f.name = P.Text(f.health)
        f.name:SetPoint("TOPLEFT", 3, -3)
        f.name:SetPoint("RIGHT", -3, 0)
        f.name:SetJustifyH("LEFT")
        f.status = P.Text(f.health)
        f.status:SetPoint("CENTER", 0, -4)
        row.frames[i] = f
    end
    return row
end

local function drawBlizzard(row, m)
    for i, f in ipairs(row.frames) do
        local s = PARTY[i]
        if not m.db.texture then
            f.health:SetStatusBarTexture(ns.Media.textures.WHITE)
            f.power:SetStatusBarTexture(ns.Media.textures.WHITE)
        end
        m:StyleFrame(f, f.health, f.power, f.name, f.status)
        f.health:SetStatusBarColor(ns.Util.ClassColor(s.class))
        f.power:SetStatusBarColor(Theme:Color(s.class == "WARRIOR" and "state.danger" or "state.info"))
        if not m.db.fonts then
            ns.Skin:Text(f.name, "unit", nil, 11); ns.Skin:Text(f.status, "number", nil, 10)
        end
        f.name:SetText(L[s.sample])
        f.name:SetTextColor(1, 1, 1)
        f.status:SetText(s.status and L[s.status] or "")
        f.status:SetTextColor(Theme:Color("text.muted"))
    end
end

P:Register("groupframe", {
    module = "GroupFrames",
    width = VIEW_W,
    height = VIEW_H,
    states = {
        { key = "range", label = "PREVIEW_STATE_RANGE", icon = "opacity" },
    },
    build = function(stage, m)
        local row
        local root = CreateFrame("Frame", nil, stage)
        root:SetPoint("CENTER")
        local pool = {}
        return function(view, scope)
            if not m:IsPhoenix() then
                root:Hide()
                row = row or blizzardRow(stage)
                row:Show()
                drawBlizzard(row, m)
                return
            end
            if row then row:Hide() end
            local key = m.SIZE_OF[scope] and scope or "party"
            local w, h = m:DrawSampleGroup(root, key, m.SIZE_OF[key], pool)
            root:SetSize(w, h)
            local scale = math.min(1.4, (VIEW_W - 24) / math.max(1, w), (VIEW_H - 24) / math.max(1, h))
            root:SetScale(ns.Previews.ClampScale(scale))
            -- (range fading acts on the real frames; the preview shows it only when asked)
            if not (view.states and view.states.range) then
                for _, f in ipairs(pool) do f:SetAlpha(1) end
            end
            root:Show()
        end
    end,
})
