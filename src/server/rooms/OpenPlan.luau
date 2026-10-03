--!strict
--[[
	The open plan: a bench of four desks and a pair, with room to walk between
	them and a wall of sample shelving, and a lounge along the south wall with
	a sofa, two armchairs and a rug. Daniel's glazed front looks onto this floor,
	so nothing stands in the lane between his door and the first desk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
local PropKit = require(script.Parent.Parent:WaitForChild("PropKit"))
local Kit = require(script.Parent.Parent:WaitForChild("InteriorKit"))

local OpenPlan = {}

local P = PropKit.Palette
local M = Enum.Material
local at, NORTH, SOUTH, EAST, WEST = Kit.at, Kit.NORTH, Kit.SOUTH, Kit.EAST, Kit.WEST

function OpenPlan.build(interior: Instance)
	local rect = OfficePlan.rect("OpenPlan")
	local room = Kit.folder(interior, "OpenPlan")

	-- Desks back to back around a fabric divider. `pairOnly` builds just the
	-- two on the near side.
	local function bench(cx: number, cz: number, width: number, seed: number, count: number, overrides: { [number]: any }?)
		local d = 2.3
		type Slot = { x: number, z: number, facing: Vector3 }
		local slots: { Slot } = {
			{ x = cx - width / 2, z = cz - d / 2, facing = NORTH },
			{ x = cx + width / 2, z = cz - d / 2, facing = NORTH },
			{ x = cx - width / 2, z = cz + d / 2, facing = SOUTH },
			{ x = cx + width / 2, z = cz + d / 2, facing = SOUTH },
		}
		if count == 2 then
			slots = { { x = cx, z = cz - d / 2, facing = NORTH }, { x = cx, z = cz + d / 2, facing = SOUTH } }
		end
		for i, slot in ipairs(slots) do
			local r = Random.new(seed + i)
			local o: PropKit.DeskOptions = {
				width = width,
				depth = d,
				screen = if r:NextNumber() < 0.3 then "lock" else "off",
				clutter = seed * 10 + i,
				chairYaw = r:NextNumber(-25, 25),
				chairPushed = r:NextNumber(0, 0.6),
			}
			if overrides and overrides[i] then
				for k, v in pairs(overrides[i]) do
					(o :: any)[k] = v
				end
			end
			PropKit.desk(room, at(slot.x, slot.z, slot.facing), o)
		end
		local span = if count == 2 then width else width * 2
		local divider = PropKit.newPart(room, "Divider", Vector3.new(span - 0.4, 1.3, 0.1), CFrame.new(cx, 3.25, cz), P.FabricTeal, M.Fabric)
		divider.CastShadow = true
	end

	-- The bench of four, with one real lamp over it and glow-only lamps on the
	-- other desks (the shadow-casting light count stays flat), and a pair.
	bench(-21, 3.5, 4.6, 3, 4, {
		[1] = { lamp = true, lampOn = true, lampGlowOnly = true },
		[2] = { lamp = true, lampOn = true, monitors = 2 },
		[3] = { lamp = true, lampOn = true, lampGlowOnly = true },
		[4] = { lamp = true, lampOn = true, lampGlowOnly = true },
	})
	bench(-12.5, 14, 4.6, 7, 2, {
		[1] = { monitors = 2, lamp = true, lampOn = true, lampGlowOnly = true },
		[2] = { lamp = true, lampOn = true, lampGlowOnly = true },
	})

	-- Sample shelving along the west wall.
	PropKit.shelving(room, at(rect.x0 + 0.55, 10, EAST), 10, 7, 4, 41, { sparse = true, depth = 1.1 })

	-- Lounge along the south wall.
	PropKit.rug(room, at(-21, 21.2, NORTH, Kit.FLOOR_TOP), 12, 6.4, Color3.fromRGB(96, 88, 80), Color3.fromRGB(70, 64, 58))
	PropKit.sofa(room, at(-21, rect.z1 - 1.45, NORTH), 7, P.Fabric, M.Fabric)
	PropKit.coffeeTable(room, at(-21, 22.4, NORTH), 4, 2.2)
	PropKit.mug(room, at(-20.1, 22.2, NORTH, 1.26), Color3.fromRGB(60, 80, 110))
	PropKit.armchair(room, at(-28.2, 22.4, EAST), P.FabricWarm)
	PropKit.armchair(room, at(-13.8, 22.4, WEST), P.FabricWarm)
	PropKit.floorLamp(room, at(-29.6, rect.z1 - 0.8, EAST), true)
	PropKit.framedArt(room, at(-21, rect.z1 - 0.05, NORTH, 7.2), 6, 3.2, 21)

	-- A bench under Daniel's glass, and greenery. The trees stand far enough
	-- off the west wall that a ficus in full leaf never touches the plaster.
	PropKit.bench(room, at(-31.5, -6.2, SOUTH), 4.5)
	PropKit.plant(room, at(rect.x0 + 1.45, 1.5, EAST), 0.9, "tree")
	PropKit.plant(room, at(rect.x0 + 1.45, 20.5, EAST), 0.9, "tree")
	PropKit.plant(room, at(rect.x1 - 1.0, rect.z1 - 1.0, NORTH), 0.7, "bush")
end

return OpenPlan
