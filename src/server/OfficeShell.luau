--!strict
--[[
	OfficeShell
	The architecture of Level 9, built from OfficePlan: the floor slab, the
	exterior walls with their windows and the entrance, every partition (solid,
	glazed or low), the lintels over the doors, the suspended ceiling, and the
	lift core with its car.

	This builds the office shell from OfficePlan instead of a binary model.
	started from: the office is now generated, so a layout change is a change
	to OfficePlan and this file, never to a binary asset that can't be edited
	from code. Like the rest of the environment it is baked into the place in
	Edit mode (EnvironmentBake) and adopted, not rebuilt, on later boots.

	Furnishing (finishes, lights, furniture, the story's props) is
	OfficeInterior's; the crime scene's staging is OfficeDetailing's. This
	module only makes the rooms.

	Everything is parented under Workspace.Office.Shell. The walls, glass and
	floor are collidable and queryable; trims, frames and the ceiling are not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent:WaitForChild("PropKit"))

local log = Logger.scoped("OfficeShell")

local OfficeShell = {}

local FOLDER_NAME = "Shell"
local P = PropKit.Palette
local M = Enum.Material

local T = OfficePlan.WallThickness
local CEILING = OfficePlan.CeilingY
local WALL_TOP = CEILING + 0.1

local PLASTER_EXTERIOR = P.Plaster
local PLASTER_PARTITION = Color3.fromRGB(198, 194, 186)
local GLASS_TINT = Color3.fromRGB(120, 150, 170)
local WINDOW_TINT = Color3.fromRGB(70, 88, 110)

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

-- The office model, created if the place has none.
function OfficeShell.ensureOffice(): Model
	local existing = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if existing and existing:IsA("Model") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local office = Instance.new("Model")
	office.Name = Config.Environment.OfficeModelName
	office.Parent = workspace
	return office
end

-- A solid, collidable block spanning (a..b) along `axis` at `at` on the other
-- axis, from y0 to y1, `depth` thick across.
local function span(
	parent: Instance,
	name: string,
	axis: "x" | "z",
	at: number,
	a: number,
	b: number,
	y0: number,
	y1: number,
	depth: number,
	color: Color3,
	material: Enum.Material
): Part
	local length, height = b - a, y1 - y0
	local mid = (a + b) / 2
	local size, center
	if axis == "x" then
		size = Vector3.new(length, height, depth)
		center = Vector3.new(mid, (y0 + y1) / 2, at)
	else
		size = Vector3.new(depth, height, length)
		center = Vector3.new(at, (y0 + y1) / 2, mid)
	end
	local p = PropKit.newPart(parent, name, size, CFrame.new(center), color, material)
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	return p
end

-- A trim or frame piece: not collidable.
local function trim(
	parent: Instance,
	name: string,
	axis: "x" | "z",
	at: number,
	a: number,
	b: number,
	y0: number,
	y1: number,
	depth: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = span(parent, name, axis, at, a, b, y0, y1, depth, color, material)
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function glass(
	parent: Instance,
	name: string,
	axis: "x" | "z",
	at: number,
	a: number,
	b: number,
	y0: number,
	y1: number,
	transparency: number,
	tint: Color3
): Part
	local p = span(parent, name, axis, at, a, b, y0, y1, 0.16, tint, M.Glass)
	p.Transparency = transparency
	p.Reflectance = 0.06
	p.CastShadow = false
	return p
end

--------------------------------------------------------------------------
-- Walls
--------------------------------------------------------------------------

-- The solid spans of a wall, each extended half a wall's thickness where it
-- ends against another wall, so corners close cleanly.
local function extendedSpans(w: OfficePlan.Wall): { { number } }
	local spans = OfficePlan.solidSpans(w)
	if #spans > 0 then
		if math.abs(spans[1][1] - w.from) < 1e-6 then
			spans[1][1] -= T / 2
		end
		local last = spans[#spans]
		if math.abs(last[2] - w.to) < 1e-6 then
			last[2] += T / 2
		end
	end
	return spans
end

-- Steel-and-glass front: full-height glass, slim mullions, a kick plate and a
-- head rail, with the door cut out below the door height (the glass
-- continues over it as a transom).
local function glazedWall(parent: Instance, w: OfficePlan.Wall)
	local folder = Instance.new("Folder")
	folder.Name = w.name
	folder.Parent = parent
	local axis, at = w.axis, w.at
	local kick = 1.0
	local rail = 0.3

	local function pane(a: number, b: number, y0: number, y1: number, label: string)
		glass(folder, label, axis, at, a, b, y0, y1, 0.42, GLASS_TINT)
	end

	-- Glass ends at the centre line of the wall it meets, inside that wall's
	-- body, so it needs no extension to close a corner.
	for index, s in ipairs(OfficePlan.solidSpans(w)) do
		local a, b = s[1], s[2]
		-- Kick plate: opaque, so the glass doesn't show feet and floor edges.
		span(folder, `Kick_{index}`, axis, at, a, b, 0, kick, T, PLASTER_PARTITION, M.Plaster)
		pane(a, b, kick, WALL_TOP - rail, `Glass_{index}`)
		-- Mullions every ~5 studs, and at both ends.
		local count = math.max(1, math.ceil((b - a) / 5))
		for i = 0, count do
			local m = a + (b - a) * i / count
			trim(folder, `Mullion_{index}_{i}`, axis, at, m - 0.09, m + 0.09, kick, WALL_TOP - rail, 0.3, P.Charcoal, M.Metal)
		end
		trim(folder, `Head_{index}`, axis, at, a, b, WALL_TOP - rail, WALL_TOP, T, P.Charcoal, M.Metal)
	end

	-- Doors: posts either side, a head rail, glass above as a transom.
	for index, o in ipairs(w.openings) do
		local a, b = o.center - o.width / 2, o.center + o.width / 2
		for side, edge in ipairs({ a, b }) do
			trim(folder, `Jamb_{index}_{side}`, axis, at, edge - 0.1, edge + 0.1, 0, OfficePlan.DoorHeight, 0.32, P.Charcoal, M.Metal)
		end
		trim(folder, `DoorHead_{index}`, axis, at, a, b, OfficePlan.DoorHeight, OfficePlan.DoorHeight + 0.25, 0.32, P.Charcoal, M.Metal)
		pane(a, b, OfficePlan.DoorHeight + 0.25, WALL_TOP - rail, `Transom_{index}`)
		trim(folder, `TransomHead_{index}`, axis, at, a, b, WALL_TOP - rail, WALL_TOP, T, P.Charcoal, M.Metal)
	end
end

-- A low glass screen (a partition that zones without closing): a base, glass
-- and a walnut cap.
local function lowWall(parent: Instance, w: OfficePlan.Wall)
	local folder = Instance.new("Folder")
	folder.Name = w.name
	folder.Parent = parent
	local axis, at = w.axis, w.at
	local height = 5.5
	for index, s in ipairs(OfficePlan.solidSpans(w)) do
		local a, b = s[1], s[2]
		span(folder, `Base_{index}`, axis, at, a, b, 0, 1.1, T * 0.8, P.WalnutDark, M.Wood)
		glass(folder, `Glass_{index}`, axis, at, a, b, 1.1, height - 0.3, 0.4, GLASS_TINT)
		trim(folder, `Cap_{index}`, axis, at, a, b, height - 0.3, height, T * 0.9, P.Walnut, M.Wood)
		local posts = math.max(1, math.ceil((b - a) / 5))
		for i = 0, posts do
			local m = a + (b - a) * i / posts
			trim(folder, `Post_{index}_{i}`, axis, at, m - 0.08, m + 0.08, 1.1, height - 0.3, 0.24, P.Charcoal, M.Metal)
		end
	end
	-- The ends of the opening are finished with a post to the cap.
	for index, o in ipairs(w.openings) do
		for side, edge in ipairs({ o.center - o.width / 2, o.center + o.width / 2 }) do
			span(folder, `EndPost_{index}_{side}`, axis, at, edge - 0.15, edge + 0.15, 0, height, T * 0.9, P.WalnutDark, M.Wood)
		end
	end
end

-- Plaster partition with door lintels.
local function solidWall(parent: Instance, w: OfficePlan.Wall, color: Color3)
	local folder = Instance.new("Folder")
	folder.Name = w.name
	folder.Parent = parent
	local axis, at = w.axis, w.at
	for index, s in ipairs(extendedSpans(w)) do
		span(folder, `Span_{index}`, axis, at, s[1], s[2], 0, WALL_TOP, T, color, M.Plaster)
	end
	for index, o in ipairs(w.openings) do
		local a, b = o.center - o.width / 2, o.center + o.width / 2
		local door = if o.kind == "lift" then 7.9 else OfficePlan.DoorHeight
		span(folder, `Lintel_{index}`, axis, at, a, b, door, WALL_TOP, T, color, M.Plaster)
		-- A slim metal architrave either side of a doorway.
		for side, edge in ipairs({ a, b }) do
			trim(folder, `Architrave_{index}_{side}`, axis, at, edge - 0.08, edge + 0.08, 0, door, T + 0.14, P.Charcoal, M.Metal)
		end
		trim(folder, `Header_{index}`, axis, at, a, b, door - 0.16, door, T + 0.14, P.Charcoal, M.Metal)
	end
	-- Skirting, both faces, in charcoal.
	for index, s in ipairs(extendedSpans(w)) do
		for _, sideSign in ipairs({ -1, 1 }) do
			local off = sideSign * (T / 2 + 0.05)
			trim(folder, `Skirting_{index}_{sideSign}`, axis, at + off, s[1], s[2], 0, 0.4, 0.1, P.Charcoal, M.Metal)
		end
	end
end

-- The exterior wall with its windows (north) or the entrance (south).
local function exteriorWall(parent: Instance, w: OfficePlan.Wall)
	local folder = Instance.new("Folder")
	folder.Name = w.name
	folder.Parent = parent
	local axis, at = w.axis, w.at
	for index, s in ipairs(OfficePlan.solidSpans(w)) do
		local a, b = s[1], s[2]
		-- The corner posts of the north and south walls run into the west and
		-- east walls; the west and east walls stop at their faces.
		span(folder, `Span_{index}`, axis, at, a, b, 0, WALL_TOP, T, PLASTER_EXTERIOR, M.Plaster)
	end
	for index, o in ipairs(w.openings) do
		local a, b = o.center - o.width / 2, o.center + o.width / 2
		if o.kind == "window" then
			local sill, head = OfficePlan.WindowSill, OfficePlan.WindowHead
			span(folder, `Sill_{index}`, axis, at, a, b, 0, sill, T, PLASTER_EXTERIOR, M.Plaster)
			span(folder, `Head_{index}`, axis, at, a, b, head, WALL_TOP, T, PLASTER_EXTERIOR, M.Plaster)
			local panes = math.max(1, math.ceil((b - a) / 11.5))
			local glassPart = glass(folder, `WinGlass_{index}`, axis, at, a + 0.25, b - 0.25, sill + 0.25, head - 0.25, 0.7, WINDOW_TINT)
			glassPart.Name = `WinGlass_{index}`
			-- Plain, not the Glass material: Roblox's glass all but hides the lit
			-- city behind it, which is the whole point of these windows.
			glassPart.Material = M.SmoothPlastic
			glassPart.Transparency = 0.84
			glassPart.Reflectance = 0.1
			-- The city's glow, through the glass into the room.
			local style = Config.Environment.Interior.CityGlow
			PropKit.light(glassPart, "SurfaceLight", style.Brightness, style.Range, style.Color, {
				face = Enum.NormalId.Back,
				angle = 75,
				shadows = false,
			})
			-- Frame: head and sill rails, posts, and a mullion between panes.
			trim(folder, `WinFrame_Top_{index}`, axis, at, a, b, head - 0.5, head, 0.6, P.Charcoal, M.Metal)
			trim(folder, `WinFrame_Bottom_{index}`, axis, at, a, b, sill, sill + 0.5, 0.6, P.Charcoal, M.Metal)
			for i = 0, panes do
				local m = a + 0.25 + (b - a - 0.5) * i / panes
				trim(folder, `WinFrame_Post_{index}_{i}`, axis, at, m - 0.25, m + 0.25, sill, head, 0.6, P.Charcoal, M.Metal)
			end
		elseif o.kind == "entrance" then
			local top = OfficePlan.DoorHeight + 1.4
			span(folder, `EntranceHead_{index}`, axis, at, a, b, top, WALL_TOP, T, PLASTER_EXTERIOR, M.Plaster)
			-- Double glass doors in a slim frame, with a bar handle. Closed: the
			-- suite is badge-only after nine, and the floor is nine storeys up.
			local doors = Instance.new("Folder")
			doors.Name = "EntranceDoors"
			doors.Parent = folder
			for side, edge in ipairs({ a, b }) do
				trim(doors, `EntranceFrame_{side}`, axis, at, edge - 0.15, edge + 0.15, 0, top, 0.6, P.Charcoal, M.Metal)
			end
			trim(doors, "EntranceFrame_Head", axis, at, a, b, top - 0.3, top, 0.6, P.Charcoal, M.Metal)
			trim(doors, "EntranceFrame_Centre", axis, at, o.center - 0.1, o.center + 0.1, 0, top, 0.5, P.Charcoal, M.Metal)
			for side = 1, 2 do
				local from = if side == 1 then a + 0.15 else o.center + 0.1
				local to = if side == 1 then o.center - 0.1 else b - 0.15
				local leaf = glass(doors, `EntranceGlass_{side}`, axis, at, from, to, 0.2, top - 0.3, 0.3, GLASS_TINT)
				leaf.CanCollide = true
				leaf.CanQuery = true
				local handleAt = if side == 1 then o.center - 0.7 else o.center + 0.7
				trim(doors, `EntranceHandle_{side}`, axis, at + 0.45, handleAt - 0.06, handleAt + 0.06, 3, 5.2, 0.12, P.Steel, M.Metal)
			end
		end
	end
	-- Skirting on the inside face (north/south walls only; the west and east
	-- walls have no doors or windows to interrupt it).
	local inward = if at < 0 then 1 else -1
	for index, s in ipairs(OfficePlan.solidSpans(w)) do
		trim(folder, `Skirting_{index}`, axis, at + inward * (T / 2 + 0.05), s[1], s[2], 0, 0.4, 0.1, P.Charcoal, M.Metal)
	end
end

--------------------------------------------------------------------------
-- Floor and ceiling
--------------------------------------------------------------------------

local function floorAndCeiling(parent: Instance)
	local f = OfficePlan.Footprint
	-- The backstop floor: sunk below the finished floors, so nothing rests on
	-- it and nothing fights it in the depth buffer (see OfficeInterior's floor
	-- layering).
	local backstop = PropKit.newPart(
		parent,
		"Floor",
		Vector3.new(f.x1 - f.x0 + T + 1, 1, f.z1 - f.z0 + T + 1),
		CFrame.new(0, -1.1, 0),
		Color3.fromRGB(70, 70, 72),
		M.Concrete
	)
	backstop.CanCollide = true
	backstop.CanQuery = true

	-- A suspended ceiling with a T-bar grid; Daniel's office and the meeting
	-- room have a dropped one lower down (OfficeInterior).
	local ceiling = Instance.new("Folder")
	ceiling.Name = "Ceiling"
	ceiling.Parent = parent
	local x0, x1, z0, z1 = f.x0 + T / 2, f.x1 - T / 2, f.z0 + T / 2, f.z1 - T / 2
	local tiles = PropKit.newPart(
		ceiling,
		"Tiles",
		Vector3.new(x1 - x0, 0.1, z1 - z0),
		CFrame.new((x0 + x1) / 2, CEILING + 0.05, (z0 + z1) / 2),
		Color3.fromRGB(206, 204, 198),
		M.Plaster
	)
	tiles.CastShadow = false
	local barColor = Color3.fromRGB(176, 176, 172)
	for x = math.ceil(x0 / 4) * 4, x1, 4 do
		local bar = PropKit.newPart(ceiling, "TBar", Vector3.new(0.1, 0.04, z1 - z0), CFrame.new(x, CEILING - 0.02, (z0 + z1) / 2), barColor, M.Metal)
		bar.CastShadow = false
	end
	for z = math.ceil(z0 / 4) * 4, z1, 4 do
		local bar = PropKit.newPart(ceiling, "TBar", Vector3.new(x1 - x0, 0.04, 0.1), CFrame.new((x0 + x1) / 2, CEILING - 0.02, z), barColor, M.Metal)
		bar.CastShadow = false
	end
end

--------------------------------------------------------------------------
-- The lift car
--------------------------------------------------------------------------

--[[
	A real car behind the doorway in the reception's east wall: brushed steel,
	a mirrored back wall, a handrail, a light, the floor display, a camera dome
	with tape across it, and the inspection certificate. Its doors stay open in
	the office; the intro closes and opens a pair of its own over the doorway
	(client-side, LiftOverlay), so nothing here moves.
]]
local STEEL_PANEL = Color3.fromRGB(150, 152, 156)
local STEEL_DARK = Color3.fromRGB(96, 99, 104)

local function liftCar(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "LiftCar"
	folder.Parent = parent
	local car = OfficePlan.Lift.car
	local ceilingY = OfficePlan.Lift.ceilingY
	local cx, cz = (car.x0 + car.x1) / 2, (car.z0 + car.z1) / 2
	local width, depth = car.x1 - car.x0, car.z1 - car.z0

	-- Floor: dark stone, a hair above the office carpet.
	local floor = PropKit.newPart(folder, "Floor", Vector3.new(width, 0.06, depth), CFrame.new(cx, 0.02, cz), Color3.fromRGB(58, 58, 62), M.Granite)
	floor.CanCollide = true
	floor.CanQuery = true
	floor.CastShadow = false

	-- Ceiling with a recessed light panel.
	local lid = PropKit.newPart(folder, "Ceiling", Vector3.new(width, 0.2, depth), CFrame.new(cx, ceilingY + 0.1, cz), STEEL_DARK, M.Metal)
	lid.CastShadow = false
	local panel = PropKit.newPart(folder, "LightPanel", Vector3.new(width - 2.6, 0.06, depth - 2.6), CFrame.new(cx, ceilingY - 0.03, cz), Color3.fromRGB(226, 222, 212), M.Neon)
	panel.CastShadow = false
	PropKit.light(panel, "PointLight", 1.3, 14, Color3.fromRGB(255, 244, 226), { shadows = false })

	-- Steel cladding on the walls' inner faces.
	local function cladding(name: string, size: Vector3, position: Vector3, color: Color3?)
		local p = PropKit.newPart(folder, name, size, CFrame.new(position), color or STEEL_PANEL, M.Metal)
		p.CastShadow = false
		p.Reflectance = 0.08
		return p
	end
	local wallH = ceilingY
	-- North and south walls (along X), the front wall (west), the back (east).
	cladding("Clad_N", Vector3.new(width, wallH, 0.14), Vector3.new(cx, wallH / 2, car.z0 + 0.07))
	cladding("Clad_S", Vector3.new(width, wallH, 0.14), Vector3.new(cx, wallH / 2, car.z1 - 0.07))
	-- The front wall either side of the doorway.
	local doorHalf = OfficePlan.Lift.doorWidth / 2
	cladding("Clad_W_N", Vector3.new(0.14, wallH, (OfficePlan.Lift.doorZ - doorHalf) - car.z0), Vector3.new(car.x0 + 0.07, wallH / 2, (car.z0 + OfficePlan.Lift.doorZ - doorHalf) / 2))
	cladding("Clad_W_S", Vector3.new(0.14, wallH, car.z1 - (OfficePlan.Lift.doorZ + doorHalf)), Vector3.new(car.x0 + 0.07, wallH / 2, (car.z1 + OfficePlan.Lift.doorZ + doorHalf) / 2))
	cladding("Clad_W_Head", Vector3.new(0.14, wallH - 7.9, OfficePlan.Lift.doorWidth), Vector3.new(car.x0 + 0.07, (wallH + 7.9) / 2, OfficePlan.Lift.doorZ))

	-- The back wall is the mirror: dark glass set proud of a steel surround,
	-- slightly reflective. (The intro adds the reflection behind it.)
	cladding("MirrorSurround", Vector3.new(0.16, wallH, car.z1 - car.z0), Vector3.new(car.x1 - 0.02, wallH / 2, cz), STEEL_DARK)
	local mirrorZ0, mirrorZ1 = car.z0 + 0.8, car.z1 - 0.8
	local mirror = PropKit.newPart(
		folder,
		"Mirror",
		Vector3.new(0.12, wallH - 2.6, mirrorZ1 - mirrorZ0),
		CFrame.new(car.x1 - 0.14, 0.9 + (wallH - 2.6) / 2, (mirrorZ0 + mirrorZ1) / 2),
		Color3.fromRGB(88, 96, 104),
		M.Glass
	)
	mirror.Transparency = 0.25
	mirror.Reflectance = 0.32
	mirror.CastShadow = false

	-- Handrails on the side walls.
	for _, side in ipairs({ { car.z0 + 0.3, "N" }, { car.z1 - 0.3, "S" } }) do
		local rail = PropKit.newPart(folder, `Handrail_{side[2]}`, Vector3.new(width - 1.2, 0.18, 0.18), CFrame.new(cx, 3.2, side[1]), P.Steel, M.Metal)
		rail.CastShadow = false
	end

	-- The floor display above the doors, facing into the car: "9".
	local display = PropKit.newPart(folder, "FloorDisplay", Vector3.new(0.05, 0.9, 1.7), CFrame.new(car.x0 + 0.18, 8.7, OfficePlan.Lift.doorZ), P.Screen, M.SmoothPlastic)
	display.CastShadow = false
	PropKit.label(display, Enum.NormalId.Right, "9", {
		color = Color3.fromRGB(255, 170, 90),
		font = Enum.Font.Code,
		lightInfluence = 0,
		pixelsPerStud = 100,
	})

	-- A camera dome in the north-west ceiling corner, and tape across it: the
	-- first thread of what the case never asks the investigator to follow.
	local dome = PropKit.newPart(folder, "CameraDome", Vector3.new(0.7, 0.7, 0.7), CFrame.new(car.x0 + 0.8, ceilingY - 0.3, car.z0 + 0.8), P.LeatherBlack, M.SmoothPlastic)
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 0.15
	dome.CastShadow = false
	local tape = PropKit.newPart(folder, "RosakTape", Vector3.new(0.92, 0.2, 0.06), CFrame.new(car.x0 + 0.8, ceilingY - 0.3, car.z0 + 0.8) * CFrame.Angles(0, math.rad(-30), math.rad(35)), Color3.fromRGB(232, 197, 71), M.SmoothPlastic)
	tape.CastShadow = false
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		PropKit.label(tape, face, "ROSAK", {
			color = Color3.fromRGB(28, 24, 12),
			font = Enum.Font.GothamBlack,
			lightInfluence = 1,
			pixelsPerStud = 300,
		})
	end

	-- Flush passenger controls on the south wall keep the cabin functional
	-- while leaving its mirrored, cinematic character unobstructed.
	local controlX, controlY, controlZ = car.x0 + 1.25, 4.95, car.z1 - 0.2
	local controlPanel = PropKit.newPart(folder, "ControlPanel", Vector3.new(1.65, 2.95, 0.08), CFrame.new(controlX, controlY, controlZ), Color3.fromRGB(42, 46, 52), M.Metal)
	controlPanel.CastShadow = false
	controlPanel.Reflectance = 0.12
	-- Read from inside the car, facing this wall: 1 2 3 along the bottom row, 9
	-- at top right. Facing +Z, the car's +X is on the viewer's left.
	for floorNumber = 1, 9 do
		local column = (floorNumber - 1) % 3
		local row = 2 - math.floor((floorNumber - 1) / 3)
		local button = PropKit.newPart(
			folder,
			`FloorButton_{floorNumber}`,
			Vector3.new(0.31, 0.31, 0.07),
			CFrame.new(controlX + 0.48 - column * 0.48, controlY + 0.72 - row * 0.48, controlZ - 0.08),
			if floorNumber == 9 then Color3.fromRGB(226, 178, 108) else Color3.fromRGB(160, 168, 174),
			M.Metal
		)
		button.CastShadow = false
		PropKit.label(button, Enum.NormalId.Front, tostring(floorNumber), {
			color = if floorNumber == 9 then Color3.fromRGB(34, 28, 20) else Color3.fromRGB(242, 242, 236),
			font = Enum.Font.Code,
			lightInfluence = 0,
			pixelsPerStud = 100,
		})
	end
	local alarm = PropKit.newPart(folder, "EmergencyCallButton", Vector3.new(0.38, 0.38, 0.08), CFrame.new(controlX - 0.48, controlY - 0.82, controlZ - 0.08), Color3.fromRGB(156, 65, 54), M.Metal)
	alarm.CastShadow = false
	PropKit.label(alarm, Enum.NormalId.Front, "!", { color = Color3.fromRGB(255, 238, 224), font = Enum.Font.GothamBold, lightInfluence = 0, pixelsPerStud = 100 })
	local grille = PropKit.newPart(folder, "IntercomGrille", Vector3.new(0.62, 0.3, 0.05), CFrame.new(controlX + 0.37, controlY - 0.82, controlZ - 0.07), Color3.fromRGB(25, 28, 32), M.Metal)
	grille.CastShadow = false
	for i = 0, 4 do
		local slot = PropKit.newPart(folder, `IntercomSlot_{i}`, Vector3.new(0.46, 0.025, 0.012), CFrame.new(controlX + 0.37, controlY - 0.73 - i * 0.045, controlZ - 0.105), Color3.fromRGB(118, 124, 128), M.Metal)
		slot.CastShadow = false
	end
	-- The inspection certificate, framed, beside the controls (the intro's lift
	-- shot lets the player look around at it).
	local cert = PropKit.newPart(folder, "Certificate", Vector3.new(1.5, 1.1, 0.06), CFrame.new(cx + 0.45, 5.6, car.z1 - 0.19), Color3.fromRGB(226, 222, 210), M.SmoothPlastic)
	cert.CastShadow = false
	PropKit.label(cert, Enum.NormalId.Front, "PERAKUAN KELAYAKAN\nTingkat 1 - 9\nLuput: 03/2027", {
		color = Color3.fromRGB(40, 40, 46),
		font = Enum.Font.GothamMedium,
		pixelsPerStud = 120,
		padding = 6,
	})
	PropKit.newPart(folder, "CertificateFrame", Vector3.new(1.7, 1.3, 0.05), CFrame.new(cx + 0.45, 5.6, car.z1 - 0.16), P.LeatherBlack, M.Wood).CastShadow = false

	-- The door surround on the reception side.
	local surroundColor = STEEL_DARK
	local z0, z1 = OfficePlan.Lift.doorZ - doorHalf, OfficePlan.Lift.doorZ + doorHalf
	local faceX = OfficePlan.Lift.doorX - T / 2 - 0.07
	trim(folder, "Surround_N", "z", faceX, z0 - 0.5, z0, 0, 8.2, 0.14, surroundColor, M.Metal)
	trim(folder, "Surround_S", "z", faceX, z1, z1 + 0.5, 0, 8.2, 0.14, surroundColor, M.Metal)
	trim(folder, "Surround_Head", "z", faceX, z0 - 0.5, z1 + 0.5, 7.9, 8.4, 0.14, surroundColor, M.Metal)
end

--------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------

function OfficeShell.start()
	local office = OfficeShell.ensureOffice()
	local existing = office:FindFirstChild(FOLDER_NAME)
	if existing and existing:GetAttribute("Plan") == Config.Environment.BuilderVersion then
		log:info("shell already present; adopting baked geometry")
		return
	end
	if existing then
		-- A shell of an older plan (or the legacy authored one): replaced.
		existing:Destroy()
	end

	local shell = Instance.new("Folder")
	shell.Name = FOLDER_NAME
	shell:SetAttribute("Plan", Config.Environment.BuilderVersion)
	shell.Parent = office

	floorAndCeiling(shell)
	for _, w in ipairs(OfficePlan.Walls) do
		if w.kind == "exterior" then
			exteriorWall(shell, w)
		elseif w.kind == "glass" then
			glazedWall(shell, w)
		elseif w.kind == "low" then
			lowWall(shell, w)
		else
			solidWall(shell, w, PLASTER_PARTITION)
		end
	end
	liftCar(shell)

	local parts = 0
	for _, d in ipairs(shell:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	log:info("shell built", { walls = #OfficePlan.Walls, parts = parts })
end

return OfficeShell
