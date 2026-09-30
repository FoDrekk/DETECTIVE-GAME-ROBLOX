--!strict
--[[
	CASE-001's opening scene (Phase 5.5). Pure data: no gameplay logic belongs
	here. Read with docs/CASE_001_INTRO_SCREENPLAY.md, which is the design; this
	is its implementation.

	The scene is played by the engine (CutsceneService / CutsceneView), which
	knows nothing of this story: every set, look, cue and action named below is
	looked up in Config (Cutscene.Sets, Cutscene.LightingPresets,
	Audio.Cutscene), and CutsceneService.validate checks each name at boot.
]]

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

type Shot = Types.CutsceneShot
type Cue = Types.CutsceneSoundCue

local function point(position: Vector3, lookAt: Vector3): Types.CutsceneCameraPoint
	return { position = position, lookAt = lookAt }
end

--------------------------------------------------------------------------
-- Scene 1: "11:47" (the cold open), 0:00 to 0:22
--------------------------------------------------------------------------

-- The rain and the fan, carried through all four shots so no cut announces itself.
local function bedroomBeds(fade: number?): { Cue }
	return {
		{ at = 0, cue = "RainInterior", fade = fade },
		{ at = 0, cue = "RoomTone", fade = fade },
	}
end

local function withBeds(extra: { Cue }, fade: number?): { Cue }
	local cues = bedroomBeds(fade)
	for _, cue in ipairs(extra) do
		table.insert(cues, cue)
	end
	return cues
end

-- The phone and the tablets on the bedside table: a top-down macro, shallow focus.
local PHONE_LOOK = Vector3.new(-5.45, 2.22, -4.15)
local PHONE_FOCUS: Types.CutsceneFocus = { distance = 1.9, radius = 0.42, blur = 0.65 }

local function bedroomShots(): { Shot }
	return {
		-- 1. Black, then a slow fade to a dark bedroom. Locked off. Rain on the
		-- window, the city orange through it, a clock: 11:47.
		{
			id = "BED-1",
			duration = 4.5,
			set = "Bedroom",
			lighting = "Bedroom",
			fadeIn = 2.6,
			camera = { from = point(Vector3.new(1.0, 3.1, 3.6), Vector3.new(-1.6, 3.6, -6)), fieldOfView = 62, fieldOfViewTo = 58, ease = "Linear" },
			sounds = bedroomBeds(2.5),
		},
		-- 2. Close-up, top-down on the bedside table. The phone buzzes face up:
		-- "Daniel". Beside it a strip of tablets, none pressed out.
		{
			id = "BED-2",
			duration = 4.5,
			set = "Bedroom",
			lighting = "Bedroom",
			camera = {
				from = point(Vector3.new(-4.2, 4.6, -3.1), PHONE_LOOK),
				to = point(Vector3.new(-4.6, 4.25, -3.45), PHONE_LOOK),
				fieldOfView = 47,
				fieldOfViewTo = 43,
				ease = "Out",
			},
			focus = PHONE_FOCUS,
			actions = { { at = 0.5, name = "PhoneRing" } },
			sounds = withBeds({ { at = 0.6, cue = "PhoneBuzz", volume = 1.0 } }),
		},
		-- 3. Same angle. A hand with a thin gold band comes in, hovers, and turns
		-- the phone face down. The buzzing stops.
		{
			id = "BED-3",
			duration = 5,
			set = "Bedroom",
			lighting = "Bedroom",
			camera = { from = point(Vector3.new(-4.6, 4.25, -3.45), PHONE_LOOK), fieldOfView = 43 },
			focus = PHONE_FOCUS,
			actions = {
				{ at = 0.2, name = "HandComes", args = { time = 2.6 } },
				{ at = 3.6, name = "PhoneFlip", args = { time = 0.9 } },
			},
			sounds = withBeds({ { at = 4.05, cue = "PhoneBuzz", stop = true, fade = 0.06 } }),
		},
		-- 4. Hold on the face-down phone. Nothing moves. Cut to black.
		{
			id = "BED-4",
			duration = 1.4,
			set = "Bedroom",
			lighting = "Bedroom",
			fadeOut = 0.7,
			camera = { from = point(Vector3.new(-4.6, 4.25, -3.45), PHONE_LOOK), fieldOfView = 43 },
			focus = PHONE_FOCUS,
			sounds = bedroomBeds(),
		},
	}
end

--------------------------------------------------------------------------
-- From the window to the tower: city, wet street, car, and lobby
--------------------------------------------------------------------------

