local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Toast: a small notice for the first occurrence of a new incident, and the
-- safe-mode notice. Created on first use; hides itself after 10 seconds.
local S = PUI.Sentinel
local Toast = {}
S.Toast = Toast

local ACCENT = { 1, 0.49, 0.04 } -- ember #FF7D0A
local SURFACE = { 0.055, 0.055, 0.063, 0.95 } -- surface.0 #0E0E10

local function button(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(110, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

function Toast:Build()
  local f = PUI:CreateFrame("Frame", "PhoenixUISentinelToast", UIParent, nil, "Sentinel")
  f:SetSize(380, 74)
  f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  f:SetFrameStrata("DIALOG")
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(SURFACE[1], SURFACE[2], SURFACE[3], SURFACE[4])
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("BOTTOMLEFT")
  bar:SetWidth(3)
  bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("TOPLEFT", 12, -10)
  f.text:SetPoint("TOPRIGHT", -10, -10)
  f.text:SetJustifyH("LEFT")
  f.primary = button(f, "Send report", function() Toast:OnPrimary() end)
  f.primary:SetPoint("BOTTOMLEFT", 12, 8)
  f.secondary = button(f, "Later", function() f:Hide() end)
  f.secondary:SetPoint("LEFT", f.primary, "RIGHT", 8, 0)
  f:Hide()
  self.frame = f
  return f
end

function Toast:Show(text, primaryLabel, onPrimary)
  local f = self.frame or self:Build()
  f.text:SetText(text)
  f.primary:SetText(primaryLabel)
  self.onPrimary = onPrimary
  f:Show()
  local token = {}
  self.token = token
  C_Timer.After(10, function() if Toast.token == token then f:Hide() end end)
end

function Toast:OnPrimary()
  self.frame:Hide()
  if self.onPrimary then self.onPrimary() end
end

-- First occurrence of a new incident (repeats are only counted).
function Toast:Notify(inc)
  if not S.toastEnabled or inc.kind == "heartbeat" or inc.kind == "test" then return end
  if not PUI.Kernel.loggedIn then return end
  local text = "|cffff7d0aPhoenix UI|r caught a " .. inc.kind .. " in " .. inc.module .. ".\n" .. inc.message:sub(1, 90)
  if S.db.optIn then
    self:Show(text, "Send report", function() S.Panel:SendNow() end)
  else
    self:Show(text, "Details", function() S.Panel:Open() end)
  end
end

function Toast:SafeModeNotice(modules)
  local names = {}
  for name in pairs(modules) do names[#names + 1] = name end
  table.sort(names)
  self:Show("|cffff7d0aPhoenix UI|r: " .. table.concat(names, ", ") .. " disabled after repeated errors. The rest of the UI is running.",
    "Re-enable", function()
      for i = 1, #names do S.SafeMode:Release(names[i]) end
    end)
end
