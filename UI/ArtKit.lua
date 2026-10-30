-- Copyright (c) 2026 VortexQ8 (ABDULRAHMAN ALYOUSEF). All rights reserved. See Media/LICENSE.md.
local _, ns = ...
-- luacheck: no max line length
local A = ns.Art

--[[ Phoenix art kit v8.1, the "phoenix-wings" look for game frames (THEME_API §7.02 / 7.03). Baked art only:
    every texture is set once when a frame is laid out or the theme changes; nothing animates, no OnUpdate.

    Media/Art/PhoenixUI_Portraits  portrait rings by classification     Media/Art/PhoenixUI_Actions  action / stance / cast
    Media/Art/PhoenixUI_Bars       health / power frames, caps, gems    Media/Art/PhoenixUI_Frames   plates, party, raid
    Media/Art/PhoenixUI_Panels     minimap ring, tooltip, chat, bags    PhoenixBarFill / PhoenixCastFill  greyscale fills
    Media/Art/PhoenixUI_V9         v9.1 pieces (loot, rolls, queue pop, ready check, talents, map, XP, debuff marks ...)
    Media/Art/PhoenixUI_Modules    v8.1 module pieces: meter, gallery, plugins, indicators, resources, upcoming modules

    A:Dress(frame, sheet, piece[, opts]) puts the piece over (or under) a frame on its own child frame and returns the
    texture; A:Undress hides it. Pieces resolve through tokens "atlas.<sheet>" and "atlas.<sheet>.<piece>", so a
    plugin swaps any part with PhoenixUI:OverrideArt. Class, spec and ability icons are never touched: the art only
    frames them. General > Look picks "phoenix-wings" (default), "settings" (v7.1 settings art only) or Phoenix art off. ]]

local ROOT = A.ROOT
local KIT = {}
A.KIT = KIT






-- PhoenixUI_Portraits: 1024x512 RGBA, pad 4px. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.portraits = {
  file = ROOT .. "PhoenixUI_Portraits",
  ring_player            = { w = 240, h = 248, coords = { 0.007812, 0.242188, 0.007812, 0.492188 }, holeX = 0.4995, holeY = 0.6029, holeR = 0.1887 },
  ring_target            = { w = 239, h = 248, coords = { 0.257812, 0.491211, 0.007812, 0.492188 }, holeX = 0.496, holeY = 0.4925, holeR = 0.3457 },
  ring_boss              = { w = 213, h = 248, coords = { 0.520508, 0.728516, 0.007812, 0.492188 }, holeX = 0.4874, holeY = 0.5737, holeR = 0.1968 },
  ring_elite             = { w = 231, h = 248, coords = { 0.761719, 0.987305, 0.007812, 0.492188 }, holeX = 0.5001, holeY = 0.6619, holeR = 0.2045 },
  ring_rare              = { w = 229, h = 248, coords = { 0.012695, 0.236328, 0.507812, 0.992188 }, holeX = 0.5005, holeY = 0.6559, holeR = 0.208 },
  ring_rareelite         = { w = 231, h = 248, coords = { 0.261719, 0.487305, 0.507812, 0.992188 }, holeX = 0.5, holeY = 0.6665, holeR = 0.1973 },
  ring_boss_s            = { w = 99, h = 124, coords = { 0.515625, 0.612305, 0.515625, 0.757812 }, holeX = 0.5032, holeY = 0.6417, holeR = 0.2357 },
}

-- PhoenixUI_Actions: 1024x512 RGBA, pad 4px. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.actions = {
  file = ROOT .. "PhoenixUI_Actions",
  action_normal          = { w = 120, h = 120, coords = { 0.003906, 0.121094, 0.007812, 0.242188 }, inset = 16 },
  action_proc            = { w = 120, h = 120, coords = { 0.128906, 0.246094, 0.007812, 0.242188 }, inset = 16 },
  action_pressed         = { w = 120, h = 120, coords = { 0.253906, 0.371094, 0.007812, 0.242188 }, inset = 16 },
  action_ready           = { w = 120, h = 120, coords = { 0.378906, 0.496094, 0.007812, 0.242188 }, inset = 16 },
  stance_normal          = { w = 60, h = 60, coords = { 0.503906, 0.562500, 0.007812, 0.125000 } },
  stance_proc            = { w = 60, h = 60, coords = { 0.570312, 0.628906, 0.007812, 0.125000 } },
  stance_pressed         = { w = 60, h = 60, coords = { 0.636719, 0.695312, 0.007812, 0.125000 } },
  stance_ready           = { w = 60, h = 60, coords = { 0.703125, 0.761719, 0.007812, 0.125000 } },
  cast_frame             = { w = 497, h = 78, coords = { 0.004883, 0.490234, 0.257812, 0.410156 }, left = 23, right = 23, top = 13, bottom = 13 },
  cast_cap_ember         = { w = 86, h = 92, coords = { 0.516602, 0.600586, 0.257812, 0.437500 } },
  cast_cap_steel         = { w = 85, h = 92, coords = { 0.641602, 0.724609, 0.257812, 0.437500 } },
  cast_fill_grey         = { w = 500, h = 28, coords = { 0.003906, 0.492188, 0.453125, 0.507812 } },
  cast_spark             = { w = 32, h = 64, coords = { 0.500000, 0.531250, 0.453125, 0.578125 }, blend = "ADD" },
}

