local _, ns = ...

--[[ ns.Glow — Phoenix's own button glows (proc alerts, assisted-combat highlight, preview).
    A glow is a plain child frame laid over its owner; nothing on the owner is touched, so it is safe on
    Blizzard's secure buttons in combat. One driver frame animates every visible glow and only runs while one is
    shown. General → Reduce motion draws each style still.
      pixel     dashes running around the edge         autocast  sparks circling the edge
      button    a breathing soft glow                  (slot: several glows per owner, e.g. "proc", "assist") ]]
local G = {}
ns.Glow = G
local Skin, Media = ns.Skin, ns.Media
local WHITE = Media.textures.WHITE
G.STYLES = { "pixel", "autocast", "button" }

local glows = setmetatable({}, { __mode = "k" }) -- owner -> { [slot] = frame }
local active = {}
local driver = CreateFrame("Frame")
driver:Hide()
local DASHES, SPARKS = 8, 4

local function still() return ns.Anim and ns.Anim:ReduceMotion() end

local function create(owner)
    local f = CreateFrame("Frame", nil, owner)
    f:SetAllPoints(owner)
    f:SetFrameLevel((owner:GetFrameLevel() or 1) + 6)
    f.dashes, f.sparks = {}, {}
    for i = 1, DASHES do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(WHITE)
        f.dashes[i] = t
    end
    for i = 1, SPARKS do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(Media.textures.MASK_CIRCLE)
        t:SetBlendMode("ADD")
        f.sparks[i] = t
    end
    f.t = 0
    return f
end

-- A point `d` along the perimeter of a w x h box, clockwise from the top-left: x, y (from TOPLEFT), side.
function G.Perimeter(d, w, h)
    local p = 2 * (w + h)
    d = d % p
    if d < w then return d, 0, "top" end
    d = d - w
    if d < h then return w, d, "right" end
    d = d - h
    if d < w then return w - d, h, "bottom" end
    return 0, h - (d - w), "left"
end

local function placeDash(t, f, d, len, thick, w, h)
    local x, y, side = G.Perimeter(d, w, h)
    t:ClearAllPoints()
    if side == "top" then
        t:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0); t:SetSize(math.min(len, w - x), thick)
    elseif side == "right" then
        t:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y); t:SetSize(thick, math.min(len, h - y))
    elseif side == "bottom" then
        t:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", x, 0); t:SetSize(math.min(len, x), thick)
    else
        t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, -y); t:SetSize(thick, math.min(len, y))
    end
end

local function paint(f)
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w <= 0 or h <= 0 then return end
    local r, g, b, a = f.r, f.g, f.b, f.a
    local per = 2 * (w + h)
    local moving = not still()
    for _, t in ipairs(f.dashes) do t:SetShown(f.style == "pixel") end
    for _, t in ipairs(f.sparks) do t:SetShown(f.style == "autocast") end
    if f.style == "pixel" then
        local len, thick = per / DASHES * 0.55, 2
        local offset = moving and (f.t * per * 0.25) or 0
        for i, t in ipairs(f.dashes) do
            placeDash(t, f, offset + (i - 1) * per / DASHES, len, thick, w, h)
            t:SetVertexColor(r, g, b, a)
        end
        Skin:HideGlow(f)
    elseif f.style == "autocast" then
        for i, t in ipairs(f.sparks) do
            local d = (moving and f.t * per * 0.35 or 0) + (i - 1) * per / SPARKS
            local x, y = G.Perimeter(d, w, h)
            local size = 6 + (i % 2) * 3
            t:ClearAllPoints()
            t:SetPoint("CENTER", f, "TOPLEFT", x, -y)
            t:SetSize(size, size)
            t:SetVertexColor(r, g, b, a)
        end
        Skin:HideGlow(f)
    else -- button: breathing glow
        local pulse = moving and (0.55 + 0.45 * math.sin(f.t * 4)) or 0.85
        Skin:Glow(f, math.max(6, w * 0.22), "Soft", r, g, b, a * pulse)
    end
end
G.Paint = paint

driver:SetScript("OnUpdate", function(_, elapsed)
    local any = false
    for f in pairs(active) do
        if f:IsShown() then
            any = true
            f.t = f.t + elapsed
            paint(f)
        else
            active[f] = nil
        end
    end
    if not any then driver:Hide() end
end)

-- style: "pixel" | "autocast" | "button"; colour as r, g, b, a.
function G:Show(owner, style, r, g, b, a, slot)
    slot = slot or "glow"
    local set = glows[owner]
    if not set then set = {}; glows[owner] = set end
    local f = set[slot]
    if not f then f = create(owner); set[slot] = f end
    f.style, f.r, f.g, f.b, f.a = style, r or 1, g or 0.8, b or 0.3, a or 1
    f:Show()
    paint(f)
    if still() then active[f] = nil else active[f] = true; driver:Show() end
    return f
end

function G:Hide(owner, slot)
    local set = glows[owner]
    local f = set and set[slot or "glow"]
    if f then f:Hide(); active[f] = nil end
end

function G:IsShown(owner, slot)
    local set = glows[owner]
    local f = set and set[slot or "glow"]
    return f ~= nil and f:IsShown()
end
