local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Live previews for the deferred batch C settings: each page's own preview
-- gets a short block of sample lines drawn from the module's live settings
-- (and the module's own text helpers where it has them), at the card's foot.
-- Display only: sample values, no unit reads.
local Options = PUI.Options
local PX = Options.PreviewsExtras
local Theme = PUI.Theme

local function foot(card, owner, rows)
  local ar, ag, ab = Theme:Color("accent")
  local n = #rows
  for i = 1, 8 do
    local fs = PX.Line(card, owner .. "C" .. i)
    fs:ClearAllPoints()
    local r = rows[i]
    if r then
      fs:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 10 + (n - i) * 15)
      fs:SetText(r)
      if i == 1 then fs:SetTextColor(ar, ag, ab) else fs:SetTextColor(0.85, 0.85, 0.85) end
      fs:Show()
    else fs:Hide() end
  end
  return n
end
PX.Foot = foot
local function on(v) return v and "on" or "off" end

PX.extend("QuestTracker", function(card)
  local X = PUI.QuestTracker and PUI.QuestTracker.Extras
  local s = X and X.s
  if not s then return end
  foot(card, "qt", { "Quest items and sharing",
    "Item buttons: " .. on(s.items) .. (s.items and ("  (" .. tostring(s.itemSize) .. " px, left of each quest)") or ""),
    "Share new quests with the group: " .. on(s.autoShare) .. (s.autoShare and s.shareSkipDaily and "  (not daily or weekly)" or "") })
end)