-- PhoenixUI_Bars: 512x512 RGBA, pad 4px. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.bars = {
  file = ROOT .. "PhoenixUI_Bars",
  health_frame           = { w = 499, h = 40, coords = { 0.007812, 0.982422, 0.007812, 0.085938 }, left = 8, right = 8, top = 3, bottom = 3 },
  health_cap_l           = { w = 90, h = 64, coords = { 0.013672, 0.189453, 0.101562, 0.226562 } },
  health_cap_r           = { w = 90, h = 64, coords = { 0.216797, 0.392578, 0.101562, 0.226562 } },
  power_frame            = { w = 492, h = 40, coords = { 0.015625, 0.976562, 0.242188, 0.320312 }, left = 8, right = 8, top = 3, bottom = 3 },
  power_cap_l            = { w = 89, h = 64, coords = { 0.013672, 0.187500, 0.335938, 0.460938 } },
  power_cap_r            = { w = 89, h = 64, coords = { 0.216797, 0.390625, 0.335938, 0.460938 } },
  bar_fill_grey          = { w = 500, h = 28, coords = { 0.007812, 0.984375, 0.476562, 0.531250 } },
  gem_lit                = { w = 50, h = 56, coords = { 0.013672, 0.111328, 0.546875, 0.656250 } },
  gem_unlit              = { w = 53, h = 56, coords = { 0.134766, 0.238281, 0.546875, 0.656250 } },
  rune                   = { w = 40, h = 56, coords = { 0.273438, 0.351562, 0.546875, 0.656250 } },
  shard                  = { w = 39, h = 56, coords = { 0.398438, 0.474609, 0.546875, 0.656250 } },
}

-- PhoenixUI_Frames: 512x512 RGBA, pad 4px. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.frames = {
  file = ROOT .. "PhoenixUI_Frames",
  nameplate              = { w = 474, h = 38, coords = { 0.013672, 0.939453, 0.007812, 0.082031 }, left = 6, right = 10, top = 4, bottom = 4 },
  nameplate_notch        = { w = 47, h = 60, coords = { 0.007812, 0.099609, 0.097656, 0.214844 } },
  crest_elite            = { w = 116, h = 124, coords = { 0.125000, 0.351562, 0.097656, 0.339844 }},
  crest_rare             = { w = 114, h = 124, coords = { 0.384766, 0.607422, 0.097656, 0.339844 }},
  crest_boss             = { w = 111, h = 124, coords = { 0.644531, 0.861328, 0.097656, 0.339844 }},
  crest_elite_s          = { w = 56, h = 56, coords = { 0.007812, 0.117188, 0.355469, 0.464844 }},
  crest_rare_s           = { w = 56, h = 56, coords = { 0.132812, 0.242188, 0.355469, 0.464844 }},
  crest_rareelite_s      = { w = 56, h = 56, coords = { 0.257812, 0.367188, 0.355469, 0.464844 }},
  crest_boss_s           = { w = 56, h = 56, coords = { 0.382812, 0.492188, 0.355469, 0.464844 }},
  party_frame            = { w = 436, h = 55, coords = { 0.011719, 0.863281, 0.480469, 0.587891 }, left = 8, right = 8, top = 5, bottom = 5 },
  party_ring             = { w = 93, h = 96, coords = { 0.009766, 0.191406, 0.603516, 0.791016 }, holeX = 0.4936, holeY = 0.4897, holeR = 0.3414 },
  raid_cell              = { w = 239, h = 89, coords = { 0.210938, 0.677734, 0.603516, 0.777344 }, inset = 22 },
  leader_feather         = { w = 48, h = 60, coords = { 0.695312, 0.789062, 0.603516, 0.720703 }},
}

-- PhoenixUI_Panels: 1024x512 RGBA, pad 4px. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.panels = {
  file = ROOT .. "PhoenixUI_Panels",
  minimap_ring           = { w = 269, h = 290, coords = { 0.013672, 0.276367, 0.007812, 0.574219 } },
  bag_panel              = { w = 289, h = 329, coords = { 0.294922, 0.577148, 0.007812, 0.650391 }, left = 40, right = 40, top = 40, bottom = 40 },
  tooltip                = { w = 290, h = 224, coords = { 0.585938, 0.869141, 0.007812, 0.445312 }, left = 90, right = 25, top = 74, bottom = 25 },
  chat_frame             = { w = 288, h = 154, coords = { 0.004883, 0.286133, 0.666016, 0.966797 }, left = 112, right = 22, top = 30, bottom = 18 },
  bag_slot               = { w = 62, h = 64, coords = { 0.295898, 0.356445, 0.666016, 0.791016 }, inset = 6 },
  bag_clasp              = { w = 90, h = 64, coords = { 0.368164, 0.456055, 0.666016, 0.791016 }, anchor = "TOP" },
}

