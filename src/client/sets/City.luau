--!strict
--[[
	City: Kota Arwana from the air, at night, in the rain. The
	towers of Dataran Arwana on the west bank, the dark curve of the Sungai
	Arwana, the old town's low roofs lit orange on the east bank, the avenues
	strung with lamps and moving light, an elevated LRT line, and a red aviation
	light blinking on the tallest roof.

	It is seen for seven seconds from a camera a hundred and fifty studs up, so
	nothing here has detail below what a lit window or a lamp gives: the city is
	made of light on dark shapes, and the haze does the rest.

	Local coordinates: the river runs from the near left toward the far right; the
	camera hangs over the river's east bank near (40, 165, 280) and pushes in
	toward the twin towers. Keep what the shot needs within about five hundred
	studs of it: Roblox stops drawing small parts (a lit window) further out than
	that, sooner on a low graphics setting.

	Actions:
	  TrafficFlows   the cars on the avenues begin to move, and the LRT train runs
	                 its line (looping, until the set comes down).
]]

local SetKit = require(script.Parent:WaitForChild("SetKit"))

local City = {}

local M = SetKit.M
local C3 = Color3.fromRGB

-- The river's course, before smoothing: (x, z) in local studs, near to far.
local RIVER = {
	Vector2.new(-340, 1000),
	Vector2.new(-160, 580),
	Vector2.new(-30, 280),
	Vector2.new(60, 60),
	Vector2.new(70, -170),
	Vector2.new(160, -400),
	Vector2.new(330, -650),
	Vector2.new(480, -980),
}
local RIVER_WIDTH = 66

local WARM = C3(255, 196, 120)
local SODIUM = C3(255, 150, 62)
local COOL = C3(190, 214, 255)

