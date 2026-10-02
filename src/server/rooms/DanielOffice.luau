--!strict
--[[
	Daniel's office: the corner office, and the scene of the case. His light was
	on; it's always on.

	The layout leaves a clear approach from the door: Daniel's chair is behind
	the desk facing the entrance, and the visitor's chair sits opposite. The
	tape outline stays on the open floor beside the desk, the
	credenza under the window where his head struck it. The desk's working
	surface faces Daniel; evidence props stay visible and bound at their new
	positions.

	The interactable desk things (phone, laptop, agenda, pen, mug, the drawer)
	are built here, by name, and the case binds its evidence to them
	(EvidenceDefinition.bindTo). The evidence props case data places itself (the
	second cup, the marked floor, the phone's woken screen) sit on this desk at
	the positions Case001 gives them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local DanielOffice = {}

local P = PropKit.Palette
local M = Enum.Material
local at, NORTH, SOUTH, EAST, WEST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.EAST, Kit.WEST

-- The centre of the desk. Everything on and around it is placed from this.
DanielOffice.DESK = Vector3.new(-27.5, 0, -19)
-- The tape outline's origin (the torso's centre) and how it lies: head toward
-- the credenza, north. Case001's marked-floor tag is placed from these too.
DanielOffice.OUTLINE = Vector3.new(-20.8, 0.037, -22.6)
-- The desk top's surface.
local TOP = Kit.DESK_TOP

function DanielOffice.build(interior: Instance)
	local rect = OfficePlan.rect("DanielOffice")
	local room = Kit.folder(interior, "DanielOffice")
	local d = DanielOffice.DESK

	------------------------------------------------------------------
	-- The desk: a walnut top on a drawer pedestal and a panel leg, a
	-- modesty panel on the visitor's side.
	------------------------------------------------------------------
	local deskTop = PropKit.newPart(room, "DeskTop", Vector3.new(8, 0.25, 4), CFrame.new(d.X, 2.5, d.Z), P.Walnut, M.Wood)
	deskTop.CastShadow = true
	local legHeight = TOP - 0.26
	local base = PropKit.newPart(room, "Pedestal", Vector3.new(1.8, legHeight, 3.7), CFrame.new(d.X - 2.9, legHeight / 2, d.Z), P.WalnutDark, M.Wood)
	base.CanCollide = true
	PropKit.newPart(room, "PanelLeg", Vector3.new(0.3, legHeight, 3.8), CFrame.new(d.X + 3.65, legHeight / 2, d.Z), P.WalnutDark, M.Wood).CanCollide = true
	PropKit.newPart(room, "Modesty", Vector3.new(6.2, 1.5, 0.12), CFrame.new(d.X + 0.4, 1.55, d.Z + 1.8), P.WalnutDark, M.Wood)
	for i = 0, 1 do
		PropKit.newPart(room, "DrawerLine", Vector3.new(1.6, 0.03, 0.02), CFrame.new(d.X - 2.9, 0.75 + i * 0.7, d.Z + 1.86), P.Walnut, M.Wood)
	end
	local collider = PropKit.newPart(room, "DeskCollider", Vector3.new(8, TOP, 4), CFrame.new(d.X, TOP / 2, d.Z), P.Charcoal, M.SmoothPlastic)
	collider.Transparency = 1
	collider.CanCollide = true
	collider.CastShadow = false

	-- The drawer faces Daniel's side; the photo of Meera is in it.
	local drawer = PropKit.newPart(room, "DeskDrawer", Vector3.new(1.8, 0.45, 0.12), CFrame.new(d.X - 2.9, 2.22, d.Z - 2.04), Color3.fromRGB(150, 104, 62), M.Wood)
	drawer.CanQuery = true
	Kit.interactable(drawer, "Examine", "Examine Drawer")
	PropKit.newPart(room, "DeskDrawer_Pull", Vector3.new(0.5, 0.06, 0.06), CFrame.new(d.X - 2.9, 2.22, d.Z - 2.13), Color3.fromRGB(40, 40, 44), M.Metal)

	------------------------------------------------------------------
	-- Daniel sits behind the desk facing the entrance; the visitor faces him
	-- from the entrance side. The positions leave a clear route around the desk.
	------------------------------------------------------------------
	PropKit.officeChair(room, at(d.X + 0.4, d.Z - 3.6, SOUTH), {
		upholstery = P.Leather,
		material = M.Leather,
		highBack = true,
		yaw = 0,
	})
	PropKit.sideChair(room, at(d.X - 1.8, d.Z + 4.0, NORTH), { upholstery = P.FabricWarm, yaw = 0 })

	------------------------------------------------------------------
	-- On the desk. The monitor, laptop and notes face the seated boss.
	------------------------------------------------------------------
	-- The screen had gone to sleep; the lamp was left on.
	PropKit.monitor(room, at(d.X, d.Z + 1.55, NORTH, TOP), "off")
	PropKit.deskLamp(room, at(d.X - 3.3, d.Z + 1.35, Vector3.new(0.5, 0, -1).Unit, TOP), true)

	-- The phone: face up beside the keyboard, its screen faintly lit.
	local phone = PropKit.newPart(room, "Phone", Vector3.new(0.7, 0.12, 1.3), CFrame.new(d.X + 3.5, TOP + 0.06, d.Z + 0.9), Color3.fromRGB(28, 30, 34), M.SmoothPlastic)
	phone.CanQuery = true
	Kit.interactable(phone, "Examine", "Examine Phone")
	local screen = PropKit.newPart(
		room,
		"Phone_Screen",
		Vector3.new(0.57, 0.02, 1.12),
		phone.CFrame * CFrame.new(0, 0.07, 0),
		Color3.fromRGB(58, 82, 98),
		M.Neon
	)
	screen.Transparency = 0.3
	screen.CastShadow = false

	-- The laptop, still awake: base, lid, lit display. Its base is the interactable.
	local laptop = Instance.new("Model")
	laptop.Name = "Laptop"
	laptop.Parent = room
	local baseCF = CFrame.new(d.X - 1, TOP + 0.05, d.Z + 0.5)
	local laptopBase = PropKit.newPart(laptop, "LaptopBase", Vector3.new(1.9, 0.1, 1.3), baseCF, Color3.fromRGB(150, 152, 158), M.SmoothPlastic)
	laptopBase.CanQuery = true
	Kit.interactable(laptopBase, "Examine", "Examine Laptop")
	PropKit.newPart(laptop, "LaptopScreen", Vector3.new(1.9, 1.2, 0.08), baseCF * CFrame.new(0, 0.55, -0.6) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(150, 152, 158), M.SmoothPlastic)
	PropKit.newPart(laptop, "LaptopDisplay", Vector3.new(1.7, 1.0, 0.04), baseCF * CFrame.new(0, 0.567, -0.553) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(70, 108, 136), M.Neon).CastShadow = false

	-- The agenda for tonight, squared on the desk.
	local agenda = PropKit.newPart(room, "Document", Vector3.new(1.5, 0.04, 1.1), CFrame.new(d.X + 1.4, TOP + 0.02, d.Z + 0.7) * CFrame.Angles(0, math.rad(14), 0), Color3.fromRGB(226, 222, 210), M.SmoothPlastic)
	agenda.CanQuery = true
	agenda.CastShadow = false
	Kit.interactable(agenda, "Read", "Read Document")

	-- A fountain pen, uncapped.
	local pen = PropKit.newPart(room, "Pen", Vector3.new(0.08, 0.08, 0.7), CFrame.new(d.X + 0.6, TOP + 0.08, d.Z + 1.35) * CFrame.Angles(0, math.rad(-30), 0), P.LeatherBlack, M.SmoothPlastic)
	pen.CanQuery = true
	Kit.flavour(pen, "Examine Pen")

	-- His mug of cold chamomile, the tag hanging over the rim: he didn't drink
	-- coffee at night, which is what makes the espresso cup across the desk
	-- worth a second look.
	local mugPos = Vector3.new(d.X - 3.4, TOP + 0.3, d.Z - 0.3)
	local mug = PropKit.newPart(room, "CoffeeCup", Vector3.new(0.6, 0.5, 0.5), CFrame.new(mugPos) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(232, 228, 220), M.SmoothPlastic)
	mug.Shape = Enum.PartType.Cylinder
	mug.CanQuery = true
	Kit.flavour(mug, "Examine Coffee Cup")
	local tea = PropKit.newPart(room, "CoffeeCup_Tea", Vector3.new(0.02, 0.42, 0.42), CFrame.new(mugPos + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 108, 46), M.SmoothPlastic)
	tea.Shape = Enum.PartType.Cylinder
	PropKit.newPart(room, "CoffeeCup_TeaString", Vector3.new(0.012, 0.3, 0.012), CFrame.new(mugPos + Vector3.new(-0.26, 0.18, 0)), Color3.fromRGB(236, 232, 222), M.Fabric).CastShadow = false
	PropKit.newPart(room, "CoffeeCup_TeaTag", Vector3.new(0.02, 0.16, 0.14), CFrame.new(mugPos + Vector3.new(-0.27, -0.04, 0)), Color3.fromRGB(214, 196, 120), M.SmoothPlastic).CastShadow = false
	PropKit.newPart(room, "CoffeeCup_Handle", Vector3.new(0.08, 0.34, 0.2), CFrame.new(mugPos + Vector3.new(0.3, 0, 0)), Color3.fromRGB(232, 228, 220), M.SmoothPlastic)

	------------------------------------------------------------------
	-- The room around the desk
	------------------------------------------------------------------
	-- The rug rests on the room finish (top at ROOM_TOP), not the base carpet,
	-- so it is not buried by the thin floor slab.
	PropKit.rug(room, at(d.X, d.Z + 1.0, NORTH, Kit.ROOM_TOP), 10, 7.5, Color3.fromRGB(70, 58, 52), Color3.fromRGB(46, 38, 34))

	-- The credenza under the window: where his head struck it. The chipped
	-- corner is the one nearest the outline.
	PropKit.credenza(room, at(DanielOffice.OUTLINE.X + 1.1, rect.z0 + 0.65, SOUTH), 2.6)

	-- A bookcase along the west wall, and a sofa to sit on.
	PropKit.shelving(room, at(rect.x0 + 0.55, -20.5, EAST), 7, 7.4, 4, 31, { frame = P.WalnutDark, material = M.Wood, depth = 1.1 })
	PropKit.sofa(room, at(rect.x0 + 1.45, -12.0, EAST), 4.5)
	PropKit.floorLamp(room, at(rect.x0 + 0.9, -16.0, EAST), true)
	PropKit.framedArt(room, at(rect.x0 + 0.05, -12.0, EAST, 7.0), 3.2, 2.3, 11)
	PropKit.plant(room, at(rect.x0 + 0.9, rect.z0 + 0.9, EAST), 0.9, "tree")

	-- His jacket is still on the rack by the door.
	PropKit.coatRack(room, at(rect.x1 - 0.7, -10.6, WEST), Color3.fromRGB(36, 40, 54))
	PropKit.bin(room, at(d.X + 3.2, d.Z + 3.4, NORTH))
	PropKit.plant(room, at(rect.x1 - 0.8, -14.5, WEST), 0.8, "blades")
	PropKit.framedArt(room, at(rect.x1 - 0.05, -17.6, WEST, 6.6), 3.4, 2.4, 41)

	-- The door to the records room, marked on this side.
	PropKit.sign(room, at(rect.x1 - 0.05, -23, WEST, 9.4), "RECORDS", Vector2.new(1.8, 0.45))
end

return DanielOffice