-- PhoenixUI_Modules: 1024x512 RGBA, pad 4px. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.modules = {
  file = ROOT .. "PhoenixUI_Modules",
  macro_panel            = { w = 159, h = 212, coords = { 0.003906, 0.159180, 0.007812, 0.421875 }, left = 20, right = 20, top = 20, bottom = 20 },
  dm_window              = { w = 256, h = 155, coords = { 0.167969, 0.417969, 0.007812, 0.310547 }, left = 22, right = 22, top = 22, bottom = 22 },
  quick_ring             = { w = 111, h = 112, coords = { 0.425781, 0.534180, 0.007812, 0.226562 } },
  dm_timer               = { w = 256, h = 105, coords = { 0.542969, 0.792969, 0.007812, 0.212891 } },
  toast                  = { w = 256, h = 84, coords = { 0.003906, 0.253906, 0.437500, 0.601562 }, left = 64, right = 16, top = 16, bottom = 16 },
  gal_cell_sel           = { w = 88, h = 76, coords = { 0.261719, 0.347656, 0.437500, 0.585938 } },
  reminder_banner        = { w = 254, h = 64, coords = { 0.356445, 0.604492, 0.437500, 0.562500 } },
  reminder_icon          = { w = 79, h = 64, coords = { 0.613281, 0.690430, 0.437500, 0.562500 } },
  dm_death_row           = { w = 128, h = 64, coords = { 0.699219, 0.824219, 0.437500, 0.562500 }, left = 8, right = 8, top = 8, bottom = 8 },
  gal_cell               = { w = 68, h = 62, coords = { 0.832031, 0.898438, 0.437500, 0.558594 }, left = 4, right = 4, top = 4, bottom = 4 },
  plug_card              = { w = 320, h = 60, coords = { 0.003906, 0.316406, 0.617188, 0.734375 }, left = 12, right = 12, top = 12, bottom = 12 },
  mplus_bar              = { w = 256, h = 56, coords = { 0.324219, 0.574219, 0.617188, 0.726562 }, left = 24, right = 24, top = 16, bottom = 16 },
  dm_self                = { w = 256, h = 52, coords = { 0.582031, 0.832031, 0.617188, 0.718750 }, left = 6, right = 6, top = 6, bottom = 6 },
  cdm_icon               = { w = 48, h = 48, coords = { 0.839844, 0.886719, 0.617188, 0.710938 } },
  affix_frame            = { w = 47, h = 48, coords = { 0.894531, 0.940430, 0.617188, 0.710938 } },
  btn_primary            = { w = 128, h = 48, coords = { 0.003906, 0.128906, 0.750000, 0.843750 }, left = 16, right = 16, top = 12, bottom = 12 },
  btn_secondary          = { w = 128, h = 48, coords = { 0.136719, 0.261719, 0.750000, 0.843750 }, left = 16, right = 16, top = 12, bottom = 12 },
  mplus_skull            = { w = 32, h = 44, coords = { 0.269531, 0.300781, 0.750000, 0.835938 } },
  dm_skull               = { w = 39, h = 44, coords = { 0.308594, 0.346680, 0.750000, 0.835938 } },
  badge_enabled          = { w = 32, h = 32, coords = { 0.355469, 0.386719, 0.750000, 0.812500 } },
  badge_disabled         = { w = 31, h = 32, coords = { 0.394531, 0.424805, 0.750000, 0.812500 } },
  badge_error            = { w = 32, h = 32, coords = { 0.433594, 0.464844, 0.750000, 0.812500 } },
  badge_loading          = { w = 31, h = 32, coords = { 0.472656, 0.502930, 0.750000, 0.812500 } },
  dm_rank                = { w = 31, h = 32, coords = { 0.511719, 0.541992, 0.750000, 0.812500 } },
  dm_spec_frame          = { w = 32, h = 32, coords = { 0.550781, 0.582031, 0.750000, 0.812500 } },
  aura_slot1             = { w = 32, h = 31, coords = { 0.589844, 0.621094, 0.750000, 0.810547 } },
  aura_slot2             = { w = 32, h = 32, coords = { 0.628906, 0.660156, 0.750000, 0.812500 } },
  aura_slot3             = { w = 32, h = 32, coords = { 0.667969, 0.699219, 0.750000, 0.812500 } },
  aura_slot4             = { w = 32, h = 32, coords = { 0.707031, 0.738281, 0.750000, 0.812500 } },
  aura_slot5             = { w = 32, h = 32, coords = { 0.746094, 0.777344, 0.750000, 0.812500 } },
  aura_slot6             = { w = 32, h = 31, coords = { 0.785156, 0.816406, 0.750000, 0.810547 } },
  aura_tint              = { w = 32, h = 32, coords = { 0.824219, 0.855469, 0.750000, 0.812500 } },
  dm_chip                = { w = 72, h = 32, coords = { 0.863281, 0.933594, 0.750000, 0.812500 }, left = 14, right = 14, top = 10, bottom = 10 },
  mem_pill               = { w = 72, h = 32, coords = { 0.003906, 0.074219, 0.859375, 0.921875 }, left = 14, right = 14, top = 10, bottom = 10 },
  dm_reset               = { w = 32, h = 27, coords = { 0.082031, 0.113281, 0.859375, 0.912109 } },
  toggle_off             = { w = 48, h = 26, coords = { 0.121094, 0.167969, 0.859375, 0.910156 } },
  toggle_on              = { w = 48, h = 23, coords = { 0.175781, 0.222656, 0.859375, 0.904297 } },
  dm_header              = { w = 256, h = 24, coords = { 0.230469, 0.480469, 0.859375, 0.906250 }, left = 12, right = 12, top = 6, bottom = 6 },
  tick                   = { w = 4, h = 18, coords = { 0.488281, 0.492188, 0.865234, 0.900391 } },
  chest_1                = { w = 22, h = 22, coords = { 0.500000, 0.521484, 0.859375, 0.902344 } },
  chest_2                = { w = 44, h = 22, coords = { 0.529297, 0.572266, 0.859375, 0.902344 } },
  chest_3                = { w = 66, h = 22, coords = { 0.580078, 0.644531, 0.859375, 0.902344 } },
  chest_pip              = { w = 16, h = 19, coords = { 0.652344, 0.667969, 0.859375, 0.896484 } },
  dm_track               = { w = 256, h = 16, coords = { 0.675781, 0.925781, 0.859375, 0.890625 }, left = 8, right = 8, top = 6, bottom = 6 },
  dm_value_back          = { w = 128, h = 16, coords = { 0.003906, 0.128906, 0.937500, 0.968750 } },
  row_sep                = { w = 256, h = 10, coords = { 0.136719, 0.386719, 0.937500, 0.957031 }, left = 8, right = 8, top = 0, bottom = 0 },
}

