local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ascent end-of-run summary card: dungeon, level, time against the limit,
-- upgrade, score change, deaths, then one row per player with the columns the
-- user picked (damage, healing, kicks, deaths) from Embers' Overall session.
-- Values the game still hides are written as "-". Optional auto-close runs on
-- a Ticker job that exists only while the card is open.
local _, ns = ...
local AS, Theme, Media, Layout, Ticker = ns.AS, PUI.Theme, PUI.Media, PUI.Layout, PUI.Ticker
local OWNER = AS.OWNER
local Summary = { rows = {} }
ns.Summary = Summary
AS.Summary = Summary
local s = AS.settings

-- Columns in order: id, header, setting, meter.
Summary.COLUMNS = {
  { id = "damage", head = "Damage", key = "sumDamage", meter = "DamageDone" },
  { id = "healing", head = "Healing", key = "sumHealing", meter = "HealingDone" },
  { id = "kicks", head = "Kicks", key = "sumKicks", meter = "Interrupts" },
  { id = "deaths", head = "Deaths", key = "sumDeaths", meter = "Deaths" },
}

function Summary.Columns()
  local out = {}
  for _, c in ipairs(Summary.COLUMNS) do if s[c.key] then out[#out + 1] = c end end
  return out
end

-- Table data for a run: { header = "...", columns = {...}, rows = { { name, class, cells = {} } } }
function Summary.Build(run)
  local cols = Summary.Columns()
  local meters = {}
  for _, c in ipairs(cols) do meters[#meters + 1] = c.meter end
  local totals = PUI.Embers and PUI.Embers.Totals(meters) or {}
  local rows = {}
  for name, t in pairs(totals) do
    local cells = {}
    for i, c in ipairs(cols) do
      local v = t[c.meter]
      cells[i] = v and (c.id == "damage" or c.id == "healing") and PUI.Format.Number(v) or (v and tostring(math.floor(v + 0.5))) or "-"
    end
    rows[#rows + 1] = { name = name, class = t.class, me = t.me, cells = cells, sortv = t.DamageDone or 0 }
  end
  table.sort(rows, function(a, b) if a.sortv ~= b.sortv then return a.sortv > b.sortv end return a.name < b.name end)
  local result = run.onTime and string.format("|cff5ad16atimed +%d|r", run.upgrades or 1) or "|cffff6a5aover time|r"
  local header = string.format("%s +%d  %s  %s / %s", run.name or "?", run.level or 0, result, AS.Clock(run.time or 0), AS.Clock(run.limit or 0))
  local sub = string.format("Deaths %d%s%s", run.deaths or 0, run.scoreDelta and string.format("   Rating %+d", run.scoreDelta) or "",
    run.pb and "   |cffe8a33dPersonal best|r" or "")
  return { header = header, sub = sub, columns = cols, rows = rows }
end

local function fs(f, role)
  local t = f:CreateFontString(nil, "OVERLAY")
  t:SetFontObject(Media:FontObject(role))
  t:SetJustifyH("LEFT")
  return t
end

local function build()
  local f = Summary.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_AscentSummary", UIParent, nil, OWNER)
  f:SetSize(420, 120)
  f:SetFrameStrata("DIALOG")
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.7)
  f.title = fs(f, "header")
  f.title:SetPoint("TOPLEFT", 10, -8)
  f.sub = fs(f, "small")
  f.sub:SetPoint("TOPLEFT", 10, -28)
  f.heads = {}
  local close = PUI:CreateFrame("Button", nil, f, nil, OWNER)
  close:SetSize(18, 18)
  close:SetPoint("TOPRIGHT", -4, -4)
  close.text = fs(close, "body")
  close.text:SetPoint("CENTER")
  close.text:SetText("x")
  close:SetScript("OnClick", function() Summary.Hide() end)
  Layout:Place(f, "ascent.summary")
  Summary.frame = f
  return f
end

local NAME_W, COL_W = 130, 66
local function cell(pool, f, i)
  local t = pool[i]
  if not t then t = fs(f, "small"); pool[i] = t end
  t:Show()
  return t
end

function Summary.Show(run)
  if s.summary == "off" then return false end
  local data = Summary.Build(run)
  if s.summary == "chat" then PUI.Slash.Print(data.header .. "  " .. data.sub) return true end
  local f = build()
  f.title:SetText(data.header)
  f.sub:SetText(data.sub)
  local y = 50
  local heads = { "Name" }
  for _, c in ipairs(data.columns) do heads[#heads + 1] = c.head end
  for i, h in ipairs(heads) do
    local t = cell(f.heads, f, i)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", 10 + (i == 1 and 0 or NAME_W + (i - 2) * COL_W), -y)
    t:SetText("|cff9a9a9a" .. h .. "|r")
  end
  for i = #heads + 1, #f.heads do f.heads[i]:Hide() end
  local used = 0
  for r, row in ipairs(data.rows) do
    y = y + 16
    for i = 1, #heads do
      used = used + 1
      local t = cell(Summary.rows, f, used)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", 10 + (i == 1 and 0 or NAME_W + (i - 2) * COL_W), -y)
      if i == 1 then
        local cr, cg, cb = 1, 1, 1
        if PUI.Embers then cr, cg, cb = PUI.Embers.ClassColor(row.class) end
        t:SetTextColor(cr, cg, cb)
        t:SetText((row.me and "> " or "") .. row.name)
      else
        t:SetTextColor(0.9, 0.9, 0.9)
        t:SetText(row.cells[i - 1])
      end
    end
    if r >= 5 then break end
  end
  for i = used + 1, #Summary.rows do Summary.rows[i]:Hide() end
  f:SetSize(math.max(300, 20 + NAME_W + #data.columns * COL_W), y + 26)
  f:Show()
  Summary.data = data
  if s.summaryHide > 0 then
    Summary.left = s.summaryHide
    Ticker:Register("ascent.summary", 1, function()
      Summary.left = Summary.left - 1
      if Summary.left <= 0 then Summary.Hide() end
    end, OWNER)
  end
  return true
end

function Summary.Hide()
  Ticker:Unregister("ascent.summary")
  if Summary.frame then Summary.frame:Hide() end
end
