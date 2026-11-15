local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Forever spellbook and talents (deferred D). The Forever client keeps the
-- classic SpellBookFrame (SpellButton1-12, skill-line tabs on the right,
-- bottom tab buttons) and the classic PlayerTalentFrame (Blizzard_TalentUI:
-- PlayerTalentFrameTalent1..N with a rank count). The catalog shell already
-- covers both windows; this file adds their Forever parts to the spellbook
-- window's extras. Rules as everywhere in skins: only Phoenix-owned textures
-- and font strings, Blizzard fonts and alpha recorded and reverted, Blizzard
-- update functions post-hooked (hooksecurefunc), nothing written into a
-- Blizzard table, out of combat. It runs only when PUI.IS_FOREVER is true and
-- the frame exists; retail keeps the PlayerSpellsFrame code in Extras2.lua.
local _, ns = ...
local SK = ns.SK
local C, X, Y = SK.Controls, SK.Extras, SK.Extras2
local Theme = PUI.Theme
local s = X.s
local On = X.On

local Z = { hooked = {}, tint = setmetatable({}, { __mode = "k" }) }
SK.Forever = Z
Z.SPELL_BUTTONS = 12
Z.SKILL_TABS = 8
Z.BOOK_TABS = 3
Z.MAX_TALENTS = 40

SK.EXTRA_DEFS.foreverRanks = { type = "toggle", default = true, mode = "simple", label = "Spell ranks (Forever)",
  tooltip = "Forever spellbook: the rank line under each spell name in the theme's muted colour (off: Blizzard's colour)." }
s.foreverRanks = true

local function G(name) local v = rawget(_G, name); if type(v) == "table" and v.GetObjectType then return v end end
Z.G = G
function Z.Wanted(frame) return PUI.IS_FOREVER == true and frame ~= nil and C.Usable(frame) end

-- hookGlobal(fname, id, fn): one post-hook on a Blizzard global function, live only while id is skinned.
local function hookGlobal(fname, id, fn)
  if Z.hooked[fname] then return true end
  if type(rawget(_G, fname)) ~= "function" then return false end
  Z.hooked[fname] = true
  hooksecurefunc(fname, function(...) if SK.applied[id] then securecallfunction(fn, ...) end end)
  return true
end
Z.HookGlobal = hookGlobal

-- RankText(subName) -> "Rank 3" style text from the spell's sub name, or "".
function Z.RankText(sub)
  if type(sub) ~= "string" or PUI.Secret.IsSecret(sub) then return "" end
  return sub
end
-- TalentState(rank, maxRank, desaturated) -> "max", "chosen", "open" or nil.
function Z.TalentState(rank, maxRank, desat)
  if type(rank) ~= "number" or type(maxRank) ~= "number" then return nil end
  if rank > 0 and rank >= maxRank then return "max" end
  if rank > 0 then return "chosen" end
  if not desat then return "open" end
end
local RING = { max = { "accent", 0.95 }, chosen = { "accent", 0.7 }, open = { "line", 0.5 } }

-- RankColour(id, fs, on): muted theme colour on the rank line; Blizzard's colour back when off or reverted.
function Z.RankColour(id, fs, on)
  local orig = Z.tint[fs]
  if on then
    if not orig then
      local r, g, b, a = fs:GetTextColor()
      orig = { r or 1, g or 1, b or 1, a or 1 }
      Z.tint[fs] = orig
      C.Own(id, function() Z.RankColour(id, fs, false) end)
    end
    local r, g, b = Theme:Color("muted")
    fs:SetTextColor(r or 0.6, g or 0.6, b or 0.6, 1)
  elseif orig then
    fs:SetTextColor(orig[1], orig[2], orig[3], orig[4])
    Z.tint[fs] = nil
  end
end

-- One classic spell button: Phoenix slot frame, fonts, rank line.
function Z.SpellButton(id, btn)
  local name = btn:GetName()
  if not name then return end
  C.Fade(id, G(name .. "SlotFrame"))
  local slot = C.Over(id, btn, "slot", "BACKGROUND", "Slot_Empty", -2)
  slot:ClearAllPoints(); slot:SetPoint("TOPLEFT", -3, 3); slot:SetPoint("BOTTOMRIGHT", 3, -3)
  local spell, sub = G(name .. "SpellName"), G(name .. "SubSpellName")
  if spell then SK.Font(id, spell, "body") end
  if sub then
    SK.Font(id, sub, "small")
    Z.RankColour(id, sub, On("foreverRanks"))
  end
