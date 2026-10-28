local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder, deferred batch C:
--  * Raider.IO filter words (rio, riomain) read from Raider.IO's public
--    GetProfile when that addon is loaded, and a realm-language badge on rows
--    ("samelang" filter word) from LibRealmInfo when another addon ships it.
--  * plugin sort hooks: GF.RegisterSort(name, help, fn) adds a filter/sort
--    word computed by another addon for every result.
--  * click-to-insert word list: the panel's Words button opens a list; a click
--    adds the word to this category's expression.
--  * Studio mover for the detached panel (element gf.panel).
-- Bosses down and cancel-oldest use two undocumented functions behind an
-- existence check: see Gaps.lua.
local _, ns = ...
local GF, Data, Expr, P = ns.GF, ns.Data, ns.Expr, ns.Panel
local Schema, Layout = PUI.Schema, PUI.Layout
local OWNER = "GroupFinder"
local s = GF.settings

local X = { sorts = {} }
GF.Extras = X

-- Raider.IO and realm language --------------------------------------------------------------------
function X.RIO(leader)
  local rio = rawget(_G, "RaiderIO")
  if type(rio) ~= "table" or type(rio.GetProfile) ~= "function" or not leader then return nil end
  local name, realm = leader:match("^([^%-]+)%-?(.*)$")
  -- securecallfunction: an error inside Raider.IO is reported, never ours to break on
  local profile = securecallfunction(rio.GetProfile, name, realm ~= "" and realm or GetNormalizedRealmName())
  if type(profile) ~= "table" then return nil end
  local m = profile.mythicKeystoneProfile
  if type(m) ~= "table" then return nil end
  return { score = tonumber(m.currentScore) or 0, main = tonumber(m.mainCurrentScore) or 0 }
end
function X.RealmLang(realm)
  local LS = rawget(_G, "LibStub")
  local lib = type(LS) == "table" and LS.GetLibrary and LS:GetLibrary("LibRealmInfo", true)
  if not (lib and realm) then return nil end
  local _, _, _, _, locale = lib:GetRealmInfo(realm)
  return type(locale) == "string" and locale or nil
end
X.LANG_BADGE = { deDE = "DE", frFR = "FR", esES = "ES", ruRU = "RU", itIT = "IT", ptBR = "PT", enGB = "EN", enUS = "EN", koKR = "KR", zhTW = "TW", zhCN = "CN" }

Expr.Define("rio", "leader's Raider.IO score (Raider.IO loaded)", "group")
Expr.Define("riomain", "leader's main character Raider.IO score (Raider.IO loaded)", "group")
Expr.Define("samelang", "leader's realm speaks your realm's language (LibRealmInfo loaded)", "group")

local vars = Data.Vars
function Data.Vars(resultID, declinedFn)
  local v, meta = vars(resultID, declinedFn)
  if not v then return v, meta end
  local r = X.RIO(meta.leader)
  v.rio, v.riomain = r and r.score or 0, r and r.main or 0
  local realm = meta.leader and meta.leader:match("%-(.+)$") or GetNormalizedRealmName()
  local theirs, mine = X.RealmLang(realm), X.RealmLang(GetNormalizedRealmName())
  meta.lang = theirs and X.LANG_BADGE[theirs] or nil
  v.samelang = theirs ~= nil and theirs == mine
  for name, sort in pairs(X.sorts) do
    local value = securecallfunction(sort.fn, resultID, v)
    v[name] = (type(value) == "number" or type(value) == "boolean") and value or 0
  end
  return v, meta
end

local text = GF.Text
function GF.Text(d)
  local out = text(d)
  local lang = s.regionBadge and d.meta and d.meta.lang
  if lang then out = "|cff9ad0ff[" .. lang .. "]|r " .. out end
  if s.rioScore and d.vars and (d.vars.rio or 0) > 0 then out = out .. "  |cffb0b0b0RIO " .. d.vars.rio .. "|r" end
  return out
end

