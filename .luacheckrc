-- Phoenix_UI luacheck config — WoW Retail 12.1.5 (TOC 120105, build 70448)
-- The `wow` std is GENERATED from the 12.1.5 client UI source (C API docs + mainline FrameXML +
-- GlobalStrings, Blizzard_Deprecated* excluded). Regenerate per patch: see tools/audit/README.md.
-- Any "accessing undefined variable" (W113) or "undefined field" (W143) on a Blizzard name means the
-- API does not exist in 12.1.5 -> fix the code, never whitelist it here.
stds.wow = dofile(".luacheck/wow_std_12.1.5.lua")
std = "lua51+wow"
max_line_length = 140
max_cyclomatic_complexity = 30
codes = true

-- The ONLY globals Phoenix_UI may write (SavedVariables). Everything else lives on the addon namespace.
globals = {
  "PhoenixUIDB", "PhoenixUICharDB",
  "Phoenix_UIDB", "Phoenix_UIPerCharDB", -- legacy, read once by the migration then set to nil
}

ignore = {
  "212/self",   -- unused self in mixin methods
  "212/_.*",    -- unused args prefixed with _
  "211/_.*", "213/_.*",
  "542",        -- empty if branch (explicit no-op)
}

exclude_files = {
  "Libs/**",           -- third-party embeds, linted upstream
  ".luacheck/**", "tools/**",
}
