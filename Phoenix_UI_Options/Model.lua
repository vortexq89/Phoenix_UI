local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Options model: turns the schema registry into pages, rows and search
-- results (PUI_V2 8, 18.2). No frames here, so it is fully unit-tested.
local Options = { rows = {} }
PUI.Options = Options
local Model = {}
Options.Model = Model
local Schema = PUI.Schema

-- Sidebar order; owners not listed follow alphabetically.
Model.PAGE_ORDER = { "Core", "Theme", "Options", "Studio", "Sentinel" }
Model.PAGE_LABEL = { Core = "General", Theme = "Theme & media", Options = "Options window", Studio = "Studio", Sentinel = "Sentinel" }

function Model.Mode()
  return Schema:Get("options.mode")
end

function Model.Visible(def, mode)
  if def.hidden then return false end
  return mode == "advanced" or def.mode == "simple"
end

local function pageRank(name)
  for i = 1, #Model.PAGE_ORDER do if Model.PAGE_ORDER[i] == name then return i end end
  return #Model.PAGE_ORDER + 1
end

-- { { name = owner, label = ..., keys = { ... } }, ... } for a mode.
function Model.Pages(mode)
  local byOwner, list = {}, {}
  for i = 1, #Schema.keys do
    local def = Schema.defs[Schema.keys[i]]
    if Model.Visible(def, mode) then
      local owner = def.owner or "Core"
      local page = byOwner[owner]
      if not page then
        page = { name = owner, label = Model.PAGE_LABEL[owner] or owner, keys = {} }
        byOwner[owner] = page
        list[#list + 1] = page
      end
      page.keys[#page.keys + 1] = def.key
    end
  end
  table.sort(list, function(a, b)
    local ra, rb = pageRank(a.name), pageRank(b.name)
    if ra ~= rb then return ra < rb end
    return a.name < b.name
  end)
  return list
end

function Model.Page(mode, name)
  local pages = Model.Pages(mode)
  for i = 1, #pages do if pages[i].name == name then return pages[i] end end
  return pages[1]
end

local function haystack(def)
  local parts = { def.key, def.label, def.tooltip, def.owner or "" }
  if def.searchTags then for i = 1, #def.searchTags do parts[#parts + 1] = def.searchTags[i] end end
  return table.concat(parts, " "):lower()
end

-- every character of needle appears in order in hay (fuzzy subsequence)
local function subsequence(hay, needle)
  local pos = 1
  for i = 1, #needle do
    pos = hay:find(needle:sub(i, i), pos, true)
    if not pos then return false end
    pos = pos + 1
  end
  return true
end

-- Search every visible key (both modes): whole-word hits rank first, then
-- substring, then fuzzy label matches. Returns a list of keys.
function Model.Search(query)
  query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then return {} end
  local scored = {}
  for i = 1, #Schema.keys do
    local def = Schema.defs[Schema.keys[i]]
    if not def.hidden then
      local hay, score = haystack(def), nil
      local all = true
      for word in query:gmatch("%S+") do
        if not hay:find(word, 1, true) then all = false end
      end
      if all then
        score = def.label:lower():find(query, 1, true) and 1 or 2
      elseif subsequence(def.label:lower(), query:gsub("%s+", "")) then
        score = 3
      end
      if score then scored[#scored + 1] = { key = def.key, score = score } end
    end
  end
  table.sort(scored, function(a, b)
    if a.score ~= b.score then return a.score < b.score end
    return a.key < b.key
  end)
  local out = {}
  for i = 1, #scored do out[i] = scored[i].key end
  return out
end

function Model.IsChanged(key)
  local def = Schema:Def(key)
  if not def or def.get then return false end
  return not Schema:IsDefault(key)
end

function Model.Choices(def)
  local c = def.choices
  if type(c) == "function" then c = c() end
  return c or {}
end

-- Display text of a value.
function Model.Format(def, value)
  if def.type == "toggle" then return value and "On" or "Off" end
  if def.type == "range" then
    local step = def.step or 1
    if step >= 1 then return string.format("%d", value) end
    if step >= 0.1 then return string.format("%.1f", value) end
    return string.format("%.2f", value)
  end
  return tostring(value)
end

-- Clamp and snap a slider value to the def's range and step.
function Model.Quantize(def, value)
  local step = def.step or 1
  local base = def.min or 0
  value = base + math.floor((value - base) / step + 0.5) * step
  if def.min and value < def.min then value = def.min end
  if def.max and value > def.max then value = def.max end
  return tonumber(string.format("%.4f", value))
end

-- Next/previous select choice (wraps).
function Model.Cycle(def, value, dir)
  local choices = Model.Choices(def)
  local n = #choices
  if n == 0 then return value end
  local idx = 1
  for i = 1, n do if choices[i] == value then idx = i end end
  return choices[(idx - 1 + (dir or 1)) % n + 1]
end

-- Applies a value from a widget: validated, live, never via /reload.
function Model.Commit(key, value)
  local def = Schema:Def(key)
  if not def then return false, "unknown setting" end
  if def.type == "range" then value = Model.Quantize(def, value) end
  local ok, why = Schema:Validate(def, value)
  if not ok then return false, why end
  if PUI.DB.DeepEqual(Schema:Get(key), value) then return true end
  Schema:Set(key, value)
  return true
end

function Model.ResetPage(mode, name)
  local page = Model.Page(mode, name)
  local n = 0
  if not page then return 0 end
  for i = 1, #page.keys do
    if Model.IsChanged(page.keys[i]) then Schema:Reset(page.keys[i]); n = n + 1 end
  end
  return n
end
