--!strict
-- The investigator's car. A close, warm dashboard against a wet blue city;
-- the warrant sits ready beside a lit phone and a small dispatch display.
local SetKit = require(script.Parent:WaitForChild("SetKit"))
local Players = game:GetService("Players")
local Car = {}
local M = SetKit.M
local C = Color3.fromRGB

function Car.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): Vector3 return origin + Vector3.new(x, y, z) end
	local function part(name: string, size: Vector3, p: Vector3, color: Color3, material: Enum.Material?)
		return SetKit.part(parent, name, size, CFrame.new(p), color, material or M.SmoothPlastic, { castShadow = true })
	end
	part("CabinFloor", Vector3.new(15, 0.4, 17), at(0, 0, 0), C(23, 26, 31), M.Fabric)
	part("Roof", Vector3.new(15, 0.5, 17), at(0, 8.4, 0), C(25, 28, 34), M.Fabric)
	part("DoorLeft", Vector3.new(0.5, 3.1, 16), at(-7.2, 1.65, 0), C(36, 39, 44), M.Metal)
	part("DoorRight", Vector3.new(0.5, 3.1, 16), at(7.2, 1.65, 0), C(36, 39, 44), M.Metal)
	for _, x in ipairs({ -7.2, 7.2 }) do
		local sideGlass = part("RainGlass", Vector3.new(0.16, 3.7, 14.6), at(x, 5.05, 0), C(76, 103, 127), M.Glass)
		sideGlass.Transparency = 0.62
		sideGlass.Reflectance = 0.06
		sideGlass.CanCollide = false
		for _, z in ipairs({ -6.6, 0, 6.6 }) do
			part("WindowPillar", Vector3.new(0.25, 3.8, 0.34), at(x, 5.05, z), C(39, 44, 53), M.Metal)
		end
	end
	-- Broad windscreen angled away toward the sodium-lit street.
	local glass = part("Windscreen", Vector3.new(13, 5.5, 0.18), at(0, 5.3, -7.6), C(66, 89, 105), M.SmoothPlastic)
	glass.CFrame *= CFrame.Angles(math.rad(-8), 0, 0)
	glass.Transparency = 0.68; glass.Reflectance = 0.1; glass.CanCollide = false
	-- Wisma Delima at the end of the road, far enough off that its one lit window
	-- (level nine) sits inside the windscreen from the driver's seat.
	part("RoadsideBlock", Vector3.new(24, 18, 10), at(-30, 9, -60), C(34, 39, 49), M.Concrete)
	local tower = part("WismaDelimaSilhouette", Vector3.new(30, 62, 10), at(14, 31, -195), C(30, 39, 52), M.Concrete)
	tower.Reflectance = 0.04
	for row = 1, 9 do
		for column = 1, 5 do
			local lit = row == 9 and column == 3
			local pane = part("DistantOfficeWindow", Vector3.new(2.4, 2.7, 0.08), at(2 + column * 4.6, row * 5.9, -189.92), if lit then C(255, 194, 121) else C(20, 30, 42), if lit then M.Neon else M.Glass)
			pane.Transparency = if lit then 0 else 0.25
		end
	end
	local horizon = part("NightHorizon", Vector3.new(420, 140, 1), at(0, 60, -260), C(18, 27, 42), M.SmoothPlastic)
	horizon.CanCollide = false
	-- Street lamps along the road ahead.
	for i, x in ipairs({ -28, -8, 18, 38 }) do
		local z = -34 - i * 14
		part("LampPole", Vector3.new(0.35, 13, 0.35), at(x, 6.5, z), C(40, 42, 46), M.Metal)
		local head = SetKit.neon(parent, "LampHead", Vector3.new(1.6, 0.3, 0.8), CFrame.new(at(x, 13, z)), if i % 2 == 0 then C(255, 172, 89) else C(255, 196, 120))
		SetKit.light(head, "SpotLight", 1.6, 24, C(255, 165, 85), { face = Enum.NormalId.Bottom, angle = 110 })
	end
	-- Dashboard and a restrained pool of instrument light.
	part("Dash", Vector3.new(15, 1.5, 3.2), at(0, 2.7, -6.1), C(30, 32, 37), M.Fabric)
	local screen, screenLabel = SetKit.sign(parent, "DispatchScreen", CFrame.new(at(3.4, 3.55, -7.55)), Vector3.new(3.2, 1.8, 0.08), "UNIT 14\nROUTE: ROZARIO & LIM", C(118, 208, 225), { panel = C(9, 19, 26), pixelsPerStud = 28 })
	local screenGlow = SetKit.neon(parent, "ScreenGlow", Vector3.new(3.5, 1.9, 0.08), CFrame.new(at(3.4, 3.55, -7.62)), C(44, 151, 179))
	screenGlow.Transparency = 0.78
	local phone = SetKit.part(parent, "Phone", Vector3.new(1.45, 0.18, 2.55), CFrame.new(at(-3.25, 3.57, -5.95)) * CFrame.Angles(math.rad(-7), 0, math.rad(9)), C(20, 23, 28), M.Metal)
	local phoneScreen, phoneLabel = SetKit.sign(parent, "PhoneScreen", CFrame.new(at(-3.25, 3.68, -5.95)) * CFrame.Angles(math.rad(-7), 0, math.rad(9)), Vector3.new(1.28, 0.04, 2.25), "NORA CALLING", C(168, 224, 238), { panel = C(15, 37, 48), pixelsPerStud = 18 })
	phoneScreen.Transparency = 1
	local phoneSurface = phoneScreen:FindFirstChildOfClass("SurfaceGui")
	if phoneSurface then phoneSurface.Face = Enum.NormalId.Top end
	phoneLabel.Rotation = 180
	-- A top-face SurfaceGui lays its canvas along the part's Z, so the card is long
	-- in Z and turned a quarter to read across the dash from the driver's side.
	local warrant = SetKit.part(parent, "WarrantCard", Vector3.new(2.1, 0.12, 3.1), CFrame.new(at(4.35, 3.55, -5.4)) * CFrame.Angles(0, math.rad(-98), math.rad(1)), C(222, 215, 191), M.Cardboard)
	local investigator = Players.LocalPlayer
	local identityGui = Instance.new("SurfaceGui")
	identityGui.Name = "InvestigatorIdentity"
	identityGui.Face = Enum.NormalId.Top
	identityGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	identityGui.CanvasSize = Vector2.new(420, 270)
	identityGui.LightInfluence = 0.6
	identityGui.Parent = warrant
	local identityBack = Instance.new("Frame")
	identityBack.Size = UDim2.fromScale(1, 1)
	identityBack.BackgroundColor3 = C(222, 215, 191)
	identityBack.BorderSizePixel = 0
	identityBack.Parent = identityGui
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "InvestigatorPortrait"
	portrait.Position = UDim2.fromScale(0.04, 0.08)
	portrait.Size = UDim2.fromScale(0.31, 0.82)
	portrait.BackgroundColor3 = C(42, 55, 67)
	portrait.BorderSizePixel = 0
	portrait.ScaleType = Enum.ScaleType.Crop
	portrait.Parent = identityBack
	local identity = Instance.new("TextLabel")
	identity.Name = "InvestigatorName"
	identity.Position = UDim2.fromScale(0.39, 0.06)
	identity.Size = UDim2.fromScale(0.57, 0.88)
	identity.BackgroundTransparency = 1
	identity.Text = `JABATAN POLIS KOTA ARWANA\nUNIT KES KHAS  /  SCU\n\nINSPEKTOR\n{investigator.DisplayName}\n\nAUTHORISED ENTRY  ·  UNIT 14`
	identity.TextColor3 = C(32, 40, 47)
	identity.TextSize = 16
	identity.Font = Enum.Font.GothamBold
	identity.TextWrapped = true
	identity.TextXAlignment = Enum.TextXAlignment.Left
	identity.TextYAlignment = Enum.TextYAlignment.Center
	identity.Parent = identityBack
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(investigator.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and portrait.Parent then portrait.Image = image end
	end)
	-- Steering wheel, the driver's seat and a soft dashboard glow make the frame
	-- read as an occupied car rather than a floating collection of props. The
	-- investigator sits in it, facing the windscreen (-Z).
	SetKit.cylinder(parent, "SteeringWheel", 0.22, 2.7, CFrame.new(at(-3.3, 3.65, -3.8)) * CFrame.Angles(0, 0, math.pi / 2), C(20, 22, 25), M.Rubber)
	part("SeatBack", Vector3.new(4.6, 5.3, 1), at(-3.3, 4.4, 1.5), C(35, 37, 42), M.Leather)
	part("SeatCushion", Vector3.new(4.6, 0.8, 3.6), at(-3.3, 2.3, -0.7), C(35, 37, 42), M.Leather)
	local detective = SetKit.avatarDouble(parent, CFrame.new(at(-3.3, 0.2, 0.3)))
	if detective then
		detective.sitOn(CFrame.new(at(-3.3, 2.7, 0.3)))
		scope.add(function() detective.destroy() end)
	end
	local dashLamp = SetKit.neon(parent, "DashGlow", Vector3.new(13, 0.12, 0.35), CFrame.new(at(0, 3.53, -7.68)), C(245, 150, 75))
	dashLamp.Transparency = 1
	local dashLight = SetKit.light(dashLamp, "PointLight", 0.08, 6, C(255, 169, 103))
	dashLight.Shadows = false
	local cabinLamp = SetKit.part(parent, "CabinLamp", Vector3.new(2.5, 0.12, 1.2), CFrame.new(at(0, 8.1, 1.8)), C(255, 221, 180), M.SmoothPlastic, { transparency = 0.18, castShadow = false })
	SetKit.light(cabinLamp, "PointLight", 1.2, 18, C(255, 213, 173))
	local wipers: { BasePart } = {}
	for i, x in ipairs({ -3.5, 3.5 }) do
		local blade = part(`Wiper_{i}`, Vector3.new(0.12, 0.13, 5.6), at(x, 3.35, -7.2), C(17, 19, 23), M.Rubber)
		blade.CFrame *= CFrame.Angles(0, 0, math.rad(if i == 1 then -12 else 12))
		wipers[i] = blade
	end
	-- Rain out beyond the glass, not between the camera and it.
	local rain = SetKit.rain(parent, CFrame.new(at(0, 18, -34)), Vector3.new(60, 0.2, 36), 22, { rate = 420, speed = 60, length = 2.2, slant = -2 })
	local ring = SetKit.newTween(phoneScreen, 0.4, { Transparency = 0 }, Enum.EasingStyle.Sine)
	local answer = SetKit.newTween(phone, 0.22, { CFrame = phone.CFrame * CFrame.Angles(0, 0, math.rad(8)) }, Enum.EasingStyle.Quad)
	local wiperTweens = {}
	for i, blade in ipairs(wipers) do
		local base = blade.CFrame
		local angle = if i == 1 then math.rad(34) else math.rad(-34)
		local tw = SetKit.newTween(blade, 0.65, { CFrame = base * CFrame.Angles(0, 0, angle) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		table.insert(wiperTweens, tw)
	end
	local actions = {
		PhoneRing = function() ring:Play(); phoneLabel.Text = "SUPT. NORA\nINCOMING CALL" end,
		Answer = function() answer:Play(); phoneLabel.Text = "SUPT. NORA\nCONNECTED" end,
		WipersOn = function() for _, tw in ipairs(wiperTweens) do tw:Play() end end,
		Notify = function() screenLabel.Text = "UNIT 14\nROZARIO & LIM  ·  LEVEL 9" end,
	}
	scope.add(rain); scope.add(ring); scope.add(answer)
	for _, tw in ipairs(wiperTweens) do scope.add(tw) end
	return { act = function(name: string, _args: { [string]: any }?) local action = actions[name]; if action then action() end end, destroy = function() scope.clean() end }
end

return Car