-- PhoenixUI_V9: 1024x512 RGBA, 37 pieces. © 2026 VortexQ8 - Phoenix UI - All rights reserved
KIT.v9 = {
  file = ROOT .. "PhoenixUI_V9",
  arena_ring             = { w = 47, h = 48, coords = { 0.902344, 0.948242, 0.246094, 0.339844 } },
  codex                  = { w = 224, h = 316, coords = { 0.222656, 0.441406, 0.007812, 0.625000 }, left = 28, right = 20, top = 44, bottom = 20 },
  codex_tab              = { w = 128, h = 44, coords = { 0.839844, 0.964844, 0.007812, 0.093750 }, left = 44, right = 12, top = 10, bottom = 10 },
  debuff_bleed           = { w = 32, h = 32, coords = { 0.902344, 0.933594, 0.433594, 0.496094 } },
  debuff_buff            = { w = 32, h = 32, coords = { 0.582031, 0.613281, 0.847656, 0.910156 } },
  debuff_curse           = { w = 32, h = 32, coords = { 0.957031, 0.988281, 0.324219, 0.386719 } },
  debuff_disease         = { w = 32, h = 32, coords = { 0.941406, 0.972656, 0.402344, 0.464844 } },
  debuff_magic           = { w = 32, h = 32, coords = { 0.957031, 0.988281, 0.246094, 0.308594 } },
  debuff_poison          = { w = 32, h = 32, coords = { 0.902344, 0.933594, 0.355469, 0.417969 } },
  extra_action           = { w = 192, h = 98, coords = { 0.003906, 0.191406, 0.728516, 0.919922 } },
  loot_panel             = { w = 150, h = 292, coords = { 0.449219, 0.595703, 0.007812, 0.578125 }, left = 18, right = 18, top = 44, bottom = 18 },
  loot_row               = { w = 256, h = 52, coords = { 0.644531, 0.894531, 0.847656, 0.949219 }, left = 12, right = 12, top = 12, bottom = 12 },
  map_border             = { w = 216, h = 360, coords = { 0.003906, 0.214844, 0.007812, 0.710938 }, left = 40, right = 40, top = 64, bottom = 24 },
  mark_bleed             = { w = 10, h = 16, coords = { 0.499023, 0.508789, 0.593750, 0.625000 } },
  mark_buff              = { w = 14, h = 16, coords = { 0.981445, 0.995117, 0.402344, 0.433594 } },
  mark_curse             = { w = 16, h = 15, coords = { 0.621094, 0.636719, 0.847656, 0.876953 } },
  mark_disease           = { w = 16, h = 16, coords = { 0.472656, 0.488281, 0.593750, 0.625000 } },
  mark_magic             = { w = 13, h = 16, coords = { 0.981445, 0.994141, 0.449219, 0.480469 } },
  mark_poison            = { w = 10, h = 16, coords = { 0.452148, 0.461914, 0.593750, 0.625000 } },
  micro_hover            = { w = 32, h = 31, coords = { 0.642578, 0.673828, 0.511719, 0.572266 } },
  micro_normal           = { w = 31, h = 32, coords = { 0.603516, 0.633789, 0.511719, 0.574219 } },
  micro_pressed          = { w = 31, h = 32, coords = { 0.681641, 0.711914, 0.511719, 0.574219 } },
  obj_bullet             = { w = 24, h = 18, coords = { 0.972656, 0.996094, 0.195312, 0.230469 } },
  quest_campaign         = { w = 20, h = 24, coords = { 0.974609, 0.994141, 0.007812, 0.054688 } },
  quest_daily            = { w = 23, h = 24, coords = { 0.972656, 0.995117, 0.070312, 0.117188 } },
  quest_world            = { w = 24, h = 24, coords = { 0.972656, 0.996094, 0.132812, 0.179688 } },
  queue_pop              = { w = 360, h = 137, coords = { 0.222656, 0.574219, 0.642578, 0.910156 } },
  ready_check            = { w = 256, h = 120, coords = { 0.582031, 0.832031, 0.595703, 0.830078 } },
  roll_greed             = { w = 32, h = 32, coords = { 0.759766, 0.791016, 0.511719, 0.574219 } },
  roll_need              = { w = 32, h = 32, coords = { 0.720703, 0.751953, 0.511719, 0.574219 } },
  roll_pass              = { w = 32, h = 32, coords = { 0.798828, 0.830078, 0.085938, 0.148438 } },
  roll_transmog          = { w = 31, h = 32, coords = { 0.798828, 0.829102, 0.007812, 0.070312 } },
  talent_node            = { w = 48, h = 49, coords = { 0.839844, 0.886719, 0.234375, 0.330078 } },
  talent_node_sel        = { w = 52, h = 54, coords = { 0.839844, 0.890625, 0.111328, 0.216797 } },
  talent_square          = { w = 64, h = 62, coords = { 0.902344, 0.964844, 0.109375, 0.230469 }, left = 8, right = 8, top = 8, bottom = 8 },
  trinket_socket         = { w = 24, h = 23, coords = { 0.003906, 0.027344, 0.937500, 0.982422 } },
  xp_bar                 = { w = 448, h = 30, coords = { 0.199219, 0.636719, 0.929688, 0.988281 }, left = 40, right = 40, top = 10, bottom = 10 },
}

