--!strict
-- The Rozario & Lim tower at 12:40 AM: one ninth-floor light, rain, a
-- low police light-bar, and the investigator stepping out into the forecourt.
local SetKit = require(script.Parent:WaitForChild("SetKit"))
local Forecourt = {}
local M = SetKit.M
local C = Color3.fromRGB

function Forecourt.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): Vector3 return origin + Vector3.new(x, y, z) end
	local function part(name: string, size: Vector3, p: Vector3, color: Color3, material: Enum.Material?)
		return SetKit.part(parent, name, size, CFrame.new(p), color, material or M.SmoothPlastic, { castShadow = true })
	end
	part("Forecourt", Vector3.new(150, 0.5, 105), at(0, -0.25, 0), C(29, 32, 40), M.Asphalt).Reflectance = 0.24
	part("Tower", Vector3.new(54, 112, 22), at(0, 56, -54), C(35, 42, 55), M.Concrete)
	for y = 12, 100, 10 do
		for x = -22, 22, 8 do
			local lit = math.abs(y - 92) < 0.5 and math.abs(x) < 1
			local pane = part("TowerWindow", Vector3.new(3.6, 4.5, 0.12), at(x, y, -42.7), if lit then C(255, 202, 122) else C(21, 31, 43), if lit then M.Neon else M.Glass)
			pane.Transparency = if lit then 0 else 0.25
		end
	end
	SetKit.sign(parent, "TowerLogo", CFrame.new(at(0, 8, -42.5)), Vector3.new(18, 3, 0.3), "ROZARIO & LIM", C(209, 190, 148), { panel = C(23, 31, 42), pixelsPerStud = 42 })
	-- A single warm window at floor nine, framed against the dark grid.
	local ninth = SetKit.neon(parent, "NinthFloor", Vector3.new(3.5, 4.8, 0.18), CFrame.new(at(0, 92, -42.55)), C(255, 191, 108))
	SetKit.light(ninth, "SurfaceLight", 0.7, 8, C(255, 182, 104), { face = Enum.NormalId.Front, angle = 70 })
	-- Patrol sedan and red/blue reflections sweep the wet paving.
	part("PatrolBody", Vector3.new(8, 2.2, 16), at(-24, 1.7, 8), C(215, 216, 211), M.Metal)
	part("PatrolRoof", Vector3.new(6.5, 1.4, 7), at(-24, 3.4, 8), C(37, 44, 54), M.Metal)
	local red = SetKit.neon(parent, "LightRed", Vector3.new(1.7, 0.4, 0.6), CFrame.new(at(-25, 4.15, 8)), C(255, 34, 42))
	local blue = SetKit.neon(parent, "LightBlue", Vector3.new(1.7, 0.4, 0.6), CFrame.new(at(-23, 4.15, 8)), C(52, 123, 255))
	SetKit.label(part("DoorMarking", Vector3.new(4, 0.12, 2), at(-24, 2.88, 8), C(242, 240, 231), M.SmoothPlastic), Enum.NormalId.Top, "POLIS", { color = C(31, 45, 60), size = 20, font = Enum.Font.GothamBold })
	local taxi = part("ArrivingSedan", Vector3.new(8, 2.2, 16), at(30, 1.8, 8), C(35, 43, 54), M.SmoothPlastic)
	part("EntryCanopy", Vector3.new(36, 1, 16), at(0, 12, -29), C(41, 48, 58), M.Metal)
	SetKit.neon(parent, "CanopyEdge", Vector3.new(33, 0.12, 0.25), CFrame.new(at(0, 11.4, -20.9)), C(186, 197, 209))
	local double = SetKit.avatarDouble(parent, CFrame.lookAt(at(19, 2.2, 7), at(0, 2.2, -15)))
	if double then scope.add(function() double.destroy() end) end
	local redLight = SetKit.light(red, "PointLight", 1.2, 32, C(255, 35, 46))
	local blueLight = SetKit.light(blue, "PointLight", 1.2, 32, C(62, 112, 255))
	local rain = SetKit.rain(parent, CFrame.new(at(0, 44, 0)), Vector3.new(150, 0.2, 115), 90, { rate = 950, speed = 82, length = 3, slant = -3 })
	local drive = SetKit.newTween(taxi, 3.2, { CFrame = CFrame.new(at(8, 1.8, -12)) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local walk: Tween? = nil
	local actions = {
		SedanArrives = function() drive:Play() end,
		StepOut = function()
			if double then
				double.animate(SetKit.WalkAnimation, false)
				walk = SetKit.newTween(double.root, 2.5, { CFrame = CFrame.lookAt(at(12, 2.2, -15), at(0, 2.2, -42)) }, Enum.EasingStyle.Linear)
				walk:Play(); scope.add(walk)
			end
		end,
		LightsOff = function() redLight.Enabled = false; blueLight.Enabled = false end,
	}
	scope.add(rain); scope.add(drive)
	return { act = function(name: string, _args: { [string]: any }?) local action = actions[name]; if action then action() end end, destroy = function() scope.clean() end }
end

return Forecourt
