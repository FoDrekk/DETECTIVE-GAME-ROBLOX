--!strict
--[[
	SetKit (Phase 5.5)
	What every scene set is built from: parts with Roblox's built-in materials
	(no third-party models, no asset ids), self-lit signs, small lights, rain, and
	the investigator's own avatar as a stand-in you can pose.

	Everything here is client-side scenery, seen for a few seconds through a
	camera the scene controls, so it follows two rules the office doesn't:
	  * nothing collides, touches or answers a ray: the parts are only ever looked at;
	  * detail goes where the camera goes. A set is authored against its shots.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SetKit = {}

SetKit.M = Enum.Material

--------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------

-- Everything a set starts that isn't a part parented under its folder: tweens,
-- connections, threads, and changes to the world (a function that undoes them).
export type Scope = {
	add: (item: any) -> any,
	clean: () -> (),
}

function SetKit.scope(): Scope
	local items: { any } = {}
	return {
		add = function(item: any): any
			table.insert(items, item)
			return item
		end,
		clean = function()
			for index = #items, 1, -1 do
				local item = items[index]
				local kind = typeof(item)
				if kind == "RBXScriptConnection" then
					item:Disconnect()
				elseif kind == "thread" then
					pcall(task.cancel, item)
				elseif kind == "function" then
					pcall(item)
				elseif kind == "Instance" then
					if item:IsA("TweenBase") then
						item:Cancel()
					else
						item:Destroy()
					end
				end
			end
			table.clear(items)
		end,
	}
end

--------------------------------------------------------------------------
-- Parts
--------------------------------------------------------------------------

export type PartOptions = {
	transparency: number?,
	reflectance: number?,
	castShadow: boolean?,
	shape: Enum.PartType?,
}

function SetKit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	options: PartOptions?
): Part
	local o: PartOptions = options or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	if o.shape then
		p.Shape = o.shape
	end
	if o.castShadow ~= nil then
		p.CastShadow = o.castShadow
	else
		-- Small details don't cast shadows (cheap, and avoids shadow acne).
		p.CastShadow = size.X * size.Y * size.Z > 0.35 and math.max(size.X, size.Y, size.Z) > 1
	end
	p.Parent = parent
	return p
end

function SetKit.ball(parent: Instance, name: string, diameter: number, at: CFrame | Vector3, color: Color3, material: Enum.Material?, options: PartOptions?): Part
	local cf = if typeof(at) == "CFrame" then at else CFrame.new(at)
	local o: PartOptions = table.clone(options or {})
	o.shape = Enum.PartType.Ball
	return SetKit.part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material, o)
end

-- An ellipsoid: Ball parts are always spheres (their Size is forced uniform), so a
-- squashed or stretched one is a block wearing a sphere mesh.
function SetKit.ellipsoid(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, options: PartOptions?): Part
	local p = SetKit.part(parent, name, size, cframe, color, material, options)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A cylinder whose axis is the CFrame's X (Roblox's own orientation for one).
function SetKit.cylinder(parent: Instance, name: string, length: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, options: PartOptions?): Part
	local o: PartOptions = table.clone(options or {})
	o.shape = Enum.PartType.Cylinder
	return SetKit.part(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material, o)
end

-- A cylinder standing upright, centred at `position`.
function SetKit.pillar(parent: Instance, name: string, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?, options: PartOptions?): Part
	return SetKit.cylinder(parent, name, height, diameter, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, options)
end

-- A cylinder from one point to another.
function SetKit.rod(parent: Instance, name: string, diameter: number, a: Vector3, b: Vector3, color: Color3, material: Enum.Material?, options: PartOptions?): Part
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt(a:Lerp(b, 0.5), b) * CFrame.Angles(0, math.rad(90), 0)
	return SetKit.cylinder(parent, name, math.max(length, 0.01), diameter, cf, color, material, options)
end

-- A self-lit part (a sign tube, a window, a screen edge).
function SetKit.neon(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, options: PartOptions?): Part
	local o: PartOptions = table.clone(options or {})
	o.castShadow = false
	return SetKit.part(parent, name, size, cframe, color, Enum.Material.Neon, o)
end

--------------------------------------------------------------------------
-- Light and text
--------------------------------------------------------------------------

export type LightOptions = { face: Enum.NormalId?, angle: number?, shadows: boolean? }

function SetKit.light(part: BasePart, kind: "PointLight" | "SpotLight" | "SurfaceLight", brightness: number, range: number, color: Color3?, options: LightOptions?): Light
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
	l.Color = color or Color3.new(1, 1, 1)
	l.Shadows = options ~= nil and options.shadows == true
	l.Parent = part
	return l
end

