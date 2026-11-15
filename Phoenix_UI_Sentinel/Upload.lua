local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Upload (mockup 15 "auto-upload via Companion"): every Phoenix report is
-- saved for the Companion app, which posts it to the vq8s.com dashboard
-- through the existing /phoenix/api/ingest path (contract v2, same stable
-- ids, so re-sends are deduped). The game cannot open network connections,
-- so the Companion reads the SavedVariables file the client writes at
-- logout and reload. Preview shows the exact payload (after the privacy
-- kit) that leaves this PC; other addons' errors are included only when
-- you allow it.
local S = PUI.Sentinel
local U = { DASHBOARD = "https://vq8s.com/phoenix" }
S.Upload = U

function U:Payload() return S.Export:Payload() end

-- Pretty JSON (two-space indent) of the payload, for reading.
function U.Pretty(json)
  local out, depth, inStr, esc = {}, 0, false, false
  for i = 1, #json do
    local c = json:sub(i, i)
    if inStr then
      out[#out + 1] = c
      if esc then esc = false elseif c == "\\" then esc = true elseif c == '"' then inStr = false end
    elseif c == '"' then inStr = true; out[#out + 1] = c
    elseif c == "{" or c == "[" then depth = depth + 1; out[#out + 1] = c .. "\n" .. string.rep("  ", depth)
    elseif c == "}" or c == "]" then depth = depth - 1; out[#out + 1] = "\n" .. string.rep("  ", depth) .. c
    elseif c == "," then out[#out + 1] = ",\n" .. string.rep("  ", depth)
    elseif c == ":" then out[#out + 1] = ": "
    else out[#out + 1] = c end
  end
  return table.concat(out)
end

function U:PreviewText()
  local db = S.db
  if not db.optIn then return "Auto-upload is off. Nothing leaves this PC.\n\nTurn on 'Auto-upload via Companion' to send Phoenix error reports to the dashboard." end
  local p = self:Payload()
  local header = string.format("This is exactly what the Companion uploads (%d reports, privacy filters applied). The Companion also removes file paths, e-mails and BattleTags.\n\n", #p.reports)
  return header .. U.Pretty(S.Export.ToJSON(p))
end

-- Status line: queued reports and the last time the game saved them.
function U:Status()
  local db = S.db
  if not db.optIn then return "Auto-upload: off" end
  local n = #self:Payload().reports
  local saved = db.lastSaved and date("%H:%M", db.lastSaved) or "not yet (at logout or reload)"
  return string.format("Auto-upload: %d reports queued for the Companion - last saved %s - dashboard vq8s.com/phoenix", n, saved)
end
-- At logout and before "send now" the exact preview payload is written to
-- db.outbox; the Companion uploads that table as-is.
function U:MarkSaved()
  local db = S.db
  if not db then return end
  db.lastSaved = time()
  db.outbox = db.optIn and self:Payload() or nil
end
