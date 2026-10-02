--!strict
--[[
	CitySkyline (M6)
	The night city outside the office's north windows, built at runtime like
	the rest of the environment staging. It is placed from the plan's north
	wall (OfficePlan), so it follows the windows wherever the plan puts them.
	A flat night sky and four dark towers alone read as a black void from
	inside; on top of them this adds:

	  * a band of city-light haze along the horizon, so silhouettes read;
	  * two layers of towers between the authored ones and the sky;
	  * window grids on every tower (authored and new): mostly dark glass,
	    some lit warm, a few cool -- most of the city asleep. The nearer
	    towers show their dark windows too, so a facade reads as a building
	    rather than a black slab;
	  * slow-blinking aviation lights on the tallest roofs.

	Deterministic (fixed random seed), so every session sees the same city.
	Purely environmental: no case data, nothing interactive.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent:WaitForChild("PropKit"))

local log = Logger.scoped("CitySkyline")

local CitySkyline = {}

local FOLDER_NAME = "Skyline"
local SEED = 1947

local WARM = Color3.fromRGB(255, 206, 140)
local COOL = Color3.fromRGB(176, 204, 255)
-- Dark glass: just brighter than the night, so the facade grid reads.
local UNLIT = Color3.fromRGB(30, 36, 52)
local AVIATION_RED = Color3.fromRGB(255, 50, 40)

-- Where things stand, measured outward from the north wall (studs beyond it).
-- The near towers are the backdrop's own; layers of towers fill in behind them,
-- out to the far city, and the night-sky plane closes the view. The far layers
-- are big and sparse: from the office they are a few lit windows each, fading
-- into the haze (the office Atmosphere), which is what gives the view depth.
-- The neighbours are lower than level nine: their roofs sit under the window
-- line, so the view goes over them to the city.
local NEAR_TOWERS = {
	{ x = -30, width = 14, height = 4, depth = 10, beyond = 11, color = Color3.fromRGB(26, 28, 38) },
	{ x = -12, width = 16, height = 6, depth = 10, beyond = 17, color = Color3.fromRGB(22, 24, 34) },
	{ x = 8, width = 12, height = 3, depth = 10, beyond = 9, color = Color3.fromRGB(28, 30, 40) },
	{ x = 28, width = 18, height = 5, depth = 10, beyond = 15, color = Color3.fromRGB(20, 22, 32) },
}
local SKY_BEYOND = 420
local LAYERS = {
	{ beyond = 26, span = 80, minWidth = 8, maxWidth = 14, minHeight = 2, maxHeight = 8, color = Color3.fromRGB(20, 22, 30), windowScale = 1, facade = true },
	{ beyond = 32, span = 80, minWidth = 10, maxWidth = 18, minHeight = 3, maxHeight = 10, color = Color3.fromRGB(26, 29, 40), windowScale = 0.8, facade = false },
	{ beyond = 80, span = 150, minWidth = 12, maxWidth = 22, minHeight = 40, maxHeight = 110, color = Color3.fromRGB(22, 24, 34), windowScale = 1.6, facade = false },
	{ beyond = 160, span = 270, minWidth = 16, maxWidth = 30, minHeight = 60, maxHeight = 170, color = Color3.fromRGB(24, 26, 36), windowScale = 2.2, facade = false },
	{ beyond = 280, span = 420, minWidth = 22, maxWidth = 40, minHeight = 80, maxHeight = 220, color = Color3.fromRGB(26, 28, 38), windowScale = 3, facade = false },
}
local LIT_CHANCE = 0.2
local COOL_CHANCE = 0.25

local function block(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Windows on a tower's face toward the office (+Z). With `facade`, unlit
-- windows are drawn as dark glass; without, they are simply the tower's own
-- dark surface (the far layer, mostly hidden behind the near one).
local function lightWindows(tower: BasePart, scale: number, facade: boolean, rng: Random, parent: Instance): number
	local size = tower.Size
	local face = tower.Position.Z + size.Z / 2 + 0.06
	local windowSize = Vector3.new(1.1 * scale, 1.3 * scale, 0.1)
	local columnStep, rowStep = 2.2 * scale, 2.8 * scale
	local columns = math.floor((size.X - 2) / columnStep)
	local rows = math.floor((size.Y - 4) / rowStep)
	local left = tower.Position.X - (columns - 1) * columnStep / 2
	local bottom = tower.Position.Y - size.Y / 2 + 3
	local lit = 0
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			if rng:NextNumber() < LIT_CHANCE then
				local color = if rng:NextNumber() < COOL_CHANCE then COOL else WARM
				-- Slight per-window variation, as if behind different blinds.
				local dim = 0.55 + rng:NextNumber() * 0.45
				block(
					"Window",
					windowSize,
					Vector3.new(left + column * columnStep, bottom + row * rowStep, face),
					color:Lerp(Color3.new(0, 0, 0), 1 - dim),
					Enum.Material.Neon,
					parent
				)
				lit += 1
			elseif facade then
				block("Window", windowSize, Vector3.new(left + column * columnStep, bottom + row * rowStep, face), UNLIT, Enum.Material.Neon, parent)
			end
		end
	end
	return lit
end

-- The lamp itself (steady, bright): built by the bake or by a fresh run.
-- The blink is runtime state, armed separately below.
local function aviationLight(tower: BasePart, parent: Instance): BasePart
	local top = tower.Position + Vector3.new(0, tower.Size.Y / 2 + 0.4, 0)
	return block("AviationLight", Vector3.new(0.6, 0.6, 0.6), top, AVIATION_RED, Enum.Material.Neon, parent)
end

local function armAviationBlink(lamp: BasePart)
	TweenService:Create(
		lamp,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.9 }
	):Play()
end

-- A distant elevated arterial breaks up the tower bases and gives the
-- Malaysian night skyline a recognisable layer of movement and scale.
local function buildRoadway(parent: Instance, northZ: number)
	local roadZ = northZ - 8.5
	local roadY = 4.15
	block("ElevatedRoad", Vector3.new(176, 0.42, 5.2), Vector3.new(0, roadY, roadZ), Color3.fromRGB(34, 38, 46), Enum.Material.Asphalt, parent)
	block("RoadDeckEdge", Vector3.new(176, 0.32, 0.28), Vector3.new(0, roadY - 0.32, roadZ + 2.55), Color3.fromRGB(70, 74, 78), Enum.Material.Concrete, parent)
	for x = -80, 80, 16 do
		block("LaneMark", Vector3.new(5.2, 0.035, 0.1), Vector3.new(x, roadY + 0.23, roadZ), Color3.fromRGB(206, 190, 148), Enum.Material.Neon, parent)
	end
	for _, x in ipairs({ -70, -35, 0, 35, 70 }) do
		block("RoadLampPole", Vector3.new(0.12, 2.5, 0.12), Vector3.new(x, roadY + 1.35, roadZ + 2.8), Color3.fromRGB(60, 64, 70), Enum.Material.Metal, parent)
		local lamp = block("RoadLamp", Vector3.new(0.5, 0.12, 0.22), Vector3.new(x, roadY + 2.55, roadZ + 2.8), Color3.fromRGB(255, 190, 116), Enum.Material.Neon, parent)
		lamp.Transparency = 0.12
	end
	local sign = block("RoadSign", Vector3.new(4.8, 1.15, 0.12), Vector3.new(2, roadY + 4.15, roadZ + 2.7), Color3.fromRGB(27, 66, 59), Enum.Material.SmoothPlastic, parent)
	PropKit.label(sign, Enum.NormalId.Back, "PUSAT BANDAR  ·  2 KM", {
		color = Color3.fromRGB(231, 235, 219),
		font = Enum.Font.GothamBold,
		lightInfluence = 0,
		pixelsPerStud = 80,
		padding = 5,
	})
	for i, x in ipairs({ -54, 54 }) do
		local laneZ = roadZ + (i == 1 and -1.25 or 1.25)
		local car = block(`TrafficBody_{i}`, Vector3.new(2.2, 0.45, 0.88), Vector3.new(x, roadY + 0.48, laneZ), Color3.fromRGB(47, 54, 66), Enum.Material.Metal, parent)
		for _, side in ipairs({ -1, 1 }) do
			local isForward = side == (if i == 1 then 1 else -1)
			block(`TrafficLamp_{i}_{side}`, Vector3.new(0.12, 0.12, 0.08), car.Position + Vector3.new(side * 1.06, 0.03, 0), if isForward then Color3.fromRGB(255, 206, 136) else Color3.fromRGB(244, 72, 62), Enum.Material.Neon, parent)
		end
	end
end

local function armTraffic(parent: Instance)
	for index, delta in ipairs({ 140, -140 }) do
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("BasePart") and (child.Name == `TrafficBody_{index}` or child.Name:match(`^TrafficLamp_{index}_`)) then
				TweenService:Create(
					child,
					TweenInfo.new(36, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
					{ Position = child.Position + Vector3.new(delta, 0, 0) }
				):Play()
			end
		end
	end
end

-- A container that every client always has in full. The place streams, and a
-- city hundreds of studs out would otherwise arrive piecemeal, or not at all,
-- through the windows.
local function persistentModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	return model
end

-- The near towers and the sky plane (the "backdrop"), placed from the north wall.
local function buildBackdrop(office: Instance, northZ: number): Model
	local backdrop = persistentModel("Backdrop", office)
	block("NightSky", Vector3.new(1400, 560, 1), Vector3.new(0, 200, northZ - SKY_BEYOND), Color3.fromRGB(18, 20, 30), Enum.Material.SmoothPlastic, backdrop)
	for _, t in ipairs(NEAR_TOWERS) do
		local tower = block(
			"Bldg",
			Vector3.new(t.width, t.height, t.depth),
			Vector3.new(t.x, t.height / 2, northZ - t.beyond - t.depth / 2),
			t.color,
			Enum.Material.Concrete,
			backdrop
		)
		tower.CanCollide = false
	end
	return backdrop
end

function CitySkyline.start()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn("no office; skipping skyline")
		return
	end
	local northZ = OfficePlan.getWall("North").at

	local existing = office:FindFirstChild(FOLDER_NAME)
	if existing then
		-- Baked already: adopt the geometry as-is (it is deterministic, and
		-- author edits to it survive). The aviation blink is runtime state:
		-- re-arm it only when a game is running.
		if RunService:IsRunning() then
			for _, child in ipairs(existing:GetDescendants()) do
				if child.Name == "AviationLight" and child:IsA("BasePart") then
					child.Transparency = 0
					armAviationBlink(child)
				end
			end
			armTraffic(existing)
		end
		log:info("skyline already present; adopting baked geometry", { parts = #existing:GetChildren() })
		return
	end

	local backdrop = office:FindFirstChild("Backdrop") or buildBackdrop(office, northZ)

	local folder = persistentModel(FOLDER_NAME, office)

	local rng = Random.new(SEED)
	buildRoadway(folder, northZ)

	-- City-light haze: stacked bands, brightest at the horizon, in front of
	-- the authored sky plane. Neon so they hold their colour at night.
	local sky = backdrop:FindFirstChild("NightSky")
	local skyZ = if sky and sky:IsA("BasePart") then sky.Position.Z + 0.6 else northZ - SKY_BEYOND + 0.6
	local bands = {
		{ height = 90, color = Color3.fromRGB(150, 100, 78) },
		{ height = 200, color = Color3.fromRGB(88, 70, 86) },
		{ height = 340, color = Color3.fromRGB(46, 46, 72) },
	}
	for index, band in ipairs(bands) do
		-- Wider bands sit further back so the narrower, brighter ones overlap
		-- them from the horizon up.
		block(
			`Haze_{index}`,
			Vector3.new(1400, band.height, 0.2),
			Vector3.new(0, band.height / 2 - 2, skyZ + (#bands - index) * 0.1),
			band.color,
			Enum.Material.Neon,
			folder
		)
	end

	local towers: { BasePart } = {}
	for layerIndex, layer in ipairs(LAYERS) do
		local x = -layer.span + rng:NextNumber() * 4
		while x < layer.span do
			local width = rng:NextNumber(layer.minWidth, layer.maxWidth)
			local height = rng:NextNumber(layer.minHeight, layer.maxHeight)
			local depth = rng:NextNumber(6, 10)
			local tower = block(
				`Tower_{layerIndex}`,
				Vector3.new(width, height, depth),
				Vector3.new(x + width / 2, height / 2 - 1, northZ - layer.beyond - depth / 2),
				layer.color,
				Enum.Material.Concrete,
				folder
			)
			tower:SetAttribute("WindowScale", layer.windowScale)
			tower:SetAttribute("Facade", layer.facade)
			table.insert(towers, tower)
			x += width + rng:NextNumber(0.5, 4)
		end
	end

	-- The authored towers get lit windows too.
	for _, child in ipairs(backdrop:GetChildren()) do
		if child.Name == "Bldg" and child:IsA("BasePart") then
			child:SetAttribute("WindowScale", 1)
			child:SetAttribute("Facade", true)
			table.insert(towers, child)
		end
	end

	local windows = 0
	for _, tower in ipairs(towers) do
		windows += lightWindows(
			tower,
			tower:GetAttribute("WindowScale") :: number,
			tower:GetAttribute("Facade") == true,
			rng,
			folder
		)
	end

	-- Aviation lights on the three tallest roofs.
	table.sort(towers, function(a, b)
		return a.Position.Y + a.Size.Y / 2 > b.Position.Y + b.Size.Y / 2
	end)
	for i = 1, math.min(3, #towers) do
		local lamp = aviationLight(towers[i], folder)
		-- The blink only runs in a live game; an Edit-mode bake leaves the
		-- lamps steady and bright.
		if RunService:IsRunning() then
			armAviationBlink(lamp)
		end
	end
	if RunService:IsRunning() then
		armTraffic(folder)
	end

	log:info("skyline built", { towers = #towers, litWindows = windows, parts = #folder:GetChildren() })
end

return CitySkyline
