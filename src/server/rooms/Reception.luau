--!strict
--[[
	Reception, where the lift opens. A walnut desk with a stone top and the
	firm's name on its fascia, the guard's chair behind it (and his flask on the
	counter), the visitors' book, a waiting area with a sofa and a coffee table
	by the corridor, the firm's name lit on the east wall, and the lift's call
	panel beside the car's doors.

	The counter's evidence (the printed badge log, the camera monitor) is case
	data (Case001.propPlacement); this room keeps their stretches of counter
	clear. Sam waits beside the desk (Case001.npcPlacement), turned toward the
	lift.

	ReceptionDesk, GuardFlask and ElevatorPanel are interactable by name.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local Reception = {}

local P = PropKit.Palette
local M = Enum.Material
local at, NORTH, SOUTH, EAST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.EAST

-- The desk's centre. Everything on the counter is placed from it, and Case001
-- puts the printout and the camera monitor on it.
Reception.DESK = Vector3.new(17, 0, 15)
-- The counter's surface.
local COUNTER = 3.26

function Reception.build(interior: Instance)
	local rect = OfficePlan.rect("Reception")
	local room = Kit.folder(interior, "Reception")
	local d = Reception.DESK

	-- The desk: walnut body, stone top, and a fascia with the firm's name on the
	-- visitors' side (south, facing the entrance).
	local desk = PropKit.newPart(room, "ReceptionDesk", Vector3.new(6, 3.2, 2), CFrame.new(d.X, 1.6, d.Z), P.WalnutDark, M.Wood)
	desk.CanCollide = true
	desk.CanQuery = true
	Kit.flavour(desk, "Examine Reception Desk")
	PropKit.newPart(room, "CounterTop", Vector3.new(6.2, 0.06, 2.2), CFrame.new(d.X, 3.23, d.Z), Color3.fromRGB(52, 54, 58), M.Granite)
	local fascia = PropKit.newPart(room, "ReceptionPanel", Vector3.new(6.2, 3.0, 0.14), CFrame.new(d.X, 1.6, d.Z + 1.08), P.Walnut, M.WoodPlanks)
	PropKit.label(fascia, Enum.NormalId.Back, "ROZARIO & LIM", {
		color = Color3.fromRGB(206, 176, 112),
		font = Enum.Font.GothamBold,
		pixelsPerStud = 50,
		size = 30,
	})

	-- The guard's chair behind the desk, his flask on the counter.
	PropKit.officeChair(room, at(d.X + 0.2, d.Z - 2.3, SOUTH), { yaw = -20 })
	local flask = PropKit.newPart(room, "GuardFlask", Vector3.new(0.9, 0.32, 0.32), CFrame.new(d.X - 1.9, COUNTER + 0.45, d.Z - 0.45) * CFrame.Angles(0, 0, math.rad(90)), P.Steel, M.Metal)
	flask.Shape = Enum.PartType.Cylinder
	flask.Reflectance = 0.1
	flask.CanQuery = true
	PropKit.newPart(room, "FlaskCap", Vector3.new(0.14, 0.34, 0.34), CFrame.new(d.X - 1.9, COUNTER + 0.97, d.Z - 0.45) * CFrame.Angles(0, 0, math.rad(90)), P.LeatherBlack, M.SmoothPlastic).Shape = Enum.PartType.Cylinder
	Kit.flavour(flask, "Examine Flask")
	PropKit.newPart(room, "VisitorBook", Vector3.new(1.1, 0.1, 0.8), CFrame.new(d.X + 2.3, COUNTER + 0.05, d.Z + 0.5) * CFrame.Angles(0, math.rad(-8), 0), Color3.fromRGB(96, 30, 34), M.Leather)
	PropKit.bin(room, at(d.X + 3.9, d.Z - 1.7, NORTH))

	-- The firm's name on the east wall, lit from below.
	local logoZ = 13.75
	local logo = PropKit.newPart(room, "LogoWall", Vector3.new(0.2, 5, 8.5), CFrame.new(rect.x1 - 0.1, 5.6, logoZ), P.Walnut, M.WoodPlanks)
	PropKit.label(logo, Enum.NormalId.Left, "ROZARIO & LIM\n<font size=\"22\">DESIGN SDN. BHD. · EST. 2010</font>", {
		color = Color3.fromRGB(214, 184, 118),
		font = Enum.Font.GothamBold,
		pixelsPerStud = 50,
		size = 50, -- "ROZARIO & LIM" is longer than the old name: one line on this wall
		lightInfluence = 0.4,
		lineHeight = 1.1,
	})
	local logoText = (logo:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass("TextLabel")
	if logoText then
		logoText.RichText = true
	end
	local wash = PropKit.newPart(room, "LogoWash", Vector3.new(0.3, 0.2, 8), CFrame.new(rect.x1 - 0.35, 2.95, logoZ), P.Charcoal, M.Metal)
	PropKit.light(wash, "SpotLight", 1.2, 10, P.WarmLight, { face = Enum.NormalId.Top, angle = 70, shadows = false })

	-- The lift's call panel, on the reception side of its wall, beside the doors.
	local panelZ = OfficePlan.Lift.doorZ + OfficePlan.Lift.doorWidth / 2 + 1.05
	local faceX = OfficePlan.Lift.doorX - OfficePlan.WallThickness / 2
	local callPanel = PropKit.newPart(room, "ElevatorPanel", Vector3.new(0.06, 0.9, 0.45), CFrame.new(faceX - 0.03, 3.6, panelZ), P.Steel, M.Metal)
	callPanel.CanQuery = true
	Kit.flavour(callPanel, "Examine Lift")
	local button = PropKit.newPart(room, "CallButton", Vector3.new(0.04, 0.18, 0.18), CFrame.new(faceX - 0.08, 3.6, panelZ), Color3.fromRGB(255, 196, 120), M.Neon)
	button.Shape = Enum.PartType.Cylinder
	button.CFrame = CFrame.new(faceX - 0.08, 3.6, panelZ)

	-- Waiting area by the corridor.
	PropKit.sofa(room, at(11.5, rect.z1 - 1.45, NORTH), 6, P.Fabric, M.Fabric)
	PropKit.coffeeTable(room, at(11.5, 22.3, NORTH), 3.8, 2.2)
	PropKit.paperStack(room, at(11.7, 22.0, NORTH, 1.26) * CFrame.Angles(0, math.rad(12), 0), 3)
	PropKit.armchair(room, at(rect.x0 + 1.5, 21.8, EAST), P.FabricTeal)
	PropKit.floorLamp(room, at(rect.x0 + 1.1, rect.z1 - 0.9, EAST), true)
	PropKit.plant(room, at(rect.x0 + 1.0, rect.z0 + 1.2, EAST), 0.9, "tree")
	PropKit.plant(room, at(rect.x1 - 1.0, rect.z0 + 1.2, EAST), 0.9, "tree")
end

return Reception
