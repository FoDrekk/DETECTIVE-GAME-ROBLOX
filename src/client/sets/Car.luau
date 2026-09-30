--!strict
-- The investigator's car. A close, warm dashboard against a wet blue city;
-- the warrant sits ready beside a lit phone and a small dispatch display.
local SetKit = require(script.Parent:WaitForChild("SetKit"))
local Car = {}
local M = SetKit.M
local C = Color3.fromRGB

function Car.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): Vector3 return origin + Vector3.new(x, y, z) end
	local function part(name: string, size: Vector3, p: Vector3, color: Color3, material: Enum.Material?)
		return SetKit.part(parent, name, size, CFrame.new(p), color, material or M.SmoothPlastic, { castShadow = true })
	end
	part("CabinFloor", Vector3.new(15, 0.4, 17), at(0, 0, 0), C(23, 26, 31), M.Fabric)
	part("Roof", Vector3.new(15, 0.5, 17), at(0, 8.4, 0), C(25, 28, 34), M.Fabric)
	part("DoorLeft", Vector3.new(0.5, 7.8, 16), at(-7.2, 4, 0), C(36, 39, 44), M.Metal)
	part("DoorRight", Vector3.new(0.5, 7.8, 16), at(7.2, 4, 0), C(36, 39, 44), M.Metal)
	-- Broad windscreen angled away toward the sodium-lit street.
	local glass = part("Windscreen", Vector3.new(13, 5.5, 0.18), at(0, 5.3, -7.6), C(66, 89, 105), M.SmoothPlastic)
	glass.CFrame *= CFrame.Angles(math.rad(-8), 0, 0)
	glass.Transparency = 0.68; glass.Reflectance = 0.1; glass.CanCollide = false
	part("StreetBeyond", Vector3.new(50, 28, 1), at(0, 9, -25), C(37, 31, 35), M.SmoothPlastic)
	for i = 1, 8 do
		local lamp = SetKit.neon(parent, "PassingLamp", Vector3.new(0.4, 7 + (i % 3), 0.4), CFrame.new(at(-23 + i * 6.5, 3.5, -24.2)), if i % 2 == 0 then C(255, 172, 89) else C(199, 209, 241))
		lamp.Transparency = 0.24
	end
	-- Dashboard and a restrained pool of instrument light.
	part("Dash", Vector3.new(15, 1.5, 3.2), at(0, 2.7, -6.1), C(30, 32, 37), M.Fabric)
	local screen, _ = SetKit.sign(parent, "DispatchScreen", CFrame.new(at(3.4, 3.55, -7.55)), Vector3.new(3.2, 1.8, 0.08), "UNIT 14\nROUTE: ROZARIO & LIM", C(118, 208, 225), { panel = C(9, 19, 26), pixelsPerStud = 28 })
	local screenGlow = SetKit.neon(parent, "ScreenGlow", Vector3.new(3.5, 1.9, 0.08), CFrame.new(at(3.4, 3.55, -7.62)), C(44, 151, 179))
	screenGlow.Transparency = 0.78
	local phone = SetKit.part(parent, "Phone", Vector3.new(1.45, 0.18, 2.55), CFrame.new(at(-3.25, 3.57, -5.95)) * CFrame.Angles(math.rad(-7), 0, math.rad(9)), C(20, 23, 28), M.Metal)
	local phoneScreen = SetKit.sign(parent, "PhoneScreen", CFrame.new(at(-3.25, 3.68, -5.95)) * CFrame.Angles(math.rad(-7), 0, math.rad(9)), Vector3.new(1.28, 0.04, 2.25), "NORA CALLING", C(168, 224, 238), { panel = C(15, 37, 48), pixelsPerStud = 18 })
	phoneScreen.Transparency = 1
	local warrant = SetKit.part(parent, "WarrantCard", Vector3.new(3.1, 0.12, 2.1), CFrame.new(at(0.5, 3.55, -5.4)) * CFrame.Angles(0, math.rad(-8), math.rad(1)), C(222, 215, 191), M.Cardboard)
	SetKit.label(warrant, Enum.NormalId.Top, "AUTHORISED ENTRY\nINVESTIGATION UNIT 14\nKOTA ARWANA", { color = C(32, 40, 47), size = 16, font = Enum.Font.GothamBold })
	-- Steering wheel, seat backs and a soft dashboard glow make the frame read as
	-- an occupied car rather than a floating collection of props.
	SetKit.cylinder(parent, "SteeringWheel", 0.22, 2.7, CFrame.new(at(-3.3, 3.65, -3.8)) * CFrame.Angles(0, 0, math.pi / 2), C(20, 22, 25), M.Rubber)
	part("SeatBack", Vector3.new(4.6, 5.3, 1), at(-3.3, 4.4, 1.5), C(35, 37, 42), M.Leather)
	local dashLamp = SetKit.neon(parent, "DashGlow", Vector3.new(13, 0.12, 0.35), CFrame.new(at(0, 3.53, -7.68)), C(245, 150, 75))
	SetKit.light(dashLamp, "PointLight", 0.55, 12, C(255, 169, 103))
	local wipers: { BasePart } = {}
	for i, x in ipairs({ -3.5, 3.5 }) do
		local blade = part(`Wiper_{i}`, Vector3.new(0.12, 0.13, 5.6), at(x, 3.35, -7.2), C(17, 19, 23), M.Rubber)
		blade.CFrame *= CFrame.Angles(0, 0, math.rad(if i == 1 then -12 else 12))
		wipers[i] = blade
	end
	local rain = SetKit.rain(parent, CFrame.new(at(0, 12, -10)), Vector3.new(18, 0.2, 14), 28, { rate = 380, speed = 60, length = 2.2, slant = -2 })
	local ring = SetKit.newTween(phoneScreen, 0.4, { Transparency = 0 }, Enum.EasingStyle.Sine)
	local answer = SetKit.newTween(phone, 0.22, { CFrame = phone.CFrame * CFrame.Angles(0, 0, math.rad(8)) }, Enum.EasingStyle.Quad)
	local wiperTweens = {}
	for i, blade in ipairs(wipers) do
		local base = blade.CFrame
		local angle = if i == 1 then math.rad(34) else math.rad(-34)
		local tw = SetKit.newTween(blade, 0.65, { CFrame = base * CFrame.Angles(0, 0, angle) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		table.insert(wiperTweens, tw)
	end
	local actions = {
		PhoneRing = function() ring:Play() end,
		Answer = function() answer:Play(); screen.Name = "DispatchScreenActive" end,
		WipersOn = function() for _, tw in ipairs(wiperTweens) do tw:Play() end end,
		Notify = function() screen.Name = "DispatchIncomingCall" end,
	}
	scope.add(rain); scope.add(ring); scope.add(answer)
	for _, tw in ipairs(wiperTweens) do scope.add(tw) end
	return { act = function(name: string, _args: { [string]: any }?) local action = actions[name]; if action then action() end end, destroy = function() scope.clean() end }
end

return Car
