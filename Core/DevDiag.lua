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
D.Store = function() return db() end
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
    local st = db().selftest
    if st and st.pages and next(st.pages) then
        report.selftest = { loops = st.loops, started = st.started, stopReason = st.stopReason, pages = st.pages }
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("Self-test: %d loops, stop: %s"):format(st.loops or 0, tostring(st.stopReason or "running"))
        local keys = {}
        for k in pairs(st.pages) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local r = st.pages[k]
            lines[#lines + 1] = ("  %-22s steps %d  issues %d  errors %d"):format(k, r.steps or 0, r.count or 0, r.errors or 0)
            for _, x in ipairs(r.issues or {}) do
                lines[#lines + 1] = ("    [%s] %s %s  %s"):format(SEV[x.sev] or "?", tostring(x.kind), tostring(x.what), tostring(x.detail))
            end
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


---------------------------------------------------------------- self-test (dev only, opt-in)
-- /pui dev selftest on: walks every options page, every tab, every preview state and movers on/off,
-- one step per timer tick, auditing after each step. No input is sent to the game and nothing is
-- played: it pauses in combat and stops for good as soon as the player moves, casts or opens a vehicle.
-- ReloadUI / C_UI.Reload need a hardware event, so results reach PhoenixUIDevDB at the next /reload,
-- logout or idle disconnect. Each finished page is also printed to chat and (optionally) screenshotted.
local ST = { running = false, paused = false }
D.SelfTest = ST
local STEP, LOOP_WAIT, MAX_LOOPS = 0.6, 60, 500

local function stepIssues(label)
    report = { issues = {} }
    textSeen = 0
    local cfg = _G.PhoenixUI_Config
    if cfg and cfg:IsVisible() then auditText(cfg, label) end
    pcall(auditPreviews)
    return report.issues
end

local function buildSteps()
    local C, steps = ns.Config, {}
    for _, g in ipairs(C:Groups()) do
        for _, key in ipairs(g.entries or {}) do
            steps[#steps + 1] = { page = key, label = key, run = function() return C:Show(key) end }
            steps[#steps + 1] = { page = key, expand = true }
        end
    end
    local mv = ns.modules and ns.modules.Movers
    if mv and mv.SetUnlocked then
        steps[#steps + 1] = { page = "movers", label = "movers on", run = function() mv:SetUnlocked(true) end }
        steps[#steps + 1] = { page = "movers", label = "movers off", run = function() mv:SetUnlocked(false) end }
    end
    return steps
end

-- Tabs and preview states of a page become their own steps right after the page opens.
local function expand(page, key)
    local out = {}
    if not page then return out end
    local function tabs(n)
        if not page.tabs or not page.tabList then return end
        out[#out + 1] = { page = key, label = key .. " tab " .. n, run = function()
            page.tabs:SetValue(n); page.tabs.onChange(page.tabs, n)
        end }
    end
    for n = 1, #(page.tabList or {}) do tabs(n) end
    local card = page.pinned
    if card and card.states and card.states.chips then
        for _, it in ipairs(card.states.chips) do if it:IsShown() then
            out[#out + 1] = { page = key, label = key .. " preview " .. tostring(it.value), run = function()
                card.states:SetValue({ [it.value] = true }); card.states.onChange(card.states, card.states:GetValue())
            end }
        end end
        out[#out + 1] = { page = key, label = key .. " preview plain", run = function()
            card.states:SetValue({}); card.states.onChange(card.states, card.states:GetValue())
        end }
    end
    return out
end

local function store()
    local d = db()
    d.selftest = d.selftest or {}
    return d.selftest
end

function ST:Stop(why)
    if self.ticker then self.ticker:Cancel() end
    self.ticker, self.running = nil, false
    local st = store()
    st.stopped, st.stopReason = time(), why
    ns:Print("self-test stopped: " .. tostring(why))
end

local function flushPage(key)
    local st, r = store(), ST.cur
    if not r then return end
    st.pages = st.pages or {}
    st.pages[key] = r
    ns:Print(("self-test %s: %d steps, %d issues%s"):format(key, r.steps, r.count, r.errors > 0 and (", " .. r.errors .. " errors") or ""))
    if st.shots and Screenshot then pcall(Screenshot) end
end

function ST:Tick()
    if not self.running then return end
    if InCombatLockdown() then self.paused = true; return end
    self.paused = false
    if self.waitUntil then
        if GetTime() < self.waitUntil then return end
        self.waitUntil = nil
    end
    local s = self.steps[self.i]
    if not s then
        if self.curKey then flushPage(self.curKey); self.curKey, self.cur = nil, nil end
        local st = store()
        st.loops = (st.loops or 0) + 1
        st.lastLoop = time()
        if ns.Config and _G.PhoenixUI_Config then _G.PhoenixUI_Config:Hide() end
        if st.loops >= MAX_LOOPS then return self:Stop("loop cap") end
        self.steps, self.i, self.waitUntil = buildSteps(), 1, GetTime() + LOOP_WAIT
        return
    end
    self.i = self.i + 1
    if s.page ~= self.curKey then
        if self.curKey then flushPage(self.curKey) end
        self.curKey, self.cur = s.page, { steps = 0, count = 0, errors = 0, issues = {}, time = time() }
    end
    if s.expand then
        local add = expand(ns.Config.pages[s.page], s.page)
        for n = #add, 1, -1 do table.insert(self.steps, self.i, add[n]) end
        return
    end
    local ok, err = pcall(s.run)
    local r = self.cur
    r.steps = r.steps + 1
    if not ok then
        r.errors = r.errors + 1
        r.issues[#r.issues + 1] = { sev = 1, kind = "selftest-error", what = s.label, detail = tostring(err) }
    end
    for _, x in ipairs(stepIssues(s.label)) do
        r.count = r.count + 1
        if #r.issues < 40 then
            r.issues[#r.issues + 1] = { sev = x.sev, kind = x.kind, what = s.label .. ": " .. tostring(x.what), detail = x.detail }
        end
    end
end

function ST:Start()
    local C = ns.Config
    if InCombatLockdown() then return false, "in combat" end
    if not C or not C.Groups then
        if ns.Launcher and ns.Launcher.Load then ns.Launcher:Load() end
        C = ns.Config
    end
    if not (C and C.Groups and C.Show) then return false, "options not loaded" end
    D:SetEnabled(true)
    local st = store()
    st.started, st.loops, st.pages, st.stopReason = time(), 0, {}, nil
    self.steps, self.i, self.curKey, self.cur, self.running = buildSteps(), 1, nil, nil, true
    self.ticker = C_Timer.NewTicker(STEP, function() ST:Tick() end)
    return true
end

-- the player taking over ends the test; nothing is ever pressed for them
local function playerActs(_, event, unit)
    if ST.running and (event ~= "UNIT_SPELLCAST_SENT" or unit == "player") then ST:Stop("player " .. event) end
end
for _, ev in ipairs({ "PLAYER_STARTED_MOVING", "UNIT_SPELLCAST_SENT", "PLAYER_TARGET_CHANGED", "UNIT_ENTERED_VEHICLE" }) do
    ns.Events:On(ev, ST, playerActs)
end
ns.Events:On("PLAYER_LOGOUT", ST, function()
    if ST.running then store().stopReason = "logout (results saved)" end
end)

function ST:Slash(arg)
    if arg == "on" then
        local ok, why = self:Start()
        ns:Print(ok and "self-test ON - stops when you move, cast or target; /reload or log out to save results"
            or ("self-test not started: " .. tostring(why)))
    elseif arg == "off" then
        if self.running then self:Stop("off") end
    elseif arg == "shots on" or arg == "shots off" then
        store().shots = arg == "shots on"
        ns:Print("self-test screenshots " .. (store().shots and "ON" or "OFF"))
    else
        local st = store()
        local state = self.running and (self.paused and "paused (combat)" or "running") or "off"
        ns:Print(("self-test %s, loops %d%s"):format(state,
            st.loops or 0, st.stopReason and (", last stop: " .. st.stopReason) or ""))
    end
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
    elseif rest:match("^selftest") then
        ST:Slash(rest:match("^selftest%s*(.-)%s*$"))
    elseif rest == "clear" then
        db().last = nil
        wipe(taint); wipe(localeMiss); wipe(localeOrder)
        ns:Print("dev diagnostics cleared")
    else
        ns:Print("/pui dev [on|off|audit|pages|clear|selftest on|off|shots on|off]")
    end
end
