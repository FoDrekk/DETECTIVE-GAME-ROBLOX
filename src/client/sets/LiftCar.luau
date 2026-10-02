--!strict
--[[
	LiftCar (Phase 5.5): a world set. The lift car behind reception's east wall is
	built in the office (OfficeShell) with its doors open, and stays that way
	for everyone: this set adds what the intro's ride needs, on this client only,
	and takes every bit of it away again.

	  * a pair of steel door leaves over the doorway, built CLOSED (the ride
	    starts shut in), that slide open ("DoorsOpen") or shut ("DoorsClose");
	  * the floor display's number ("Display"), counting up as the car climbs;
	  * a shudder ("Shudder") as the car moves off or stops;
	  * the mirror: the back wall is dark glass, and behind it (through the real
	    wall, hidden for the ride) a reflection of the car -- its walls, its light,
	    its own doors -- with the player's avatar in it, turning as they look. A
	    mirror that shows an empty car would say "this is a set"; one that shows
	    you says you are in it.

	The reflection is real geometry seen through the glass (a mirror-image copy
	of the car on the far side of the plane), so it is perspective-correct from
	anywhere the player looks with no rendering tricks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local CameraController = require(script.Parent.Parent:WaitForChild("CameraController"))
local SetKit = require(script.Parent:WaitForChild("SetKit"))

local LiftCar = {}

local M = SetKit.M
local STEEL = Color3.fromRGB(150, 152, 156)
local DEFAULT_TIME = 1.7

-- The parts of the real car that have a mirror image (the rest carry text or
-- lights, which don't reflect into a box).
local REFLECTED = {
	Floor = true,
	Ceiling = true,
	LightPanel = true,
	Clad_N = true,
	Clad_S = true,
	Clad_W_N = true,
	Clad_W_S = true,
	Clad_W_Head = true,
	Handrail_N = true,
	Handrail_S = true,
}

local function extentsOf(part: BasePart): (number, number, number, number, number, number)
	local cf, size = part.CFrame, part.Size
	local ex = (math.abs(cf.XVector.X) * size.X + math.abs(cf.YVector.X) * size.Y + math.abs(cf.ZVector.X) * size.Z) / 2
	local ey = (math.abs(cf.XVector.Y) * size.X + math.abs(cf.YVector.Y) * size.Y + math.abs(cf.ZVector.Y) * size.Z) / 2
	local ez = (math.abs(cf.XVector.Z) * size.X + math.abs(cf.YVector.Z) * size.Y + math.abs(cf.ZVector.Z) * size.Z) / 2
	local p = cf.Position
	return p.X - ex, p.X + ex, p.Y - ey, p.Y + ey, p.Z - ez, p.Z + ez
end

function LiftCar.build(_origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local lift = OfficePlan.Lift
	local car = lift.car
	local doorX, doorZ = lift.doorX, lift.doorZ
	local leafWidth = lift.doorWidth / 2 - 0.02
	local leafHeight = OfficePlan.DoorHeight
	local planeX = car.x1 - 0.2 -- the mirror glass's front face

	local office = workspace:FindFirstChild("Office")
	local carFolder = office and office:FindFirstChild("LiftCar", true)

	--------------------------------------------------------------------
	-- The door leaves (and their reflections), closed to begin with
	--------------------------------------------------------------------
	-- Shut, the leaves overlap a hair (and stand a hair apart in depth) so no seam of
	-- reception's light shows between them.
	local closedZ = { doorZ - leafWidth / 2 + 0.01, doorZ + leafWidth / 2 - 0.01 }
	local leafX = { doorX, doorX + 0.03 }
	local openZ = { doorZ - leafWidth / 2 - lift.doorWidth / 2 - 0.05, doorZ + leafWidth / 2 + lift.doorWidth / 2 + 0.05 }
	local leaves: { BasePart } = {}
	local reflections: { BasePart } = {}
	for index = 1, 2 do
		local leaf = SetKit.part(
			parent,
			`DoorLeaf_{index}`,
			Vector3.new(0.16, leafHeight, leafWidth),
			CFrame.new(leafX[index], leafHeight / 2, closedZ[index]),
			STEEL,
			M.Metal,
			{ reflectance = 0.1, castShadow = false }
		)
		leaves[index] = leaf
		local reflection = SetKit.part(
			parent,
			`DoorLeafReflection_{index}`,
			leaf.Size,
			SetKit.reflectFrame(planeX, leaf.CFrame),
			STEEL,
			M.Metal,
			{ reflectance = 0.1, castShadow = false }
		)
		reflections[index] = reflection
	end

	local function slide(target: { number }, seconds: number)
		for index = 1, 2 do
			local goal = CFrame.new(leafX[index], leafHeight / 2, target[index])
			scope.add(SetKit.tween(leaves[index], seconds, { CFrame = goal }))
			scope.add(SetKit.tween(reflections[index], seconds, { CFrame = SetKit.reflectFrame(planeX, goal) }))
		end
	end

	--------------------------------------------------------------------
	-- The mirror: reveal the far side, and put a reflection of the car there
	--------------------------------------------------------------------
	local hidden: { BasePart } = {}
	if office and carFolder then
		for _, descendant in ipairs(office:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name ~= "Mirror" and not descendant:IsDescendantOf(parent) then
				local x0, _, y0, _, z0, z1 = extentsOf(descendant)
				-- Wholly behind the glass, and in the lift's corridor of space.
				if x0 >= planeX - 0.02 and y0 < 13 and z0 < car.z1 + 0.5 and z1 > car.z0 - 0.5 then
					descendant.LocalTransparencyModifier = 1
					table.insert(hidden, descendant)
				end
			end
		end
		for _, child in ipairs(carFolder:GetChildren()) do
			if child:IsA("BasePart") and REFLECTED[child.Name] then
				local copy = SetKit.part(
					parent,
					`Reflection_{child.Name}`,
					child.Size,
					SetKit.reflectFrame(planeX, child.CFrame),
					child.Color,
					child.Material,
					{ reflectance = child.Reflectance, castShadow = false }
				)
				copy.Transparency = child.Transparency
			end
		end
		-- Behind the reflected doorway: reception's light, dimmed to a glow.
		local beyondX = 2 * planeX - (doorX - 1.2)
		SetKit.part(
			parent,
			"ReflectionBeyond",
			Vector3.new(0.1, leafHeight, lift.doorWidth),
			CFrame.new(beyondX, leafHeight / 2, doorZ),
			Color3.fromRGB(120, 108, 92),
			M.Neon,
			{ castShadow = false }
		)
		-- Light for the reflected room, so the avatar in it is seen.
		local lamp = SetKit.part(
			parent,
			"ReflectionLamp",
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(2 * planeX - (car.x0 + car.x1) / 2, 8.6, (car.z0 + car.z1) / 2),
			Color3.new(1, 1, 1),
			M.SmoothPlastic,
			{ transparency = 1 }
		)
		SetKit.light(lamp, "PointLight", 1.25, 13, Color3.fromRGB(255, 244, 226))
	end

	-- The avatar in the mirror: it faces the way the player looks, so turning to
	-- the glass shows their face, and looking at the doors shows their back.
	local double = SetKit.avatarDouble(parent, CFrame.new(2 * planeX - OfficePlan.Spawn.X, OfficePlan.Spawn.Y, OfficePlan.Spawn.Z))
	if double then
		double.animate(SetKit.IdleAnimation, true)
		scope.add(RunService.RenderStepped:Connect(function()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = workspace.CurrentCamera
			if not root or not root:IsA("BasePart") or not camera then
				return
			end
			local look = camera.CFrame.LookVector
			local facing = Vector3.new(look.X, 0, look.Z)
			if facing.Magnitude < 0.05 then
				return
			end
			local position, mirrored = SetKit.reflectX(planeX, root.Position, facing.Unit)
			double.place(CFrame.lookAt(position, position + mirrored))
		end))
	end

	--------------------------------------------------------------------
	-- The floor display
	--------------------------------------------------------------------
	local display = carFolder and carFolder:FindFirstChild("FloorDisplay")
	local displayLabel = display and display:FindFirstChildWhichIsA("TextLabel", true)
	local shownText = displayLabel and displayLabel.Text

	local actions: { [string]: (args: { [string]: any }?) -> () } = {
		DoorsClose = function(args)
			slide(closedZ, (args and args.time) or DEFAULT_TIME)
		end,
		DoorsOpen = function(args)
			slide(openZ, (args and args.time) or DEFAULT_TIME)
		end,
		Display = function(args)
			if displayLabel and args and args.text ~= nil then
				displayLabel.Text = tostring(args.text)
			end
		end,
		Shudder = function(args)
			CameraController.shake((args and args.amount) or 0.1, (args and args.time) or 0.7)
		end,
	}

	return {
		act = function(name: string, args: { [string]: any }?)
			local action = actions[name]
			if action then
				action(args)
			end
		end,
		destroy = function()
			scope.clean()
			for _, part in ipairs(hidden) do
				if part.Parent then
					part.LocalTransparencyModifier = 0
				end
			end
			if displayLabel and shownText then
				displayLabel.Text = shownText
			end
			if double then
				double.destroy()
			end
		end,
	}
end

return LiftCar
