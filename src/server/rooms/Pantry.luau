--!strict
--[[
	The pantry: a kitchen run along the west wall with the espresso machine
	on it, a fridge with a note on the door, wall cabinets with a warm strip
	light. It opens onto the corridor through a wide pass-through, so the light
	falls out into the dark.

	The espresso machine itself is the evidence prop case data places
	(EvidenceDefinition.propPlacement, style EspressoMachine); this room
	leaves its stretch of counter clear for it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local Pantry = {}

local at, EAST = Kit.at, Kit.EAST

-- The counter's surface (PropKit.kitchenRun's top).
Pantry.COUNTER_TOP = 3.0

function Pantry.build(interior: Instance)
	local rect = OfficePlan.rect("Pantry")
	local room = Kit.folder(interior, "Pantry")
	local top = Pantry.COUNTER_TOP

	-- The fridge in the north-west corner, then six studs of counter with the sink
	-- at the south end.
	PropKit.fridge(room, at(rect.x0 + 1.1, rect.z0 + 1.15, EAST))
	PropKit.kitchenRun(room, at(rect.x0 + 1.0, -12.2, EAST), 6, true)
	PropKit.wallCabinets(room, at(rect.x0 + 0.6, -12.2, EAST, 5.4), 6, true)

	-- On the counter, from the north: the espresso machine (case data), the
	-- microwave, the kettle, the sink, two mugs on the drainer.
	PropKit.microwave(room, at(rect.x0 + 1.0, -12.9, EAST, top))
	PropKit.kettle(room, at(rect.x0 + 1.0, -11.5, EAST, top))
	PropKit.mug(room, at(rect.x0 + 0.7, -9.6, EAST, top))
	PropKit.mug(room, at(rect.x0 + 1.3, -9.4, EAST, top), Color3.fromRGB(40, 60, 90))
	PropKit.bin(room, at(rect.x1 - 0.7, rect.z0 + 0.7, EAST))
end

return Pantry
