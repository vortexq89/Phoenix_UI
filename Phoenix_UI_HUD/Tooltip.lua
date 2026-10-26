local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Tooltip (PUI_V2 5.9): cursor or default anchor, hide in combat, spell and
-- item IDs, guild rank and Mythic+ score lines on player tooltips. Hooks are
-- post-hooks installed once on first enable and do nothing while the module is
-- off. Values that may be secret are never compared or concatenated: a line is
-- added only when Secret.IsSecret says the value is plain. Off by default.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local OWNER = "Tooltip"

local TT = { active = false, hooked = false }
ns.TT = TT
PUI.Tooltip = TT

local s = { anchor = "default", combat = "show", ids = true, guildRank = true, mplus = true }
TT.settings = s

local function plain(v) return type(v) ~= "nil" and not Secret.IsSecret(v) end

function TT.OnDefaultAnchor(tooltip, parent)
  if TT.active and s.anchor == "cursor" then tooltip:SetOwner(parent, "ANCHOR_CURSOR") end
end

function TT.OnShow(tooltip)
  if TT.active and s.combat == "hide" and InCombatLockdown() then tooltip:Hide() end
end

function TT.AddId(tooltip, data, label)
  if not (TT.active and s.ids) or type(data) ~= "table" then return end
  local id = data.id
  if plain(id) then tooltip:AddLine(string.format("%s ID: %d", label, id), 0.6, 0.6, 0.65) end
end

function TT.OnUnit(tooltip)
  if not TT.active then return end
  local _, unit = tooltip:GetUnit()
  if not plain(unit) then return end
  local isPlayer = UnitIsPlayer(unit)
  if not plain(isPlayer) or not isPlayer then return end
  if s.guildRank then
    local guild, rank = GetGuildInfo(unit)
    if plain(guild) and plain(rank) then tooltip:AddLine(string.format("<%s> %s", guild, rank), 0.4, 0.9, 0.4) end
  end
  if s.mplus then
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    local score = type(summary) == "table" and summary.currentSeasonScore
    if plain(score) and score > 0 then tooltip:AddLine(string.format("Mythic+ score: %d", score), 1, 0.5, 0.1) end
  end
end

local function hook()
  if TT.hooked then return end
  TT.hooked = true
  hooksecurefunc("GameTooltip_SetDefaultAnchor", TT.OnDefaultAnchor)
  GameTooltip:HookScript("OnShow", TT.OnShow)
  local types = Enum.TooltipDataType
  if types and TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(types.Spell, function(tt, data) TT.AddId(tt, data, "Spell") end)
    TooltipDataProcessor.AddTooltipPostCall(types.Item, function(tt, data) TT.AddId(tt, data, "Item") end)
    TooltipDataProcessor.AddTooltipPostCall(types.Unit, function(tt) TT.OnUnit(tt) end)
  end
end

local schema = {}
TT.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value end
  schema["tt." .. name] = def
end
key("anchor", { type = "select", default = "default", choices = { "default", "cursor" }, label = "Tooltip position",
  tooltip = "Default corner position or following the cursor.", mode = "simple" })
key("combat", { type = "select", default = "show", choices = { "show", "hide" }, label = "Tooltips in combat",
  tooltip = "Show or hide tooltips while you are in combat.", mode = "simple" })
key("ids", { type = "toggle", default = true, label = "Spell and item IDs", tooltip = "Adds the spell or item ID line.", mode = "advanced" })
key("guildRank", { type = "toggle", default = true, label = "Guild and rank", tooltip = "Adds guild name and rank to player tooltips.", mode = "advanced" })
key("mplus", { type = "toggle", default = true, label = "Mythic+ score", tooltip = "Adds the player's current Mythic+ score.", mode = "advanced" })

TT.module = PUI:RegisterModule(OWNER, {
  label = "Tooltip", tooltip = "Tooltip position, combat visibility and extra lines.", enabledByDefault = false,
  schema = schema,
  onEnable = function() TT.active = true; hook() end,
  onDisable = function() TT.active = false end,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
