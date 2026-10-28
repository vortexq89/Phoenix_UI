local ADDON, ns = ...

--[[ ns.DevDiag — developer diagnostics (for the Phoenix developers and their assistant, not the player-facing Bugs
    module). Off unless turned on with /pui dev. When on, it writes PhoenixUIDevDB.last at logout and /reload (and
    on demand with /pui dev audit), with:
      errors        Phoenix errors and warnings of this session, other addons' errors in their own section
      layout        every visible Phoenix frame: rect, off-screen, zero size, hidden-but-enabled, overlaps with
                    other Phoenix frames and with Blizzard frames; text truncation/overflow and fonts under 12
                    effective px inside Phoenix frames and the settings window
      actionbars    real button size and scale against the configured size (the 24-vs-40 bug)
      previews      preview content against its stage
      icons         Phoenix art on game-content buttons (game icons are never replaced)
      taint, combat queue leftovers, memory/CPU, module enable state, stored-vs-applied mismatches, missing
      locale keys hit at runtime
    Output: issues ranked by severity (1 critical .. 4 info), plus `text` and `json` strings so a tool outside the
    game (tools/pc/phoenix_diag.ps1) can export them without a Lua parser. Rules kept: no OnUpdate (C_Timer only),
    secret values are never compared (num() drops them), nothing is audited in combat. Fixed English on purpose. ]]
local D = {}
ns.DevDiag = D

local SEV = { "critical", "high", "medium", "low" }
local MAX_TEXT, MAX_ISSUES = 6000, 400
local BLIZZARD = { "PlayerFrame", "TargetFrame", "FocusFrame", "MinimapCluster", "ObjectiveTrackerFrame", "BuffFrame",
    "DebuffFrame", "ChatFrame1", "MainMenuBar", "MainActionBar", "MicroMenuContainer", "BagsBar",
    "StatusTrackingBarManager", "EncounterBar", "PartyFrame", "CompactRaidFrameContainer", "ZoneAbilityFrame",
    "ExtraActionBarFrame", "PlayerCastingBarFrame" }

local sessionStart = time()
local taint, localeMiss, localeOrder = {}, {}, {}

local function isSecret(v) local f = ns.Secret and ns.Secret.IsSecret; return f and f(v) and true or false end
local function num(v) if isSecret(v) or type(v) ~= "number" then return nil end return v end
local function api(name, space)
    local t = space and _G[space]
    local fn = (type(t) == "table" and t[name]) or _G[name]
    return type(fn) == "function" and fn or nil
end
local function db()
    if type(PhoenixUIDevDB) ~= "table" then PhoenixUIDevDB = { enabled = false } end
    return PhoenixUIDevDB
end
function D:IsEnabled() return db().enabled == true end

