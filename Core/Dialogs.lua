local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Dialogs (plan 1.26, 1.27, G5, G10): Phoenix's own confirm, keep/revert
-- and copy dialogs. Nothing enters Blizzard's StaticPopup list. The windows are
-- drawn by the options kit (load-on-demand); this file is the stable API.
--   Dialogs:Confirm{ title, text, accept, cancel, danger, onAccept, onCancel }
--   Dialogs:KeepOrRevert{ title, text, seconds, onKeep, onRevert }
--   Dialogs:Copy(title, text[, hint])
-- PUI.Links: "open this Phoenix page" chat links through Blizzard's addon
-- link type (|Haddon:PhoenixUI:...|h) and EventRegistry, never SetItemRef hooks.
local Dialogs = { queue = {} }
PUI.Dialogs = Dialogs

local function impl()
  if not (PUI.Options and PUI.Options.Dialogs) then PUI.OptionsHost:Load() end
  return PUI.Options and PUI.Options.Dialogs
end

local function checkSpec(spec, need)
  assert(type(spec) == "table", "dialog spec must be a table")
  for _, k in ipairs(need) do assert(spec[k] ~= nil, "dialog spec needs " .. k) end
end

function Dialogs:Confirm(spec)
  checkSpec(spec, { "title", "text" })
  local d = impl()
  if d then return d:Confirm(spec) end
end

-- Timed confirm for UI scale/layout swaps: reverts unless kept (G33 owned timer).
function Dialogs:KeepOrRevert(spec)
  checkSpec(spec, { "title", "onRevert" })
  spec.seconds = spec.seconds or 10
  local d = impl()
  if d then return d:KeepOrRevert(spec) end
end

function Dialogs:Copy(title, text, hint)
  assert(type(title) == "string", "Dialogs:Copy needs a title")
  local d = impl()
  if d then return d:Copy(title, tostring(text or ""), hint) end
end

function Dialogs:Paste(title, hint, onText)
  assert(type(onText) == "function", "Dialogs:Paste needs a callback")
  local d = impl()
  if d then return d:Paste(title, hint, onText) end
end

function Dialogs:Close()
  local d = PUI.Options and PUI.Options.Dialogs
  if d then d:Close() end
end

------------------------------------------------------------------------------
local Links = { handlers = {} }
PUI.Links = Links
local PREFIX = "PhoenixUI"

-- Link(action, arg, text) -> "|Haddon:PhoenixUI:action:arg|h[text]|h" (accent coloured).
function Links.Make(action, arg, text)
  assert(type(action) == "string" and action:match("^[%w_]+$"), "link action must be a word")
  arg = tostring(arg or ""):gsub("[|:]", "")
  local r, g, b = PUI.Theme:Color("accent")
  return string.format("|cff%02x%02x%02x|Haddon:%s:%s:%s|h[%s]|h|r", (r or 1) * 255, (g or 0.5) * 255, (b or 0.1) * 255,
    PREFIX, action, arg, tostring(text or action))
end

function Links:Register(action, fn)
  assert(type(fn) == "function", "Links:Register needs a handler")
  self.handlers[action] = fn
end

-- Parses "addon:PhoenixUI:action:arg" and runs the handler. Returns true when handled.
function Links:Handle(link)
  if type(link) ~= "string" then return false end
  local prefix, action, arg = link:match("^addon:([^:]+):([^:]+):?(.*)$")
  if prefix ~= PREFIX then return false end
  local fn = self.handlers[action]
  if not fn then return false end
  securecallfunction(fn, arg)
  return true
end

Links:Register("open", function(page) PUI.OptionsHost:OpenOptions(page ~= "" and page or nil) end)

if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("SetItemRef", function(_, link) Links:Handle(link) end, Links)
end
