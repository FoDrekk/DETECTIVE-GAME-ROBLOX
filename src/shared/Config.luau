--!strict
--[[
	Config
	Global, non-case configuration values.
	Case-specific data lives in src/config.
]]

local Config = {}

Config.Game = {
	AutoStartCase = "CASE-001",
	-- The session is server-wide, so only one investigator per
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
	-- Stale-bake detection, made self-healing in the office
	-- redesign. EnvironmentBake.bake() stamps this onto Workspace.Office once
	-- it finishes (Edit mode only); every boot compares it against a baked
	-- place's own stamp. Bump this by hand whenever a change to OfficePlan or
	-- to the builders (OfficeShell/OfficeRoom/OfficeDetailing/OfficeInterior/
	-- the rooms/CitySkyline/SuspectSpawner) would change what they generate.
	-- The builders adopt a current bake unchanged (author edits to baked props
	-- survive); a stale one is discarded and rebuilt (EnvironmentBake.
	-- ensureCurrent), with a warning that the place should be re-baked and
	-- saved. See `815064d` for the incident this exists to catch: a floor fix
	-- landed in the builders, but the already-baked `.rbxl` was never
	-- re-baked, so the fix never reached the saved place.
	BuilderVersion = 12,
	-- 12:40 AM, after hours (OfficeRoom). Readability first: the local lights
	-- carry the mood, ambient and exposure keep every room playable.
	Night = {
		ClockTime = 0.67,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(48, 51, 60),
		OutdoorAmbient = Color3.fromRGB(44, 49, 62),
		EnvironmentDiffuseScale = 0.3,
		EnvironmentSpecularScale = 0.32,
		ExposureCompensation = 0.55,
		ShadowSoftness = 0.22,
		-- Colour grade: a touch of contrast, slightly desaturated, warm.
		Contrast = 0.06,
		Saturation = -0.12,
		Tint = Color3.fromRGB(255, 247, 238),
		-- Bloom only for things that actually glow (screens, signs, lamps).
		BloomIntensity = 0.5,
		BloomSize = 24,
		BloomThreshold = 1.35,
		-- The haze: thin enough that the room stays clear and the far city
		-- reads through the windows, fading into sodium-orange light.
		Atmosphere = {
			Density = 0.07,
			Offset = 0.25,
			Color = Color3.fromRGB(120, 88, 76),
			Decay = Color3.fromRGB(150, 92, 64),
			Glare = 0,
			Haze = 2.2,
		},
	},
	-- Interior lighting plan (OfficeInterior). Brightness/Range per fixture;
	-- `shadows` only where a shadow tells you something.
	Interior = {
		Lights = {
			DanielOffice = { brightness = 1.35, range = 22, color = Color3.fromRGB(255, 238, 218), shadows = true },
			MeetingRoom = { brightness = 0.55, range = 18, color = Color3.fromRGB(255, 240, 226) },
			MeetingPendant = { brightness = 2.0, range = 16 },
			Reception = { brightness = 1.0, range = 18, color = Color3.fromRGB(255, 234, 210), shadows = true },
			Lobby = { brightness = 0.72, range = 17, color = Color3.fromRGB(250, 235, 216) },
			OpenPlan = { brightness = 0.7, range = 20, color = Color3.fromRGB(255, 240, 222), shadows = true },
			Studio = { brightness = 0.82, range = 22, color = Color3.fromRGB(232, 236, 242) },
			-- Night lights: a dim bank left on so a big floor isn't black.
			NightLight = { brightness = 0.32, range = 16, color = Color3.fromRGB(236, 232, 226) },
			Corridor = { brightness = 0.5, range = 17, color = Color3.fromRGB(238, 236, 226) },
			WestHall = { brightness = 0.5, range = 15, color = Color3.fromRGB(248, 237, 220) },
			Pantry = { brightness = 0.8, range = 15, color = Color3.fromRGB(255, 242, 226) },
			Records = { brightness = 0.82, range = 14, color = Color3.fromRGB(222, 228, 238), shadows = true },
		},
		-- The city's light through the north windows.
		CityGlow = { Brightness = 0.6, Range = 18, Color = Color3.fromRGB(164, 180, 210) },
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
	-- Key to open the accusation picker ([Q] opens it
	-- rather than concluding directly). Only does anything once the server
	-- has said accusing is open; the server re-validates eligibility and the
	-- chosen accusation regardless.
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

-- Audio. Every asset is from a Roblox-licensed partner library
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
	--[[
		The sounds a scripted scene can ask for by name (Types.
		CutsceneSoundCue). A scene names a cue and never an asset id, so a sound can
		be swapped here without touching a shot. Every asset is from a Roblox
		partner library (Pro Sound Effects, APM Music) or a free Creator Store
		upload, and was checked to load.

		`volume` is the cue's own level (a shot can override it). `loops` cues are
		beds: they run until a shot stops asking for them. Levels are set against
		each source's measured loudness, so the mix sits together: the quiet
		sources (the lift, the dawn pad) are turned up, the loud ones down.
	]]
	Cutscene = {
		-- Beds.
		RainInterior = { id = "rbxassetid://9112858540", volume = 0.55, loops = true },
		RainStreet = { id = "rbxassetid://9112856768", volume = 0.5, loops = true },
		RoomTone = { id = "rbxassetid://9112777624", volume = 0.35, loops = true },
		TrafficWet = { id = "rbxassetid://9112905322", volume = 0.5, loops = true },
		Mamak = { id = "rbxassetid://9112875348", volume = 0.5, loops = true },
		Wipers = { id = "rbxassetid://9112906346", volume = 0.35, loops = true },
		-- The case's music: low keys, sparse. Enters over the city, gone in the lift.
		Motif = { id = "rbxassetid://1836904259", volume = 0.5, loops = true },
		-- The dawn pad under the outro.
		DawnPad = { id = "rbxassetid://1838792473", volume = 1.2, loops = true },
		-- The phone vibrating: a bed, so it buzzes until a shot stops it.
		PhoneBuzz = { id = "rbxassetid://121031853982816", volume = 1.0, loops = true },
		-- One-shots.
		Notification = { id = "rbxassetid://75568314388208", volume = 1.0 },
		Thunder = { id = "rbxassetid://9120015808", volume = 0.5 },
		Train = { id = "rbxassetid://9116330273", volume = 0.6 },
		CarDoor = { id = "rbxassetid://9113022904", volume = 0.7 },
		RadioStatic = { id = "rbxassetid://9119591638", volume = 0.5 },
		BadgeBeep = { id = "rbxassetid://9113939212", volume = 0.8 },
		-- The lift: one recording (about 11.5 s) of a car's doors closing (1 to 2 s in),
		-- riding (2.5 to 8.5 s, a faint hum) and ringing at the floor and opening
		-- (9 s on). A scene starts each part where it lies (`from`). The ride is far
		-- longer than the hum, so it is laid end to end: two names for the same
		-- recording, used in turn, so stopping one segment never cuts the next.
		LiftHumA = { id = "rbxassetid://9114303418", volume = 6.0 },
		LiftHumB = { id = "rbxassetid://9114303418", volume = 6.0 },
		LiftBell = { id = "rbxassetid://9114303418", volume = 6.0 },
	},
}

-- Suspect characters. Body packages are Roblox's free "Man" and "Woman"
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
	-- Conversation shot, relative to the suspect's face (studs).
	Conversation = {
		Distance = 4.2,
		SideOffset = 1.1,
		Height = 0.4,
		AimDrop = 1.1,
	},
}