end
function Z.SpellButtons(id)
  for i = 1, Z.SPELL_BUTTONS do local b = G("SpellButton" .. i); if b then Z.SpellButton(id, b) end end
end
function Z.Tabs(id)
  for i = 1, Z.SKILL_TABS do
    local t = G("SpellBookSkillLineTab" .. i)
    if t then local f = C.Over(id, t, "face", "BACKGROUND", "Slot_Empty", -2); f:ClearAllPoints(); f:SetPoint("TOPLEFT", -2, 2); f:SetPoint("BOTTOMRIGHT", 2, -2) end
  end
  for i = 1, Z.BOOK_TABS do
    local t = G("SpellBookFrameTabButton" .. i)
    if t then
      for _, r in ipairs({ t:GetRegions() }) do if r.GetObjectType and r:GetObjectType() == "Texture" then C.Fade(id, r) end end
      local f = C.Over(id, t, "face", "BACKGROUND", "Button_Normal"); f:ClearAllPoints(); f:SetAllPoints()
      local fs = t.GetFontString and t:GetFontString()
      if fs then SK.Font(id, fs, "body") end
    end
  end
end

-- One classic talent button: ring by state, Phoenix rank font.
function Z.TalentButton(id, btn, tab, index)
  local name = btn:GetName()
  local rankFS = name and G(name .. "Rank")
  if rankFS then SK.Font(id, rankFS, "small") end
  C.Fade(id, name and G(name .. "Slot"))
  local info = rawget(_G, "GetTalentInfo")
  if not info then return end
  local _, _, _, _, rank, maxRank = info(tab, index)
  local icon = name and G(name .. "IconTexture")
  local state = On("talentRings") and Z.TalentState(rank, maxRank, icon and icon.IsDesaturated and icon:IsDesaturated())
  local bag = C.over[btn]
  if not state then if bag and bag.ring then bag.ring:Hide() end return end
  local ring = C.Over(id, btn, "ring", "OVERLAY", "StatusOrb", 7)
  ring:ClearAllPoints(); ring:SetPoint("TOPLEFT", -4, 4); ring:SetPoint("BOTTOMRIGHT", 4, -4)
  Theme:Paint(ring, RING[state][1], RING[state][2], "vertex")
end
function Z.SelectedTab(frame)
  local get = rawget(_G, "PanelTemplates_GetSelectedTab")
  local t = get and get(frame)
  return type(t) == "number" and t or 1
end
function Z.Talents(id, frame)
  local tab = Z.SelectedTab(frame)
  local count = rawget(_G, "GetNumTalents")
  local n = count and count(tab) or 0
  if type(n) ~= "number" then n = 0 end
  for i = 1, math.min(n, Z.MAX_TALENTS) do
    local b = G("PlayerTalentFrameTalent" .. i)
    if b and b:IsShown() then Z.TalentButton(id, b, tab, i) end
  end
end

-- Window extra for the spellbook pack on Forever (frame is one of the pack's frames).
function Z.Extra(frame, id)
  if not Z.Wanted(frame) then return end
  local name = frame:GetName()
  if name == "SpellBookFrame" then
    local function run() Z.SpellButtons(id); Z.Tabs(id) end
    hookGlobal("SpellBookFrame_Update", id, run)
    hookGlobal("SpellButton_UpdateButton", id, function(btn) if btn and btn.GetName then Z.SpellButton(id, btn) end end)
    run()
  elseif name == "PlayerTalentFrame" then
    local function run() Z.Talents(id, frame) end
    hookGlobal("TalentFrame_Update", id, run)
    hookGlobal("PlayerTalentFrame_Update", id, run)
    run()
  end
end

-- Chain onto the spellbook window's extra (Extras2.lua) and its extras list.
local impl = SK.WINDOW_IMPL.spellbook
local retail = impl.extra
impl.extra = function(frame, arg, id)
  if retail then retail(frame, arg, id) end
  if PUI.IS_FOREVER then Z.Extra(frame, id) end
end
table.insert(SK.WINDOW_EXTRAS.spellbook, "foreverRanks")