-- Plugin sort words ---------------------------------------------------------------------------------
function X.RegisterSort(name, help, fn)
  assert(type(name) == "string" and name:match("^[%l_][%w_]*$"), "sort word must be a lower-case word")
  assert(type(fn) == "function", "sort word needs a function(resultID, vars)")
  assert(not Expr.names[name] or X.sorts[name], "'" .. name .. "' is already a filter word")
  X.sorts[name] = { fn = fn, help = help }
  Expr.Define(name, help or ("plugin word " .. name), "plugin")
  return true
end
function X.UnregisterSort(name)
  if not X.sorts[name] then return false end
  X.sorts[name] = nil
  Expr.Undefine(name)
  return true
end
GF.RegisterSort, GF.UnregisterSort = X.RegisterSort, X.UnregisterSort

-- Click-to-insert word list --------------------------------------------------------------------
function X.Insert(cat, word)
  local k = "gf." .. cat .. ".expr"
  if not Schema:Def(k) then return nil end
  local cur = Schema:Get(k) or ""
  local nextText = cur:match("^%s*$") and word or (cur .. " and " .. word)
  Schema:Set(k, nextText)
  return nextText
end
function X.Words(filter)
  local out = {}
  for _, name in ipairs(Expr.order) do
    if not filter or filter == "" or name:find(filter, 1, true) then out[#out + 1] = name end
  end
  return out
end
X.COLS, X.ROWS = 3, 14
function X.ShowWords()
  local host = P.frame
  if not host then return nil end
  local f = X.wordFrame
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIGroupFinderWords", host, nil, OWNER)
    f:SetSize(300, 20 + X.ROWS * 18)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.97)
    f.buttons = {}
    for i = 1, X.COLS * X.ROWS do
      local b = CreateFrame("Button", nil, f)
      b:SetSize(96, 16)
      b:SetPoint("TOPLEFT", 4 + ((i - 1) % X.COLS) * 98, -6 - math.floor((i - 1) / X.COLS) * 18)
      b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFontObject(PUI.Media:FontObject("small")); b.text:SetAllPoints()
      b:SetScript("OnClick", function(self) if self.word then X.Insert(GF.category or "dungeon", self.word); if GF.active then P.Update() end end end)
      b:SetScript("OnEnter", function(self)
        local d = self.word and Expr.names[self.word]
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.word); GameTooltip:AddLine(d.help, 0.8, 0.8, 0.8, true); GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.buttons[i] = b
    end
    X.wordFrame = f
  end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -4)
  local words = X.Words()
  for i, b in ipairs(f.buttons) do
    b.word = words[i]
    b.text:SetText(words[i] and ("|cffe8a33d" .. words[i] .. "|r") or "")
    b:SetShown(words[i] ~= nil)
  end
  if f:IsShown() and X.open then f:Hide(); X.open = false else f:Show(); X.open = true end
  return f
end
local build = P.Build
function P.Build()
  local f = build()
  if f and f.help and not X.hooked then
    X.hooked = true
    f.help:SetScript("OnClick", function() if IsShiftKeyDown() then P.ShowHelp() else X.ShowWords() end end)
  end
  return f
end

-- Studio mover for the detached panel -------------------------------------------------------
local pos = Schema:Get("gf.panelPos") or {}
Layout:RegisterElement("gf.panel", { label = "Group Finder panel (detached)", owner = OWNER, size = { 300, 420 },
  default = { point = pos.point or "CENTER", x = pos.x or 420, y = pos.y or 0 } })
local place = P.Place
function P.Place()
  place()
  if P.frame and s.dock == "detached" then Layout:Place(P.frame, "gf.panel") end
end

local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; if GF.active then GF.Refresh() end end
  GF.schema["gf." .. name] = def
  Schema:Register("gf." .. name, def)
  s[name] = Schema:Get("gf." .. name)
end
key("rioScore", { type = "toggle", default = true, label = "Raider.IO score on rows",
  tooltip = "With Raider.IO loaded, adds the leader's Raider.IO score to each row (filter words rio and riomain work either way)." })
key("regionBadge", { type = "toggle", default = true, label = "Realm language badge",
  tooltip = "Shows the leader's realm language ([DE], [FR] ...) when an addon with LibRealmInfo is loaded." })
