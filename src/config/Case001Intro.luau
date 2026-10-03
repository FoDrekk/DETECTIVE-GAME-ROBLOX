--!strict
--[[
	CASE-001 opening. The screenplay is the story authority; these shots are its
	performance: precise visual handoffs, varied lensing, and a measured build
	from private unease to public arrival. Gameplay state is never changed here.
]]

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

type Shot = Types.CutsceneShot
type Cue = Types.CutsceneSoundCue

local function point(position: Vector3, lookAt: Vector3): Types.CutsceneCameraPoint
	return { position = position, lookAt = lookAt }
end

local function roomBeds(fade: number?): { Cue }
	return {
		{ at = 0, cue = "RainInterior", fade = fade },
		{ at = 0, cue = "RoomTone", fade = fade },
	}
end

local function plusBeds(extra: { Cue }, fade: number?): { Cue }
	local cues = roomBeds(fade)
	for _, cue in ipairs(extra) do table.insert(cues, cue) end
	return cues
end

local PHONE = Vector3.new(-5.45, 2.22, -4.15)
local PHONE_FOCUS: Types.CutsceneFocus = { distance = 1.9, radius = 0.42, blur = 0.65 }
local LIFT_EYE = Vector3.new(31.75, 5.1, 23.75)
local LIFT_DOORS = Vector3.new(26.0, 6.2, 23.75)

local function bedroom(): { Shot }
	return {
		{
			id = "BED-WIDE", duration = 6, set = "Bedroom", lighting = "Bedroom", fadeIn = 2.2,
			camera = {
				from = point(Vector3.new(2.5, 4.2, 7.2), Vector3.new(-1.5, 3.4, -4.5)),
				to = point(Vector3.new(1.4, 3.8, 5.9), Vector3.new(-1.7, 3.25, -4.6)),
				fieldOfView = 58, fieldOfViewTo = 52, ease = "InOut",
			},
			sounds = roomBeds(2),
		},
		{
			id = "BED-CLOCK", duration = 4, set = "Bedroom", lighting = "Bedroom",
			camera = {
				from = point(Vector3.new(2.4, 4.4, 0.8), Vector3.new(-1.6, 3.6, -2.8)),
				to = point(Vector3.new(0.9, 4.0, -0.1), Vector3.new(-1.9, 3.4, -3.0)),
				fieldOfView = 48, fieldOfViewTo = 44, ease = "Out",
			},
			sounds = roomBeds(),
		},
		{
			id = "BED-PHONE", duration = 5, set = "Bedroom", lighting = "Bedroom",
			camera = {
				from = point(Vector3.new(-3.1, 4.9, -1.6), PHONE),
				to = point(Vector3.new(-4.35, 4.35, -3.1), PHONE),
				fieldOfView = 48, fieldOfViewTo = 42, ease = "InOut",
			},
			focus = PHONE_FOCUS,
			actions = { { at = 0.45, name = "PhoneRing" } },
			sounds = plusBeds({ { at = 0.5, cue = "PhoneBuzz", volume = 1.0 } }),
		},
		{
			id = "BED-HAND", duration = 4, set = "Bedroom", lighting = "Bedroom",
			camera = {
				from = point(Vector3.new(-4.35, 4.35, -3.1), PHONE),
				to = point(Vector3.new(-4.55, 4.22, -3.35), PHONE),
				fieldOfView = 42, ease = "Out",
			},
			focus = PHONE_FOCUS,
			actions = {
				{ at = 0.15, name = "HandComes", args = { time = 2.1 } },
				{ at = 2.75, name = "PhoneFlip", args = { time = 0.8 } },
			},
			sounds = plusBeds({ { at = 3.15, cue = "PhoneBuzz", stop = true, fade = 0.08 } }),
		},
		{
			id = "BED-EMPTY", duration = 1, set = "Bedroom", lighting = "Bedroom", fadeOut = 0.65,
			camera = { from = point(Vector3.new(-4.55, 4.22, -3.35), PHONE), fieldOfView = 42 },
			focus = PHONE_FOCUS,
			sounds = roomBeds(),
		},
	}
