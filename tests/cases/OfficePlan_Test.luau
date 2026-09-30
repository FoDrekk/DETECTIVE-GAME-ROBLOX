--!strict
--[[
	The floor plan (OfficePlan) as data: that it is a sound plan before anything
	is built from it.

	  * every room is well-formed, inside the footprint, and big enough to move
	    in; no two rooms overlap;
	  * the rooms, the wall bodies and the lift tile the floor: there is no gap
	    in the plan nobody accounted for, and no wall runs through a room;
	  * every doorway joins two places, and is wide enough to walk through;
	  * the whole floor can be walked from the lift, and the corridor runs the
	    length of the floor from the entrance to the window.

	The built geometry (furniture, colliders) is OfficeLayout_Test's.
]]
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
	local expect = t.expect

	local function overlapArea(a: Plan.Rect, b: Plan.Rect): number
		local w = math.min(a.x1, b.x1) - math.max(a.x0, b.x0)
		local d = math.min(a.z1, b.z1) - math.max(a.z0, b.z0)
		if w <= 0 or d <= 0 then
			return 0
		end
		return w * d
	end

	local half = Plan.WallThickness / 2
	local f = Plan.Footprint
	-- The clear interior: inside the exterior walls' inner faces.
	local inner = { x0 = f.x0 + half, x1 = f.x1 - half, z0 = f.z0 + half, z1 = f.z1 - half } :: Plan.Rect

	-- Rooms and the car, as one list of clear floors (the car is carved out of
	-- reception's rectangle).
	local function isFloor(x: number, z: number): boolean
		return Plan.roomAt(x, z) ~= nil
	end

	t.test("every room is well-formed and inside the walls", function()
		for _, room in ipairs(Plan.Rooms) do
			local r = room.rect
			expect.truthy(r.x1 > r.x0 and r.z1 > r.z0)
			expect.truthy(r.x0 >= inner.x0 - 1e-6 and r.x1 <= inner.x1 + 1e-6)
			expect.truthy(r.z0 >= inner.z0 - 1e-6 and r.z1 <= inner.z1 + 1e-6)
		end
		local car = Plan.Lift.car
		expect.truthy(car.x0 >= inner.x0 and car.x1 <= inner.x1 and car.z0 >= inner.z0 and car.z1 <= inner.z1)
	end)

	t.test("no two rooms overlap, and the lift car stands in the hole reception leaves for it", function()
		for i, a in ipairs(Plan.Rooms) do
			for j = i + 1, #Plan.Rooms do
				local b = Plan.Rooms[j]
				expect.equal(overlapArea(a.rect, b.rect), 0)
			end
		end
		-- The car is wholly inside reception's core hole, and inside no other room.
		local car = Plan.Lift.car
		local core = Plan.LiftCore
		expect.truthy(car.x0 >= core.x0 and car.x1 <= core.x1 and car.z0 >= core.z0 and car.z1 <= core.z1)
		for _, room in ipairs(Plan.Rooms) do
			if room.name ~= "Reception" then
				expect.equal(overlapArea(car, room.rect), 0)
			end
		end
	end)

	t.test("rooms are big enough to move in", function()
		-- The smaller side of each room, in studs. (A character is 2 across; the
		-- third-person camera wants room behind it.)
		local minimum = {
			DanielOffice = 18,
			Archive = 9,
			Pantry = 9,
			Spine = 11,
			MeetingRoom = 17,
			Studio = 15,
			Reception = 19,
			OpenPlan = 29,
		}
		for _, room in ipairs(Plan.Rooms) do
			local r = room.rect
			local side = math.min(r.x1 - r.x0, r.z1 - r.z0)
			expect.truthy(minimum[room.name] ~= nil)
			expect.truthy(side >= minimum[room.name])
		end
		local car = Plan.Lift.car
		expect.truthy(car.x1 - car.x0 >= 7 and car.z1 - car.z0 >= 7)
	end)

	t.test("the rooms, the wall bodies and the lift tile the floor: no gap, no wall through a room", function()
		local gaps = {}
		local through = {}
		local x = inner.x0 + 0.25
		while x < inner.x1 do
			local z = inner.z0 + 0.25
			while z < inner.z1 do
				local floor = isFloor(x, z)
				local wall = Plan.wallAt(x, z)
				if not floor and not wall then
					-- Not a room, not a wall body: only the lift core's own steel
					-- and stone is allowed here, and that is inside the car's walls.
					table.insert(gaps, `{x},{z}`)
				end
				if floor and wall and Plan.insideWall(x, z) then
					table.insert(through, `{x},{z}`)
				end
				z += 0.5
			end
			x += 0.5
		end
		if #gaps > 0 then
			error(`{#gaps} cell(s) belong to no room and no wall, e.g. {gaps[1]}`)
		end
		if #through > 0 then
			error(`{#through} cell(s) of wall run through a room, e.g. {through[1]}`)
		end
	end)

	t.test("every doorway joins two places", function()
		local checked = 0
		for _, w in ipairs(Plan.Walls) do
			for _, o in ipairs(w.openings) do
				if o.kind ~= "window" then
					checked += 1
					local a = if w.axis == "x" then { o.center, w.at - 1.5 } else { w.at - 1.5, o.center }
					local b = if w.axis == "x" then { o.center, w.at + 1.5 } else { w.at + 1.5, o.center }
					local roomA, roomB = Plan.roomAt(a[1], a[2]), Plan.roomAt(b[1], b[2])
					expect.truthy(roomA)
					if o.kind ~= "entrance" then
						expect.truthy(roomB)
						expect.truthy((roomA :: Plan.Room).name ~= (roomB :: Plan.Room).name)
					end
				end
			end
		end
		expect.truthy(checked >= 8)
	end)

	t.test("doorways are wide enough to walk through", function()
		local minimum = { door = 4.5, pass = 8, entrance = 8, lift = 5 }
		for _, w in ipairs(Plan.Walls) do
			for _, o in ipairs(w.openings) do
				if o.kind ~= "window" then
					expect.truthy(o.width >= minimum[o.kind])
				end
			end
		end
	end)

	-- Flood fill over the plan (half-stud cells): floor and doorways, not wall.
	local function reachableFrom(x0: number, z0: number): ({ [string]: boolean }, number)
		local step = 0.5
		local function key(ix: number, iz: number): string
			return `{ix},{iz}`
		end
		local function walkable(ix: number, iz: number): boolean
			local x, z = ix * step, iz * step
			if Plan.insideWall(x, z) then
				return false
			end
			return isFloor(x, z) or Plan.wallAt(x, z) ~= nil
		end
		local seen: { [string]: boolean } = {}
		local queue = { { math.floor(x0 / step + 0.5), math.floor(z0 / step + 0.5) } }
		seen[key(queue[1][1], queue[1][2])] = true
		local count = 0
		local head = 1
		while head <= #queue do
			local cell = queue[head]
			head += 1
			count += 1
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, nz = cell[1] + d[1], cell[2] + d[2]
				local k = key(nx, nz)
				if not seen[k] and walkable(nx, nz) then
					seen[k] = true
					table.insert(queue, { nx, nz })
				end
			end
		end
		return seen, count
	end

	t.test("the whole floor can be walked from the lift", function()
		local seen = reachableFrom(Plan.Spawn.X, Plan.Spawn.Z)
		local function reached(x: number, z: number): boolean
			return seen[`{math.floor(x / 0.5 + 0.5)},{math.floor(z / 0.5 + 0.5)}`] == true
		end
		for _, room in ipairs(Plan.Rooms) do
			local cx, cz = Plan.center(room.rect)
			-- A room's own centre may have furniture; the plan has none, so the
			-- centre of every room is reachable.
			expect.truthy(reached(cx, cz))
		end
		-- Both ends of the corridor, the pantry's pass-through, Daniel's door.
		expect.truthy(reached(0, 26.5))
		expect.truthy(reached(0, -26.5))
		local daniel = Plan.openingOf("DanielFront", "door")
		expect.truthy(daniel and reached((daniel :: Plan.Opening).center, Plan.getWall("DanielFront").at))
		local pass = Plan.openingOf("SpineWest", "pass")
		expect.truthy(pass and reached(Plan.getWall("SpineWest").at, (pass :: Plan.Opening).center))
	end)

	t.test("the corridor runs the length of the floor, entrance to window, clear of walls", function()
		local z = inner.z1 - 0.5
		while z > inner.z0 + 0.5 do
			expect.falsy(Plan.insideWall(0, z))
			expect.equal((Plan.roomAt(0, z) :: Plan.Room).name, "Spine")
			z -= 1
		end
		-- The entrance is at its south end, the window at its north end.
		local entrance = Plan.openingOf("South", "entrance")
		expect.truthy(entrance and math.abs((entrance :: Plan.Opening).center) < 1)
		local window = Plan.openingOf("North", "window")
		expect.truthy(window)
		local windows = 0
		for _, o in ipairs(Plan.getWall("North").openings) do
			if o.kind == "window" and math.abs(o.center) < 1 then
				windows += 1
			end
		end
		expect.equal(windows, 1)
	end)

	t.test("the investigator arrives inside the lift car, facing its doors", function()
		local room = Plan.roomAt(Plan.Spawn.X, Plan.Spawn.Z)
		expect.truthy(room and (room :: Plan.Room).name == "LiftCar")
		local car = Plan.Lift.car
		-- The doors are on the car's west face, and the spawn is well inside.
		expect.near(car.x0, Plan.Lift.doorX + Plan.WallThickness / 2)
		expect.truthy(Plan.Spawn.X - car.x0 > 3)
		expect.truthy(Plan.contains(car, Plan.Spawn.X, Plan.Spawn.Z, 3))
	end)
end
