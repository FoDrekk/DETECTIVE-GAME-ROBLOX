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


-- Palette (kept close to the existing Office/UI palette, not invented fresh).
local PLASTER = Color3.fromRGB(180, 176, 168)
local TRIM = Color3.fromRGB(55, 54, 51)
local GLASS_TINT = Color3.fromRGB(120, 150, 170)



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



local function buildMeetingRoomGlazing(folder: Instance)
	-- Interior glazing on the Meeting Room's corridor-facing wall, echoing
	-- the glass door Daniel's Office already has. A new glass part inserted
	-- at the wall's own position would sit inside (and be hidden behind)
	-- the existing solid wall part, defeating the point of glazing -- so
	-- this makes the existing "Part_Meeting_West_N" segment itself
	-- semi-transparent instead (a property tweak on a named existing
	-- instance, the same safe category as the lighting retuning above),
	-- and frames its corridor-facing surface with slim rails and mullions,
	-- which sit in genuinely open space and need no embedding.
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local shell = office and office:FindFirstChild("Shell")
	local wall = shell and shell:FindFirstChild("Part_Meeting_West_N")
	if wall and wall:IsA("BasePart") then
		wall.Transparency = 0.6
		wall.Material = Enum.Material.Glass
		wall.Color = GLASS_TINT
	end

	-- A real frame on the corridor side: head and sill rails with slim
	-- mullions (it used to be one solid slab that hid the glass entirely).
	local x = 9.42
	local z0, z1 = -23.5, -12
	local length = z1 - z0
	local mid = (z0 + z1) / 2
	part("Meeting_Glazing_Head", Vector3.new(0.16, 0.25, length), Vector3.new(x, 11.8, mid), TRIM, Enum.Material.Metal, false).Parent = folder
	part("Meeting_Glazing_Sill", Vector3.new(0.16, 0.25, length), Vector3.new(x, 0.125, mid), TRIM, Enum.Material.Metal, false).Parent = folder
	for i = 0, 3 do
		local z = z0 + 0.1 + i * (length - 0.2) / 3
		part(`Meeting_Glazing_Mullion_{i}`, Vector3.new(0.16, 11.8, 0.16), Vector3.new(x, 5.9, z), TRIM, Enum.Material.Metal, false).Parent = folder
	end
end


local function buildDroppedCeilings(folder: Instance)
	-- Visually caps Daniel's Office and the Meeting Room lower than the
	-- open plan's ceiling, for a more intimate private-room scale. Their
	-- lights are fitted by OfficeInterior with the rest of the lighting.
	local danielCeiling = part("DanielOffice_DroppedCeiling", Vector3.new(15, 0.3, 11), Vector3.new(-22, 11, -8), PLASTER, Enum.Material.Plaster, false)
	danielCeiling.Parent = folder
	local meetingCeiling = part("MeetingRoom_DroppedCeiling", Vector3.new(19, 0.3, 17), Vector3.new(20, 11, -15), PLASTER, Enum.Material.Plaster, false)
	meetingCeiling.Parent = folder
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

-- A chalk outline on the floor of Daniel's office, in the open floor east
-- of the desk -- clear of the desk, of the walkway between the office and
-- records-room doors (x -22..-18), and in view from the doorway. Thin chalk
-- strokes tracing a silhouette (one arm flung up, one down, as found), not
-- filled shapes.
local CHALK_ORIGIN = Vector3.new(-17.0, 0.085, -8.6)
local CHALK_SCALE = 0.9
-- Outline points (x, z) around the torso centre, head toward -z.
local CHALK_BODY = {
	{ 0.3, -1.5 }, { 0.9, -1.3 }, { 1.9, -1.9 }, { 2.4, -2.6 }, { 2.1, -2.85 },
	{ 1.6, -2.15 }, { 0.9, -0.8 }, { 0.8, 0.9 }, { 1.2, 2.3 }, { 1.6, 3.4 },
	{ 1.1, 3.5 }, { 0.7, 2.35 }, { 0.1, 1.3 }, { -0.6, 2.4 }, { -0.8, 3.5 },
	{ -1.3, 3.4 }, { -1.1, 2.3 }, { -0.8, 0.9 }, { -0.9, -0.7 }, { -1.6, 0.1 },
	{ -1.9, 0.9 }, { -2.3, 0.7 }, { -2.0, -0.1 }, { -0.9, -1.3 }, { -0.3, -1.5 },
}

local function buildChalkOutline(folder: Instance)
	local outline = Instance.new("Folder")
	outline.Name = "ChalkOutline"
	outline.Parent = folder
	local chalk = Color3.fromRGB(232, 232, 226)

	local function stroke(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		if length < 0.01 then
			return
		end
		local p = Instance.new("Part")
		p.Name = "Stroke"
		p.Size = Vector3.new(0.09, 0.012, length + 0.06)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Color = chalk
		p.Material = Enum.Material.Sand
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = outline
	end

	local function point(x: number, z: number): Vector3
		return CHALK_ORIGIN + Vector3.new(x * CHALK_SCALE, 0, z * CHALK_SCALE)
	end
	for i = 1, #CHALK_BODY do
		local here = CHALK_BODY[i]
		local nextPoint = CHALK_BODY[i % #CHALK_BODY + 1]
		if i < #CHALK_BODY then
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

		-- Cold chamomile, the tag still hanging over the rim: Daniel didn't
		-- drink coffee at night (which is what makes the espresso cup on the
		-- visitor's side of the desk worth a second look).
		local tea = part("CoffeeCup_Tea", Vector3.new(0.02, diameter * 0.84, diameter * 0.84), center, Color3.fromRGB(150, 108, 46), Enum.Material.SmoothPlastic, false)
		tea.Shape = Enum.PartType.Cylinder
		tea.CFrame = CFrame.new(center + Vector3.new(0, height / 2 - 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		tea.CanQuery = false
		tea.Parent = folder
		local string_ = part("CoffeeCup_TeaString", Vector3.new(0.012, 0.3, 0.012), center + Vector3.new(-diameter / 2 - 0.01, height / 2 - 0.12, 0), Color3.fromRGB(236, 232, 222), Enum.Material.Fabric, false)
		string_.CanQuery = false
		string_.CastShadow = false
		string_.Parent = folder
		local tag = part("CoffeeCup_TeaTag", Vector3.new(0.02, 0.16, 0.14), center + Vector3.new(-diameter / 2 - 0.02, height / 2 - 0.34, 0), Color3.fromRGB(214, 196, 120), Enum.Material.SmoothPlastic, false)
		tag.CanQuery = false
		tag.CastShadow = false
		tag.Parent = folder

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

	local folder = office:FindFirstChild(DETAIL_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DETAIL_FOLDER_NAME
		folder.Parent = office
	end

	buildReceptionPartition(folder)
	buildMeetingRoomGlazing(folder)
	buildDroppedCeilings(folder)
	buildCrimeSceneTape(folder)
	buildChalkOutline(folder)
	buildEvidenceMarkers(folder)
	dressDeskProps(office, folder)

	log:info("office detailing applied", { parts = #folder:GetChildren() })
end

return OfficeDetailing