end

local function city(): { Shot }
	return {
		{
			id = "CITY-REVEAL", duration = 7, set = "City", lighting = "CityAerial",
			camera = {
				from = point(Vector3.new(60, 175, 300), Vector3.new(-150, 75, -220)),
				to = point(Vector3.new(30, 152, 215), Vector3.new(-170, 90, -240)),
				fieldOfView = 56, fieldOfViewTo = 48, ease = "InOut",
			},
			actions = { { at = 0.3, name = "TrafficFlows" } },
			sounds = { { at = 0, cue = "RainStreet", fade = 0.8 }, { at = 0.5, cue = "Motif", volume = 0.2, fade = 1.8 } },
		},
		{
			id = "CITY-LRT", duration = 5.5, set = "Street", lighting = "CityNight",
			camera = {
				from = point(Vector3.new(-14, 7.6, 27), Vector3.new(-18, 17, 4)),
				to = point(Vector3.new(-12, 7.4, 15), Vector3.new(-18, 17, -8)),
				fieldOfView = 58, fieldOfViewTo = 52, ease = "In",
			},
			actions = { { at = 0.15, name = "TrainPasses" } },
			sounds = { { at = 0, cue = "RainStreet", fade = 0.4 }, { at = 0.2, cue = "Train", volume = 0.42 }, { at = 0, cue = "Motif", volume = 0.16 } },
		},
		{
			id = "CITY-MAMAK", duration = 5.5, set = "Street", lighting = "CityNight",
			camera = {
				-- Across the near table to the lit shopfront, then over to the rider.
				from = point(Vector3.new(-3, 4.6, -5), Vector3.new(-17, 3.2, -24)),
				to = point(Vector3.new(0, 4.4, -7), Vector3.new(4, 3.2, -18)),
				fieldOfView = 48, fieldOfViewTo = 42, ease = "InOut",
			},
			actions = { { at = 0.2, name = "TeaPulled" } },
			sounds = { { at = 0, cue = "Mamak", fade = 0.5 }, { at = 0, cue = "TrafficWet" }, { at = 0.2, cue = "RainStreet" }, { at = 0, cue = "Motif", volume = 0.16 } },
		},
		{
			id = "CITY-DISPATCH", duration = 9.5, set = "Street", lighting = "CityNight",
			camera = {
				from = point(Vector3.new(20, 4.8, 13), Vector3.new(8, 3.1, -1)),
				to = point(Vector3.new(13, 4.2, 5), Vector3.new(7, 3.2, -5)),
				fieldOfView = 47, fieldOfViewTo = 42, ease = "Out", handheld = 0.025,
			},
			actions = { { at = 0.15, name = "SedanRolls" }, { at = 4.2, name = "SedanStops" } },
			sounds = { { at = 0, cue = "RadioStatic", volume = 0.3 }, { at = 0.1, cue = "TrafficWet" }, { at = 0.1, cue = "RainStreet" }, { at = 0, cue = "Motif", volume = 0.1, fade = 1 } },
			lines = {
				{ at = 0.35, duration = 4.2, speaker = "Radio", text = "Control to all units. Sudden death. Wisma Delima, level nine." },
				{ at = 4.75, duration = 4.0, speaker = "Radio", text = "Reported by the security guard at 12:14 AM." },
			},
		},
	}
end

