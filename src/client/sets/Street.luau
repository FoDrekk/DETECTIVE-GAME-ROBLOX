--!strict
-- Kota Arwana at street level: a wet Lorong Meranti, late mamak lights,
-- an elevated LRT, a rider waiting under the awning, and the sedan arriving.
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
	-- A plastic table and two glasses; one is drawn toward the rider mid-shot.
	part("TableTop", Vector3.new(7, 0.35, 4), at(-10, 2.1, -17), C(58, 66, 70), M.Metal)
	for x = -12.7, -7.3, 5.4 do part("TableLeg", Vector3.new(0.25, 2, 0.25), at(x, 1, -17), C(45, 48, 52), M.Metal) end
	local glass = SetKit.cylinder(parent, "TehTarik", 0.9, 0.48, CFrame.new(at(-10.6, 2.65, -17)), C(166, 104, 51), M.Glass, { transparency = 0.12 })
	part("Saucer", Vector3.new(1, 0.08, 1), at(-10.6, 2.25, -17), C(190, 185, 173), M.CeramicTiles)
	-- Rider: helmet, rain jacket, still waiting astride a compact bike.
	part("BikeBody", Vector3.new(1.4, 1.2, 5.2), at(8, 1.45, -17), C(155, 35, 34), M.Metal)
	for z = -19.5, -14.5, 5 do SetKit.cylinder(parent, "BikeWheel", 0.32, 1.45, CFrame.new(at(8, 0.9, z)) * CFrame.Angles(0, 0, math.pi / 2), C(20, 22, 26), M.Rubber) end
	part("RiderJacket", Vector3.new(1.8, 2.4, 1.1), at(8, 3.25, -17), C(30, 76, 78), M.Fabric)
	SetKit.ball(parent, "RiderHelmet", 1.35, at(8, 5.05, -17.1), C(28, 35, 45), M.SmoothPlastic)
	SetKit.neon(parent, "HelmetStripe", Vector3.new(0.1, 0.16, 1.1), CFrame.new(at(8, 5.1, -17.75)), C(220, 185, 89))
	-- Sedan rolls in from frame right, passes the mamak, and comes to rest.
	local sedan = Instance.new("Model")
	sedan.Name = "Sedan"
	sedan.Parent = parent
	local body = SetKit.part(sedan, "Body", Vector3.new(7.6, 2, 15), CFrame.new(at(24, 1.9, 25)), C(38, 47, 59), M.SmoothPlastic)
	SetKit.part(sedan, "Roof", Vector3.new(6.5, 1.8, 7), CFrame.new(at(24, 3.65, 25)), C(31, 38, 48), M.SmoothPlastic)
	for x = 20.1, 27.9, 7.8 do
		for z = 19, 31, 12 do
			SetKit.cylinder(sedan, "Wheel", 0.7, 2.3, CFrame.new(at(x, 1.05, z)) * CFrame.Angles(0, 0, math.pi / 2), C(17, 18, 20), M.Rubber)
		end
	end
	for x = 21, 27, 6 do SetKit.neon(sedan, "Headlamp", Vector3.new(1.15, 0.4, 0.18), CFrame.new(at(x, 2.05, 17.45)), C(255, 235, 191)) end
	local rain = SetKit.rain(parent, CFrame.new(at(0, 24, 0)), Vector3.new(110, 0.2, 92), 78, { rate = 750, speed = 78, length = 2.6, slant = -3 })
	local teaTween = SetKit.newTween(glass, 0.9, { CFrame = CFrame.new(at(-8.4, 2.65, -17)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local arrive = SetKit.newTween(body, 3.4, { CFrame = CFrame.new(at(8, 1.9, -2)) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local stop = SetKit.newTween(body, 0.8, { CFrame = CFrame.new(at(8, 1.9, -4)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local actions = {
		TrainPasses = function()
			local train = part("LRTTrain", Vector3.new(6, 5, 22), at(-18, 19, 24), C(158, 165, 177), M.Metal)
			local windows = SetKit.neon(parent, "LRTWindows", Vector3.new(6.2, 1.5, 20), CFrame.new(at(-18, 19.2, 24)), C(255, 229, 179))
			local move = SetKit.newTween(train, 2.4, { CFrame = CFrame.new(at(-18, 19, -40)) }, Enum.EasingStyle.Linear)
			local moveWindows = SetKit.newTween(windows, 2.4, { CFrame = CFrame.new(at(-18, 19.2, -40)) }, Enum.EasingStyle.Linear)
			move:Play(); moveWindows:Play(); scope.add(move); scope.add(moveWindows)
		end,
		TeaPulled = function() teaTween:Play() end,
		SedanRolls = function() arrive:Play() end,
		SedanStops = function() stop:Play() end,
	}
	scope.add(rain)
	scope.add(teaTween); scope.add(arrive); scope.add(stop)
	return {
		act = function(name: string, _args: { [string]: any }?) local action = actions[name]; if action then action() end end,
		destroy = function() scope.clean() end,
	}
end

return Street
