local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Fixed-in sync, the part that needs no new infrastructure (deferred batch
-- D; design in docs/FIXED_SYNC.md). The Companion turns the dashboard's
-- fixed list into a "!PUI_SEN" string (same encoding as report exports);
-- pasting it here (/pui sentinel fixed) marks those errors Fixed in that
-- version, so they show "Back after fix" if they return. Validated and
-- capped; unknown kinds and malformed rows are refused, nothing else in the
-- saved data changes.
local S = PUI.Sentinel
local F = {}
S.FixedSync = F
F.KIND, F.MAX = "fixed-in", 500

-- Apply(payload) -> applied, skipped or nil, reason
function F.Apply(payload)
  if type(payload) ~= "table" or payload.kind ~= F.KIND or type(payload.fixed) ~= "table" then return nil, "not a fixed-in list" end
  if #payload.fixed > F.MAX then return nil, "too many rows (max " .. F.MAX .. ")" end
  local applied, skipped = 0, 0
  for _, row in ipairs(payload.fixed) do
    local hash, ver = type(row) == "table" and row.hash, type(row) == "table" and row.fixedIn
    if type(hash) == "string" and hash:match("^%x+$") and #hash >= 8 and #hash <= 64 and type(ver) == "string" and #ver <= 32 and ver:match("^[%w%.%-]+$") then
      local cur = S.Store:DB().resolved[hash]
      if cur and cur.state == "fixed" and cur.fixedIn == ver then skipped = skipped + 1
      else S.Store:SetState(hash, "fixed", ver); applied = applied + 1 end
    else skipped = skipped + 1 end
  end
  if S.Reporter and S.Reporter.frame and S.Reporter.frame:IsShown() then S.Reporter:Paint() end
  return applied, skipped
end

function F.Import(text)
  local payload, why = S.Export.Decode((text or ""):gsub("%s+", ""))
  if not payload then return nil, why end
  return F.Apply(payload)
end

function F.Prompt()
  PUI.Dialogs:Paste("Fixed-in list", "Paste the string from the Companion's fixed-string command, then Import.", function(text)
    local applied, skipped = F.Import(text)
    if not applied then PUI.Slash.Print("fixed-in list refused: " .. tostring(skipped)) return end
    PUI.Slash.Print(string.format("fixed-in list: %d marked fixed, %d skipped", applied, skipped))
  end)
end

-- Automatic half (docs/FIXED_SYNC.md part 2). The Phoenix Uploader fetches the
-- dashboard's signed fixed list, checks the Ed25519 signature, and writes it
-- into this addon's SavedVariables as PhoenixUISentinelFixed while the game
-- is closed. The signature is checked by the Uploader (Lua has no fast
-- Ed25519); here the list must carry the Uploader's checksum (Adler-32 over
-- "hash=version;" for every row in order), so a damaged or hand-edited file
-- is refused. Applied once at load through Apply's own validation, then
-- cleared; local Ignored states win (Apply only marks Fixed).
function F.Sum(rows)
  local a, b = 1, 0
  for _, row in ipairs(rows) do
    local text = tostring(row.hash) .. "=" .. tostring(row.fixedIn) .. ";"
    for i = 1, #text do
      a = (a + text:byte(i)) % 65521
      b = (b + a) % 65521
    end
  end
  return b * 65536 + a
end

-- ApplyCompanion(data) -> applied, skipped or nil, reason
function F.ApplyCompanion(data)
  if type(data) ~= "table" or data.kind ~= F.KIND or type(data.fixed) ~= "table" then return nil, "no list" end
  if type(data.sum) ~= "number" or F.Sum(data.fixed) ~= data.sum then return nil, "checksum does not match" end
  local keep = {}
  for _, row in ipairs(data.fixed) do
    local hash = type(row) == "table" and row.hash
    local st = type(hash) == "string" and S.Store:DB().resolved[hash]
    if not (st and st.state == "ignored") then keep[#keep + 1] = row end
  end
  return F.Apply({ kind = F.KIND, fixed = keep })
end

function F.LoadCompanion()
  local data = rawget(_G, "PhoenixUISentinelFixed")
  if data == nil then return end
  -- lint-allow: global own SavedVariables
  PhoenixUISentinelFixed = nil
  local applied, skipped = F.ApplyCompanion(data)
  F.last = { applied = applied, skipped = skipped, at = type(data) == "table" and data.at or nil }
end
