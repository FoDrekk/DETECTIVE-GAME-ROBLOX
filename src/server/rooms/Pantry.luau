--!strict
--[[
	A compact executive pantry, arranged as a clean galley: fridge and dry
	storage at the north end, coffee and microwave in the middle, sink and mugs
	at the south end, with a water point by the open corridor entrance. The
	central aisle stays open; the case's espresso machine keeps its authored
	position and remains easy to approach.

	The espresso machine itself is the evidence prop case data places
	(EvidenceDefinition.propPlacement, style EspressoMachine); this room
	leaves its stretch of counter clear for it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local Pantry = {}

local at, EAST = Kit.at, Kit.EAST
local M = Enum.Material

-- The counter's surface (PropKit.kitchenRun's top).
Pantry.COUNTER_TOP = 3.0

function Pantry.build(interior: Instance)
	local rect = OfficePlan.rect("Pantry")
	local room = Kit.folder(interior, "Pantry")
	local top = Pantry.COUNTER_TOP

	-- North end: a full-height stainless fridge with a restrained shared-kitchen
	-- reminder. The one-wall galley leaves a clear aisle from the pass-through.
	local fridge = PropKit.fridge(room, at(rect.x0 + 1.1, rect.z0 + 1.15, EAST))
	for _, part in ipairs(fridge:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "Note" then
			part.Size = Vector3.new(0.44, 0.34, 0.02)
		end
	end

	local runAt = at(rect.x0 + 1.0, -12.2, EAST)
	local run = PropKit.kitchenRun(room, runAt, 6, true)
	local uppers = PropKit.wallCabinets(room, at(rect.x0 + 0.6, -12.2, EAST, 5.4), 6, true)

	-- A calm stone worktop and warm oak fronts make the existing fitted run read
	-- as a deliberate finish. The espresso evidence prop remains at its case-data
	-- coordinates on this counter.
	for _, part in ipairs(run:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Counter" then
				part.Color = Color3.fromRGB(186, 180, 166)
				part.Material = M.Marble
			elseif part.Name == "Door" or part.Name == "Carcass" then
				part.Color = Color3.fromRGB(112, 84, 62)
				part.Material = M.Wood
			end
		end
	end
	for _, part in ipairs(uppers:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "Door" or part.Name == "Body") then
			part.Color = Color3.fromRGB(210, 203, 190)
			part.Material = M.SmoothPlastic
		elseif part:IsA("BasePart") and part.Name == "StripLight" then
			local light = part:FindFirstChildWhichIsA("Light")
			if light then
				light.Brightness = 1.0
				light.Range = 8
				light.Color = Color3.fromRGB(255, 238, 212)
			end
		end
	end

	-- Warm, pale porcelain backsplash with quiet grout lines. It fills the gap
	-- between the counter and cabinets without adding loose countertop clutter.
	local backsplash = PropKit.newPart(
		room,
		"PorcelainBacksplash",
		Vector3.new(0.05, 1.3, 6.05),
		CFrame.new(rect.x0 + 0.12, 3.65, -12.2),
		Color3.fromRGB(216, 211, 199),
		M.CeramicTiles
	)
	backsplash.CastShadow = false
	for index = 1, 4 do
		local z = -14.8 + index * 1.2
		local grout = PropKit.newPart(
			room,
			`BacksplashGrout_{index}`,
			Vector3.new(0.018, 1.26, 0.025),
			CFrame.new(rect.x0 + 0.15, 3.65, z),
			Color3.fromRGB(180, 176, 166),
			M.SmoothPlastic
		)
		grout.CastShadow = false
	end
	for index = 1, 2 do
		local grout = PropKit.newPart(
			room,
			`BacksplashCourse_{index}`,
			Vector3.new(0.018, 0.025, 5.95),
			CFrame.new(rect.x0 + 0.15, 3.22 + index * 0.43, -12.2),
			Color3.fromRGB(180, 176, 166),
			M.SmoothPlastic
		)
		grout.CastShadow = false
	end

	-- On the counter, from the north: the espresso machine (case data), the
	-- microwave, the kettle, the sink, two mugs on the drainer.
	PropKit.microwave(room, at(rect.x0 + 1.0, -12.9, EAST, top))
	PropKit.kettle(room, at(rect.x0 + 1.0, -11.5, EAST, top))
	PropKit.mug(room, at(rect.x0 + 0.7, -9.6, EAST, top))
	PropKit.mug(room, at(rect.x0 + 1.3, -9.4, EAST, top), Color3.fromRGB(40, 60, 90))

	-- A slim, plumbed water station beside the entry, with a refill bottle and
	-- paper cups. It sits outside the working aisle and is not an interactable.
	local cooler = Instance.new("Folder")
	cooler.Name = "WaterStation"
	cooler.Parent = room
	local coolerX, coolerZ = rect.x1 - 1.0, rect.z1 - 1.8
	local body = PropKit.newPart(cooler, "CoolerCabinet", Vector3.new(1.25, 2.25, 1.05), CFrame.new(coolerX, 1.16, coolerZ), Color3.fromRGB(220, 222, 220), M.Metal)
	body.Reflectance = 0.04
	PropKit.newPart(cooler, "CoolerFace", Vector3.new(0.03, 1.0, 0.9), CFrame.new(coolerX - 0.65, 1.55, coolerZ), Color3.fromRGB(202, 208, 210), M.Metal)
	PropKit.newPart(cooler, "WaterSpoutHot", Vector3.new(0.08, 0.18, 0.08), CFrame.new(coolerX - 0.71, 2.12, coolerZ - 0.2), Color3.fromRGB(166, 68, 58), M.Neon)
	PropKit.newPart(cooler, "WaterSpoutCold", Vector3.new(0.08, 0.18, 0.08), CFrame.new(coolerX - 0.71, 2.12, coolerZ + 0.2), Color3.fromRGB(92, 152, 190), M.Neon)
	local dripTray = PropKit.newPart(cooler, "DripTray", Vector3.new(0.48, 0.05, 0.64), CFrame.new(coolerX - 0.74, 1.78, coolerZ), Color3.fromRGB(150, 156, 158), M.Metal)
	dripTray.CastShadow = false
	local bottle = PropKit.newPart(
		cooler,
		"WaterBottle",
		Vector3.new(0.82, 0.82, 1.35),
		CFrame.new(coolerX, 3.15, coolerZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(135, 185, 205),
		M.Glass
	)
	bottle.Transparency = 0.28
	bottle.Reflectance = 0.08
	PropKit.newPart(cooler, "BottleCap", Vector3.new(0.24, 0.2, 0.24), CFrame.new(coolerX, 3.85, coolerZ), Color3.fromRGB(78, 132, 164), M.SmoothPlastic)
	local cups = PropKit.newPart(cooler, "CupStack", Vector3.new(0.36, 0.32, 0.36), CFrame.new(coolerX - 0.76, 2.82, coolerZ + 0.42), Color3.fromRGB(244, 241, 232), M.SmoothPlastic)
	cups.Shape = Enum.PartType.Cylinder
	PropKit.bin(room, at(rect.x1 - 0.7, rect.z0 + 0.7, EAST))
end

return Pantry
