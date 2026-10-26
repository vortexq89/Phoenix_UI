local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Coexist (plan 1.35, D-WT-COMPAT-1): the conflict notice. When another
-- addon that does the same job as a Phoenix module is loaded, Phoenix asks the
-- user which side keeps the job and changes nothing until they pick:
--   "ask"     (default) the Phoenix module stays dormant; the notice is shown
--   "phoenix" the Phoenix module runs; the other addon is turned off for the
--             next session (C_AddOns.DisableAddOn, never its settings)
--   "other"   the other addon keeps the job; the Phoenix module stays off
-- The choice is a normal setting (core.coexist.<id>) and can be changed at any
-- time on the module's page. Phoenix never writes another addon's settings.
--   key, def = Coexist:Define(id, { module = "ActionBars", job = "Action bars", addons = { "Bartender4", ... } })
--   Coexist:Allows(id) -> bool  (use as the module's loadCondition)
--   Coexist:Loaded(id) -> { names of the other addons that are loaded }
local Coexist = { entries = {}, order = {}, asked = {} }
PUI.Coexist = Coexist
local Schema = PUI.Schema

Coexist.CHOICES = { "ask", "phoenix", "other" }
Coexist.CHOICE_LABELS = { ask = "Ask me", phoenix = "Phoenix keeps the job", other = "The other addon keeps the job" }

function Coexist:Loaded(id)
  local e = self.entries[id]
  local out = {}
  if not e then return out end
  for _, name in ipairs(e.addons) do
    if C_AddOns.IsAddOnLoaded(name) then out[#out + 1] = name end
  end
  return out
end

function Coexist:Choice(id)
  local key = "core.coexist." .. id
  if not Schema:Def(key) then return "ask" end
  return Schema:Get(key)
end

-- True when the Phoenix module may run: nothing else loaded, or the user chose Phoenix.
function Coexist:Allows(id)
  if #self:Loaded(id) == 0 then return true end
  return self:Choice(id) == "phoenix"
end

-- Notice text for the dialog and the options readout.
function Coexist:Describe(id)
  local e = self.entries[id]
  local loaded = self:Loaded(id)
  if not e or #loaded == 0 then return nil end
  return table.concat(loaded, ", ") .. " also does " .. e.job:lower() .. ". Pick which one keeps the job; nothing changes until you pick."
end

local function reevaluate(e)
  if PUI.Modules[e.module] then PUI.Kernel:Evaluate(e.module) end
end

-- Applies a pick from the notice (or the setting): turning the other addon off
-- takes effect the next time the game loads addons.
function Coexist:Pick(id, choice)
  local e = self.entries[id]
  if not e then return false end
  Schema:Set("core.coexist." .. id, choice)
  return true
end

-- Define(id, spec) -> key, def: the module puts def into its own schema so
-- the choice lives (and is reset, searched, exported) with that module.
function Coexist:Define(id, spec)
  assert(type(id) == "string" and id ~= "", "Coexist:Define needs an id")
  assert(type(spec) == "table" and spec.module and spec.job and type(spec.addons) == "table", "Coexist:Define needs module, job, addons")
  local e = { id = id, module = spec.module, job = spec.job, addons = spec.addons }
  if not self.entries[id] then self.order[#self.order + 1] = id end
  self.entries[id] = e
  local def = { type = "select", default = "ask", choices = self.CHOICES, choiceLabels = self.CHOICE_LABELS,
    label = spec.job .. ": when another addon does this",
    tooltip = "When " .. table.concat(spec.addons, ", ") .. " is loaded, choose whether Phoenix or that addon keeps the job. "
      .. "Phoenix keeps it: the other addon is turned off from the next load. The other addon keeps it: this Phoenix module stays off.",
    mode = "simple", searchTags = { "conflict", "addon", "coexist", "bartender", "dominos" },
    apply = function(v)
      if v == "phoenix" then
        for _, name in ipairs(self:Loaded(id)) do C_AddOns.DisableAddOn(name) end
      end
      reevaluate(e)
    end }
  return "core.coexist." .. id, def
end

-- Shows one notice per entry per session for entries still on "ask" whose
-- Phoenix module the user turned on.
function Coexist:Notify()
  for _, id in ipairs(self.order) do
    local e = self.entries[id]
    local text = self:Describe(id)
    if text and not self.asked[id] and self:Choice(id) == "ask" and Schema:Def("module." .. e.module) and Schema:Get("module." .. e.module) then
      self.asked[id] = true
      PUI.Dialogs:Confirm({ title = "Phoenix UI: " .. e.job, text = text,
        accept = "Phoenix keeps it", cancel = "Keep " .. self:Loaded(id)[1],
        onAccept = function() self:Pick(id, "phoenix") end,
        onCancel = function() self:Pick(id, "other") end })
    end
  end
end

PUI.Kernel:On("DB_READY", function() if C_Timer then C_Timer.After(2, function() Coexist:Notify() end) end end)
