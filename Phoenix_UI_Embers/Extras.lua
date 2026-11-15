local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers, deferred batch C:
--  * show/hide-all and reset hotkeys through the binding ledger (override
--    bindings owned by Phoenix, never the user's saved bindings).
--  * window snapping: windows 2-4 dock to the previous window (right or below)
--    so a set moves as one; off keeps each window on its own Studio mover.
--  * threat warning (the Forever threat meter's missing piece): a sound and a
--    flash when your threat on the target reaches a share you choose while
--    you are not the tank. Only plain (non-secret) values are compared.
local _, ns = ...
local EM = ns.EM
local Schema, Layout = PUI.Schema, PUI.Layout
local OWNER = EM.OWNER

local X = { s = { keyToggle = "", keyReset = "", snap = "none", snapGap = 2, warnAt = 0, warnSound = "None" }, hidden = false, warned = false }
EM.Extras = X
local s = X.s
local plain = EM.Plain or function(v) if PUI.Secret.IsSecret(v) then return nil end return v end

-- Hotkeys -------------------------------------------------------------------------------------
function X.ToggleAll()
  X.hidden = not X.hidden
  for _, w in ipairs(EM.windows) do
    if X.hidden then w.frame:Hide() elseif w.index <= EM.settings.windows and EM.active then w.frame:Show() end
  end
  return X.hidden
end
function X.Reset()
  C_DamageMeter.ResetAllCombatSessions()
  wipe(EM.graph)
  if EM.active then EM.RefreshWindows() end
end
local function clickButton(name, fn)
  local b = rawget(_G, name)
  if b then return b end
  b = PUI:CreateFrame("Button", name, UIParent, nil, OWNER)
  b:SetScript("OnClick", fn)
  return b
end
function X.ClaimKeys()
  PUI.Bindings:Release(OWNER)
  if not EM.active then return end
  if s.keyToggle ~= "" then
    clickButton("PhoenixUI_EmbersToggle", X.ToggleAll)
    PUI.Bindings:Claim(OWNER, s.keyToggle, { click = "PhoenixUI_EmbersToggle" })
  end
  if s.keyReset ~= "" then
    clickButton("PhoenixUI_EmbersReset", X.Reset)
    PUI.Bindings:Claim(OWNER, s.keyReset, { click = "PhoenixUI_EmbersReset" })
  end
end

-- Snapping --------------------------------------------------------------------------------------
function X.Snap()
  for i, w in ipairs(EM.windows) do
    if i == 1 or s.snap == "none" then
      Layout:Place(w.frame, "embers.window" .. i)
    else
      local prev = EM.windows[i - 1].frame
      w.frame:ClearAllPoints()
      if s.snap == "right" then w.frame:SetPoint("TOPLEFT", prev, "TOPRIGHT", s.snapGap, 0)
      else w.frame:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -s.snapGap) end
    end
  end
end

-- Threat warning -------------------------------------------------------------------------------
function X.CheckThreat()
  if not EM.active or s.warnAt <= 0 then return false end
  if not UnitExists("target") then X.warned = false; return false end
  local tanking, _, pct = UnitDetailedThreatSituation("player", "target")
  tanking, pct = plain(tanking), plain(pct)
  if type(pct) ~= "number" or tanking == nil then return false end
  if not tanking and pct >= s.warnAt then
    if not X.warned then
      X.warned = true
      if not PUI.Media:PlaySound(s.warnSound) then PUI.Media:Alert(SOUNDKIT.RAID_WARNING) end
      for _, w in ipairs(EM.windows) do if w.outline and w.outline.SetAlpha then w.outline:SetAlpha(1) end end
      return true
    end
  elseif pct < s.warnAt - 10 or tanking then
    X.warned = false
  end
  return false
end
X.events = CreateFrame("Frame")
X.events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_TARGET_CHANGED" then X.warned = false end
  X.CheckThreat()
end)
function X.Events()
  local on = EM.active and s.warnAt > 0
  for _, ev in ipairs({ "UNIT_THREAT_LIST_UPDATE", "PLAYER_TARGET_CHANGED" }) do
    if on then X.events:RegisterEvent(ev) else X.events:UnregisterEvent(ev) end
  end
end

local function sync()
  X.ClaimKeys()
  X.Events()
  if EM.active then X.Snap() end
end
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then X.hidden = false; sync() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then sync() end end)

local function key(name, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; sync() end
  def.searchTags = { "meter", "damage", "hotkey", "snap", "threat" }
  EM.schema["embers." .. name] = def
  Schema:Register("embers." .. name, def)
  s[field] = Schema:Get("embers." .. name)
end
key("keyToggle", "keyToggle", { type = "keybind", default = "", label = "Show/hide all windows key",
  tooltip = "A key that hides or shows every meter window. Empty means no key.", mode = "advanced" })
key("keyReset", "keyReset", { type = "keybind", default = "", label = "Reset meter key",
  tooltip = "A key that resets the meter data. Empty means no key.", mode = "advanced" })
key("snap", "snap", { type = "select", default = "none", choices = { "none", "right", "below" },
  choiceLabels = { none = "Each window on its own", right = "Dock to the right", below = "Dock below" }, label = "Window snapping",
  tooltip = "Windows 2-4 dock to the previous one, so moving window 1 moves the set.", mode = "simple" })
key("snapGap", "snapGap", { type = "range", default = 2, min = 0, max = 20, step = 1, label = "Snapped window gap",
  tooltip = "Space between docked windows.", mode = "advanced" })
key("threatWarn", "warnAt", { type = "range", default = 0, min = 0, max = 100, step = 5, label = "Threat warning at (%)",
  tooltip = "Plays a sound when your threat on your target reaches this share and you are not tanking. 0 turns it off.", mode = "simple" })
key("threatSound", "warnSound", { type = "select", default = "None", choices = function() return PUI.Media:List("sound") end, preview = "sound",
  label = "Threat warning sound", tooltip = "Sound for the threat warning (None uses the raid warning sound).", mode = "advanced" })
