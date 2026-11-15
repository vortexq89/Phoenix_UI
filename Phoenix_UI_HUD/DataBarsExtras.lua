local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Data Bars, deferred batch B:
--  * LDB host: an "ldb:Name" block shows any LibDataBroker feed's text and
--    passes clicks to the feed (read through LibStub when another addon ships
--    it; Phoenix bundles no copy).
--  * Travel and profession blocks (hearth, prof1, prof2) clicked through
--    secure action buttons laid over their cells, placed out of combat only
--    and anchored to UIParent so the bar itself never becomes protected.
--  * Per-spec sets: each bar's block list can be saved per specialization and
--    switches with the spec (/pui dbspec save | clear).
local _, ns = ...
local DB = ns.DataBars
local Schema, CQ = PUI.Schema, PUI.CombatQueue
local OWNER = "DataBars"
local BLOCKS = DB.BLOCKS

local X = { secure = {}, spec = { on = false, sets = {} } }
DB.Extras = X
X.HEARTH = 6948

-- LDB host ---------------------------------------------------------------------------------
function X.Broker()
  local LS = rawget(_G, "LibStub")
  if type(LS) ~= "table" or type(LS.GetLibrary) ~= "function" then return nil end
  return LS:GetLibrary("LibDataBroker-1.1", true)
end
function X.Feed(name)
  local ldb = X.Broker()
  return ldb and name and ldb:GetDataObjectByName(name) or nil
