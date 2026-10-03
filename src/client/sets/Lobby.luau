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
	-- The lift bank the walk arrives at: three bays of brushed steel, a floor
	-- arrow over each, the centre bay the one that serves this arrival.
	for bay, x in ipairs({ 0.5, 8.5, 16.5 }) do
		part(`LiftFrame_{bay}`, Vector3.new(6.4, 12.4, 0.7), at(x, 6.2, -26.6), C(64, 70, 80), M.Metal)
		local isCentre = bay == 2
		local doorColor = if isCentre then C(96, 104, 118) else C(52, 58, 68)
		local left = part(`LiftDoorL_{bay}`, Vector3.new(2.9, 11.4, 0.18), at(x - 1.5, 5.7, -26.2), doorColor, M.Metal)
		local right = part(`LiftDoorR_{bay}`, Vector3.new(2.9, 11.4, 0.18), at(x + 1.5, 5.7, -26.2), doorColor, M.Metal)
		left.Reflectance, right.Reflectance = 0.18, 0.18
		if isCentre then
			-- The bay's floor indicator: a soft "9" over the doors that are
			-- about to take the investigator up.
			local arrow = SetKit.neon(parent, "LiftArrow", Vector3.new(1.1, 1.1, 0.1), CFrame.new(at(x, 13.1, -26.2)), C(120, 208, 190))
			SetKit.label(arrow, Enum.NormalId.Front, "9", { color = C(224, 250, 245), size = 42, font = Enum.Font.GothamBold, lightInfluence = 0 })
		end
	end
	-- The entrance doors behind the arrival: tall dark glass in a steel frame,
	-- the wet night faintly in them.
	local entranceDoors = part("EntranceDoors", Vector3.new(14, 11, 0.25), at(1, 5.5, 28.5), C(18, 26, 38), M.Glass)
	entranceDoors.Transparency = 0.45
	part("EntranceFrame", Vector3.new(15, 11.6, 0.5), at(1, 5.8, 28.5), C(64, 70, 80), M.Metal)
	for _, x in ipairs({ -2.4, 1, 4.4 }) do
		part("EntranceMullion", Vector3.new(0.22, 10.8, 0.4), at(x, 5.5, 28.4), C(58, 64, 74), M.Metal)
	end
	-- Entrance matting, wet footprints on the marble's shine.
	local matting = part("Matting", Vector3.new(13, 0.06, 4), at(1, 0.03, 25), C(30, 32, 36), M.Fabric)
	matting.CastShadow = false
	for x = -31, 31, 8 do
		part("WallPilaster", Vector3.new(1.1, 23, 1.4), at(x, 11.5, -26.1), C(75, 81, 92), M.Marble)
	end
	for x = -27, 27, 18 do
		local panel = SetKit.neon(parent, "WallWash", Vector3.new(10, 0.12, 0.2), CFrame.new(at(x, 19, -25.25)), C(164, 191, 225))
		SetKit.light(panel, "PointLight", 0.8, 24, C(168, 195, 232))
	end
	-- A ceiling: indoors, so the look's Ambient (not the night's OutdoorAmbient) lights it.
	part("Ceiling", Vector3.new(72, 1, 58), at(0, 16.5, 0), C(70, 74, 82), M.Concrete)
	-- Cold overhead light on the gates, the security desk and the lift bank.
	for _, spot in ipairs({ { 8.5, -2 }, { -23, -12 }, { 8.5, -14 }, { 8.5, -22 } }) do
		local panel = SetKit.neon(parent, "CeilingPanel", Vector3.new(6, 0.12, 2.4), CFrame.new(at(spot[1], 15, spot[2])), C(226, 236, 248))
		SetKit.light(panel, "SpotLight", 1.8, 24, C(224, 234, 248), { face = Enum.NormalId.Bottom, angle = 90 })
	end
	-- Reception podium and the raised brass turnstile lane.
	part("SecurityDesk", Vector3.new(15, 3.3, 5), at(-23, 1.65, -12), C(43, 50, 60), M.Marble)
	part("DeskTop", Vector3.new(15.5, 0.3, 5.4), at(-23, 3.45, -12), C(176, 157, 125), M.Marble)
	SetKit.sign(parent, "DeskName", CFrame.new(at(-23, 4.15, -9.22)), Vector3.new(9, 1.1, 0.1), "SECURITY  ·  LOBBY", C(229, 218, 195), { panel = C(32, 39, 48), pixelsPerStud = 25 })
	-- Wet-night arrival: an umbrella stand by the doors, and a directory
	-- naming the destination floor.
	local stand = part("UmbrellaStand", Vector3.new(1.2, 2.2, 1.2), at(-33, 1.1, 8), C(52, 56, 62), M.Metal)
	stand.CastShadow = false
	for i, shade in ipairs({ C(120, 30, 32), C(30, 60, 90) }) do
		part("Umbrella", Vector3.new(0.18, 2.6, 0.18), at(-33.3 + i * 0.5, 2.6, 8), shade, M.Fabric).CastShadow = false
	end
	SetKit.sign(parent, "Directory", CFrame.new(at(-8, 5.5, -26.4)), Vector3.new(10, 3, 0.2), "LEVEL 9\nROZARIO & LIM", C(229, 218, 195), { panel = C(32, 39, 48), pixelsPerStud = 25 })
	local gates: { BasePart } = {}
	for x = 4, 13, 4.5 do
		local pedestal = part("Turnstile", Vector3.new(1.1, 3.5, 1.1), at(x, 1.75, -2), C(100, 106, 113), M.Metal)
		part("GateBase", Vector3.new(3.4, 0.24, 3.4), at(x, 0.2, -2), C(62, 67, 74), M.Metal)
		local arm = part("GateArm", Vector3.new(4.8, 0.16, 0.22), at(x + 1.4, 2.5, -2), C(185, 190, 197), M.Metal)
		table.insert(gates, arm)
		local reader = SetKit.neon(parent, "CardReader", Vector3.new(0.26, 0.65, 0.45), CFrame.new(at(x - 0.5, 3.15, -2)), C(38, 146, 161))
		SetKit.label(reader, Enum.NormalId.Front, "TAP", { color = C(224, 250, 255), size = 13, font = Enum.Font.GothamBold })
	end
	-- Security constable: a dressed R15 figure at the desk, falling back to the
	-- block figure when the client cannot build one.
	local constable = SetKit.figureDouble(parent, CFrame.lookAt(at(-23, 0, -16), at(-18, 0, -16)), {
		shirt = C(30, 45, 62),
		pants = C(26, 30, 40),
		skin = C(187, 146, 117),
		headgear = "cap",
		headgearColor = C(23, 35, 49),
		patch = "badge",
		patchColor = C(221, 181, 83),
	})
	if constable then
		scope.add(function() constable.destroy() end)
	end
	local head: BasePart? = nil
	if not constable then
		part("ConstableUniform", Vector3.new(2.4, 3.3, 1.25), at(-23, 5.2, -16), C(30, 45, 62), M.Fabric)
		head = SetKit.ball(parent, "ConstableHead", 1.7, at(-23, 7.75, -16), C(187, 146, 117), M.SmoothPlastic)
		SetKit.ball(parent, "ConstableCap", 2.0, at(-23, 8.6, -16), C(23, 35, 49), M.Fabric)
		part("ConstableArm", Vector3.new(0.75, 2.7, 0.8), at(-24.5, 4.9, -16), C(30, 45, 62), M.Fabric)
		part("Badge", Vector3.new(0.42, 0.52, 0.1), at(-21.75, 5.7, -15.32), C(221, 181, 83), M.Metal)
	end
	-- The printed wording is literal and legible in the close shot.
	local tap = SetKit.sign(parent, "ReaderInstruction", CFrame.new(at(8.5, 5.2, -2)), Vector3.new(8, 2.3, 0.2), "TAP ACCESS CARD", C(177, 225, 232), { panel = C(13, 25, 34), pixelsPerStud = 26 })
	-- The floor's top is y = 0.
	local detective = SetKit.avatarDouble(parent, CFrame.lookAt(at(1, 0, 7), at(8, 0, -2)))
	local approach: Tween? = nil
	local passGate: Tween? = nil
	if detective then
		detective.animate(SetKit.WalkAnimation, true)
		approach = SetKit.newTween(detective.root, 1.8, { CFrame = detective.rootAt(CFrame.lookAt(at(5.8, 0, 1.2), at(8, 0, -2))) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		-- The walk ends under the centre lift bay, at the doors that will take
		-- the investigator up: the cut to the lift car is the same door.
		passGate = SetKit.newTween(detective.root, 2.6, { CFrame = detective.rootAt(CFrame.lookAt(at(8.5, 0, -21), at(8.5, 0, -26))) }, Enum.EasingStyle.Linear)
		scope.add(function() detective.destroy() end)
	end
	local nod: Tween? = nil
	if head then
		nod = SetKit.newTween(head, 0.32, { CFrame = head.CFrame * CFrame.Angles(math.rad(14), 0, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end
	local tapGlow = SetKit.newTween(tap, 0.25, { Color = C(122, 235, 200) }, Enum.EasingStyle.Sine)
	local readerGui = tap:FindFirstChildWhichIsA("SurfaceGui")
	local readerLabel = readerGui and readerGui:FindFirstChildWhichIsA("TextLabel")
	local gateTween = SetKit.newTween(gates[2], 0.6, { CFrame = gates[2].CFrame * CFrame.Angles(0, math.rad(82), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local actions = {
		ConstableNods = function()
			if constable then
				constable.pose({ Neck = CFrame.Angles(math.rad(16), 0, 0) })
			elseif nod then
				nod:Play()
			end
		end,
		TapCard = function()
			tapGlow:Play()
			if approach then approach:Play() end
		end,
		ReaderAccepts = function()
			if readerLabel then readerLabel.Text = "ACCESS GRANTED  ·  12:38 AM" end
			gateTween:Play()
			if passGate then passGate:Play() end
		end,
	}
	if nod then
		scope.add(nod)
	end
	scope.add(tapGlow)
	scope.add(gateTween)
	if approach then scope.add(approach) end
	if passGate then scope.add(passGate) end
	return { act = function(name: string, _args: { [string]: any }?) local action = actions[name]; if action then action() end end, destroy = function() scope.clean() end }
end

return Lobby
