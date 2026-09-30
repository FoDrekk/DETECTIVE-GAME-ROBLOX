--!strict
--[[
	The records room: Daniel's private archive, reached through his office.
	File cabinets along the south wall (the first holds the partnership file),
	shelving on the north wall (one framed photograph lies face down on a
	shelf), archive boxes stacked on the cabinets. The middle of the room is
	left clear: it is a place to stand and read.

	FileCabinet_1 and Shelf_Frame are interactable by name; the case binds the
	Partnership Drawer and the Face-Down Photo to them (bindTo).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local Archive = {}

local P = PropKit.Palette
local M = Enum.Material
local at, NORTH, SOUTH, EAST, WEST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.EAST, Kit.WEST

-- A two-drawer file cabinet against the wall, its front facing `facing`.
local function fileCabinet(parent: Instance, name: string, position: Vector3, facing: Vector3, label: string?): BasePart
	local cf = CFrame.lookAt(position, position + facing)
	local body = PropKit.newPart(parent, name, Vector3.new(2.2, 4.2, 1.8), cf * CFrame.new(0, 2.1, 0), P.Graphite, M.Metal)
	body.CanCollide = true
	body.CanQuery = true
	for i, y in ipairs({ 3.0, 1.2 }) do
		local face = PropKit.newPart(parent, `{name}_Drawer{i}`, Vector3.new(1.9, 1.6, 0.1), cf * CFrame.new(0, y, -0.93), Color3.fromRGB(96, 98, 104), M.Metal)
		face.CastShadow = false
		PropKit.newPart(parent, `{name}_Handle{i}`, Vector3.new(0.6, 0.07, 0.1), cf * CFrame.new(0, y + 0.35, -1.0), P.Steel, M.Metal)
		local slot = PropKit.newPart(parent, `{name}_Label{i}`, Vector3.new(0.9, 0.3, 0.02), cf * CFrame.new(0, y + 0.08, -0.99), P.Paper, M.SmoothPlastic)
		slot.CastShadow = false
		if i == 1 and label then
			PropKit.label(slot, Enum.NormalId.Front, label, { color = Color3.fromRGB(30, 30, 44), font = Enum.Font.PermanentMarker, padding = 2 })
		end
	end
	return body
end

function Archive.build(interior: Instance)
	local rect = OfficePlan.rect("Archive")
	local room = Kit.folder(interior, "Records")

	-- Cabinets along the south wall.
	local z = rect.z1 - 0.9
	local cabinet = fileCabinet(room, "FileCabinet_1", Vector3.new(-13.4, 0, z), NORTH, "R&L\nPARTNERSHIP")
	Kit.flavour(cabinet, "Examine Filing Cabinet")
	fileCabinet(room, "FileCabinet_2", Vector3.new(-11.1, 0, z), NORTH, "ACCOUNTS")
	fileCabinet(room, "FileCabinet_3", Vector3.new(-8.8, 0, z), NORTH, "STAFF")

	-- Shelving on the north wall; the shelf is the interactable, over the whole
	-- unit. One framed photograph lies face down on a shelf.
	local shelvingCF = at(-11.0, rect.z0 + 0.6, SOUTH)
	PropKit.shelving(room, shelvingCF, 8, 7, 4, 5, { depth = 1.2 })
	local frame = Kit.hotspot(room, "Shelf_Frame", Vector3.new(8, 7, 1.2), shelvingCF * CFrame.new(0, 3.5, 0))
	frame.CanQuery = true
	Kit.flavour(frame, "Examine Shelves")
	local photo = PropKit.newPart(room, "PhotoFrame", Vector3.new(0.95, 0.08, 1.2), CFrame.new(-8.3, 5.28, rect.z0 + 0.95) * CFrame.Angles(0, math.rad(12), 0), P.WalnutDark, M.Wood)
	photo.CastShadow = false
	local backing = PropKit.newPart(room, "PhotoBacking", Vector3.new(0.8, 0.02, 1.05), photo.CFrame * CFrame.new(0, 0.05, 0), Color3.fromRGB(176, 150, 112), M.Cardboard)
	backing.CastShadow = false

	-- Archive boxes on top of the cabinets.
	local boxes = {
		{ Vector3.new(1.8, 1.4, 1.5), Vector3.new(-11.1, 4.9, z) },
		{ Vector3.new(1.6, 1.3, 1.5), Vector3.new(-8.8, 4.85, z) },
		{ Vector3.new(1.6, 1.2, 1.4), Vector3.new(-8.9, 6.1, z) },
	}
	for i, spec in ipairs(boxes) do
		PropKit.newPart(room, `Box_{i}`, spec[1], CFrame.new(spec[2]) * CFrame.Angles(0, math.rad(i * 9), 0), Color3.fromRGB(176, 150, 112), M.Cardboard)
	end
end

return Archive
