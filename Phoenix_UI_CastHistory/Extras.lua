local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cast History, deferred batch C:
--  * Masque: with Masque loaded, strip icons join a "Phoenix UI / Cast History"
--    group (its public Group / AddButton / RemoveButton calls); off removes them.
--  * Addon Compartment: Alt+click on Phoenix's own compartment entry shows
--    the Cast History test strip. Phoenix only registers one compartment entry
--    (the game has no call to remove an entry, so a separate one could not
--    follow its setting live).
--  * Embers link: a "Casts" button on Embers' spell breakdown shows that
--    player's recent casts (from this module's history) under the breakdown.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local CH, T, SR = ns.CH, ns.Tracker, ns.Strip
local OWNER = "CastHistory"
local s = CH.settings
local X = { masqued = {} }
CH.Extras = X

-- Masque -------------------------------------------------------------------------------------------
function X.MasqueGroup()
  if X.group ~= nil then return X.group or nil end
  local LS = rawget(_G, "LibStub")
  local msq = type(LS) == "table" and LS.GetLibrary and LS:GetLibrary("Masque", true)
  X.group = msq and msq:Group("Phoenix UI", "Cast History") or false
  return X.group or nil
end
function X.Skin(b)
  local g = s.masque and X.MasqueGroup()
  if g and not X.masqued[b] then g:AddButton(b, { Icon = b.tex }); X.masqued[b] = true
  elseif not s.masque and X.masqued[b] and X.group then X.group:RemoveButton(b); X.masqued[b] = nil end
end
function X.SkinAll()
  for _, st in pairs(SR.strips) do for _, b in ipairs(st.icons) do X.Skin(b) end end
  for _, b in ipairs(SR.pool) do X.Skin(b) end
end
local add = SR.Add
function SR.Add(unit, spellID, kind, st)
  local b = add(unit, spellID, kind, st)
  if b then X.Skin(b) end
  return b
end

-- Compartment (Alt+click on Phoenix's entry; Shift+click stays Sentinel's) -----------------------------
local click = PUI.Entry.Click
function PUI.Entry.Click(entry, button)
  if s.compartment and CH.active and IsAltKeyDown() then return X.ToggleTest() end
  return click(entry, button)
end
function X.ToggleTest()
  if X.testing then SR.ClearAll(); X.testing = false else CH.Test(); X.testing = true end
  return X.testing
end

-- Embers link ------------------------------------------------------------------------------------------
function X.UnitFor(d)
  if d.me then return "player" end
  local guid = d.guid
  if guid == nil or Secret.IsSecret(guid) then return nil end
  for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
    local g = UnitGUID(u)
    if g ~= nil and not Secret.IsSecret(g) and g == guid then return u end
  end
end
X.LINK_ICONS = 10
function X.ShowCasts(f, unit)
  local row = rawget(f, "phxCasts")
  if not row then
    row = CreateFrame("Frame", nil, f); row:SetSize(220, 22); row:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -4)
    row.icons = {}
    for i = 1, X.LINK_ICONS do
      local t = row:CreateTexture(nil, "ARTWORK"); t:SetSize(20, 20); t:SetPoint("LEFT", (i - 1) * 22, 0); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.icons[i] = t
    end
    row.empty = row:CreateFontString(nil, "OVERLAY"); row.empty:SetFontObject(PUI.Media:FontObject("small")); row.empty:SetPoint("LEFT")
    rawset(f, "phxCasts", row)
  end
  local hist = unit and T.History(unit) or {}
  local n = 0
  for i, t in ipairs(row.icons) do
    local h = hist[i]
    if h and h.id then n = n + 1; t:SetTexture(C_Spell.GetSpellTexture(h.id)); t:Show() else t:Hide() end
  end
  row.empty:SetText(n == 0 and (unit and "No casts recorded yet." or "Cast history covers you and your party.") or "")
  row:Show()
  return n
end
function X.HookEmbers()
  local Recap = PUI.Embers and PUI.Embers.Recap
  if X.hooked or not Recap then return false end
  X.hooked = true
  local show = Recap.ShowBreakdown
  function Recap.ShowBreakdown(w, d)
    show(w, d)
    local f = Recap.flyout
    if not f then return end
    local btn = rawget(f, "phxLink")
    if not btn then
      btn = CreateFrame("Button", nil, f); btn:SetSize(44, 16); btn:SetPoint("TOPRIGHT", -6, -6)
      btn.text = btn:CreateFontString(nil, "OVERLAY"); btn.text:SetFontObject(PUI.Media:FontObject("small")); btn.text:SetAllPoints(); btn.text:SetText("|cffe8a33dCasts|r")
      rawset(f, "phxLink", btn)
    end
    local row = rawget(f, "phxCasts")
    if row then row:Hide() end
    btn:SetScript("OnClick", function() X.ShowCasts(f, X.UnitFor(d)) end)
    btn:SetShown(CH.active and s.embersLink)
  end
  return true
end
PUI.Kernel:On("LOGIN", X.HookEmbers)

local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; if name == "masque" then X.SkinAll() end end
  CH.schema["ch." .. name] = def
  Schema:Register("ch." .. name, def)
  s[name] = Schema:Get("ch." .. name)
end
key("masque", { type = "toggle", default = true, label = "Masque skins", tooltip = "With Masque loaded, cast icons use the skin you pick for \"Phoenix UI: Cast History\" in Masque." })
key("compartment", { type = "toggle", default = true, label = "Alt+click in the addon menu", tooltip = "Alt+click Phoenix UI in the minimap addon menu to show or clear the Cast History test strip." })
key("embersLink", { type = "toggle", default = true, mode = "simple", label = "Casts button in Embers", tooltip = "Embers' spell breakdown gets a Casts button that shows that player's recent casts (you and your party)." })
