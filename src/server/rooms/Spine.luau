--!strict
--[[
	The corridor: the long axis of the floor, from the entrance at the south end
	to the window at the north end, where Meera stands looking out at the city.
	Wide enough to walk two abreast; the meeting room's glass on one side and
	the pantry's pass-through on the other. Planters flank the window, a bench
	waits by the records wall, and the entrance hall at the south end has its
	doormat, umbrella stand, exit sign and badge reader.

	Signage (the badge reader, the quiet-room plate, the no-smoking notice) lives in
	its own folder so a baked place can be patched (OfficeInterior.patchSignage).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local Spine = {}

local M = Enum.Material
local at, NORTH, SOUTH, EAST, WEST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.EAST, Kit.WEST

function Spine.build(interior: Instance)
	local rect = OfficePlan.rect("Spine")
	local room = Kit.folder(interior, "Corridor")

	-- The window end: planters either side, a bench along the records wall.
	PropKit.planter(room, at(rect.x1 - 0.8, rect.z0 + 1.6, EAST), 3.2)
	PropKit.planter(room, at(rect.x0 + 0.8, rect.z0 + 1.6, WEST), 3.2)
	PropKit.bench(room, at(rect.x0 + 1.0, -22.5, EAST), 4.5)
	PropKit.framedArt(room, at(rect.x0 - 0.05, -21.0, EAST, 6.4), 3.4, 2.4, 41)

	-- Along the meeting room's glass.
	PropKit.planter(room, at(rect.x1 - 0.8, -11.0, EAST), 3.2)
	PropKit.plant(room, at(rect.x0 + 0.8, -6.4, EAST), 0.8, "blades")

	-- The pantry's neighbour: a fire extinguisher by the records wall.
	PropKit.fireExtinguisher(room, at(rect.x0 - 0.05, -19.0, EAST))

	-- The entrance hall.
	local z = rect.z1
	Kit.slab(room, "Doormat", -3.4, 3.4, z - 2.4, z - 0.2, Kit.ROOM_TOP + 0.01, 0.02, Color3.fromRGB(36, 36, 38), M.Fabric)
	PropKit.exitSign(room, at(0, z - 0.05, NORTH, 11.2))
	PropKit.plant(room, at(rect.x0 + 0.9, z - 0.9, NORTH), 0.9, "tree")
	PropKit.umbrellaStand(room, at(rect.x1 - 0.9, z - 0.9, NORTH), { Color3.fromRGB(28, 30, 36), Color3.fromRGB(90, 24, 30) })

	-- The wayfinding above the pantry's pass-through.
	PropKit.sign(room, at(rect.x0 - 0.05, -13, EAST, 10.2), "PANTRY", Vector2.new(1.8, 0.45))
end

-- Small Malaysian office signage: environment only, no gameplay, nothing
-- tagged. Built into its own folder so a baked place can be patched with
-- OfficeInterior.patchSignage() instead of a full re-bake.
function Spine.signage(interior: Instance)
	local room = Kit.folder(interior, "Signage")
	local rect = OfficePlan.rect("Spine")
	local z = rect.z1

	-- "Tap access card" beside the suite entrance. The quiet-room directory
	-- is beside the lift call button in Reception, so the entry itself cannot
	-- be mistaken for a prayer-room door.
	PropKit.sign(room, at(rect.x1 - 0.55, z - 0.05, NORTH, 4.5), "Tap access card", Vector2.new(1.3, 0.34))

	-- "NO SMOKING" by the extinguisher.
	PropKit.sign(room, at(rect.x0 - 0.05, -20.6, EAST, 4.4), "NO SMOKING", Vector2.new(2.0, 0.42), {
		plate = Color3.fromRGB(232, 232, 226),
		color = Color3.fromRGB(170, 30, 30),
	})

	-- "VISITORS' BOOK": a small placard on a flat foot on the
	-- reception counter, in the gap between the printout and the camera
	-- monitor (which hides the book itself from the visitors' side).
	local ink = Color3.fromRGB(34, 36, 40)
	local desk = require(script.Parent:WaitForChild("Reception")).DESK
	local plate = PropKit.newPart(room, "BookPlate", Vector3.new(0.86, 0.28, 0.04), at(desk.X + 0.1, desk.Z + 0.55, SOUTH, 3.26 + 0.04 + 0.14), ink, M.Metal)
	PropKit.label(plate, Enum.NormalId.Front, "VISITORS' BOOK", {
		color = Color3.fromRGB(214, 190, 138),
		font = Enum.Font.GothamBold,
		padding = 3,
	})
	PropKit.newPart(room, "BookFoot", Vector3.new(0.86, 0.04, 0.24), CFrame.new(desk.X + 0.1, 3.26 + 0.02, desk.Z + 0.55), ink, M.Metal)
end

return Spine
