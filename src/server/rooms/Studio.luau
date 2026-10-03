--!strict
--[[
	The studio: where a design firm actually works. One long table for
	drawings and samples with chairs tucked in, a wall of material samples on
	the east side, a pin-up board on the meeting room's wall (the notices
	nobody took down: the drinks that were cancelled, the rota, the lost
	scarf), a copier and the water cooler by the reception wall. Open to the
	corridor behind a low glass screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local Studio = {}

local P = PropKit.Palette
local M = Enum.Material
local at, NORTH, SOUTH, WEST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.WEST

function Studio.build(interior: Instance)
	local rect = OfficePlan.rect("Studio")
	local room = Kit.folder(interior, "Studio")

	-- The worktable, and its chairs.
	PropKit.meetingTable(room, at(20, 0, SOUTH), 10, 4.2)
	for _, x in ipairs({ 17, 23 }) do
		PropKit.sideChair(room, at(x, -3.3, SOUTH), { upholstery = P.FabricWarm })
		PropKit.sideChair(room, at(x, 3.3, NORTH), { upholstery = P.FabricWarm })
	end
	PropKit.paperStack(room, at(18, 0.4, SOUTH, 2.6), 5)
	PropKit.paperStack(room, at(22.0, -0.6, SOUTH, 2.6) * CFrame.Angles(0, math.rad(20), 0), 3)
	PropKit.mug(room, at(20.2, 1.0, SOUTH, 2.6), Color3.fromRGB(150, 60, 50))

	-- Material samples along the east wall.
	PropKit.shelving(room, at(rect.x1 - 0.6, 0, WEST), 10, 7, 4, 17, { depth = 1.1, sparse = true })

	-- The pin-up board on the meeting room's wall, with what was left up.
	local wallZ = rect.z0
	local board = PropKit.newPart(room, "Noticeboard", Vector3.new(5, 3, 0.12), CFrame.new(14, 6.2, wallZ + 0.06), Color3.fromRGB(150, 116, 80), M.Cardboard)
	board.CastShadow = false
	type Note = { x: number, y: number, text: string, color: Color3, tilt: number }
	local notes: { Note } = {
		{ x = -1.6, y = 0.6, text = "FIRE DRILL\nThursday 10:00", color = Color3.fromRGB(236, 226, 150), tilt = -4 },
		{ x = 0.1, y = 0.5, text = "ROZARIO & LIM\n15 YEARS\nFriday drinks, 6pm\n<font color=\"#a02222\">CANCELLED</font>", color = P.Paper, tilt = 3 },
		{ x = 1.7, y = 0.7, text = "Kitchen rota:\nweek 3 — Priya", color = Color3.fromRGB(190, 220, 236), tilt = -2 },
		{ x = -1.5, y = -0.8, text = "Lost: grey scarf", color = Color3.fromRGB(236, 226, 150), tilt = 6 },
	}
	for _, n in ipairs(notes) do
		local note = PropKit.newPart(room, "Note", Vector3.new(1.3, 1.0, 0.02), CFrame.new(14 + n.x, 6.2 + n.y, wallZ + 0.14) * CFrame.Angles(0, 0, math.rad(n.tilt)), n.color, M.SmoothPlastic)
		local gui = PropKit.label(note, Enum.NormalId.Back, n.text, { color = Color3.fromRGB(40, 40, 50), font = Enum.Font.GothamMedium, pixelsPerStud = 60 })
		local text = gui:FindFirstChildOfClass("TextLabel")
		if text then
			text.RichText = true
		end
	end

	-- Copier and water, against the reception wall.
	local back = rect.z1
	PropKit.copier(room, at(30.6, back - 1.0, NORTH))
	PropKit.waterCooler(room, at(33.9, back - 0.8, NORTH))
	PropKit.plant(room, at(rect.x0 + 1.1, back - 1.0, NORTH), 0.8, "blades")
	PropKit.plant(room, at(rect.x1 - 1.0, rect.z0 + 1.1, SOUTH), 0.8, "bush")
end

return Studio