A.FILL = ROOT .. "PhoenixBarFill"
A.CAST_FILL = ROOT .. "PhoenixCastFill"
A.DEFAULTS["cast.capScale"] = 1.4
A.DEFAULTS["bar.capScale"] = 1.0

local function general() return ns.modules and ns.modules.General and ns.modules.General.db end
-- game-frame art on (the "phoenix-wings" look)
function A.GameArt()
    local g = general()
    if not g then return true end
    return g.artKit ~= false and (g.artPreset or "phoenix-wings") == "phoenix-wings"
end

function A:KitPiece(sheet, key)
    local s = KIT[sheet]
    if not s then return nil end
    local p = A.ResolveToken("atlas." .. sheet .. "." .. key)
    if p then return p end
    local o = A.ResolveToken("atlas." .. sheet)
    if o and o[key] then return o[key], o.file end
    return s[key], s.file
end

local SLICE = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
local function slice(tex, p, scale)
    if not tex.SetTextureSliceMargins then return end
    local l, r, t, b = p.left or p.inset, p.right or p.inset, p.top or p.inset, p.bottom or p.inset
    if l then
        tex:SetTextureSliceMargins(l * scale, (t or 0) * scale, (r or 0) * scale, (b or 0) * scale)
        if SLICE and tex.SetTextureSliceMode then tex:SetTextureSliceMode(SLICE) end
    elseif tex.ClearTextureSlice then
        tex:ClearTextureSlice()
    end
end

-- tex shows sheet piece `key` (scale: margins in source pixels times scale)
function A:PaintKit(tex, sheet, key, scale)
    local p, file = self:KitPiece(sheet, key)
    if not (tex and p) then return false end
    tex:SetTexture(p.file or file)
    tex:SetTexCoord(unpack(p.coords))
    slice(tex, p, scale or 0.5)
    return true
