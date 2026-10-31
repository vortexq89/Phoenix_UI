-- Offline geometry for the smoke harness: records anchors, sizes, scales and parents set on stub frames
-- and resolves them to screen rectangles (UIParent = 0,0 .. w,h), so layout tests can check that the options
-- window keeps its size, stays on screen and that controls do not overlap. Not a WoW layout engine: it
-- handles SetPoint / SetAllPoints / ClearAllPoints with explicit offsets, SetSize, SetScale and parents.
local G = { points = setmetatable({}, { __mode = "k" }), parent = setmetatable({}, { __mode = "k" }),
    scale = setmetatable({}, { __mode = "k" }), root = nil, rootW = 1366, rootH = 768 }

local H = { LEFT = 0, CENTER = 0.5, RIGHT = 1 }
local V = { BOTTOM = 0, CENTER = 0.5, TOP = 1 }
local function split(p)
    p = p or "CENTER"
    local v = p:find("TOP") and 1 or (p:find("BOTTOM") and 0 or 0.5)
    local h = p:find("LEFT") and 0 or (p:find("RIGHT") and 1 or 0.5)
    return h, v
end
G.split = split

function G.Install(frameMethods)
    frameMethods.SetPoint = function(self, p, rel, rp, x, y)
        if type(rel) == "number" then rel, rp, x, y = nil, p, rel, rp end
        if rp == nil and type(rel) ~= "string" and type(rel) ~= "table" then rp = p end
        local list = G.points[self] or {}
        for i = #list, 1, -1 do if list[i].p == p then table.remove(list, i) end end
        list[#list + 1] = { p = p, rel = rel, rp = rp or p, x = tonumber(x) or 0, y = tonumber(y) or 0 }
        G.points[self] = list
    end
    frameMethods.ClearAllPoints = function(self) G.points[self] = nil end
    frameMethods.SetAllPoints = function(self, rel)
        G.points[self] = { { p = "TOPLEFT", rel = rel, rp = "TOPLEFT", x = 0, y = 0 },
            { p = "BOTTOMRIGHT", rel = rel, rp = "BOTTOMRIGHT", x = 0, y = 0 } }
    end
    frameMethods.SetScale = function(self, s) G.scale[self] = s end
    frameMethods.GetScale = function(self) return G.scale[self] or 1 end
    frameMethods.SetParent = function(self, p) G.parent[self] = p end
end

local function eff(f, depth)
    depth = depth or 0
    if not f or depth > 40 then return 1 end
    return (G.scale[f] or 1) * eff(G.parent[f], depth + 1)
end
G.EffectiveScale = eff

-- rect(f) -> left, bottom, width, height in screen units, or nil when it cannot be resolved
function G.Rect(f, depth)
    depth = depth or 0
    if f == nil or depth > 40 then return nil end
    if f == G.root then return 0, 0, G.rootW, G.rootH end
    local s = eff(f)
    local w, h = rawget(f, "__w"), rawget(f, "__h")
    local pts = G.points[f]
    if not pts or #pts == 0 then return nil end
    local xs, ys = {}, {}
    for _, pt in ipairs(pts) do
        local rel = pt.rel
        if rel == nil or type(rel) == "string" then rel = G.parent[f] or G.root end
        local l, b, rw, rh = G.Rect(rel, depth + 1)
        if not l then return nil end
        local ph, pv = split(pt.p)
        local rh2, rv2 = split(pt.rp)
        xs[#xs + 1] = { frac = ph, at = l + rw * rh2 + pt.x * s }
        ys[#ys + 1] = { frac = pv, at = b + rh * rv2 + pt.y * s }
    end
    local function axis(list, size)
        local lo, hi
        for _, a in ipairs(list) do
            if a.frac == 0 then lo = a.at elseif a.frac == 1 then hi = a.at end
        end
        if lo and hi then return lo, hi - lo end
        local a = list[1]
        size = (size or 0) * s
        return a.at - size * a.frac, size
    end
    local l, width = axis(xs, w)
    local b, height = axis(ys, h)
    return l, b, width, height
end

function G.Overlap(a, b, slack)
    slack = slack or 0.5
    local al, ab, aw, ah = G.Rect(a)
    local bl, bb, bw, bh = G.Rect(b)
    if not (al and bl) then return false end
    return al + aw - slack > bl and bl + bw - slack > al and ab + ah - slack > bb and bb + bh - slack > ab
end

return G
