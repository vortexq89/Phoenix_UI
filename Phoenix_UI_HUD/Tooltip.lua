local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Tooltip (plan 5.7, mockup 13): anchor (default corner or cursor, with
-- offsets), scale, hide in combat with a peek modifier, Phoenix skin with an
-- item-quality border (ColorManager, G40), health strip restyle, class-coloured
-- names, and info lines: guild and rank, target, Mythic+ score (colour from
-- PUI.Season) and best run, enemy forces from the shared forces provider
-- (Ascent owns forces data), who cast an aura, and mount collected.
-- One TooltipDataProcessor post-call per data type; never forces UberTooltips.
-- Values that may be secret are never compared or concatenated: a line is
-- built only from plain values, and secret text goes straight to a FontString.
-- IDs live in TooltipIDs.lua. Off by default.
local _, ns = ...
local Schema, Secret, Theme = PUI.Schema, PUI.Secret, PUI.Theme
local OWNER = "Tooltip"

local TT = { active = false, hooked = false }
ns.TT = TT
PUI.Tooltip = TT

local s = { anchor = "default", combat = "show", peek = "shift", guildRank = true, mplus = true, scale = 1, offsetX = 16, offsetY = 16,
  skin = true, bgAlpha = 0.92, qualityBorder = true, classNames = true, health = true, healthHeight = 6,
  target = true, bestRun = true, forces = true, auraSource = true, mountOwned = true }
TT.settings = s

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
TT.Plain = plain

------------------------------------------------------------------------------
-- Anchor and visibility
local CURSOR = { cursor = "ANCHOR_CURSOR", cursorLeft = "ANCHOR_CURSOR_LEFT", cursorRight = "ANCHOR_CURSOR_RIGHT" }
function TT.OnDefaultAnchor(tooltip, parent)
  if not TT.active then return end
  local a = CURSOR[s.anchor]
  if a then
    if a == "ANCHOR_CURSOR" then tooltip:SetOwner(parent, a)
    else tooltip:SetOwner(parent, a, a == "ANCHOR_CURSOR_LEFT" and -s.offsetX or s.offsetX, s.offsetY) end
  end
end

function TT.PeekDown()
  if s.peek == "shift" then return IsShiftKeyDown() end
  if s.peek == "ctrl" then return IsControlKeyDown() end
  if s.peek == "alt" then return IsAltKeyDown() end
  return false
end

function TT.OnShow(tooltip)
  if not TT.active then return end
  tooltip:SetScale(s.scale)
  if s.combat == "hide" and InCombatLockdown() and not TT.PeekDown() then tooltip:Hide(); return end
  TT.Skin(tooltip)
end

------------------------------------------------------------------------------
-- Skin: Phoenix panel behind the tooltip; Blizzard's NineSlice faded by alpha.
local skins = setmetatable({}, { __mode = "k" })
function TT.SkinFrame(tooltip)
  local k = skins[tooltip]
  if k then return k end
  k = CreateFrame("Frame", nil, tooltip)
  k:SetAllPoints()
  k:SetFrameLevel(math.max(0, tooltip:GetFrameLevel() - 1))
  k.bg = k:CreateTexture(nil, "BACKGROUND")
  k.bg:SetAllPoints()
  k.edges = Theme:Outline(k, "line2", 1)
  skins[tooltip] = k
  return k
end

-- PaintSkin(frame, r, g, b): the one paint path (real tooltips and the preview).
function TT.PaintSkin(k, r, g, b)
  local sr, sg, sb = Theme:Color("surface.1")
  k.bg:SetColorTexture(sr, sg, sb, s.bgAlpha)
  for _, e in pairs(k.edges or {}) do
    if r then e:SetColorTexture(r, g, b, 1) else e:SetColorTexture(Theme:Color("line2")) end
  end
end

