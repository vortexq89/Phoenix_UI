local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Friends list skin (mockup 19, EllesmereUI parity, Phoenix's own art):
-- styles Blizzard's friend rows through a post-hook only; Blizzard still
-- builds the list. Each row gets a class icon, class-coloured name, status
-- orb (online / AFK / DND), zone and activity line, region tag, faction
-- tint, and app-only friends dimmed when you hide them. Nothing on the row
-- is replaced, so turning the skin off restores the row on the next update.
local _, ns = ...
local D = ns.Data
local K = { decorated = setmetatable({}, { __mode = "k" }) }
ns.Skin = K

K.STATUS_COLORS = { online = { 0.35, 0.8, 0.35 }, afk = { 0.95, 0.75, 0.2 }, dnd = { 0.9, 0.25, 0.25 }, offline = { 0.45, 0.45, 0.45 } }
K.FACTION = { Horde = { 0.55, 0.1, 0.1 }, Alliance = { 0.1, 0.25, 0.6 } }

local function parts(button)
  local p = K.decorated[button]
  if p then return p end
  p = {}
  p.icon = button:CreateTexture(nil, "ARTWORK"); p.icon:SetSize(16, 16); p.icon:SetPoint("LEFT", 4, 0)
  p.orb = button:CreateTexture(nil, "OVERLAY"); p.orb:SetSize(8, 8); p.orb:SetPoint("TOPRIGHT", -34, -6)
  p.region = button:CreateFontString(nil, "OVERLAY"); p.region:SetFontObject(PUI.Media:FontObject("small")); p.region:SetPoint("BOTTOMRIGHT", -34, 5)
  p.banner = button:CreateTexture(nil, "BACKGROUND", nil, -1); p.banner:SetAllPoints()
  K.decorated[button] = p
  return p
end

-- Entry for a Blizzard row: buttonType 2 = WoW friend, 3 = Battle.net.
function K.EntryFor(button)
  local id = button.id
  if not id then return nil end
  if button.buttonType == 2 then local f = C_FriendList.GetFriendInfoByIndex(id); return f and D.FromWoW(id, f) end
  if button.buttonType == 3 then local a = C_BattleNet.GetFriendAccountInfo(id); return a and D.FromBNet(id, a) end
  return nil
end

function K.Paint(button, s)
  local p = parts(button)
  local on = s.skin
  for _, r in pairs(p) do r:SetShown(on) end
  button:SetAlpha(1)
  if not on then return end
  local e = K.EntryFor(button)
  if not e then for _, r in pairs(p) do r:Hide() end return end
  local c = e.classFile and C_ClassColor.GetClassColor(e.classFile)
  if s.classIcons and e.classFile then p.icon:SetAtlas("classicon-" .. e.classFile:lower()); p.icon:Show() else p.icon:Hide() end
  if s.classNames and c and e.online and button.name then button.name:SetTextColor(c.r, c.g, c.b) end
  local sc = K.STATUS_COLORS[e.status] or K.STATUS_COLORS.offline
  if s.statusOrb then p.orb:SetColorTexture(sc[1], sc[2], sc[3], 1); p.orb:Show() else p.orb:Hide() end
  if s.regionIcons and e.region then p.region:SetText(e.region); p.region:Show() else p.region:Hide() end
  local fc = s.factionBanners and e.faction and K.FACTION[e.faction]
  if fc then p.banner:SetColorTexture(fc[1], fc[2], fc[3], 0.22); p.banner:Show() else p.banner:Hide() end
  if s.zoneLine and button.info and e.online then
    local line = e.zone or ""
    if s.activity and e.activity then line = (line ~= "" and (line .. "  -  ") or "") .. e.activity end
    if line ~= "" then button.info:SetText(line) end
  end
  if (s.hideAppOnly and e.appOnly) or (s.wowOnly and not D.InGame(e, s.sameGame)) then button:SetAlpha(s.appOnlyAlpha) end
end

function K.Hook(s)
  if K.hooked then return true end
  local fn = rawget(_G, "FriendsFrame_UpdateFriendButton")
  if not fn then return false end
  K.hooked = true
  hooksecurefunc("FriendsFrame_UpdateFriendButton", function(button) if ns.F.active then K.Paint(button, s) end end)
  return true
end
