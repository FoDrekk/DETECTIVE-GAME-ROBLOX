--!strict
--[[
	OfficeDawn (Phase 5.5): a world set. The office at first light: the deadline
	the whole case is played against ("forensics can't get there till six")
	arriving at the north windows.

	The lighting preset "Dawn" changes the sky's light; this set changes what
	is out there to be lit. "Brighten" over its `time` warms the night-sky plane and
	the city-light haze to a dawn, raises a sun behind the towers, and lets the
	office's own lamps look small against the day. Everything is a client-side
	change to what the server built, undone when the set comes down.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local SetKit = require(script.Parent:WaitForChild("SetKit"))

local OfficeDawn = {}

local DEFAULT_TIME = 8
local SKY_DAWN = Color3.fromRGB(78, 92, 138)
local HAZE_DAWN = {
	Haze_1 = Color3.fromRGB(255, 182, 116),
	Haze_2 = Color3.fromRGB(214, 146, 136),
	Haze_3 = Color3.fromRGB(104, 108, 156),
}
-- What the office's own lamps are turned down to, as a fraction of their night level.
local LAMP_FRACTION = 0.6

function OfficeDawn.build(_origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local office = workspace:FindFirstChild("Office")
	local sky = office and office:FindFirstChild("NightSky", true)
	local restore: { () -> () } = {}

	-- The parts whose colour changes, remembered so they can go back.
	local tinted: { { part: BasePart, from: Color3, to: Color3 } } = {}
	if sky and sky:IsA("BasePart") then
		table.insert(tinted, { part = sky, from = sky.Color, to = SKY_DAWN })
	end
	for name, color in pairs(HAZE_DAWN) do
		local haze = office and office:FindFirstChild(name, true)
		if haze and haze:IsA("BasePart") then
			table.insert(tinted, { part = haze, from = haze.Color, to = color })
		end
	end

	-- The sun: a large self-lit disc in front of the sky plane and behind the towers,
	-- below the horizon until it rises.
	local northZ = OfficePlan.getWall("North").at
	local sunZ = if sky and sky:IsA("BasePart") then sky.Position.Z + 1.0 else northZ - 35
	local sun = SetKit.ball(parent, "Sun", 16, Vector3.new(6, -9, sunZ), Color3.fromRGB(255, 226, 168), Enum.Material.Neon, { transparency = 1, castShadow = false })

	-- The lamps: every light the office's interior owns, dimmed as the day comes.
	local lamps: { { light: Light, from: number } } = {}
	local lights = office and office:FindFirstChild("Lights", true)
	if lights then
		for _, descendant in ipairs(lights:GetDescendants()) do
			if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
				table.insert(lamps, { light = descendant, from = descendant.Brightness })
			end
		end
	end

	local actions: { [string]: (args: { [string]: any }?) -> () } = {
		Brighten = function(args)
			local seconds = (args and args.time) or DEFAULT_TIME
			for _, entry in ipairs(tinted) do
				scope.add(SetKit.tween(entry.part, seconds, { Color = entry.to }))
			end
			scope.add(SetKit.tween(sun, seconds, { Position = Vector3.new(6, 7, sunZ), Transparency = 0.05 }))
			for _, lamp in ipairs(lamps) do
				scope.add(SetKit.tween(lamp.light, seconds, { Brightness = lamp.from * LAMP_FRACTION }))
			end
		end,
	}

	table.insert(restore, function()
		for _, entry in ipairs(tinted) do
			if entry.part.Parent then
				entry.part.Color = entry.from
			end
		end
		for _, lamp in ipairs(lamps) do
			if lamp.light.Parent then
				lamp.light.Brightness = lamp.from
			end
		end
	end)

	return {
		act = function(name: string, args: { [string]: any }?)
			local action = actions[name]
			if action then
				action(args)
			end
		end,
		destroy = function()
			scope.clean()
			for _, undo in ipairs(restore) do
				undo()
			end
		end,
	}
end

return OfficeDawn
