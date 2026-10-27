local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- In-game sharing (mockup 15 "Share with a player (you start it)"):
-- nothing is sent until you press Share. The receiver gets a prompt first;
-- only after they accept are the chunks sent, each with its index, and the
-- whole report carries a checksum the receiver checks before showing it.
-- Wire (addon prefix PUISEN, whisper):
--   O|id|chunks|checksum|bytes   offer        A|id  accept    N|id  decline
--   C|id|i|data                  chunk i      (sent 4 per second by one
--   Ticker entry that exists only while a transfer runs)
local S = PUI.Sentinel
local Share = { PREFIX = "PUISEN", CHUNK = 220, out = {}, inbox = {}, nextId = 0 }
S.Share = Share

function Share.Checksum(text) return S.Capture.Hash(text) end

-- Pack(inc) -> encoded single-report string (privacy applied).
function Share.Pack(inc)
  local db = S.db
  local report = { hash = inc.hash, kind = inc.kind, module = inc.module, addon = inc.addon, message = inc.message, stack = inc.stack, locals = inc.locals,
    count = inc.count, addonVersion = inc.addonVersion or S:Version(), build = inc.build, firstSeen = inc.firstSeen, lastSeen = inc.lastSeen,
    from = "Phoenix_UI_Sentinel " .. S:Version(), install = db.installId and db.installId:sub(1, 6) }
  S.Privacy.Report(report, S.Privacy.Name())
  local json = S.Export.ToJSON(report)
  return C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(json))
end
function Share.Split(text, size)
  local out = {}
  for i = 1, #text, size do out[#out + 1] = text:sub(i, i + size - 1) end
  return out
end

local function send(msg, target) return C_ChatInfo.SendAddonMessage(Share.PREFIX, msg, "WHISPER", target) end

-- Offer(inc, target): starts a transfer; returns the offer summary.
function Share:Offer(inc, target)
  if type(target) ~= "string" or target == "" then return nil, "no player name" end
  local text = Share.Pack(inc)
  self.nextId = self.nextId + 1
  local id = tostring(self.nextId)
  local chunks = Share.Split(text, self.CHUNK)
  local sum = Share.Checksum(text)
  self.out[id] = { target = target, chunks = chunks, sum = sum, next = 1, state = "offered" }
  send(string.format("O|%s|%d|%s|%d", id, #chunks, sum, #text), target)
  return { id = id, chunks = #chunks, bytes = #text, checksum = sum }
end

function Share:Pump()
  local busy = false
  for id, t in pairs(self.out) do
    if t.state == "sending" then
      busy = true
      send(string.format("C|%s|%d|%s", id, t.next, t.chunks[t.next]), t.target)
      t.next = t.next + 1
      if t.next > #t.chunks then t.state = "done"; PUI.Slash.Print(string.format("report sent to %s (%d chunks)", t.target, #t.chunks)) end
    end
  end
  if not busy then PUI.Ticker:Unregister("sentinel.share") end
end
function Share:StartSending(id)
  local t = self.out[id]
  if not t or t.state ~= "offered" then return end
  t.state = "sending"
  PUI.Ticker:Register("sentinel.share", 0.25, function() Share:Pump() end, "Sentinel")
end

-- Receiving ---------------------------------------------------------------
local function trusted(sender)
  local short = sender:match("^[^-]+") or sender
  for i = 1, C_FriendList.GetNumFriends() or 0 do
    local f = C_FriendList.GetFriendInfoByIndex(i)
    if f and f.name == short then return true end
  end
  return IsInGuild() and rawget(_G, "UnitIsInMyGuild") ~= nil and UnitIsInMyGuild(short) == true
end
function Share:Prompt(sender, id, offer)
  local mode = PUI.Schema:Get("sentinel.shareAccept")
  if mode == "never" or (mode == "trusted" and not trusted(sender)) then send("N|" .. id, sender); return "refused" end
  PUI.Dialogs:Confirm({ title = "Error report from " .. sender,
    text = string.format("%s wants to send you a Phoenix error report (%d bytes, %d chunks, checksum %s). Accept?", sender, offer.bytes, offer.chunks, offer.sum),
    accept = "Accept", cancel = "Decline",
    onAccept = function() Share:Accept(sender, id) end,
    onCancel = function() self.inbox[sender .. "|" .. id] = nil; send("N|" .. id, sender) end })
  return "asked"
end
function Share:Accept(sender, id)
  local box = self.inbox[sender .. "|" .. id]
  if not box then return end
  box.accepted = true
  send("A|" .. id, sender)
end

-- OnMessage(prefix, msg, channel, sender) -> what happened (tests read it).
function Share:OnMessage(prefix, msg, _, sender)
  if prefix ~= self.PREFIX or type(msg) ~= "string" or PUI.Secret.IsSecret(msg) then return nil end
  local kind, id, rest = msg:match("^(%u)|([^|]+)|?(.*)$")
  if kind == "O" then
    local n, sum, bytes = rest:match("^(%d+)|(%x+)|(%d+)$")
    if not n or tonumber(n) > 60 then return "bad offer" end
    local offer = { chunks = tonumber(n), sum = sum, bytes = tonumber(bytes), parts = {}, got = 0 }
    self.inbox[sender .. "|" .. id] = offer
    return self:Prompt(sender, id, offer)
  elseif kind == "A" then self:StartSending(id); return "accepted"
  elseif kind == "N" then local t = self.out[id]; if t then t.state = "declined" end; return "declined"
  elseif kind == "C" then
    local box = self.inbox[sender .. "|" .. id]
    if not (box and box.accepted) then return "ignored" end -- never accepted: dropped
    local i, data = rest:match("^(%d+)|(.*)$")
    i = tonumber(i)
    if not i or i < 1 or i > box.chunks or box.parts[i] then return "bad chunk" end
    box.parts[i], box.got = data, box.got + 1
    if box.got < box.chunks then return "chunk" end
    self.inbox[sender .. "|" .. id] = nil
    local text = table.concat(box.parts)
    if Share.Checksum(text) ~= box.sum then return "checksum failed" end
    local packed = C_EncodingUtil.DecodeBase64(text)
    local json = packed and C_EncodingUtil.DecompressString(packed)
    if not json then return "bad data" end
    local report = S.Export.FromJSON(json)
    report.receivedFrom, report.receivedAt = sender, time()
    local db = S.db
    db.received = db.received or {}
    table.insert(db.received, 1, report)
    for k = #db.received, 21, -1 do db.received[k] = nil end
    if S.Reporter then S.Reporter:OpenReceived(1) end
    return "received", report
  end
  return nil
end