-- Connections the investigator makes.
Config.Reasoning = {
	-- Seconds before another pairing or answer is taken after a miss.
	MissCooldown = 2,
}

-- Scripted scenes (CutsceneService / CutsceneView).
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
	--[[
		The intro is skipped by HOLDING the primary input (E / X / the
		touch button) or Space for this long, with a meter filling as it is held;
		letting go cancels. A hold can't happen by accident. Escape is
		Roblox-reserved and is deliberately not used.
	]]
	SkipHoldSeconds = 1,
	-- Seconds the client waits, after asking to begin an investigation whose case
	-- opens on a scene, for that scene to arrive before it treats the
	-- investigation as begun without one (a server that refused to play it).
	IntroWait = 4,
	-- KeyCode enum names that skip an intro as well as the primary input. Space is
	-- free during a scene: movement is locked while one plays.
	SkipKeys = { "Space" },
	--[[
		Where each set a scene can be framed in stands. The intro's sets
		are built by the client (CutsceneSets) far from the office, only for as long
		as the scene plays, so nothing is ever in shot during play. A shot's camera
		points are relative to its set's origin; `world` sets are the office itself
		(their points are world coordinates). `actions` lists what the set can be
		told to do (Types.CutsceneAction.name): the server checks a scene against it
		at boot, and the headless playthrough checks each set really does them.
	]]
	Sets = {
		Bedroom = { origin = Vector3.new(0, 0, 800), actions = { "PhoneRing", "PhoneStop", "HandComes", "PhoneFlip" } },
		Street = { origin = Vector3.new(600, 0, 800), actions = { "TrainPasses", "TeaPulled", "SedanRolls", "SedanStops" } },
		Car = { origin = Vector3.new(1200, 0, 800), actions = { "PhoneRing", "Answer", "WipersOn", "Notify" } },
		Forecourt = { origin = Vector3.new(1800, 0, 800), actions = { "SedanArrives", "StepOut", "LightsOff" } },
		Lobby = { origin = Vector3.new(2400, 0, 800), actions = { "ConstableNods", "TapCard", "ReaderAccepts" } },
		City = { origin = Vector3.new(3000, 0, 800), actions = { "TrafficFlows" } },
		LiftCar = { world = true, actions = { "DoorsClose", "Display", "DoorsOpen", "Shudder" } },
		OfficeDawn = { world = true, actions = { "Brighten" } },
	},
	-- How a shot's `ease` moves the camera: the curve of progress over time.
	Eases = { "InOut", "Out", "In", "Linear" },
	--[[
		Named looks a shot can ask for (Types.CutsceneShot.lighting). A
		preset lists only what it means to change; the rest keeps the world's value,
		and the player's own lighting is put back when the scene ends, however it
		ends. Presets, not per-shot numbers, so every shot in a place is lit the same
		way. `Bloom`, `Grade` and `Vignette` belong to the camera, not the sky;
		`Atmosphere` is the world's haze (and `Stars` its stars), which the office
		keeps thick and blue and which a city in the rain wants thin and warm.
	]]
	LightingPresets = {
		-- The cold open: a dark bedroom, the city orange through the rain.
		Bedroom = {
			ClockTime = 0.4,
			Brightness = 0.1,
			Ambient = Color3.fromRGB(14, 12, 14),
			OutdoorAmbient = Color3.fromRGB(40, 30, 26),
			ExposureCompensation = 0.28,
			FogColor = Color3.fromRGB(96, 46, 30),
			FogStart = 110,
			FogEnd = 1000,
			Atmosphere = { Density = 0.1, Offset = 0.1, Color = Color3.fromRGB(70, 46, 42), Decay = Color3.fromRGB(120, 70, 44), Glare = 0, Haze = 0.6 },
			Stars = 0,
			Bloom = { intensity = 0.36, size = 24, threshold = 1.05 },
			Grade = { contrast = 0.11, saturation = -0.1, tint = Color3.fromRGB(246, 235, 224), brightness = 0 },
			Vignette = 0.5,
		},
		-- Kota Arwana at night in the rain: sodium orange, wet, alive.
		CityNight = {
			ClockTime = 0.6,
			Brightness = 0.8,
			Ambient = Color3.fromRGB(62, 60, 74),
			OutdoorAmbient = Color3.fromRGB(110, 92, 86),
			ExposureCompensation = 0.9,
			FogColor = Color3.fromRGB(46, 34, 34),
			FogStart = 40,
			FogEnd = 900,
			Atmosphere = { Density = 0.1, Offset = 0.1, Color = Color3.fromRGB(80, 62, 60), Decay = Color3.fromRGB(150, 90, 60), Glare = 0, Haze = 1.6 },
			Stars = 0,
			Bloom = { intensity = 0.5, size = 24, threshold = 1.1 },
			Grade = { contrast = 0.14, saturation = -0.06, tint = Color3.fromRGB(255, 236, 222), brightness = 0 },
			Vignette = 0.35,
		},
		-- Inside the car, lit by the dashboard and the streetlights going past.
		CarInterior = {
			ClockTime = 0.6,
			Brightness = 0.22,
			Ambient = Color3.fromRGB(63, 67, 78),
			OutdoorAmbient = Color3.fromRGB(82, 76, 77),
			ExposureCompensation = 1.2,
			FogColor = Color3.fromRGB(46, 34, 34),
			FogStart = 40,
			FogEnd = 900,
			Atmosphere = { Density = 0.08, Offset = 0.05, Color = Color3.fromRGB(80, 62, 60), Decay = Color3.fromRGB(150, 90, 60), Glare = 0, Haze = 1.0 },
			Stars = 0,
			Bloom = { intensity = 0.35, size = 20, threshold = 1.1 },
			Grade = { contrast = 0.14, saturation = -0.1, tint = Color3.fromRGB(230, 240, 255), brightness = 0 },
			Vignette = 0.5,
		},
		-- The tower's forecourt, cold and wet.
		Forecourt = {
			ClockTime = 0.65,
			Brightness = 0.6,
			Ambient = Color3.fromRGB(48, 54, 72),
			OutdoorAmbient = Color3.fromRGB(80, 86, 110),
			ExposureCompensation = 0.8,
			FogColor = Color3.fromRGB(30, 34, 46),
			FogStart = 50,
			FogEnd = 700,
			Atmosphere = { Density = 0.1, Offset = 0.05, Color = Color3.fromRGB(60, 70, 96), Decay = Color3.fromRGB(70, 80, 120), Glare = 0, Haze = 1.0 },
			Stars = 0,
			Bloom = { intensity = 0.75, size = 26, threshold = 0.92 },
			Grade = { contrast = 0.14, saturation = -0.12, tint = Color3.fromRGB(226, 236, 255), brightness = 0 },
			Vignette = 0.4,
		},
		-- The tower lobby: marble and cold overhead light.
		Lobby = {
			ClockTime = 0.67,
			Brightness = 0.35,
			Ambient = Color3.fromRGB(68, 72, 84),
			OutdoorAmbient = Color3.fromRGB(56, 60, 74),
			ExposureCompensation = 0.8,
			FogColor = Color3.fromRGB(30, 34, 46),
			FogStart = 200,
			FogEnd = 2000,
			Atmosphere = { Density = 0, Haze = 0 },
			Stars = 0,
			Bloom = { intensity = 0.35, size = 22, threshold = 1.1 },
			Grade = { contrast = 0.08, saturation = -0.12, tint = Color3.fromRGB(232, 240, 255), brightness = 0 },
			Vignette = 0.18,
		},
		-- The lift car: a small steel box under one hard ceiling light.
		Lift = {
			ClockTime = 0.67,
			Brightness = 0.35,
			Ambient = Color3.fromRGB(40, 42, 48),
			OutdoorAmbient = Color3.fromRGB(48, 52, 65),
			ExposureCompensation = 0.1,
			FogColor = Color3.fromRGB(30, 34, 46),
			FogStart = 200,
			FogEnd = 2000,
			Atmosphere = { Density = 0, Haze = 0 },
			Stars = 0,
			Bloom = { intensity = 0.3, size = 18, threshold = 1.2 },
			Grade = { contrast = 0.12, saturation = -0.15, tint = Color3.fromRGB(236, 240, 248), brightness = 0 },
			Vignette = 0.3,
		},
		-- The city from the air: warm haze and a long view.
		CityAerial = {
			ClockTime = 0.5,
			Brightness = 0.3,
			Ambient = Color3.fromRGB(30, 30, 42),
			OutdoorAmbient = Color3.fromRGB(64, 50, 48),
			ExposureCompensation = 0.4,
			FogColor = Color3.fromRGB(70, 44, 36),
			FogStart = 260,
			FogEnd = 2600,
			-- Thin: the city is hundreds of studs away, and any real density drowns it.
			-- The haze and decay carry the sodium glow along the horizon instead.
			Atmosphere = { Density = 0.08, Offset = 0.25, Color = Color3.fromRGB(110, 70, 58), Decay = Color3.fromRGB(220, 112, 58), Glare = 0, Haze = 2.6 },
			Stars = 0,
			Bloom = { intensity = 0.45, size = 20, threshold = 1.2 },
			Grade = { contrast = 0.14, saturation = -0.04, tint = Color3.fromRGB(255, 236, 222), brightness = 0 },
			Vignette = 0.35,
		},
		-- Dawn over Kota Arwana: the deadline the case is played against
		-- ("forensics can't get there till six").
		Dawn = {
			ClockTime = 6.1,
			Brightness = 0.9,
			Ambient = Color3.fromRGB(58, 54, 58),
			OutdoorAmbient = Color3.fromRGB(96, 86, 92),
			ExposureCompensation = 0.25,
			FogColor = Color3.fromRGB(120, 100, 100),
			FogStart = 300,
			FogEnd = 1400,
			Atmosphere = { Density = 0.25, Offset = 0.05, Color = Color3.fromRGB(150, 120, 110), Decay = Color3.fromRGB(230, 140, 90), Glare = 0, Haze = 1.2 },
			Stars = 0,
			Bloom = { intensity = 0.7, size = 28, threshold = 1.05 },
			Grade = { contrast = 0.06, saturation = -0.04, tint = Color3.fromRGB(255, 238, 226), brightness = 0 },
			Vignette = 0.25,
		},
	},
}

