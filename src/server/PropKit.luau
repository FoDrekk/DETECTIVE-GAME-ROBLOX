--!strict
--[[
	PropKit
	The office's furniture and fixtures, built from parts with Roblox's
	built-in PBR materials (no third-party models, no scripts, no asset ids).
	One palette and one construction vocabulary, so everything reads as the
	same building: brushed steel and charcoal frames, warm oak and walnut,
	dark fabric, leather, glass.

	Conventions (every builder):
	  * `at` is a CFrame on the FLOOR (or a surface, for tabletop props) at
	    the prop's footprint centre; its LookVector is the prop's front --
	    the side a person uses or reads (screens face it, chairs face it,
	    a desk's user sits on it).
	  * Visual parts are anchored and never collide, touch or query. A prop a
	    player should not walk through gets one invisible collider box
	    (cheap, and camera occlusion ignores it).
	  * Only large pieces cast shadows; small details don't (performance).
	  * Returns the Model it built, parented to `parent`.

	Purely environmental: nothing here is interactive or case-specific. The
	one exception to "decoration only" is `evidence(...)`, which builds the
	look for a clue whose Interactable part OfficeRoom creates.
]]

local PropKit = {}

--------------------------------------------------------------------------
-- Palette & materials
--------------------------------------------------------------------------

local P = {
	Plaster = Color3.fromRGB(186, 182, 174),
	PlasterDark = Color3.fromRGB(150, 146, 139),
	Navy = Color3.fromRGB(34, 44, 62),
	Charcoal = Color3.fromRGB(42, 44, 48),
	Graphite = Color3.fromRGB(58, 60, 66),
	Steel = Color3.fromRGB(150, 153, 158),
	SteelDark = Color3.fromRGB(96, 99, 104),
	Oak = Color3.fromRGB(168, 134, 96),
	Walnut = Color3.fromRGB(94, 62, 42),
	WalnutDark = Color3.fromRGB(64, 42, 30),
	Laminate = Color3.fromRGB(214, 210, 202),
	Fabric = Color3.fromRGB(46, 49, 56),
	FabricWarm = Color3.fromRGB(88, 74, 64),
	FabricTeal = Color3.fromRGB(44, 72, 78),
	Leather = Color3.fromRGB(52, 34, 26),
	LeatherBlack = Color3.fromRGB(28, 26, 26),
	Screen = Color3.fromRGB(12, 13, 16),
	ScreenGlow = Color3.fromRGB(58, 92, 128),
	Paper = Color3.fromRGB(232, 229, 220),
	Leaf = Color3.fromRGB(56, 88, 52),
	LeafDark = Color3.fromRGB(38, 64, 40),
	Soil = Color3.fromRGB(46, 34, 26),
	Ceramic = Color3.fromRGB(226, 222, 214),
	Glass = Color3.fromRGB(150, 178, 190),
	WarmLight = Color3.fromRGB(255, 212, 164),
	NeutralLight = Color3.fromRGB(255, 240, 222),
	CoolLight = Color3.fromRGB(196, 214, 255),
	ExitGreen = Color3.fromRGB(70, 220, 120),
}
PropKit.Palette = P

local M = Enum.Material

--------------------------------------------------------------------------
-- Construction helpers
--------------------------------------------------------------------------

export type Builder = {
	model: Model,
	at: CFrame,
}

local function begin(parent: Instance, name: string, at: CFrame): Builder
	local model = Instance.new("Model")
	model.Name = name
	model.WorldPivot = at
	model.Parent = parent
	return { model = model, at = at }
end

local function finish(b: Builder): Model
	return b.model
end

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	-- Small details don't cast shadows (cheap, and avoids shadow acne).
	p.CastShadow = size.X * size.Y * size.Z > 0.35 and math.max(size.X, size.Y, size.Z) > 1
	p.Parent = parent
	return p
end
PropKit.newPart = newPart

-- A box at local offset (x, y, z) (its centre), optionally rotated.
local function box(
	b: Builder,
	name: string,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material,
	rotation: CFrame?
): Part
	local cf = b.at * CFrame.new(x, y, z)
	if rotation then
		cf *= rotation
	end
	return newPart(b.model, name, size, cf, color, material)
end

-- A cylinder standing upright (axis = local Y) centred at (x, y, z).
local function post(
	b: Builder,
	name: string,
	height: number,
	diameter: number,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = newPart(
		b.model,
		name,
		Vector3.new(height, diameter, diameter),
		b.at * CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A cylinder lying along local X (e.g. a rail or a roll).
local function rod(
	b: Builder,
	name: string,
	length: number,
	diameter: number,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material,
	rotation: CFrame?
): Part
	local cf = b.at * CFrame.new(x, y, z)
	if rotation then
		cf *= rotation
	end
	local p = newPart(b.model, name, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(b: Builder, name: string, diameter: number, x: number, y: number, z: number, color: Color3, material: Enum.Material): Part
	local p = newPart(b.model, name, Vector3.new(diameter, diameter, diameter), b.at * CFrame.new(x, y, z), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- One invisible collider for the whole prop (local centre + size).
local function collider(b: Builder, size: Vector3, x: number, y: number, z: number)
	local p = newPart(b.model, "Collider", size, b.at * CFrame.new(x, y, z), P.Charcoal, M.SmoothPlastic)
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	p.CastShadow = false
end

-- Light attached to a part.
local function light(
	part: BasePart,
	kind: "PointLight" | "SpotLight" | "SurfaceLight",
	brightness: number,
	range: number,
	color: Color3,
	options: { face: Enum.NormalId?, angle: number?, shadows: boolean? }?
): Light
	local l: Light
	if kind == "SpotLight" then
		local s = Instance.new("SpotLight")
		s.Face = options and options.face or Enum.NormalId.Bottom
		s.Angle = options and options.angle or 70
		s.Range = range
		l = s
	elseif kind == "SurfaceLight" then
		local s = Instance.new("SurfaceLight")
		s.Face = options and options.face or Enum.NormalId.Bottom
		s.Angle = options and options.angle or 110
		s.Range = range
		l = s
	else
		local s = Instance.new("PointLight")
		s.Range = range
		l = s
	end
	l.Brightness = brightness
	l.Color = color
	l.Shadows = options ~= nil and options.shadows == true
	l.Parent = part
	return l
end
PropKit.light = light

-- Text on a part face.
export type LabelOptions = {
	color: Color3?,
	font: Enum.Font?,
	scaled: boolean?,
	size: number?,
	pixelsPerStud: number?,
	lightInfluence: number?,
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	background: Color3?,
	padding: number?,
	lineHeight: number?,
}

local function label(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	options: LabelOptions?
): SurfaceGui
	local o: LabelOptions = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.pixelsPerStud or 80
	gui.LightInfluence = o.lightInfluence or 1
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if o.background then 0 else 1
	if o.background then
		t.BackgroundColor3 = o.background
	end
	t.BorderSizePixel = 0
	t.Text = text
	t.TextColor3 = o.color or P.Charcoal
	t.Font = o.font or Enum.Font.GothamMedium
	t.TextScaled = o.scaled ~= false and o.size == nil
	if o.size then
		t.TextSize = o.size
	end
	t.TextWrapped = true
	t.LineHeight = o.lineHeight or 1
	t.TextXAlignment = o.xAlign or Enum.TextXAlignment.Center
	t.TextYAlignment = o.yAlign or Enum.TextYAlignment.Center
	t.Parent = gui
	if o.padding then
		local pad = Instance.new("UIPadding")
		local px = UDim.new(0, o.padding)
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = px, px, px, px
		pad.Parent = t
	end
	return gui
end
PropKit.label = label

local function rotY(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end
local function rotX(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end
local function rotZ(degrees: number): CFrame
	return CFrame.Angles(0, 0, math.rad(degrees))
end

-- Deterministic variety: the same seed always furnishes the same way.
local function rng(seed: number): Random
	return Random.new(seed)
end

--------------------------------------------------------------------------
-- Seating
--------------------------------------------------------------------------

export type ChairStyle = {
	upholstery: Color3?,
	material: Enum.Material?,
	frame: Color3?,
	highBack: boolean?,
	arms: boolean?,
	-- Degrees the chair is turned from square, and how far it's pushed back:
	-- chairs left where people got up.
	yaw: number?,
}

-- A swivel office chair: five-star base, gas lift, seat, backrest, arms.
function PropKit.officeChair(parent: Instance, at: CFrame, style: ChairStyle?): Model
	local s: ChairStyle = style or {}
	local b = begin(parent, "OfficeChair", at * rotY(s.yaw or 0))
	local fabric = s.upholstery or P.Fabric
	local mat = s.material or M.Fabric
	local frame = s.frame or P.Charcoal
	for i = 0, 4 do
		local angle = i * 72
		box(b, "Leg", Vector3.new(0.16, 0.1, 0.95), 0, 0.2, 0, frame, M.Metal, rotY(angle) * CFrame.new(0, 0, 0.48))
		local r = math.rad(angle)
		ball(b, "Caster", 0.2, math.sin(r) * 0.92, 0.1, math.cos(r) * 0.92, P.LeatherBlack, M.Rubber)
	end
	post(b, "Hub", 0.2, 0.34, 0, 0.24, 0, frame, M.Metal)
	post(b, "GasLift", 1.1, 0.16, 0, 0.85, 0, P.SteelDark, M.Metal)
	box(b, "SeatPan", Vector3.new(1.5, 0.12, 1.4), 0, 1.42, 0, frame, M.Metal)
	box(b, "Seat", Vector3.new(1.72, 0.26, 1.64), 0, 1.6, -0.02, fabric, mat)
	local backHeight = if s.highBack then 2.5 else 1.85
	box(b, "Spine", Vector3.new(0.3, 0.9, 0.12), 0, 1.75, 0.82, frame, M.Metal, rotX(-8))
	box(b, "Back", Vector3.new(1.62, backHeight, 0.24), 0, 1.72 + backHeight / 2 + 0.12, 0.9, fabric, mat, rotX(-9))
	if s.highBack then
		box(b, "Headrest", Vector3.new(1.1, 0.5, 0.26), 0, 1.72 + backHeight + 0.5, 1.05, fabric, mat, rotX(-9))
	end
	if s.arms ~= false then
		for _, side in ipairs({ -1, 1 }) do
			box(b, "ArmPost", Vector3.new(0.1, 0.62, 0.14), side * 0.9, 1.95, 0.25, frame, M.Metal)
			box(b, "ArmPad", Vector3.new(0.2, 0.1, 0.95), side * 0.9, 2.3, 0.1, P.LeatherBlack, M.Rubber)
		end
	end
	collider(b, Vector3.new(1.6, 1.9, 1.6), 0, 0.95, 0)
	return finish(b)
end

-- A four-legged visitor / meeting chair.
function PropKit.sideChair(parent: Instance, at: CFrame, style: ChairStyle?): Model
	local s: ChairStyle = style or {}
	local b = begin(parent, "SideChair", at * rotY(s.yaw or 0))
	local fabric = s.upholstery or P.Fabric
	local frame = s.frame or P.Charcoal
	for _, x in ipairs({ -0.68, 0.68 }) do
		for _, z in ipairs({ -0.62, 0.62 }) do
			box(b, "Leg", Vector3.new(0.1, 1.5, 0.1), x, 0.75, z, frame, M.Metal)
		end
	end
	box(b, "Seat", Vector3.new(1.6, 0.24, 1.5), 0, 1.6, 0, fabric, s.material or M.Fabric)
	box(b, "Back", Vector3.new(1.55, 1.4, 0.18), 0, 2.55, 0.72, fabric, s.material or M.Fabric, rotX(-6))
	for _, x in ipairs({ -0.68, 0.68 }) do
		box(b, "BackPost", Vector3.new(0.08, 1.2, 0.08), x, 2.25, 0.7, frame, M.Metal, rotX(-6))
	end
	collider(b, Vector3.new(1.6, 1.8, 1.5), 0, 0.9, 0)
	return finish(b)
end

-- A two- or three-seat sofa.
function PropKit.sofa(parent: Instance, at: CFrame, width: number, color: Color3?, material: Enum.Material?): Model
	local b = begin(parent, "Sofa", at)
	local c = color or P.Fabric
	local mat = material or M.Fabric
	local depth = 2.9
	box(b, "Base", Vector3.new(width, 0.9, depth), 0, 0.75, 0, c, mat)
	local seats = if width > 6 then 3 else 2
	local seatW = (width - 1.2) / seats
	for i = 1, seats do
		local x = -width / 2 + 0.6 + seatW * (i - 0.5)
		box(b, "Cushion", Vector3.new(seatW - 0.06, 0.42, depth - 0.8), x, 1.4, -0.3, c, mat)
		box(b, "BackCushion", Vector3.new(seatW - 0.06, 1.3, 0.55), x, 2.1, 0.95, c, mat, rotX(-10))
	end
	box(b, "Back", Vector3.new(width, 1.9, 0.45), 0, 1.7, 1.22, c, mat)
	for _, side in ipairs({ -1, 1 }) do
		box(b, "Arm", Vector3.new(0.6, 1.5, depth), side * (width / 2 - 0.3), 1.2, 0, c, mat)
		for _, z in ipairs({ -1.25, 1.25 }) do
			box(b, "Foot", Vector3.new(0.18, 0.3, 0.18), side * (width / 2 - 0.25), 0.15, z, P.WalnutDark, M.Wood)
		end
	end
	collider(b, Vector3.new(width, 2.4, depth), 0, 1.2, 0)
	return finish(b)
end

function PropKit.armchair(parent: Instance, at: CFrame, color: Color3?): Model
	local b = begin(parent, "Armchair", at)
	local c = color or P.FabricWarm
	box(b, "Base", Vector3.new(2.5, 0.9, 2.6), 0, 0.75, 0, c, M.Fabric)
	box(b, "Cushion", Vector3.new(1.7, 0.4, 1.9), 0, 1.38, -0.25, c, M.Fabric)
	box(b, "Back", Vector3.new(2.5, 1.8, 0.45), 0, 1.7, 1.08, c, M.Fabric, rotX(-6))
	for _, side in ipairs({ -1, 1 }) do
		box(b, "Arm", Vector3.new(0.4, 1.35, 2.6), side * 1.05, 1.15, 0, c, M.Fabric)
		for _, z in ipairs({ -1.1, 1.1 }) do
			box(b, "Foot", Vector3.new(0.16, 0.3, 0.16), side * 1.05, 0.15, z, P.WalnutDark, M.Wood)
		end
	end
	collider(b, Vector3.new(2.5, 2.4, 2.6), 0, 1.2, 0)
	return finish(b)
end

--------------------------------------------------------------------------
-- Tables & desks
--------------------------------------------------------------------------

-- Monitor on a stand. `state` "off" (black glass), "lock" (a dim lock
-- screen), or "on" (a working screen with lines of content).
function PropKit.monitor(parent: Instance, at: CFrame, state: ("off" | "lock" | "on")?, caption: string?): Model
	local b = begin(parent, "Monitor", at)
	box(b, "Foot", Vector3.new(0.75, 0.05, 0.5), 0, 0.025, 0.05, P.Charcoal, M.Metal)
	box(b, "Neck", Vector3.new(0.14, 0.72, 0.1), 0, 0.4, 0.14, P.Charcoal, M.Metal)
	local bezel = box(b, "Bezel", Vector3.new(2.25, 1.32, 0.08), 0, 1.06, 0.05, P.LeatherBlack, M.SmoothPlastic)
	bezel.CastShadow = true
	local mode = state or "off"
	local screen = box(b, "Screen", Vector3.new(2.1, 1.17, 0.02), 0, 1.07, 0.0, P.Screen, M.Glass)
	screen.Reflectance = 0.06
	if mode ~= "off" then
		screen.Material = M.Neon
		screen.Color = if mode == "lock" then Color3.fromRGB(18, 26, 40) else Color3.fromRGB(30, 46, 66)
		local text = caption or (if mode == "lock" then "ROZARIO & LIM\n\nLocked" else "")
		label(screen, Enum.NormalId.Front, text, {
			color = Color3.fromRGB(150, 176, 210),
			font = Enum.Font.GothamMedium,
			pixelsPerStud = 60,
			size = 11,
			lightInfluence = 0,
		})
	end
	return finish(b)
end

export type DeskOptions = {
	width: number?,
	depth: number?,
	top: Color3?,
	topMaterial: Enum.Material?,
	frame: Color3?,
	monitors: number?,
	screen: ("off" | "lock" | "on")?,
	chair: boolean?,
	chairYaw: number?,
	chairPushed: number?,
	clutter: number?, -- seed for the small things people leave behind
	lamp: boolean?,
	lampOn: boolean?,
}

-- A workstation: desktop on panel legs, modesty panel, monitor(s),
-- keyboard and mouse, an office chair, and a few personal things.
function PropKit.desk(parent: Instance, at: CFrame, options: DeskOptions?): Model
	local o: DeskOptions = options or {}
	local w = o.width or 4.8
	local d = o.depth or 2.4
	local topY = 2.6
	local b = begin(parent, "Desk", at)
	local frame = o.frame or P.Charcoal
	box(b, "Top", Vector3.new(w, 0.12, d), 0, topY - 0.06, 0, o.top or P.Oak, o.topMaterial or M.Wood)
	for _, side in ipairs({ -1, 1 }) do
		box(b, "Leg", Vector3.new(0.12, topY - 0.12, d - 0.3), side * (w / 2 - 0.25), (topY - 0.12) / 2, 0, frame, M.Metal)
		box(b, "Foot", Vector3.new(0.3, 0.08, d - 0.1), side * (w / 2 - 0.25), 0.04, 0, frame, M.Metal)
	end
	box(b, "Modesty", Vector3.new(w - 0.6, 1.1, 0.06), 0, topY - 0.75, d / 2 - 0.25, frame, M.Metal)
	collider(b, Vector3.new(w, topY, d), 0, topY / 2, 0)

	local monitors = o.monitors or 1
	for i = 1, monitors do
		local x = if monitors == 1 then 0 else (i - 1.5) * 2.3
		local yaw = if monitors == 1 then 0 else (i - 1.5) * -16
		PropKit.monitor(b.model, b.at * CFrame.new(x, topY, d / 2 - 0.55) * rotY(yaw), o.screen)
	end
	box(b, "Keyboard", Vector3.new(1.35, 0.05, 0.42), -0.1, topY + 0.03, -0.15, P.Graphite, M.SmoothPlastic)
	box(b, "Keys", Vector3.new(1.25, 0.02, 0.32), -0.1, topY + 0.065, -0.15, P.LeatherBlack, M.SmoothPlastic)
	box(b, "Mouse", Vector3.new(0.2, 0.07, 0.32), 0.85, topY + 0.035, -0.15, P.Graphite, M.SmoothPlastic)

	if o.lamp then
		PropKit.deskLamp(b.model, b.at * CFrame.new(-w / 2 + 0.55, topY, d / 2 - 0.45), o.lampOn == true)
	end
	if o.clutter then
		local r = rng(o.clutter)
		-- A mug, a paper stack, sometimes a plant or a photo.
		if r:NextNumber() < 0.75 then
			PropKit.mug(b.model, b.at * CFrame.new(w / 2 - 0.6, topY, -0.35 + r:NextNumber(-0.2, 0.3)), nil)
		end
		if r:NextNumber() < 0.8 then
			PropKit.paperStack(b.model, b.at * CFrame.new(-w / 2 + 0.8, topY, -0.2) * rotY(r:NextNumber(-15, 15)), r:NextInteger(2, 7))
		end
		if r:NextNumber() < 0.4 then
			PropKit.plant(b.model, b.at * CFrame.new(w / 2 - 0.45, topY, d / 2 - 0.4), 0.35, "bush")
		elseif r:NextNumber() < 0.5 then
			local frameP = box(b, "PhotoFrame", Vector3.new(0.5, 0.4, 0.05), w / 2 - 0.5, topY + 0.2, d / 2 - 0.35, P.WalnutDark, M.Wood, rotX(-12) * rotY(-20))
			frameP.CastShadow = false
		end
	end

	if o.chair ~= false then
		local pushed = o.chairPushed or 0
		PropKit.officeChair(parent, at * CFrame.new(0, 0, -(d / 2 + 1.0 + pushed)) * rotY(180), {
			yaw = o.chairYaw or 0,
		})
	end
	return finish(b)
end

-- A meeting table on two pedestal bases.
function PropKit.meetingTable(parent: Instance, at: CFrame, width: number, depth: number): Model
	local b = begin(parent, "MeetingTable", at)
	local topY = 2.6
	box(b, "Top", Vector3.new(width, 0.16, depth), 0, topY - 0.08, 0, P.Walnut, M.Wood)
	box(b, "Edge", Vector3.new(width + 0.04, 0.05, depth + 0.04), 0, topY - 0.19, 0, P.Charcoal, M.Metal)
	for _, x in ipairs({ -width / 3, width / 3 }) do
		box(b, "Pedestal", Vector3.new(0.5, topY - 0.3, 0.5), x, (topY - 0.3) / 2 + 0.1, 0, P.Charcoal, M.Metal)
		box(b, "Plate", Vector3.new(1.6, 0.1, depth * 0.6), x, 0.05, 0, P.Charcoal, M.Metal)
	end
	box(b, "PowerHatch", Vector3.new(1.0, 0.02, 0.4), 0, topY + 0.01, 0, P.SteelDark, M.Metal)
	collider(b, Vector3.new(width, topY, depth), 0, topY / 2, 0)
	return finish(b)
end

-- Low table for a lounge.
function PropKit.coffeeTable(parent: Instance, at: CFrame, width: number, depth: number): Model
	local b = begin(parent, "CoffeeTable", at)
	box(b, "Top", Vector3.new(width, 0.12, depth), 0, 1.2, 0, P.Oak, M.Wood)
	box(b, "Shelf", Vector3.new(width - 0.3, 0.06, depth - 0.3), 0, 0.35, 0, P.Charcoal, M.Metal)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			box(b, "Leg", Vector3.new(0.1, 1.14, 0.1), x * (width / 2 - 0.12), 0.57, z * (depth / 2 - 0.12), P.Charcoal, M.Metal)
		end
	end
	collider(b, Vector3.new(width, 1.26, depth), 0, 0.63, 0)
	return finish(b)
end

-- A standing-height breakout table.
function PropKit.highTable(parent: Instance, at: CFrame, width: number, depth: number): Model
	local b = begin(parent, "HighTable", at)
	local topY = 3.5
	box(b, "Top", Vector3.new(width, 0.12, depth), 0, topY - 0.06, 0, P.Oak, M.Wood)
	for _, x in ipairs({ -width / 2 + 0.4, width / 2 - 0.4 }) do
		box(b, "Leg", Vector3.new(0.16, topY - 0.12, 0.16), x, (topY - 0.12) / 2, 0, P.Charcoal, M.Metal)
		box(b, "Foot", Vector3.new(0.16, 0.08, depth - 0.3), x, 0.04, 0, P.Charcoal, M.Metal)
	end
	box(b, "Rail", Vector3.new(width - 0.8, 0.1, 0.1), 0, 0.9, 0, P.Charcoal, M.Metal)
	collider(b, Vector3.new(width, topY, depth), 0, topY / 2, 0)
	return finish(b)
end

function PropKit.stool(parent: Instance, at: CFrame, color: Color3?): Model
	local b = begin(parent, "Stool", at)
	post(b, "Seat", 0.18, 1.0, 0, 2.6, 0, color or P.FabricWarm, M.Leather)
	post(b, "Column", 2.4, 0.14, 0, 1.3, 0, P.Charcoal, M.Metal)
	post(b, "FootRing", 0.06, 0.8, 0, 0.9, 0, P.Charcoal, M.Metal)
	post(b, "Base", 0.06, 0.9, 0, 0.03, 0, P.Charcoal, M.Metal)
	collider(b, Vector3.new(0.9, 2.7, 0.9), 0, 1.35, 0)
	return finish(b)
end

-- A slatted bench.
function PropKit.bench(parent: Instance, at: CFrame, width: number): Model
	local b = begin(parent, "Bench", at)
	for i = 0, 4 do
		box(b, "Slat", Vector3.new(width, 0.12, 0.26), 0, 1.5, -0.62 + i * 0.31, P.Oak, M.Wood)
	end
	for _, x in ipairs({ -width / 2 + 0.3, width / 2 - 0.3 }) do
		box(b, "Frame", Vector3.new(0.14, 1.45, 1.5), x, 0.72, 0, P.Charcoal, M.Metal)
	end
	collider(b, Vector3.new(width, 1.6, 1.6), 0, 0.8, 0)
	return finish(b)
end

-- A long planter box with shrubs.
function PropKit.planter(parent: Instance, at: CFrame, length: number): Model
	local b = begin(parent, "Planter", at)
	box(b, "Box", Vector3.new(length, 1.6, 1.4), 0, 0.8, 0, P.Charcoal, M.Concrete)
	box(b, "Soil", Vector3.new(length - 0.2, 0.05, 1.2), 0, 1.58, 0, P.Soil, M.Ground)
	local count = math.max(2, math.floor(length / 1.1))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * (length / count)
		ball(b, "Shrub", 1.1, x, 2.1, (i % 2) * 0.2 - 0.1, if i % 2 == 0 then P.LeafDark else P.Leaf, M.LeafyGrass)
		ball(b, "Shrub", 0.8, x + 0.3, 2.5, -0.1, P.Leaf, M.LeafyGrass)
	end
	collider(b, Vector3.new(length, 1.6, 1.4), 0, 0.8, 0)
	return finish(b)
end

--------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------

export type ShelvingOptions = { frame: Color3?, material: Enum.Material?, depth: number?, sparse: boolean? }

-- Open shelving with binders, boxes and books, filled deterministically.
function PropKit.shelving(
	parent: Instance,
	at: CFrame,
	width: number,
	height: number,
	levels: number,
	seed: number,
	options: ShelvingOptions?
): Model
	local o: ShelvingOptions = options or {}
	local b = begin(parent, "Shelving", at)
	local depth = o.depth or 1.2
	local frame = o.frame or P.Charcoal
	local mat = o.material or M.Metal
	for _, side in ipairs({ -1, 1 }) do
		box(b, "Side", Vector3.new(0.1, height, depth), side * (width / 2 - 0.05), height / 2, 0, frame, mat)
	end
	box(b, "Back", Vector3.new(width, height, 0.06), 0, height / 2, depth / 2 - 0.03, frame, mat)
	local r = rng(seed)
	local binderColors = {
		Color3.fromRGB(44, 58, 86),
		Color3.fromRGB(120, 34, 38),
		Color3.fromRGB(38, 40, 44),
		Color3.fromRGB(196, 190, 176),
		Color3.fromRGB(64, 84, 70),
	}
	local gap = (height - 0.2) / levels
	for level = 0, levels do
		local y = 0.1 + level * gap
		box(b, "Shelf", Vector3.new(width - 0.2, 0.08, depth - 0.06), 0, y, 0, frame, mat)
		if level < levels then
			local x = -width / 2 + 0.2
			while x < width / 2 - 0.5 do
				local roll = r:NextNumber()
				if o.sparse and roll < 0.35 then
					x += r:NextNumber(0.4, 1.0)
				elseif roll < 0.55 then
					-- A run of binders.
					local count = r:NextInteger(3, 8)
					local color = binderColors[r:NextInteger(1, #binderColors)]
					for _ = 1, count do
						if x > width / 2 - 0.4 then
							break
						end
						local bh = math.min(gap - 0.25, 1.15)
						local binder = box(b, "Binder", Vector3.new(0.26, bh, depth - 0.35), x + 0.13, y + 0.04 + bh / 2, 0.05, color, M.SmoothPlastic)
						binder.CastShadow = false
						local spine = box(b, "Spine", Vector3.new(0.2, 0.18, 0.02), x + 0.13, y + bh * 0.72, -(depth - 0.35) / 2 + 0.04, P.Paper, M.SmoothPlastic)
						spine.CastShadow = false
						x += 0.28
					end
				elseif roll < 0.8 then
					-- An archive box.
					local bw = r:NextNumber(0.9, 1.3)
					local bh = math.min(gap - 0.3, r:NextNumber(0.6, 0.9))
					box(b, "Box", Vector3.new(bw, bh, depth - 0.25), x + bw / 2, y + 0.04 + bh / 2, 0.0, Color3.fromRGB(176, 150, 112), M.Cardboard)
					x += bw + 0.08
				else
					-- A small stack of books lying flat.
					local count = r:NextInteger(2, 4)
					for i = 1, count do
						local book = box(
							b,
							"Book",
							Vector3.new(0.75, 0.12, 0.95),
							x + 0.4,
							y + 0.1 + (i - 1) * 0.12,
							0.0,
							binderColors[r:NextInteger(1, #binderColors)],
							M.SmoothPlastic,
							rotY(r:NextNumber(-10, 10))
						)
						book.CastShadow = false
					end
					x += 0.95
				end
			end
		end
	end
	collider(b, Vector3.new(width, height, depth), 0, height / 2, 0)
	return finish(b)
end

--------------------------------------------------------------------------
-- Small things on surfaces (`at` is on the surface)
--------------------------------------------------------------------------

function PropKit.mug(parent: Instance, at: CFrame, color: Color3?, contents: Color3?): Model
	local b = begin(parent, "Mug", at)
	post(b, "Body", 0.5, 0.42, 0, 0.25, 0, color or P.Ceramic, M.SmoothPlastic)
	post(b, "Coffee", 0.02, 0.34, 0, 0.44, 0, contents or Color3.fromRGB(40, 26, 18), M.SmoothPlastic)
	box(b, "Handle", Vector3.new(0.07, 0.3, 0.18), 0.25, 0.27, 0, color or P.Ceramic, M.SmoothPlastic)
	return finish(b)
end

function PropKit.paperStack(parent: Instance, at: CFrame, sheets: number): Model
	local b = begin(parent, "Papers", at)
	for i = 1, sheets do
		local sheet = box(b, "Sheet", Vector3.new(0.85, 0.02, 1.1), 0, 0.01 + (i - 1) * 0.022, 0, P.Paper, M.SmoothPlastic, rotY((i % 3 - 1) * 4))
		sheet.CastShadow = false
	end
	return finish(b)
end

function PropKit.deskLamp(parent: Instance, at: CFrame, on: boolean): Model
	local b = begin(parent, "DeskLamp", at)
	post(b, "Base", 0.08, 0.6, 0, 0.04, 0, P.Charcoal, M.Metal)
	box(b, "Arm1", Vector3.new(0.08, 1.1, 0.08), 0, 0.55, -0.1, P.Charcoal, M.Metal, rotX(-18))
	box(b, "Arm2", Vector3.new(0.08, 0.9, 0.08), 0, 1.2, -0.45, P.Charcoal, M.Metal, rotX(-70))
	local head = box(b, "Head", Vector3.new(0.4, 0.26, 0.5), 0, 1.3, -0.85, P.Charcoal, M.Metal, rotX(18))
	local bulb = box(b, "Bulb", Vector3.new(0.28, 0.02, 0.36), 0, 1.16, -0.87, if on then P.WarmLight else P.Ceramic, if on then M.Neon else M.SmoothPlastic, rotX(18))
	if on then
		light(head, "SpotLight", 1.6, 12, P.WarmLight, { face = Enum.NormalId.Bottom, angle = 95, shadows = true })
	end
	bulb.CastShadow = false
	return finish(b)
end

--------------------------------------------------------------------------
-- Plants
--------------------------------------------------------------------------

-- "blades": a snake plant; "bush": a leafy shrub; "tree": a tall ficus.
function PropKit.plant(parent: Instance, at: CFrame, scale: number, kind: ("blades" | "bush" | "tree")?): Model
	local b = begin(parent, "Plant", at)
	local s = scale
	local k = kind or "blades"
	local potH = 1.3 * s
	post(b, "Pot", potH, 1.25 * s, 0, potH / 2, 0, P.Charcoal, M.Concrete)
	post(b, "Rim", 0.1 * s, 1.35 * s, 0, potH, 0, P.Graphite, M.Concrete)
	post(b, "Soil", 0.05, 1.1 * s, 0, potH - 0.05, 0, P.Soil, M.Ground)
	local r = rng(math.floor(at.Position.X * 13 + at.Position.Z * 7))
	if k == "blades" then
		for i = 1, 11 do
			local angle = i * (360 / 11) + r:NextNumber(-12, 12)
			local tilt = r:NextNumber(4, 16)
			local h = r:NextNumber(1.6, 2.6) * s
			local blade = box(
				b,
				"Blade",
				Vector3.new(0.3 * s, h, 0.05),
				0,
				potH,
				0,
				if i % 3 == 0 then P.LeafDark else P.Leaf,
				M.SmoothPlastic,
				rotY(angle) * rotX(tilt) * CFrame.new(0, h / 2, 0.12 * s)
			)
			blade.CastShadow = true
		end
	elseif k == "bush" then
		for i = 1, 7 do
			local angle = math.rad(i * 51)
			local radius = r:NextNumber(0.1, 0.45) * s
			ball(
				b,
				"Foliage",
				r:NextNumber(0.7, 1.0) * s,
				math.cos(angle) * radius,
				potH + r:NextNumber(0.3, 0.8) * s,
				math.sin(angle) * radius,
				if i % 2 == 0 then P.LeafDark else P.Leaf,
				M.LeafyGrass
			)
		end
	else
		post(b, "Trunk", 3.2 * s, 0.14 * s, 0, potH + 1.6 * s, 0, P.WalnutDark, M.Wood)
		for i = 1, 12 do
			local angle = math.rad(i * 30 + r:NextNumber(-10, 10))
			local radius = r:NextNumber(0.3, 0.9) * s
			ball(
				b,
				"Foliage",
				r:NextNumber(0.8, 1.2) * s,
				math.cos(angle) * radius,
				potH + r:NextNumber(2.4, 4.0) * s,
				math.sin(angle) * radius,
				if i % 3 == 0 then P.LeafDark else P.Leaf,
				M.LeafyGrass
			)
		end
	end
	collider(b, Vector3.new(1.2 * s, 2 * s, 1.2 * s), 0, s, 0)
	return finish(b)
end

--------------------------------------------------------------------------
-- Lighting fixtures
--------------------------------------------------------------------------

-- A recessed ceiling panel. `at` is on the ceiling's underside.
function PropKit.ceilingPanel(
	parent: Instance,
	at: CFrame,
	size: Vector2,
	on: boolean,
	lightSpec: { brightness: number, range: number, color: Color3, shadows: boolean? }?
): Model
	local b = begin(parent, "CeilingPanel", at)
	box(b, "Frame", Vector3.new(size.X + 0.2, 0.06, size.Y + 0.2), 0, -0.03, 0, P.Steel, M.Metal)
	local diffuser = box(
		b,
		"Diffuser",
		Vector3.new(size.X, 0.04, size.Y),
		0,
		-0.07,
		0,
		if on then Color3.fromRGB(242, 238, 228) else Color3.fromRGB(200, 200, 198),
		if on then M.Neon else M.SmoothPlastic
	)
	diffuser.CastShadow = false
	if on and lightSpec then
		light(diffuser, "SurfaceLight", lightSpec.brightness, lightSpec.range, lightSpec.color, {
			face = Enum.NormalId.Bottom,
			angle = 115,
			shadows = lightSpec.shadows,
		})
	end
	return finish(b)
end

-- A pendant lamp hanging `drop` studs below `at` (on the ceiling).
function PropKit.pendant(
	parent: Instance,
	at: CFrame,
	drop: number,
	on: boolean,
	brightness: number?,
	range: number?,
	color: Color3?
): Model
	local b = begin(parent, "Pendant", at)
	box(b, "Cord", Vector3.new(0.04, drop, 0.04), 0, -drop / 2, 0, P.LeatherBlack, M.SmoothPlastic)
	local shade = post(b, "Shade", 0.55, 1.3, 0, -drop - 0.2, 0, P.Charcoal, M.Metal)
	local bulb = post(b, "Glow", 0.03, 1.1, 0, -drop - 0.48, 0, if on then P.WarmLight else P.Graphite, if on then M.Neon else M.SmoothPlastic)
	bulb.CastShadow = false
	if on then
		local holder = newPart(b.model, "LightSource", Vector3.new(0.2, 0.2, 0.2), at * CFrame.new(0, -drop - 0.55, 0), P.WarmLight, M.SmoothPlastic)
		holder.Transparency = 1
		holder.CastShadow = false
		light(holder, "SpotLight", brightness or 2.2, range or 18, color or P.WarmLight, {
			face = Enum.NormalId.Bottom,
			angle = 100,
			shadows = true,
		})
		shade.CastShadow = false
	end
	return finish(b)
end

function PropKit.floorLamp(parent: Instance, at: CFrame, on: boolean): Model
	local b = begin(parent, "FloorLamp", at)
	post(b, "Base", 0.1, 1.1, 0, 0.05, 0, P.Charcoal, M.Metal)
	post(b, "Pole", 5.4, 0.1, 0, 2.75, 0, P.Charcoal, M.Metal)
	local shade = post(b, "Shade", 1.1, 1.4, 0, 5.6, 0, P.Paper, M.Fabric)
	if on then
		shade.Material = M.Neon
		shade.Color = Color3.fromRGB(255, 226, 180)
		shade.Transparency = 0.15
		light(shade, "PointLight", 0.9, 10, P.WarmLight, nil)
	end
	return finish(b)
end

--------------------------------------------------------------------------
-- Walls: signage, art, safety, windows
--------------------------------------------------------------------------

-- A framed abstract print. `at` is on the wall surface, facing the room.
function PropKit.framedArt(parent: Instance, at: CFrame, width: number, height: number, seed: number): Model
	local b = begin(parent, "Art", at)
	box(b, "Frame", Vector3.new(width, height, 0.1), 0, 0, -0.05, P.LeatherBlack, M.Wood)
	local mat = box(b, "Mat", Vector3.new(width - 0.2, height - 0.2, 0.02), 0, 0, -0.1, P.Paper, M.SmoothPlastic)
	mat.CastShadow = false
	local r = rng(seed)
	local tones = {
		Color3.fromRGB(46, 58, 80),
		Color3.fromRGB(150, 120, 86),
		Color3.fromRGB(88, 96, 104),
		Color3.fromRGB(120, 54, 48),
		Color3.fromRGB(196, 186, 164),
	}
	for i = 1, 3 do
		local bw = r:NextNumber(0.25, 0.6) * (width - 0.6)
		local bh = r:NextNumber(0.25, 0.7) * (height - 0.6)
		local block = box(
			b,
			"Block",
			Vector3.new(bw, bh, 0.02),
			r:NextNumber(-0.25, 0.25) * (width - 0.6 - bw),
			r:NextNumber(-0.25, 0.25) * (height - 0.6 - bh),
			-0.115 - i * 0.003,
			tones[r:NextInteger(1, #tones)],
			M.SmoothPlastic
		)
		block.CastShadow = false
	end
	return finish(b)
end

export type SignOptions = { plate: Color3?, color: Color3?, glow: boolean?, font: Enum.Font? }

-- A plaque/sign with text. `at` on the wall surface, facing the room.
function PropKit.sign(
	parent: Instance,
	at: CFrame,
	text: string,
	size: Vector2,
	options: SignOptions?
): Model
	local o: SignOptions = options or {}
	local b = begin(parent, "Sign", at)
	local plate = box(b, "Plate", Vector3.new(size.X, size.Y, 0.06), 0, 0, -0.03, o.plate or P.Charcoal, M.Metal)
	plate.CastShadow = false
	label(plate, Enum.NormalId.Front, text, {
		color = o.color or Color3.fromRGB(214, 190, 138),
		font = o.font or Enum.Font.GothamBold,
		lightInfluence = if o.glow then 0 else 1,
		padding = 4,
	})
	return finish(b)
end

function PropKit.exitSign(parent: Instance, at: CFrame): Model
	local b = begin(parent, "ExitSign", at)
	local body = box(b, "Body", Vector3.new(1.3, 0.5, 0.12), 0, 0, -0.06, P.Charcoal, M.SmoothPlastic)
	local face = box(b, "Face", Vector3.new(1.2, 0.4, 0.02), 0, 0, -0.13, P.ExitGreen, M.Neon)
	label(face, Enum.NormalId.Front, "KELUAR", { color = Color3.fromRGB(235, 255, 240), font = Enum.Font.GothamBlack, lightInfluence = 0 })
	light(body, "PointLight", 0.35, 5, P.ExitGreen, nil)
	face.CastShadow = false
	return finish(b)
end

function PropKit.fireExtinguisher(parent: Instance, at: CFrame): Model
	local b = begin(parent, "Extinguisher", at)
	box(b, "Bracket", Vector3.new(0.5, 0.2, 0.08), 0, 2.9, 0.1, P.Charcoal, M.Metal)
	post(b, "Body", 1.3, 0.48, 0, 2.2, -0.12, Color3.fromRGB(170, 30, 30), M.SmoothPlastic)
	post(b, "Valve", 0.25, 0.2, 0, 3.0, -0.12, P.LeatherBlack, M.Metal)
	box(b, "Hose", Vector3.new(0.06, 0.9, 0.06), 0.2, 2.35, -0.3, P.LeatherBlack, M.Rubber)
	local tag = box(b, "Sign", Vector3.new(0.7, 0.7, 0.03), 0, 3.8, 0.08, Color3.fromRGB(180, 30, 30), M.SmoothPlastic)
	label(tag, Enum.NormalId.Front, "FIRE", { color = Color3.new(1, 1, 1), font = Enum.Font.GothamBold })
	return finish(b)
end

function PropKit.wallClock(parent: Instance, at: CFrame, hour: number, minute: number): Model
	local b = begin(parent, "Clock", at)
	rod(b, "Body", 0.12, 1.6, 0, 0, -0.06, P.Charcoal, M.Metal, rotY(90))
	local face = rod(b, "Face", 0.02, 1.4, 0, 0, -0.13, P.Ceramic, M.SmoothPlastic, rotY(90))
	face.CastShadow = false
	local hourAngle = (hour % 12 + minute / 60) * 30
	local minuteAngle = minute * 6
	box(b, "Hour", Vector3.new(0.06, 0.4, 0.02), 0, 0, -0.15, P.LeatherBlack, M.SmoothPlastic, rotZ(-hourAngle) * CFrame.new(0, 0.18, 0))
	box(b, "Minute", Vector3.new(0.04, 0.6, 0.02), 0, 0, -0.16, P.LeatherBlack, M.SmoothPlastic, rotZ(-minuteAngle) * CFrame.new(0, 0.27, 0))
	return finish(b)
end

-- Horizontal blinds across a window opening, partly lowered. `at` is the
-- centre of the opening on the room side, facing into the room.
function PropKit.blinds(parent: Instance, at: CFrame, width: number, height: number, lowered: number): Model
	local b = begin(parent, "Blinds", at)
	box(b, "Headrail", Vector3.new(width, 0.2, 0.25), 0, height / 2 - 0.1, -0.15, P.Laminate, M.SmoothPlastic)
	local covered = height * lowered
	local slats = math.floor(covered / 0.32)
	for i = 1, slats do
		local slat = box(
			b,
			"Slat",
			Vector3.new(width - 0.1, 0.04, 0.26),
			0,
			height / 2 - 0.25 - (i - 1) * 0.32,
			-0.15,
			P.Laminate,
			M.SmoothPlastic,
			rotX(-35)
		)
		slat.CastShadow = true
	end
	box(b, "BottomRail", Vector3.new(width - 0.05, 0.08, 0.28), 0, height / 2 - 0.25 - slats * 0.32, -0.15, P.Laminate, M.SmoothPlastic)
	return finish(b)
end

--------------------------------------------------------------------------
-- Appliances & office equipment
--------------------------------------------------------------------------

function PropKit.copier(parent: Instance, at: CFrame): Model
	local b = begin(parent, "Copier", at)
	box(b, "Base", Vector3.new(2.3, 2.2, 1.9), 0, 1.1, 0, P.Laminate, M.SmoothPlastic)
	box(b, "Trays", Vector3.new(2.1, 1.3, 0.05), 0, 0.9, -0.96, Color3.fromRGB(190, 188, 182), M.SmoothPlastic)
	box(b, "Top", Vector3.new(2.3, 0.7, 1.9), 0, 2.55, 0, Color3.fromRGB(200, 198, 192), M.SmoothPlastic)
	box(b, "Lid", Vector3.new(2.0, 0.12, 1.6), 0, 2.96, 0.05, P.Graphite, M.SmoothPlastic)
	local panel = box(b, "Panel", Vector3.new(0.9, 0.08, 0.45), 0.55, 2.95, -0.75, P.Graphite, M.SmoothPlastic, rotX(18))
	local screen = box(b, "Screen", Vector3.new(0.55, 0.02, 0.3), 0.55, 3.0, -0.76, Color3.fromRGB(40, 90, 120), M.Neon, rotX(18))
	screen.CastShadow = false
	panel.CastShadow = false
	PropKit.paperStack(b.model, b.at * CFrame.new(-0.4, 3.02, 0), 3)
	collider(b, Vector3.new(2.3, 3, 1.9), 0, 1.5, 0)
	return finish(b)
end

function PropKit.waterCooler(parent: Instance, at: CFrame): Model
	local b = begin(parent, "WaterCooler", at)
	box(b, "Body", Vector3.new(1.1, 3.0, 1.1), 0, 1.5, 0, P.Laminate, M.SmoothPlastic)
	box(b, "Tap", Vector3.new(0.3, 0.3, 0.12), 0, 2.4, -0.58, P.Graphite, M.SmoothPlastic)
	local bottle = post(b, "Bottle", 1.5, 0.95, 0, 3.8, 0, Color3.fromRGB(150, 196, 220), M.Glass)
	bottle.Transparency = 0.45
	collider(b, Vector3.new(1.1, 4.5, 1.1), 0, 2.25, 0)
	return finish(b)
end

function PropKit.bin(parent: Instance, at: CFrame, color: Color3?): Model
	local b = begin(parent, "Bin", at)
	post(b, "Body", 1.2, 0.85, 0, 0.6, 0, color or P.Graphite, M.Metal)
	post(b, "Liner", 0.02, 0.8, 0, 1.2, 0, P.LeatherBlack, M.Plastic)
	return finish(b)
end

function PropKit.coatRack(parent: Instance, at: CFrame, coat: Color3?): Model
	local b = begin(parent, "CoatRack", at)
	post(b, "Base", 0.1, 1.2, 0, 0.05, 0, P.Charcoal, M.Metal)
	post(b, "Pole", 5.6, 0.14, 0, 2.85, 0, P.WalnutDark, M.Wood)
	for i = 0, 3 do
		box(b, "Hook", Vector3.new(0.06, 0.06, 0.5), 0, 5.5, 0, P.Charcoal, M.Metal, rotY(i * 90) * CFrame.new(0, 0, 0.25) * rotX(-30))
	end
	if coat then
		box(b, "Coat", Vector3.new(1.2, 2.8, 0.45), 0, 4.1, 0.3, coat, M.Fabric, rotX(4))
		box(b, "Collar", Vector3.new(0.9, 0.3, 0.5), 0, 5.45, 0.25, coat, M.Fabric)
	end
	collider(b, Vector3.new(1.0, 6, 1.0), 0, 3, 0)
	return finish(b)
end

function PropKit.umbrellaStand(parent: Instance, at: CFrame, umbrellas: { Color3 }): Model
	local b = begin(parent, "UmbrellaStand", at)
	post(b, "Body", 1.6, 0.9, 0, 0.8, 0, P.Charcoal, M.Metal)
	for i, c in ipairs(umbrellas) do
		local tilt = if i % 2 == 0 then 8 else -10
		box(b, "Umbrella", Vector3.new(0.26, 2.9, 0.26), (i - (#umbrellas + 1) / 2) * 0.22, 1.9, 0, c, M.Fabric, rotZ(tilt))
		box(b, "Handle", Vector3.new(0.1, 0.35, 0.1), (i - (#umbrellas + 1) / 2) * 0.22 - math.sin(math.rad(tilt)) * 1.5, 3.35, 0, P.WalnutDark, M.Wood)
	end
	return finish(b)
end

--------------------------------------------------------------------------
-- Kitchen
--------------------------------------------------------------------------

-- A run of base cabinets with a stone counter; `at` is the front centre
-- line on the floor, facing into the room.
function PropKit.kitchenRun(parent: Instance, at: CFrame, width: number, withSink: boolean): Model
	local b = begin(parent, "KitchenRun", at)
	local depth = 2.0
	local topY = 3.0
	box(b, "Plinth", Vector3.new(width, 0.3, depth - 0.2), 0, 0.15, 0.1, P.Charcoal, M.SmoothPlastic)
	box(b, "Carcass", Vector3.new(width, topY - 0.4, depth), 0, 0.3 + (topY - 0.4) / 2, 0, P.Laminate, M.SmoothPlastic)
	box(b, "Counter", Vector3.new(width + 0.1, 0.16, depth + 0.1), 0, topY - 0.08, 0, Color3.fromRGB(52, 54, 58), M.Granite)
	local doors = math.max(2, math.floor(width / 1.6))
	local dw = width / doors
	for i = 1, doors do
		local x = -width / 2 + dw * (i - 0.5)
		box(b, "Door", Vector3.new(dw - 0.06, topY - 0.55, 0.05), x, 0.3 + (topY - 0.45) / 2, -depth / 2 - 0.02, P.Laminate, M.SmoothPlastic)
		box(b, "Pull", Vector3.new(0.5, 0.05, 0.07), x, topY - 0.45, -depth / 2 - 0.07, P.SteelDark, M.Metal)
	end
	if withSink then
		box(b, "Sink", Vector3.new(1.4, 0.04, 1.1), width / 2 - 1.2, topY + 0.01, 0.1, P.Steel, M.Metal)
		box(b, "TapBase", Vector3.new(0.12, 0.7, 0.12), width / 2 - 1.2, topY + 0.35, 0.7, P.Steel, M.Metal)
		box(b, "Spout", Vector3.new(0.1, 0.1, 0.5), width / 2 - 1.2, topY + 0.68, 0.48, P.Steel, M.Metal)
	end
	collider(b, Vector3.new(width, topY, depth), 0, topY / 2, 0)
	return finish(b)
end

-- Wall cabinets above a run, with a warm strip light beneath.
function PropKit.wallCabinets(parent: Instance, at: CFrame, width: number, underLight: boolean): Model
	local b = begin(parent, "WallCabinets", at)
	local body = box(b, "Body", Vector3.new(width, 2.2, 1.2), 0, 1.1, 0, P.Laminate, M.SmoothPlastic)
	body.CastShadow = true
	local doors = math.max(2, math.floor(width / 1.6))
	local dw = width / doors
	for i = 1, doors do
		local x = -width / 2 + dw * (i - 0.5)
		box(b, "Door", Vector3.new(dw - 0.06, 2.1, 0.05), x, 1.1, -0.62, P.Laminate, M.SmoothPlastic)
		box(b, "Pull", Vector3.new(0.5, 0.05, 0.07), x, 0.15, -0.67, P.SteelDark, M.Metal)
	end
	if underLight then
		local strip = box(b, "StripLight", Vector3.new(width - 0.4, 0.04, 0.12), 0, -0.02, -0.35, P.WarmLight, M.Neon)
		strip.CastShadow = false
		light(strip, "SurfaceLight", 1.4, 9, P.WarmLight, { face = Enum.NormalId.Bottom, angle = 120, shadows = false })
	end
	return finish(b)
end

function PropKit.fridge(parent: Instance, at: CFrame): Model
	local b = begin(parent, "Fridge", at)
	box(b, "Body", Vector3.new(2.3, 6.0, 2.1), 0, 3.0, 0, P.Steel, M.Metal)
	box(b, "DoorSplit", Vector3.new(2.3, 0.05, 0.02), 0, 4.0, -1.06, P.SteelDark, M.Metal)
	for _, y in ipairs({ 2.6, 4.6 }) do
		box(b, "Handle", Vector3.new(0.08, 1.0, 0.12), 0.9, y, -1.12, P.SteelDark, M.Metal)
	end
	-- A note stuck on the door ("Label susu anda. TQ.": label your milk, thanks).
	local note = box(b, "Note", Vector3.new(0.5, 0.5, 0.01), -0.4, 4.8, -1.07, Color3.fromRGB(236, 224, 128), M.SmoothPlastic, rotZ(4))
	label(note, Enum.NormalId.Front, "Label susu anda. TQ.", { color = Color3.fromRGB(40, 40, 60), font = Enum.Font.PermanentMarker })
	collider(b, Vector3.new(2.3, 6, 2.1), 0, 3, 0)
	return finish(b)
end

function PropKit.microwave(parent: Instance, at: CFrame): Model
	local b = begin(parent, "Microwave", at)
	box(b, "Body", Vector3.new(1.6, 0.9, 1.1), 0, 0.45, 0, P.Graphite, M.SmoothPlastic)
	local door = box(b, "Door", Vector3.new(1.05, 0.7, 0.03), -0.2, 0.45, -0.56, P.Screen, M.Glass)
	door.Reflectance = 0.1
	local clock = box(b, "Clock", Vector3.new(0.3, 0.12, 0.02), 0.55, 0.62, -0.56, Color3.fromRGB(60, 200, 120), M.Neon)
	label(clock, Enum.NormalId.Front, "00:40", { color = Color3.fromRGB(200, 255, 220), font = Enum.Font.Code, lightInfluence = 0 })
	return finish(b)
end

function PropKit.kettle(parent: Instance, at: CFrame): Model
	local b = begin(parent, "Kettle", at)
	post(b, "Base", 0.08, 0.7, 0, 0.04, 0, P.LeatherBlack, M.SmoothPlastic)
	post(b, "Body", 0.75, 0.6, 0, 0.47, 0, P.Steel, M.Metal)
	box(b, "Handle", Vector3.new(0.08, 0.5, 0.12), 0.34, 0.6, 0, P.LeatherBlack, M.SmoothPlastic)
	return finish(b)
end

--------------------------------------------------------------------------
-- Rugs & floor dressing
--------------------------------------------------------------------------

function PropKit.rug(parent: Instance, at: CFrame, width: number, depth: number, color: Color3, border: Color3?): Model
	local b = begin(parent, "Rug", at)
	local base = box(b, "Rug", Vector3.new(width, 0.04, depth), 0, 0.02, 0, border or color, M.Fabric)
	base.CastShadow = false
	if border then
		local inner = box(b, "Field", Vector3.new(width - 0.8, 0.045, depth - 0.8), 0, 0.023, 0, color, M.Fabric)
		inner.CastShadow = false
	end
	return finish(b)
end

--------------------------------------------------------------------------
-- Doors & lifts
--------------------------------------------------------------------------

-- Lift doors with a call panel. `at` on the wall surface, facing the room.
function PropKit.liftDoors(parent: Instance, at: CFrame): (Model, BasePart)
	local b = begin(parent, "Lift", at)
	box(b, "Surround", Vector3.new(4.6, 8.4, 0.2), 0, 4.2, -0.1, P.SteelDark, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		local leaf = box(b, "Door", Vector3.new(1.95, 7.6, 0.1), side * 1.0, 3.8, -0.24, P.Steel, M.Metal)
		leaf.Reflectance = 0.12
	end
	box(b, "Seam", Vector3.new(0.03, 7.6, 0.12), 0, 3.8, -0.25, P.Charcoal, M.Metal)
	local display = box(b, "Display", Vector3.new(1.2, 0.4, 0.04), 0, 8.0, -0.22, P.Screen, M.SmoothPlastic)
	label(display, Enum.NormalId.Front, "9  ▼", { color = Color3.fromRGB(255, 170, 90), font = Enum.Font.Code, lightInfluence = 0 })
	local panel = box(b, "CallPanel", Vector3.new(0.45, 0.9, 0.06), 2.8, 3.6, -0.03, P.Steel, M.Metal)
	local button = post(b, "Button", 0.04, 0.18, 2.8, 3.6, -0.08, Color3.fromRGB(255, 196, 120), M.Neon)
	button.CFrame = b.at * CFrame.new(2.8, 3.6, -0.08) * rotY(90)
	return finish(b), panel
end

--------------------------------------------------------------------------
-- Evidence looks (OfficeRoom tags the returned body as the interactable)
--------------------------------------------------------------------------

local EVIDENCE_BUILDERS: { [string]: (b: Builder) -> BasePart } = {
	-- Tonight's badge log, fresh off the printer, squared on the counter.
	Printout = function(b)
		local sheet = box(b, "Sheet", Vector3.new(0.95, 0.03, 1.25), 0, 0.015, 0, P.Paper, M.SmoothPlastic, rotY(-6))
		sheet.CastShadow = false
		label(sheet, Enum.NormalId.Top, "AFTER-HOURS ACCESS · TINGKAT 9\n\n21:00  SECURITY  S. GURUNG\n22:28  LIM, V.    OUT\n23:04  LIM, V.    IN\n23:52  LIM, V.    OUT", {
			color = Color3.fromRGB(40, 40, 46),
			font = Enum.Font.Code,
			pixelsPerStud = 120,
			size = 9,
			xAlign = Enum.TextXAlignment.Left,
			yAlign = Enum.TextYAlignment.Top,
			padding = 8,
		})
		return sheet
	end,

	-- The pantry espresso machine, its display still showing the last brew.
	EspressoMachine = function(b)
		local body = box(b, "Body", Vector3.new(1.3, 1.5, 1.2), 0, 0.75, 0.05, P.Steel, M.Metal)
		body.Reflectance = 0.08
		box(b, "Top", Vector3.new(1.3, 0.1, 1.2), 0, 1.55, 0.05, P.Charcoal, M.Metal)
		box(b, "Tray", Vector3.new(1.0, 0.08, 0.45), 0, 0.06, -0.6, P.Charcoal, M.Metal)
		box(b, "Group", Vector3.new(0.35, 0.2, 0.3), 0, 0.95, -0.62, P.Charcoal, M.Metal)
		box(b, "Handle", Vector3.new(0.1, 0.08, 0.5), 0, 0.85, -0.85, P.LeatherBlack, M.SmoothPlastic)
		local display = box(b, "Display", Vector3.new(0.7, 0.3, 0.02), 0, 1.3, -0.56, Color3.fromRGB(20, 40, 36), M.Neon)
		label(display, Enum.NormalId.Front, "LAST 23:31\n2 × ESPRESSO", {
			color = Color3.fromRGB(150, 255, 200),
			font = Enum.Font.Code,
			pixelsPerStud = 140,
			size = 11,
			lightInfluence = 0,
		})
		display.CastShadow = false
		for _, x in ipairs({ -0.25, 0.25 }) do
			post(b, "DripCup", 0.18, 0.2, x, 0.19, -0.6, P.Ceramic, M.SmoothPlastic)
		end
		return body
	end,

	-- A small espresso cup on its saucer, half drunk.
	EspressoCup = function(b)
		post(b, "Saucer", 0.04, 0.55, 0, 0.02, 0, P.Ceramic, M.SmoothPlastic)
		local cup = post(b, "Cup", 0.28, 0.3, 0, 0.18, 0, P.Ceramic, M.SmoothPlastic)
		post(b, "Coffee", 0.02, 0.25, 0, 0.26, 0, Color3.fromRGB(38, 22, 14), M.SmoothPlastic)
		box(b, "Handle", Vector3.new(0.05, 0.14, 0.1), 0.17, 0.2, 0, P.Ceramic, M.SmoothPlastic)
		box(b, "Spoon", Vector3.new(0.04, 0.02, 0.28), -0.18, 0.05, 0.05, P.Steel, M.Metal, rotY(25))
		return cup
	end,

	-- The lobby camera monitor: four dead feeds and a sticky note.
	CameraMonitor = function(b)
		local model = PropKit.monitor(b.model, b.at, "on", "")
		local screen = model:FindFirstChild("Screen") :: BasePart
		local gui = screen:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
		gui:ClearAllChildren()
		for i = 0, 3 do
			local cell = Instance.new("TextLabel")
			cell.Size = UDim2.new(0.5, -3, 0.5, -3)
			cell.Position = UDim2.new((i % 2) * 0.5, 2, math.floor(i / 2) * 0.5, 2)
			cell.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
			cell.BorderSizePixel = 0
			cell.Text = `CAM {i + 1}\nNO SIGNAL`
			cell.TextColor3 = Color3.fromRGB(170, 190, 220)
			cell.Font = Enum.Font.Code
			cell.TextSize = 12
			cell.Parent = gui
		end
		local note = newPart(model, "StickyNote", Vector3.new(0.55, 0.55, 0.01), b.at * CFrame.new(0.72, 1.62, -0.03) * rotZ(-5), Color3.fromRGB(240, 226, 120), M.SmoothPlastic)
		note.CastShadow = false
		label(note, Enum.NormalId.Front, "Don't call the contractor out. Next week.\n— V.L.", {
			color = Color3.fromRGB(30, 30, 60),
			font = Enum.Font.PermanentMarker,
			pixelsPerStud = 200,
			padding = 6,
		})
		return model:FindFirstChild("Bezel") :: BasePart
	end,
}

-- Builds the look for a clue (`style` from EvidenceDefinition.propPlacement)
-- and returns it with the part that should carry the Interactable contract.
function PropKit.evidence(style: string, parent: Instance, at: CFrame): (Model, BasePart)
	local builder = EVIDENCE_BUILDERS[style]
	local b = begin(parent, style, at)
	if not builder then
		local fallback = box(b, "Panel", Vector3.new(1, 1, 0.2), 0, 0.5, 0, P.Graphite, M.Metal)
		return finish(b), fallback
	end
	local body = builder(b)
	return finish(b), body
end

return PropKit
