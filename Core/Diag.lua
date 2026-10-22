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

-- The glyph textures the settings window created, as the game sees them right now.
local function glyphs()
    local out, order = {}, {}
    for tex, s in pairs(ns.Icons:Tracked()) do
        if s.name then order[#order + 1] = { tex = tex, s = s, vis = tex:IsVisible() } end
    end
    table.sort(order, function(a, b) return a.vis and not b.vis end) -- what is on screen first
    for _, o in ipairs(order) do
        local tex, s = o.tex, o.s
        if #out >= MAX_GLYPHS then break end
        do
            local r, g, b, a = tex:GetVertexColor()
            local l, rr, t, bb = tex:GetTexCoord()
            local w, h = tex:GetSize()
            local parent = tex:GetParent()
            out[#out + 1] = {
                name = s.name, file = short(tex:GetTexture()), size = tostring(round(w)) .. "x" .. tostring(round(h)),
                loaded = tex.IsObjectLoaded and tex:IsObjectLoaded() or "n/a",
                shown = tex:IsShown(), visible = tex:IsVisible(), alpha = round(tex:GetEffectiveAlpha()),
                color = ("%.2f %.2f %.2f %.2f"):format(r or -1, g or -1, b or -1, a or -1),
                coords = ("%.3f %.3f %.3f %.3f"):format(l or -1, rr or -1, t or -1, bb or -1),
                layer = tex:GetDrawLayer(), parentShown = parent and parent:IsShown() or false,
            }
        end
    end
    return out
end

local running

function D:Run(quiet)
    if running then return end
    running = true
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
            local tex, m = p.tex, p.m
            local loaded = not tex.IsObjectLoaded or tex:IsObjectLoaded()
            local w, h = tex:GetSize()
            local ok = loaded and round(w) == m.w and round(h) == m.h
            if not ok then failed = failed + 1 end
            results[#results + 1] = { file = short(m.path), kind = m.kind, ok = ok, loaded = loaded,
                size = tostring(round(w)) .. "x" .. tostring(round(h)), want = m.w .. "x" .. m.h, id = tex:GetTextureFileID() }
        end
        holder:Hide()
        local build, _, _, toc = GetBuildInfo()
        local pw, ph = GetPhysicalScreenSize()
        local report = {
            version = ns.version, time = time(), build = build, toc = toc, locale = GetLocale(),
            screen = tostring(pw) .. "x" .. tostring(ph), uiScale = round(UIParent:GetEffectiveScale()),
            media = results, failed = failed, total = #results,
            window = ns.Config and ns.Config.current or false, glyphs = glyphs(),
        }
        ns.DB.sv.global.diag = report
        running = false
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
    local function poll()
        waited = waited + STEP
        local pending = false
        for _, p in ipairs(probes) do
            if p.tex.IsObjectLoaded and not p.tex:IsObjectLoaded() then pending = true; break end
        end
        if pending and waited < WAIT then C_Timer.After(STEP, poll) else ns.SafeCall(finish) end
    end
    C_Timer.After(STEP, poll)
end

-- Once per version, quietly, after the login rush.
ns.Events:On("PLAYER_LOGIN", D, function()
    local last = ns.DB.sv.global.diag
    if type(last) == "table" and last.version == ns.version then return end
    C_Timer.After(8, function() D:Run(true) end)
end)