---------------------------------------------------------------- report building
local report
local function issue(sev, kind, what, detail)
    if #report.issues >= MAX_ISSUES then report.truncated = true; return end
    report.issues[#report.issues + 1] = { sev = sev, kind = kind, what = tostring(what), detail = detail and tostring(detail) or "" }
end

local function nameOf(f)
    if not f then return "?" end
    local n = f.GetName and f:GetName()
    if n then return n end
    if f.puiDiagName then return f.puiDiagName end
    local p = f.GetParent and f:GetParent()
    return (p and nameOf(p) or "?") .. ".<anon>"
end

-- l, b, w, h in UIParent units, or nil (not resolved, or secret)
local function rect(f)
    if not (f and f.GetLeft) then return nil end
    local l, b, w, h = num(f:GetLeft()), num(f:GetBottom()), num(f:GetWidth()), num(f:GetHeight())
    if not (l and b and w and h) then return nil end
    local k = (num(f:GetEffectiveScale()) or 1) / (num(UIParent:GetEffectiveScale()) or 1)
    return l * k, b * k, w * k, h * k
end
local function round(v) return math.floor(v + 0.5) end
local function rectText(l, b, w, h) return ("%d,%d %dx%d"):format(round(l), round(b), round(w), round(h)) end
local function overlap(a, b)
    local w = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
    local h = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
    if w > 1 and h > 1 then return w * h end
    return nil
end
local function ancestor(a, b) -- is a an ancestor of b
    local p = b and b.GetParent and b:GetParent()
    while p do if p == a then return true end; p = p:GetParent() end
    return false
end

---------------------------------------------------------------- text (truncation, overflow, small fonts)
local textSeen
local function physicalScale()
    local fn = api("GetPhysicalScreenSize")
    local _, h = 0, 768
    if fn then _, h = fn() end
    return (num(h) or 768) / 768
end
local function auditText(root, where)
    if not root or not root.GetRegions then return end
    local stack, phys = { root }, physicalScale()
    while #stack > 0 and textSeen < MAX_TEXT do
        local f = table.remove(stack)
        if f:IsVisible() then
            for _, r in ipairs({ f:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" and r:IsVisible() then
                    textSeen = textSeen + 1
                    local text = r:GetText()
                    if text and not isSecret(text) and text ~= "" then
                        local sw, w = num(r:GetStringWidth()), num(r:GetWidth())
                        local sh, h = num(r:GetStringHeight()), num(r:GetHeight())
                        local wraps = r.CanWordWrap and r:CanWordWrap()
                        local label = where .. " " .. nameOf(f) .. " '" .. text:sub(1, 40) .. "'"
                        if sw and w and w > 1 and not wraps and sw > w + 1 then
                            issue(3, "text-truncated", label, ("string %d > box %d"):format(round(sw), round(w)))
                        elseif sh and h and h > 1 and wraps and sh > h + 2 then
                            issue(3, "text-overflow", label, ("text height %d > box %d"):format(round(sh), round(h)))
                        end
                        local _, size = r:GetFont()
                        size = num(size)
                        local eff = size and size * (num(r:GetEffectiveScale()) or 1) * phys
                        if eff and eff < 11.5 then
                            issue(4, "font-small", label, ("%.1f px on screen (font %d)"):format(eff, size))
                        end
                    end
                end
            end
            for _, c in ipairs({ f:GetChildren() }) do stack[#stack + 1] = c end
        end
    end
end

---------------------------------------------------------------- frames
local function phoenixFrames()
    local list, seen = {}, {}
    local function add(f, label, active)
        if f and not seen[f] then seen[f] = true; list[#list + 1] = { f = f, label = label or nameOf(f), active = active } end
    end
    local M = ns:GetModule("Movers")
    if M and M.GetEntries then
        for _, e in ipairs(M:GetEntries()) do
            if e.owned then
                local active = e.store and e.store.active and e.store.active()
                add(e.target, M:LabelOf(e) or e.key, active)
            end
        end
    end
    add(_G.PhoenixUI_MinimapButton, "minimap button")
    return list
end

local function auditOneFrame(x, shown, sw, sh)
    local f = x.f
    if x.active and not f:IsShown() then issue(3, "hidden-enabled", x.label, "enabled but not shown") end
    if not f:IsVisible() then return end
    local l, b, w, h = rect(f)
    if not l then issue(4, "unresolved", x.label, "no position"); return end
    report.frames[#report.frames + 1] = { name = x.label, rect = rectText(l, b, w, h) }
    if w < 1 or h < 1 then issue(2, "zero-size", x.label, rectText(l, b, w, h)) end
    if l + w < 1 or b + h < 1 or l > sw - 1 or b > sh - 1 then
        issue(2, "off-screen", x.label, rectText(l, b, w, h))
    elseif l < -1 or b < -1 or l + w > sw + 1 or b + h > sh + 1 then
        issue(3, "partly-off-screen", x.label, rectText(l, b, w, h))
    end
    shown[#shown + 1] = { f = f, label = x.label, r = { l, b, w, h } }
    auditText(f, "frame")
end

local function auditFrames()
    local shown, sw, sh = {}, num(UIParent:GetWidth()) or 0, num(UIParent:GetHeight()) or 0
    for _, x in ipairs(phoenixFrames()) do auditOneFrame(x, shown, sw, sh) end
    return shown
end

local function auditOverlaps(shown)
    for i = 1, #shown do
        for j = i + 1, #shown do
            local a, b = shown[i], shown[j]
            if not ancestor(a.f, b.f) and not ancestor(b.f, a.f) then
                local area = overlap(a.r, b.r)
                if area then issue(2, "overlap", a.label .. " x " .. b.label, ("%d px2"):format(round(area))) end
            end
        end
    end
    for _, name in ipairs(BLIZZARD) do
        local bf = _G[name]
        if bf and bf.IsVisible and bf:IsVisible() then
            local l, b, w, h = rect(bf)
            if l then
                for _, a in ipairs(shown) do
                    local area = overlap(a.r, { l, b, w, h })
                    if area and not ancestor(bf, a.f) and not ancestor(a.f, bf) then
                        issue(3, "overlap-blizzard", a.label .. " x " .. name, ("%d px2"):format(round(area)))
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------- action bars, icons
local function auditButton(def, b, h, i)
    local btn = _G[def.prefix .. i]
    if not (btn and btn:IsVisible()) then return end
    local w, s = num(btn:GetWidth()), num(btn:GetScale())
    local eff = w and s and w * s * (num(h:GetScale()) or 1)
    local where = def.key .. " " .. def.prefix .. i
    if s and math.abs(s - 1) > 0.01 then issue(1, "button-scale", where, ("scale %.2f (should be 1)"):format(s)) end
    if eff and math.abs(eff - b.width * (b.scale or 1)) > 1 then
        issue(1, "button-size", where, ("drawn %d, configured %d"):format(round(eff), b.width))
    end
    local icon = btn.icon or btn.Icon
    local tex = icon and icon.GetTexture and icon:GetTexture()
    if type(tex) == "string" and not isSecret(tex) and tex:find("AddOns\\" .. ADDON, 1, true) then
        issue(1, "icon-rule", where, "Phoenix art on a game button: " .. tex)
    end
end

local function auditBars()
    local AB = ns:GetModule("ActionBars")
    if not (AB and AB:IsEnabled() and AB.IsPhoenix and AB:IsPhoenix() and AB.BARS) then return end
    for _, def in ipairs(AB.BARS) do
        local b = AB.db.bars[def.key]
        local h = _G["PhoenixUI_ActionBar_" .. def.key]
        if b and b.enabled and h and h:IsVisible() and def.prefix then
            for i = 1, math.min(b.buttons or 0, def.count or 12) do auditButton(def, b, h, i) end
        end
    end
end

local function auditPreviews()
    local P = ns.Previews
    for _, stage in ipairs(P and P.stages or {}) do
        if stage:IsVisible() then
            local sl, sb, sw, sh = rect(stage)
            if sl then
                for _, c in ipairs({ stage:GetChildren() }) do
                    if c:IsVisible() then
                        local l, b, w, h = rect(c)
                        if l and w > 1 and h > 1 and (l < sl - 2 or b < sb - 2 or l + w > sl + sw + 2 or b + h > sb + sh + 2) then
                            issue(3, "preview-fit", (stage.kind or "?") .. " " .. nameOf(c),
                                ("content %s outside stage %s"):format(rectText(l, b, w, h), rectText(sl, sb, sw, sh)))
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------- state
local function auditState()
    for _, m in ipairs(ns.moduleList or {}) do
        local stored = m.db and m.db.enabled
        local on = m.IsEnabled and m:IsEnabled() or false
        report.modules[#report.modules + 1] = { key = m.key, enabled = on, stored = stored ~= false, state = m.state }
        if stored == true and not on and not m.unavailable then issue(2, "module-mismatch", m.key, "enabled in settings, not running") end
        if stored == false and on then issue(2, "module-mismatch", m.key, "disabled in settings, still running") end
    end
    local Gen = ns.modules.General
    local want = Gen and Gen.IsEnabled and Gen:IsEnabled() and Gen.WantedScale and num(Gen:WantedScale())
    local live = num(UIParent:GetScale())
    if want and live and math.abs(live - want) > 0.01 then
        issue(2, "setting-mismatch", "UI scale", ("stored %.2f, live %.2f"):format(want, live))
    end
    if not InCombatLockdown() then
        for _, k in ipairs(ns.Combat.Pending and ns.Combat:Pending() or {}) do issue(2, "combat-leftover", k, "queued job never ran") end
    end
    for _, t in ipairs(taint) do issue(1, "taint", t.what, t.detail) end
    for _, k in ipairs(localeOrder) do issue(3, "locale-missing", k, localeMiss[k] .. " lookups") end
end

local function auditPerf()
    local upd, mem = api("UpdateAddOnMemoryUsage"), api("GetAddOnMemoryUsage")
    if upd and mem then upd(); report.perf.memoryKB = num(mem(ADDON)) end
    local metric = api("GetAddOnMetric", "C_AddOnProfiler")
    if metric and Enum and Enum.AddOnProfilerMetric then
        local ok, v = pcall(metric, ADDON, Enum.AddOnProfilerMetric.RecentAverageTime)
        if ok then report.perf.recentAvgMs = num(v) end
    end
    local kb = report.perf.memoryKB
    if kb and kb > 20000 then issue(3, "memory", ADDON, ("%d KB"):format(round(kb))) end
end

local function auditErrors()
    local sv = type(PhoenixUIBugsDB) == "table" and PhoenixUIBugsDB.reports or {}
    for _, r in ipairs(sv) do
        if (r.lastSeen or 0) >= sessionStart then
            local row = { kind = r.kind, message = r.message, count = r.count, source = r.source, stack = r.stack }
            if r.source == ADDON or r.source == ADDON .. "_Options" or r.source == ADDON .. "_Data" then
                report.errors[#report.errors + 1] = row
                issue(r.kind == "warning" and 2 or 1, "lua-" .. (r.kind or "error"), (r.message or ""):sub(1, 120), "x" .. (r.count or 1))
            else
                report.otherErrors[#report.otherErrors + 1] = row
            end
        end
    end
end

---------------------------------------------------------------- output
local function jsonEsc(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
        return ("\\u%04x"):format(c:byte())
    end) .. '"'
end
local function json(v)
    local t = type(v)
    if t == "table" then
        if #v > 0 or next(v) == nil then
            local out = {}
            for i, x in ipairs(v) do out[i] = json(x) end
            return "[" .. table.concat(out, ",") .. "]"
        end
        local keys, out = {}, {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do out[#out + 1] = jsonEsc(k) .. ":" .. json(v[k]) end
        return "{" .. table.concat(out, ",") .. "}"
    elseif t == "number" then return tostring(v)
    elseif t == "boolean" then return v and "true" or "false"
    elseif v == nil then return "null" end
    return jsonEsc(v)
end
D.JSON = json

local function summaryLine(prefix, r)
    local c = r.summary
    return ("%s: %d critical, %d high, %d medium, %d low"):format(prefix, c.critical, c.high, c.medium, c.low)
end

local function finish()
    table.sort(report.issues, function(a, b)
        if a.sev ~= b.sev then return a.sev < b.sev end
        return a.kind < b.kind
    end)
    local counts = { critical = 0, high = 0, medium = 0, low = 0 }
    for _, i in ipairs(report.issues) do counts[SEV[i.sev]] = counts[SEV[i.sev]] + 1 end
    report.summary = counts
    local lines = { ("Phoenix UI dev diagnostics %s  version %s  flavor %s  reason %s"):format(
        date("%Y-%m-%d %H:%M:%S", report.time), tostring(ns.version), tostring(ns.flavor), report.reason),
        ("critical %d  high %d  medium %d  low %d  (texts checked %d)"):format(counts.critical, counts.high,
            counts.medium, counts.low, report.textsChecked or 0), "" }
    for _, i in ipairs(report.issues) do
        lines[#lines + 1] = ("[%s] %-18s %s  %s"):format(SEV[i.sev]:upper(), i.kind, i.what, i.detail)
    end
    if #report.otherErrors > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Other addons' errors:"
        for _, e in ipairs(report.otherErrors) do
            lines[#lines + 1] = ("  %s: %s"):format(tostring(e.source), tostring(e.message):sub(1, 160))
        end
    end
    report.text = table.concat(lines, "\n")
    local copy = {}
    for k, v in pairs(report) do if k ~= "text" then copy[k] = v end end
    report.json = json(copy)
    db().last = report
    return report
end

-- Builds the report now. reason: "logout" | "audit" | "test". Layout parts are skipped in combat.
function D:Audit(reason)
    report = { time = time(), reason = reason or "audit", version = ns.version, issues = {}, frames = {}, modules = {},
        errors = {}, otherErrors = {}, perf = {}, inCombat = InCombatLockdown() and true or false }
    textSeen = 0
    local steps = { auditErrors, auditState, auditPerf }
    if not report.inCombat then
        steps[#steps + 1] = function() auditOverlaps(auditFrames()) end
        steps[#steps + 1] = auditBars
        steps[#steps + 1] = auditPreviews
        steps[#steps + 1] = function()
            local cfg = _G.PhoenixUI_Config
            if cfg and cfg:IsVisible() then auditText(cfg, "options") end
        end
    end
    for _, fn in ipairs(steps) do
        local ok, err = pcall(fn)
        if not ok then issue(2, "diag-failed", "audit step", err) end
    end
    report.textsChecked = textSeen
    return finish()
end

-- Every options page in turn (one per timer tick so each lays out), then the audit. On demand only.
function D:AuditPages(done)
    local C = ns.Config
    if InCombatLockdown() or not (C and C.Groups and C.Show) then return false end
    if not C.loaded and ns.Launcher and ns.Launcher.Load then ns.Launcher:Load() end
    local pages = {}
    for _, g in ipairs(C:Groups()) do for _, key in ipairs(g.entries or {}) do pages[#pages + 1] = key end end
    local i, pageIssues = 0, {}
    local ticker
    ticker = C_Timer.NewTicker(0.3, function()
        if InCombatLockdown() then ticker:Cancel(); return end
        if i > 0 then
            report = { issues = {} }
            textSeen = 0
            local cfg = _G.PhoenixUI_Config
            if cfg then auditText(cfg, "page " .. pages[i]) end
            for _, x in ipairs(report.issues) do pageIssues[#pageIssues + 1] = x end
        end
        i = i + 1
        if i > #pages then
            ticker:Cancel()
            local r = D:Audit("pages")
            for _, x in ipairs(pageIssues) do if #r.issues < MAX_ISSUES then r.issues[#r.issues + 1] = x end end
            report = r
            finish()
            if done then done(r) end
            return
        end
        C:Show(pages[i])
    end)
    return true
end

---------------------------------------------------------------- hooks
local function hookLocale()
    local mt = getmetatable(ns.L)
    if not mt or mt.puiDiag then return end
    local base = mt.__index
    mt.puiDiag = true
    mt.__index = function(t, key)
        local v = base(t, key)
        if v == key and D:IsEnabled() and type(key) == "string" and key:match("^[%u%d_]+$") then
            if not localeMiss[key] then localeOrder[#localeOrder + 1] = key end
            localeMiss[key] = (localeMiss[key] or 0) + 1
        end
        return v
    end
end
D.HookLocale = hookLocale

local owner = {}
local function onTaint(_, event, addon, fn)
    if not D:IsEnabled() then return end
    if addon == ADDON or addon == ADDON .. "_Options" then
        taint[#taint + 1] = { what = event, detail = tostring(fn) }
    end
end
ns.Events:On("ADDON_ACTION_BLOCKED", owner, onTaint)
ns.Events:On("ADDON_ACTION_FORBIDDEN", owner, onTaint)
-- registered at file load, before DB's own logout handler strips defaults from the saved tables
ns.Events:On("PLAYER_LOGOUT", owner, function()
    if D:IsEnabled() then pcall(D.Audit, D, "logout") end
end)
ns.Events:On("PLAYER_LOGIN", owner, function()
    if D:IsEnabled() then hookLocale() end
end)

function D:SetEnabled(on)
    db().enabled = on and true or false
    if on then hookLocale() end
end

function D:Slash(rest)
    rest = (rest or ""):lower()
    if rest == "" or rest == "on" or rest == "off" then
        local on = rest == "on" or (rest == "" and not self:IsEnabled())
        self:SetEnabled(on)
        ns:Print("dev diagnostics " .. (on and "ON - a report is written at every /reload and logout (PhoenixUIDevDB)" or "OFF"))
    elseif rest == "audit" then
        local r = self:Audit("audit")
        ns:Print(summaryLine("dev audit", r))
    elseif rest == "pages" then
        if not self:AuditPages(function(r)
            ns:Print(summaryLine("dev page audit", r))
        end) then ns:Print("dev page audit: not in combat") end
    elseif rest == "clear" then
        db().last = nil
        wipe(taint); wipe(localeMiss); wipe(localeOrder)
        ns:Print("dev diagnostics cleared")
    else
        ns:Print("/pui dev [on|off|audit|pages|clear]")
    end
end
