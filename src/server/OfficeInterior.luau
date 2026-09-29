--!strict
--[[
	OfficeInterior
	The office as a lived-in workplace at 12:40 AM: finishes, furniture,
	after-hours lighting and room dressing, built at runtime on top of the
	authored shell (assets/Office.rbxm), like the rest of the environment
	staging (see OfficeDetailing for why the binary asset is not edited).

	What it does:
	  * Finishes: carpet in the open plan, marble in the lobby, walnut boards
	    in Daniel's office, tiles in the kitchenette, concrete in the records
	    room; plaster walls; a suspended ceiling at a human scale (the shell's
	    16-stud ceiling read as a warehouse).
	  * Furniture: the shell's block desks, chairs, table and bench are
	    replaced by PropKit furniture in the same places (the authored
	    interactables -- evidence and flavour objects -- keep their names,
	    tags and positions; some are restyled in place).
	  * Lighting as a story beat: after hours most of the floor is dark.
	    Daniel's office is lit ("His light was on. It's always on."), the
	    meeting room is set for a midnight signing, reception is lit for the
	    guard, one bank over the desks was left on, the kitchenette strip
	    light glows, the records room tube flickers, and the city's glow comes
	    in through the north windows. Few lights cast shadows (performance).
	  * Dressing that tells the story without saying it: chairs left where
	    people got up, a visitor chair pulled back from Daniel's desk, water
	    glasses set out for a meeting nobody sat down to, a jacket still on the
	    coat rack, a cancelled anniversary flyer on the noticeboard.

	A few dressing props are interactable flavour objects (GuardFlask,
	MeetingWater, ElevatorPanel): tagged with the shared Interactable
	contract here; their text is case data (Case001.observations) applied by
	OfficeRoom.finalize, which runs after this module.

	No case logic, no evidence: evidence props are OfficeRoom's.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))

local PropKit = require(script.Parent:WaitForChild("PropKit"))

local log = Logger.scoped("OfficeInterior")

local OfficeInterior = {}

local P = PropKit.Palette
local M = Enum.Material
local FOLDER_NAME = "Interior"
local CEILING_Y = 12
-- Underside of the dropped ceilings over Daniel's office and the meeting
-- room (OfficeDetailing builds them at y = 11, 0.3 thick).
local DROPPED_Y = 10.85
-- Floors are laid out so the base carpet's top sits exactly at the old Y=0
-- the authored shell and all floor-standing props use, so nothing sinks into
-- it. Room finishes are a thin decorative layer 0.03 above the carpet (the
-- smallest gap that reliably avoids z-fighting); both are walkable. See
-- finishShell for the full layering.
local FLOOR_TOP = 0.00
local ROOM_TOP = 0.03

local Style = Config.Environment.Interior

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

-- A placement on the floor (or at height y) at (x, z), facing `facing`.
local function at(x: number, z: number, facing: Vector3, y: number?): CFrame
	local p = Vector3.new(x, y or 0, z)
	return CFrame.lookAt(p, p + facing)
end

local function slab(parent: Instance, name: string, x0: number, x1: number, z0: number, z1: number, y: number, thickness: number, color: Color3, material: Enum.Material): Part
	local p = PropKit.newPart(
		parent,
		name,
		Vector3.new(x1 - x0, thickness, z1 - z0),
		CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2),
		color,
		material
	)
	p.CastShadow = false
	return p
end

local function find(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function destroy(root: Instance, path: { string })
	local target = find(root, path)
	if target then
		target:Destroy()
	end
end

-- Tag a dressing part as an interactable flavour object (text comes from
-- case data, applied by OfficeRoom.finalize).
local function flavour(part: BasePart, prompt: string)
	CollectionService:AddTag(part, Interactable.TAG)
	part:SetAttribute(Interactable.AttributeName.Kind, "Examine")
	part:SetAttribute(Interactable.AttributeName.PromptLabel, prompt)
end

--------------------------------------------------------------------------
-- Shell: finishes, ceiling, windows
--------------------------------------------------------------------------

local function finishShell(office: Instance, folder: Instance)
	local shell = office:FindFirstChild("Shell")
	if shell then
		for _, p in ipairs(shell:GetChildren()) do
			if p:IsA("BasePart") then
				if string.find(p.Name, "^Wall_") then
					p.Color = P.Plaster
					p.Material = M.Plaster
				elseif string.find(p.Name, "^Part_") and p.Material ~= M.Glass then
					p.Color = Color3.fromRGB(198, 194, 186)
					p.Material = M.Plaster
				elseif string.find(p.Name, "^WinFrame") or string.find(p.Name, "^Trim") then
					p.Color = P.Charcoal
					p.Material = M.Metal
				elseif string.find(p.Name, "^WinGlass") then
					p.Color = Color3.fromRGB(70, 88, 110)
					p.Transparency = 0.7
					p.Reflectance = 0.08
				elseif p.Name == "Floor" then
					p.Color = Color3.fromRGB(70, 70, 72)
				end
			end
		end
	end

	-- Floors.
	--
	-- The authored `Shell.Floor` (top at Y=0.00) and the decorative finishes
	-- used to sit within 0.075 studs of each other across the same 59x47
	-- footprint, so their surfaces fought in the depth buffer and flickered.
	-- A single floor cannot both be coplanar with another opaque floor and be
	-- free of flicker, so this establishes one clear physical surface:
	--
	--   * `Shell.Floor` is sunk well below the room and left only as a
	--     backstop (it stays collidable/queryable, but nothing rests on it).
	--   * The base `Carpet` is the real floor, with its top at the authored
	--     Y=0.00 so every floor-standing prop (authored or placed at Y=0)
	--     rests on it exactly rather than sinking. It is CanCollide/CanQuery,
	--     so player collision and SuspectSpawner.floorBelow's downward
	--     raycast both land on it.
	--   * Room slabs are a thin decorative layer 0.03 above the carpet (the
	--     smallest gap that reliably avoids z-fighting) and are also
	--     CanCollide/CanQuery, so inside a room the player and NPCs stand on
	--     the surface actually being drawn (0.03) instead of sinking to the
	--     carpet 0.03 below it.
	--
	-- Clearances: shell-floor top is sunk to -0.60; carpet spans -0.06..0.00;
	-- room slabs span -0.02..0.03. Every visible pair is separated by >= 0.03
	-- and the large flat surfaces (carpet vs shell) by 0.54, so nothing
	-- fights.

	-- Guarded by an attribute: an Edit-mode bake sinks it once and persists
	-- that; a later re-run (partial rebuild) must not sink it again.
	local shellFloor = find(office, { "Shell", "Floor" })
	if shellFloor and shellFloor:IsA("BasePart") and not shellFloor:GetAttribute("FloorSunk") then
		-- Sink the authored floor so its top is well below the new surface.
		shellFloor.Position = Vector3.new(
			shellFloor.Position.X,
			shellFloor.Position.Y - 0.6,
			shellFloor.Position.Z
		)
		shellFloor:SetAttribute("FloorSunk", true)
	end

	local floors = Instance.new("Folder")
	floors.Name = "Floors"
	floors.Parent = folder

	-- The base carpet: the physical, walkable floor everywhere.
	local carpet = slab(floors, "Carpet", -29.5, 29.5, -23.5, 23.5, FLOOR_TOP - 0.03, 0.06, Color3.fromRGB(58, 62, 70), M.Carpet)
	carpet.CanCollide = true
	carpet.CanQuery = true

	type Zone = { name: string, x0: number, x1: number, z0: number, z1: number, color: Color3, material: Enum.Material }
	local zones: { Zone } = {
		{ name = "Lobby", x0 = 10.5, x1 = 29.5, z0 = 7, z1 = 23.5, color = Color3.fromRGB(208, 202, 192), material = M.Marble },
		{ name = "DanielOffice", x0 = -29.5, x1 = -14.5, z0 = -13.5, z1 = -2.5, color = Color3.fromRGB(92, 64, 44), material = M.WoodPlanks },
		{ name = "MeetingRoom", x0 = 10.5, x1 = 29.5, z0 = -23.5, z1 = -6.5, color = Color3.fromRGB(44, 52, 68), material = M.Carpet },
		{ name = "Records", x0 = -29.5, x1 = -14.5, z0 = -23.5, z1 = -14.5, color = Color3.fromRGB(128, 126, 122), material = M.Concrete },
		{ name = "Kitchenette", x0 = -13.5, x1 = -9.5, z0 = -23.5, z1 = -13.2, color = Color3.fromRGB(196, 194, 188), material = M.CeramicTiles },
		{ name = "Runner", x0 = -7, x1 = 3, z0 = -23.5, z1 = 6, color = Color3.fromRGB(82, 84, 90), material = M.Carpet },
	}
	-- Room finishes: thin, disjoint, a clear gap above the base carpet. They
	-- are the visible floor in their rooms, so they are walkable too.
	for _, zone in ipairs(zones) do
		local finish = slab(floors, zone.name, zone.x0, zone.x1, zone.z0, zone.z1, ROOM_TOP - 0.025, 0.05, zone.color, zone.material)
		finish.CanCollide = true
		finish.CanQuery = true
	end
	-- The doormat sits on the lobby finish, not on the base carpet.
	slab(floors, "Doormat", 14.8, 21.2, 21.4, 23.4, ROOM_TOP + 0.01, 0.02, Color3.fromRGB(36, 36, 38), M.Fabric)

	-- A suspended ceiling at 12 studs with a T-bar grid.
	local ceiling = Instance.new("Folder")
	ceiling.Name = "Ceiling"
	ceiling.Parent = folder
	slab(ceiling, "Tiles", -29.5, 29.5, -23.5, 23.5, CEILING_Y + 0.05, 0.1, Color3.fromRGB(206, 204, 198), M.Plaster)
	for x = -26, 26, 4 do
		slab(ceiling, "TBar", x - 0.05, x + 0.05, -23.5, 23.5, CEILING_Y - 0.02, 0.04, Color3.fromRGB(176, 176, 172), M.Metal)
	end
	for z = -20, 20, 4 do
		slab(ceiling, "TBar", -29.5, 29.5, z - 0.05, z + 0.05, CEILING_Y - 0.02, 0.04, Color3.fromRGB(176, 176, 172), M.Metal)
	end
	-- Close the authored gap between the entrance frame (11) and lintel.
	slab(folder, "EntranceTransom", 14, 22, 23.7, 24.3, 11.5, 1, P.Charcoal, M.Metal)

	-- The shell's high fixtures and its 16-stud warehouse ceiling both sit
	-- above the new suspended ceiling at 12: retire them. The ceiling has no
	-- collision or query dependency (nothing raycasts against it), and it is
	-- fully occluded from below by the new one, so removing it is safe and
	-- keeps the runtime shell consistent with what the room actually is.
	local lighting = office:FindFirstChild("Lighting")
	if lighting then
		lighting:Destroy()
	end
	local shellCeiling = shell and shell:FindFirstChild("Ceiling")
	if shellCeiling then
		shellCeiling:Destroy()
	end

	-- Blinds, and the city's glow coming in through the glass.
	local windows = Instance.new("Folder")
	windows.Name = "Windows"
	windows.Parent = folder
	local blinds = { [-22] = 0.8, [-4] = 0.22, [14] = 0.5 }
	for x, lowered in pairs(blinds) do
		PropKit.blinds(windows, at(x, -23.55, SOUTH, 7), 11.4, 7.4, lowered)
		-- The light lives on the authored glass; skip if a bake already
		-- attached one (force re-bake leaves it behind with the shell).
		local glass = shell and shell:FindFirstChild(`WinGlass_{x}`)
		if glass and glass:IsA("BasePart") and not glass:FindFirstChildWhichIsA("SurfaceLight") then
			PropKit.light(glass, "SurfaceLight", Style.CityGlow.Brightness, Style.CityGlow.Range, Style.CityGlow.Color, {
				face = Enum.NormalId.Back,
				angle = 75,
				shadows = false,
			})
		end
	end
end

--------------------------------------------------------------------------
-- Lighting fixtures (the after-hours plan)
--------------------------------------------------------------------------

local function buildLights(folder: Instance): { BasePart }
	local lights = Instance.new("Folder")
	lights.Name = "Lights"
	lights.Parent = folder
	local flicker: { BasePart } = {}

	local function panel(name: string, x: number, z: number, y: number, on: boolean, spec: any?)
		local model = PropKit.ceilingPanel(lights, CFrame.new(x, y, z), Vector2.new(2, 4), on, spec)
		model.Name = name
		return model
	end

	-- Daniel's office: his light was on.
	panel("DanielOffice", -22, -8, DROPPED_Y, true, Style.Lights.DanielOffice)
	-- Meeting room: dim room light; the pendant over the table is on.
	panel("MeetingRoom", 20, -20.5, DROPPED_Y, true, Style.Lights.MeetingRoom)
	PropKit.pendant(lights, CFrame.new(20, DROPPED_Y, -14), 3.3, true, Style.Lights.MeetingPendant.brightness, Style.Lights.MeetingPendant.range)
	-- Reception, for the guard.
	panel("Reception", 24, 18, CEILING_Y, true, Style.Lights.Reception)
	panel("Lobby", 16, 13, CEILING_Y, true, Style.Lights.Lobby)
	-- One bank left on over the west desks; the rest of the floor is dark.
	panel("OpenPlanOn", -22.5, 12.8, CEILING_Y, true, Style.Lights.OpenPlan)
	panel("OpenPlanOff1", -11.6, 12.8, CEILING_Y, false)
	panel("OpenPlanOff2", -22.5, 20.5, CEILING_Y, false)
	panel("EastDesks", 25, 0.3, CEILING_Y, true, Style.Lights.EastDesks)
	panel("EastOff", 17, -1.5, CEILING_Y, false)
	-- Corridor night lights.
	panel("CorridorNorth", -2, -17, CEILING_Y, true, Style.Lights.Corridor)
	panel("CorridorMid", -2, -6, CEILING_Y, false)
	panel("CorridorSouth", -2, 3.5, CEILING_Y, true, Style.Lights.Corridor)
	panel("WestHall", -20, 2.5, CEILING_Y, true, Style.Lights.WestHall)
	-- Records room: a tube on its way out.
	local records = panel("Records", -22, -19, CEILING_Y, true, Style.Lights.Records)
	local diffuser = records:FindFirstChild("Diffuser")
	if diffuser and diffuser:IsA("BasePart") then
		table.insert(flicker, diffuser)
	end
	return flicker
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

--------------------------------------------------------------------------
-- Rooms
--------------------------------------------------------------------------

local function danielsOffice(office: Instance, folder: Instance)
	local room = Instance.new("Folder")
	room.Name = "DanielOffice"
	room.Parent = folder

	-- The authored desk top stays (the evidence rests on it); its block legs,
	-- chair, monitor, lamp and glow are replaced.
	local desk = find(office, { "Furniture", "DanielDesk" })
	if desk then
		for _, child in ipairs(desk:GetChildren()) do
			if child:IsA("BasePart") then
				if child.Name == "Top" then
					child.Color = P.Walnut
					child.Material = M.Wood
				else
					child:Destroy()
				end
			end
		end
	end
	for _, name in ipairs({ "DanielChair", "DanielMonitor", "DanielLamp" }) do
		destroy(office, { "Furniture", name })
	end

	-- Executive base: a drawer pedestal under the drawer front, a panel
	-- leg, and a modesty panel on the visitor's side.
	local deskTop = 2.62
	local base = PropKit.newPart(room, "Pedestal", Vector3.new(1.8, deskTop - 0.26, 3.7), CFrame.new(-26.9, (deskTop - 0.26) / 2, -8), P.WalnutDark, M.Wood)
	base.CanCollide = true
	PropKit.newPart(room, "PanelLeg", Vector3.new(0.3, deskTop - 0.26, 3.8), CFrame.new(-20.35, (deskTop - 0.26) / 2, -8), P.WalnutDark, M.Wood).CanCollide = true
	PropKit.newPart(room, "Modesty", Vector3.new(6.2, 1.5, 0.12), CFrame.new(-23.6, 1.55, -9.8), P.WalnutDark, M.Wood)
	for i = 0, 1 do
		PropKit.newPart(room, "DrawerLine", Vector3.new(1.6, 0.03, 0.02), CFrame.new(-26.9, 0.75 + i * 0.7, -6.14), P.Walnut, M.Wood)
	end
	local deskCollider = PropKit.newPart(room, "DeskCollider", Vector3.new(8, deskTop, 4), CFrame.new(-24, deskTop / 2, -8), P.Charcoal, M.SmoothPlastic)
	deskCollider.Transparency = 1
	deskCollider.CanCollide = true
	deskCollider.CastShadow = false

	-- His chair, pulled out and turned toward the door: he got up.
	PropKit.officeChair(room, at(-23.6, -4.4, NORTH), {
		upholstery = P.Leather,
		material = M.Leather,
		highBack = true,
		yaw = 38,
	})
	-- The screen had gone to sleep; the lamp was left on.
	PropKit.monitor(room, at(-24, -9.55, SOUTH, deskTop), "off")
	PropKit.deskLamp(room, at(-27.3, -9.35, Vector3.new(0.5, 0, 1).Unit, deskTop), true)
	-- The visitor's chair, pushed back from the desk.
	PropKit.sideChair(room, at(-25.8, -12.0, SOUTH), { upholstery = P.FabricWarm, yaw = -14 })

	PropKit.shelving(room, at(-27.2, -13.4, SOUTH), 4.6, 7.4, 4, 31, { frame = P.WalnutDark, material = M.Wood, depth = 1.1 })
	-- The rug rests on the room finish (top at ROOM_TOP), not the base
	-- carpet, so it is not buried by the thin floor slab.
	PropKit.rug(room, at(-24, -7, NORTH, ROOM_TOP), 10, 7.5, Color3.fromRGB(70, 58, 52), Color3.fromRGB(46, 38, 34))
	PropKit.framedArt(room, at(-25.4, -2.52, NORTH, 6.3), 3.2, 2.3, 11)
	PropKit.framedArt(room, at(-28.7, -2.52, NORTH, 6.6), 1.2, 1.5, 12)
	-- His jacket is still on the rack.
	PropKit.coatRack(room, at(-15.3, -3.4, WEST), Color3.fromRGB(36, 40, 54))
	PropKit.plant(room, at(-29, -3.2, NORTH), 0.9, "blades")
	PropKit.bin(room, at(-20.9, -5.2, NORTH))
end

local function recordsRoom(office: Instance, folder: Instance)
	local room = Instance.new("Folder")
	room.Name = "Records"
	room.Parent = folder
	local storage = find(office, { "Furniture", "Storage" })
	if not storage then
		return
	end
	for _, child in ipairs(storage:GetChildren()) do
		if child:IsA("BasePart") then
			if string.find(child.Name, "^FileCabinet") then
				child.Color = P.Graphite
				child.Material = M.Metal
			elseif string.find(child.Name, "^DrawerFace") then
				child.Color = Color3.fromRGB(96, 98, 104)
				child.Material = M.Metal
				-- A handle and a label slot on each drawer face (they face +X).
				PropKit.newPart(room, "Handle", Vector3.new(0.1, 0.07, 0.6), child.CFrame * CFrame.new(0.08, 0.35, 0), P.Steel, M.Metal)
				PropKit.newPart(room, "Label", Vector3.new(0.02, 0.2, 0.45), child.CFrame * CFrame.new(0.06, 0.62, 0), P.Paper, M.SmoothPlastic)
			elseif string.find(child.Name, "^Shelf_Board") then
				child:Destroy()
			elseif child.Name == "Shelf_Frame" then
				-- Keep the interactable, hide its block; real shelving takes its place.
				child.Transparency = 1
				child.CanCollide = false
			end
		end
	end
	PropKit.shelving(room, at(-22, -23.2, SOUTH), 8, 7, 4, 5, { depth = 1.2 })
	PropKit.shelving(room, at(-15.2, -17.3, WEST), 4.5, 7.5, 5, 9, { depth = 1.2, sparse = true })
	PropKit.sign(room, at(-16.9, -13.45, NORTH, 6.2), "RECORDS", Vector2.new(1.8, 0.45))
end

local function meetingRoom(office: Instance, folder: Instance)
	local room = Instance.new("Folder")
	room.Name = "MeetingRoom"
	room.Parent = folder
	destroy(office, { "Furniture", "MeetingTable" })
	for i = 1, 4 do
		destroy(office, { "Furniture", `MeetChair_{i}` })
	end
	for i = 1, 3 do
		destroy(office, { "StoryProps", `MeetingPaper_{i}` })
	end
	destroy(office, { "StoryProps", "Clock" })
	destroy(office, { "StoryProps", "ClockFace" })

	local tableTop = 2.6
	PropKit.meetingTable(room, at(20, -14, SOUTH), 9, 4.2)
	-- Six chairs, tucked in neatly: nobody sat down.
	for _, x in ipairs({ 16.8, 20, 23.2 }) do
		PropKit.sideChair(room, at(x, -17.3, SOUTH))
		PropKit.sideChair(room, at(x, -10.7, NORTH))
	end
	-- Two places set, facing each other: water, a pen, a copy of the papers.
	for _, spot in ipairs({ { 18.2, -15.1, 1 }, { 21.8, -12.9, -1 } }) do
		local x, z, side = spot[1], spot[2], spot[3]
		local glass = PropKit.newPart(room, "WaterGlass", Vector3.new(0.5, 0.34, 0.34), CFrame.new(x + 0.9 * side, tableTop + 0.25, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 214, 226), M.Glass)
		glass.Shape = Enum.PartType.Cylinder
		glass.Transparency = 0.55
		PropKit.paperStack(room, at(x, z, if side > 0 then SOUTH else NORTH, tableTop), 4)
		PropKit.newPart(room, "Pen", Vector3.new(0.05, 0.05, 0.6), CFrame.new(x - 0.7 * side, tableTop + 0.03, z) * CFrame.Angles(0, math.rad(20), 0), P.LeatherBlack, M.SmoothPlastic)
	end
	local setting = PropKit.newPart(room, "MeetingWater", Vector3.new(4.6, 0.7, 3.2), CFrame.new(20, tableTop + 0.35, -14), P.Charcoal, M.SmoothPlastic)
	setting.Transparency = 1
	setting.CastShadow = false
	flavour(setting, "Examine the Table")

	-- The screen on the east wall, idle.
	local screen = find(office, { "Furniture", "PresScreen" })
	if screen and screen:IsA("BasePart") then
		screen.Color = P.LeatherBlack
		screen.Material = M.SmoothPlastic
	end
	local panelOn = find(office, { "Furniture", "PresScreenOn" })
	if panelOn and panelOn:IsA("BasePart") then
		panelOn.Color = Color3.fromRGB(14, 20, 30)
		panelOn.Material = M.Neon
		-- The label lives on the authored part; one bake already attached it.
		if not panelOn:FindFirstChildOfClass("SurfaceGui") then
			PropKit.label(panelOn, Enum.NormalId.Left, "HDMI 1\nNo signal", {
				color = Color3.fromRGB(110, 130, 160),
				font = Enum.Font.GothamMedium,
				size = 22,
				lightInfluence = 0,
			})
		end
	end

	-- The whiteboard: last quarter, and a partnership struck out.
	local board = find(office, { "Furniture", "Whiteboard" })
	if board and board:IsA("BasePart") then
		local gui = board:FindFirstChildOfClass("SurfaceGui") or PropKit.label(board, Enum.NormalId.Back, "", { pixelsPerStud = 60 })
		local text = gui:FindFirstChildOfClass("TextLabel")
		if text then
			text.RichText = true
			text.TextScaled = false
			text.TextSize = 34
			text.Font = Enum.Font.PermanentMarker
			text.TextColor3 = Color3.fromRGB(34, 52, 110)
			text.TextXAlignment = Enum.TextXAlignment.Left
			text.TextYAlignment = Enum.TextYAlignment.Top
			text.Text = "Q3 TARGETS\n\n<s>R&amp;L</s>   <font color=\"#9a2a2a\">R</font>\n\nretainers +12%\nnew clients: 4\n\n<font color=\"#9a2a2a\">sign by FRI</font>"
			local pad = text:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 40)
			pad.PaddingTop = UDim.new(0, 26)
			pad.Parent = text
		end
		PropKit.newPart(room, "MarkerTray", Vector3.new(4, 0.1, 0.35), CFrame.new(20, 3.62, -23.15), P.Steel, M.Metal)
		for i, color in ipairs({ Color3.fromRGB(30, 50, 120), Color3.fromRGB(150, 30, 30), P.LeatherBlack }) do
			local marker = PropKit.newPart(room, "Marker", Vector3.new(0.6, 0.12, 0.12), CFrame.new(18.8 + i * 0.7, 3.73, -23.15), color, M.SmoothPlastic)
			marker.Shape = Enum.PartType.Cylinder
		end
	end

	PropKit.plant(room, at(28.2, -22.3, SOUTH), 0.8, "tree")
	PropKit.wallClock(room, at(9.45, -14, WEST, 8.4), 12, 40)
	PropKit.sign(room, at(17.2, -5.45, SOUTH, 6.4), "MEETING", Vector2.new(1.9, 0.45))
end

local function reception(office: Instance, folder: Instance): BasePart?
	local room = Instance.new("Folder")
	room.Name = "Reception"
	room.Parent = folder
	local furniture = office:FindFirstChild("Furniture")

	-- The desk: walnut body, stone top, a fascia with the firm's name on the
	-- visitors' side (south, facing the entrance).
	local desk = furniture and furniture:FindFirstChild("ReceptionDesk")
	if desk and desk:IsA("BasePart") then
		desk.Color = P.WalnutDark
		desk.Material = M.Wood
		PropKit.newPart(room, "CounterTop", Vector3.new(6.2, 0.06, 2.2), desk.CFrame * CFrame.new(0, desk.Size.Y / 2 + 0.03, 0), Color3.fromRGB(52, 54, 58), M.Granite)
	end
	local fascia = furniture and furniture:FindFirstChild("ReceptionPanel")
	if fascia and fascia:IsA("BasePart") then
		fascia.CFrame = CFrame.new(24, 1.6, 19.08)
		fascia.Size = Vector3.new(6.2, 3.0, 0.14)
		fascia.Color = P.Walnut
		fascia.Material = M.WoodPlanks
		if not fascia:FindFirstChildOfClass("SurfaceGui") then
			PropKit.label(fascia, Enum.NormalId.Back, "ROZARIO & LIM", {
				color = Color3.fromRGB(206, 176, 112),
				font = Enum.Font.GothamBold,
				pixelsPerStud = 50,
				size = 30,
			})
		end
	end
	destroy(office, { "Furniture", "ReceptionChair" })
	destroy(office, { "Furniture", "LobbyBench" })
	destroy(office, { "Furniture", "Plant" })
	destroy(office, { "StoryProps", "Bin" })
	destroy(office, { "StoryProps", "UmbrellaStand" })

	-- The guard's chair behind the desk, and his flask on the counter.
	PropKit.officeChair(room, at(24.2, 15.7, SOUTH), { yaw = -20 })
	local flask = PropKit.newPart(room, "GuardFlask", Vector3.new(0.9, 0.32, 0.32), CFrame.new(22.1, 3.26 + 0.45, 17.55) * CFrame.Angles(0, 0, math.rad(90)), P.Steel, M.Metal)
	flask.Shape = Enum.PartType.Cylinder
	flask.Reflectance = 0.1
	PropKit.newPart(room, "FlaskCap", Vector3.new(0.14, 0.34, 0.34), CFrame.new(22.1, 3.26 + 0.97, 17.55) * CFrame.Angles(0, 0, math.rad(90)), P.LeatherBlack, M.SmoothPlastic).Shape = Enum.PartType.Cylinder
	flavour(flask, "Examine Flask")
	PropKit.newPart(room, "VisitorBook", Vector3.new(1.1, 0.1, 0.8), CFrame.new(26.3, 3.31, 18.5) * CFrame.Angles(0, math.rad(-8), 0), Color3.fromRGB(96, 30, 34), M.Leather)
	PropKit.bin(room, at(27.9, 16.3, NORTH))

	-- The firm's name on the east wall, lit from below.
	local logo = PropKit.newPart(room, "LogoWall", Vector3.new(0.2, 5, 8.5), CFrame.new(29.35, 5.6, 15.2), P.Walnut, M.WoodPlanks)
	PropKit.label(logo, Enum.NormalId.Left, "ROZARIO & LIM\n<font size=\"22\">DESIGN SDN. BHD. · EST. 2010</font>", {
		color = Color3.fromRGB(214, 184, 118),
		font = Enum.Font.GothamBold,
		pixelsPerStud = 50,
		size = 50, -- "ROZARIO & LIM" is longer than the old name: one line on this wall
		lightInfluence = 0.4,
		lineHeight = 1.1,
	})
	local text = (logo:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass("TextLabel")
	if text then
		text.RichText = true
	end
	local wash = PropKit.newPart(room, "LogoWash", Vector3.new(0.3, 0.2, 8), CFrame.new(29.1, 2.95, 15.2), P.Charcoal, M.Metal)
	PropKit.light(wash, "SpotLight", 1.2, 10, P.WarmLight, { face = Enum.NormalId.Top, angle = 70, shadows = false })

	-- The lift: parked on this floor, one trip down since midnight.
	local _, panel = PropKit.liftDoors(room, at(26, 23.45, NORTH))
	panel.Name = "ElevatorPanel"
	flavour(panel, "Examine Lift")

	-- Waiting area.
	PropKit.sofa(room, at(11.9, 15.5, EAST), 6, P.Fabric, M.Fabric)
	PropKit.coffeeTable(room, at(15.1, 15.5, EAST), 3.8, 2.2)
	PropKit.paperStack(room, at(15.3, 15.1, EAST, 1.26) * CFrame.Angles(0, math.rad(12), 0), 3)
	PropKit.armchair(room, at(15.1, 20.2, NORTH), P.FabricTeal)
	PropKit.floorLamp(room, at(11.2, 11.4, EAST), true)
	PropKit.plant(room, at(11.3, 22.6, EAST), 0.9, "tree")
	-- Two umbrellas: it rained earlier.
	PropKit.umbrellaStand(room, at(21.9, 22.9, NORTH), { Color3.fromRGB(28, 30, 36), Color3.fromRGB(90, 24, 30) })
	PropKit.exitSign(room, at(18, 23.45, NORTH, 11.2))
	return desk and desk:IsA("BasePart") and desk or nil
end

local function openPlan(folder: Instance)
	local room = Instance.new("Folder")
	room.Name = "OpenPlan"
	room.Parent = folder

	-- A pod: two desks each way, back to back, with a fabric divider.
	local function pod(cx: number, cz: number, width: number, seed: number, overrides: { [number]: any }?)
		local d = 2.3
		type Slot = { x: number, z: number, facing: Vector3 }
		local slots: { Slot } = {
			{ x = cx - width / 2, z = cz - d / 2, facing = NORTH },
			{ x = cx + width / 2, z = cz - d / 2, facing = NORTH },
			{ x = cx - width / 2, z = cz + d / 2, facing = SOUTH },
			{ x = cx + width / 2, z = cz + d / 2, facing = SOUTH },
		}
		for i, slot in ipairs(slots) do
			local r = Random.new(seed + i)
			local o: PropKit.DeskOptions = {
				width = width,
				depth = d,
				screen = if r:NextNumber() < 0.3 then "lock" else "off",
				clutter = seed * 10 + i,
				chairYaw = r:NextNumber(-25, 25),
				chairPushed = r:NextNumber(0, 0.6),
			}
			if overrides and overrides[i] then
				for k, v in pairs(overrides[i]) do
					(o :: any)[k] = v
				end
			end
			PropKit.desk(room, at(slot.x, slot.z, slot.facing), o)
		end
		local divider = PropKit.newPart(room, "Divider", Vector3.new(width * 2 - 0.4, 1.3, 0.1), CFrame.new(cx, 3.25, cz), P.FabricTeal, M.Fabric)
		divider.CastShadow = true
	end

	-- West desks (one bank of lights still on over them).
	pod(-22.5, 12.8, 4.6, 3, { [2] = { lamp = true, lampOn = true, monitors = 2 } })
	pod(-11.6, 12.8, 4.6, 7, { [3] = { monitors = 2 } })
	-- East desks, by the lobby.
	pod(25, 0.3, 4.2, 11, { [1] = { screen = "on" } })

	-- Lounge along the south wall.
	PropKit.rug(room, at(-22.5, 20.4, NORTH, FLOOR_TOP), 11, 5.6, Color3.fromRGB(96, 88, 80), Color3.fromRGB(70, 64, 58))
	PropKit.sofa(room, at(-22.5, 22.0, NORTH), 7, P.Fabric, M.Fabric)
	PropKit.coffeeTable(room, at(-22.5, 18.9, NORTH), 4, 2.2)
	PropKit.mug(room, at(-21.6, 18.7, NORTH, 1.26), Color3.fromRGB(60, 80, 110))
	PropKit.armchair(room, at(-27.9, 18.9, EAST), P.FabricWarm)
	PropKit.armchair(room, at(-17.1, 18.9, WEST), P.FabricWarm)
	PropKit.floorLamp(room, at(-28.6, 22.8, EAST), true)
	PropKit.framedArt(room, at(-22.5, 23.45, NORTH, 7.2), 6, 3.2, 21)
	PropKit.shelving(room, at(-12.5, 22.9, NORTH), 6, 3.2, 2, 13, { sparse = true, depth = 1.0 })
	PropKit.plant(room, at(-29.1, 15.6, EAST), 0.9, "tree")
	PropKit.plant(room, at(-9.3, 22.6, NORTH), 0.7, "bush")

	-- East side: copier and water by the lobby partition.
	PropKit.copier(room, at(12.2, 3.6, EAST))
	PropKit.waterCooler(room, at(11.0, -2.8, EAST))
	-- Noticeboard on the meeting room's outside wall.
	local board = PropKit.newPart(room, "Noticeboard", Vector3.new(5, 3, 0.12), CFrame.new(23, 6.2, -5.44), Color3.fromRGB(150, 116, 80), M.Cardboard)
	board.CastShadow = false
	type Note = { x: number, y: number, text: string, color: Color3, tilt: number }
	local notes: { Note } = {
		{ x = -1.6, y = 0.6, text = "FIRE DRILL\nThursday 10:00", color = Color3.fromRGB(236, 226, 150), tilt = -4 },
		{ x = 0.1, y = 0.5, text = "ROZARIO & LIM\n15 YEARS\nFriday drinks, 6pm\n<font color=\"#a02222\">CANCELLED</font>", color = P.Paper, tilt = 3 },
		{ x = 1.7, y = 0.7, text = "Kitchen rota:\nweek 3 — Sam", color = Color3.fromRGB(190, 220, 236), tilt = -2 },
		{ x = -1.5, y = -0.8, text = "Lost: grey scarf", color = Color3.fromRGB(236, 226, 150), tilt = 6 },
	}
	for _, n in ipairs(notes) do
		local note = PropKit.newPart(room, "Note", Vector3.new(1.3, 1.0, 0.02), CFrame.new(23 + n.x, 6.2 + n.y, -5.37) * CFrame.Angles(0, 0, math.rad(n.tilt)), n.color, M.SmoothPlastic)
		local gui = PropKit.label(note, Enum.NormalId.Back, n.text, { color = Color3.fromRGB(40, 40, 50), font = Enum.Font.GothamMedium, pixelsPerStud = 60 })
		local text = gui:FindFirstChildOfClass("TextLabel")
		if text then
			text.RichText = true
		end
	end
end

local function centre(folder: Instance)
	local room = Instance.new("Folder")
	room.Name = "Centre"
	room.Parent = folder

	-- The kitchenette, against the records room's outside wall.
	PropKit.kitchenRun(room, at(-12.5, -19.5, EAST), 7, true)
	PropKit.wallCabinets(room, at(-13.0, -19.5, EAST, 5.4), 7, true)
	PropKit.fridge(room, at(-12.45, -14.9, EAST))
	PropKit.microwave(room, at(-12.9, -18.9, EAST, 3.0))
	PropKit.kettle(room, at(-12.5, -20.5, EAST, 3.0))
	PropKit.mug(room, at(-12.2, -23.0, EAST, 3.0))
	PropKit.mug(room, at(-12.6, -22.8, EAST, 3.0), Color3.fromRGB(40, 60, 90))
	PropKit.bin(room, at(-10.8, -23.1, EAST))
	PropKit.sign(room, at(-13.45, -19.5, EAST, 9.2), "PANTRY", Vector2.new(1.8, 0.45))

	-- Outside Daniel's office: a noticeboard and an extinguisher.
	PropKit.fireExtinguisher(room, at(-13.45, -11.5, EAST))
	PropKit.framedArt(room, at(-26, -1.45, SOUTH, 6.2), 3.4, 2.4, 41)
	PropKit.plant(room, at(-29, 6, EAST), 0.8, "blades")
	PropKit.plant(room, at(7.6, -22.4, SOUTH), 0.8, "blades")
	PropKit.plant(room, at(-12.2, 5.6, SOUTH), 0.7, "bush")
	PropKit.exitSign(room, at(-1, 6.6, NORTH, 11.2))

	-- A breakout table between the corridor and Daniel's side of the floor.
	PropKit.highTable(room, at(-10.3, -6.5, EAST), 4.2, 1.8)
	PropKit.stool(room, at(-10.3, -8.3, SOUTH))
	PropKit.stool(room, at(-11.3, -4.8, NORTH))
	PropKit.stool(room, at(-9.1, -4.9, NORTH))
	PropKit.mug(room, at(-10.8, -6.3, EAST, 3.5), Color3.fromRGB(150, 60, 50))
	-- Planters along the meeting room's glass wall.
	for _, z in ipairs({ -21.2, -17.6, -14.0 }) do
		PropKit.planter(room, at(8.7, z, WEST), 3.2)
	end
	-- The hall outside Daniel's office: a bench under the print.
	PropKit.bench(room, at(-26, -0.4, SOUTH), 4.5)
end

--------------------------------------------------------------------------
-- Signage (Phase 5.2)
--------------------------------------------------------------------------

-- Small Malaysian office signage: environment only, no gameplay, nothing
-- tagged. Built into its own folder so a baked place can be patched with
-- OfficeInterior.patchSignage() instead of a full re-bake.
local function signage(interior: Instance)
	local room = Instance.new("Folder")
	room.Name = "Signage"
	room.Parent = interior

	-- "Sila imbas kad" (please tap your card) on the wall between the lift
	-- surround (x 23.7..28.3) and the entrance doors (frames end at x 22),
	-- with a surau wayfinding plate above it (the prayer room is on another
	-- floor; no room or door is implied here). Both are in the reception's
	-- light: the waiting area's walls are too dark to read a sign on.
	PropKit.sign(room, at(22.85, 23.4, NORTH, 4.5), "Sila imbas kad", Vector2.new(1.3, 0.34))
	PropKit.sign(room, at(22.85, 23.4, NORTH, 5.05), "SURAU · TINGKAT 8", Vector2.new(1.55, 0.34))

	-- "DILARANG MEROKOK" (no smoking) on the pantry wall, by the extinguisher.
	PropKit.sign(room, at(-13.42, -12.9, EAST, 5.2), "DILARANG MEROKOK", Vector2.new(2.0, 0.42), {
		plate = Color3.fromRGB(232, 232, 226),
		color = Color3.fromRGB(170, 30, 30),
	})

	-- "BUKU PELAWAT" (visitors' book): a small placard on a flat foot, on
	-- the reception counter in the gap between the printout and the camera
	-- monitor (which hides the book itself from the visitors' side).
	local ink = Color3.fromRGB(34, 36, 40)
	local plate = PropKit.newPart(room, "BookPlate", Vector3.new(0.86, 0.28, 0.04), at(24.1, 18.55, SOUTH, 3.26 + 0.04 + 0.14), ink, M.Metal)
	PropKit.label(plate, Enum.NormalId.Front, "BUKU PELAWAT", {
		color = Color3.fromRGB(214, 190, 138),
		font = Enum.Font.GothamBold,
		padding = 3,
	})
	PropKit.newPart(room, "BookFoot", Vector3.new(0.86, 0.04, 0.24), CFrame.new(24.1, 3.26 + 0.02, 18.55), ink, M.Metal)
end

--------------------------------------------------------------------------
-- Public entry point
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
	destroy(interior, { "Signage" })
	signage(interior)
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

		finishShell(office, interior)
		buildLights(interior)
		danielsOffice(office, interior)
		recordsRoom(office, interior)
		meetingRoom(office, interior)
		reception(office, interior)
		openPlan(interior)
		centre(interior)
		signage(interior)
		-- The shell's authored block desks, chairs and monitors are replaced.
		for i = 1, 3 do
			destroy(office, { "Furniture", `MainDesk_{i}` })
			destroy(office, { "Furniture", `MainChair_{i}` })
			destroy(office, { "Furniture", `MainMon_{i}` })
		end
		destroy(office, { "Furniture", "StorageCredenza" })
	end

	-- The flicker loop is runtime state: an Edit-mode bake only positions
	-- the parts; a running game arms the loop.
	if RunService:IsRunning() then
		startFlicker(findFlickerParts(interior))
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
