local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the chat mirror.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local CH = ns.CH

local function enable(t, ...)
  local keys = { "module.Chat", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end end)
  Schema:Set("module.Chat", true)
end

Tests:Add("Chat", "off by default; every setting has apply", function(t)
  t:eq(Schema:Def("module.Chat").default, false, "module defaults off")
  for key, def in pairs(CH.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.Chat") then t:eq(next(CH.mirrors), nil, "no mirrors while off") end
end)

Tests:Add("Chat", "decoration touches plain lines only", function(t)
  local saved = { Schema:Get("chat.timestamps"), Schema:Get("chat.abbreviate") }
  t:cleanup(function() Schema:Set("chat.timestamps", saved[1]); Schema:Set("chat.abbreviate", saved[2]) end)
  Schema:Set("chat.timestamps", "off")
  Schema:Set("chat.abbreviate", true)
  t:eq(CH.Decorate("|Hchannel:channel:2|h[2. Trade - City]|h [Bob]: wts"), "|Hchannel:channel:2|h[2]|h [Bob]: wts", "channel abbreviated")
  if H then
    local secret = H.secret("x")
    t:ok(CH.Decorate(secret) == secret, "secret line passed through unchanged")
    t:eq(CH.MatchesKeyword(secret), false, "secret line never searched")
  end
end)

Tests:Add("Chat", "mirror follows AddMessage and scrolling; Blizzard text hidden and restored", function(t)
  if not H then return end
  enable(t, "chat.keywords")
  Schema:Set("chat.keywords", "Phoenix, summon")
  local m = CH.mirrors[ChatFrame1]
  t:ok(m and m:IsShown(), "mirror over ChatFrame1")
  t:eq(ChatFrame1.FontStringContainer:GetAlpha(), 0, "Blizzard text alpha 0")
  ChatFrame1:AddMessage("need a SUMMON please")
  t:eq(m.messages[#m.messages], "need a SUMMON please", "line mirrored")
  t:eq(ChatFrame1.last, "need a SUMMON please", "Blizzard AddMessage still ran (post-hook only)")
  t:ok(H.flashed and #H.sounds > 0, "keyword alert sound and flash")
  ChatFrame1:SetScrollOffset(3)
  t:eq(m:GetScrollOffset(), 3, "scrolled in lockstep")
  ChatFrame1:AddMessage(H.secret("secret line"))
  t:ok(CH.history[#CH.history] == "need a SUMMON please", "secret lines kept out of copy history")
  Schema:Set("module.Chat", false)
  t:eq(ChatFrame1.FontStringContainer:GetAlpha(), 1, "Blizzard text restored")
  t:eq(m:IsShown(), false, "mirror hidden")
end)