PX.extend("Reminders", function(card)
  local X = PUI.Reminders and PUI.Reminders.Extras
  local s = X and X.s
  if not s then return end
  local n = 0
  for _ in pairs(s.zones or {}) do n = n + 1 end
  foot(card, "rm", { "Consumables, talents and overrides",
    "Weapon oil in instances: " .. on(s.oil) .. "   Season consumables: " .. on(s.consumables),
    "Talents by instance: " .. on(s.talents) .. "  (" .. n .. " saved)",
    "Sound and icon overrides: " .. #(s.overrides or {}) })
end)

PX.extend("Embers", function(card)
  local X = PUI.Embers and PUI.Embers.Extras
  local s = X and X.s
  if not s then return end
  foot(card, "em", { "Hotkeys, snapping and threat",
    "Snap windows: " .. tostring(s.snap) .. (s.snap ~= "none" and ("  gap " .. tostring(s.snapGap)) or ""),
    "Threat warning: " .. ((s.warnAt or 0) > 0 and (s.warnAt .. "%  ->  \"Threat 92%\"") or "off") })
end)

PX.extend("Ascent", function(card)
  local X = PUI.Ascent and PUI.Ascent.Extras
  local s = X and X.s
  if not s then return end
  local rows = { "Pull and score" }
  if s.pull then rows[#rows + 1] = "Enemy forces 62.0%  |  " .. tostring(X.PullText({ add = 8.5, after = 70.5 })) end
  if s.projection then rows[#rows + 1] = "Score if timed: " .. math.floor(X.Score(12, 0.8)) .. "  (best on this dungeon 285)" end
  rows[#rows + 1] = "/pui vaultplan: Slot 1 unlocked at +12, Slot 2: 3 more runs (1 of 4)"
  foot(card, "as", rows)
end)

PX.extend("Flow", function(card)
  local s = PUI.Flow and PUI.Flow.settings
  if not s then return end
  foot(card, "fl", { "More conveniences",
    "Leave prompt " .. on(s.leavePrompt) .. "   Open containers " .. on(s.openContainers) .. "   Train All " .. on(s.trainAll),
    "Hide tutorials " .. on(s.hideTutorials) .. "   Hide banners " .. on(s.hideBanners) .. "   /gg " .. on(s.gg) .. (s.gg and ("  \"" .. tostring(s.ggText) .. "\"") or ""),
    "Queue protection " .. on(s.queueProtect) .. (s.queueProtect and (" " .. s.queueProtectTime .. " s") or "") .. "   Tab binder " .. on(s.tabBinder) .. "   Screenshot " .. on(s.screenshot) })
end)

PX.extend("GroupFinder", function(card)
  local GF = PUI.GroupFinder
  local s = GF and GF.settings
  if not s then return end
  local row = (s.regionBadge and "|cff9ad0ff[DE]|r " or "") .. "+12 Ara-Kara  leader 2650" .. (s.rioScore and "  |cffb0b0b0RIO 2710|r" or "")
  foot(card, "gf", { "Raider.IO, realm language and words", row, "Words button: click a word to add it, Shift+click for help" })
end)

PX.extend("RaidTools", function(card)
  local RT = PUI.RaidTools
  local X = RT and RT.Extras
  if not X then return end
  local s = X.settings
  local lines = X.NotesFor("Dimensius", { "Dimensius: soak the left orb", "*: lust on pull" })
  foot(card, "rt", { "Notes, tooltip and stats window",
    "Notes window (" .. on(s.notes) .. "): " .. table.concat(lines, " / "),
    "Boss tooltip: " .. (s.bossTooltip and "Phoenix: 3 kills, 7 wipes, best 4:12" or "off"),
    "/pui statswin lists " .. s.statsRows .. " bosses with Export and reset" })
end)

PX.extend("Pulse", function(card)
  local PL = PUI.Pulse
  local X = PL and PL.Extras
  if not X then return end
  local s = X.settings
  local rows = { "Next abilities" .. (s.nextHud and "" or " (off)") }
  local sample = { { "Devouring Cosmos", 8 }, { "Mass Ejection", 14 }, { "Reverse Gravity", 21 }, { "Shattered Space", 33 }, { "Conqueror's Cross", 41 } }
  if s.nextHud then for i = 1, s.nextCount do rows[#rows + 1] = string.format("%-20s %d", sample[i][1], sample[i][2]) end end
  rows[#rows + 1] = "Blizzard timeline hidden: " .. on(s.hideBlizzard) .. "   Per-boss lines: " .. #(s.bossRules or {})
  foot(card, "pl", rows)
end)

PX.extend("Arena", function(card)
  local s = PUI.Arena and PUI.Arena.settings
  if not s then return end
  foot(card, "ar", { "Pets, auras, dispels and range",
    "Pet frames " .. on(s.pets) .. (s.pets and (" " .. s.petWidth .. "x" .. s.petHeight .. " " .. s.petAnchor) or "") .. "   Class-icon aura " .. on(s.classAura) .. (s.classAura and (" (" .. tostring(s.auraOrder) .. ")") or ""),
    "Dispel tracker " .. on(s.dispelTracker) .. "   Range fade " .. on(s.range) .. (s.range and (" to " .. math.floor(s.rangeAlpha * 100) .. "%") or ""),
    "Healers only: trinket " .. on(s.trinketHealerOnly) .. ", DR " .. on(s.drHealerOnly) .. ", cast bar " .. on(s.castHealerOnly),
    "Clicks: " .. table.concat(s.clicks or {}, ", ") })
end)

PX.extend("Spark", function(card)
  local SP = PUI.Spark
  local X = SP and SP.Extras
  if not X then return end
  local M = SP.settings.master
  local name = X.Text("Shadow Word: Pain")
  foot(card, "sp", { "Auras, triggers and text",
    "Aura rows: " .. on(SP.settings.rows.auraGain.on) .. " gain, " .. on(SP.settings.rows.auraFade.on) .. " fade   Sample name: " .. tostring(name),
    "Triggers " .. on(M.triggersOn) .. ": " .. #(M.triggers or {}) .. " (build with /pui spark trigger)",
    "Import from MSBT: /pui spark msbt" })
end)

PX.extend("CastHistory", function(card)
  local s = PUI.CastHistory and PUI.CastHistory.settings
  if not s then return end
  foot(card, "ch", { "Links",
    "Masque skins " .. on(s.masque) .. "   Alt+click in the addon menu " .. on(s.compartment) .. "   Casts button in Embers " .. on(s.embersLink) })
end)

PX.extend("PvP", function(card)
  local PV = PUI.PvP
  local s = PV and PV.settings
  if not s then return end
  foot(card, "pv", { "Conquest frame, history and rounds",
    "Conquest overlay " .. on(s.conquestOverlay) .. " (" .. tostring(s.overlayCorner) .. ")   Title IDs found automatically " .. on(s.autoTitleIDs),
    "History window: " .. s.historyRows .. " rows   Drag headers " .. on(s.dragHeaders),
    "Solo Shuffle: Round 4 of 6  2:11" .. (s.shuffleRounds and "  [W L W]" or "") })
end)

PX.extend("Friends", function(card)
  local s = PUI.Friends and PUI.Friends.settings
  if not s then return end
  local c = s.frameColor or { r = 1, g = 1, b = 1 }
  foot(card, "fr", { "Look and add-friend help",
    "Class icons: " .. tostring(s.iconTheme) .. "   Border and tabs " .. on(s.frameStyle) .. string.format("  |cff%02x%02x%02x(colour)|r", c.r * 255, c.g * 255, c.b * 255),
    "Suggestions when adding a friend " .. on(s.addFriendSearch) })
end)

PX.extend("Sentinel", function(card)
  local g = function(k) return PUI.Schema:Get("sentinel." .. k) end
  local warn = g("baselineWarn") or 0
  foot(card, "sn", { "Sounds, baseline and trace",
    "Error sound: " .. tostring(g("alertSoundName")) .. (g("alertSound") and "" or "  (sound off)"),
    "Many new errors: " .. (warn > 0 and ("one chat line after " .. warn .. " outside your usual ones") or "off"),
    "Event trace: " .. (g("trace") and "on  (/pui trace)" or "off") })
end)