local function journeyShots(): { Shot }
	return {
		{
			id = "CITY-AERIAL",
			duration = 5.5,
			set = "City",
			lighting = "CityAerial",
			camera = {
				from = point(Vector3.new(-70, 145, 640), Vector3.new(10, 8, -80)),
				to = point(Vector3.new(-12, 118, 490), Vector3.new(12, 5, -130)),
				fieldOfView = 58,
				fieldOfViewTo = 52,
				ease = "InOut",
			},
			actions = { { at = 0.25, name = "TrafficFlows" } },
			sounds = { { at = 0, cue = "RainStreet", fade = 0.8 }, { at = 0.1, cue = "Motif", volume = 0.22, fade = 1.2 } },
		},
		{
			id = "STREET-TRAIN",
			duration = 4.2,
			set = "Street",
			lighting = "CityNight",
			camera = {
				from = point(Vector3.new(-14, 8.2, 23), Vector3.new(-18, 17, 0)),
				to = point(Vector3.new(-10, 7.4, 8), Vector3.new(-18, 17, -12)),
				fieldOfView = 56,
				ease = "Out",
				handheld = 0.08,
			},
			actions = { { at = 0.2, name = "TrainPasses" } },
			sounds = { { at = 0, cue = "RainStreet", fade = 0.5 }, { at = 0.1, cue = "Train", volume = 0.35 } },
			lines = { { at = 1.4, duration = 2.2, speaker = "Radio", text = "Unit 14, lokasi Menara Rozario. Hujan lebat.\n(Unit 14, Rozario Tower. Heavy rain.)" } },
		},
		{
			id = "STREET-MAMAK",
			duration = 5.4,
			set = "Street",
			lighting = "CityNight",
			camera = {
				from = point(Vector3.new(-8, 5.3, -8), Vector3.new(1, 3, -16)),
				to = point(Vector3.new(-4.2, 4.2, -10.4), Vector3.new(7, 3.2, -17)),
				fieldOfView = 46,
				fieldOfViewTo = 42,
				ease = "InOut",
			},
			actions = { { at = 0.4, name = "TeaPulled" }, { at = 1.0, name = "SedanRolls" }, { at = 3.7, name = "SedanStops" } },
			sounds = { { at = 0, cue = "Mamak", fade = 0.7 }, { at = 0, cue = "TrafficWet" }, { at = 0.2, cue = "RainStreet" } },
		},
		{
			id = "CAR-WARRANT",
			duration = 4.6,
			set = "Car",
			lighting = "CarInterior",
			camera = {
				from = point(Vector3.new(-5.8, 5.1, 2.8), Vector3.new(-1.2, 3.4, -6.1)),
				to = point(Vector3.new(-4.8, 4.8, 1.6), Vector3.new(-1.2, 3.45, -6.2)),
				fieldOfView = 49,
				fieldOfViewTo = 44,
				ease = "Out",
				handheld = 0.04,
			},
			actions = { { at = 0.45, name = "PhoneRing" }, { at = 1.25, name = "Answer" }, { at = 1.8, name = "Notify" } },
			sounds = { { at = 0, cue = "RainInterior", fade = 0.4 }, { at = 0.4, cue = "PhoneBuzz" }, { at = 0.8, cue = "Wipers" }, { at = 1.2, cue = "Notification" } },
			lines = { { at = 1.6, duration = 2.5, speaker = "Nora", text = "The guard's waiting downstairs. I'll stay on the line." } },
		},
		{
			id = "CAR-EN-ROUTE",
			duration = 4.8,
			set = "Car",
			lighting = "CarInterior",
			camera = {
				from = point(Vector3.new(0.2, 5.1, 1.2), Vector3.new(2.3, 4.1, -7.2)),
				to = point(Vector3.new(1.1, 4.85, 0.3), Vector3.new(2.6, 4, -7.2)),
				fieldOfView = 50,
				fieldOfViewTo = 47,
				ease = "InOut",
			},
			actions = { { at = 0.1, name = "WipersOn" } },
			sounds = { { at = 0, cue = "RainInterior" }, { at = 0, cue = "Wipers" }, { at = 0.4, cue = "RadioStatic", volume = 0.3 } },
			lines = { { at = 0.8, duration = 3.3, speaker = "Nora", text = "We have a short window before forensics can get here. Find out what happened." } },
		},
		{
			id = "FORECOURT",
			duration = 7,
			set = "Forecourt",
			lighting = "Forecourt",
			camera = {
				from = point(Vector3.new(32, 7.5, 48), Vector3.new(0, 49, -54)),
				to = point(Vector3.new(22, 6.5, 34), Vector3.new(0, 50, -54)),
				fieldOfView = 58,
				fieldOfViewTo = 53,
				ease = "InOut",
			},
			actions = { { at = 0.2, name = "SedanArrives" }, { at = 3.3, name = "StepOut" }, { at = 5.8, name = "LightsOff" } },
			sounds = { { at = 0, cue = "RainStreet", fade = 0.7 }, { at = 0.7, cue = "CarDoor" }, { at = 5.6, cue = "BadgeBeep", volume = 0.38 } },
		},
		{
			id = "LOBBY-CONSTABLE",
			duration = 3,
			set = "Lobby",
			lighting = "Lobby",
			camera = {
				from = point(Vector3.new(-30, 6.4, -2), Vector3.new(-23, 6, -16)),
				to = point(Vector3.new(-27, 6.1, -5), Vector3.new(-23, 6, -16)),
				fieldOfView = 49,
				fieldOfViewTo = 45,
				ease = "Out",
			},
			actions = { { at = 0.6, name = "ConstableNods" } },
			sounds = { { at = 0, cue = "RoomTone", fade = 0.8 } },
			lines = { { at = 0.8, duration = 2.1, speaker = "Constable", text = "Tingkat 9. Lift dah kosong." } },
		},
		{
			id = "LOBBY-ACCESS",
			duration = 4.5,
			set = "Lobby",
			lighting = "Lobby",
			camera = {
				from = point(Vector3.new(-4, 5.2, 9), Vector3.new(8, 3.5, -2)),
				to = point(Vector3.new(1, 4.7, 6), Vector3.new(8, 3.5, -2)),
				fieldOfView = 48,
				fieldOfViewTo = 44,
				ease = "InOut",
			},
			actions = { { at = 1.2, name = "TapCard" }, { at = 1.7, name = "ReaderAccepts" } },
			sounds = { { at = 0, cue = "RoomTone" }, { at = 1.1, cue = "BadgeBeep", volume = 0.55 } },
		},
	}
