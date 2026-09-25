--!strict
--[[
	OfficeDetailing (Phase 2L-A)
	Additive, runtime-generated environment detailing for the Studio-authored
	Office (assets/Office.rbxm) -- implements the "Office Environment & Map
	Redesign" proposal's Must/Should-have items without editing the binary
	asset at all.

	Why runtime, not the Studio asset directly: there is no reliable,
	scripted way from this development environment to sync a Studio-side
	edit of Workspace.Office back into the tracked assets/Office.rbxm file
	(the same constraint Phase 2I's EV-004 prop already worked around, and
	the proposal's own Migration Strategy section flagged explicitly).
	Every addition below follows that exact precedent instead: a NEW part
	parented alongside the existing asset, or a property tweak (position,
	brightness, range, color) applied to an existing NAMED instance at
	runtime. The redesign's own KEEP/MODIFY/RELOCATE/REBUILD/REMOVE audit
	found nothing that requires removing or restructuring the existing
	asset, so nothing here does either.

	Purely environmental: no case-specific data, no suspect/evidence ids.
	Same charter as OfficeRoom (which owns the office's other runtime
	environment concerns); split into its own module for size, not scope.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local log = Logger.scoped("OfficeDetailing")

local OfficeDetailing = {}

local DETAIL_FOLDER_NAME = "Detailing"

--------------------------------------------------------------------------
-- Small construction helpers (mirrors SuspectSpawner's plain-Part style)
--------------------------------------------------------------------------

local function part(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = canCollide
	p.Transparency = transparency or 0
	return p
end

local function pointLight(parent: Instance, brightness: number, range: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Parent = parent
end

-- Palette (kept close to the existing Office/UI palette, not invented fresh).
local PLASTER = Color3.fromRGB(180, 176, 168)
local PLASTER_DARK = Color3.fromRGB(160, 156, 148)
local TRIM = Color3.fromRGB(55, 54, 51)
local GLASS_TINT = Color3.fromRGB(120, 150, 170)
local WOOD = Color3.fromRGB(120, 88, 58)
local METAL = Color3.fromRGB(70, 72, 78)
local WARM_LIGHT = Color3.fromRGB(255, 214, 170)
local NEUTRAL_LIGHT = Color3.fromRGB(255, 244, 224)
local COOL_LIGHT = Color3.fromRGB(205, 222, 255)

--------------------------------------------------------------------------
-- 1. Lighting retuning -- property changes on EXISTING named fixtures only
--------------------------------------------------------------------------

--[[
	The authored Office ships 7 identical ceiling fixtures (brightness 1.1,
	range 26, white) plus one accent light near Daniel's desk. The redesign
	calls for a lighting hierarchy instead: warm and bright in Daniel's
	Office, neutral in the Meeting Room and open workspace, cool and dim in
	Storage, brightest at Reception. Every fixture below is looked up by its
	authored position (the asset assigns no unique names to the 7 identical
	"Fixture" parts), so a fixture missing from the asset is skipped, not
	errored.
]]
local FIXTURE_TUNING: { { pos: Vector3, brightness: number, range: number, color: Color3 } } = {
	-- Storage (dim, cool)
	{ pos = Vector3.new(-22, 15.6, -14), brightness = 0.7, range = 18, color = COOL_LIGHT },
	-- Meeting Room (neutral) -- also relocated lower in step 6 (dropped ceiling)
	{ pos = Vector3.new(20, 15.6, -14), brightness = 1.15, range = 22, color = NEUTRAL_LIGHT },
	-- Open workspace (neutral)
	{ pos = Vector3.new(-22, 15.6, 6), brightness = 1.0, range = 22, color = NEUTRAL_LIGHT },
	{ pos = Vector3.new(-4, 15.6, 4), brightness = 1.0, range = 22, color = NEUTRAL_LIGHT },
	{ pos = Vector3.new(-4, 15.6, 18), brightness = 1.0, range = 22, color = NEUTRAL_LIGHT },
	{ pos = Vector3.new(20, 15.6, 12), brightness = 1.0, range = 22, color = NEUTRAL_LIGHT },
	-- Reception (brightest, warm -- first impression at the entrance)
	{ pos = Vector3.new(24, 15.6, 20), brightness = 1.45, range = 22, color = WARM_LIGHT },
}

local function findFixture(pos: Vector3): BasePart?
	local lightingFolder = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not lightingFolder then
		return nil
	end
	local folder = lightingFolder:FindFirstChild("Lighting")
	if not folder then
		return nil
	end
	for _, inst in ipairs(folder:GetChildren()) do
		if inst:IsA("BasePart") and (inst.Position - pos).Magnitude < 0.5 then
			return inst
		end
	end
	return nil
end

local function retuneFixtures()
	for _, tuning in ipairs(FIXTURE_TUNING) do
		local fixture = findFixture(tuning.pos)
		if fixture then
			local light = fixture:FindFirstChildWhichIsA("PointLight")
			if light then
				light.Brightness = tuning.brightness
				light.Range = tuning.range
				light.Color = tuning.color
			end
		end
	end

	-- Strengthen the existing Daniel's-desk accent glow slightly, in line
	-- with making his office the warmest room on the floor.
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local lightingFolder = office and office:FindFirstChild("Lighting")
	local danielGlow = lightingFolder and lightingFolder:FindFirstChild("DanielGlow")
	if danielGlow and danielGlow:IsA("BasePart") then
		local light = danielGlow:FindFirstChildWhichIsA("PointLight")
		if light then
			light.Brightness = 1.6
			light.Color = WARM_LIGHT
		end
	end
end

--------------------------------------------------------------------------
-- 2. New geometry -- all additive, parented under a new Detailing folder
--------------------------------------------------------------------------

local function buildReceptionPartition(folder: Instance)
	-- Half-height glass partition (~5.5 studs, well under the 16-stud
	-- ceiling) marking Reception as its own zone without blocking sightlines.
	-- Two segments either side of a through-traffic gap aligned with the
	-- entrance axis.
	local glassA = part("Reception_Partition_A", Vector3.new(4, 5.5, 0.3), Vector3.new(12, 2.75, 7), GLASS_TINT, Enum.Material.Glass, true, 0.35)
	glassA.Parent = folder
	local glassB = part("Reception_Partition_B", Vector3.new(10, 5.5, 0.3), Vector3.new(25, 2.75, 7), GLASS_TINT, Enum.Material.Glass, true, 0.35)
	glassB.Parent = folder
	local capA = part("Reception_Partition_Cap_A", Vector3.new(4, 0.3, 0.6), Vector3.new(12, 5.65, 7), TRIM, Enum.Material.SmoothPlastic, true)
	capA.Parent = folder
	local capB = part("Reception_Partition_Cap_B", Vector3.new(10, 0.3, 0.6), Vector3.new(25, 5.65, 7), TRIM, Enum.Material.SmoothPlastic, true)
	capB.Parent = folder
end

local function buildCorridorSpine(folder: Instance)
	-- A distinct flooring strip (thin part laid over the existing floor)
	-- plus two pendant fixtures, visually defining a ~12-stud circulation
	-- spine out of what was previously an undefined 24-stud gap.
	local strip = part("Corridor_Floor", Vector3.new(12, 0.15, 44), Vector3.new(-2, 0.08, -2), PLASTER_DARK, Enum.Material.SmoothPlastic, false)
	strip.Parent = folder

	for _, z in ipairs({ -14, 4 }) do
		local pendantCord = part(`Corridor_Pendant_Cord_{z}`, Vector3.new(0.15, 4, 0.15), Vector3.new(-2, 14, z), TRIM, Enum.Material.SmoothPlastic, false)
		pendantCord.Parent = folder
		local pendant = part(`Corridor_Pendant_{z}`, Vector3.new(2.4, 0.6, 2.4), Vector3.new(-2, 11.8, z), METAL, Enum.Material.Metal, false)
		pendant.Parent = folder
		pointLight(pendant, 0.9, 16, NEUTRAL_LIGHT)
	end
end

local function buildWallArticulation(folder: Instance)
	-- Pilasters + sconces along the two previously blank 48-stud long walls,
	-- so the exterior reads as constructed rather than an extruded box.
	for _, x in ipairs({ -30, 30 }) do
		local side = if x < 0 then -1 else 1
		-- Offsets place each part flush against the wall's interior face
		-- and projecting into the room: wall half-thickness (0.5) + the
		-- part's own half-depth in the direction perpendicular to the wall.
		for _, z in ipairs({ -20, -10, 0, 10, 20 }) do
			local pilaster = part(`Pilaster_{x}_{z}`, Vector3.new(0.4, 16, 1.6), Vector3.new(x - side * 0.7, 8, z), PLASTER_DARK, Enum.Material.Plaster, false)
			pilaster.Parent = folder
		end
		for _, z in ipairs({ -15, 5, 15 }) do
			local sconce = part(`Sconce_{x}_{z}`, Vector3.new(0.3, 1.2, 0.6), Vector3.new(x - side * 0.65, 9.5, z), METAL, Enum.Material.Metal, false)
			sconce.Parent = folder
			pointLight(sconce, 0.5, 10, WARM_LIGHT)
		end
	end
	-- Two generic (non-narrative) framed signage panels, purely decorative.
	local signA = part("Signage_East", Vector3.new(0.15, 3, 4), Vector3.new(29.5, 9, -2), Color3.fromRGB(30, 31, 35), Enum.Material.SmoothPlastic, false)
	signA.Parent = folder
	local signB = part("Signage_West", Vector3.new(0.15, 3, 4), Vector3.new(-29.5, 9, 14), Color3.fromRGB(30, 31, 35), Enum.Material.SmoothPlastic, false)
	signB.Parent = folder
end

local function buildMeetingRoomGlazing(folder: Instance)
	-- Interior glazing on the Meeting Room's corridor-facing wall, echoing
	-- the glass door Daniel's Office already has. A new glass part inserted
	-- at the wall's own position would sit inside (and be hidden behind)
	-- the existing solid wall part, defeating the point of glazing -- so
	-- this makes the existing "Part_Meeting_West_N" segment itself
	-- semi-transparent instead (a property tweak on a named existing
	-- instance, the same safe category as the lighting retuning above),
	-- and adds a frame outline flush against its corridor-facing surface,
	-- which sits in genuinely open space and needs no embedding.
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local shell = office and office:FindFirstChild("Shell")
	local wall = shell and shell:FindFirstChild("Part_Meeting_West_N")
	if wall and wall:IsA("BasePart") then
		wall.Transparency = 0.6
		wall.Material = Enum.Material.Glass
		wall.Color = GLASS_TINT
	end

	local frame = part("Meeting_InteriorGlazing_Frame", Vector3.new(0.5, 9, 7.4), Vector3.new(9.4, 4.25, -18.5), TRIM, Enum.Material.SmoothPlastic, false)
	frame.Parent = folder
end

local function buildPantry(folder: Instance)
	-- New small break area, carved from the open floor near Storage's south
	-- face. Purely environmental: no evidence, no suspect, no narrative claim.
	-- East wall stays solid; the south wall is split with a doorway gap
	-- (matching every other door in this building), rather than leaving the
	-- only access an accidental sliver against the exterior wall.
	local wallEast = part("Pantry_Wall_East", Vector3.new(0.3, 5.5, 9), Vector3.new(-18, 2.75, 2.5), PLASTER, Enum.Material.Plaster, true)
	wallEast.Parent = folder
	local wallSouthA = part("Pantry_Wall_South_A", Vector3.new(4, 5.5, 0.3), Vector3.new(-26, 2.75, 7), PLASTER, Enum.Material.Plaster, true)
	wallSouthA.Parent = folder
	local wallSouthB = part("Pantry_Wall_South_B", Vector3.new(3, 5.5, 0.3), Vector3.new(-19.5, 2.75, 7), PLASTER, Enum.Material.Plaster, true)
	wallSouthB.Parent = folder

	local counter = part("Pantry_Counter", Vector3.new(6, 2.2, 1.6), Vector3.new(-25, 1.1, 3), WOOD, Enum.Material.Wood, true)
	counter.Parent = folder
	local fridge = part("Pantry_Fridge", Vector3.new(2, 4.5, 2), Vector3.new(-20.5, 2.25, 2), Color3.fromRGB(214, 214, 214), Enum.Material.Metal, true)
	fridge.Parent = folder
	local coffeeMachine = part("Pantry_CoffeeMachine", Vector3.new(0.8, 1, 0.8), Vector3.new(-25, 2.3, 2.6), Color3.fromRGB(40, 40, 42), Enum.Material.SmoothPlastic, false)
	coffeeMachine.Parent = folder
	for _, x in ipairs({ -27, -25.5 }) do
		local stool = part(`Pantry_Stool_{x}`, Vector3.new(1.2, 1.6, 1.2), Vector3.new(x, 0.8, 5.5), TRIM, Enum.Material.Metal, true)
		stool.Parent = folder
	end

	local fixture = part("Pantry_Fixture", Vector3.new(3, 0.3, 3), Vector3.new(-23, 15.6, 3), METAL, Enum.Material.SmoothPlastic, false)
	fixture.Parent = folder
	pointLight(fixture, 1.2, 12, WARM_LIGHT)
end

local function buildDroppedCeilings(folder: Instance)
	-- Visually caps Daniel's Office and the Meeting Room lower than the
	-- 16-stud open plenum, for a more intimate private-room scale. The
	-- original ceiling stays where it is above these -- purely additive.
	local danielCeiling = part("DanielOffice_DroppedCeiling", Vector3.new(15, 0.3, 11), Vector3.new(-22, 11, -8), PLASTER, Enum.Material.Plaster, false)
	danielCeiling.Parent = folder
	local meetingCeiling = part("MeetingRoom_DroppedCeiling", Vector3.new(19, 0.3, 17), Vector3.new(20, 11, -15), PLASTER, Enum.Material.Plaster, false)
	meetingCeiling.Parent = folder

	-- Daniel's Office had no ceiling fixture at all (an audit finding, not a
	-- deliberate choice) -- add one beneath the new dropped ceiling.
	local danielFixture = part("DanielOffice_Fixture", Vector3.new(3, 0.3, 3), Vector3.new(-22, 10.7, -8), METAL, Enum.Material.SmoothPlastic, false)
	danielFixture.Parent = folder
	pointLight(danielFixture, 1.6, 20, WARM_LIGHT)

	-- Relocate the existing Meeting Room fixture down to sit below its new
	-- dropped ceiling too (a position tweak on an existing instance, not a
	-- new one -- its retuned brightness/range from step 1 carries over).
	local meetingFixture = findFixture(Vector3.new(20, 15.6, -14))
	if meetingFixture then
		meetingFixture.Position = Vector3.new(20, 10.7, -14)
	end
end

local function buildDeskDensification(folder: Instance)
	-- Two more desk clusters, matching the existing MainDesk style, so the
	-- open workspace reads as a floor that housed a whole company rather
	-- than three isolated desks in a large room.
	local positions = { Vector3.new(-12, 0, 18), Vector3.new(6, 0, 20) }
	for i, pos in ipairs(positions) do
		local desk = part(`ExtraDesk_{i}`, Vector3.new(5, 2.4, 2.4), pos + Vector3.new(0, 2.5, 0), WOOD, Enum.Material.Wood, true)
		desk.Parent = folder
		local monitor = part(`ExtraDesk_{i}_Monitor`, Vector3.new(1.6, 1.2, 0.15), pos + Vector3.new(0, 4.1, -0.9), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, false)
		monitor.Parent = folder
		local chair = part(`ExtraDesk_{i}_Chair`, Vector3.new(1.6, 2.6, 1.6), pos + Vector3.new(0, 1.4, 2), TRIM, Enum.Material.Fabric, true)
		chair.Parent = folder
	end
end

--------------------------------------------------------------------------
-- 8. Crime scene dressing (M3) -- purely atmospheric, no case-specific data
--------------------------------------------------------------------------

local TAPE_YELLOW = Color3.fromRGB(232, 197, 71)

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

	-- M6: lettering, readable from the corridor and from inside the office.
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

-- Crossed tape across Daniel's office doorway -- the one entrance a player
-- must pass through to reach the scene, so it reads before anything else.
local function buildCrimeSceneTape(folder: Instance)
	local doorGapMinX, doorGapMaxX = -22, -18
	local doorZ = -2.75
	local low, high = 3, 6.4
	tapeStrip("SceneTape_1", Vector3.new(doorGapMinX, low, doorZ), Vector3.new(doorGapMaxX, high, doorZ), folder)
	tapeStrip("SceneTape_2", Vector3.new(doorGapMinX, high, doorZ), Vector3.new(doorGapMaxX, low, doorZ), folder)
end

-- A flat, abstracted chalk outline on the floor of Daniel's office, in the
-- open floor east of the desk -- clear of the desk, of the walkway between
-- the office and storage doors (x -22..-18), and in view from the doorway.
-- All parts share the same thin Y extent so they sit flush on the floor
-- without z-fighting each other.
local function buildChalkOutline(folder: Instance)
	local y = 0.06
	local thickness = 0.05
	local origin = Vector3.new(-16.4, y, -8.8) -- torso center
	local outline = Instance.new("Folder")
	outline.Name = "ChalkOutline"
	outline.Parent = folder

	local function stroke(name: string, size: Vector3, offset: Vector3, yaw: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(origin + offset) * CFrame.Angles(0, math.rad(yaw), 0)
		p.Color = Color3.fromRGB(235, 235, 230)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.Parent = outline
	end

	stroke("Head", Vector3.new(1.3, thickness, 1.3), Vector3.new(0, 0, -2), 0)
	stroke("Torso", Vector3.new(1.6, thickness, 3), Vector3.new(0, 0, 0), 0)
	stroke("ArmLeft", Vector3.new(0.5, thickness, 2.2), Vector3.new(-1.3, 0, -0.6), 35)
	stroke("ArmRight", Vector3.new(0.5, thickness, 2.4), Vector3.new(1.4, 0, -0.3), -50)
	stroke("LegLeft", Vector3.new(0.55, thickness, 2.6), Vector3.new(-0.7, 0, 2.4), -20)
	stroke("LegRight", Vector3.new(0.55, thickness, 2.6), Vector3.new(0.7, 0, 2.4), 20)
end

-- Small numbered evidence markers beside the desk items (M3). Purely
-- atmospheric staging -- the number carries no meaning of its own, and the
-- item beneath each marker is already the real, independently-tagged
-- Interactable; these are never tagged and never referenced by id, so they
-- can never shadow or duplicate a real interaction.
local function buildEvidenceMarkers(folder: Instance)
	local markers = {
		{ n = 1, pos = Vector3.new(-20.5, 2.85, -10.2) }, -- beside the Phone
		{ n = 2, pos = Vector3.new(-25, 2.85, -9.8) }, -- beside the Laptop
		{ n = 3, pos = Vector3.new(-22.6, 2.85, -9.6) }, -- beside the Document
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
-- Public entry point
--------------------------------------------------------------------------

-- The authored spawn sits in the entrance doorway, which puts the default
-- camera outside the front facade looking in through the glass doors. Moving
-- it into the lobby (still facing into the office) makes the opening shot an
-- interior one. The pad itself is hidden; it is not a gameplay object.
local SPAWN_POSITION = Vector3.new(18, 0.2, 10)

local function placeInvestigatorSpawn(office: Instance)
	local spawnPad = office:FindFirstChild("InvestigatorSpawn")
	if spawnPad and spawnPad:IsA("SpawnLocation") then
		spawnPad.CFrame = CFrame.lookAt(SPAWN_POSITION, SPAWN_POSITION + Vector3.new(0, 0, -1))
		spawnPad.Transparency = 1
		-- No spawn-protection bubble: there is nothing to be protected from.
		spawnPad.Duration = 0
	end
end

-- M6: the authored asset ships Daniel's desk group 4 studs above the floor
-- (desk, chair, monitor, lamp), leaving the evidence on it hanging in the air
-- at the correct desk height. Settle the group so the evidence rests on the
-- desk: desk and chair onto the floor, the chair pulled out on the side the
-- laptop faces, the monitor and lamp onto the desk's back edge, and the
-- lamp's light and the coffee cup back with them. Each move is a rigid
-- transform of a named authored folder/part, keyed by where it lands.
local DESK_TOP_Y = 2.62

-- Rigidly move every part in `group` so that `from` (a point in its current
-- frame) lands on `to`, turned by `yaw` degrees.
local function moveGroup(group: Instance, from: Vector3, to: Vector3, yaw: number)
	local transform = CFrame.new(to) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(-from)
	local parts: { BasePart } = {}
	if group:IsA("BasePart") then
		table.insert(parts, group)
	end
	for _, descendant in ipairs(group:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	for _, p in ipairs(parts) do
		p.CFrame = transform * p.CFrame
	end
end

local function lowestPoint(group: Instance): Vector3?
	local best: Vector3? = nil
	for _, descendant in ipairs(group:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local bottom = descendant.Position - Vector3.new(0, descendant.Size.Y / 2, 0)
			if not best or bottom.Y < best.Y then
				best = bottom
			end
		end
	end
	return best
end

local function settleDanielsDesk(office: Instance)
	local furniture = office:FindFirstChild("Furniture")
	if not furniture then
		return
	end
	local desk = furniture:FindFirstChild("DanielDesk")
	local deskBottom = desk and lowestPoint(desk)
	-- Idempotent: only an elevated desk is corrected.
	if not desk or not deskBottom or deskBottom.Y < 1 then
		return
	end
	local drop = Vector3.new(0, -deskBottom.Y, 0)
	moveGroup(desk, Vector3.zero, drop, 0)

	local chair = furniture:FindFirstChild("DanielChair")
	if chair then
		-- Pulled out on the south side, where the laptop faces.
		moveGroup(chair, Vector3.zero, drop + Vector3.new(0, 0, 3), 0)
	end

	local monitor = furniture:FindFirstChild("DanielMonitor")
	local monitorBase = monitor and lowestPoint(monitor)
	if monitor and monitorBase then
		-- Behind the laptop, screen turned toward the chair.
		moveGroup(monitor, monitorBase, Vector3.new(-24, DESK_TOP_Y, -9.55), 180)
	end

	local lamp = furniture:FindFirstChild("DanielLamp")
	local lampBase = lamp and lowestPoint(lamp)
	if lamp and lampBase then
		local target = Vector3.new(-27.2, DESK_TOP_Y, -9.3)
		moveGroup(lamp, lampBase, target, 0)
		local glow = office:FindFirstChild("DanielGlow", true)
		local head = lamp:FindFirstChild("LampHead")
		if glow and glow:IsA("BasePart") and head and head:IsA("BasePart") then
			glow.Position = head.Position - Vector3.new(0, 0.4, 0)
		end
	end

	local cup = office:FindFirstChild("Interactables") and office.Interactables:FindFirstChild("CoffeeCup")
	if cup and cup:IsA("BasePart") then
		-- The desk's far-left corner, set back: clear of the evidence, so it
		-- never becomes the prompt while approaching the phone, laptop or
		-- document.
		cup.Position = Vector3.new(-27.4, DESK_TOP_Y + cup.Size.Y / 2, -7.7)
	end
end

-- M6: the desk props, dressed. The Interactable parts themselves keep their
-- names, tags and positions (interaction and framing depend on them); only
-- their look changes, plus untagged decoration parented to Detailing.
local function dressDeskProps(office: Instance, folder: Instance)
	local interactables = office:FindFirstChild("Interactables")
	if not interactables then
		return
	end

	-- A white ceramic mug of cold coffee instead of a red block.
	local cup = interactables:FindFirstChild("CoffeeCup")
	if cup and cup:IsA("Part") then
		local height, diameter = 0.6, 0.5
		local center = cup.Position
		cup.Shape = Enum.PartType.Cylinder
		-- A cylinder's axis is its local X: stand it upright.
		cup.Size = Vector3.new(height, diameter, diameter)
		cup.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		cup.Color = Color3.fromRGB(232, 228, 220)
		cup.Material = Enum.Material.SmoothPlastic

		local coffee = part("CoffeeCup_Coffee", Vector3.new(0.02, diameter * 0.84, diameter * 0.84), center, Color3.fromRGB(38, 24, 16), Enum.Material.SmoothPlastic, false)
		coffee.Shape = Enum.PartType.Cylinder
		coffee.CFrame = CFrame.new(center + Vector3.new(0, height / 2 - 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
		coffee.CanQuery = false
		coffee.Parent = folder

		local handle = part("CoffeeCup_Handle", Vector3.new(0.08, 0.34, 0.2), center + Vector3.new(diameter / 2 + 0.05, 0, 0), cup.Color, Enum.Material.SmoothPlastic, false)
		handle.CanQuery = false
		handle.Parent = folder
	end

	-- The phone's screen still faintly lit, face up on the desk.
	local phone = interactables:FindFirstChild("Phone")
	if phone and phone:IsA("BasePart") then
		local screen = part(
			"Phone_Screen",
			Vector3.new(phone.Size.X * 0.82, 0.02, phone.Size.Z * 0.86),
			phone.Position,
			Color3.fromRGB(58, 82, 98),
			Enum.Material.Neon,
			false,
			0.3
		)
		screen.CFrame = phone.CFrame * CFrame.new(0, phone.Size.Y / 2 + 0.01, 0)
		screen.CanQuery = false
		screen.Parent = folder
	end

	-- The drawer front under the desktop on the chair side, at the desk's
	-- far-left end, away from the evidence (the authored part lies flat on
	-- top of the desk). The desk's front edge is z = -6; the default
	-- orientation keeps the examine close-up on the open, chair side.
	local drawer = interactables:FindFirstChild("DeskDrawer")
	if drawer and drawer:IsA("BasePart") then
		local front = Vector3.new(-26.9, DESK_TOP_Y - 0.1 - 0.3, -5.96)
		drawer.Size = Vector3.new(1.8, 0.45, 0.12)
		drawer.CFrame = CFrame.new(front)
		drawer.Color = Color3.fromRGB(150, 104, 62)
		drawer.Material = Enum.Material.Wood
		local pull = part("DeskDrawer_Pull", Vector3.new(0.5, 0.06, 0.06), front + Vector3.new(0, 0, 0.09), Color3.fromRGB(40, 40, 44), Enum.Material.Metal, false)
		pull.CanQuery = false
		pull.Parent = folder
	end

	-- Screens at night: the monitor has gone to sleep; the laptop is still
	-- awake, dimmed.
	local monitor = office:FindFirstChild("Furniture") and office.Furniture:FindFirstChild("DanielMonitor")
	local monitorScreen = monitor and monitor:FindFirstChild("Screen")
	if monitorScreen and monitorScreen:IsA("BasePart") then
		monitorScreen.Color = Color3.fromRGB(16, 18, 22)
		monitorScreen.Material = Enum.Material.Glass
	end
	local laptop = interactables:FindFirstChild("Laptop")
	local laptopDisplay = laptop and laptop:FindFirstChild("LaptopDisplay")
	if laptopDisplay and laptopDisplay:IsA("BasePart") then
		laptopDisplay.Color = Color3.fromRGB(70, 108, 136)
	end
	-- The meeting room's presentation screen idles on a dim standby blue.
	local presentation = office:FindFirstChild("Furniture") and office.Furniture:FindFirstChild("PresScreenOn")
	if presentation and presentation:IsA("BasePart") then
		presentation.Color = Color3.fromRGB(24, 40, 66)
	end
end

function OfficeDetailing.start()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} not found; skipping environment detailing`)
		return
	end

	placeInvestigatorSpawn(office)
	settleDanielsDesk(office)
	retuneFixtures()

	local folder = office:FindFirstChild(DETAIL_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DETAIL_FOLDER_NAME
		folder.Parent = office
	end

	buildReceptionPartition(folder)
	buildCorridorSpine(folder)
	buildWallArticulation(folder)
	buildMeetingRoomGlazing(folder)
	buildPantry(folder)
	buildDroppedCeilings(folder)
	buildDeskDensification(folder)
	buildCrimeSceneTape(folder)
	buildChalkOutline(folder)
	buildEvidenceMarkers(folder)
	dressDeskProps(office, folder)

	log:info("office detailing applied", { parts = #folder:GetChildren() })
end

return OfficeDetailing
