local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Data Bars (plan 5.7, owners 1.O): up to four user bars, each an ordered list
-- of blocks laid out by an equal-width solver, plus the XP / reputation /
-- honor progress bar (Data Bars owns it; Action Bars only links here).
-- Gold and currencies are read from PUI.Wallet (Vault owns them), M+ score
-- colours from PUI.Season, coordinates follow the Minimap's coordinates owner.
-- Blocks refresh on one 1 s Ticker entry that exists only while a bar shows
-- blocks; the progress bar is event-driven. Off by default.
local _, ns = ...
local Schema, Layout, Ticker, Theme, Media, Secret = PUI.Schema, PUI.Layout, PUI.Ticker, PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "DataBars"

local DB = { active = false, bars = {} }
ns.DataBars = DB
PUI.DataBars = DB

local g = { goldStyle = "gold", textColor = "white", separators = true, clock24 = true }
DB.global = g

local function pct(a, b) if not b or b <= 0 then return 0 end return math.floor(a / b * 100 + 0.5) end
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

-- Block registry: text(arg) -> string; click(arg) optional; tip label.
local BLOCKS = {
  clock = { label = "Clock", text = function() return date(g.clock24 and "%H:%M" or "%I:%M %p") end, click = "ToggleCalendar" },
  fps = { label = "Frame rate", text = function() return string.format("%d fps", math.floor(GetFramerate())) end },
  latency = { label = "Latency (home / world)", text = function() local _, _, home, world = GetNetStats(); return string.format("%d / %d ms", home, world) end },
  location = { label = "Zone", text = function() return GetMinimapZoneText() end, click = "ToggleWorldMap" },
  coords = { label = "Coordinates", text = function()
    local MM = PUI.Minimap
    if not MM or not MM.CoordsAllowed() then return "" end
    return MM.Coords() or ""
  end },
  gold = { label = "Gold", text = function() return PUI.Wallet:Money(PUI.Wallet:Gold(), g.goldStyle) end, click = "ToggleAllBags" },
  session = { label = "Gold this session", text = function()
    local d = PUI.Wallet:Session()
    return (d >= 0 and "+" or "") .. PUI.Wallet:Money(d, "gold")
  end },
  currencies = { label = "Tracked currencies", text = function()
    local parts = {}
    for _, c in ipairs(PUI.Wallet:Watched()) do parts[#parts + 1] = BreakUpLargeNumbers(c.quantity) .. " " .. (c.name or "") end
    return table.concat(parts, "  ")
  end, click = "ToggleCharacter", clickArg = "TokenFrame" },
  currency = { label = "One currency (currency:ID)", text = function(arg)
    local c = PUI.Wallet:Currency(tonumber(arg))
    if not c then return "" end
    if c.max and c.max > 0 then return string.format("%s %s/%s", c.name, BreakUpLargeNumbers(c.quantity), BreakUpLargeNumbers(c.max)) end
    return c.name .. " " .. BreakUpLargeNumbers(c.quantity)
  end },
  bags = { label = "Free bag slots", text = function()
    local free = 0
    for bag = 0, 4 do free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return string.format("Bags %d", free)
  end, click = "ToggleAllBags" },
  durability = { label = "Lowest durability", text = function()
    local low
    for slot = 1, 18 do
      local cur, max = GetInventoryItemDurability(slot)
      if cur and max and max > 0 then local p = pct(cur, max); if not low or p < low then low = p end end
    end
    return string.format("Dur %d%%", low or 100)
  end, click = "ToggleCharacter", clickArg = "PaperDollFrame" },
  ilvl = { label = "Equipped item level", text = function() local _, equipped = GetAverageItemLevel(); return string.format("ilvl %.1f", equipped or 0) end },
  xp = { label = "Experience", text = function()
    local max = UnitXPMax("player")
    if not plain(max) or max <= 0 then return "" end
    return string.format("XP %d%%", pct(UnitXP("player"), max))
  end },
  rep = { label = "Watched reputation", text = function()
    local d = C_Reputation.GetWatchedFactionData()
    if type(d) ~= "table" or not d.name then return "" end
    local span = (d.nextReactionThreshold or 0) - (d.currentReactionThreshold or 0)
    return string.format("%s %d%%", d.name, pct((d.currentStanding or 0) - (d.currentReactionThreshold or 0), span))
  end },
  honor = { label = "Honor level", text = function()
    local max = UnitHonorMax("player")
    if not plain(max) or max <= 0 then return "" end
    return string.format("Honor %d (%d%%)", UnitHonorLevel("player") or 0, pct(UnitHonor("player"), max))
  end },
  spec = { label = "Specialization", text = function()
    local spec = C_SpecializationInfo.GetSpecialization()
    local name = spec and select(2, C_SpecializationInfo.GetSpecializationInfo(spec))
    return name or ""
  end },
  mplus = { label = "Mythic+ score", text = function()
    local sum = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    local score = type(sum) == "table" and sum.currentSeasonScore
    if not plain(score) then return "" end
    return "M+ " .. PUI.Season:ColoredScore(score)
  end },
  friends = { label = "Friends online", text = function()
    local n = C_FriendList.GetNumOnlineFriends() or 0
    local _, bn = BNGetNumFriends()
    return string.format("Friends %d", n + (bn or 0))
  end, click = "ToggleFriendsFrame" },
  guild = { label = "Guild online", text = function()
    if not IsInGuild() then return "" end
    local _, online = GetNumGuildMembers()
    return string.format("Guild %d", online or 0)
  end, click = "ToggleGuildFrame" },
  mail = { label = "New mail", text = function() return HasNewMail() and "Mail" or "" end },
  vault = { label = "Great Vault", text = function() return C_WeeklyRewards.HasAvailableRewards() and "Vault ready" or "" end },
  volume = { label = "Master volume", text = function()
    local v = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0
    return string.format("Vol %d%%", math.floor(v * 100 + 0.5))
  end },
}
DB.BLOCKS = BLOCKS
local BLOCK_NAMES = {}
for k in pairs(BLOCKS) do BLOCK_NAMES[#BLOCK_NAMES + 1] = k end
table.sort(BLOCK_NAMES)
DB.BLOCK_NAMES = BLOCK_NAMES

-- Sample values for the options preview (same paint code as the real bars).
DB.SAMPLE = { clock = "21:42", fps = "144 fps", latency = "18 / 32 ms", location = "Silvermoon City", coords = "48.2, 61.7",
  gold = "123,456g", session = "+1,250g", currencies = "2,410 Valorstones", currency = "Valorstones 2,410/3,000", bags = "Bags 42",
  durability = "Dur 87%", ilvl = "ilvl 678.4", xp = "XP 64%", rep = "Silvermoon 40%", honor = "Honor 52 (18%)", spec = "Arms",
  mplus = "M+ 3,412", friends = "Friends 8", guild = "Guild 23", mail = "Mail", vault = "Vault ready", volume = "Vol 60%" }

local cfg = {
  { blocks = "clock,fps,latency,durability,gold", width = 480, height = 20, fontSize = 12, bgAlpha = 0.8, fill = false, mouseover = false, pos = { "BOTTOM", 0, 2 } },
  { blocks = "", width = 480, height = 20, fontSize = 12, bgAlpha = 0.8, fill = false, mouseover = false, pos = { "TOP", 0, -2 } },
  { blocks = "", width = 360, height = 20, fontSize = 12, bgAlpha = 0.8, fill = false, mouseover = false, pos = { "BOTTOMLEFT", 2, 2 } },
  { blocks = "", width = 360, height = 20, fontSize = 12, bgAlpha = 0.8, fill = false, mouseover = false, pos = { "BOTTOMRIGHT", -2, 2 } },
}
DB.cfg = cfg

-- Parse("clock, currency:3008, nope") -> { {name="clock"}, {name="currency", arg="3008"} }
function DB.Parse(text)
  local list = {}
  for token in (text or ""):gmatch("[^,%s]+") do
    local name, arg = token:match("^(%a+):(.+)$")
    name = name or token
    if BLOCKS[name] then list[#list + 1] = { name = name, arg = arg } end
  end
  return list
end

-- Equal-width solver: n blocks share the bar width.
function DB.Solve(width, n)
  if n <= 0 then return {} end
  local w = width / n
  local out = {}
  for i = 1, n do out[i] = { x = (i - 1) * w, w = w } end
  return out
end

local function textColor()
  if g.textColor == "class" then
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
  elseif g.textColor == "accent" then
    return Theme:Color("accent")
  end
  return 1, 1, 1
end

function DB.BlockText(entry)
  local b = BLOCKS[entry.name]
  return b and b.text(entry.arg) or ""
end

-- PaintBar(frame, list, c, sample): the one paint path (real bars and preview).
function DB.PaintBar(b, list, c, sample)
  local width = c.fill and UIParent:GetWidth() or c.width
  b:SetSize(width, c.height)
  b.bg = rawget(b, "bg") or b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  local r, gg, bl = Theme:Color("surface.1")
  b.bg:SetColorTexture(r, gg, bl, c.bgAlpha)
  b.cells = rawget(b, "cells") or {}
  b.seps = rawget(b, "seps") or {}
  b.list = list
  local slots = DB.Solve(width, #list)
  local tr, tg, tb = textColor()
  for j, slot in ipairs(slots) do
    local cell = b.cells[j]
    if not cell then
      cell = b:CreateFontString(nil, "OVERLAY")
      cell:SetFontObject(Media:FontObject("number"))
      cell:SetJustifyH("CENTER")
      b.cells[j] = cell
    end
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", b, "LEFT", slot.x, 0)
    cell:SetWidth(slot.w)
    local font, _, flags = cell:GetFont()
    if font then cell:SetFont(font, c.fontSize, flags) end
    cell:SetTextColor(tr, tg, tb)
    if sample then cell:SetText(DB.SAMPLE[list[j].name] or list[j].name) end
    cell:Show()
    local sep = b.seps[j]
    if j > 1 then
      if not sep then sep = b:CreateTexture(nil, "ARTWORK"); b.seps[j] = sep end
      sep:ClearAllPoints()
      sep:SetSize(1, c.height - 6)
      sep:SetPoint("LEFT", b, "LEFT", slot.x, 0)
      sep:SetColorTexture(1, 1, 1, 0.15)
      sep:SetShown(g.separators)
    end
  end
  for j = #slots + 1, #b.cells do b.cells[j]:Hide() end
  for j = #slots + 1, #b.seps do if b.seps[j] then b.seps[j]:Hide() end end
end

local function onClick(bar, button)
  if InCombatLockdown() then return end
  local x = select(1, GetCursorPosition()) / (bar:GetEffectiveScale() or 1) - (bar:GetLeft() or 0)
  local slots = DB.Solve(bar:GetWidth(), #bar.list)
  for j, slot in ipairs(slots) do
    if x >= slot.x and x < slot.x + slot.w then
      local blk = BLOCKS[bar.list[j].name]
      if blk and blk.run then blk.run(bar.list[j].arg, bar, button); return end
      if button ~= "LeftButton" then return end
      local fn = blk and blk.click and PUI.Minimap and PUI.Minimap.Resolve(blk.click)
      if type(fn) == "function" then if blk.clickArg then fn(blk.clickArg) else fn() end end
      return
    end
  end
end
DB.OnClick = onClick

local function bar(i)
  local b = DB.bars[i]
  if b then return b end
  b = PUI:CreateFrame("Button", "PhoenixUI_DataBar" .. i, UIParent, nil, OWNER)
  Theme:Backdrop(b, "surface.1")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) if cfg[i].mouseover then self:SetAlpha(1) end end)
  b:SetScript("OnLeave", function(self) if cfg[i].mouseover then self:SetAlpha(0) end end)
  b.cells = {}
  DB.bars[i] = b
  return b
end

function DB.Update()
  for _, b in pairs(DB.bars) do
    if b:IsShown() then
      for j, cell in ipairs(b.cells) do
        local entry = b.list[j]
        if entry then cell:SetText(DB.BlockText(entry)) end
      end
    end
  end
end

function DB.Layout(i)
  local c = cfg[i]
  local list = DB.Parse(c.blocks)
  if not DB.active or #list == 0 then
    local old = DB.bars[i]
    if old then old.list = {}; old:Hide() end
    return
  end
  local b = bar(i)
  DB.PaintBar(b, list, c)
  Layout:Place(b, "db.bar" .. i)
  b:SetAlpha(c.mouseover and 0 or 1)
  b:Show()
end

------------------------------------------------------------------------------
-- XP / reputation / honor progress bar (owner: Data Bars).
local P = { enabled = false, mode = "auto", width = 480, height = 8, text = "percent", rested = true,
  xpColor = { r = 0.58, g = 0.24, b = 0.86, a = 1 }, repColor = { r = 0.2, g = 0.75, b = 0.35, a = 1 }, honorColor = { r = 0.95, g = 0.45, b = 0.1, a = 1 } }
DB.progress = P

-- Which kind the bar shows now: xp below max level, else watched rep, else honor.
function DB.ProgressKind()
  if P.mode ~= "auto" then return P.mode end
  local max = UnitXPMax("player")
  if plain(max) and max > 0 and not (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel()) then return "xp" end
  if type(C_Reputation.GetWatchedFactionData()) == "table" then return "rep" end
  return "honor"
end

-- Values for a kind: cur, max, rested (passed to the StatusBar untouched).
function DB.ProgressValues(kind)
  if kind == "xp" then return UnitXP("player"), UnitXPMax("player"), GetXPExhaustion() end
  if kind == "rep" then
    local d = C_Reputation.GetWatchedFactionData()
    if type(d) ~= "table" then return 0, 1 end
    return (d.currentStanding or 0) - (d.currentReactionThreshold or 0), math.max(1, (d.nextReactionThreshold or 1) - (d.currentReactionThreshold or 0))
  end
  return UnitHonor("player"), UnitHonorMax("player")
end

function DB.ProgressText(cur, max)
  if P.text == "none" or not plain(cur) or not plain(max) or max <= 0 then return "" end
  if P.text == "percent" then return string.format("%d%%", pct(cur, max)) end
  local v = PUI.Format.Number(cur) .. " / " .. PUI.Format.Number(max)
  if P.text == "value" then return v end
  return string.format("%s  (%d%%)", v, pct(cur, max))
end

-- PaintProgress(bar, kind, cur, max, rested): shared by the real bar and the preview.
function DB.PaintProgress(pb, kind, cur, max, rested)
  pb:SetSize(P.width, P.height)
  pb:SetStatusBarTexture(PUI.Bars:TexturePath())
  local c = (kind == "xp" and P.xpColor) or (kind == "rep" and P.repColor) or P.honorColor
  pb:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
  pb:SetMinMaxValues(0, max or 1)
  pb:SetValue(cur or 0)
  pb.text:SetText(DB.ProgressText(cur, max))
  pb.rested:SetShown(P.rested and kind == "xp" and plain(rested) and type(rested) == "number" and rested > 0)
end

local function progressBar()
  if DB.pbar then return DB.pbar end
  local pb = PUI:CreateFrame("StatusBar", "PhoenixUI_ProgressBar", UIParent, nil, OWNER)
  pb.bg = pb:CreateTexture(nil, "BACKGROUND")
  pb.bg:SetAllPoints()
  pb.bg:SetColorTexture(0, 0, 0, 0.6)
  pb.rested = pb:CreateTexture(nil, "ARTWORK")
  pb.rested:SetPoint("TOPRIGHT")
  pb.rested:SetPoint("BOTTOMRIGHT")
  pb.rested:SetWidth(2)
  pb.rested:SetColorTexture(0.3, 0.55, 1, 0.8)
  pb.text = pb:CreateFontString(nil, "OVERLAY")
  pb.text:SetFontObject(Media:FontObject("small"))
  pb.text:SetPoint("CENTER")
  DB.pbar = pb
  return pb
end

function DB.RefreshProgress()
  if not (DB.active and P.enabled) then
    if DB.pbar then DB.pbar:Hide() end
    return
  end
  local pb = progressBar()
  local kind = DB.ProgressKind()
  DB.PaintProgress(pb, kind, DB.ProgressValues(kind))
  Layout:Place(pb, "db.progress")
  pb:Show()
end

function DB.Refresh()
  local any = false
  for i = 1, #cfg do
    DB.Layout(i)
    if DB.bars[i] and #DB.bars[i].list > 0 and DB.bars[i]:IsShown() then any = true end
  end
  if any and not Ticker:IsRegistered("db.update") then Ticker:Register("db.update", 1, DB.Update, OWNER)
  elseif not any and Ticker:IsRegistered("db.update") then Ticker:Unregister("db.update") end
  if any then DB.Update() end
  DB.RefreshProgress()
end

------------------------------------------------------------------------------
-- Settings
local schema = {}
DB.schema = schema
local NAMES_HELP = table.concat(BLOCK_NAMES, ", ")
for i, c in ipairs(cfg) do
  local function key(name, def)
    def.owner = OWNER
    def.apply = function(value) c[name] = value; DB.Refresh() end
    def.searchTags = { "data bar", "databar", "info bar", "broker" }
    schema["db.bar" .. i .. "." .. name] = def
  end
  local L = "Data bar " .. i .. " "
  key("blocks", { type = "text", default = c.blocks, label = L .. "blocks",
    tooltip = "Comma-separated blocks in order; empty hides the bar. Use currency:ID for one currency. Blocks: " .. NAMES_HELP .. ".", mode = "simple" })
  key("width", { type = "range", default = c.width, min = 100, max = 1920, step = 1, label = L .. "width",
    tooltip = "Width of the bar; blocks share it equally.", mode = "advanced" })
  key("height", { type = "range", default = c.height, min = 12, max = 40, step = 1, label = L .. "height",
    tooltip = "Height of the bar.", mode = "advanced" })
  key("fill", { type = "toggle", default = false, label = L .. "full screen width",
    tooltip = "Stretches the bar across the whole screen.", mode = "simple" })
  key("fontSize", { type = "range", default = 12, min = 8, max = 20, step = 1, label = L .. "text size",
    tooltip = "Font size of the blocks.", mode = "advanced" })
  key("bgAlpha", { type = "range", default = 0.8, min = 0, max = 1, step = 0.05, label = L .. "background opacity",
    tooltip = "0 makes the bar background invisible.", mode = "advanced" })
  key("mouseover", { type = "toggle", default = false, label = L .. "show on mouse-over only",
    tooltip = "The bar stays invisible until you point at it.", mode = "advanced" })
  Layout:RegisterElement("db.bar" .. i, { label = "Data bar " .. i, owner = OWNER, size = { c.width, c.height },
    default = { point = c.pos[1], x = c.pos[2], y = c.pos[3] } })
end
local function gkey(k, field, def)
  def.owner = OWNER
  def.apply = function(v) g[field] = v; DB.Refresh() end
  def.searchTags = { "data bar", "databar", "gold", "clock" }
  schema[k] = def
end
gkey("db.style.gold", "goldStyle", { type = "select", default = "gold", choices = { "gold", "full", "icons" },
  choiceLabels = { gold = "Gold only (123,456g)", full = "Gold, silver, copper", icons = "Coin icons" },
  label = "Gold display", tooltip = "How the gold block shows money.", mode = "simple" })
gkey("db.style.textColor", "textColor", { type = "select", default = "white", choices = { "white", "class", "accent" },
  choiceLabels = { white = "White", class = "Class colour", accent = "Accent colour" }, label = "Block text colour",
  tooltip = "Colour of every block's text.", mode = "simple" })
gkey("db.style.separators", "separators", { type = "toggle", default = true, label = "Separators between blocks",
  tooltip = "Thin lines between blocks.", mode = "advanced" })
gkey("db.style.clock24", "clock24", { type = "toggle", default = true, label = "24-hour clock block",
  tooltip = "The clock block uses 24-hour time.", mode = "advanced" })

local function pkey(field, def)
  def.owner = OWNER
  def.apply = function(v) P[field] = v; DB.RefreshProgress() end
  def.searchTags = { "experience", "xp", "reputation", "honor", "progress" }
  schema["db.progress." .. field] = def
end
pkey("enabled", { type = "toggle", default = false, label = "XP / reputation / honor bar",
  tooltip = "A progress bar for experience, your watched reputation or honor. Data Bars owns this bar.", mode = "simple" })
pkey("mode", { type = "select", default = "auto", choices = { "auto", "xp", "rep", "honor" },
  choiceLabels = { auto = "Automatic (XP, then reputation, then honor)", xp = "Experience", rep = "Watched reputation", honor = "Honor" },
  label = "Progress bar shows", tooltip = "Automatic shows experience until max level, then your watched reputation, then honor.", mode = "simple" })
pkey("text", { type = "select", default = "percent", choices = { "none", "percent", "value", "both" },
  choiceLabels = { none = "No text", percent = "Percent", value = "Current / max", both = "Both" }, label = "Progress bar text",
  tooltip = "Text on the progress bar.", mode = "advanced" })
pkey("width", { type = "range", default = 480, min = 100, max = 1920, step = 1, label = "Progress bar width", tooltip = "Width of the progress bar.", mode = "advanced" })
pkey("height", { type = "range", default = 8, min = 2, max = 30, step = 1, label = "Progress bar height", tooltip = "Height of the progress bar.", mode = "advanced" })
pkey("rested", { type = "toggle", default = true, label = "Rested marker", tooltip = "Marks rested experience on the bar.", mode = "advanced" })
pkey("xpColor", { type = "color", default = { r = 0.58, g = 0.24, b = 0.86, a = 1 }, label = "Experience colour", tooltip = "Fill colour for experience.", mode = "advanced" })
pkey("repColor", { type = "color", default = { r = 0.2, g = 0.75, b = 0.35, a = 1 }, label = "Reputation colour", tooltip = "Fill colour for reputation.", mode = "advanced" })
pkey("honorColor", { type = "color", default = { r = 0.95, g = 0.45, b = 0.1, a = 1 }, label = "Honor colour", tooltip = "Fill colour for honor.", mode = "advanced" })
Layout:RegisterElement("db.progress", { label = "XP / reputation bar", owner = OWNER, size = { 480, 8 }, default = { point = "BOTTOM", x = 0, y = 24 } })

DB.module = PUI:RegisterModule(OWNER, {
  label = "Data bars", tooltip = "Information bars (clock, FPS, latency, gold, currencies, durability, M+ score and more) and the XP / reputation / honor bar.", enabledByDefault = false,
  schema = schema,
  onEnable = function(mod)
    DB.active = true
    for _, ev in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "UPDATE_FACTION", "HONOR_XP_UPDATE", "PLAYER_LEVEL_UP" }) do
      mod:RegisterEvent(ev, DB.RefreshProgress)
    end
    DB.Refresh()
  end,
  onDisable = function() DB.active = false; DB.Refresh() end,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
PUI.Kernel:On("WALLET_MONEY", function() if DB.active then DB.Update() end end)
