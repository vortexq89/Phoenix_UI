local _, ns = ...

--[[ ns.Diag — in-game self-test for Phoenix media and the settings window (/pui diag).
    Every bundled texture (icon atlases, brand art, bars, glows, shapes) is loaded into a probe texture and
    checked once the client reports it loaded: native size must match the file. When the settings window
    has been opened, the glyph textures it uses are inspected too (file, size, alpha, colour, visibility).
    Results are printed and kept in PhoenixUIDB.global.diag, so a SavedVariables file shows what the game
    really did. The check runs by itself once per version, a few seconds after login, and prints only when
    something failed. Output is fixed English on purpose: it is a support tool, like /pui testerror. ]]
local D = {}
ns.Diag = D

local WAIT, STEP = 4, 0.25 -- seconds to wait for asynchronous texture loads, poll step
local MAX_GLYPHS = 24

local function media()
    local T = ns.C.TEXTURES
    local icons = "Interface\\AddOns\\" .. ns.ADDON .. "\\Media\\Icons\\"
    local list = {}
    local function add(kind, path, w, h) list[#list + 1] = { kind = kind, path = path, w = w, h = h } end
    for _, t in ipairs(ns.IconData.tiers) do add("icons", icons .. t.file, t.width, t.height) end
    for _, n in ipairs({ 64, 128, 256 }) do add("brand", T .. "Emblem" .. n, n, n) end
    add("brand", T .. "Logo512", 512, 128)
    add("brand", T .. "Logo1024", 1024, 256)
    for _, b in ipairs(ns.TextureData.bars) do add("bar", T .. b.file, 256, 32) end
    for _, g in ipairs(ns.TextureData.glows) do add("glow", T .. g.file, 64, 64) end
    for _, b in ipairs(ns.TextureData.borders) do add("border", T .. b.file, 128, 16) end
    add("shape", T .. "Circle", 32, 32); add("shape", T .. "Rounded", 32, 32)
    add("shape", T .. "Pill", 64, 32); add("shape", T .. "FadeV", 8, 64)
    return list
end

local function short(path) return (tostring(path):gsub("^Interface\\AddOns\\[^\\]+\\Media\\", "")) end
local function round(v) return type(v) == "number" and math.floor(v * 1000 + 0.5) / 1000 or v end

-- obj:method(...) when the object has it; nil when it does not or the call fails. A self-test must never throw,
-- and widget methods differ between object types (textures have no GetEffectiveAlpha) and client builds.
local function try(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, obj, ...)
    if ok then return a, b, c, d end
end

-- A number or nil, never a secret value (the game may hand those back during combat).
local function num(v)
    if type(v) ~= "number" or ns.Secret.IsSecret(v) then return nil end
    return v
end

local function fmt4(pattern, a, b, c, d)
    return pattern:format(num(a) or -1, num(b) or -1, num(c) or -1, num(d) or -1)
end

-- Textures have no effective alpha of their own: their alpha times the parent frame's effective alpha.
local function effectiveAlpha(tex)
    local own = num(try(tex, "GetAlpha")) or 1
    local parent = try(tex, "GetParent")
    local inherited = num(try(parent, "GetEffectiveAlpha")) or 1
    return round(own * inherited)
end

local function glyph(tex, s)
    local w, h = try(tex, "GetSize")
    local parent = try(tex, "GetParent")
    local loaded = "n/a"
    if type(tex.IsObjectLoaded) == "function" then loaded = try(tex, "IsObjectLoaded") == true end
    return {
        name = tostring(s.name), file = short(try(tex, "GetTexture") or "?"),
        size = tostring(round(num(w))) .. "x" .. tostring(round(num(h))), loaded = loaded,
        shown = try(tex, "IsShown") == true, visible = try(tex, "IsVisible") == true, alpha = effectiveAlpha(tex),
        color = fmt4("%.2f %.2f %.2f %.2f", try(tex, "GetVertexColor")),
        coords = fmt4("%.3f %.3f %.3f %.3f", try(tex, "GetTexCoord")),
        layer = tostring(try(tex, "GetDrawLayer") or "?"), parentShown = try(parent, "IsShown") == true,
    }
end

-- The glyph textures the settings window created, as the game sees them right now.
local function glyphs()
    local out, order = {}, {}
    local tracked = ns.Icons and ns.Icons.Tracked and ns.Icons:Tracked() or {}
    for tex, s in pairs(tracked) do
        if type(s) == "table" and s.name then order[#order + 1] = { tex = tex, s = s, vis = try(tex, "IsVisible") == true } end
    end
    table.sort(order, function(a, b) return a.vis and not b.vis end) -- what is on screen first
    for _, o in ipairs(order) do
        if #out >= MAX_GLYPHS then break end
        local ok, entry = pcall(glyph, o.tex, o.s)
        out[#out + 1] = ok and entry or { name = tostring(o.s.name), error = tostring(entry) }
    end
    return out
end

local function probe(p)
    local tex, m = p.tex, p.m
    local loaded = true
    if type(tex.IsObjectLoaded) == "function" then loaded = try(tex, "IsObjectLoaded") == true end
    local w, h = try(tex, "GetSize")
    w, h = round(num(w)), round(num(h))
    return { file = short(m.path), kind = m.kind, ok = loaded and w == m.w and h == m.h, loaded = loaded,
        size = tostring(w) .. "x" .. tostring(h), want = m.w .. "x" .. m.h, id = num(try(tex, "GetTextureFileID")) }
end

local running

function D:IsRunning() return running == true end

local function run(quiet)
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 64, -64) -- off screen, but shown so loads are not deferred
    local probes = {}
    for i, m in ipairs(media()) do
        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT")
        tex:SetTexture(m.path)
        probes[i] = { tex = tex, m = m }
    end
    local waited = 0
    local function finish()
        local results, failed = {}, 0
        for _, p in ipairs(probes) do
            local ok, r = pcall(probe, p)
            if not ok then r = { file = short(p.m.path), kind = p.m.kind, ok = false, loaded = false, size = "?",
                want = p.m.w .. "x" .. p.m.h, error = tostring(r) } end
            if not r.ok then failed = failed + 1 end
            results[#results + 1] = r
        end
        pcall(holder.Hide, holder)
        local build, _, _, toc = GetBuildInfo()
        local pw, ph = GetPhysicalScreenSize()
        local okGlyphs, list = pcall(glyphs)
        local report = {
            version = ns.version, time = time(), build = build, toc = toc, flavor = ns.flavor, locale = GetLocale(),
            screen = tostring(pw) .. "x" .. tostring(ph), uiScale = round(num(try(UIParent, "GetEffectiveScale"))),
            media = results, failed = failed, total = #results,
            window = ns.Config and ns.Config.current or false, glyphs = okGlyphs and list or {},
            glyphError = not okGlyphs and tostring(list) or nil,
        }
        ns.DB.sv.global.diag = report
        running = false
        ns.Events:Fire("PUI_DIAG_DONE", report)
        local glyphNote = #report.glyphs > 0 and (" · %d settings glyphs recorded"):format(#report.glyphs)
            or " · open /pui first to include the settings window"
        if not quiet or failed > 0 then
            ns:Print("diag: %d/%d media files loaded%s.", report.total - failed, report.total, glyphNote)
            for _, r in ipairs(results) do
                if not r.ok then
                    ns:Print("  FAILED %s (loaded=%s, size %s, expected %s)", r.file, tostring(r.loaded), r.size, r.want)
                end
            end
            if not quiet then ns:Print("diag: saved for support; /reload or log out to write it to disk.") end
        end
    end
    -- finish() is guarded piece by piece; this outer guard only makes sure a run can never stay "running".
    local function done()
        local ok, err = pcall(finish)
        if not ok then
            running = false
            ns.DB.sv.global.diag = { version = ns.version, time = time(), error = tostring(err), media = {}, glyphs = {} }
            if not quiet then ns:Print("diag: the self-test failed (%s).", tostring(err)) end
        end
    end
    local function poll()
        waited = waited + STEP
        local pending = false
        for _, p in ipairs(probes) do
            if type(p.tex.IsObjectLoaded) == "function" and try(p.tex, "IsObjectLoaded") == false then pending = true; break end
        end
        if pending and waited < WAIT then C_Timer.After(STEP, poll) else done() end
    end
    C_Timer.After(STEP, poll)
end

function D:Run(quiet)
    if running then return end
    running = true
    local ok, err = pcall(run, quiet)
    if not ok then
        running = false
        ns.DB.sv.global.diag = { version = ns.version, time = time(), error = tostring(err), media = {}, glyphs = {} }
        if not quiet then ns:Print("diag: the self-test failed (%s).", tostring(err)) end
    end
end

-- Once per version, quietly, after the login rush.
ns.Events:On("PLAYER_LOGIN", D, function()
    local last = ns.DB.sv.global.diag
    if type(last) == "table" and last.version == ns.version then return end
    C_Timer.After(8, function() D:Run(true) end)
end)