end

--------------------------------------------------------------------------
-- The lift (Scenes 5 and 6): the one place the player is present
--------------------------------------------------------------------------

-- The player's eyes in the car: where the spawn pad puts them, looking at the
-- doors and the floor display above them.
local LIFT_EYE = Vector3.new(31.75, 5.1, 23.75)
local LIFT_DOORS = Vector3.new(26.0, 6.2, 23.75)

-- The ride's sound. The recording (Config.Audio.Cutscene.LiftHumA/B) has about
-- six seconds of quiet hum; a ride is longer, so segments are laid end to end,
-- alternating the two names so stopping one never cuts the next.
local function rideHum(seconds: number): { Cue }
	local cues: { Cue } = {}
	local at = 0
	local index = 0
	while at < seconds - 0.05 do
		local name = if index % 2 == 0 then "LiftHumA" else "LiftHumB"
		table.insert(cues, { at = at, cue = name, from = 2.6, fade = 0.5 })
		table.insert(cues, { at = math.min(at + 5.7, seconds), cue = name, stop = true, fade = 0.6 })
		at += 5.3
		index += 1
	end
	return cues
end

-- The floor display's climb: G, then 1 to 8 on a steady beat, then 9 as it stops.
local function floorDisplay(): { Types.CutsceneAction }
	local actions: { Types.CutsceneAction } = { { at = 0, name = "Display", args = { text = "G" } } }
	for floor = 1, 8 do
		table.insert(actions, { at = 0.8 + floor * 3.0, name = "Display", args = { text = tostring(floor) } })
	end
	table.insert(actions, { at = 26.0, name = "Display", args = { text = "9" } })
	return actions
end

local RIDE_SECONDS = 31

local function liftShots(): { Shot }
	local ride: Shot = {
		id = "LIFT",
		duration = RIDE_SECONDS,
		set = "LiftCar",
		mouseLook = true,
		fadeIn = 1.2,
		camera = { from = point(LIFT_EYE, LIFT_DOORS), fieldOfView = 68, handheld = 0.05 },
		actions = floorDisplay(),
		sounds = rideHum(RIDE_SECONDS),
		lines = {
			{ at = 10.6, duration = 4.2, speaker = "Nora", text = "Jangan lupa makan.\n(Don't forget to eat.)" },
		},
	}
	table.insert(ride.actions :: { Types.CutsceneAction }, { at = 0.4, name = "Shudder", args = { amount = 0.06, time = 0.9 } })
	table.insert(ride.actions :: { Types.CutsceneAction }, { at = 25.8, name = "Shudder", args = { amount = 0.09, time = 0.8 } })
	table.insert(ride.sounds :: { Cue }, { at = 10.3, cue = "Notification" })

	local open: Shot = {
		id = "LIFT-OPEN",
		duration = 6,
		set = "LiftCar",
		mouseLook = true,
		camera = { from = point(LIFT_EYE, LIFT_DOORS), fieldOfView = 68, fieldOfViewTo = 64, handheld = 0.05 },
		sounds = { { at = 0, cue = "LiftBell", from = 8.6 } },
		actions = { { at = 0.7, name = "DoorsOpen", args = { time = 1.9 } } },
		titleCard = {
			at = 1.6,
			duration = 4.2,
			kicker = "CASE 001",
			title = "THE LAST CALL",
			subtitle = "Rozario & Lim  ·  Tingkat 9  ·  12:40 AM",
		},
	}
	return { ride, open }
end

--------------------------------------------------------------------------
-- The scene
--------------------------------------------------------------------------

local Intro: Types.CutsceneDefinition = {
	id = "CUT-INTRO",
	-- Every later run starts at the lift doors (screenplay, "Skip rules").
	replayFrom = "LIFT-OPEN",
	shots = (function(): { Shot }
		local shots = bedroomShots()
		for _, shot in ipairs(journeyShots()) do
			table.insert(shots, shot)
		end
		for _, shot in ipairs(liftShots()) do
			table.insert(shots, shot)
		end
		return shots
	end)(),
}

return Intro