-- The title screen, and the camera drift behind it (world coordinates of
-- the office; the shot ping-pongs between From and To).
Config.Presentation = {
	Title = {
		Kicker = "A MYSTERY CASE",
		-- Shown until the case briefing arrives with the real title.
		Fallback = "THE LAST CALL",
		Footer = "Best played with headphones.",
	},
	IntroShot = {
		-- The title screen's drift: up the corridor from the entrance toward the
		-- north window, where Meera stands with her back to the room and the city
		-- beyond the glass (window centre (0, 7, -28)).
		From = { Position = Vector3.new(1.5, 6.2, 14), LookAt = Vector3.new(-0.5, 5.4, -26) },
		To = { Position = Vector3.new(0.5, 5.6, -8), LookAt = Vector3.new(0, 5.2, -26) },
		Duration = 26,
	},
	-- A case briefing that opens on the scene (the briefing screen, kept for
	-- cases without an intro): from the door corner of Daniel's office across the
	-- tape outline to his desk (lamp still on, the second cup, the visitor's
	-- chair pushed back) and the taped door.
	BriefingShot = {
		From = { Position = Vector3.new(-18.4, 6.2, -10.2), LookAt = Vector3.new(-26.0, 2.4, -19.6) },
		To = { Position = Vector3.new(-19.6, 5.4, -11.6), LookAt = Vector3.new(-25.8, 2.5, -19.4) },
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

-- Case briefing presentation (CaseBriefingView).
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

-- Scripted scene presentation (CutsceneView).
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
	-- Seconds a bed the next shot doesn't ask for takes to fade out at a cut.
	BedFade = 0.8,
	-- How long the recordings a scene needs are waited for before it starts anyway.
	PreloadWait = 2.5,
	-- An intro's last frame eases into the player's own camera over this
	-- many seconds, instead of cutting to it.
	Handover = 0.9,
	-- Skipping an intro dips to black for this long first (its sets and
	-- lighting are undone behind it).
	SkipDip = 0.35,
	-- The hold-to-skip hint appears this long after an intro starts, for
	-- this many seconds.
	IntroHintDelay = 1.5,
	IntroHintSeconds = 6,
	-- The title card over a shot (screen space, so it reads the same
	-- on a phone and a monitor).
	TitleCard = {
		KickerSize = 14,
		TitleSize = 46,
		SubtitleSize = 16,
		FadeIn = 0.9,
		FadeOut = 0.9,
		-- The card sits this far below centre (a fraction of the screen).
		CentreOffset = 0.04,
		MaxWidth = 760,
	},
	-- The hold-to-skip meter, in the bottom bar beside the hint.
	SkipMeter = {
		Width = 132,
		Height = 3,
		Margin = 24,
		BottomGap = 34,
	},
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