function TT.Skin(tooltip, r, g, b)
  local ns9 = rawget(tooltip, "NineSlice")
  if not (TT.active and s.skin) then
    if skins[tooltip] then skins[tooltip]:Hide() end
    if ns9 and ns9.SetAlpha then ns9:SetAlpha(1) end
    return
  end
  local k = TT.SkinFrame(tooltip)
  TT.PaintSkin(k, r, g, b)
  k:Show()
  if ns9 and ns9.SetAlpha then ns9:SetAlpha(0) end
end

function TT.QualityColor(quality)
  if not plain(quality) or type(quality) ~= "number" then return nil end
  local cm = rawget(_G, "ColorManager")
  local c = cm and cm.GetColorDataForItemQuality and cm.GetColorDataForItemQuality(quality)
  if c and c.color then return c.color:GetRGB() end
  return nil
end

function TT.StyleHealth()
  local bar = rawget(_G, "GameTooltipStatusBar")
  if not bar then return end
  if not TT.active then bar:SetAlpha(1); return end
  bar:SetAlpha(s.health and 1 or 0)
  bar:SetHeight(s.healthHeight)
  bar:SetStatusBarTexture(PUI.Bars:TexturePath())
end

------------------------------------------------------------------------------
-- Info lines. UnitLines(info) is pure: the real tooltip and the preview build
-- the same lines from an info table.
--   info = { guild, rank, target, score, best = { level, name, timed }, forces }
function TT.UnitLines(info)
  local out = {}
  if s.guildRank and info.guild then
    out[#out + 1] = { info.rank and string.format("<%s> %s", info.guild, info.rank) or ("<" .. info.guild .. ">"), 0.4, 0.9, 0.4 }
  end
  if s.target and info.target then out[#out + 1] = { "Target: " .. info.target, 0.85, 0.85, 0.85 } end
  if s.mplus and info.score and info.score > 0 then
    local line = "Mythic+ score: " .. PUI.Season:ColoredScore(info.score)
    if s.bestRun and info.best then
      line = line .. string.format("  |cffb0b0b0best +%d %s%s|r", info.best.level, info.best.name, info.best.timed and "" or " (over time)")
    end
    out[#out + 1] = { line, 1, 0.82, 0 }
  end
  return out
end

local function bestRun(summary)
  local best
  for _, r in ipairs(type(summary) == "table" and summary.runs or {}) do
    local lvl = r.bestRunLevel
    if plain(lvl) and type(lvl) == "number" and (not best or lvl > best.level) then
      local d = PUI.Season:Dungeon(r.challengeModeID)
      best = { level = lvl, name = d and d.name or "", timed = r.finishedSuccess == true }
    end
  end
  return best
end
TT.BestRun = bestRun

function TT.UnitInfo(unit)
  local info = {}
  local guild, rank = GetGuildInfo(unit)
  if plain(guild) and guild and plain(rank) then info.guild, info.rank = guild, rank end
  local tname = UnitName(unit .. "target")
  if plain(tname) and tname then info.target = tname end
  local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
  local score = type(summary) == "table" and summary.currentSeasonScore
  if plain(score) and type(score) == "number" then info.score = score; info.best = bestRun(summary) end
  return info
end

local function nameLine(tooltip)
  local name = tooltip.GetName and tooltip:GetName()
  return type(name) == "string" and rawget(_G, name .. "TextLeft1") or nil
end

function TT.OnUnit(tooltip)
  if not TT.active then return end
  local _, unit = tooltip:GetUnit()
  if not plain(unit) or not unit then return end
  local isPlayer = UnitIsPlayer(unit)
  if plain(isPlayer) and isPlayer then
    if s.classNames then
      local _, class = UnitClass(unit)
      local c = plain(class) and class and RAID_CLASS_COLORS[class]
      local fs = nameLine(tooltip)
      if c and fs then fs:SetTextColor(c.r, c.g, c.b) end
    end
    for _, l in ipairs(TT.UnitLines(TT.UnitInfo(unit))) do tooltip:AddLine(l[1], l[2], l[3], l[4]) end
  elseif s.forces then
    -- Forces text from the shared provider (Ascent's data): may be secret, so it
    -- is handed to the tooltip's FontString as is, never read.
    local text = PUI.Season:UnitForces(unit)
    if text ~= nil then tooltip:AddDoubleLine("Enemy forces", text, 1, 0.82, 0, 1, 1, 1) end
  end
end

function TT.OnItem(tooltip, data)
  if not TT.active then return end
  local id = type(data) == "table" and data.id
  if not plain(id) or type(id) ~= "number" then return end
  if s.qualityBorder and s.skin then
    local _, _, quality = C_Item.GetItemInfo(id)
    local r, g, b = TT.QualityColor(quality)
    if r then TT.Skin(tooltip, r, g, b) end
  end
  if s.mountOwned then
    local mountID = C_MountJournal.GetMountFromItem(id)
    if plain(mountID) and type(mountID) == "number" and mountID > 0 then
      local collected = select(11, C_MountJournal.GetMountInfoByID(mountID))
      if plain(collected) then
        tooltip:AddLine(collected and "Mount: collected" or "Mount: not collected", collected and 0.4 or 1, collected and 0.9 or 0.4, 0.4)
      end
    end
  end
end

-- Aura source: "Cast by <name>" in the caster's class colour.
function TT.OnAura(tooltip, unit, auraInstanceID)
  if not (TT.active and s.auraSource) or not plain(auraInstanceID) then return end
  local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
  local src = type(aura) == "table" and aura.sourceUnit
  if not plain(src) or not src then return end
  local name = UnitName(src)
  if not plain(name) or not name then return end
  local _, class = UnitClass(src)
  local c = plain(class) and class and RAID_CLASS_COLORS[class]
  tooltip:AddLine("Cast by " .. name, c and c.r or 1, c and c.g or 1, c and c.b or 1)
  tooltip:Show()
end

local function hook()
  if TT.hooked then return end
  TT.hooked = true
  hooksecurefunc("GameTooltip_SetDefaultAnchor", TT.OnDefaultAnchor)
  GameTooltip:HookScript("OnShow", TT.OnShow)
  local types = Enum.TooltipDataType
  if types and TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(types.Item, function(tt, data) TT.OnItem(tt, data) end)
    TooltipDataProcessor.AddTooltipPostCall(types.Unit, function(tt) TT.OnUnit(tt) end)
  end
  for _, m in ipairs({ "SetUnitBuffByAuraInstanceID", "SetUnitDebuffByAuraInstanceID", "SetUnitAuraByAuraInstanceID" }) do
    if type(GameTooltip[m]) == "function" then hooksecurefunc(GameTooltip, m, TT.OnAura) end
  end
  ns.IDs.Hook()
end

------------------------------------------------------------------------------
-- Sample tooltip for the options preview (real line builders + real skin).
TT.SAMPLE_UNIT = { guild = "Phoenix Rising", rank = "Officer", target = "you", score = 3412,
  best = { level = 16, name = "Ara-Kara", timed = true } }

local schema = {}
TT.schema = schema
local function key(name, def, sub)
  def.owner = OWNER
  def.apply = function(value) s[sub or name] = value; if TT.active then TT.StyleHealth() end end
  def.searchTags = def.searchTags or { "tooltip" }
  schema["tt." .. name] = def
end
key("anchor", { type = "select", default = "default", choices = { "default", "cursor", "cursorLeft", "cursorRight" },
  choiceLabels = { default = "Default corner", cursor = "On the cursor", cursorLeft = "Left of the cursor", cursorRight = "Right of the cursor" },
  label = "Tooltip position", tooltip = "Default corner position (movable in Edit Mode) or following the cursor.", mode = "simple" })
key("offsetX", { type = "range", default = 16, min = -100, max = 100, step = 1, label = "Cursor offset X",
  tooltip = "Sideways distance from the cursor for the left/right cursor positions.", mode = "advanced" })
key("offsetY", { type = "range", default = 16, min = -100, max = 100, step = 1, label = "Cursor offset Y",
  tooltip = "Vertical distance from the cursor for the left/right cursor positions.", mode = "advanced" })
key("scale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Tooltip scale", tooltip = "Size of tooltips.", mode = "simple" })
key("combat", { type = "select", default = "show", choices = { "show", "hide" }, label = "Tooltips in combat",
  tooltip = "Show or hide tooltips while you are in combat.", mode = "simple" })
key("peek", { type = "select", default = "shift", choices = { "none", "shift", "ctrl", "alt" },
  choiceLabels = { none = "No peek key", shift = "Hold Shift", ctrl = "Hold Ctrl", alt = "Hold Alt" }, label = "Peek in combat",
  tooltip = "When tooltips are hidden in combat, holding this key shows them anyway.", mode = "advanced" })
key("guildRank", { type = "toggle", default = true, label = "Guild and rank", tooltip = "Adds guild name and rank to player tooltips.", mode = "simple" })
key("mplus", { type = "toggle", default = true, label = "Mythic+ score", tooltip = "Adds the player's Mythic+ score, coloured by your M+ score colour setting.", mode = "simple" })
key("style.skin", { type = "toggle", default = true, label = "Phoenix tooltip style",
  tooltip = "Phoenix background and border on tooltips; off keeps Blizzard's look.", mode = "simple", searchTags = { "tooltip", "skin", "style" } }, "skin")
key("style.bgAlpha", { type = "range", default = 0.92, min = 0.3, max = 1, step = 0.02, label = "Tooltip background opacity",
  tooltip = "How solid the tooltip background is.", mode = "advanced" }, "bgAlpha")
key("style.qualityBorder", { type = "toggle", default = true, label = "Item quality border",
  tooltip = "Item tooltips get a border in the item's quality colour.", mode = "simple" }, "qualityBorder")
key("style.classNames", { type = "toggle", default = true, label = "Class-coloured names",
  tooltip = "Player names in their class colour.", mode = "simple" }, "classNames")
key("style.health", { type = "toggle", default = true, label = "Health strip",
  tooltip = "The health bar under unit tooltips.", mode = "advanced" }, "health")
key("style.healthHeight", { type = "range", default = 6, min = 2, max = 16, step = 1, label = "Health strip height",
  tooltip = "Height of the health bar under unit tooltips.", mode = "advanced" }, "healthHeight")
key("lines.target", { type = "toggle", default = true, label = "Target line", tooltip = "Who the player is targeting.", mode = "advanced" }, "target")
key("lines.bestRun", { type = "toggle", default = true, label = "Best Mythic+ run",
  tooltip = "Adds the highest key the player finished this season next to the score.", mode = "advanced" }, "bestRun")
key("lines.forces", { type = "toggle", default = true, label = "Enemy forces",
  tooltip = "In Mythic+, how much enemy forces an enemy is worth (data from the M+ tracker).", mode = "simple" }, "forces")
key("lines.auraSource", { type = "toggle", default = true, label = "Aura caster",
  tooltip = "Buff and debuff tooltips show who cast them.", mode = "advanced" }, "auraSource")
key("lines.mountOwned", { type = "toggle", default = true, label = "Mount collected",
  tooltip = "Mount items say whether you already have the mount.", mode = "advanced" }, "mountOwned")

TT.module = PUI:RegisterModule(OWNER, {
  label = "Tooltip", tooltip = "Tooltip position, style, info lines and IDs (28 kinds, click-free copy).", enabledByDefault = false,
  schema = schema,
  onEnable = function() TT.active = true; hook(); TT.StyleHealth() end,
  onDisable = function()
    TT.active = false
    TT.StyleHealth()
    TT.Skin(GameTooltip)
    GameTooltip:SetScale(1)
    ns.IDs.ClaimCopy(false)
  end,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