end
function X.FeedNames()
  local ldb, out = X.Broker(), {}
  if ldb and ldb.DataObjectIterator then
    for name in ldb:DataObjectIterator() do out[#out + 1] = name end
  end
  table.sort(out)
  return out
end
BLOCKS.ldb = { label = "LibDataBroker feed (ldb:Name)", text = function(arg)
  local o = X.Feed(arg)
  if not o then return "" end
  local t = o.text or o.value or o.label or arg
  return type(t) == "string" and t or tostring(t)
end, run = function(arg, bar, button)
  local o = X.Feed(arg)
  if o and type(o.OnClick) == "function" then o.OnClick(bar, button) end
end }

-- Travel and professions ------------------------------------------------------------------------
local function professions()
  local fn = rawget(_G, "GetProfessions")
  if type(fn) ~= "function" then return nil, nil end
  return fn()
end
function X.Profession(n)
  local p = select(n, professions())
  if not p then return nil end
  local name, _, rank, max = GetProfessionInfo(p)
  if not name then return nil end
  return { name = name, rank = rank or 0, max = max or 0 }
end
local function profText(n)
  local p = X.Profession(n)
  if not p then return "" end
  return string.format("%s %d/%d", p.name, p.rank, p.max)
end
BLOCKS.hearth = { label = "Hearthstone (click to use)", secure = true, text = function()
  local where = GetBindLocation() or ""
  local start, dur = C_Container.GetItemCooldown(X.HEARTH)
  if start and dur and start > 0 and dur > 1.5 then
    local left = math.max(0, start + dur - GetTime())
    return string.format("%s %d:%02d", where, math.floor(left / 60), math.floor(left % 60))
  end
  return where
end }
BLOCKS.prof1 = { label = "First profession (click to open)", secure = true, text = function() return profText(1) end }
BLOCKS.prof2 = { label = "Second profession (click to open)", secure = true, text = function() return profText(2) end }
DB.SAMPLE.ldb, DB.SAMPLE.hearth, DB.SAMPLE.prof1, DB.SAMPLE.prof2 = "Broker 42", "Dornogal", "Blacksmithing 87/100", "Mining 100/100"
for _, n in ipairs({ "ldb", "hearth", "prof1", "prof2" }) do table.insert(DB.BLOCK_NAMES, n) end
table.sort(DB.BLOCK_NAMES)
for i in ipairs(DB.cfg) do
  local def = DB.schema["db.bar" .. i .. ".blocks"]
  if def then
    def.tooltip = "Comma-separated blocks in order; empty hides the bar. Use currency:ID for one currency and ldb:Name for a LibDataBroker feed. Blocks: "
      .. table.concat(DB.BLOCK_NAMES, ", ") .. "."
  end
end

-- Secure attributes for a secure block (nil when there is nothing to cast/use).
function X.Action(name)
  if name == "hearth" then
    if (C_Item.GetItemCount(X.HEARTH) or 0) > 0 then return { type = "item", item = "item:" .. X.HEARTH } end
    return nil
  end
  local n = name == "prof1" and 1 or name == "prof2" and 2 or nil
  local p = n and X.Profession(n)
  if p then return { type = "macro", macrotext = "/cast " .. p.name } end
  return nil
end

local function overlay(i, j)
  X.secure[i] = X.secure[i] or {}
  local o = X.secure[i][j]
  if o then return o end
  o = PUI:CreateFrame("Button", "PhoenixUI_DataBar" .. i .. "Secure" .. j, UIParent, "SecureActionButtonTemplate", OWNER)
  o:RegisterForClicks("AnyUp", "AnyDown")
  o:SetFrameStrata("MEDIUM")
  o:SetScript("OnEnter", function() local b = DB.bars[i]; if b and DB.cfg[i].mouseover then b:SetAlpha(1) end end)
  o:SetScript("OnLeave", function() local b = DB.bars[i]; if b and DB.cfg[i].mouseover then b:SetAlpha(0) end end)
  X.secure[i][j] = o
  return o
end

-- Place the overlays for bar i (out of combat only; queued otherwise).
function X.PlaceSecure(i)
  if InCombatLockdown() then CQ.Defer("db.secure" .. i, function() X.PlaceSecure(i) end); return end
  local b = DB.bars[i]
  local list = b and b:IsShown() and b.list or {}
  local used = {}
  local left, bottom = b and b:GetLeft(), b and b:GetBottom()
  local slots = DB.Solve(b and b:GetWidth() or 0, #list)
  for j, entry in ipairs(list) do
    local blk = BLOCKS[entry.name]
    local act = blk and blk.secure and left and X.Action(entry.name)
    if act then
      local o = overlay(i, j)
      o:SetAttribute("type", act.type)
      o:SetAttribute("item", act.item)
      o:SetAttribute("macrotext", act.macrotext)
      o:ClearAllPoints()
      o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left + slots[j].x, bottom)
      o:SetSize(slots[j].w, b:GetHeight())
      o:Show()
      used[j] = true
    end
  end
  for j, o in pairs(X.secure[i] or {}) do if not used[j] then o:Hide() end end
end

-- Per-spec sets ---------------------------------------------------------------------------------
function X.SpecID()
  if PUI.IS_FOREVER then return nil end
  local idx = C_SpecializationInfo.GetSpecialization()
  if not idx then return nil end
  local id = C_SpecializationInfo.GetSpecializationInfo(idx)
  return type(id) == "number" and id or nil
end
function X.BlocksFor(i)
  local base = DB.cfg[i].blocks
  if not X.spec.on then return base end
  local id = X.SpecID()
  local set = id and X.spec.sets[id]
  local v = set and set[i]
  if type(v) == "string" then return v end
  return base
end
function X.SaveSpec()
  local id = X.SpecID()
  if not id then return false end
  local sets = {}
  for k, v in pairs(Schema:Get("db.spec.sets") or {}) do sets[k] = v end
  local set = {}
  for i, c in ipairs(DB.cfg) do set[i] = c.blocks end
  sets[id] = set
  Schema:Set("db.spec.sets", sets)
  if not X.spec.on then Schema:Set("db.spec.on", true) end
  return true
end
function X.ClearSpec()
  local id = X.SpecID()
  if not id then return false end
  local sets = {}
  for k, v in pairs(Schema:Get("db.spec.sets") or {}) do if k ~= id then sets[k] = v end end
  Schema:Set("db.spec.sets", sets)
  return true
end

local baseLayout = DB.Layout
function DB.Layout(i)
  local c = DB.cfg[i]
  local saved = c.blocks
  c.blocks = X.BlocksFor(i)
  baseLayout(i)
  c.blocks = saved
  X.PlaceSecure(i)
end

X.events = CreateFrame("Frame")
if not PUI.IS_FOREVER then X.events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") end
X.events:RegisterEvent("SKILL_LINES_CHANGED")
X.events:SetScript("OnEvent", function(_, event, unit)
  if not DB.active then return end
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
  DB.Refresh()
end)

local function key(k, def)
  def.owner = OWNER
  def.searchTags = { "data bar", "databar", "spec", "specialization", "broker", "ldb" }
  DB.schema[k] = def
  Schema:Register(k, def)
  def.apply(Schema:Get(k))
end
key("db.spec.on", { type = "toggle", default = false, label = "Per-spec data bar blocks",
  tooltip = "Each specialization can keep its own block list for every bar (save one with /pui dbspec save). Specs without a saved set use the normal lists.",
  mode = "advanced", apply = function(v) X.spec.on = v == true; DB.Refresh() end })
key("db.spec.sets", { type = "layout", default = {}, label = "Saved per-spec blocks",
  tooltip = "The block lists saved for each specialization.", mode = "advanced",
  apply = function(v) X.spec.sets = type(v) == "table" and v or {}; DB.Refresh() end })

PUI.Slash:Register("dbspec", function(rest)
  if rest == "clear" then
    PUI.Slash.Print(X.ClearSpec() and "Data bars: this spec now uses the normal block lists." or "No specialization yet.")
  else
    PUI.Slash.Print(X.SaveSpec() and "Data bars: block lists saved for this spec." or "No specialization yet.")
  end
end, "[save|clear]: save the data bar blocks for this specialization, or clear them")
