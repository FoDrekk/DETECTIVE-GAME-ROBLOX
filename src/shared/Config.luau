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
