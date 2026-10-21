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

-- The ONLY globals Phoenix_UI may write: its SavedVariables, plus GetMinimapShape (the minimap-button
-- convention, defined only while the square minimap is on). Everything else lives on the addon namespace.
globals = {
  "GetMinimapShape",
  "PhoenixUIDB",
  "Phoenix_UIDB", "Phoenix_UIPerCharDB", -- legacy, read once by the migration then set to nil
}

read_globals = {
  "LibStub", -- embedded in Libs/ (loaded first by Libs/Libs.xml)
  -- set by <Script> blocks in Blizzard_Fonts_Shared/Shared/GameFonts.xml (not visible to the Lua-only std generator)
  "STANDARD_TEXT_FONT", "UNIT_NAME_FONT", "DAMAGE_TEXT_FONT", "NAMEPLATE_FONT", "NAMEPLATE_SPELLCAST_FONT",
}

ignore = {
  "212/self",   -- unused self in mixin methods
  "432/self",   -- script handlers named self inside widget constructors
  "212/_.*",    -- unused args prefixed with _
  "211/_.*", "213/_.*",
  "542",        -- empty if branch (explicit no-op)
}

exclude_files = {
  "Libs/**",           -- third-party embeds, linted upstream
  ".luacheck/**", "tools/**",
}

-- Locale files are prose; long string lines are expected there.
files["Locales/*.lua"] = { max_line_length = false }
