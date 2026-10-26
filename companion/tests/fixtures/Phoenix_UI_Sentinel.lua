
PhoenixUISentinelDB = {
	["installId"] = "0123456789abcdef0123456789abcdef",
	["session"] = 3,
	["optIn"] = true,
	["incidents"] = {
		["1a2b3c4d"] = {
			["hash"] = "1a2b3c4d",
			["kind"] = "error",
			["module"] = "Sentinel",
			["message"] = "Interface/AddOns/Phoenix_UI_Sentinel/Slash.lua:12: induced test error",
			["stack"] = "[string \"@Interface/AddOns/Phoenix_UI_Sentinel/Slash.lua\"]:12: in function <...>\n[C]: ?",
			["locals"] = "path = \"C:\\Users\\Vorte\\Desktop\"\nmail = \"me@example.com\"",
			["count"] = 2,
			["firstSeen"] = 1790000000,
			["lastSeen"] = 1790000100,
			["session"] = 2,
			["lastSession"] = 3,
			["addonVersion"] = "2.0.0-alpha.1",
			["interface"] = 120105,
			["build"] = 70575,
			["locale"] = "enUS",
			["severity"] = "S2",
			["track"] = "dev",
			["context"] = {
				["combat"] = false,
				["zone"] = "Dornogal",
				["group"] = 0,
			},
		},
		["9f8e7d6c"] = {
			["hash"] = "9f8e7d6c",
			["kind"] = "taint",
			["module"] = "Core",
			["message"] = "ADDON_ACTION_BLOCKED: Phoenix_UI tried to call CastSpellByName",
			["stack"] = "",
			["count"] = 1,
			["firstSeen"] = 1790000200,
			["lastSeen"] = 1790000200,
			["session"] = 3,
			["addonVersion"] = "2.0.0-alpha.1",
			["interface"] = 120105,
			["build"] = 70575,
			["locale"] = "enUS",
		},
	},
	["heartbeats"] = {
		{
			["version"] = "2.0.0-alpha.1",
			["build"] = 70575,
			["interface"] = 120105,
			["track"] = "dev",
			["modules"] = {
			},
			["errors"] = 2,
			["zeroError"] = false,
			["cpu"] = {
			},
			["session"] = 2,
			["at"] = 1790000050,
		}, -- [1]
	},
	["tests"] = {
		{
			["session"] = 3,
			["at"] = 1790000300,
			["summary"] = "34 passed, 0 failed",
			["failed"] = {
			},
			["ms"] = 41.5,
			["version"] = "2.0.0-alpha.1",
			["build"] = 70575,
		}, -- [1]
	},
	["sessionErrors"] = {
		[3] = {
			["1a2b3c4d"] = 2,
		},
	},
}
