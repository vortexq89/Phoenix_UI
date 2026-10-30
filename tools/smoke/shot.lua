-- In-game-equivalent screenshots of the settings window, offline (PUI_SHOT_OUT=<dir> lua5.1 tools/smoke/harness.lua .).
-- The harness runs the real Phoenix_UI code; this records what it draws (textures with their colour, gradient, file
-- and tex coords; font strings with text, font file, size, colour and anchors), lays the window out at its real
-- size and writes one JSON scene per page. tools/smoke/shot_render.py paints a scene with the bundled fonts and
-- icon atlases. Not part of the checks: nothing here runs unless PUI_SHOT_OUT is set.
local S = {}
local utf8codes -- defined below
local seq = 0
local function nextSeq() seq = seq + 1; return seq end

function S.Install(ctx)
    local fm, rm, Geo = ctx.frameMethods, ctx.regionMethods, ctx.Geo
    local newRegion = ctx.newRegion
    local function region(kind)
        return function(self, _, layer, _, sub)
            local r = newRegion()
            Geo.parent[r] = self
            rawset(r, "__kind", kind); rawset(r, "__layer", layer or "ARTWORK"); rawset(r, "__sub", tonumber(sub) or 0)
            rawset(r, "__seq", nextSeq())
            return r
        end
    end
    fm.CreateTexture = region("tex")
    fm.CreateFontString = region("text")
    fm.SetFrameLevel = function(self, l) rawset(self, "__lvl", l) end
    fm.GetFrameLevel = function(self)
        local l = rawget(self, "__lvl")
        if l then return l end
        local p = Geo.parent[self]
        return p and (p:GetFrameLevel() + 1) or 1
    end
    -- edit boxes draw their own text
    fm.SetText = function(self, t) rawset(self, "__text", t ~= nil and tostring(t) or "") end
    fm.GetText = function(self) return rawget(self, "__text") or "" end
    fm.SetFont = function(self, path, size, flags) rawset(self, "__font", { path, size, flags }); return true end
    fm.SetTextColor = function(self, r, g, b, a) rawset(self, "__tcol", { r or 1, g or 1, b or 1, a or 1 }) end
    fm.SetTextInsets = function(self, l, r) rawset(self, "__ins", { l or 0, r or 0 }) end
    fm.SetJustifyH = function(self, j) rawset(self, "__jh", j) end
    -- status bars: texture, colour and fill
    fm.SetStatusBarTexture = function(self, t) rawset(self, "__sbtex", type(t) == "string" and t or "WHITE") end
    fm.SetStatusBarColor = function(self, r, g, b, a) rawset(self, "__sbcol", { r or 1, g or 1, b or 1, a or 1 }) end
    fm.SetMinMaxValues = function(self, lo, hi) rawset(self, "__min", tonumber(lo) or 0); rawset(self, "__max", tonumber(hi) or 1) end
    fm.GetMinMaxValues = function(self) return rawget(self, "__min") or 0, rawget(self, "__max") or 1 end
    fm.SetValue = function(self, v) rawset(self, "__sbval", tonumber(v)) end
    fm.GetValue = function(self) return rawget(self, "__sbval") or 0 end
    fm.SetReverseFill = function(self, v) rawset(self, "__rev", v and true or false) end
    fm.SetClipsChildren = function(self, v) rawset(self, "__clips", v and true or false) end
    fm.SetAlpha = function(self, a) rawset(self, "__alpha", a) end
    fm.GetAlpha = function(self) return rawget(self, "__alpha") or 1 end
    rm.SetVertexColor = function(self, r, g, b, a) rawset(self, "__vc", { r or 1, g or 1, b or 1, a or 1 }); rawset(self, "__grad", nil) end
    rm.GetVertexColor = function(self) local c = rawget(self, "__vc") or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    rm.SetColorTexture = function(self, r, g, b, a)
        rawset(self, "__tex", "WHITE"); rawset(self, "__vc", { r or 1, g or 1, b or 1, a or 1 }); rawset(self, "__grad", nil)
    end
    rm.SetGradient = function(self, o, c1, c2)
        local function rgba(c) if type(c) == "table" and c.r then return { c.r, c.g, c.b, c.a or 1 } end return { 1, 1, 1, 1 } end
        rawset(self, "__grad", { o, rgba(c1), rgba(c2) })
    end
    rm.SetTexture = function(self, t) rawset(self, "__tex", type(t) == "string" and t or (t and tostring(t)) or nil) end
    rm.GetTexture = function(self) return rawget(self, "__tex") end
    rm.SetAtlas = function(self, a) rawset(self, "__atlas", a) end
    rm.SetTexCoord = function(self, a, b, c, d, ...)
        if select("#", ...) > 0 then rawset(self, "__tc", { a, (...), c, d }) else rawset(self, "__tc", { a, b, c, d }) end
    end
    rm.GetTexCoord = function(self) local t = rawget(self, "__tc") or { 0, 1, 0, 1 }; return t[1], t[2], t[3], t[4] end
    rm.SetDrawLayer = function(self, l, sub) rawset(self, "__layer", l); rawset(self, "__sub", tonumber(sub) or 0) end
    rm.SetAlpha = fm.SetAlpha
    rm.GetAlpha = fm.GetAlpha
    rm.SetFont = function(self, path, size, flags) rawset(self, "__font", { path, size, flags }); return true end
    rm.GetFont = function(self) local f = rawget(self, "__font"); if f then return f[1], f[2], f[3] end return "font", 12, "" end
    rm.SetTextColor = function(self, r, g, b, a) rawset(self, "__tcol", { r or 1, g or 1, b or 1, a or 1 }) end
    rm.GetTextColor = function(self) local c = rawget(self, "__tcol") or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    rm.SetJustifyH = function(self, j) rawset(self, "__jh", j) end
    rm.SetJustifyV = function(self, j) rawset(self, "__jv", j) end
    -- text measured with the real advance widths (PUI_SHOT_METRICS, tools/smoke/shot_metrics.py)
    local mpath = os.getenv("PUI_SHOT_METRICS")
    local metrics = mpath and dofile(mpath) or {}
    local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  ")) end
    local function measure(self, line)
        local f = rawget(self, "__font")
        local size = f and tonumber(f[2]) or 12
        local m = f and metrics[(tostring(f[1]):match("([^\\/]+)$"))]
        if not m then return #line * size * 0.5 end
        local w = 0
        for _, cp in utf8codes(line) do w = w + (m.adv[cp] or m.adv[32] or m.upm / 2) end
        return w * size / m.upm
    end
    local function lines(self)
        local t = plain(rawget(self, "__text"))
        if t == "" then return {} end
        local w = rawget(self, "__w")
        local out = {}
        for para in (t .. "\n"):gmatch("(.-)\n") do
            if rawget(self, "__wrap") and w and w > 0 and not rawget(self, "__autow") then
                local line = ""
                for word in para:gmatch("%S+") do
                    local test = line == "" and word or (line .. " " .. word)
                    if measure(self, test) > w and line ~= "" then out[#out + 1] = line; line = word else line = test end
                end
                out[#out + 1] = line
            else
                out[#out + 1] = para
            end
        end
        return out
    end
    rm.GetUnboundedStringWidth = function(self)
        local best = 0
        for _, l in ipairs(lines(self)) do best = math.max(best, measure(self, l)) end
        return best
    end
    rm.GetStringWidth = function(self)
        local u, w = rm.GetUnboundedStringWidth(self), rawget(self, "__w")
        if w and not rawget(self, "__autow") then return math.min(u, w) end
        return u
    end
    rm.GetStringHeight = function(self)
        local f = rawget(self, "__font")
        local size = f and tonumber(f[2]) or 12
        return math.max(1, #lines(self)) * math.floor(size * 1.18 + 0.5)
    end
    S.measure = rm
end

-- iterates the code points of a UTF-8 string (Lua 5.1 has no utf8 library)
function utf8codes(str)
    local i, n = 1, #str
    return function()
        if i > n then return nil end
        local c = str:byte(i)
        local cp, len
        if c < 0x80 then cp, len = c, 1
        elseif c < 0xE0 then cp, len = (c % 0x20) * 64 + (str:byte(i + 1) or 0) % 64, 2
        elseif c < 0xF0 then cp, len = ((c % 0x10) * 64 + (str:byte(i + 1) or 0) % 64) * 64 + (str:byte(i + 2) or 0) % 64, 3
        else cp, len = 0x3F, 4 end
        local at = i
        i = i + len
        return at, cp
    end
end

---------------------------------------------------------------- dump
local function esc(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
local function json(v)
    local t = type(v)
    if t == "table" then
        if #v > 0 or next(v) == nil then
            local out = {}
            for i = 1, #v do out[i] = json(v[i]) end
            return "[" .. table.concat(out, ",") .. "]"
        end
        local out = {}
        for k, x in pairs(v) do out[#out + 1] = esc(k) .. ":" .. json(x) end
        return "{" .. table.concat(out, ",") .. "}"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        return string.format("%.3f", v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "string" then return esc(v) end
    return "null"
end

function S.Run(ctx)
    local ns, Geo, frames, regions, scripts = ctx.ns, ctx.Geo, ctx.frames, ctx.regions, ctx.scripts
    local env, out = ctx.env, ctx.out
    local UI = env.UIParent
    local W0, H0 = 1600, 960
    Geo.root, Geo.rootW, Geo.rootH = UI, W0, H0
    rawset(UI, "__w", W0); rawset(UI, "__h", H0)
    ctx.slashes.pui("")
    local C = ns.Config
    local f = C:Build()
    f:SetScale(1)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UI, "CENTER", 0, 0)
    local LAYER = { BACKGROUND = 0, BORDER = 1, ARTWORK = 2, OVERLAY = 3, HIGHLIGHT = 4 }

    local function ancestors(o)
        local list, p = {}, Geo.parent[o]
        while p do list[#list + 1] = p; p = Geo.parent[p] end
        return list
    end
    local function shown(o)
        if rawget(o, "__shown") == false then return false end
        for _, p in ipairs(ancestors(o)) do
            if rawget(p, "__shown") == false then return false end
            if p == f then return true end
        end
        return o == f
    end
    -- frames sized by two anchors report their real size, as GetWidth does in game after a layout pass
    local function settle()
        for _ = 1, 3 do
            for _, fr in ipairs(frames) do
                local pts = Geo.points[fr]
                if pts and #pts >= 2 then
                    local _, _, w, h = Geo.Rect(fr)
                    local s = Geo.EffectiveScale(fr)
                    if w and w > 0 then rawset(fr, "__w", w / s) end
                    if h and h > 0 then rawset(fr, "__h", h / s) end
                end
            end
            -- scroll children hang at the scroll frame's top-left
            for _, fr in ipairs(frames) do
                local child = rawget(fr, "child")
                if child and rawget(fr, "__type") == "ScrollFrame" then
                    if not Geo.points[child] then
                        Geo.points[child] = { { p = "TOPLEFT", rel = fr, rp = "TOPLEFT", x = 0, y = 0 } }
                    end
                    if rawget(fr, "__w") then rawset(child, "__w", rawget(fr, "__w")) end
                end
            end
        end
    end

    -- a font string without a set size is as large as its text, as in game
    local function sizeTexts()
        for r in pairs(regions) do
            if rawget(r, "__kind") == "text" then
                if rawget(r, "__autow") then rawset(r, "__w", nil); rawset(r, "__autow", nil) end
                if rawget(r, "__autoh") then rawset(r, "__h", nil); rawset(r, "__autoh", nil) end
                local pts = Geo.points[r] or {}
                local hasX, hasY = 0, 0
                for _, pt in ipairs(pts) do
                    local h, v = Geo.split(pt.p)
                    if h == 0 or h == 1 then hasX = hasX + (h == 0 and 1 or 2) end
                    if v == 0 or v == 1 then hasY = hasY + (v == 0 and 1 or 2) end
                end
                if not rawget(r, "__w") and hasX ~= 3 then
                    rawset(r, "__w", S.measure.GetUnboundedStringWidth(r)); rawset(r, "__autow", true)
                end
                if not rawget(r, "__h") and hasY ~= 3 then
                    rawset(r, "__h", S.measure.GetStringHeight(r)); rawset(r, "__autoh", true)
                end
            end
        end
    end

    local function textAnchor(r)
        local pts = Geo.points[r]
        if not pts or #pts == 0 then return nil end
        local s = Geo.EffectiveScale(r)
        local xs, ys = {}, {}
        for _, pt in ipairs(pts) do
            local rel = pt.rel
            if rel == nil or type(rel) == "string" then rel = Geo.parent[r] or Geo.root end
            local l, b, rw, rh = Geo.Rect(rel)
            if not l then return nil end
            local ph, pv = Geo.split(pt.p)
            local rh2, rv2 = Geo.split(pt.rp)
            xs[#xs + 1] = { ph, l + rw * rh2 + pt.x * s }
            ys[#ys + 1] = { pv, H0 - (b + rh * rv2 + pt.y * s) }
        end
        return xs, ys
    end

    local function clipOf(o)
        local box
        for _, p in ipairs(ancestors(o)) do
            if rawget(p, "__clips") or rawget(p, "__type") == "ScrollFrame" then
                local l, b, w, h = Geo.Rect(p)
                if l then
                    local r = { l, H0 - b - h, l + w, H0 - b }
                    if not box then box = r
                    else box = { math.max(box[1], r[1]), math.max(box[2], r[2]), math.min(box[3], r[3]), math.min(box[4], r[4]) } end
                end
            end
            if p == f then break end
        end
        return box
    end

    local function dump(name)
        local items = {}
        local function level(o) return o.GetFrameLevel and o:GetFrameLevel() or 1 end
        local function alpha(o)
            local a = rawget(o, "__alpha") or 1
            for _, p in ipairs(ancestors(o)) do a = a * (rawget(p, "__alpha") or 1) end
            return a
        end
        for r in pairs(regions) do
            local kind = rawget(r, "__kind")
            if kind and shown(r) then
                local parent = Geo.parent[r]
                local item = { kind = kind, lvl = level(parent), layer = LAYER[rawget(r, "__layer")] or 2,
                    sub = rawget(r, "__sub") or 0, seq = rawget(r, "__seq") or 0, alpha = alpha(r), clip = clipOf(r) }
                if kind == "tex" then
                    local l, b, w, h = Geo.Rect(r)
                    if l and w and h and w > 0 and h > 0 then
                        item.rect = { l, H0 - b - h, w, h }
                        item.tex = rawget(r, "__tex"); item.tc = rawget(r, "__tc"); item.vc = rawget(r, "__vc"); item.grad = rawget(r, "__grad")
                        if item.tex or item.vc or item.grad then items[#items + 1] = item end
                    end
                else
                    local t = rawget(r, "__text")
                    local xs, ys = textAnchor(r)
                    if t and t ~= "" and xs then
                        item.text = t; item.xs = xs; item.ys = ys
                        item.w = (not rawget(r, "__autow")) and rawget(r, "__w") or nil
                        item.h = (not rawget(r, "__autoh")) and rawget(r, "__h") or nil
                        item.font = rawget(r, "__font"); item.col = rawget(r, "__tcol"); item.jh = rawget(r, "__jh"); item.jv = rawget(r, "__jv")
                        item.wrap = rawget(r, "__wrap"); item.scale = Geo.EffectiveScale(r)
                        items[#items + 1] = item
                    end
                end
            end
        end
        for _, fr in ipairs(frames) do
            if rawget(fr, "__type") == "StatusBar" and shown(fr) then
                local l, b, w, h = Geo.Rect(fr)
                local lo, hi = rawget(fr, "__min") or 0, rawget(fr, "__max") or 1
                local v = rawget(fr, "__sbval")
                if l and w > 0 and h > 0 and type(v) == "number" and hi > lo then
                    local p = math.max(0, math.min(1, (v - lo) / (hi - lo)))
                    local fw = w * p
                    local x = rawget(fr, "__rev") and (l + w - fw) or l
                    items[#items + 1] = { kind = "tex", lvl = level(fr), layer = 2, sub = -1, seq = 0, alpha = alpha(fr), clip = clipOf(fr),
                        rect = { x, H0 - b - h, fw, h }, tex = rawget(fr, "__sbtex") or "WHITE", vc = rawget(fr, "__sbcol") or { 0.4, 0.8, 0.4, 1 } }
                end
            end
        end
        for _, fr in ipairs(frames) do
            local t = rawget(fr, "__text")
            if rawget(fr, "__type") == "EditBox" and t and t ~= "" and shown(fr) then
                local l, b, w, h = Geo.Rect(fr)
                if l and w > 0 then
                    local ins = rawget(fr, "__ins") or { 0, 0 }
                    local jh = rawget(fr, "__jh") or "LEFT"
                    items[#items + 1] = { kind = "text", text = t, lvl = level(fr) + 1, layer = 3, sub = 0, seq = 0, alpha = alpha(fr),
                        clip = clipOf(fr), xs = { { 0, l + ins[1] }, { 1, l + w - ins[2] } }, ys = { { 0.5, H0 - (b + h / 2) } },
                        font = rawget(fr, "__font"), col = rawget(fr, "__tcol"), jh = jh, scale = Geo.EffectiveScale(fr) }
                end
            end
        end
        local l, b, w, h = Geo.Rect(f)
        local fh = assert(io.open(out .. "/" .. name .. ".json", "w"))
        fh:write(json({ window = { l, H0 - b - h, w, h }, screen = { W0, H0 }, items = items }))
        fh:close()
        print(("  shot %s: %d items, window %dx%d"):format(name, #items, w, h))
    end

    local function shoot(key, name)
        local page = C:Show(key)
        page:SetAlpha(1)
        for _ = 1, 2 do
            sizeTexts()
            settle()
            if page.scroll and scripts[page.scroll] and scripts[page.scroll].OnSizeChanged then
                scripts[page.scroll].OnSizeChanged(page.scroll, rawget(page.scroll, "__w"), rawget(page.scroll, "__h"))
            end
            if page.Layout then page:Layout() end
            C:LayoutSidebar()
        end
        sizeTexts()
        settle()
        -- sliders place their fill from the bar width, which is only known now
        for _, fr in ipairs(frames) do
            if rawget(fr, "fill") and rawget(fr, "thumb") and rawget(fr, "bar") and rawget(fr, "value") and fr.SetValue then
                pcall(fr.SetValue, fr, rawget(fr, "value"))
            end
        end
        sizeTexts()
        settle()
        dump(name)
    end
    shoot("ActionBars", "actionbars")
    shoot("UnitFrames", "unitframes")
    shoot("home", "home")
end

return S
