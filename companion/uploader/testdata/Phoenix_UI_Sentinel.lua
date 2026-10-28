
PhoenixUISentinelDB = {
	["installId"] = "aa11bb22cc33dd44",
	["optIn"] = true,
	["session"] = 9,
	["outbox"] = {
		["schema"] = 2,
		["flavor"] = "forever",
		["session"] = 9,
		["installId"] = "aa11bb22cc33dd44",
		["addons"] = {
			{
				["name"] = "WeakAuras",
				["version"] = "5.19.1",
				["enabled"] = true,
				["loaded"] = true,
			}, -- [1]
		},
		["reports"] = {
			{
				["id"] = "aa11bb22cc33dd44-9-123",
				["hash"] = "0000abcd",
				["kind"] = "error",
				["message"] = "Interface/AddOns/Phoenix_UI/Core/x.lua:1: boom",
				["count"] = 3,
				["interface"] = 16020,
				["flavor"] = "forever",
				["addon"] = "Phoenix_UI",
				["source"] = "sentinel",
				["context"] = {
					["zone"] = "Elwynn",
				},
			}, -- [1]
		},
	},
}
