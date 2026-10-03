--!strict
-- Kota Arwana at street level: a wet Lorong Meranti under sodium lamps, a
-- 24-hour mamak in a row of shophouses, the LRT guideway overhead, a rider
-- waiting by the stall, and the unmarked car pulling up.
local SetKit = require(script.Parent:WaitForChild("SetKit"))
local Street = {}
local M = SetKit.M
local C = Color3.fromRGB

function Street.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end
	local function part(name: string, size: Vector3, p: Vector3, color: Color3, material: Enum.Material?)
		return SetKit.part(parent, name, size, CFrame.new(p), color, material or M.SmoothPlastic, { castShadow = true })
	end
	part("WetRoad", Vector3.new(96, 0.35, 74), at(0, 0, 0), C(31, 33, 39), M.Asphalt).Reflectance = 0.24
	for z = -32, 32, 8 do
		local streak = part("RainReflection", Vector3.new(1.1, 0.025, 8), at(-15 + ((z + 32) % 3) * 15, 0.2, z), C(123, 91, 67), M.Neon)
		streak.Transparency = 0.45
		streak.CanCollide = false
	end
	-- Shopfront and deep red awning anchor the recognizably local night stop.
	part("Shop", Vector3.new(27, 13, 8), at(-24, 6.5, -34), C(48, 43, 40), M.Concrete)
	part("ShopGlass", Vector3.new(22, 6, 0.15), at(-24, 4, -29.8), C(28, 38, 46), M.SmoothPlastic).Transparency = 0.35
	local awning = part("MamakAwning", Vector3.new(29, 0.6, 8), at(-24, 10.2, -28), C(105, 40, 34), M.Fabric)
	awning.CFrame *= CFrame.Angles(math.rad(-3), 0, 0)
	SetKit.sign(parent, "MamakSign", CFrame.new(at(-24, 12.3, -29.7)), Vector3.new(17, 2.2, 0.3), "KEDAI MAMAK 24 JAM", C(255, 203, 126), { panel = C(46, 36, 34), pixelsPerStud = 48 })
	local warm = SetKit.neon(parent, "ShopGlow", Vector3.new(17, 0.2, 0.2), CFrame.new(at(-24, 9.1, -29.5)), C(255, 175, 91))
	SetKit.light(warm, "PointLight", 1.4, 28, C(255, 160, 80))
	-- Inside, still open: strip-lit and bright behind the glass, the counter dark
	-- against it.
	local inside = SetKit.neon(parent, "ShopInterior", Vector3.new(21.6, 5.8, 0.05), CFrame.new(at(-24, 4, -29.95)), C(255, 222, 176))
	inside.Transparency = 0.45
	SetKit.light(inside, "SurfaceLight", 1.2, 16, C(255, 228, 190), { face = Enum.NormalId.Back, angle = 120 })
	part("Counter", Vector3.new(9, 2.4, 0.04), at(-28, 2.2, -29.9), C(30, 26, 24))
	-- Plastic tables and stools out on the five-foot way; the near table's glass
	-- is drawn toward the rider mid-shot.
	local stools = { C(46, 92, 160), C(170, 40, 40), C(46, 92, 160), C(214, 160, 40) }
	for index, spot in ipairs({ { -10, -17 }, { -21, -21 } }) do
		local x, z = spot[1], spot[2]
		part("TableTop", Vector3.new(7, 0.35, 4), at(x, 2.1, z), C(58, 66, 70), M.Metal)
		for _, dx in ipairs({ -2.7, 2.7 }) do
			part("TableLeg", Vector3.new(0.25, 2, 0.25), at(x + dx, 1, z), C(45, 48, 52), M.Metal)
		end
		for side = 0, 1 do
			local stool = SetKit.pillar(parent, "Stool", 1.3, 1.05, at(x - 1.8 + side * 3.6, 0.65, z + (if index == 1 then 2.8 else -2.8)), stools[index * 2 - 1 + side], M.Plastic)
			stool.CastShadow = false
		end
	end
	local glass = SetKit.pillar(parent, "TehTarik", 0.9, 0.48, at(-10.6, 2.72, -17), C(166, 104, 51), M.Glass, { transparency = 0.12 })
	part("Saucer", Vector3.new(1, 0.08, 1), at(-10.6, 2.25, -17), C(190, 185, 173), M.CeramicTiles)
	SetKit.pillar(parent, "Glass", 0.9, 0.46, at(-22, 2.72, -21.4), C(150, 82, 40), M.Glass, { transparency = 0.15 })
	SetKit.pillar(parent, "Glass", 0.9, 0.46, at(-20.2, 2.72, -20.6), C(214, 190, 150), M.Glass, { transparency = 0.15 })
	-- Rider: a dressed R15 figure in a rain jacket and helmet, waiting astride
	-- a compact bike (block figure fallback when the client cannot build one).
	part("BikeBody", Vector3.new(1.4, 1.2, 5.2), at(8, 1.45, -17), C(155, 35, 34), M.Metal)
	for _, z in ipairs({ -19.5, -14.5 }) do
		SetKit.cylinder(parent, "BikeWheel", 0.32, 1.45, CFrame.new(at(8, 0.9, z)), C(20, 22, 26), M.Rubber)
	end
	-- The bike's headlamp, left on while the rider waits: a small pool on the
	-- wet road in front of it.
	local bikeLamp = SetKit.neon(parent, "BikeHeadlamp", Vector3.new(0.7, 0.35, 0.12), CFrame.new(at(8, 1.55, -19.7)), C(235, 240, 250))
	SetKit.light(bikeLamp, "SpotLight", 1.2, 14, C(235, 240, 250), { face = Enum.NormalId.Front, angle = 55 })
	SetKit.glint(parent, "BikeGlint", CFrame.new(at(8, 0.22, -24)), 2.6, 7, C(210, 220, 240), 0.5)
	local riderSeat = CFrame.lookAt(at(8, 2.1, -17), at(8, 2.1, -18))
	local rider = SetKit.figureDouble(parent, riderSeat, {
		shirt = C(30, 76, 78),
		pants = C(24, 28, 34),
		skin = C(176, 130, 96),
		headgear = "helmet",
		headgearColor = C(28, 35, 45),
	})
	if rider then
		rider.sitOn(riderSeat)
		scope.add(function() rider.destroy() end)
	else
		part("RiderJacket", Vector3.new(1.8, 2.4, 1.1), at(8, 3.25, -17), C(30, 76, 78), M.Fabric)
		SetKit.ball(parent, "RiderHelmet", 1.35, at(8, 5.05, -17.1), C(28, 35, 45), M.SmoothPlastic)
		SetKit.neon(parent, "HelmetStripe", Vector3.new(0.1, 0.16, 1.1), CFrame.new(at(8, 5.1, -17.75)), C(220, 185, 89))
	end
	-- The LRT: a guideway on piers above the street, which the train crosses.
	part("Guideway", Vector3.new(8, 2, 170), at(-18, 15.4, 0), C(116, 118, 124), M.Concrete)
	part("GuidewayEdge", Vector3.new(8.4, 0.6, 170), at(-18, 16.6, 0), C(92, 94, 100), M.Concrete)
	for _, z in ipairs({ -48, -8, 32 }) do
		part("Pier", Vector3.new(3, 14.4, 3), at(-18, 7.2, z), C(104, 106, 112), M.Concrete)
	end
	-- Shophouses behind the mamak: two storeys, a few rooms still lit upstairs.
	SetKit.part(parent, "Shophouses", Vector3.new(120, 22, 6), CFrame.new(at(10, 11, -40)), C(58, 50, 46), M.Concrete, { castShadow = false })
	local rng = Random.new(41)
	for x = -46, 66, 6 do
		if math.abs(x + 24) > 15 then
			local lit = rng:NextNumber() < 0.35
			local pane = SetKit.part(parent, "UpperWindow", Vector3.new(3.2, 3.4, 0.1), CFrame.new(at(x, 16, -36.95)), if lit then C(255, 196, 128) else C(24, 28, 36), if lit then M.Neon else M.Glass)
			pane.Transparency = if lit then 0.1 else 0.3
		end
	end
	-- Sodium lamps on both kerbs: the street's light, and the rain's.
	for _, spot in ipairs({ { -36, 9 }, { 0, 9 }, { 34, 9 }, { 22, -12 } }) do
		part("LampPost", Vector3.new(0.4, 13, 0.4), at(spot[1], 6.5, spot[2]), C(58, 60, 64), M.Metal)
		local head = SetKit.neon(parent, "LampHead", Vector3.new(1.6, 0.35, 0.8), CFrame.new(at(spot[1], 13, spot[2])), C(255, 170, 84))
		SetKit.light(head, "SpotLight", 2.2, 30, C(255, 160, 80), { face = Enum.NormalId.Bottom, angle = 110 })
		SetKit.glint(parent, `Glint_{spot[1]}`, CFrame.new(at(spot[1], 0.21, spot[2])), 2.2, 11, C(255, 150, 70), 0.42)
	end
	-- The lamppost notice from the screenplay: no parking, hand-painted.
	SetKit.sign(parent, "NoParking", CFrame.new(at(0, 7.5, 8.7)) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(2.2, 1.1, 0.06), "NO PARKING", C(236, 236, 230), { panel = C(206, 60, 44), font = Enum.Font.GothamBlack, pixelsPerStud = 55 })
	-- The unmarked car rolls in along the street from the east and pulls up past
	-- the mamak. The whole model moves (a driver value, as the bedroom's hand does).
	local sedan = Instance.new("Model")
	sedan.Name = "Sedan"
	sedan.Parent = parent
	-- Contemporary executive sedan: low metallic body, glasshouse cabin, grille,
	-- mirrors and full-width rear lamp bar. Faces -Z (front at -Z).
	local body = SetKit.part(sedan, "Body", Vector3.new(7.4, 1.5, 15), CFrame.new(at(0, 1.65, 0)), C(26, 32, 42), M.Metal)
	body.Reflectance = 0.12
	SetKit.part(sedan, "Hood", Vector3.new(7.0, 0.35, 3.4), CFrame.new(at(0, 2.5, -5.6)), C(32, 39, 51), M.Metal)
	SetKit.part(sedan, "Trunk", Vector3.new(7.0, 0.35, 2.6), CFrame.new(at(0, 2.5, 6.0)), C(32, 39, 51), M.Metal)
	local cabin = SetKit.part(sedan, "Cabin", Vector3.new(6.2, 1.7, 6.4), CFrame.new(at(0, 3.3, 0.4)), C(16, 26, 38), M.Glass)
	cabin.Transparency = 0.25
	cabin.Reflectance = 0.15
	SetKit.part(sedan, "Grille", Vector3.new(3.6, 0.6, 0.15), CFrame.new(at(0, 1.7, -7.55)), C(120, 130, 142), M.Metal)
	for _, x in ipairs({ -2.9, 2.9 }) do
		SetKit.part(sedan, "Mirror", Vector3.new(0.5, 0.3, 0.7), CFrame.new(at(x, 3.1, -2.6)), C(26, 32, 42), M.Metal)
	end
	for _, x in ipairs({ -3.9, 3.9 }) do
		for _, z in ipairs({ -5.6, 5.6 }) do
			SetKit.cylinder(sedan, "Wheel", 0.75, 2.3, CFrame.new(at(x, 1.0, z)), C(12, 13, 15), M.Rubber)
			SetKit.cylinder(sedan, "Rim", 0.4, 2.36, CFrame.new(at(x, 1.0, z)), C(150, 156, 164), M.Metal)
		end
	end
	for _, x in ipairs({ -2.6, 2.6 }) do
		local lamp = SetKit.neon(sedan, "Headlamp", Vector3.new(1.5, 0.42, 0.18), CFrame.new(at(x, 2.0, -7.55)), C(214, 232, 255))
		SetKit.light(lamp, "SpotLight", 1.6, 26, C(255, 240, 210), { face = Enum.NormalId.Front, angle = 50 })
	end
	SetKit.neon(sedan, "TailBar", Vector3.new(5.6, 0.32, 0.16), CFrame.new(at(0, 2.0, 7.55)), C(200, 30, 30))
	local plateF = SetKit.part(sedan, "Plate_F", Vector3.new(1.7, 0.42, 0.06), CFrame.new(at(0, 1.3, -7.58)), C(240, 240, 236), M.SmoothPlastic, { castShadow = false })
	SetKit.label(plateF, Enum.NormalId.Front, "W 144 SCU", { color = C(16, 18, 22), size = 26, font = Enum.Font.GothamBold, lightInfluence = 0.4 })
	sedan.PrimaryPart = body
	-- Facing west (-X), driving along the near kerb.
	local function onStreet(x: number): CFrame
		return CFrame.new(at(x, 1.9, -3)) * CFrame.Angles(0, math.rad(90), 0)
	end
	local driver = Instance.new("CFrameValue")
	driver.Value = onStreet(52)
	sedan:PivotTo(driver.Value)
	scope.add(driver)
	scope.add(driver.Changed:Connect(function(value: CFrame)
		sedan:PivotTo(value)
	end))
	local rain = SetKit.rain(parent, CFrame.new(at(0, 24, 0)), Vector3.new(110, 0.2, 92), 78, { rate = 750, speed = 78, length = 2.6, slant = -3 })
	local teaTween = SetKit.newTween(glass, 0.9, { CFrame = glass.CFrame + Vector3.new(2.2, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local arrive = SetKit.newTween(driver, 3.6, { Value = onStreet(11) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local stop = SetKit.newTween(driver, 0.8, { Value = onStreet(9.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local actions = {
		TrainPasses = function()
			local train = part("LRTTrain", Vector3.new(6, 5, 22), at(-18, 19, 70), C(158, 165, 177), M.Metal)
			local windows = SetKit.neon(parent, "LRTWindows", Vector3.new(6.2, 1.5, 20), CFrame.new(at(-18, 19.2, 70)), C(255, 229, 179))
			local move = SetKit.tween(train, 4.4, { CFrame = CFrame.new(at(-18, 19, -70)) }, Enum.EasingStyle.Linear)
			local moveWindows = SetKit.tween(windows, 4.4, { CFrame = CFrame.new(at(-18, 19.2, -70)) }, Enum.EasingStyle.Linear)
			scope.add(move)
			scope.add(moveWindows)
		end,
		TeaPulled = function()
			teaTween:Play()
		end,
		SedanRolls = function()
			arrive:Play()
		end,
		SedanStops = function()
			stop:Play()
		end,
	}
	scope.add(rain)
	scope.add(teaTween)
	scope.add(arrive)
	scope.add(stop)
	return {
		act = function(name: string, _args: { [string]: any }?)
			local action = actions[name]
			if action then
				action()
			end
		end,
		destroy = function()
			scope.clean()
		end,
	}
end

return Street
