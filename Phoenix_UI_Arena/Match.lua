local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Arena match info (plan 1.O "Arena match timer, dampening, Shadowsight"; the
-- Flow dampening row links here): one small header above the frames and the
-- post-match card.
--  * match time: C_PvP.GetActiveMatchDuration (restored after a reload);
--  * dampening: the Dampening aura on you; its value may be secret, so it goes
--    to the engine formatter;
--  * Shadowsight: the eyes spawn a set time after the gates open; the header
--    counts down to it, then says the eyes are up.
-- 1 Hz Ticker entry, registered only while a match is live (zero work outside
-- arenas). The card after a match lists both teams' specs, your rating
-- change, match time, trinket uses and the DR the game reported per enemy.
local _, ns = ...
local Secret, Ticker = PUI.Secret, PUI.Ticker
local ST = ns.State
local M = { live = false }
ns.Match = M
local OWNER = "Arena"
M.DAMPENING_AURA = 110310
M.SHADOWSIGHT_AT = 90

function M.Clock(sec)
  sec = math.max(0, math.floor(sec or 0))
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
function M.Duration()
  local d = C_PvP.GetActiveMatchDuration and C_PvP.GetActiveMatchDuration()
  if d == nil or Secret.IsSecret(d) then return nil end
  return d
end
function M.ShadowsightText(dur)
  if not dur then return nil end
  if dur < M.SHADOWSIGHT_AT then return "Shadowsight " .. M.Clock(M.SHADOWSIGHT_AT - dur) end
  return "Shadowsight up"
end

-- Header(fs, s): writes "Match 2:41 - Dampening 12% - Shadowsight 0:20".
function M.Paint(fs, s)
  if not fs then return end
  local dur = M.Duration()
  local parts = {}
  if s.matchTimer and dur then parts[#parts + 1] = "Match " .. M.Clock(dur) end
  if s.shadowsight then local t = M.ShadowsightText(dur); if t then parts[#parts + 1] = t end end
  local aura = s.dampening and C_UnitAuras.GetPlayerAuraBySpellID(M.DAMPENING_AURA)
  local value = aura and aura.points and aura.points[1]
  local head = table.concat(parts, "  -  ")
  if value ~= nil then
    fs:SetFormattedText("%s%sDampening %d%%", head, head ~= "" and "  -  " or "", value)
  else
    fs:SetText(head)
  end
end

function M.Start(fs, s)
  M.live = true
  M.fs, M.s = fs, s
  Ticker:Register("arena.match", 1, function() M.Paint(M.fs, M.s) end, OWNER)
  M.Paint(fs, s)
end
function M.Stop()
  M.live = false
  Ticker:Unregister("arena.match")
end

-- Card --------------------------------------------------------------------------
-- Collect(): the facts for the card (plain values only; secret numbers stay as
-- values for the widget's formatter).
function M.Collect(winner, duration)
  local me = C_PvP.GetScoreInfoByPlayerGuid and C_PvP.GetScoreInfoByPlayerGuid(UnitGUID("player"))
  local myFaction = me and me.faction
  local mine, theirs = {}, {}
  for i = 1, 10 do
    local info = C_PvP.GetScoreInfo(i)
    if not info then break end
    local side = (myFaction ~= nil and info.faction == myFaction) and mine or theirs
    side[#side + 1] = { name = info.name, class = info.classToken, spec = info.talentSpec }
  end
  local enemies = {}
  for _, unit in ipairs(ST.UNITS) do
    local u = ST.units[unit]
    if u and u.life ~= "none" then
      enemies[#enemies + 1] = { unit = unit, trinketUses = u.trinketUses, drCount = #u.drHistory }
    end
  end
  local won
  if winner ~= nil and not Secret.IsSecret(winner) and myFaction ~= nil then won = winner == myFaction end
  return { mine = mine, theirs = theirs, duration = duration, ratingChange = me and me.ratingChange, rating = me and me.rating,
    mmrChange = me and me.mmrChange, enemies = enemies, won = won }
end
function M.CardLines(c)
  local function comp(list)
    local t = {}
    for _, p in ipairs(list) do t[#t + 1] = (p.spec ~= nil and not Secret.IsSecret(p.spec) and p.spec ~= "" and p.spec or (p.class or "?")) end
    return #t > 0 and table.concat(t, " / ") or "-"
  end
  local head = (c.won == true and "Victory") or (c.won == false and "Defeat") or "Match over"
  if c.duration and not Secret.IsSecret(c.duration) then head = head .. "  " .. M.Clock(c.duration) end
  local out = { head, "Your team: " .. comp(c.mine), "Enemy team: " .. comp(c.theirs) }
  for i, e in ipairs(c.enemies) do
    out[#out + 1] = string.format("Enemy %d: trinket used %d x, DR reported %d x", i, e.trinketUses, e.drCount)
  end
  return out
end
function M.ShowCard(c, s)
  local f = M.card
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIArenaCard", UIParent, nil, OWNER)
    f:SetSize(340, 170)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.94)
    f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2)
    f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
    f.lines = {}
    f.rating = f:CreateFontString(nil, "OVERLAY"); f.rating:SetPoint("TOPRIGHT", -10, -10)
    f.close = CreateFrame("Button", nil, f); f.close:SetSize(60, 20); f.close:SetPoint("BOTTOMRIGHT", -8, 8)
    f.close.text = f.close:CreateFontString(nil, "OVERLAY"); f.close.text:SetPoint("CENTER"); f.close.text:SetText("Close")
    f.close.text:SetFontObject(PUI.Media:FontObject("small"))
    f.close:SetScript("OnClick", function() f:Hide() end)
    M.card = f
    PUI.Layout:Place(f, "arena.card")
  end
  local lines = M.CardLines(c)
  for i, text in ipairs(lines) do
    local fs = f.lines[i]
    if not fs then fs = f:CreateFontString(nil, "OVERLAY"); f.lines[i] = fs end
    fs:SetFontObject(PUI.Media:FontObject(i == 1 and "header" or "small"))
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 20)
    fs:SetText(text); fs:Show()
  end
  for i = #lines + 1, #f.lines do f.lines[i]:Hide() end
  f.rating:SetFontObject(PUI.Media:FontObject("header"))
  if c.ratingChange ~= nil and s.cardRating then f.rating:SetFormattedText("%+d rating", c.ratingChange) else f.rating:SetText("") end
  f:SetScale(s.cardScale or 1)
  f:Show()
  M.lastLines = lines
  return f
end
