--!strict
--[[
	Config
	Global, non-case configuration values.
	Case-specific data lives in src/config.
]]

local Config = {}

Config.Game = {
	AutoStartCase = "CASE-001",
	-- Phase 3 (R2): the session is server-wide, so only one investigator per
	-- server. Also set Max Players to 1 in Game Settings when publishing.
	MaxInvestigators = 1,
	FullServerMessage = "This case is a solo investigation, and someone is already on it. "
		.. "Please join again to start your own.",
}

Config.Environment = {
	-- Authored office model name under Workspace.
	OfficeModelName = "Office",
	-- Root objects removed at runtime so the authored environment is the only
	-- ground. Names, not references, so this stays data-driven.
	DefaultGroundNames = { "Baseplate", "SpawnLocation" },
	-- Phase 2P: stale-bake detection. EnvironmentBake.bake() stamps this onto
	-- Workspace.Office once it finishes (Edit mode only); OfficeRoom.start()
	-- compares it against a baked place's own stamp on every boot, live or
	-- Edit. Bump this by hand whenever a change to OfficeRoom/OfficeDetailing/
	-- OfficeInterior/CitySkyline/SuspectSpawner would change what they
	-- generate -- the builders themselves still adopt existing generated
	-- folders unchanged (Baked content is adopted, not rebuilt); this only
	-- warns when that adoption is silently keeping geometry a later bump
	-- never reached. See `815064d` for the incident this exists to catch:
	-- a floor/grounding fix landed in the builders, but the already-baked
	-- `.rbxl` was never re-baked, so the fix never reached the saved place.
	BuilderVersion = 4,
	-- 12:40 AM, after hours (OfficeRoom). Readability first: the local lights
	-- carry the mood, ambient and exposure keep every room playable.
	Night = {
		ClockTime = 0.67,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(40, 42, 50),
		OutdoorAmbient = Color3.fromRGB(38, 44, 62),
		EnvironmentDiffuseScale = 0.25,
		EnvironmentSpecularScale = 0.45,
		ExposureCompensation = 0.4,
		ShadowSoftness = 0.22,
		-- Colour grade: a touch of contrast, slightly desaturated, warm.
		Contrast = 0.1,
		Saturation = -0.12,
		Tint = Color3.fromRGB(255, 247, 238),
		-- Bloom only for things that actually glow (screens, signs, lamps).
		BloomIntensity = 0.5,
		BloomSize = 24,
		BloomThreshold = 1.35,
	},
	-- Interior lighting plan (OfficeInterior). Brightness/Range per fixture;
	-- `shadows` only where a shadow tells you something.
	Interior = {
		Lights = {
			DanielOffice = { brightness = 1.3, range = 18, color = Color3.fromRGB(255, 232, 204), shadows = true },
			MeetingRoom = { brightness = 0.5, range = 16, color = Color3.fromRGB(255, 240, 222) },
			MeetingPendant = { brightness = 2.0, range = 16 },
			Reception = { brightness = 1.1, range = 16, color = Color3.fromRGB(255, 226, 190), shadows = true },
			Lobby = { brightness = 0.7, range = 16, color = Color3.fromRGB(255, 226, 190) },
			OpenPlan = { brightness = 0.7, range = 18, color = Color3.fromRGB(255, 240, 222), shadows = true },
			EastDesks = { brightness = 0.55, range = 16, color = Color3.fromRGB(255, 240, 222) },
			Corridor = { brightness = 0.45, range = 14, color = Color3.fromRGB(230, 232, 255) },
			WestHall = { brightness = 0.5, range = 14, color = Color3.fromRGB(255, 236, 214) },
			Records = { brightness = 0.9, range = 16, color = Color3.fromRGB(206, 222, 255), shadows = true },
		},
		-- The city's light through the north windows.
		CityGlow = { Brightness = 0.55, Range = 16, Color = Color3.fromRGB(150, 172, 226) },
	},
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

-- M6: suspect characters. Body packages are Roblox's free "Man" and "Woman"
-- bundles; every id was checked with MarketplaceService:GetProductInfo
-- (creator Roblox, correct asset type) before being added.
Config.Characters = {
	Bodies = {
		Man = {
			Torso = 86500008,
			LeftArm = 86500054,
			RightArm = 86500036,
			LeftLeg = 86500064,
			RightLeg = 86500078,
		},
		Woman = {
			Torso = 86499666,
			LeftArm = 86499716,
			RightArm = 86499698,
			LeftLeg = 86499753,
			RightLeg = 86499793,
		},
	},
	-- Roblox's default R15 idle (the same one player avatars use).
	IdleAnimation = "rbxassetid://507766388",
	-- Seconds for a suspect to turn toward the player who speaks to them.
	TurnTime = 0.45,
	-- Name tags show only within this many studs.
	NameTagDistance = 26,
}

Config.Camera = {
	ExamineBlendTime = 0.6,
	-- M6: conversation shot, relative to the suspect's face (studs).
	Conversation = {
		Distance = 4.2,
		SideOffset = 1.1,
		Height = 0.4,
		AimDrop = 1.1,
	},
}

-- M6: title screen and the camera drift behind it (world coordinates of the
-- authored office; the shot ping-pongs between From and To).
-- M9: connections the investigator makes.
Config.Reasoning = {
	-- Seconds before another pairing or answer is taken after a miss.
	MissCooldown = 2,
}

-- Phase 5.1: scripted scenes (CutsceneService / CutsceneView).
Config.Cutscene = {
	-- The server ends a scene itself this many seconds after its last shot
	-- if the client never reports reaching the end, so the story can never
	-- wait forever on a client that went quiet.
	EndGrace = 5,
	-- A client reporting the end is believed up to this many seconds early
	-- (clock granularity), never more: an unskippable scene can't be cut
	-- short by claiming it finished.
	EndTolerance = 0.5,
	-- Skipping takes two presses of the primary input within this many
	-- seconds, so a press meant for something else never throws a scene
	-- away.
	SkipConfirmWindow = 2.5,
}

Config.Presentation = {
	Title = {
		Kicker = "A MYSTERY CASE",
		-- Shown until the case briefing arrives with the real title.
		Fallback = "THE LAST CALL",
		Footer = "Best played with headphones.",
	},
	IntroShot = {
		-- Down the dark corridor toward the north window, where Mara stands
		-- with her back to the room and the city beyond the glass (window
		-- centre (-4, 7, -23.8)).
		From = { Position = Vector3.new(-1.5, 6.2, -6), LookAt = Vector3.new(-4.5, 5.4, -24) },
		To = { Position = Vector3.new(-3, 5.6, -12.5), LookAt = Vector3.new(-4.2, 5.2, -24) },
		Duration = 26,
	},
	-- M8: the case briefing opens on the scene: from the far corner of
	-- Daniel's office across the tape outline to his desk (lamp still on,
	-- the second cup, the visitor's chair pushed back) and the taped door.
	BriefingShot = {
		From = { Position = Vector3.new(-15.6, 6.2, -12.6), LookAt = Vector3.new(-24.5, 2.2, -6.5) },
		To = { Position = Vector3.new(-16.9, 5.4, -11.4), LookAt = Vector3.new(-24.4, 2.3, -6.6) },
		Duration = 30,
	},
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

-- M8: case briefing presentation (CaseBriefingView).
Config.UI.Briefing = {
	-- Fraction of the screen height each letterbox bar covers.
	Letterbox = 0.07,
	-- The text column: distance from the left edge, gap above the bottom
	-- bar, and widths.
	Margin = 72,
	BottomGap = 36,
	MaxWidth = 640,
	HookWidth = 500,
	TitleSize = 54,
	HookSize = 18,
	HookColor = Color3.fromRGB(208, 208, 202),
	ButtonWidth = 250,
	FadeIn = 1.4,
	-- Delay between each line arriving.
	Stagger = 0.18,
}

-- Phase 5.1: scripted scene presentation (CutsceneView).
Config.UI.Cutscene = {
	-- Fraction of the screen height each letterbox bar covers.
	Letterbox = 0.1,
	-- Seconds for the bars to slide in and out.
	BarTime = 0.6,
	-- Subtitles sit this far above the bottom bar; text size follows the
	-- screen height within these bounds.
	SubtitleGap = 18,
	SubtitleMaxWidth = 900,
	SubtitleSizeMin = 15,
	SubtitleSizeMax = 22,
	SubtitleFade = 0.2,
}

-- Conversation presentation (DialogueView).
Config.UI.Dialogue = {
	PanelHeight = 178,
	PanelMaxWidth = 860,
	PanelBottomOffset = 34,
	PanelTransparency = 0.06,
	-- Fraction of the screen height each letterbox bar covers.
	LetterboxHeight = 0.075,
	BodyTop = 30,
	BodyTopWithPrompt = 54,
	BodyTextSize = 19,
	ChoiceHeight = 40,
	ChoiceHover = Color3.fromRGB(34, 32, 28),
	-- Typewriter: characters per second, and holds after punctuation.
	CharactersPerSecond = 52,
	SentencePause = 0.32,
	EllipsisPause = 0.22,
	CommaPause = 0.1,
	DashPause = 0.22,
	-- The investigator's own lines.
	PlayerText = Color3.fromRGB(196, 204, 214),
	PlayerFont = Enum.Font.GothamMedium,
	-- Speaker portrait (a still copy of the NPC in a ViewportFrame).
	PortraitSize = 126,
	PortraitDistance = 3.1,
	PortraitFieldOfView = 26,
	PortraitAimDrop = 0.35,
	PortraitBackdrop = Color3.fromRGB(24, 26, 32),
	PortraitAmbient = Color3.fromRGB(120, 118, 124),
	PortraitLight = Color3.fromRGB(255, 226, 190),
	-- Depth of field while talking (the speaker is ~4 studs away).
	FocusDistance = 4.4,
	FocusRadius = 3,
	FocusBlur = 0.3,
}

return Config