end

local dressed = setmetatable({}, { __mode = "k" }) -- frame -> { [slot] = texture }

-- MODULES_SPEC shared rule: the painted glass is translucent, so a #0E0B0A 92% fill sits under it, inset 3
local function backdrop(t, on)
    if not on then if t.backdrop then t.backdrop:Hide() end return end
    local bd = t.backdrop
    if not bd then bd = t.holder:CreateTexture(nil, "BACKGROUND", nil, -8); t.backdrop = bd end
    bd:SetColorTexture(0x0E / 255, 0x0B / 255, 0x0A / 255, 0.92)
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT", t, "TOPLEFT", 3, -3)
    bd:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -3, 3)
    bd:Show()
end

-- opts: slot (default piece), out (outset px, or { l, r, t, b }), layer, level (+/- frame levels), scale, alpha
function A:Dress(frame, sheet, key, opts)
    if not frame then return nil end
    opts = opts or {}
    local slot = opts.slot or key
    local set = dressed[frame]
    if not set then set = {}; dressed[frame] = set end
    local t = set[slot]
    if not t and InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        -- QA-05: a new holder on a secure button or header waits for the end of combat (existing ones only swap coords)
        if ns.Combat and ns.Combat.Run then
            ns.Combat:Run("art." .. tostring(frame) .. "." .. slot, function() A:Dress(frame, sheet, key, opts) end)
        end
        return nil
    end
    if not t then
        local holder = CreateFrame("Frame", nil, frame)
        holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() + (opts.level or 1)))
        t = holder:CreateTexture(nil, opts.layer or "OVERLAY")
        t.holder = holder
        set[slot] = t
    end
    t.sheet, t.key, t.opts, t.undressed = sheet, key, opts, nil
    local on = A.GameArt() and self:PaintKit(t, sheet, key, opts.scale)
    t.holder:SetShown(on and true or false)
    if not on then return t end
    local o = opts.out or 0
    local l, r, tp, b = o, o, o, o
    if type(o) == "table" then l, r, tp, b = o[1], o[2], o[3], o[4] end
    t:ClearAllPoints()
    if opts.size then
        t:SetSize(opts.size[1], opts.size[2])
        t:SetPoint(opts.point or "CENTER", opts.anchor or frame, opts.relPoint or opts.point or "CENTER", opts.x or 0, opts.y or 0)
    else
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", -l, tp)
        t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", r, -b)
    end
    t:SetVertexColor(1, 1, 1, opts.alpha or 1)
    t:SetBlendMode(opts.blend or "BLEND")
    backdrop(t, opts.backdrop)
    return t
end

function A:Undress(frame, slot)
    local set = dressed[frame]
    if not set then return end
    for k, t in pairs(set) do if not slot or k == slot then t.holder:Hide(); t.undressed = true end end
end

-- every dressed frame again (theme / look change, a plugin override)
function A:Redress()
    for frame, set in pairs(dressed) do
        for _, t in pairs(set) do if not t.undressed then self:Dress(frame, t.sheet, t.key, t.opts) end end
    end
end

---------------------------------------------------------------- pieces by state
-- classification -> portrait ring / small crest (no crest for normal units)
A.RING = { worldboss = "ring_boss", elite = "ring_elite", rare = "ring_rare", rareelite = "ring_rareelite" }
A.CREST = { worldboss = "crest_boss_s", elite = "crest_elite_s", rare = "crest_rare_s", rareelite = "crest_rareelite_s" }

function A.Classification(unit)
    if not (unit and UnitExists and UnitExists(unit)) then return "normal" end
    local ok, c = pcall(UnitClassification, unit)
    if ok and type(c) == "string" and (not issecretvalue or not issecretvalue(c)) then return c end
    return "normal"
end

-- size: the portrait width; boss frames (54 px) take the compact boss ring below 64 px (v9.1)
function A.RingFor(unitKey, unit, size)
    if unitKey == "player" then return "ring_player" end
    local r = A.RING[A.Classification(unit)] or "ring_target"
    if r == "ring_boss" and size and size < 64 then return "ring_boss_s" end
    return r
end

-- unit frame: health and power frames with caps, portrait ring by classification
function A:DressUnit(f, unit)
    if f.Health then
        self:Dress(f.Health, "bars", "health_frame", { out = 2 })
    end
    if f.Power and f.Power:IsShown() then
        self:Dress(f.Power, "bars", "power_frame", { out = 2 })
    elseif f.Power then
        self:Undress(f.Power)
    end
    if f.PortraitHolder and f.PortraitHolder:IsShown() then
        local w = f.PortraitHolder:GetWidth() or 0
        self:Dress(f.PortraitHolder, "portraits", A.RingFor(f.unitKey, unit, w), { slot = "ring", out = math.floor(w * 0.45 + 0.5) })
    elseif f.PortraitHolder then
        self:Undress(f.PortraitHolder)
    end