local function carAndCall(): { Shot }
	return {
		{
			id = "CAR-CREDENTIAL", duration = 5, set = "Car", lighting = "CarInterior",
			camera = {
				from = point(Vector3.new(6.0, 5.7, -0.2), Vector3.new(4.35, 3.55, -5.4)),
				to = point(Vector3.new(5.2, 4.8, -2.3), Vector3.new(4.35, 3.55, -5.4)),
				fieldOfView = 43, fieldOfViewTo = 38, ease = "Out",
			},
			sounds = { { at = 0, cue = "RainInterior", fade = 0.6 }, { at = 1.7, cue = "PhoneBuzz" }, { at = 0, cue = "Motif", volume = 0.12 } },
		},
		{
			id = "CAR-NORA-1", duration = 13, set = "Car", lighting = "CarInterior",
			camera = {
				-- From the passenger seat: the investigator in profile against the
				-- rain on the driver's window.
				from = point(Vector3.new(3.4, 5.7, -1.2), Vector3.new(-3.3, 5.0, 0.2)),
				to = point(Vector3.new(2.8, 5.5, -1.8), Vector3.new(-3.3, 5.0, 0.1)),
				fieldOfView = 46, fieldOfViewTo = 40, ease = "InOut", handheld = 0.018,
			},
			actions = { { at = 0.4, name = "PhoneRing" }, { at = 1.1, name = "Answer" }, { at = 1.5, name = "Notify" } },
			sounds = { { at = 0, cue = "RainInterior", fade = 0.5 }, { at = 0.5, cue = "PhoneBuzz" }, { at = 1.1, cue = "PhoneBuzz", stop = true, fade = 0.08 }, { at = 1, cue = "Wipers" }, { at = 1.3, cue = "Notification" }, { at = 0, cue = "Motif", volume = 0.14, fade = 0.7 } },
			lines = {
				{ at = 1.7, duration = 2.2, speaker = "Nora", text = "There yet?" },
				{ at = 4.0, duration = 1.5, speaker = "You", text = "Five minutes." },
				{ at = 5.7, duration = 6.8, speaker = "Nora", text = "Daniel Rozario. Forty-one. Half of Rozario & Lim, the design firm on nine." },
			},
		},
		{
			id = "CAR-NORA-2", duration = 14, set = "Car", lighting = "CarInterior",
			camera = {
				from = point(Vector3.new(-5.8, 5.0, -2.3), Vector3.new(-3.25, 3.75, -5.95)),
				to = point(Vector3.new(-5.0, 4.55, -3.9), Vector3.new(-3.25, 3.7, -5.95)),
				fieldOfView = 43, fieldOfViewTo = 37, ease = "Out",
			},
			actions = { { at = 0.2, name = "WipersOn" } },
			sounds = { { at = 0, cue = "RainInterior" }, { at = 0, cue = "Wipers" }, { at = 0.5, cue = "RadioStatic", volume = 0.25 }, { at = 0, cue = "Motif", volume = 0.12 } },
			lines = {
				{ at = 0.5, duration = 8.8, speaker = "Nora", text = "The guard found him just after twelve. The ambulance took him to Hospital Besar. Patrol taped the floor. Forensics can't get there till six." },
				{ at = 9.5, duration = 2.1, speaker = "You", text = "So until six—" },
			},
		},
		{
			id = "CAR-DESTINATION", duration = 18.5, set = "Car", lighting = "CarInterior",
			camera = {
				from = point(Vector3.new(0.2, 5.1, 1.5), Vector3.new(12, 22, -190)),
				to = point(Vector3.new(0.6, 5.2, 0.4), Vector3.new(14, 44, -190)),
				fieldOfView = 54, fieldOfViewTo = 44, ease = "InOut",
			},
			lines = {
				{ at = 0.2, duration = 5.6, speaker = "Nora", text = "Until six, it's yours. His wife is up there. So is his partner. Nobody's gone home." },
				{ at = 6.0, duration = 4.8, speaker = "Nora", text = "They've had two hours to decide what happened. You haven't had any. Good." },
				{ at = 11.0, duration = 2.8, speaker = "Nora", text = "Listen to all of them. Believe the room." },
				{ at = 14.0, duration = 1.2, speaker = "You", text = "And you?" },
				{ at = 15.5, duration = 2.5, speaker = "Nora", text = "I'll be asleep. Call me when you know." },
			},
			sounds = { { at = 0, cue = "RainInterior" }, { at = 0, cue = "Wipers" }, { at = 0, cue = "Motif", volume = 0.18, fade = 0.5 } },
		},
	}
