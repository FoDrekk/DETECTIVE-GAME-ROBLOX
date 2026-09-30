--!strict
-- A quiet marble lobby at 12:40 AM: turnstiles, a sleepy constable, a
-- credential reader, and the cold wash of the lift bank beyond.
local SetKit = require(script.Parent:WaitForChild("SetKit"))
local Lobby = {}
local M = SetKit.M
local C = Color3.fromRGB

function Lobby.build(origin: Vector3, parent: Folder)
	local scope = SetKit.scope()
	local function at(x: number, y: number, z: number): Vector3 return origin + Vector3.new(x, y, z) end
	local function part(name: string, size: Vector3, p: Vector3, color: Color3, material: Enum.Material?)
		return SetKit.part(parent, name, size, CFrame.new(p), color, material or M.SmoothPlastic, { castShadow = true })
	end
	part("MarbleFloor", Vector3.new(72, 0.5, 58), at(0, -0.25, 0), C(101, 105, 112), M.Marble)
	part("BackWall", Vector3.new(72, 24, 1), at(0, 12, -27), C(48, 54, 64), M.Concrete)
	for x = -31, 31, 8 do
		part("WallPilaster", Vector3.new(1.1, 23, 1.4), at(x, 11.5, -26.1), C(75, 81, 92), M.Marble)
	end
	for x = -27, 27, 18 do
		local panel = SetKit.neon(parent, "WallWash", Vector3.new(10, 0.12, 0.2), CFrame.new(at(x, 19, -25.25)), C(164, 191, 225))
		SetKit.light(panel, "PointLight", 0.8, 24, C(168, 195, 232))
	end
	-- Reception podium and the raised brass turnstile lane.
	part("SecurityDesk", Vector3.new(15, 3.3, 5), at(-23, 1.65, -12), C(43, 50, 60), M.Marble)
	part("DeskTop", Vector3.new(15.5, 0.3, 5.4), at(-23, 3.45, -12), C(176, 157, 125), M.Marble)
	SetKit.sign(parent, "DeskName", CFrame.new(at(-23, 4.15, -9.22)), Vector3.new(9, 1.1, 0.1), "SECURITY  ·  LOBI", C(229, 218, 195), { panel = C(32, 39, 48), pixelsPerStud = 25 })
	local gates: { BasePart } = {}
	for x = 4, 13, 4.5 do
		local pedestal = part("Turnstile", Vector3.new(1.1, 3.5, 1.1), at(x, 1.75, -2), C(100, 106, 113), M.Metal)
		part("GateBase", Vector3.new(3.4, 0.24, 3.4), at(x, 0.2, -2), C(62, 67, 74), M.Metal)
		local arm = part("GateArm", Vector3.new(4.8, 0.16, 0.22), at(x + 1.4, 2.5, -2), C(185, 190, 197), M.Metal)
		arm.CFrame *= CFrame.Angles(0, math.rad(0), 0)
		table.insert(gates, arm)
		local reader = SetKit.neon(parent, "CardReader", Vector3.new(0.26, 0.65, 0.45), CFrame.new(at(x - 0.5, 3.15, -2)), C(38, 146, 161))
		SetKit.label(reader, Enum.NormalId.Front, "TAP", { color = C(224, 250, 255), size = 13, font = Enum.Font.GothamBold })
	end
	local gateTween: Tween? = nil
	-- Security constable, shown in profile at the desk rather than as a mannequin
	-- in the center of the frame.
	local torso = part("ConstableUniform", Vector3.new(2.4, 3.3, 1.25), at(-23, 5.2, -16), C(30, 45, 62), M.Fabric)
	local head = SetKit.ball(parent, "ConstableHead", 1.7, at(-23, 7.75, -16), C(187, 146, 117), M.SmoothPlastic)
	SetKit.ball(parent, "ConstableCap", 2.0, at(-23, 8.6, -16), C(23, 35, 49), M.Fabric)
	part("ConstableArm", Vector3.new(0.75, 2.7, 0.8), at(-24.5, 4.9, -16), C(30, 45, 62), M.Fabric)
	part("Badge", Vector3.new(0.42, 0.52, 0.1), at(-21.75, 5.7, -15.32), C(221, 181, 83), M.Metal)
	-- The printed wording is literal and legible in the close shot.
	local tap = SetKit.sign(parent, "ReaderInstruction", CFrame.new(at(8.5, 5.2, -2)), Vector3.new(8, 2.3, 0.2), "SILA IMBAS KAD\nTAP ACCESS CARD", C(177, 225, 232), { panel = C(13, 25, 34), pixelsPerStud = 26 })
	local nod = SetKit.newTween(head, 0.32, { CFrame = head.CFrame * CFrame.Angles(math.rad(14), 0, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tapGlow = SetKit.newTween(tap, 0.25, { Color = C(122, 235, 200) }, Enum.EasingStyle.Sine)
	local gateBase = gates[2].CFrame
	gateTween = SetKit.newTween(gates[2], 0.6, { CFrame = gateBase * CFrame.Angles(0, math.rad(82), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local actions = {
		ConstableNods = function() nod:Play() end,
		TapCard = function() tapGlow:Play() end,
		ReaderAccepts = function() if gateTween then gateTween:Play() end end,
	}
	scope.add(nod); scope.add(tapGlow); if gateTween then scope.add(gateTween) end
	local _ = torso
	return { act = function(name: string, _args: { [string]: any }?) local action = actions[name]; if action then action() end end, destroy = function() scope.clean() end }
end

return Lobby
