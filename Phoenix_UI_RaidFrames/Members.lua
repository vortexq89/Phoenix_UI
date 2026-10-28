local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Free party placement (deferred batch B, Studio): instead of the party
-- header's row or column, you and each party member get a frame of your own
-- that Studio moves on its own (rf.party.member1..5). The frames are secure
-- unit buttons with a fixed unit (you, party1..4), shown by a state driver;
-- the party header is hidden while this is on. Built and moved out of combat.
local _, ns = ...
local RF = ns.RF or PUI.RaidFrames
local Layout, CQ, Schema = PUI.Layout, PUI.CombatQueue, PUI.Schema
local OWNER = "RaidFrames"
local s = RF.settings
local M = { on = false, buttons = {} }
RF.Members = M
M.UNITS = { "player", "party1", "party2", "party3", "party4" }

for i = 1, 5 do
  Layout:RegisterElement("rf.party.member" .. i, { label = i == 1 and "Party: you" or ("Party member " .. (i - 1)), owner = OWNER,
    size = { 90, 44 }, default = { point = "TOPLEFT", x = 27, y = -213 - (i - 1) * 48 } })
end

-- State-driver condition for member i (plain macro conditions, secure).
function M.Visibility(i)
  if i == 1 then
    if not s.showPlayer then return "hide" end
    return s.showSolo and "[group:raid] hide; show" or "[group:raid] hide; [group:party] show; hide"
  end
  return "[group:raid] hide; [@" .. M.UNITS[i] .. ",exists] show; hide"
end

local function build(i)
  local b = M.buttons[i]
  if b then return b end
  b = PUI:CreateFrame("Button", "PhoenixUI_RF_PartyMember" .. i, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate", OWNER)
  b:SetAttribute("*type1", "target")
  b:SetAttribute("*type2", "togglemenu")
  b:SetAttribute("unit", M.UNITS[i])
  M.buttons[i] = b
  RF.InitButton(b)
  return b
end

function M.Apply()
  CQ.Defer("rf.members", function()
    local want = RF.active and M.on
    local header = RF.headers and RF.headers.party
    local t = s.tiers.party
    for i = 1, 5 do
      if want then
        local b = build(i)
        b:SetSize(t.width, t.height)
        Layout:Place(b, "rf.party.member" .. i)
        RegisterStateDriver(b, "visibility", M.Visibility(i))
      elseif M.buttons[i] then
        UnregisterStateDriver(M.buttons[i], "visibility")
        M.buttons[i]:Hide()
      end
    end
    if header and want then RegisterStateDriver(header, "visibility", "hide") end
  end)
end

local applyLayout = RF.ApplyLayout
function RF.ApplyLayout()
  applyLayout()
  if RF.active and (M.on or next(M.buttons)) then M.Apply() end
end

PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then M.Apply() end end)

RF.key("party.free", { type = "toggle", default = false, label = "Place party members one by one",
  tooltip = "You and each party member get your own frame that you can move anywhere in Studio, instead of one row. Sorting by role does not apply while this is on.",
  mode = "simple", searchTags = { "studio", "party", "free placement" } }, function(v) M.on = v end, "layout")
Schema:Register("rf.party.free", RF.schema["rf.party.free"])
M.on = Schema:Get("rf.party.free")
