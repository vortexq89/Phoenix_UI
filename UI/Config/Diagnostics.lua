local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Config = ns.Config

--[[ Tools > Diagnostics: the /pui diag self-test on a page. It shows the last run (it also runs by itself once
    per version), lets you run it again, chooses where icons come from, and gives a plain-text report to paste
    into a bug report. The report itself stays in English on purpose, like /pui diag. ]]
local page = { key = "diagnostics", label = "DIAGNOSTICS", desc = "DIAGNOSTICS_DESC", icon = "diagnostics", locked = true, db = {} }
local updaters = {}

local function last() local d = ns.DB.sv.global.diag; return type(d) == "table" and d or nil end

local function update()
    for _, fn in ipairs(updaters) do ns.SafeCall(fn) end
end

-- A read-only value on the right of a row; fn() -> text, token
local function valueRow(fn)
    return function(row)
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(W.CONTROL_WIDTH + 140, 24)
        holder.dot = W:Dot(holder, 7)
        holder.text = W.Text(holder, "body", "text.secondary", "RIGHT")
        holder.text:SetPoint("RIGHT")
        holder.dot:SetPoint("RIGHT", holder.text, "LEFT", -8, 0)
        updaters[#updaters + 1] = function()
            local text, token = fn()
            holder.text:SetText(text or "")
            Skin:Text(holder.text, "body", token and "text.primary" or "text.secondary")
            holder.dot:SetShown(token ~= nil)
            if token then W.Color(holder.dot, token) end
        end
        return holder
    end
end

local function mediaSummary(d)
    local kinds, order = {}, {}
    for _, r in ipairs(d.media or {}) do
        local k = kinds[r.kind]
        if not k then k = { ok = 0, n = 0 }; kinds[r.kind] = k; order[#order + 1] = r.kind end
        k.n = k.n + 1
        if r.ok then k.ok = k.ok + 1 end
    end
    local parts = {}
    for _, kind in ipairs(order) do parts[#parts + 1] = ("%s %d/%d"):format(kind, kinds[kind].ok, kinds[kind].n) end
    return table.concat(parts, "  ·  ")
end

-- Plain-text report for support.
local function report()
    local d = last()
    if not d then return "Phoenix UI " .. ns.version .. ": no diagnostics yet. Run them above." end
    local lines = {
        ("Phoenix UI %s · WoW %s (%s) · %s"):format(tostring(d.version), tostring(d.build), tostring(d.toc), tostring(d.locale)),
        ("Screen %s · UI scale %s · icons: %s%s"):format(tostring(d.screen), tostring(d.uiScale), ns.Icons:Source(),
            ns.Icons.game and " (game icons in use)" or ""),
        ("Media %d/%d loaded · %s"):format((d.total or 0) - (d.failed or 0), d.total or 0, mediaSummary(d)),
    }
    for _, r in ipairs(d.media or {}) do
        if not r.ok then
            lines[#lines + 1] = ("FAILED %s loaded=%s size=%s want=%s id=%s"):format(tostring(r.file), tostring(r.loaded),
                tostring(r.size), tostring(r.want), tostring(r.id))
        end
    end
    for i, g in ipairs(d.glyphs or {}) do
        if i > 8 then break end
        lines[#lines + 1] = ("glyph %s %s %s loaded=%s visible=%s alpha=%s"):format(tostring(g.name), tostring(g.file), tostring(g.size),
            tostring(g.loaded), tostring(g.visible), tostring(g.alpha))
    end
    return table.concat(lines, "\n")
end

local schema = {
    { type = "header", label = "DIAG_STATUS", icon = "diagnostics", wide = true },
    { type = "description", text = "DIAG_INTRO" },
    { type = "custom", label = "DIAG_LAST_RUN", build = valueRow(function()
        local d = last()
        if ns.Diag:IsRunning() then return L.DIAG_RUNNING, "state.info" end
        if not d then return L.DIAG_NEVER end
        return date("%Y-%m-%d %H:%M", d.time) .. (d.version ~= ns.version and ("  ·  " .. L.DIAG_OLD_VERSION) or "")
    end) },
    { type = "custom", label = "DIAG_MEDIA", build = valueRow(function()
        local d = last()
        if not d then return "–" end
        local ok = (d.total or 0) - (d.failed or 0)
        return L.DIAG_MEDIA_COUNT:format(ok, d.total or 0), (d.failed or 0) == 0 and "state.success" or "state.danger"
    end) },
    { type = "custom", label = "DIAG_CLIENT", build = valueRow(function()
        local d = last()
        local build, _, _, toc = GetBuildInfo()
        return ("%s  ·  %s  ·  %s"):format(d and d.build or build, d and d.toc or toc, d and d.locale or GetLocale())
    end) },
    { type = "custom", label = "DIAG_DISPLAY", build = valueRow(function()
        local d = last()
        if not d then return "–" end
        return L.DIAG_DISPLAY_VALUE:format(tostring(d.screen), tostring(d.uiScale))
    end) },
    { type = "button", label = "DIAG_RUN", desc = "DIAG_RUN_DESC", button = "DIAG_RUN_BUTTON", icon = "diagnostics",
      variant = "primary", func = function()
        ns.Diag:Run(false)
        update()
    end },
    { type = "header", label = "DIAG_ICONS", icon = "preview" },
    { type = "select", label = "DIAG_ICON_SOURCE", desc = "DIAG_ICON_SOURCE_DESC", default = "auto",
      values = {
          { value = "auto", label = "DIAG_ICONS_AUTO" }, { value = "phoenix", label = "DIAG_ICONS_PHOENIX" },
          { value = "game", label = "DIAG_ICONS_GAME" },
      },
      get = function() return ns.Icons:Source() end,
      set = function(_, v)
          ns.Icons:SetSource(v)
          update()
      end },
    { type = "custom", label = "DIAG_ICONS_NOW", build = valueRow(function()
        if ns.Icons.game then
            return ns.Icons:AtlasFailed() and L.DIAG_ICONS_GAME_FAILED or L.DIAG_ICONS_GAME, "state.warning"
        end
        return L.DIAG_ICONS_PHOENIX, "state.success"
    end) },
    { type = "header", label = "DIAG_FILES", icon = "textures" },
    { type = "custom", label = "DIAG_BY_KIND", build = valueRow(function()
        local d = last()
        return d and mediaSummary(d) or "–"
    end) },
    { type = "header", label = "DIAG_REPORT", icon = "copy", wide = true },
    { type = "description", text = "DIAG_REPORT_DESC" },
    { type = "custom", label = "DIAG_REPORT_TEXT", fullWidth = true, height = 196, build = function(row)
        local area = W:TextArea(row, 400, 140)
        updaters[#updaters + 1] = function() area:SetValue(report()) end
        return area
    end },
}

Config:RegisterPage("diagnostics", function(parent)
    local p = Config.BuildSchemaPage(parent, page, schema)
    p:HookScript("OnShow", update)
    ns.Events:Listen("PUI_DIAG_DONE", p, function() if p:IsShown() then update(); p:Refresh() end end)
    update()
    return p
end, { label = page.label, icon = page.icon, object = page, schema = schema })

Config.DiagReport = report
