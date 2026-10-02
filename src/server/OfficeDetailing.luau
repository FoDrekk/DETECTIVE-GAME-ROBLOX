--!strict
--[[
	OfficeDetailing
	The crime scene, and the investigator's arrival: crossed tape across the
	door of Daniel's office, the tape outline on the floor beside his desk with
	its numbered marker, the three numbered evidence cards on the desk, and the
	spawn pad in the lift car.

	Purely atmospheric: none of it is tagged, and none of it is ever
	referenced by id, so nothing here can shadow a real interaction.
	Everything is parented under Workspace.Office.Detailing, built once and
	adopted (not rebuilt) from a baked place.

	The architecture is OfficeShell's and the furnishing OfficeInterior's; this
	module holds only what the case staged on top of them. Positions come from
	OfficePlan and from Daniel's room (DanielOffice.DESK / OUTLINE), so the scene
	stays where the desk is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local DanielOffice = require(script.Parent:WaitForChild("rooms"):WaitForChild("DanielOffice"))

local log = Logger.scoped("OfficeDetailing")

local OfficeDetailing = {}

local DETAIL_FOLDER_NAME = "Detailing"

local TAPE_YELLOW = Color3.fromRGB(232, 197, 71)

--------------------------------------------------------------------------
-- Tape across the door
--------------------------------------------------------------------------

-- A thin ribbon from `pointA` to `pointB`. CFrame.lookAt orients the part's
-- local Z axis toward `pointB`, so putting the ribbon's length on Size.Z
-- (not the more usual Size.X) makes it span exactly between the two points.
-- For a ribbon in a wall plane (constant Z) the part's local X is the wall
-- normal, so the ribbon is thin on X and its lettered faces are Right/Left.
local TAPE_TEXT = "CRIME SCENE  •  DO NOT CROSS  •  CRIME SCENE  •  DO NOT CROSS  •  CRIME SCENE"

local function tapeStrip(name: string, pointA: Vector3, pointB: Vector3, parent: Instance)
	local mid = (pointA + pointB) / 2
	local length = (pointB - pointA).Magnitude
	local strip = Instance.new("Part")
	strip.Name = name
	strip.Size = Vector3.new(0.06, 0.5, length)
	strip.CFrame = CFrame.lookAt(mid, pointB)
	strip.Color = TAPE_YELLOW
	strip.Material = Enum.Material.SmoothPlastic
	strip.Anchored = true
	strip.CanCollide = false
	strip.Parent = parent

	-- Lettering, readable from the floor outside and from inside the office.
	for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 60
		surface.LightInfluence = 1
		surface.Parent = strip
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextWrapped = false
		label.TextColor3 = Color3.fromRGB(20, 18, 14)
		label.Text = TAPE_TEXT
		label.Parent = surface
	end
end

-- Crossed tape across the doorway of Daniel's office -- the one entrance a
-- player must pass through to reach the scene, so it reads before anything
-- else, through the glass, from the length of the open plan.
local function buildCrimeSceneTape(folder: Instance)
	local door = OfficePlan.openingOf("DanielFront", "door")
	local doorZ = OfficePlan.getWall("DanielFront").at
	assert(door, "Daniel's office has no door in the plan")
	local minX, maxX = door.center - door.width / 2 + 0.2, door.center + door.width / 2 - 0.2
	local low, high = 3, 6.4
	tapeStrip("SceneTape_1", Vector3.new(minX, low, doorZ), Vector3.new(maxX, high, doorZ), folder)
	tapeStrip("SceneTape_2", Vector3.new(minX, high, doorZ), Vector3.new(maxX, low, doorZ), folder)
end

--------------------------------------------------------------------------
-- The tape outline and its marker
--------------------------------------------------------------------------

-- A tape outline on the floor of Daniel's office (patrol tape,
-- not chalk: tape is what a Kota Arwana patrol carries), on the open floor
-- beside the desk, its head toward the credenza under the window where it
-- struck. Thin strips tracing a silhouette (one arm flung up, one down, as
-- found), not filled shapes, with a numbered evidence marker beside it. The
-- origin's Y is the strip centre: it clears the room finish (top at 0.03; see
-- OfficeInterior's floor layering) by ~0.001.
local TAPE_OUTLINE_NAME = "TapeOutline"
local FLOOR_MARKER_NAME = "FloorMarker"
local TAPE_SCALE = 0.9
-- Outline points (x, z) around the torso centre, head toward -z.
local TAPE_BODY = {
	{ 0.3, -1.5 }, { 0.9, -1.3 }, { 1.9, -1.9 }, { 2.4, -2.6 }, { 2.1, -2.85 },
	{ 1.6, -2.15 }, { 0.9, -0.8 }, { 0.8, 0.9 }, { 1.2, 2.3 }, { 1.6, 3.4 },
	{ 1.1, 3.5 }, { 0.7, 2.35 }, { 0.1, 1.3 }, { -0.6, 2.4 }, { -0.8, 3.5 },
	{ -1.3, 3.4 }, { -1.1, 2.3 }, { -0.8, 0.9 }, { -0.9, -0.7 }, { -1.6, 0.1 },
	{ -1.9, 0.9 }, { -2.3, 0.7 }, { -2.0, -0.1 }, { -0.9, -1.3 }, { -0.3, -1.5 },
}

local function buildTapeOutline(folder: Instance)
	local outline = Instance.new("Folder")
	outline.Name = TAPE_OUTLINE_NAME
	outline.Parent = folder
	local origin = DanielOffice.OUTLINE

	local function stroke(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		if length < 0.01 then
			return
		end
		local p = Instance.new("Part")
		p.Name = "Stroke"
		p.Size = Vector3.new(0.1, 0.012, length + 0.06)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Color = TAPE_YELLOW
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = outline
	end

	local function point(x: number, z: number): Vector3
		return origin + Vector3.new(x * TAPE_SCALE, 0, z * TAPE_SCALE)
	end
	for i = 1, #TAPE_BODY do
		local here = TAPE_BODY[i]
		local nextPoint = TAPE_BODY[i % #TAPE_BODY + 1]
		if i < #TAPE_BODY then
			stroke(point(here[1], here[2]), point(nextPoint[1], nextPoint[2]))
		end
	end
	-- The head: a ring of strokes, left open where it meets the neck.
	local head = { 0, -2.15 }
	local radius = 0.62
	local segments = 10
	for i = 1, segments - 1 do
		local a0 = math.rad(90 + 360 * (i - 0.5) / segments)
		local a1 = math.rad(90 + 360 * (i + 0.5) / segments)
		stroke(
			point(head[1] + math.cos(a0) * radius, head[2] + math.sin(a0) * radius),
			point(head[1] + math.cos(a1) * radius, head[2] + math.sin(a1) * radius)
		)
	end
end

-- A numbered evidence marker standing on the floor beside the outline: two
-- yellow plates leaning together into a tent, the number on both faces.
local function buildFloorMarker(folder: Instance, number: number)
	local marker = Instance.new("Model")
	marker.Name = FLOOR_MARKER_NAME
	marker.Parent = folder
	-- Beside the torso, in the gap between the raised arm and the leg.
	local base = DanielOffice.OUTLINE + Vector3.new(1.45, 0, 0)
	for side = -1, 1, 2 do
		local plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Size = Vector3.new(0.55, 0.75, 0.02)
		plate.Color = TAPE_YELLOW
		plate.Material = Enum.Material.SmoothPlastic
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanTouch = false
		plate.CanQuery = false
		plate.CastShadow = false
		-- side -1 faces -Z leaning toward +Z; side 1 faces +Z leaning toward -Z.
		local lean = CFrame.Angles(math.rad(15), 0, 0)
		local turn = if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		plate.CFrame = CFrame.new(base + Vector3.new(0, 0.37, side * 0.09)) * turn * lean
		plate.Parent = marker

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0.6
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 80
		gui.Parent = plate
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = tostring(number)
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.fromRGB(20, 20, 20)
		text.TextScaled = true
		text.Parent = gui
	end
end

-- Replace the tape outline and floor marker in an already-baked place (Edit
-- mode), leaving everything else in the detailing folder alone. Returns
-- whether there was a folder to patch.
function OfficeDetailing.patchTapeOutline(): boolean
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local folder = office and office:FindFirstChild(DETAIL_FOLDER_NAME)
	if not folder then
		return false
	end
	for _, name in ipairs({ TAPE_OUTLINE_NAME, FLOOR_MARKER_NAME }) do
		local old = folder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	buildTapeOutline(folder)
	buildFloorMarker(folder, 4)
	return true
end

-- Small numbered evidence cards on the desk, in front of the things they mark:
-- tent cards standing on the desk, facing the doorway. The number
-- carries no meaning of its own, and the item behind each is already the real,
-- independently-tagged Interactable.
local function buildEvidenceMarkers(folder: Instance)
	local d = DanielOffice.DESK
	local top = 2.9
	local markers = {
		{ n = 1, pos = Vector3.new(d.X + 3.5, top, d.Z + 1.65) }, -- before the phone
		{ n = 2, pos = Vector3.new(d.X - 1.0, top, d.Z + 1.35) }, -- before the laptop
		{ n = 3, pos = Vector3.new(d.X + 1.4, top, d.Z + 1.55) }, -- before the agenda
	}
	for _, marker in ipairs(markers) do
		local card = Instance.new("Part")
		card.Name = `EvidenceMarker_{marker.n}`
		card.Size = Vector3.new(0.5, 0.55, 0.02)
		card.CFrame = CFrame.lookAt(marker.pos, marker.pos + Vector3.new(0, 0, 1)) * CFrame.Angles(math.rad(-25), 0, 0)
		card.Color = TAPE_YELLOW
		card.Material = Enum.Material.SmoothPlastic
		card.Anchored = true
		card.CanCollide = false
		card.Parent = folder

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.PixelsPerStud = 80
		gui.Parent = card

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = tostring(marker.n)
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(20, 20, 20)
		label.TextScaled = true
		label.Parent = gui
	end
end

--------------------------------------------------------------------------
-- The spawn
--------------------------------------------------------------------------

-- The investigator arrives in the lift car, facing out of its doors. The pad
-- itself is hidden; it is not a gameplay object. (Created here if the place
-- has none.)
local function placeInvestigatorSpawn(office: Instance)
	local spawnPad = office:FindFirstChild("InvestigatorSpawn")
	if not spawnPad then
		local created = Instance.new("SpawnLocation")
		created.Name = "InvestigatorSpawn"
		created.Size = Vector3.new(4, 0.4, 4)
		created.Anchored = true
		created.Parent = office
		spawnPad = created
	end
	if spawnPad:IsA("SpawnLocation") then
		spawnPad.CFrame = CFrame.lookAt(OfficePlan.Spawn, OfficePlan.Spawn + Vector3.new(-1, 0, 0))
		spawnPad.Transparency = 1
		spawnPad.CanCollide = true
		-- No spawn-protection bubble: there is nothing to be protected from.
		spawnPad.Duration = 0
	end
end

--------------------------------------------------------------------------
-- Public entry point
--------------------------------------------------------------------------

function OfficeDetailing.start()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} not found; skipping environment detailing`)
		return
	end
	if office:FindFirstChild(DETAIL_FOLDER_NAME) then
		-- Baked already: adopt as-is, including any author adjustments. The
		-- spawn pad move is a one-shot edit the bake already made.
		log:info("detailing already present; adopting baked geometry")
		return
	end

	placeInvestigatorSpawn(office)

	local folder = Instance.new("Folder")
	folder.Name = DETAIL_FOLDER_NAME
	folder.Parent = office

	buildCrimeSceneTape(folder)
	buildTapeOutline(folder)
	buildFloorMarker(folder, 4)
	buildEvidenceMarkers(folder)

	log:info("office detailing applied", { parts = #folder:GetChildren() })
end

return OfficeDetailing
