--!strict
--[[
	CitySkyline (M6)
	The night city outside the office's north windows, built at runtime like
	the rest of the environment staging (see OfficeDetailing for why nothing
	is edited in the authored asset). The authored backdrop -- a flat night
	sky and four dark towers -- read as a black void from inside; this adds:

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

local log = Logger.scoped("CitySkyline")

local CitySkyline = {}

local FOLDER_NAME = "Skyline"
local SEED = 1947

local WARM = Color3.fromRGB(255, 206, 140)
local COOL = Color3.fromRGB(176, 204, 255)
-- Dark glass: just brighter than the night, so the facade grid reads.
local UNLIT = Color3.fromRGB(30, 36, 52)
local AVIATION_RED = Color3.fromRGB(255, 50, 40)

-- Towers stand between the authored backdrop towers (z -38..-46) and the
-- authored night-sky plane (z = -60).
local LAYERS = {
	{ z = -50, minWidth = 8, maxWidth = 14, minHeight = 24, maxHeight = 58, color = Color3.fromRGB(20, 22, 30), windowScale = 1, facade = true },
	{ z = -56, minWidth = 10, maxWidth = 18, minHeight = 16, maxHeight = 44, color = Color3.fromRGB(26, 29, 40), windowScale = 0.8, facade = false },
}
local SKYLINE_MIN_X, SKYLINE_MAX_X = -80, 80
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

function CitySkyline.start()
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local backdrop = office and office:FindFirstChild("Backdrop")
	if not office or not backdrop then
		log:warn("no authored backdrop; skipping skyline")
		return
	end

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
		end
		log:info("skyline already present; adopting baked geometry", { parts = #existing:GetChildren() })
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = office

	local rng = Random.new(SEED)

	-- City-light haze: stacked bands, brightest at the horizon, in front of
	-- the authored sky plane. Neon so they hold their colour at night.
	local sky = backdrop:FindFirstChild("NightSky")
	local skyZ = if sky and sky:IsA("BasePart") then sky.Position.Z + 0.6 else -59.4
	local bands = {
		{ height = 10, color = Color3.fromRGB(150, 100, 78) },
		{ height = 22, color = Color3.fromRGB(88, 70, 86) },
		{ height = 38, color = Color3.fromRGB(46, 46, 72) },
	}
	for index, band in ipairs(bands) do
		-- Wider bands sit further back so the narrower, brighter ones overlap
		-- them from the horizon up.
		block(
			`Haze_{index}`,
			Vector3.new(220, band.height, 0.2),
			Vector3.new(0, band.height / 2 - 2, skyZ + (#bands - index) * 0.1),
			band.color,
			Enum.Material.Neon,
			folder
		)
	end

	local towers: { BasePart } = {}
	for layerIndex, layer in ipairs(LAYERS) do
		local x = SKYLINE_MIN_X + rng:NextNumber() * 4
		while x < SKYLINE_MAX_X do
			local width = rng:NextNumber(layer.minWidth, layer.maxWidth)
			local height = rng:NextNumber(layer.minHeight, layer.maxHeight)
			local depth = rng:NextNumber(6, 10)
			local tower = block(
				`Tower_{layerIndex}`,
				Vector3.new(width, height, depth),
				Vector3.new(x + width / 2, height / 2 - 1, layer.z - depth / 2),
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

	log:info("skyline built", { towers = #towers, litWindows = windows, parts = #folder:GetChildren() })
end

return CitySkyline