-- A smooth curve through the points (Catmull-Rom), `steps` samples per span.
local function spline(points: { Vector2 }, steps: number): { Vector2 }
	local out: { Vector2 } = {}
	for i = 1, #points - 1 do
		local p0 = points[math.max(i - 1, 1)]
		local p1 = points[i]
		local p2 = points[i + 1]
		local p3 = points[math.min(i + 2, #points)]
		for s = 0, steps - 1 do
			local t = s / steps
			local t2, t3 = t * t, t * t * t
			table.insert(
				out,
				0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
			)
		end
	end
	table.insert(out, points[#points])
	return out
end

-- Distance from (x, z) to the river's centre line, and which bank (+1 east/right
-- of the flow, -1 west/left).
local function relativeToRiver(course: { Vector2 }, x: number, z: number): (number, number)
	local best, side = math.huge, 1
	local p = Vector2.new(x, z)
	for i = 1, #course - 1 do
		local a, b = course[i], course[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		local closest = a + ab * t
		local d = (p - closest).Magnitude
		if d < best then
			best = d
			-- The flow runs from a to b (here, north: -Z). In (x, z), a positive cross
			-- product is to the east of the flow.
			local cross = ab.X * (p.Y - a.Y) - ab.Y * (p.X - a.X)
			side = if cross > 0 then 1 else -1
		end
	end
	return best, side
end

function City.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end
	local rng = Random.new(1947)

	--------------------------------------------------------------------
	-- Ground, sky and the horizon glow
	--------------------------------------------------------------------
	SetKit.part(parent, "Ground", Vector3.new(2000, 1, 2000), CFrame.new(at(0, -0.5, 0)), C3(22, 20, 26), M.SmoothPlastic, { castShadow = false })
	SetKit.gradientSky(parent, "Sky", CFrame.lookAt(at(0, 260, -1250), at(0, 260, 0)), 3600, 900, {
		{ at = 0, color = C3(8, 10, 18) },
		{ at = 0.34, color = C3(14, 18, 30) },
		{ at = 0.5, color = C3(28, 36, 54) },
		{ at = 0.56, color = C3(56, 70, 98) },
		{ at = 0.6, color = C3(44, 58, 86) },
		{ at = 1, color = C3(10, 14, 24) },
	})

	--------------------------------------------------------------------
	-- The river
	--------------------------------------------------------------------
	local course = spline(RIVER, 8)
	local river = Instance.new("Folder")
	river.Name = "River"
	river.Parent = parent
	for i = 1, #course - 1 do
		local a, b = course[i], course[i + 1]
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local from, to = at(mid.X, 0.15, mid.Y), at(b.X, 0.15, b.Y)
		SetKit.part(river, "Water", Vector3.new(RIVER_WIDTH, 0.3, length + 2.5), CFrame.lookAt(from, to), C3(12, 16, 28), M.SmoothPlastic, { reflectance = 0.35, castShadow = false })
	end
	-- The bank lamps, both sides, and the glints of the towers' lights on the water.
	local banks = Instance.new("Folder")
	banks.Name = "Banks"
	banks.Parent = parent
	for i = 1, #course - 1, 2 do
		local a, b = course[i], course[i + 1]
		local direction = (b - a).Unit
		local normal = Vector2.new(-direction.Y, direction.X)
		for _, sign in ipairs({ -1, 1 }) do
			local p = a + normal * (RIVER_WIDTH / 2 + 4) * sign
			SetKit.neon(banks, "Lamp", Vector3.new(1, 1, 1), CFrame.new(at(p.X, 1, p.Y)), if sign < 0 then COOL else SODIUM)
		end
	end

	--------------------------------------------------------------------
	-- Dataran Arwana: the towers on the west bank
	--------------------------------------------------------------------
	local cbd = Instance.new("Folder")
	cbd.Name = "DataranArwana"
	cbd.Parent = parent
	local placed: { { x: number, z: number, r: number } } = {}
	local function clear(x: number, z: number, radius: number): boolean
		for _, other in ipairs(placed) do
			local dx, dz = other.x - x, other.z - z
			if math.sqrt(dx * dx + dz * dz) < other.r + radius then
				return false
			end
		end
		return true
	end
	local function tower(name: string, x: number, z: number, width: number, depth: number, height: number, seed: number, crown: Color3?)
		table.insert(placed, { x = x, z = z, r = math.max(width, depth) * 0.8 })
		local body = SetKit.tower(cbd, name, at(x, 0, z), width, depth, height, {
			color = C3(20 + rng:NextInteger(0, 8), 24 + rng:NextInteger(0, 8), 34 + rng:NextInteger(0, 10)),
			seed = seed,
			litChance = 0.27,
			faces = { "south", "east" },
			scale = 2.5,
			coolChance = 0.34,
			material = M.SmoothPlastic,
		})
		body.Reflectance = 0.12
		-- A lit crown on the roof line.
		if crown then
			SetKit.neon(cbd, `{name}_Crown`, Vector3.new(width + 0.6, 1.2, depth + 0.6), CFrame.new(at(x, height + 0.6, z)), crown)
		end
		return body
	end
	-- Landmarks first: the twin towers with their skybridge, and the spire.
	tower("Twin_A", -206, -250, 32, 32, 250, 5, WARM)
	tower("Twin_B", -160, -250, 32, 32, 250, 6, WARM)
	SetKit.part(cbd, "Skybridge", Vector3.new(18, 6, 8), CFrame.new(at(-183, 172, -250)), C3(30, 36, 50), M.SmoothPlastic, { castShadow = false })
	SetKit.neon(cbd, "Skybridge_Glow", Vector3.new(17, 1.2, 8.2), CFrame.new(at(-183, 172, -250)), COOL)
	local spire = tower("Spire", -288, -70, 26, 26, 310, 7, C3(255, 90, 60))
	local lamps: { BasePart } = {}
	for _, target in ipairs({ { -206, -250, 250 }, { -160, -250, 250 }, { -288, -70, 310 } }) do
		local lamp = SetKit.neon(cbd, "AviationLight", Vector3.new(1.4, 1.4, 1.4), CFrame.new(at(target[1], target[3] + 4, target[2])), C3(255, 40, 30))
		table.insert(lamps, lamp)
	end
	for index = 1, 44 do
		for _ = 1, 8 do
			local x = rng:NextNumber(-470, -40)
			local z = rng:NextNumber(-820, 380)
			local distance, side = relativeToRiver(course, x, z)
			local width = rng:NextNumber(20, 36)
			local depth = rng:NextNumber(20, 34)
			if side < 0 and distance > RIVER_WIDTH / 2 + 26 and clear(x, z, math.max(width, depth) * 0.8) then
				local height = 70 + 170 * rng:NextNumber() ^ 2
				tower(`Tower_{index}`, x, z, width, depth, height, 100 + index, if rng:NextNumber() < 0.3 then COOL else nil)
				break
			end
		end
	end
	-- The aviation lights blink (a fast, dim-to-bright breath).
	for _, lamp in ipairs(lamps) do
		scope.add(SetKit.tween(lamp, 1.4, { Transparency = 0.92 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		local blink = game:GetService("TweenService"):Create(lamp, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.9 })
		blink:Play()
		scope.add(blink)
	end

	--------------------------------------------------------------------
	-- The old town: low roofs, lit orange, on the east bank
	--------------------------------------------------------------------
	local old = Instance.new("Folder")
	old.Name = "OldTown"
	old.Parent = parent
	local plaster = { C3(52, 40, 40), C3(60, 46, 42), C3(46, 38, 46), C3(64, 50, 44) }
	local count = 0
	for gx = 110, 620, 38 do
		for gz = -640, 420, 34 do
			local x = gx + rng:NextNumber(-5, 5)
			local z = gz + rng:NextNumber(-5, 5)
			local distance, side = relativeToRiver(course, x, z)
			-- Streets: every fourth line is left empty.
			local street = (math.floor((gx - 110) / 38) % 4 == 0) or (math.floor((gz + 640) / 34) % 5 == 0)
			if side > 0 and distance > RIVER_WIDTH / 2 + 24 and not street then
				count += 1
				local width = rng:NextNumber(13, 20)
				local depth = rng:NextNumber(12, 17)
				local height = rng:NextNumber(9, 22)
				local body = SetKit.tower(old, "House", at(x, 0, z), width, depth, height, {
					color = plaster[rng:NextInteger(1, #plaster)],
					seed = 300 + count,
					litChance = 0.38,
					faces = { "south", "west" },
					scale = 1.5,
					warm = SODIUM,
					cool = WARM,
					coolChance = 0.25,
				})
				body.CastShadow = false
				-- A roof: terracotta, its ridge a line of dim orange.
				local roof = SetKit.part(old, "Roof", Vector3.new(width + 1.2, 2.6, depth + 1.2), CFrame.new(at(x, height + 1.3, z)), C3(84, 38, 30), M.SmoothPlastic, { castShadow = false })
				roof.Reflectance = 0.08
			end
		end
	end
	-- Old town street lamps: sodium, in lines along the empty streets.
	for gx = 110, 620, 38 * 4 do
		for z = -600, 400, 30 do
			local distance, side = relativeToRiver(course, gx - 19, z)
			if side > 0 and distance > RIVER_WIDTH / 2 + 12 then
				SetKit.neon(old, "Lamp", Vector3.new(1.1, 1.1, 1.1), CFrame.new(at(gx - 19 + 4, 6, z)), SODIUM)
				SetKit.neon(old, "Lamp", Vector3.new(1.1, 1.1, 1.1), CFrame.new(at(gx - 19 - 4, 6, z + 15)), SODIUM)
			end
		end
	end

	--------------------------------------------------------------------
	-- A bridge over the river, lit along its length
	--------------------------------------------------------------------
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = parent
	do
		local centre = course[math.floor(#course * 0.34)]
		local ahead = course[math.floor(#course * 0.34) + 1]
		local flow = (ahead - centre).Unit
		local across = Vector2.new(-flow.Y, flow.X)
		local from = centre - across * 100
		local to = centre + across * 100
		SetKit.part(bridge, "Deck", Vector3.new(22, 2.4, 200), CFrame.lookAt(at(centre.X, 3, centre.Y), at(to.X, 3, to.Y)), C3(36, 36, 44), M.SmoothPlastic, { castShadow = false })
		for i = -9, 9 do
			local p = centre + across * (i * 10)
			for _, side in ipairs({ -1, 1 }) do
				local lp = p + flow * (10 * side)
				SetKit.neon(bridge, "Lamp", Vector3.new(1, 1, 1), CFrame.new(at(lp.X, 8, lp.Y)), WARM)
			end
		end
		local _ = from
	end

	--------------------------------------------------------------------
	-- Avenues, their cars, and the LRT line
	--------------------------------------------------------------------
	local traffic: { Tween } = {}
	local avenues = {
		{ from = Vector3.new(-520, 1.2, 300), to = Vector3.new(620, 1.2, 300) },
		{ from = Vector3.new(-520, 1.2, -120), to = Vector3.new(620, 1.2, -120) },
		{ from = Vector3.new(-520, 1.2, -480), to = Vector3.new(640, 1.2, -480) },
		{ from = Vector3.new(-330, 1.2, 640), to = Vector3.new(-330, 1.2, -820) },
		{ from = Vector3.new(120, 1.2, 640), to = Vector3.new(120, 1.2, -820) },
	}
	local roads = Instance.new("Folder")
	roads.Name = "Avenues"
	roads.Parent = parent
	local carFolder = Instance.new("Folder")
	carFolder.Name = "Cars"
	carFolder.Parent = parent
	for index, avenue in ipairs(avenues) do
		local mid = (avenue.from + avenue.to) / 2
		local length = (avenue.to - avenue.from).Magnitude
		SetKit.part(roads, "Avenue", Vector3.new(14, 0.3, length), CFrame.lookAt(origin + mid, origin + avenue.to), C3(28, 28, 34), M.SmoothPlastic, { reflectance = 0.2, castShadow = false })
		local direction = (avenue.to - avenue.from).Unit
		local side = Vector3.new(-direction.Z, 0, direction.X)
		for step = 0, length, 26 do
			for _, sign in ipairs({ -1, 1 }) do
				local p = avenue.from + direction * step + side * 9 * sign
				SetKit.neon(roads, "Lamp", Vector3.new(1, 1, 1), CFrame.new(origin + p + Vector3.new(0, 5, 0)), if index % 2 == 0 then WARM else SODIUM)
			end
		end
		-- Cars: white lights coming one way, red going the other.
		for car = 1, 9 do
			local lane = if car % 2 == 0 then 1 else -1
			local head = avenue.from + side * 3 * lane
			local tail = avenue.to + side * 3 * lane
			local start, finish = head, tail
			if lane > 0 then
				start, finish = tail, head
			end
			local part = SetKit.neon(carFolder, "Car", Vector3.new(1.3, 0.7, 2.6), CFrame.lookAt(origin + start, origin + finish), if lane > 0 then C3(255, 244, 214) else C3(255, 50, 40))
			local time = length / rng:NextNumber(16, 26)
			local tween = game:GetService("TweenService"):Create(part, TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, rng:NextNumber(0, time)), { CFrame = CFrame.lookAt(origin + finish, origin + finish + (finish - start)) })
			table.insert(traffic, tween)
		end
	end

	-- The LRT: an elevated line along Z, and a train of lit windows.
	local lrt = Instance.new("Folder")
	lrt.Name = "LRT"
	lrt.Parent = parent
	local lineX = -250
	SetKit.part(lrt, "Guideway", Vector3.new(7, 3, 1800), CFrame.new(at(lineX, 30, -100)), C3(120, 122, 130), M.Concrete, { castShadow = false })
	for z = -800, 760, 50 do
		SetKit.part(lrt, "Pier", Vector3.new(3, 30, 3), CFrame.new(at(lineX, 15, z)), C3(100, 102, 110), M.Concrete, { castShadow = false })
	end
	local train = Instance.new("Model")
	train.Name = "Train"
	train.Parent = lrt
	local trainParts: { BasePart } = {}
	for car = 0, 1 do
		local z = 700 - car * 27
		local body = SetKit.part(train, "Car", Vector3.new(5.6, 5.4, 25), CFrame.new(at(lineX, 34, z)), C3(150, 154, 166), M.SmoothPlastic, { castShadow = false })
		local windows = SetKit.neon(train, "Windows", Vector3.new(5.8, 1.6, 22), CFrame.new(at(lineX, 35, z)), C3(255, 236, 190))
		table.insert(trainParts, body)
		table.insert(trainParts, windows)
	end
	local trainBase: { [BasePart]: CFrame } = {}
	for _, trainPart in ipairs(trainParts) do
		trainBase[trainPart] = trainPart.CFrame
	end
	local trainOffset = Instance.new("NumberValue")
	trainOffset.Value = 0
	scope.add(trainOffset)
	scope.add(trainOffset.Changed:Connect(function(value: number)
		for trainPart, base in pairs(trainBase) do
			trainPart.CFrame = base + Vector3.new(0, 0, -value)
		end
	end))

	--------------------------------------------------------------------
	-- Rain over the camera's part of the sky
	--------------------------------------------------------------------
	SetKit.rain(parent, CFrame.new(at(20, 230, 240)), Vector3.new(360, 0.2, 360), 170, { rate = 1600, speed = 95, length = 3.2, slant = -4 })

	local actions: { [string]: (args: { [string]: any }?) -> () } = {
		TrafficFlows = function()
			for _, tween in ipairs(traffic) do
				tween:Play()
			end
			scope.add(SetKit.tween(trainOffset, 40, { Value = 1500 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In))
		end,
	}
	for _, tween in ipairs(traffic) do
		scope.add(tween)
	end

	local _ = spire
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

return City