end

-- class power pip (StatusBar): a gem over it; lit / unlit follow the fill, tinted with the resource colour
function A:DressPip(p, kind, lit, r, g, b)
    local key = kind == "Runes" and "rune" or kind == "SoulShards" and "shard" or (lit and "gem_lit" or "gem_unlit")
    local t = self:Dress(p, "bars", key, { slot = "gem", out = 2, level = 2 })
    if t and r and t.holder:IsShown() then t:SetVertexColor(r, g, b, 1) end
    return t
end

-- action button: frame by state ("normal" | "proc" | "pressed" | "ready"); stance and pet buttons use the small set
function A:DressAction(b, state, small)
    local key = (small and "stance_" or "action_") .. (state or "normal")
    local w = b.GetWidth and b:GetWidth() or 36
    return self:Dress(b, "actions", key, { slot = "border", out = math.floor(w * 0.12 + 0.5), scale = w / 120 * 1.6 })
end

-- cast bar: frame around the bar, ember cap (interruptible) and steel cap (locked) at capScale x bar height
function A:DressCast(_, bar, h)
    self:Dress(bar, "actions", "cast_frame", { out = { 6, 6, 4, 4 }, scale = math.max(0.25, h / 78 * 1.4) })
    local cs = (A:Token("cast.capScale") or 1.4) * h
    local ember = self:Dress(bar, "actions", "cast_cap_ember", { slot = "cap", size = { cs * 0.93, cs }, point = "RIGHT", relPoint = "LEFT", x = cs * 0.3, level = 3 })
    local steel = self:Dress(bar, "actions", "cast_cap_steel", { slot = "lock", size = { cs * 0.93, cs }, point = "RIGHT", relPoint = "LEFT", x = cs * 0.3, level = 3 })
    return ember, steel
end

-- interruptible state onto the caps; ni may be secret, so it only ever reaches SetAlphaFromBoolean
function A:CastLock(bar, ni)
    local set = dressed[bar]
    if not (set and set.cap and set.lock) then return end
    if not (issecretvalue and issecretvalue(ni)) then
        set.cap:SetAlpha(ni and 0 or 1); set.lock:SetAlpha(ni and 1 or 0)
    elseif set.cap.SetAlphaFromBoolean then
        set.cap:SetAlphaFromBoolean(ni, 0, 1); set.lock:SetAlphaFromBoolean(ni, 1, 0)
    end
end

-- nameplate: frame, notch at the left (1.25x plate height) and the classification crest
function A:DressPlate(p, h, unit)
    local bar = p.Health or p.health or p.bar
    if not bar then return end
    self:Dress(bar, "frames", "nameplate", { out = { 2, 3, 2, 2 }, scale = math.max(0.25, h / 38 * 1.4) })
    local nh = h * 1.25
    self:Dress(bar, "frames", "nameplate_notch", { slot = "notch", size = { nh * 0.78, nh }, point = "RIGHT", relPoint = "LEFT", x = nh * 0.25, level = 2 })
    local crest = A.CREST[A.Classification(unit)]
    if crest then
        self:Dress(bar, "frames", crest, { slot = "crest", size = { 16, 16 }, point = "BOTTOM", relPoint = "TOP", y = -2, level = 3 })
    else
        self:Undress(bar, "crest")
    end
end

-- group button: party frame or raid cell (out of the button, under its text)
function A:DressGroup(b, raid)
    if raid then return self:Dress(b, "frames", "raid_cell", { slot = "group", out = 3, scale = 0.35 }) end
    return self:Dress(b, "frames", "party_frame", { slot = "group", out = 3, scale = 0.6 })
end

function A:DressMinimap(mm, w)
    return self:Dress(mm, "panels", "minimap_ring", { slot = "ring", size = { w * 1.18, w * 1.27 }, y = -w * 0.02, level = 2 })
end
function A:DressTooltip(tt) return self:Dress(tt, "panels", "tooltip", { slot = "panel", out = 2, scale = 0.35, layer = "BACKGROUND", level = 0 }) end
function A:DressChat(cf) return self:Dress(cf, "panels", "chat_frame", { slot = "panel", out = 4, scale = 0.4, layer = "BACKGROUND", level = 0 }) end
function A:DressBags(win)
    self:Dress(win, "panels", "bag_panel", { slot = "panel", out = 4, scale = 0.5, layer = "BACKGROUND", level = 0 })
    return self:Dress(win, "panels", "bag_clasp", { slot = "clasp", size = { 60, 43 }, point = "CENTER", relPoint = "TOP", level = 3 })
end
function A:DressBagSlot(btn) return self:Dress(btn, "panels", "bag_slot", { slot = "slot", out = 2, scale = 0.6, layer = "BACKGROUND", level = 0 }) end

