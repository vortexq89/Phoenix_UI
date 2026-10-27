-- Prints every registered settings key as "key<TAB>owner<TAB>file" by loading
-- Phoenix UI and its children under the offline stub, one file at a time, and
-- attributing each new key to the file that registered it. Used by manifest.py.
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(here .. "/wow_stub.lua")
local function tocFiles(dir, name)
  local fh = io.open(H.root .. "/" .. dir .. "/" .. name .. ".toc")
  if not fh then return nil end
  local files = {}
  for line in fh:lines() do
    line = line:gsub("\r", "")
    if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  fh:close()
  return files
end
local seen, out = {}, {}
local function load(name)
  local dir = name == "Phoenix_UI" and "." or name
  local files = tocFiles(dir, name)
  if not files then return end
  local ns = {}
  for _, file in ipairs(files) do
    local chunk = assert(loadfile(H.root .. "/" .. dir .. "/" .. file))
    local ok, err = H.dispatch(chunk, name, ns)
    if not ok then error(file .. ": " .. tostring(err)) end
    local S = PhoenixUI and PhoenixUI.Schema
    if S then
      for key, def in pairs(S.defs) do
        if not seen[key] then
          seen[key] = true
          local rel = (dir == "." and "" or dir .. "/") .. file
          out[#out + 1] = key .. "\t" .. tostring(def.owner or "Core") .. "\t" .. rel
        end
      end
    end
  end
  H.loaded[name] = true
  H.fire("ADDON_LOADED", name, false)
end
load("Phoenix_UI")
for _, child in ipairs({ "Phoenix_UI_UnitFrames", "Phoenix_UI_ResourceBars", "Phoenix_UI_ActionBars", "Phoenix_UI_Nameplates", "Phoenix_UI_RaidFrames", "Phoenix_UI_CooldownManager", "Phoenix_UI_HUD", "Phoenix_UI_Chat", "Phoenix_UI_Skins", "Phoenix_UI_Vault", "Phoenix_UI_Flow", "Phoenix_UI_QuestTracker", "Phoenix_UI_Reminders", "Phoenix_UI_Setup", "Phoenix_UI_Embers", "Phoenix_UI_Ascent", "Phoenix_UI_Oracle", "Phoenix_UI_Wisdom", "Phoenix_UI_Loadouts", "Phoenix_UI_GroupFinder", "Phoenix_UI_RaidTools", "Phoenix_UI_Pulse", "Phoenix_UI_Arena", "Phoenix_UI_Spark", "Phoenix_UI_CastHistory", "Phoenix_UI_PvP", "Phoenix_UI_Friends", "Phoenix_UI_Media", "Phoenix_UI_Sentinel", "Phoenix_UI_Options" }) do
  if not H.loaded[child] then load(child) end
end
table.sort(out)
io.stdout:write(table.concat(out, "\n"), "\n")
