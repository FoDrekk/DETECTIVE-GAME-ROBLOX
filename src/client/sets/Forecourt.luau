--!strict
-- Wisma Delima at 12:40 AM: one ninth-floor light, the lobby still lit, rain,
-- a patrol car's light-bar, and the investigator stepping out into the forecourt.
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
	SetKit.sign(parent, "TowerLogo", CFrame.new(at(0, 13.6, -42.5)), Vector3.new(18, 2.4, 0.3), "WISMA DELIMA", C(209, 190, 148), { panel = C(23, 31, 42), pixelsPerStud = 42 })
	-- The lobby, still lit behind its glass at ground level: the forecourt's light.
	local lobby = SetKit.neon(parent, "LobbyGlass", Vector3.new(40, 9, 0.2), CFrame.new(at(0, 4.5, -42.6)), C(214, 176, 128))
	lobby.Transparency = 0.62
	SetKit.light(lobby, "SurfaceLight", 1.4, 34, C(255, 220, 180), { face = Enum.NormalId.Front, angle = 120 })
	-- The city's glow behind the tower, so it stands against the sky.
	SetKit.gradientSky(parent, "CityGlow", CFrame.lookAt(at(0, 70, -170), at(0, 70, 0)), 520, 220, {
		{ at = 0, color = C(12, 14, 24) },
		{ at = 0.55, color = C(40, 34, 52) },
		{ at = 0.85, color = C(150, 82, 52) },
		{ at = 1, color = C(200, 110, 60) },
	})
	-- A single warm window at floor nine, framed against the dark grid.
	local ninth = SetKit.neon(parent, "NinthFloor", Vector3.new(3.5, 4.8, 0.18), CFrame.new(at(0, 92, -42.55)), C(255, 191, 108))
	SetKit.light(ninth, "SurfaceLight", 0.7, 8, C(255, 182, 104), { face = Enum.NormalId.Front, angle = 70 })
	-- Patrol sedan and red/blue reflections sweep the wet paving.
	part("PatrolBody", Vector3.new(8, 2.2, 16), at(-24, 1.7, 8), C(215, 216, 211), M.Metal)
	part("PatrolRoof", Vector3.new(6.5, 1.4, 7), at(-24, 3.4, 8), C(37, 44, 54), M.Metal)
	local red = SetKit.neon(parent, "LightRed", Vector3.new(1.7, 0.4, 0.6), CFrame.new(at(-25, 4.15, 8)), C(255, 34, 42))
	local blue = SetKit.neon(parent, "LightBlue", Vector3.new(1.7, 0.4, 0.6), CFrame.new(at(-23, 4.15, 8)), C(52, 123, 255))
	SetKit.label(part("DoorMarking", Vector3.new(4, 0.12, 2), at(-24, 2.88, 8), C(242, 240, 231), M.SmoothPlastic), Enum.NormalId.Top, "POLIS", { color = C(31, 45, 60), size = 20, font = Enum.Font.GothamBold })
	-- The investigator's car, which turns into the drive and stops by the canopy.
	-- Built facing -Z; the whole model moves with its driver value.
	local sedan = Instance.new("Model")
	sedan.Name = "ArrivingSedan"
	sedan.Parent = parent
	local body = SetKit.part(sedan, "Body", Vector3.new(7.6, 2.2, 15), CFrame.new(at(0, 1.8, 0)), C(35, 43, 54), M.SmoothPlastic)
	SetKit.part(sedan, "Roof", Vector3.new(6.5, 1.7, 7), CFrame.new(at(0, 3.7, 0.6)), C(29, 35, 44), M.SmoothPlastic)
	for _, x in ipairs({ -3, 3 }) do
		local lamp = SetKit.neon(sedan, "Headlamp", Vector3.new(1.15, 0.4, 0.18), CFrame.new(at(x, 2.05, -7.55)), C(255, 235, 191))
		SetKit.light(lamp, "SpotLight", 1.8, 30, C(255, 240, 210), { face = Enum.NormalId.Front, angle = 50 })
		SetKit.neon(sedan, "TailLamp", Vector3.new(1.15, 0.35, 0.18), CFrame.new(at(x, 2.05, 7.55)), C(200, 30, 30))
	end
	sedan.PrimaryPart = body
	local driver = Instance.new("CFrameValue")
	driver.Value = CFrame.lookAt(at(34, 1.8, 30), at(14, 1.8, -2))
	sedan:PivotTo(driver.Value)
	scope.add(driver)
	scope.add(driver.Changed:Connect(function(value: CFrame)
		sedan:PivotTo(value)
	end))
	part("EntryCanopy", Vector3.new(36, 1, 16), at(0, 12, -29), C(41, 48, 58), M.Metal)
	SetKit.neon(parent, "CanopyEdge", Vector3.new(33, 0.12, 0.25), CFrame.new(at(0, 11.4, -20.9)), C(186, 197, 209))
	for _, x in ipairs({ -11, 0, 11 }) do
		local downlight = SetKit.neon(parent, "Downlight", Vector3.new(1.2, 0.1, 1.2), CFrame.new(at(x, 11.45, -27)), C(240, 236, 226))
		SetKit.light(downlight, "SpotLight", 2, 18, C(240, 232, 218), { face = Enum.NormalId.Bottom, angle = 80 })
	end
	local redLight = SetKit.light(red, "PointLight", 1.2, 32, C(255, 35, 46))
	local blueLight = SetKit.light(blue, "PointLight", 1.2, 32, C(62, 112, 255))
	local rain = SetKit.rain(parent, CFrame.new(at(0, 44, 0)), Vector3.new(150, 0.2, 115), 90, { rate = 950, speed = 82, length = 3, slant = -3 })
	local drive = SetKit.newTween(driver, 3.2, { Value = CFrame.lookAt(at(14, 1.8, -2), at(10, 1.8, -20)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	scope.add(rain)
	scope.add(drive)
	local actions = {
		SedanArrives = function()
			drive:Play()
		end,
		-- The investigator appears at the driver's door of the stopped car and
		-- walks to the entrance.
		StepOut = function()
			local double = SetKit.avatarDouble(parent, CFrame.lookAt(at(9.6, 0, -1), at(4, 0, -20)))
			if double then
				scope.add(double.destroy)
				double.animate(SetKit.WalkAnimation, true)
				scope.add(SetKit.tween(double.root, 3, { CFrame = double.rootAt(CFrame.lookAt(at(4, 0, -16), at(0, 0, -42))) }, Enum.EasingStyle.Linear))
			end
		end,
		LightsOff = function()
			redLight.Enabled = false
			blueLight.Enabled = false
		end,
	}
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

return Forecourt
