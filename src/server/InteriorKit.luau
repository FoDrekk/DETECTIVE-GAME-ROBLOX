--!strict
--[[
	InteriorKit
	Small helpers the room builders share: placements on the floor, slabs,
	interactable flavour tagging, and the interactable parts the story asks
	for. Nothing here knows about a particular room.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
local PropKit = require(script.Parent:WaitForChild("PropKit"))

local InteriorKit = {}

local M = Enum.Material

InteriorKit.NORTH = Vector3.new(0, 0, -1)
InteriorKit.SOUTH = Vector3.new(0, 0, 1)
InteriorKit.EAST = Vector3.new(1, 0, 0)
InteriorKit.WEST = Vector3.new(-1, 0, 0)

-- Floors are laid out so the base carpet's top sits at Y = 0 and every
-- floor-standing prop rests on it; room finishes are a thin decorative layer
-- 0.03 above (the smallest gap that reliably avoids z-fighting); both are
-- walkable. See OfficeInterior's floor layering.
InteriorKit.FLOOR_TOP = 0.00
InteriorKit.ROOM_TOP = 0.03

-- The top of a desk and of a counter (props rest on these).
InteriorKit.DESK_TOP = 2.62

-- A placement on the floor (or at height y) at (x, z), facing `facing`.
function InteriorKit.at(x: number, z: number, facing: Vector3, y: number?): CFrame
	local p = Vector3.new(x, y or 0, z)
	return CFrame.lookAt(p, p + facing)
end

-- A flat slab spanning x0..x1, z0..z1 with its centre at height y.
function InteriorKit.slab(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = PropKit.newPart(
		parent,
		name,
		Vector3.new(x1 - x0, thickness, z1 - z0),
		CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2),
		color,
		material
	)
	p.CastShadow = false
	return p
end

-- A folder for a room, parented under `parent`.
function InteriorKit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Tag a part as an interactable object. The text an Examine shows is case
-- data (Case001.observations), applied by OfficeRoom.finalize; evidence ids
-- come from case data too (OfficeRoom.applyEvidenceBindings).
function InteriorKit.interactable(part: BasePart, kind: string, prompt: string)
	CollectionService:AddTag(part, Interactable.TAG)
	part:SetAttribute(Interactable.AttributeName.Kind, kind)
	part:SetAttribute(Interactable.AttributeName.PromptLabel, prompt)
end

-- Tag a dressing part as an interactable flavour object.
function InteriorKit.flavour(part: BasePart, prompt: string)
	InteriorKit.interactable(part, "Examine", prompt)
end

-- An invisible box that carries an interactable over some dressing.
function InteriorKit.hotspot(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local p = PropKit.newPart(parent, name, size, cframe, PropKit.Palette.Charcoal, M.SmoothPlastic)
	p.Transparency = 1
	p.CastShadow = false
	return p
end

-- Rotate a point (x, z) about the origin by `yawDegrees` (a turn about +Y,
-- as CFrame.Angles(0, yaw, 0) would turn it), and add it to `origin`.
function InteriorKit.turn(origin: Vector3, x: number, z: number, yawDegrees: number): Vector3
	local r = math.rad(yawDegrees)
	local cosR, sinR = math.cos(r), math.sin(r)
	return origin + Vector3.new(x * cosR + z * sinR, 0, -x * sinR + z * cosR)
end

return InteriorKit