export type LabelOptions = {
	color: Color3?,
	font: Enum.Font?,
	scaled: boolean?,
	size: number?,
	pixelsPerStud: number?,
	-- 0 is self-lit (a screen, a sign); 1 lets the room's light fall on it.
	lightInfluence: number?,
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	background: Color3?,
	padding: number?,
	richText: boolean?,
	lineHeight: number?,
}

-- Text on a part's face. Returns the label so a set can change it later.
function SetKit.label(part: BasePart, face: Enum.NormalId, text: string, options: LabelOptions?): TextLabel
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
	t.TextColor3 = o.color or Color3.fromRGB(40, 40, 46)
	t.Font = o.font or Enum.Font.GothamMedium
	t.TextScaled = o.scaled ~= false and o.size == nil
	if o.size then
		t.TextSize = o.size
	end
	t.TextWrapped = true
	t.RichText = o.richText == true
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
	return t
end

-- A lit sign: a dark panel with self-lit text on its front face (-Z) and a small
-- light so it throws colour on what stands near it. Returns the panel and label.
export type SignOptions = {
	panel: Color3?,
	font: Enum.Font?,
	pixelsPerStud: number?,
	lightRange: number?,
	lightBrightness: number?,
	richText: boolean?,
	transparency: number?,
}

function SetKit.sign(parent: Instance, name: string, cframe: CFrame, size: Vector3, text: string, color: Color3, options: SignOptions?): (Part, TextLabel)
	local o: SignOptions = options or {}
	local panel = SetKit.part(parent, name, size, cframe, o.panel or Color3.fromRGB(14, 14, 18), Enum.Material.SmoothPlastic, { castShadow = false, transparency = o.transparency })
	local label = SetKit.label(panel, Enum.NormalId.Front, text, {
		color = color,
		font = o.font or Enum.Font.GothamBold,
		lightInfluence = 0,
		pixelsPerStud = o.pixelsPerStud or 60,
		richText = o.richText,
	})
	if (o.lightRange or 0) > 0 then
		SetKit.light(panel, "SurfaceLight", o.lightBrightness or 1.2, o.lightRange :: number, color, { face = Enum.NormalId.Front, angle = 150 })
	end
	return panel, label
end

-- The stretched glint a light leaves on a wet surface: a soft neon strip laid on
-- the ground beneath (or beside) whatever shines. `length` runs along the
-- CFrame's Z, `width` along X.
function SetKit.glint(parent: Instance, name: string, cframe: CFrame, width: number, length: number, color: Color3, transparency: number?): Part
	return SetKit.neon(parent, name, Vector3.new(width, 0.04, length), cframe, color, { transparency = transparency or 0.55 })
end