end

local function arrival(): { Shot }
	return {
		{
			id = "TOWER-ARRIVE", duration = 7, set = "Forecourt", lighting = "Forecourt",
			camera = {
				from = point(Vector3.new(38, 7.8, 46), Vector3.new(6, 4.5, -18)),
				to = point(Vector3.new(21, 6.6, 30), Vector3.new(7, 3.5, -20)),
				fieldOfView = 57, fieldOfViewTo = 49, ease = "InOut",
			},
			actions = { { at = 0.1, name = "SedanArrives" }, { at = 3.2, name = "StepOut" } },
			sounds = { { at = 0, cue = "RainStreet", fade = 0.6 }, { at = 3.2, cue = "CarDoor" }, { at = 5.8, cue = "Motif", volume = 0.24, fade = 0.8 } },
		},
		{
			id = "TOWER-NINTH", duration = 8, set = "Forecourt", lighting = "Forecourt",
			camera = {
				from = point(Vector3.new(29, 12, 22), Vector3.new(0, 8, -43)),
				to = point(Vector3.new(18, 47, 23), Vector3.new(0, 93, -43)),
				fieldOfView = 52, fieldOfViewTo = 38, ease = "Out",
			},
			sounds = { { at = 0, cue = "RainStreet" }, { at = 0, cue = "Motif", volume = 0.27, fade = 0.8 } },
		},
		{
			id = "TOWER-DOOR", duration = 7, set = "Forecourt", lighting = "Forecourt",
			camera = {
				from = point(Vector3.new(12, 5.8, 12), Vector3.new(1, 5.4, -22)),
				to = point(Vector3.new(6, 5.2, 2), Vector3.new(1, 5.2, -25)),
				fieldOfView = 46, fieldOfViewTo = 40, ease = "InOut",
			},
			actions = { { at = 0.2, name = "LightsOff" } },
			-- The beep lands as the investigator reaches the entrance reader.
			sounds = { { at = 0, cue = "RainStreet" }, { at = 4.5, cue = "BadgeBeep", volume = 0.35 }, { at = 0, cue = "Motif", volume = 0.18, fade = 0.8 } },
		},
	}
end

local function lobby(): { Shot }
	return {
		{
			id = "LOBBY-CONSTABLE", duration = 6, set = "Lobby", lighting = "Lobby",
			camera = {
				from = point(Vector3.new(-34, 6.1, 1), Vector3.new(-23, 6.2, -15)),
				to = point(Vector3.new(-29, 5.9, -3), Vector3.new(-23, 6.2, -15)),
				fieldOfView = 50, fieldOfViewTo = 44, ease = "Out",
			},
			actions = { { at = 0.7, name = "ConstableNods" } },
			sounds = { { at = 0, cue = "RoomTone", fade = 0.7 }, { at = 0, cue = "Motif", volume = 0.12, fade = 1.2 } },
			lines = { { at = 1.0, duration = 3, speaker = "Constable", text = "Level nine, Inspector." } },
		},
		{
			id = "LOBBY-ACCESS", duration = 8, set = "Lobby", lighting = "Lobby",
			camera = {
				from = point(Vector3.new(-4, 5.4, 10), Vector3.new(8, 3.6, -2)),
				to = point(Vector3.new(2, 4.9, 5), Vector3.new(8, 3.5, -2)),
				fieldOfView = 48, fieldOfViewTo = 42, ease = "InOut",
			},
			actions = { { at = 0.6, name = "TapCard" }, { at = 1.15, name = "ReaderAccepts" } },
			sounds = { { at = 0, cue = "RoomTone" }, { at = 0.7, cue = "BadgeBeep", volume = 0.5 }, { at = 0, cue = "Motif", volume = 0.1, fade = 1.3 } },
			lines = { { at = 2.0, duration = 3.4, speaker = "System", text = "ACCESS GRANTED  ·  12:38 AM" } },
		},
	}
end

