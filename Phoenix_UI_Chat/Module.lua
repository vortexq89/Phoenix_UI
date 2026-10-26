local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Chat module registration: loaded last so History.lua and Whisper.lua have
-- added their settings to the one schema first.
local _, ns = ...
local CH, Schema = ns.CH, PUI.Schema
local OWNER = "Chat"
local schema = CH.schema

local ckey, cdef = PUI.Coexist:Define("chat", { module = OWNER, job = "Chat",
  addons = { "Prat-3.0", "Chattynator", "Chatter", "Glass", "WIM", "BasicChatMods" } })
cdef.owner = OWNER
schema[ckey] = cdef

CH.module = PUI:RegisterModule(OWNER, {
  label = "Chat", tooltip = "Skinned Blizzard chat with keyword alerts, links, emoji, searchable history and whisper windows.",
  enabledByDefault = false, loadCondition = function() return PUI.Coexist:Allows("chat") end,
  schema = schema, onEnable = CH.OnEnable, onDisable = CH.OnDisable,
})
for k, def in pairs(schema) do if k:sub(1, 5) == "chat." then def.apply(Schema:Get(k)) end end