-- A backdrop that glows: a large opaque plane facing the camera (its front, -Z, is
-- turned toward `cframe`'s look), painted with a vertical gradient by a
-- SurfaceGui (self-lit). Opaque on purpose: the Glass material only refracts
-- what is opaque behind it, so a see-through sky would vanish behind a window.
-- `stops` run from the TOP of the plane to the bottom.
export type GradientStop = { at: number, color: Color3 }

function SetKit.gradientSky(parent: Instance, name: string, cframe: CFrame, width: number, height: number, stops: { GradientStop }): Part
	local plane = SetKit.part(parent, name, Vector3.new(width, height, 1), cframe, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, { castShadow = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(64, 512)
	gui.LightInfluence = 0
	gui.Parent = plane
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local keypoints: { ColorSequenceKeypoint } = {}
	for _, stop in ipairs(stops) do
		table.insert(keypoints, ColorSequenceKeypoint.new(stop.at, stop.color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(keypoints)
	gradient.Parent = frame
	return plane
end

--------------------------------------------------------------------------
-- Towers
--------------------------------------------------------------------------

export type TowerOptions = {
	color: Color3?,
	material: Enum.Material?,
	seed: number?,
	-- Chance a window is lit (the rest are dark glass, or nothing).
	litChance: number?,
	-- Which faces have windows: "north" (-Z), "south" (+Z), "east" (+X), "west" (-X).
	faces: { string }?,
	-- Draw unlit windows too (dark glass), so a near facade reads as a building.
	facade: boolean?,
	warm: Color3?,
	cool: Color3?,
	coolChance: number?,
	-- Window size scale (a far tower's windows are drawn larger so they still read).
	scale: number?,
	-- A row that is lit in every window (a floor still at work), counted from the ground.
	litRow: number?,
}

local WARM = Color3.fromRGB(255, 206, 140)
local COOL = Color3.fromRGB(176, 204, 255)
local UNLIT = Color3.fromRGB(30, 36, 52)

local FACES = {
	north = { normal = Vector3.new(0, 0, -1), right = Vector3.new(-1, 0, 0), axis = "x" },
	south = { normal = Vector3.new(0, 0, 1), right = Vector3.new(1, 0, 0), axis = "x" },
	east = { normal = Vector3.new(1, 0, 0), right = Vector3.new(0, 0, -1), axis = "z" },
	west = { normal = Vector3.new(-1, 0, 0), right = Vector3.new(0, 0, 1), axis = "z" },
}

--[[
	A tower standing on the ground at `base` (the centre of its footprint), with a
	grid of windows on the faces asked for. Deterministic for a given seed. Returns
	the body and how many windows are lit.
]]
function SetKit.tower(parent: Instance, name: string, base: Vector3, width: number, depth: number, height: number, options: TowerOptions?): (Part, number)
	local o: TowerOptions = options or {}
	local body = SetKit.part(parent, name, Vector3.new(width, height, depth), CFrame.new(base + Vector3.new(0, height / 2, 0)), o.color or Color3.fromRGB(24, 26, 34), o.material or Enum.Material.Concrete, { castShadow = false })
	local rng = Random.new(o.seed or 1)
	local scale = o.scale or 1
	local windowW, windowH = 1.1 * scale, 1.3 * scale
	local stepX, stepY = 2.2 * scale, 2.8 * scale
	local lit = 0
	local warm, cool = o.warm or WARM, o.cool or COOL
	for _, faceName in ipairs(o.faces or { "south" }) do
		local face = FACES[faceName]
		if face then
			local span = if face.axis == "x" then width else depth
			local offset = if face.axis == "x" then depth / 2 else width / 2
			local columns = math.max(math.floor((span - 2) / stepX), 1)
			local rows = math.max(math.floor((height - 4) / stepY), 1)
			for row = 0, rows - 1 do
				local y = base.Y + 3 + row * stepY
				for column = 0, columns - 1 do
					local along = (column - (columns - 1) / 2) * stepX
					local isLit = rng:NextNumber() < (o.litChance or 0.2) or (o.litRow ~= nil and row == o.litRow)
					if isLit or o.facade then
						local color = UNLIT
						if isLit then
							color = if rng:NextNumber() < (o.coolChance or 0.25) then cool else warm
							color = color:Lerp(Color3.new(0, 0, 0), 1 - (0.55 + rng:NextNumber() * 0.45))
							lit += 1
						end
						local position = Vector3.new(base.X, y, base.Z) + face.normal * (offset + 0.06) + face.right * along
						SetKit.neon(body, "Window", Vector3.new(windowW, windowH, 0.1), CFrame.lookAt(position, position + face.normal), color)
					end
				end
			end
		end
	end
	return body, lit
end

--------------------------------------------------------------------------
-- Motion
--------------------------------------------------------------------------

-- Tween any instance's properties and start it. The caller keeps the Tween if it
-- means to cancel it (or hands it to a Scope).
function SetKit.tween(target: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(target, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), goal)
	tween:Play()
	return tween
end

-- A named set action starts its movement later. Keep its tween dormant until
-- that action is called; `tween` above remains the convenient immediate form.
function SetKit.newTween(target: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	return TweenService:Create(target, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), goal)
end

--------------------------------------------------------------------------
-- Rain
--------------------------------------------------------------------------

export type RainOptions = {
	-- Particles a second over the whole volume.
	rate: number?,
	-- Studs a second the drops fall at.
	speed: number?,
	-- How far the fall leans sideways, studs a second along +X of the volume.
	slant: number?,
	-- Drop length in studs (drawn stretched along the fall).
	length: number?,
	color: Color3?,
	transparency: number?,
}

--[[
	Rain falling through a volume: an invisible plate `size` wide, its CFrame the
	centre of the top of the volume; drops fall for `depth` studs.
]]
function SetKit.rain(parent: Instance, cframe: CFrame, size: Vector3, depth: number, options: RainOptions?): Part
	local o: RainOptions = options or {}
	local plate = SetKit.part(parent, "Rain", Vector3.new(size.X, 0.2, size.Z), cframe, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { transparency = 1, castShadow = false })
	local speed = o.speed or 90
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Drops"
	emitter.Rate = o.rate or 900
	emitter.Lifetime = NumberRange.new(depth / speed)
	emitter.Speed = NumberRange.new(speed)
	emitter.SpreadAngle = Vector2.new(0, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Size = NumberSequence.new(o.length or 1.3)
	emitter.Squash = NumberSequence.new(-0.94)
	emitter.Color = ColorSequence.new(o.color or Color3.fromRGB(190, 205, 225))
	emitter.Transparency = NumberSequence.new(o.transparency or 0.55)
	emitter.LightEmission = 0.35
	emitter.LightInfluence = 0.5
	emitter.Acceleration = Vector3.new(o.slant or 0, 0, 0)
	emitter.Parent = plate
	return plate
end

--------------------------------------------------------------------------
-- The investigator's double
--------------------------------------------------------------------------

export type Double = {
	model: Model,
	root: BasePart,
	-- Play an animation by asset id; returns the track (nil if it wouldn't load).
	animate: (assetId: string, looped: boolean?) -> AnimationTrack?,
	-- Pose joints by name (Motor6D.Transform) after stopping animations.
	pose: (joints: { [string]: CFrame }) -> (),
	-- Put the double's root at `cf`.
	place: (cf: CFrame) -> (),
	-- Where its root goes for it to stand with its feet at `feet` (for tweening
	-- a walk).
	rootAt: (feet: CFrame) -> CFrame,
	-- Seat it: hips on `seat` (the top of the seat, facing the way it faces).
	sitOn: (seat: CFrame) -> (),
	destroy: () -> (),
}

local IDLE_ANIMATION = "rbxassetid://507766388"
SetKit.IdleAnimation = IDLE_ANIMATION
SetKit.SitAnimation = "rbxassetid://2506281703"
SetKit.WalkAnimation = "rbxassetid://507777826"

--[[
	The player's own avatar as a stand-in the scene can place, pose and animate:
	the scenes show "you" (the warrant card's holder in the car, the detective
	stepping out, the reflection in the lift's mirror), and it has to be the
	avatar the player chose. It is a clone of their character, so the rig is
	right; only its root is anchored, so joints still move and animations play.
	It stands with its feet at `feet`, however tall the player's avatar is.
	Nil when the player has no character yet (a scene then simply goes without).
]]
function SetKit.avatarDouble(parent: Instance, feet: CFrame): Double?
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	if not clone then
		return nil
	end
	clone.Name = "Double"
	local root = clone:FindFirstChild("HumanoidRootPart")
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		clone:Destroy()
		return nil
	end
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.LocalTransparencyModifier = 0
		end
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	clone.Parent = parent
	-- An R15 root stands its legs' length (HipHeight) plus half its own height
	-- above the ground, and sits half its height above the seat.
	local standHeight = humanoid.HipHeight + root.Size.Y / 2
	local sitHeight = root.Size.Y / 2
	clone:PivotTo(feet * CFrame.new(0, standHeight, 0))

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks: { AnimationTrack } = {}

	local double: Double
	double = {
		model = clone,
		root = root,
		animate = function(assetId: string, looped: boolean?): AnimationTrack?
			local animation = Instance.new("Animation")
			animation.AnimationId = assetId
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			animation:Destroy()
			if not ok or not track then
				return nil
			end
			track.Looped = looped ~= false
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.1)
			table.insert(tracks, track)
			return track
		end,
		pose = function(joints: { [string]: CFrame })
			for _, track in ipairs(tracks) do
				track:Stop(0)
			end
			table.clear(tracks)
			for _, descendant in ipairs(clone:GetDescendants()) do
				if descendant:IsA("Motor6D") then
					local transform = joints[descendant.Name]
					if transform then
						descendant.Transform = transform
					end
				end
			end
		end,
		place = function(cf: CFrame)
			clone:PivotTo(cf)
		end,
		rootAt = function(at: CFrame): CFrame
			return at * CFrame.new(0, standHeight, 0)
		end,
		sitOn = function(seat: CFrame)
			clone:PivotTo(seat * CFrame.new(0, sitHeight, 0))
			double.animate(SetKit.SitAnimation, true)
		end,
		destroy = function()
			for _, track in ipairs(tracks) do
				pcall(function()
					track:Stop(0)
				end)
			end
			clone:Destroy()
		end,
	}
	return double
end

--[[
	The reflection of a point across the plane x = planeX, and of a direction:
	what a mirror on that plane shows of a person at `position` facing `facing`.
]]
function SetKit.reflectX(planeX: number, position: Vector3, facing: Vector3): (Vector3, Vector3)
	return Vector3.new(2 * planeX - position.X, position.Y, position.Z), Vector3.new(-facing.X, facing.Y, facing.Z)
end

--[[
	A box-like part's frame reflected across the plane x = planeX. A mirror image
	can't be a rotation, but a box is the same box with one axis negated, so the
	third axis is flipped to keep the frame right-handed. (Text and lights are not
	reflected: only the shapes.)
]]
function SetKit.reflectFrame(planeX: number, cf: CFrame): CFrame
	local p = cf.Position
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	local mx = Vector3.new(-x.X, x.Y, x.Z)
	local my = Vector3.new(-y.X, y.Y, y.Z)
	local mz = Vector3.new(z.X, -z.Y, -z.Z) -- the mirrored Z axis, negated
	return CFrame.fromMatrix(Vector3.new(2 * planeX - p.X, p.Y, p.Z), mx, my, mz)
end

-- Let go of a part after a while whatever else happens.
function SetKit.discardAfter(instance: Instance, seconds: number)
	Debris:AddItem(instance, seconds)
end

return SetKit