-- the default status-bar fill: greyscale baked art, tinted by the class / power / reaction colour the bar already gets
function A.BarFill(cast)
    if not A.GameArt() then return nil end
    local f = cast and A:Token("texture.castFill") or A:Token("texture.barFill")
    return f or (cast and A.CAST_FILL or A.FILL)
end
A.DEFAULTS["texture.barFill"] = A.FILL
A.DEFAULTS["texture.castFill"] = A.CAST_FILL

---------------------------------------------------------------- v8.1 module pieces (THEME_API §7.04, MODULES_SPEC.md)
A.SLOT = { -- slot -> modules atlas key; tokens "atlas.modules.<key>" swap the art
    ["DamageMeter.window"] = "dm_window", ["DamageMeter.header"] = "dm_header", ["DamageMeter.chip"] = "dm_chip",
    ["DamageMeter.reset"] = "dm_reset", ["DamageMeter.row.track"] = "dm_track", ["DamageMeter.row.self"] = "dm_self",
    ["DamageMeter.row.rank"] = "dm_rank", ["DamageMeter.row.specFrame"] = "dm_spec_frame",
    ["DamageMeter.row.valueBacking"] = "dm_value_back", ["DamageMeter.timer"] = "dm_timer",
    ["DamageMeter.death.row"] = "dm_death_row", ["DamageMeter.death.skull"] = "dm_skull",
    ["IconGallery.cell"] = "gal_cell", ["IconGallery.selected"] = "gal_cell_sel", ["Plugins.card"] = "plug_card",
    ["Plugins.badge.enabled"] = "badge_enabled", ["Plugins.badge.disabled"] = "badge_disabled",
    ["Plugins.badge.error"] = "badge_error", ["Plugins.badge.loading"] = "badge_loading", ["Plugins.memory"] = "mem_pill",
    ["Plugins.toggle.on"] = "toggle_on", ["Plugins.toggle.off"] = "toggle_off",
    ["Plugins.button.primary"] = "btn_primary", ["Plugins.button.secondary"] = "btn_secondary",
    ["GroupFrames.indicator.tint"] = "aura_tint", ["Resources.tick"] = "tick", ["Resources.separator"] = "row_sep",
    ["Cooldowns.icon"] = "cdm_icon", ["Reminders.icon"] = "reminder_icon", ["Reminders.banner"] = "reminder_banner",
    ["MythicPlus.bar"] = "mplus_bar", ["MythicPlus.pip"] = "chest_pip", ["MythicPlus.deaths"] = "mplus_skull",
    ["MythicPlus.affix"] = "affix_frame", ["MythicPlus.forces"] = "dm_track", ["Toast.frame"] = "toast",
    ["Quickdraw.ring"] = "quick_ring", ["Macros.panel"] = "macro_panel",
}
for i = 1, 6 do A.SLOT["GroupFrames.indicator" .. i] = "aura_slot" .. i end
for i = 1, 3 do A.SLOT["MythicPlus.chest" .. i] = "chest_" .. i end

-- a module slot on a frame (opts as Dress; panels pass backdrop = true)
function A:DressSlot(frame, slot, opts)
    local key = A.SLOT[slot]
    if not key then return nil end
    opts = opts or {}
    opts.slot = opts.slot or slot
    return self:Dress(frame, "modules", key, opts)
end

-- a texture of the frame's own shows a module piece (rows, badges, ticks: drawn parts, not overlays)
function A:PaintSlot(tex, slot, scale)
    local key = A.SLOT[slot]
    return key and A.GameArt() and self:PaintKit(tex, "modules", key, scale or 1) or false
end

-- the plugin loading badge turns in 90° steps on a 0.25 s C_Timer while loading; never an OnUpdate
local spinning = setmetatable({}, { __mode = "k" })
function A:SpinBadge(tex, on)
    if spinning[tex] then spinning[tex]:Cancel(); spinning[tex] = nil end
    if tex.SetRotation then tex:SetRotation(0) end
    if not (on and C_Timer and C_Timer.NewTicker and tex.SetRotation) then return end
    local step = 0
    spinning[tex] = C_Timer.NewTicker(0.25, function()
        step = (step + 1) % 4
        tex:SetRotation(step * math.pi / 2)
    end)
end

-- text on class-coloured bars: 1 px black outline (MODULES_SPEC shared rules)
function A.OutlineText(fs)
    if not (fs and fs.GetFont and A.GameArt()) then return end
    local font, size, flags = fs:GetFont()
    if font and not (flags or ""):find("OUTLINE") then fs:SetFont(font, size, "OUTLINE") end
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1) end
end

if ns.Events and ns.Events.Listen then
    ns.Events:Listen("PUI_THEME_CHANGED", KIT, function() A:Redress() end)
end
