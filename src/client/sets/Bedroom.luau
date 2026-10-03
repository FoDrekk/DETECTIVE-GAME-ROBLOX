--!strict
--[[
	Bedroom: the cold open's set. A condo bedroom in Bukit Pelangi at
	11:47 at night: rain on a big window, the city cool and blue behind it,
	a bedside table with a clock, a phone and a strip of tablets, and a hand.

	Nothing here names her: no face, no lanyard, no photograph. There is a hand
	with a thin gold band, and a strip of migraine tablets none of which has been
	pressed out (the rare player who remembers them will hear "I took something.
	I was out by ten." and know). It is never pointed at.

	Local coordinates (origin: the middle of the floor; the window is in the north
	wall, -Z; the bed's head is against the west wall, -X):
	  * the bedside table stands between the bed and the window, its top 2.2 up;
	  * the phone lies on it with its long axis along X, its top toward the west.

	Actions:
	  PhoneRing   the phone starts to buzz: its screen lights (Incoming call,
	              "Daniel"), it shivers on the wood. Until PhoneStop.
	  PhoneStop   screen dark, still.
	  HandComes   the hand comes in from the east and hovers over the phone
	              ({ time } seconds to arrive).
	  PhoneFlip   the hand touches the phone and turns it face down; the buzzing
	              stops as it goes over; the hand withdraws.
]]

local RunService = game:GetService("RunService")

local SetKit = require(script.Parent:WaitForChild("SetKit"))

local Bedroom = {}

local M = SetKit.M
local C3 = Color3.fromRGB

local PLASTER = C3(58, 53, 57)
local PLASTER_DARK = C3(44, 40, 45)
local WOOD = C3(78, 54, 40)
local WOOD_DARK = C3(50, 35, 28)
local LINEN = C3(96, 92, 98)
local BLANKET = C3(104, 88, 98)
local SKIN = C3(224, 184, 160)
local NAIL = C3(228, 192, 182)
local GOLD = C3(238, 192, 88)

local WALL = 0.5
local TABLE_TOP = 2.2
-- Where the phone lies (its centre), and the strip of tablets beside it.
local PHONE_AT = Vector3.new(-5.45, TABLE_TOP + 0.03, -4.45)
local STRIP_AT = Vector3.new(-5.45, TABLE_TOP + 0.011, -3.85)

function Bedroom.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local function world(v: Vector3): Vector3
		return origin + v
	end

	--------------------------------------------------------------------
	-- The room
	--------------------------------------------------------------------
	local shell = Instance.new("Folder")
	shell.Name = "Room"
	shell.Parent = parent
	local function slab(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?)
		return SetKit.part(shell, name, size, at(x, y, z), color, material or M.SmoothPlastic, { castShadow = true })
	end
	slab("Floor", Vector3.new(15, 0.3, 13), 0, -0.15, 0, WOOD_DARK, M.Wood)
	slab("Ceiling", Vector3.new(15, 0.3, 13), 0, 9.15, 0, PLASTER_DARK)
	slab("Wall_W", Vector3.new(WALL, 9.3, 13), -7.25, 4.5, 0, PLASTER)
	slab("Wall_E", Vector3.new(WALL, 9.3, 13), 7.25, 4.5, 0, PLASTER)
	slab("Wall_S", Vector3.new(15, 9.3, WALL), 0, 4.5, 6.25, PLASTER)
	-- The north wall, with a window opening x -4.5..4.5, y 2.4..7.6.
	slab("Wall_N_L", Vector3.new(3, 9.3, WALL), -6, 4.5, -6.25, PLASTER)
	slab("Wall_N_R", Vector3.new(3, 9.3, WALL), 6, 4.5, -6.25, PLASTER)
	slab("Wall_N_Below", Vector3.new(9, 2.4, WALL), 0, 1.2, -6.25, PLASTER)
	slab("Wall_N_Above", Vector3.new(9, 1.7, WALL), 0, 8.45, -6.25, PLASTER)
	-- Skirting, a darker line where the wall meets the floor.
	slab("Skirting_W", Vector3.new(0.12, 0.45, 12.4), -6.94, 0.22, 0, WOOD_DARK, M.Wood)
	slab("Skirting_E", Vector3.new(0.12, 0.45, 12.4), 6.94, 0.22, 0, WOOD_DARK, M.Wood)
	slab("Skirting_S", Vector3.new(13.8, 0.45, 0.12), 0, 0.22, 5.94, WOOD_DARK, M.Wood)

	-- The window: aluminium frame, two mullions, three panes of glass.
	local frameColor = C3(24, 25, 29)
	slab("Frame_Sill", Vector3.new(9.6, 0.22, 0.95), 0, 2.5, -6.05, frameColor, M.Metal)
	slab("Frame_Head", Vector3.new(9.4, 0.22, 0.5), 0, 7.5, -6.2, frameColor, M.Metal)
	for _, x in ipairs({ -4.55, 4.55 }) do
		slab("Frame_Side", Vector3.new(0.24, 5.2, 0.5), x, 5, -6.2, frameColor, M.Metal)
	end
	for _, x in ipairs({ -1.5, 1.5 }) do
		slab("Mullion", Vector3.new(0.14, 5.0, 0.24), x, 5, -6.2, frameColor, M.Metal)
	end
	local panes: { BasePart } = {}
	for index, x in ipairs({ -3.05, 0, 3.05 }) do
		-- Plain plastic, not Glass: the Glass material only refracts what is opaque
		-- behind it, and the rain is not.
		local pane = SetKit.part(shell, `Pane_{index}`, Vector3.new(2.85, 4.95, 0.05), at(x, 5, -6.25), C3(150, 172, 196), M.SmoothPlastic, { transparency = 0.9, reflectance = 0.05, castShadow = false })
		table.insert(panes, pane)
	end
	-- Sheer curtains drawn back either side.
	for _, x in ipairs({ -5.5, 5.5 }) do
		SetKit.part(shell, "Curtain", Vector3.new(1.3, 7.6, 0.2), at(x, 4.4, -5.75), C3(120, 112, 116), M.Fabric, { transparency = 0.2, castShadow = false })
	end

	--------------------------------------------------------------------
	-- Outside: the city, orange through the rain
	--------------------------------------------------------------------
	local outside = Instance.new("Folder")
	outside.Name = "Outside"
	outside.Parent = parent
	-- The glow at the horizon: the city's light pollution under low cloud at
	-- midnight -- cool, faintly blue-white where the town core sits, dying to
	-- near-black overhead. No warm band: this is hours past sunset.
	SetKit.gradientSky(outside, "Sky", CFrame.lookAt(origin + Vector3.new(0, 110, -560), origin + Vector3.new(0, 110, 0)), 2040, 420, {
		{ at = 0, color = C3(7, 9, 16) },
		{ at = 0.45, color = C3(12, 16, 28) },
		{ at = 0.66, color = C3(30, 42, 64) },
		{ at = 0.74, color = C3(66, 88, 122) },
		{ at = 0.79, color = C3(52, 70, 102) },
		{ at = 1, color = C3(16, 22, 34) },
	})
	-- A block across the street, close enough to have windows you can count,
	-- covering the left of the view; a lower one at the right.
	SetKit.tower(outside, "Block", world(Vector3.new(-17, -30, -34)), 22, 12, 58, { color = C3(22, 22, 30), seed = 31, litChance = 0.26, faces = { "south" }, facade = true })
	SetKit.tower(outside, "BlockB", world(Vector3.new(19, -30, -46)), 22, 14, 44, { color = C3(26, 26, 34), seed = 32, litChance = 0.24, faces = { "south" }, facade = true })
	-- The skyline in between, low against the glow (its tops stay under the
	-- window's own top), its windows drawn large so they still read.
	local rng = Random.new(77)
	local x = -260
	local index = 0
	while x < 240 do
		index += 1
		local width = rng:NextNumber(14, 26)
		local height = rng:NextNumber(30, 70)
		local depth = rng:NextNumber(12, 18)
		local z = -300 - rng:NextNumber(0, 110)
		SetKit.tower(outside, `Far_{index}`, world(Vector3.new(x + width / 2, -30, z)), width, depth, height + 30, { color = C3(24, 24, 34), seed = 100 + index, litChance = 0.16, faces = { "south" }, scale = 2.1, coolChance = 0.18 })
		x += width + rng:NextNumber(3, 14)
	end
	-- Ground far below: a wet dark street with the glint of its lamps.
	SetKit.part(outside, "Ground", Vector3.new(1600, 0.4, 800), at(0, -30, -250), C3(16, 16, 22), M.SmoothPlastic, { castShadow = false })

	-- Rain, falling in front of it all, and beads running down the glass.
	SetKit.rain(outside, at(0, 46, -30), Vector3.new(120, 0.2, 120), 60, { rate = 2400, speed = 70, length = 1.6, slant = -3 })
	for index, pane in ipairs(panes) do
		local beads = Instance.new("ParticleEmitter")
		beads.Name = `Beads_{index}`
		beads.Rate = 14
		beads.Lifetime = NumberRange.new(4, 7)
		beads.Speed = NumberRange.new(0.12, 0.5)
		beads.SpreadAngle = Vector2.new(6, 6)
		beads.EmissionDirection = Enum.NormalId.Bottom
		beads.Size = NumberSequence.new(0.09, 0.05)
		beads.Transparency = NumberSequence.new(0.2, 0.8)
		beads.Color = ColorSequence.new(C3(170, 200, 235))
		beads.LightEmission = 0.8
		beads.Acceleration = Vector3.new(0, -0.6, 0)
		beads.Parent = pane
	end

	-- The city's light coming in: a cool wash from the window, over everything.
	local glow = SetKit.part(outside, "GlowSource", Vector3.new(9, 5, 0.2), at(0, 5, -9), Color3.new(1, 1, 1), M.SmoothPlastic, { transparency = 1, castShadow = false })
	SetKit.light(glow, "SurfaceLight", 0.3, 22, C3(150, 178, 225), { face = Enum.NormalId.Back, angle = 120 })
	local haze = SetKit.part(outside, "GlowHaze", Vector3.new(1, 1, 1), at(0, 8, -12), Color3.new(1, 1, 1), M.SmoothPlastic, { transparency = 1, castShadow = false })
	SetKit.light(haze, "PointLight", 0.22, 26, C3(96, 122, 176))

	--------------------------------------------------------------------
	-- The bed (she is turned away, under the blanket)
	--------------------------------------------------------------------
	local bed = Instance.new("Folder")
	bed.Name = "Bed"
	bed.Parent = parent
	local function bedPart(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?): Part
		return SetKit.part(bed, name, size, at(x, y, z), color, material or M.SmoothPlastic, { castShadow = true })
	end
	bedPart("Headboard", Vector3.new(0.5, 3.8, 5.6), -6.85, 1.9, -0.1, WOOD_DARK)
	bedPart("Base", Vector3.new(6.0, 0.9, 5.2), -3.8, 0.45, -0.1, WOOD_DARK)
	bedPart("Mattress", Vector3.new(5.9, 0.7, 4.9), -3.85, 1.25, -0.1, LINEN)
	bedPart("Pillow_A", Vector3.new(1.0, 0.4, 1.9), -6.1, 1.8, -1.25, LINEN)
	bedPart("Pillow_B", Vector3.new(1.0, 0.4, 1.9), -6.1, 1.8, 0.95, LINEN)
	bedPart("Blanket", Vector3.new(4.4, 0.32, 5.0), -2.9, 1.78, -0.1, BLANKET)
	-- The turned-away shape under it, nearest the window: a shoulder and a hip.
	SetKit.ellipsoid(bed, "Shoulder", Vector3.new(1.5, 0.75, 1.3), at(-5.3, 2.02, -1.55), BLANKET, M.SmoothPlastic, { castShadow = true })
	SetKit.ellipsoid(bed, "Hip", Vector3.new(1.8, 0.7, 1.45), at(-3.8, 2.0, -1.6), BLANKET, M.SmoothPlastic, { castShadow = true })
	bedPart("Fold", Vector3.new(0.5, 0.42, 4.7), -4.95, 1.98, 0.35, BLANKET)

	--------------------------------------------------------------------
	-- The rest of the room, in the dark
	--------------------------------------------------------------------
	local room = Instance.new("Folder")
	room.Name = "Furniture"
	room.Parent = parent
	local function furniture(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?): Part
		return SetKit.part(room, name, size, at(x, y, z), color, material or M.SmoothPlastic, { castShadow = true })
	end
	-- Bedside table.
	furniture("Table_Body", Vector3.new(2.2, 2.1, 2.4), -5.9, 1.05, -4.6, WOOD)
	furniture("Table_Top", Vector3.new(2.3, 0.1, 2.5), -5.9, 2.15, -4.6, WOOD_DARK)
	furniture("Table_Drawer", Vector3.new(0.04, 0.7, 1.9), -4.78, 1.5, -4.6, WOOD_DARK)
	SetKit.part(room, "Table_Handle", Vector3.new(0.05, 0.08, 0.4), at(-4.75, 1.5, -4.6), C3(150, 150, 154), M.Metal, { castShadow = false })
	-- Wardrobe against the east wall, a chair with clothes over it.
	furniture("Wardrobe", Vector3.new(2.0, 8.0, 4.6), 6.0, 4.0, -3.5, C3(30, 23, 21))
	furniture("Wardrobe_Doors", Vector3.new(0.05, 7.4, 2.1), 4.95, 4.0, -4.6, C3(38, 29, 25))
	furniture("Wardrobe_Doors_B", Vector3.new(0.05, 7.4, 2.1), 4.95, 4.0, -2.4, C3(38, 29, 25))
	-- A chair by the south wall with a coat over it.
	furniture("Chair_Seat", Vector3.new(1.8, 0.25, 1.8), -1.2, 1.5, 5.0, WOOD_DARK)
	furniture("Chair_Back", Vector3.new(1.8, 2.6, 0.25), -1.2, 2.8, 5.8, WOOD_DARK)
	for _, dz in ipairs({ -0.75, 0.75 }) do
		for _, dx in ipairs({ -0.75, 0.75 }) do
			furniture("Chair_Leg", Vector3.new(0.18, 1.4, 0.18), -1.2 + dx, 0.7, 5.0 + dz, WOOD_DARK)
		end
	end
	furniture("Coat", Vector3.new(1.5, 1.6, 0.5), -1.2, 3.2, 5.6, C3(68, 74, 88), M.Fabric)
	-- A rug under the foot of the bed.
	SetKit.part(room, "Rug", Vector3.new(6.5, 0.06, 4.6), at(2.4, 0.03, -0.5), C3(70, 62, 66), M.Fabric, { castShadow = false })
	-- A lamp on the table, off; a glass of water.
	local lampBase = SetKit.pillar(room, "Lamp_Base", 0.9, 0.5, world(Vector3.new(-6.6, TABLE_TOP + 0.5, -5.45)), C3(90, 84, 80), M.SmoothPlastic)
	lampBase.CastShadow = false
	SetKit.part(room, "Lamp_Shade", Vector3.new(0.95, 0.75, 0.95), at(-6.6, TABLE_TOP + 1.25, -5.45), C3(150, 140, 128), M.Fabric, { castShadow = false })
	SetKit.pillar(room, "Glass", 0.42, 0.26, world(Vector3.new(-5.3, TABLE_TOP + 0.21, -5.45)), C3(190, 205, 215), M.Glass, { transparency = 0.6, castShadow = false })

	--------------------------------------------------------------------
	-- The clock: 11:47, red, on the bedside table, facing the room
	--------------------------------------------------------------------
	local clock = SetKit.part(room, "Clock", Vector3.new(1.3, 0.55, 0.45), at(-6.4, TABLE_TOP + 0.275, -4.6), C3(22, 22, 24), M.SmoothPlastic, { castShadow = false })
	clock.CFrame = CFrame.lookAt(origin + Vector3.new(-6.4, TABLE_TOP + 0.275, -4.6), origin + Vector3.new(-5, TABLE_TOP + 0.275, -4.6))
	local clockFace = SetKit.label(clock, Enum.NormalId.Front, "11:47", {
		color = C3(255, 60, 44),
		font = Enum.Font.Code,
		lightInfluence = 0,
		pixelsPerStud = 260,
		padding = 20,
	})
	clockFace.Name = "Digits"
	SetKit.light(clock, "PointLight", 0.5, 7, C3(255, 70, 50))

	--------------------------------------------------------------------
	-- The strip of tablets: a blister pack, none of them pressed out
	--------------------------------------------------------------------
	local strip = Instance.new("Model")
	strip.Name = "Tablets"
	strip.Parent = room
	local foil = SetKit.part(strip, "Foil", Vector3.new(0.72, 0.014, 0.34), CFrame.new(world(STRIP_AT)), C3(196, 198, 204), M.Metal, { reflectance = 0.3, castShadow = false })
	SetKit.label(foil, Enum.NormalId.Top, "MIGRAINE RELIEF  50 mg", {
		color = C3(60, 64, 78),
		font = Enum.Font.GothamBold,
		pixelsPerStud = 900,
		lightInfluence = 1,
		padding = 8,
	})
	for column = 0, 3 do
		for row = 0, 1 do
			local x = STRIP_AT.X + (column - 1.5) * 0.155
			local z = STRIP_AT.Z + (row - 0.5) * 0.15
			SetKit.ball(strip, "Blister", 0.11, world(Vector3.new(x, STRIP_AT.Y + 0.05, z)), C3(200, 220, 230), M.Glass, { transparency = 0.55, castShadow = false })
			SetKit.ball(strip, "Pill", 0.075, world(Vector3.new(x, STRIP_AT.Y + 0.035, z)), C3(238, 236, 228), M.SmoothPlastic, { castShadow = false })
		end
	end

	--------------------------------------------------------------------
	-- The phone
	--------------------------------------------------------------------
	local phone = Instance.new("Model")
	phone.Name = "Phone"
	phone.Parent = room
	-- Long axis along X, the top of the screen toward -X (west).
	local phoneBase = CFrame.new(world(PHONE_AT))
	local body = SetKit.part(phone, "Body", Vector3.new(0.6, 0.055, 0.29), phoneBase, C3(30, 32, 36), M.SmoothPlastic, { castShadow = false })
	local screen = SetKit.part(phone, "Screen", Vector3.new(0.56, 0.008, 0.265), phoneBase * CFrame.new(0, 0.03, 0), C3(6, 7, 9), M.Glass, { castShadow = false, reflectance = 0.1 })
	local back = SetKit.part(phone, "Back", Vector3.new(0.58, 0.006, 0.27), phoneBase * CFrame.new(0, -0.03, 0), C3(52, 56, 66), M.Metal, { castShadow = false, reflectance = 0.25 })
	SetKit.ball(phone, "Camera", 0.07, phoneBase * CFrame.new(-0.2, -0.04, -0.08), C3(12, 12, 14), M.Glass, { castShadow = false })
	phone.PrimaryPart = body
	local ui = Instance.new("SurfaceGui")
	ui.Name = "Ring"
	ui.Face = Enum.NormalId.Top
	ui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	ui.PixelsPerStud = 900
	ui.LightInfluence = 0
	ui.Enabled = false
	ui.Parent = screen
	local canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = C3(12, 16, 26)
	canvas.BorderSizePixel = 0
	canvas.Parent = ui
	local function line(text: string, y: number, height: number, size: number, color: Color3, font: Enum.Font)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Text = text
		label.TextColor3 = color
		label.Font = font
		label.TextSize = size
		label.Parent = canvas
		return label
	end
	line("incoming call", 0.12, 0.1, 22, C3(150, 160, 178), Enum.Font.Gotham)
	line("Daniel \u{2665}", 0.3, 0.18, 46, C3(244, 246, 250), Enum.Font.GothamBold)
	line("mobile", 0.5, 0.08, 20, C3(150, 160, 178), Enum.Font.Gotham)
	for index, color in ipairs({ C3(214, 60, 60), C3(70, 190, 100) }) do
		local button = Instance.new("Frame")
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromScale(if index == 1 then 0.28 else 0.72, 0.84)
		button.Size = UDim2.fromOffset(74, 74)
		button.BackgroundColor3 = color
		button.BorderSizePixel = 0
		button.Parent = canvas
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = button
	end
	local phoneLight = SetKit.part(phone, "Glow", Vector3.new(0.2, 0.05, 0.2), phoneBase * CFrame.new(0, 0.08, 0), Color3.new(1, 1, 1), M.SmoothPlastic, { transparency = 1, castShadow = false })
	local glowLight = SetKit.light(phoneLight, "PointLight", 0, 1.7, C3(150, 190, 255))

	--------------------------------------------------------------------
	-- The hand: a thin gold band on the ring finger
	--------------------------------------------------------------------
	local hand = Instance.new("Model")
	hand.Name = "Hand"
	hand.Parent = room
	-- Modelled with the wrist at the origin, the fingers toward -Z, palm down. Made
	-- of rods and rounded ends so it reads as a hand at the distance a hand is seen.
	local handRoot = SetKit.part(hand, "Wrist", Vector3.new(0.12, 0.22, 0.22), CFrame.identity, SKIN, M.SmoothPlastic, { castShadow = false })
	handRoot.Shape = Enum.PartType.Cylinder
	local function handBall(name: string, diameter: Vector3, offset: CFrame, color: Color3): Part
		local p = SetKit.part(hand, name, diameter, offset, color, M.SmoothPlastic, { castShadow = false })
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- A rod along the frame's -Z, from the frame's origin for `length`.
	local function handRod(name: string, length: number, diameter: number, frame: CFrame, color: Color3, material: Enum.Material?): Part
		local p = SetKit.part(hand, name, Vector3.new(length, diameter, diameter), frame * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.rad(90), 0), color, material or M.SmoothPlastic, { castShadow = false })
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	handRod("Forearm", 1.5, 0.24, CFrame.new(0, 0, 1.5), SKIN)
	handRod("Cuff", 0.55, 0.34, CFrame.new(0, 0, 1.75), C3(196, 192, 204))
	-- The palm and the back of the hand.
	SetKit.ellipsoid(hand, "Heel", Vector3.new(0.27, 0.1, 0.22), CFrame.new(0, 0, -0.07), SKIN, M.SmoothPlastic, { castShadow = false })
	SetKit.ellipsoid(hand, "Back", Vector3.new(0.31, 0.105, 0.36), CFrame.new(0, 0.004, -0.19), SKIN, M.SmoothPlastic, { castShadow = false })
	SetKit.part(hand, "Palm", Vector3.new(0.29, 0.06, 0.2), CFrame.new(0, -0.012, -0.2), SKIN, M.SmoothPlastic, { castShadow = false })
	-- The row of knuckles the fingers grow from.
	local knuckles = SetKit.cylinder(hand, "Knuckles", 0.29, 0.07, CFrame.new(0, -0.004, -0.31), SKIN, M.SmoothPlastic, { castShadow = false })
	knuckles.CanQuery = false
	-- Fingers: three segments each, curling a little toward the table.
	local fingers = {
		{ x = -0.105, lengths = { 0.13, 0.085, 0.065 } },
		{ x = -0.035, lengths = { 0.145, 0.095, 0.07 } },
		{ x = 0.035, lengths = { 0.13, 0.09, 0.066 } },
		{ x = 0.105, lengths = { 0.1, 0.065, 0.055 } },
	}
	local curls = { 4, 16, 28 }
	local diameters = { 0.064, 0.058, 0.052 }
	for index, finger in ipairs(fingers) do
		local frame = CFrame.new(finger.x, -0.004, -0.31)
		for segment, length in ipairs(finger.lengths) do
			frame = frame * CFrame.Angles(math.rad(-curls[segment]), 0, 0)
			local rod = handRod(`Finger_{index}_{segment}`, length, diameters[segment], frame, SKIN)
			local joint = handBall(`Knuckle_{index}_{segment}`, Vector3.new(diameters[segment], diameters[segment], diameters[segment]), frame * CFrame.new(0, 0, -length), SKIN)
			if segment == 3 then
				SetKit.part(hand, `Nail_{index}`, Vector3.new(0.04, 0.007, 0.042), joint.CFrame * CFrame.new(0, diameters[3] / 2 - 0.004, 0.02), NAIL, M.SmoothPlastic, { castShadow = false })
			end
			if index == 3 and segment == 1 then
				-- The ring finger's band: thin, gold, catching whatever light there is.
				local bandFrame = frame * CFrame.new(0, 0, -length * 0.42)
				local band = handRod("Ring", 0.024, 0.072, bandFrame, GOLD, M.Metal)
				band.Reflectance = 0.6
			end
			frame = frame * CFrame.new(0, 0, -length)
			rod.CanQuery = false
		end
	end
	local thumbFrame = CFrame.new(-0.16, -0.012, -0.12) * CFrame.Angles(0, math.rad(34), 0)
	for segment, length in ipairs({ 0.12, 0.09 }) do
		thumbFrame = thumbFrame * CFrame.Angles(math.rad(-6 * segment), 0, 0)
		handRod(`Thumb_{segment}`, length, 0.07 - 0.008 * segment, thumbFrame, SKIN)
		handBall(`ThumbJoint_{segment}`, Vector3.new(0.066, 0.066, 0.066), thumbFrame * CFrame.new(0, 0, -length), SKIN)
		thumbFrame = thumbFrame * CFrame.new(0, 0, -length)
	end
	hand.PrimaryPart = handRoot
	hand:ScaleTo(0.78)

	-- Poses of the hand: the wrist's position, fingers pointing west (-X).
	local function handPose(offset: Vector3, roll: number?): CFrame
		return CFrame.lookAt(world(PHONE_AT + offset), world(PHONE_AT + offset) + Vector3.new(-1, 0, 0)) * CFrame.Angles(0, 0, roll or 0)
	end
	local AWAY = handPose(Vector3.new(3.2, 0.6, 0.5))
	local HOVER = handPose(Vector3.new(0.66, 0.3, 0.0), math.rad(-4))
	local TOUCH = handPose(Vector3.new(0.6, 0.09, 0.0), math.rad(-2))
	-- The hand starts out of the world.
	hand:PivotTo(AWAY)
	for _, d in ipairs(hand:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	local function showHand(visible: boolean)
		for _, d in ipairs(hand:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = if visible then 0 else 1
			end
		end
	end

	--------------------------------------------------------------------
	-- Motion
	--------------------------------------------------------------------
	local ringing = false
	local flipped = false
	local phonePivot = phoneBase
	local handDriver = Instance.new("CFrameValue")
	handDriver.Value = AWAY
	scope.add(handDriver)
	scope.add(handDriver.Changed:Connect(function(value: CFrame)
		hand:PivotTo(value)
	end))
	local hovering = false
	local hoverStart = 0

	-- The phone shivers on the wood while it rings, in bursts.
	scope.add(RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if ringing then
			local burst = (t % 1.5) < 1.05
			local amplitude = if burst then 0.006 else 0.0012
			local dx = (math.noise(t * 41, 3.1) * 2) * amplitude
			local dz = (math.noise(t * 37, 7.7) * 2) * amplitude
			local spin = math.noise(t * 33, 1.9) * 0.02 * (if burst then 1 else 0.2)
			phone:PivotTo(phonePivot * CFrame.new(dx, 0, dz) * CFrame.Angles(0, spin, 0))
			glowLight.Brightness = (if burst then 2.2 else 1.5) + math.noise(t * 9, 2.2) * 0.25
		end
		if hovering then
			-- The hand's hesitation: a slight tremor and a slow sway.
			local held = t - hoverStart
			local sway = CFrame.new(math.noise(held * 0.9, 5.5) * 0.02, math.noise(held * 1.1, 8.2) * 0.012, math.noise(held * 0.8, 1.4) * 0.02)
			local shake = CFrame.Angles(math.noise(held * 6, 2.4) * 0.006, math.noise(held * 7, 9.6) * 0.008, 0)
			handDriver.Value = HOVER * sway * shake
		end
	end))

	local function setScreen(lit: boolean)
		ui.Enabled = lit
		screen.Color = if lit then C3(20, 28, 44) else C3(6, 7, 9)
		glowLight.Brightness = if lit then 2.0 else 0
	end

	local function tweenHand(target: CFrame, seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
		scope.add(SetKit.tween(handDriver, seconds, { Value = target }, style, direction))
	end

	local actions: { [string]: (args: { [string]: any }?) -> () } = {
		PhoneRing = function()
			ringing = true
			setScreen(true)
		end,
		PhoneStop = function()
			ringing = false
			setScreen(false)
			if not flipped then
				phone:PivotTo(phonePivot)
			end
		end,
		HandComes = function(args)
			local seconds = (args and args.time) or 2.4
			showHand(true)
			handDriver.Value = AWAY
			tweenHand(HOVER, seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			task.delay(seconds, function()
				hovering = true
				hoverStart = os.clock()
			end)
		end,
		PhoneFlip = function(args)
			if flipped then
				return
			end
			flipped = true
			hovering = false
			local seconds = (args and args.time) or 0.9
			-- Down onto the phone's edge...
			tweenHand(TOUCH, 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.delay(0.42, function()
				-- ...and over it goes, the buzzing stopping as it turns.
				ringing = false
				local turn = Instance.new("NumberValue")
				turn.Value = 0
				scope.add(turn)
				scope.add(turn.Changed:Connect(function(angle: number)
					phone:PivotTo(phonePivot * CFrame.new(-0.05 * math.sin(angle / 2), 0.09 * math.sin(angle), 0) * CFrame.Angles(angle, 0, 0))
				end))
				scope.add(SetKit.tween(turn, seconds * 0.6, { Value = math.pi }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
				task.delay(seconds * 0.3, function()
					setScreen(false)
				end)
				-- The hand draws back.
				task.delay(seconds * 0.55, function()
					tweenHand(AWAY, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				end)
			end)
		end,
	}

	return {
		act = function(name: string, args: { [string]: any }?)
			local action = actions[name]
			if action then
				action(args)
			end
		end,
		destroy = function()
			scope.clean()
		end,
	}
end

return Bedroom
