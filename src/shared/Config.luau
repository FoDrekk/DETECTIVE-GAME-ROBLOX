--!strict
--[[
	Config
	Global, non-case configuration values.
	Case-specific data lives in src/config.
]]

local Config = {}

Config.Game = {
	DefaultPhase = "MainMenu" :: string,
	AutoStartCase = "CASE-001",
}

Config.Environment = {
	-- Authored office model name under Workspace.
	OfficeModelName = "Office",
	-- Root objects removed at runtime so the authored environment is the only
	-- ground. Names, not references, so this stays data-driven.
	DefaultGroundNames = { "Baseplate", "SpawnLocation" },
}

Config.Logging = {
	-- Minimum severity emitted at runtime: "DEBUG" | "INFO" | "WARN" | "ERROR".
	MinSeverity = "INFO" :: string,
}

Config.Interaction = {
	-- Maximum distance (studs) at which an interactable can be prompted.
	MaxPromptDistance = 12,
	-- How often the client refreshes nearby interactables (seconds).
	ScanInterval = 0.15,
	-- Default interaction key (KeyboardKeyCode enum name).
	PrimaryKey = "E",
	-- Key to dismiss the evidence panel.
	ClosePanelKey = "Escape",
	-- Key to open/close the case timeline.
	TimelineKey = "T",
	-- Key to open/close the case file (unlocked statements/reasoning).
	CaseFileKey = "C",
	-- Key to open the accusation picker once every objective is complete
	-- (Phase 2L introduced concluding; Phase 2N makes [Q] open the accusation
	-- picker rather than conclude directly). Only does anything once the
	-- server has told the client every objective is done; the server
	-- re-validates eligibility and the chosen accusation regardless.
	ConcludeKey = "Q",
	-- Gamepad equivalents (KeyCode enum names). A stays jump and confirms
	-- the selected button in GUI navigation, so it is deliberately unused.
	Gamepad = {
		Interact = "ButtonX",
		CaseFile = "ButtonY",
		Timeline = "ButtonL1",
		Accuse = "ButtonR1",
		Close = "ButtonB",
	},
}

-- M6: audio. Every asset is from a Roblox-licensed partner library
-- (ProSoundEffects, APM Music) and was verified to load before being added.
-- Volumes are per sound, before the ambience/effects group volumes.
Config.Audio = {
	Ambience = {
		-- Rain On Window 3 (ProSoundEffects), 53.7s loop.
		Rain = { id = "rbxassetid://9112856768", volume = 0.35 },
		-- Hollow Rumble 1 (ProSoundEffects): deep, dark, steady drone, 106s.
		Drone = { id = "rbxassetid://9112795463", volume = 0.18 },
	},
	Cues = {
		-- Document Movement, Thick Papers (ProSoundEffects), 4.1s.
		EvidenceDiscovered = { id = "rbxassetid://9125490663", volume = 0.6 },
		-- Keyboard key press (ProSoundEffects), 0.5s: dialogue and UI ticks.
		Tick = { id = "rbxassetid://9113145819", volume = 0.35 },
		-- "Morbid Discovery" (APM Music), 12.7s: a contradiction or
		-- deduction clicks into place.
		Reasoning = { id = "rbxassetid://1838954912", volume = 0.45 },
		-- "Case Cracker - Sting" (APM Music), 8s.
		VerdictCorrect = { id = "rbxassetid://1842853798", volume = 0.6 },
		-- Piano Keys Impact 7 (ProSoundEffects), 14.9s, low and ominous.
		VerdictWrong = { id = "rbxassetid://9117315051", volume = 0.55 },
	},
	-- Ambience drops to this fraction behind dialogue and the closing screen.
	DuckedAmbience = 0.35,
}

Config.Camera = {
	DefaultDistance = 12,
	DefaultHeight = 2.5,
	ExamineBlendTime = 0.6,
	TransitionBlendTime = 0.35,
}

Config.UI = {}

Config.UI.Theme = {
	Background = Color3.fromRGB(12, 13, 16),
	Panel = Color3.fromRGB(18, 20, 24),
	PanelStroke = Color3.fromRGB(48, 52, 60),
	Accent = Color3.fromRGB(198, 166, 100),
	TextPrimary = Color3.fromRGB(232, 232, 228),
	TextSecondary = Color3.fromRGB(150, 154, 160),
	PromptBackground = Color3.fromRGB(10, 11, 13),
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
}

return Config
