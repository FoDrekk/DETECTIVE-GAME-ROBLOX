--!strict
--[[
	OfficeInterior
	The office as a lived-in workplace at 12:40 AM, built at runtime on top of
	the shell (OfficeShell), like the rest of the environment staging.

	What it does:
	  * Finishes: carpet in the open plan and the meeting room, marble in
	    reception and the entrance hall, walnut boards in Daniel's office,
	    tiles in the pantry, concrete in the records room and the studio; a
	    dropped ceiling over the two rooms that have one.
	  * Lighting as a story beat: after hours most of the floor is dark.
	    Daniel's office is lit ("His light was on. It's always on."), the
	    meeting room is set for a midnight signing, reception is lit for the
	    guard, one bank over the desks was left on, the pantry's strip light
	    glows, the records room tube flickers, and the city's glow comes in
	    through the north windows. Few lights cast shadows (performance).
	  * Furnishing: each room's module (src/server/rooms) places its own
	    furniture and story dressing from PropKit, relative to OfficePlan.

	A few dressing props are interactable flavour objects (GuardFlask,
	MeetingWater, ElevatorPanel, ...): tagged with the shared Interactable
	contract by the room modules; their text is case data
	(Case001.observations) applied by OfficeRoom.finalize, which runs after
	this module.

	No case logic, no evidence: evidence props are OfficeRoom's.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))

local PropKit = require(script.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent:WaitForChild("InteriorKit"))
local Rooms = script.Parent:WaitForChild("rooms")
local DanielOffice = require(Rooms:WaitForChild("DanielOffice"))
local Archive = require(Rooms:WaitForChild("Archive"))
local Pantry = require(Rooms:WaitForChild("Pantry"))
local MeetingRoom = require(Rooms:WaitForChild("MeetingRoom"))
local Studio = require(Rooms:WaitForChild("Studio"))
local OpenPlan = require(Rooms:WaitForChild("OpenPlan"))
local Reception = require(Rooms:WaitForChild("Reception"))
local Spine = require(Rooms:WaitForChild("Spine"))

local log = Logger.scoped("OfficeInterior")

local OfficeInterior = {}

local M = Enum.Material
local FOLDER_NAME = "Interior"
local CEILING_Y = OfficePlan.CeilingY
-- Underside of the dropped ceilings over Daniel's office and the meeting room
-- (a 0.3-thick slab at y = 11).
local DROPPED_Y = OfficePlan.DroppedCeilingY - 0.15
local FLOOR_TOP = Kit.FLOOR_TOP
local ROOM_TOP = Kit.ROOM_TOP
local PLASTER = Color3.fromRGB(180, 176, 168)

local Style = Config.Environment.Interior

--------------------------------------------------------------------------
-- Finishes
--------------------------------------------------------------------------

type FloorRect = { number }
type Zone = { name: string, rects: { FloorRect }, color: Color3, material: Enum.Material }

local function rectOf(name: string): FloorRect
	local r = OfficePlan.rect(name)
	return { r.x0, r.x1, r.z0, r.z1 }
end

local function finishes(folder: Instance)
	--[[
		Floors.

		One clear physical surface, layered so nothing fights in the depth
		buffer:

		  * Shell.Floor is sunk well below and left only as a backstop.
		  * The base Carpet is the real floor, its top at Y = 0.00, so every
		    floor-standing prop rests on it exactly. It is CanCollide/CanQuery,
		    so player collision and SuspectSpawner.floorBelow's downward ray
		    both land on it.
		  * Room slabs are a thin decorative layer 0.03 above the carpet (the
		    smallest gap that reliably avoids z-fighting), also CanCollide/
		    CanQuery, so inside a room the player and NPCs stand on the
		    surface actually being drawn.

		Clearances: backstop top -0.60; carpet -0.06..0.00; room slabs
		-0.02..0.03. Every visible pair is separated by >= 0.03 and the large
		flat surfaces (carpet vs backstop) by 0.54.
	]]
	local floors = Kit.folder(folder, "Floors")
	local f = OfficePlan.Footprint
	local t = OfficePlan.WallThickness / 2
	local carpet = Kit.slab(floors, "Carpet", f.x0 + t, f.x1 - t, f.z0 + t, f.z1 - t, FLOOR_TOP - 0.03, 0.06, Color3.fromRGB(58, 62, 70), M.Carpet)
	carpet.CanCollide = true
	carpet.CanQuery = true

	local zones: { Zone } = {
		{
			name = "Lobby",
			-- Reception (an L round the lift core) and the entrance hall.
			rects = { { 6.5, 27.0, 8.5, 27.5 }, { 27.0, 35.5, 8.5, 19.0 }, { -5.5, 6.5, 8.5, 27.5 } },
			color = Color3.fromRGB(208, 202, 192),
			material = M.Marble,
		},
		{ name = "DanielOffice", rects = { rectOf("DanielOffice") }, color = Color3.fromRGB(92, 64, 44), material = M.WoodPlanks },
		{ name = "MeetingRoom", rects = { rectOf("MeetingRoom") }, color = Color3.fromRGB(44, 52, 68), material = M.Carpet },
		{ name = "Records", rects = { rectOf("Archive") }, color = Color3.fromRGB(128, 126, 122), material = M.Concrete },
		{ name = "Pantry", rects = { rectOf("Pantry") }, color = Color3.fromRGB(196, 194, 188), material = M.CeramicTiles },
		{ name = "Studio", rects = { rectOf("Studio") }, color = Color3.fromRGB(152, 154, 152), material = M.Concrete },
		{
			name = "Runner",
			rects = { { -5.5, 5.5, -27.5, 8.5 } },
			color = Color3.fromRGB(82, 84, 90),
			material = M.Carpet,
		},
	}
	for _, zone in ipairs(zones) do
		for i, r in ipairs(zone.rects) do
			local finish = Kit.slab(floors, if #zone.rects > 1 then `{zone.name}_{i}` else zone.name, r[1], r[2], r[3], r[4], ROOM_TOP - 0.025, 0.05, zone.color, zone.material)
			finish.CanCollide = true
			finish.CanQuery = true
		end
	end

	-- The two rooms with a dropped ceiling, over the suspended one the shell built.
	local ceiling = Kit.folder(folder, "Ceiling")
	for _, name in ipairs({ "DanielOffice", "MeetingRoom" }) do
		local r = OfficePlan.rect(name)
		local dropped = Kit.slab(ceiling, `{name}_DroppedCeiling`, r.x0, r.x1, r.z0, r.z1, OfficePlan.DroppedCeilingY, 0.3, PLASTER, M.Plaster)
		dropped.CanCollide = false
	end
end

-- Blinds across the three north windows, partly lowered.
local function windows(folder: Instance)
	local group = Kit.folder(folder, "Windows")
	local north = OfficePlan.getWall("North")
	local lowered = { 0.8, 0.22, 0.5 }
	local index = 0
	for _, o in ipairs(north.openings) do
		if o.kind == "window" then
			index += 1
			PropKit.blinds(group, Kit.at(o.center, north.at + OfficePlan.WallThickness / 2 - 0.05, Kit.SOUTH, 7), o.width - 0.6, 7.4, lowered[index] or 0.4)
		end
	end
end

--------------------------------------------------------------------------
-- Lighting fixtures (the after-hours plan)
--------------------------------------------------------------------------

local function buildLights(folder: Instance)
	local lights = Kit.folder(folder, "Lights")

	local function panel(name: string, x: number, z: number, y: number, on: boolean, spec: any?)
		local model = PropKit.ceilingPanel(lights, CFrame.new(x, y, z), Vector2.new(2, 4), on, spec)
		model.Name = name
		return model
	end

	-- Daniel's office: his light was on.
	panel("DanielOffice", -26, -17, DROPPED_Y, true, Style.Lights.DanielOffice)
	panel("DanielOfficeEast", -21, -12, DROPPED_Y, false)
	-- Meeting room: dim room light; the pendants over the table are on.
	panel("MeetingRoom", 21, -12, DROPPED_Y, true, Style.Lights.MeetingRoom)
	-- Reception, for the guard, and the entrance hall.
	panel("Reception", 17, 19.5, CEILING_Y, true, Style.Lights.Reception)
	panel("Lobby", 12, 12, CEILING_Y, true, Style.Lights.Lobby)
	panel("ReceptionEast", 29, 13, CEILING_Y, false)
	panel("EntranceHall", 0, 21, CEILING_Y, true, Style.Lights.Lobby)
	-- One bank left on over the desks; the rest of the floor is dark.
	panel("OpenPlanOn", -21, 3.5, CEILING_Y, true, Style.Lights.OpenPlan)
	panel("OpenPlanNight", -12.5, 14, CEILING_Y, true, Style.Lights.NightLight)
	panel("OpenPlanOff", -21, 22, CEILING_Y, false)
	panel("Studio", 20, 0, CEILING_Y, true, Style.Lights.Studio)
	panel("StudioNight", 31, 0, CEILING_Y, true, Style.Lights.NightLight)
	-- Corridor night lights.
	panel("CorridorNorth", 0, -21, CEILING_Y, true, Style.Lights.Corridor)
	panel("CorridorMid", 0, -9, CEILING_Y, false)
	panel("CorridorJunction", 0, 2, CEILING_Y, true, Style.Lights.Corridor)
	panel("CorridorSouth", 0, 12, CEILING_Y, false)
	panel("WestHall", -22, -3, CEILING_Y, true, Style.Lights.WestHall)
	-- The pantry, lit from within.
	panel("Pantry", -11, -13, CEILING_Y, true, Style.Lights.Pantry)
	-- Records room: a tube on its way out.
	panel("Records", -11, -23, CEILING_Y, true, Style.Lights.Records)
end

-- Locate the flicker target inside an already-built (or baked) interior, so
-- the runtime loop can be armed whether the geometry was just built or
-- adopted from an Edit-mode bake.
local function findFlickerParts(interior: Instance): { BasePart }
	local lights = interior:FindFirstChild("Lights")
	local records = lights and lights:FindFirstChild("Records")
	local diffuser = records and records:FindFirstChild("Diffuser")
	if diffuser and diffuser:IsA("BasePart") then
		return { diffuser }
	end
	return {}
end

-- The records-room tube: mostly steady, now and then a stutter. One light,
-- a slow server loop (no per-frame work).
local function startFlicker(parts: { BasePart })
	for _, diffuser in ipairs(parts) do
		local light = diffuser:FindFirstChildWhichIsA("Light")
		if not light then
			continue
		end
		local steady = light.Brightness
		local rng = Random.new(1122)
		task.spawn(function()
			while diffuser.Parent do
				task.wait(rng:NextNumber(3, 9))
				for _ = 1, rng:NextInteger(2, 4) do
					light.Brightness = steady * 0.15
					diffuser.Material = M.SmoothPlastic
					task.wait(rng:NextNumber(0.04, 0.12))
					light.Brightness = steady
					diffuser.Material = M.Neon
					task.wait(rng:NextNumber(0.05, 0.2))
				end
			end
		end)
	end
end

-- Rain running down the office's north windows: slow beads on the glass,
-- city-cool, in the same spirit as the cold open's window. Runtime state
-- (particles never belong in a saved bake), armed on the shell's glass panes.
local function startWindowRain(office: Instance)
	local shell = office:FindFirstChild("Shell")
	if not shell then
		return
	end
	for _, pane in ipairs(shell:GetDescendants()) do
		if pane:IsA("BasePart") and pane.Name:match("^WinGlass") then
			local beads = Instance.new("ParticleEmitter")
			beads.Name = "RainBeads"
			beads.Rate = 9
			beads.Lifetime = NumberRange.new(4, 8)
			beads.Speed = NumberRange.new(0.1, 0.45)
			beads.SpreadAngle = Vector2.new(4, 4)
			beads.EmissionDirection = Enum.NormalId.Bottom
			beads.Size = NumberSequence.new(0.08, 0.045)
			beads.Transparency = NumberSequence.new(0.25, 0.85)
			beads.Color = ColorSequence.new(Color3.fromRGB(170, 198, 232))
			beads.LightEmission = 0.55
			beads.Acceleration = Vector3.new(0, -0.55, 0)
			-- The plane of the glass: north wall, so beads slide along it.
			beads.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			beads.Parent = pane
		end
	end
end

--------------------------------------------------------------------------
-- Public entry points
--------------------------------------------------------------------------

-- Replace the signage in an already-baked interior (Edit mode), leaving
-- everything else, and any author edits to it, untouched. Returns whether
-- there was an interior to patch.
function OfficeInterior.patchSignage(): boolean
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local interior = office and office:FindFirstChild(FOLDER_NAME)
	if not interior then
		return false
	end
	local old = interior:FindFirstChild("Signage")
	if old then
		old:Destroy()
	end
	Spine.signage(interior)
	return true
end

function OfficeInterior.start()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} not found; skipping interior`)
		return
	end
	local interior = office:FindFirstChild(FOLDER_NAME)
	local wasBaked = interior ~= nil
	if interior then
		-- Baked already (Edit-mode bake or a previous run): adopt the
		-- geometry as-is so author edits to props and lights survive. Only
		-- the runtime wiring below runs.
		log:info("interior already present; adopting baked geometry")
	else
		interior = Instance.new("Folder")
		interior.Name = FOLDER_NAME
		interior.Parent = office

		finishes(interior)
		windows(interior)
		buildLights(interior)
		DanielOffice.build(interior)
		Archive.build(interior)
		Pantry.build(interior)
		MeetingRoom.build(interior)
		Studio.build(interior)
		OpenPlan.build(interior)
		Reception.build(interior)
		Spine.build(interior)
		Spine.signage(interior)
	end

	-- The flicker loop and the window rain are runtime state: an Edit-mode
	-- bake only positions the parts; a running game arms the loops.
	if RunService:IsRunning() then
		startFlicker(findFlickerParts(interior))
		startWindowRain(office)
	end

	local parts, lights = 0, 0
	for _, d in ipairs(interior:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	log:info("interior ready", { parts = parts, lights = lights, baked = wasBaked })
end

return OfficeInterior
