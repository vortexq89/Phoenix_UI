-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local Errors = ns.Errors
local M = ns:GetModule("Bugs")

--[[ Send bugs in game (specs/006, BugSack's "Send bugs"): Phoenix to Phoenix over addon messages (whisper).
    The sender offers N reports; the receiver accepts in a popup; then the reports stream in small chunks and land
    in the receiver's sack with the sender's name on the source. Caps: 50 reports, 16 KB per report, one transfer
    per sender at a time. Text export and copy-for-a-report (version, client, addon list) live here too. ]]
local PREFIX = "PUIBugs"
local MAX_REPORTS, MAX_FIELD, CHUNK = 50, 16000, 220
local FS, RS = "\31", "\30" -- field / report separators
local outgoing, incoming = {}, {}

local function send(msg, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", target) end
end

-- A Phoenix question box (no StaticPopup, so nothing of Blizzard's is tainted): text, an optional name field, OK
-- and Cancel. onOk(value) / onCancel().
local ask
function M.Ask(title, text, okLabel, onOk, onCancel, input)
    local W = ns.Widgets
    if not ask then
        ask = W:Popup(title, 420, 150, "bugs")
        ask.text = W.Text(ask, "desc", "text.secondary")
        ask.text:SetPoint("TOPLEFT", 16, -42); ask.text:SetPoint("TOPRIGHT", -16, -42)
        ask.text:SetWordWrap(true); ask.text:SetJustifyH("LEFT")
        ask.input = W:Input(ask, 388, "")
        ask.input:SetPoint("BOTTOMLEFT", 16, 50)
        ask.ok = W:Button(ask, "", "primary", nil, 120)
        ask.ok:SetPoint("BOTTOMRIGHT", -16, 12)
        ask.no = W:Button(ask, CANCEL, "secondary", nil, 120)
        ask.no:SetPoint("RIGHT", ask.ok, "LEFT", -8, 0)
    end
    ask.title:SetText(title:upper())
    ask.text:SetText(text)
    ask.ok:SetText(okLabel)
    ask.input:SetShown(input ~= nil)
    if input then ask.input:SetValue(input) end
    ask.ok.onClick = function() ask:Hide(); onOk(input and ask.input:GetValue() or nil) end
    ask.no.onClick = function() ask:Hide(); if onCancel then onCancel() end end
    ask.close.onClick = ask.no.onClick
    ask:Show(); ask:Raise()
    return ask
end

local function clip(s) s = tostring(s or ""); return s:sub(1, MAX_FIELD):gsub("[\30\31]", " ") end

-- reports -> one string; and back (pure, for the harness)
function M.EncodeReports(list)
    local out = {}
    for i = 1, math.min(#list, MAX_REPORTS) do
        local r = list[i]
        out[#out + 1] = table.concat({ clip(r.kind), clip(r.message), clip(r.stack), clip(r.locals), clip(r.source),
            tostring(tonumber(r.count) or 1) }, FS)
    end
    return table.concat(out, RS)
end

function M.DecodeReports(s)
    local out = {}
    for rec in (s or ""):gmatch("[^\30]+") do
        local f = {}
        for v in (rec .. FS):gmatch("(.-)\31") do f[#f + 1] = v end
        if f[2] and f[2] ~= "" and #out < MAX_REPORTS then
            out[#out + 1] = { kind = f[1], message = f[2], stack = f[3] or "", locals = f[4] or "", source = f[5] or "?",
                count = tonumber(f[6]) or 1 }
        end
    end
    return out
end

function M.Chunks(s)
    local out = {}
    for i = 1, #s, CHUNK do out[#out + 1] = s:sub(i, i + CHUNK - 1) end
    return out
end

-- Offers the reports to a player (a name, "Name-Realm" across realms). Returns false and a reason key.
function M:SendBugs(target, list)
    target = (target or ""):gsub("%s", "")
    if target == "" then return false, "BUGS_SEND_NOBODY" end
    if not list or #list == 0 then return false, "BUGS_SEND_EMPTY" end
    local id = tostring(math.random(100000, 999999))
    outgoing[id] = { target = target, chunks = M.Chunks(M.EncodeReports(list)), count = math.min(#list, MAX_REPORTS) }
    send(("O|%s|%d"):format(id, outgoing[id].count), target)
    ns:Print(L.BUGS_SEND_OFFERED:format(outgoing[id].count, target))
    return true
end

local function stream(id)
    local o = outgoing[id]
    if not o then return end
    local n = #o.chunks
    for i, c in ipairs(o.chunks) do
        C_Timer.After(i * 0.12, function() send(("C|%s|%d|%d|%s"):format(id, i, n, c), o.target) end)
    end
    C_Timer.After(n * 0.12 + 0.5, function() ns:Print(L.BUGS_SEND_DONE:format(o.count, o.target)); outgoing[id] = nil end)
end

local function receive(sender, id, n)
    M.Ask(L.BUGS, L.BUGS_SEND_ASK:format(sender, n), ACCEPT,
        function() incoming[sender] = { id = id, parts = {} }; send("A|" .. id, sender) end,
        function() send("D|" .. id, sender) end)
end

-- One whole transfer arrived: the reports join this session's sack, marked with who sent them.
function M:TakeReceived(sender, payload)
    local list = M.DecodeReports(payload)
    for _, r in ipairs(list) do
        Errors:Record(r.kind ~= "" and r.kind or "error", r.message, r.stack, r.locals, ("%s (%s)"):format(r.source, sender), r.count)
    end
    ns:Print(L.BUGS_SEND_GOT:format(#list, sender))
    self:Refresh()
    return #list
end

function M:OnAddonMessage(prefix, msg, _, sender)
    if prefix ~= PREFIX or not self:IsEnabled() then return end
    local kind, rest = msg:match("^(%a)|(.*)$")
    if kind == "O" then
        local id, n = rest:match("^(%d+)|(%d+)$")
        if id then receive(sender, id, tonumber(n)) end
    elseif kind == "A" then
        local o = outgoing[rest]
        if o then stream(rest) end
    elseif kind == "D" then
        if outgoing[rest] then ns:Print(L.BUGS_SEND_DECLINED:format(outgoing[rest].target)); outgoing[rest] = nil end
    elseif kind == "C" then
        local id, i, n, data = rest:match("^(%d+)|(%d+)|(%d+)|(.*)$")
        local t = incoming[sender]
        if not (id and t and t.id == id) then return end
        i, n = tonumber(i), tonumber(n)
        if n > MAX_REPORTS * (MAX_FIELD * 4 / CHUNK) then incoming[sender] = nil; return end
        t.parts[i] = data
        for k = 1, n do if not t.parts[k] then return end end
        incoming[sender] = nil
        self:TakeReceived(sender, table.concat(t.parts))
    end
end

function M:SetupShare()
    if self.shareReady then return end
    self.shareReady = true
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
    ns.Events:On("CHAT_MSG_ADDON", self, function(_, _, ...) self:OnAddonMessage(...) end)
end

-- The header of a copied report or export: Phoenix version, client build, locale and the loaded addons.
function M.ReportHeader()
    local _, build = GetBuildInfo()
    local lines = { ("Phoenix UI %s · build %s · %s · %s"):format(ns.version or "?", tostring(build), GetLocale(), date("%Y-%m-%d %H:%M")) }
    local names = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(i) then names[#names + 1] = (C_AddOns.GetAddOnInfo(i)) end
    end
    lines[2] = L.BUGS_FIELD_ADDONS:format(#names, table.concat(names, ", "))
    return table.concat(lines, "\n")
end