local function lift(): { Shot }
	local rideActions: { Types.CutsceneAction } = {
		{ at = 0, name = "DoorsClose", args = { time = 1.4 } },
		{ at = 0.1, name = "Display", args = { text = "G" } },
		{ at = 0.35, name = "Shudder", args = { amount = 0.05, time = 0.8 } },
	}
	for floor = 1, 8 do
		table.insert(rideActions, { at = 0.8 + floor * 2.2, name = "Display", args = { text = tostring(floor) } })
	end
	table.insert(rideActions, { at = 19.0, name = "Display", args = { text = "9" } })
	table.insert(rideActions, { at = 19.4, name = "Shudder", args = { amount = 0.07, time = 0.75 } })
	return {
		{
			id = "LIFT-RIDE", duration = 20, set = "LiftCar", mouseLook = true,
			lighting = "Lift",
			camera = { from = point(LIFT_EYE, LIFT_DOORS), fieldOfView = 66, handheld = 0.035 },
			actions = rideActions,
			sounds = {
				{ at = 0, cue = "Motif", stop = true, fade = 6 },
				{ at = 0, cue = "LiftHumA", from = 2.6, fade = 0.5 },
				{ at = 5.6, cue = "LiftHumA", stop = true, fade = 0.4 },
				{ at = 5.3, cue = "LiftHumB", from = 2.6, fade = 0.4 },
				{ at = 11.0, cue = "LiftHumB", stop = true, fade = 0.4 },
				{ at = 10.6, cue = "LiftHumA", from = 2.6, fade = 0.4 },
				{ at = 16.3, cue = "LiftHumA", stop = true, fade = 0.5 },
				{ at = 15.9, cue = "LiftHumB", from = 2.6, fade = 0.4 },
				{ at = 19.3, cue = "Notification" },
				{ at = 19.4, cue = "LiftHumB", stop = true, fade = 0.5 },
			},
			lines = { { at = 12.2, duration = 4.4, speaker = "Nora", text = "Don't forget to eat." } },
		},
		{
			id = "LIFT-PAUSE", duration = 5, set = "LiftCar", mouseLook = true, lighting = "Lift",
			camera = { from = point(LIFT_EYE, LIFT_DOORS), fieldOfView = 66, fieldOfViewTo = 62, ease = "Out", handheld = 0.015 },
			-- The car settles on its brakes: one small shudder, then stillness.
			actions = { { at = 0.2, name = "Shudder", args = { amount = 0.04, time = 0.6 } } },
			sounds = { { at = 0, cue = "RoomTone", fade = 0.8 } },
		},
		{
			id = "LIFT-OPEN", duration = 10, set = "LiftCar", mouseLook = true, lighting = "Lift",
			camera = { from = point(LIFT_EYE, LIFT_DOORS), fieldOfView = 62, fieldOfViewTo = 58, ease = "InOut", handheld = 0.012 },
			actions = { { at = 0.5, name = "DoorsOpen", args = { time = 2.2 } } },
			sounds = { { at = 0.5, cue = "LiftBell", from = 8.6 }, { at = 0.5, cue = "Motif", stop = true, fade = 1.5 }, { at = 1.4, cue = "RoomTone", fade = 0.8 } },
			titleCard = { at = 1.4, duration = 4.2, kicker = "CASE 001", title = "THE LAST CALL", subtitle = "Rozario & Lim  ·  Level 9  ·  12:40 AM" },
		},
	}
end

local function buildShots(): { Shot }
	local shots = bedroom()
	for _, group in ipairs({ city(), carAndCall(), arrival(), lobby(), lift() }) do
		for _, shot in ipairs(group) do table.insert(shots, shot) end
	end
	return shots
end

local Intro: Types.CutsceneDefinition = {
	id = "CUT-INTRO",
	-- On later runs the player is already familiar with the setup; replay the
	-- final arrival and give control at the same lift handoff.
	replayFrom = "LIFT-OPEN",
	shots = buildShots(),
}

return Intro
