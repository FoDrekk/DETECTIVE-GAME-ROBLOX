--!strict
--[[
	The meeting room, set for a midnight signing. A long walnut table under two
	pendants, ten chairs tucked in neatly (nobody sat down), two places laid
	facing each other with water, a pen and a copy of the papers. A screen on
	the east wall on standby, the whiteboard on the south wall with the last
	quarter's targets and a partnership struck out. Glass onto the corridor.

	Victor waits at the east end of the table (Case001.npcPlacement).
	MeetingWater and Whiteboard are interactable by name.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local MeetingRoom = {}

local P = PropKit.Palette
local M = Enum.Material
local at, NORTH, SOUTH, EAST, WEST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.EAST, Kit.WEST

-- The table's centre and size; Case001 stands Victor at its east end.
MeetingRoom.TABLE = Vector3.new(21, 0, -18.5)
MeetingRoom.TABLE_SIZE = Vector2.new(14, 5)

function MeetingRoom.build(interior: Instance)
	local rect = OfficePlan.rect("MeetingRoom")
	local room = Kit.folder(interior, "MeetingRoom")
	local t = MeetingRoom.TABLE
	local half = MeetingRoom.TABLE_SIZE.X / 2
	local tableTop = 2.6

	PropKit.meetingTable(room, at(t.X, t.Z, SOUTH), MeetingRoom.TABLE_SIZE.X, MeetingRoom.TABLE_SIZE.Y)

	-- Ten chairs, tucked in: four a side and one at each end.
	for _, x in ipairs({ 16.5, 19.5, 22.5, 25.5 }) do
		PropKit.sideChair(room, at(x, t.Z - 3.8, SOUTH))
		PropKit.sideChair(room, at(x, t.Z + 3.8, NORTH))
	end
	PropKit.sideChair(room, at(t.X - half - 1.4, t.Z, EAST))
	PropKit.sideChair(room, at(t.X + half + 1.4, t.Z, WEST))

	-- Two places set, at the two ends of the table, facing each other down its
	-- length: water, a pen, a copy of the papers. Each is what the room's
	-- "MeetingWater" object examines, and each can be walked up to from the end.
	for _, side in ipairs({ -1, 1 }) do
		local x = t.X + side * (half - 1.1)
		local toward = if side < 0 then WEST else EAST
		local glass = PropKit.newPart(room, "WaterGlass", Vector3.new(0.5, 0.34, 0.34), CFrame.new(x, tableTop + 0.25, t.Z - 1.0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 214, 226), M.Glass)
		glass.Shape = Enum.PartType.Cylinder
		glass.Transparency = 0.55
		PropKit.paperStack(room, at(x, t.Z + 0.2, toward, tableTop), 4)
		PropKit.newPart(room, "Pen", Vector3.new(0.05, 0.05, 0.6), CFrame.new(x + side * 0.1, tableTop + 0.03, t.Z + 1.1) * CFrame.Angles(0, math.rad(70), 0), P.LeatherBlack, M.SmoothPlastic)
		local setting = Kit.hotspot(room, "MeetingWater", Vector3.new(1.8, 0.7, 3.2), CFrame.new(x, tableTop + 0.35, t.Z))
		Kit.flavour(setting, "Examine the Table")
	end

	-- Two pendants over the table, on.
	for _, x in ipairs({ 17.5, 24.5 }) do
		PropKit.pendant(room, CFrame.new(x, OfficePlan.DroppedCeilingY - 0.15, t.Z), 3.3, true, 1.6, 16)
	end

	-- The screen on the east wall, idle on standby.
	local screenX = rect.x1 - 0.1
	local screen = PropKit.newPart(room, "PresScreen", Vector3.new(0.15, 4, 7), CFrame.new(screenX, 6, t.Z), P.LeatherBlack, M.SmoothPlastic)
	screen.CastShadow = false
	local panel = PropKit.newPart(room, "PresScreenOn", Vector3.new(0.08, 3.6, 6.6), CFrame.new(screenX - 0.09, 6, t.Z), Color3.fromRGB(14, 20, 30), M.Neon)
	panel.CastShadow = false
	PropKit.label(panel, Enum.NormalId.Left, "HDMI 1\nNo signal", {
		color = Color3.fromRGB(110, 130, 160),
		font = Enum.Font.GothamMedium,
		size = 22,
		lightInfluence = 0,
	})

	-- The whiteboard, on the south wall: last quarter, and a partnership struck out.
	local wallZ = rect.z1
	local board = PropKit.newPart(room, "Whiteboard", Vector3.new(9, 4.5, 0.2), CFrame.new(21, 6, wallZ - 0.1), Color3.fromRGB(238, 238, 234), M.SmoothPlastic)
	board.CanQuery = true
	Kit.flavour(board, "Examine Whiteboard")
	PropKit.newPart(room, "WhiteboardFrame", Vector3.new(9.4, 4.9, 0.15), CFrame.new(21, 6, wallZ - 0.06), Color3.fromRGB(150, 152, 156), M.SmoothPlastic).CastShadow = false
	local gui = PropKit.label(board, Enum.NormalId.Front, "", { pixelsPerStud = 60 })
	local text = gui:FindFirstChildOfClass("TextLabel")
	if text then
		text.RichText = true
		text.TextScaled = false
		text.TextSize = 34
		text.Font = Enum.Font.PermanentMarker
		text.TextColor3 = Color3.fromRGB(34, 52, 110)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Text = "Q3 TARGETS\n\n<s>R&amp;L</s>   <font color=\"#9a2a2a\">R</font>\n\nretainers +12%\nnew clients: 4\n\n<font color=\"#9a2a2a\">sign by FRI</font>"
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 40)
		padding.PaddingTop = UDim.new(0, 26)
		padding.Parent = text
	end
	PropKit.newPart(room, "MarkerTray", Vector3.new(4, 0.1, 0.35), CFrame.new(21, 3.62, wallZ - 0.4), P.Steel, M.Metal)
	for i, color in ipairs({ Color3.fromRGB(30, 50, 120), Color3.fromRGB(150, 30, 30), P.LeatherBlack }) do
		local marker = PropKit.newPart(room, "Marker", Vector3.new(0.6, 0.12, 0.12), CFrame.new(19.8 + i * 0.7, 3.73, wallZ - 0.4), color, M.SmoothPlastic)
		marker.Shape = Enum.PartType.Cylinder
	end
	-- Sticky notes round its edge.
	for i, spec in ipairs({ { 16.2, 7.6 }, { 26.0, 5.2 }, { 26.9, 7.4 } }) do
		local note = PropKit.newPart(room, `Sticky_{i}`, Vector3.new(0.9, 0.9, 0.05), CFrame.new(spec[1], spec[2], wallZ - 0.235) * CFrame.Angles(0, 0, math.rad(i * 4 - 6)), Color3.fromRGB(240, 224, 130), M.SmoothPlastic)
		note.CastShadow = false
	end

	PropKit.wallClock(room, at(31.6, wallZ - 0.05, NORTH, 8.4), 12, 40)
	PropKit.plant(room, at(rect.x1 - 1.1, rect.z0 + 1.2, SOUTH), 0.8, "tree")
	PropKit.plant(room, at(rect.x1 - 1.1, rect.z1 - 1.2, SOUTH), 0.8, "tree")
end

return MeetingRoom
