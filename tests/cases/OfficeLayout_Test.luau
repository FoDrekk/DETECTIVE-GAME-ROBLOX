--!strict
--[[
	The built office (Workspace.Office, built fresh by the bootstrap headless;
	the baked place in Studio) against its plan: that the layout is one a
	person can walk.

	The colliders are rasterised onto a one-stud grid and the free floor is
	flood-filled from where the investigator arrives, with every obstacle
	grown by the width of a person (plus a margin), so a gap too narrow to
	walk through counts as closed. Then:

	  * every room, the lift and every doorway can be reached;
	  * every interactable object and every person can be walked up to;
	  * the floor is not crowded: how much of each room is blocked, and how
	    much of the walkable floor has room to spare on every side;
	  * the story's places are where the plan says: the desk in Daniel's office,
	    the printout on the reception counter, Meera at the window, Victor at the
	    meeting room's table, Sam by the lift.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfficePlan"))
	local CaseRegistry = require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName) :: Instance
	local footprint = Plan.Footprint
	local X0, Z0 = math.floor(footprint.x0), math.floor(footprint.z0)
	local NX, NZ = math.ceil(footprint.x1) - X0, math.ceil(footprint.z1) - Z0

	-- A person is about two studs across; the margin is for the camera and the
	-- swing of a turn.
	local BODY = 1.0
	local MARGIN = 0.5

	local function cellOf(x: number, z: number): (number, number)
		return math.floor(x) - X0, math.floor(z) - Z0
	end
	local function inGrid(ix: number, iz: number): boolean
		return ix >= 0 and ix < NX and iz >= 0 and iz < NZ
	end
	local function key(ix: number, iz: number): number
		return iz * NX + ix
	end
	local function centre(ix: number, iz: number): (number, number)
		return X0 + ix + 0.5, Z0 + iz + 0.5
	end

	-- 1. The obstacles: anything solid at walking height, except the people
	-- (they are placed on the floor by the spawner, and walked around).
	local blocked: { [number]: boolean } = {}
	-- ...and the part of them that is furniture: solid, but not a wall.
	local furniture: { [number]: boolean } = {}
	local function inFolder(part: Instance, name: string): boolean
		local folder = office:FindFirstChild(name)
		return folder ~= nil and part:IsDescendantOf(folder)
	end
	for _, d in ipairs(office:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide and not inFolder(d, "Suspects") then
			local isFurniture = not inFolder(d, "Shell")
			local half = d.Size / 2
			local top, bottom = d.Position.Y + half.Y, d.Position.Y - half.Y
			if top > 0.8 and bottom < 6 then
				local cf = d.CFrame
				-- The part's footprint on the floor: its corners' extent, then each
				-- cell whose centre is inside the (turned) box.
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, sx in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = cf * Vector3.new(half.X * sx, 0, half.Z * sz)
						minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
						minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
					end
				end
				for ix = math.floor(minX) - X0, math.floor(maxX) - X0 do
					for iz = math.floor(minZ) - Z0, math.floor(maxZ) - Z0 do
						if inGrid(ix, iz) then
							local cx, cz = centre(ix, iz)
							local local_ = cf:PointToObjectSpace(Vector3.new(cx, d.Position.Y, cz))
							if math.abs(local_.X) <= half.X + 0.01 and math.abs(local_.Z) <= half.Z + 0.01 then
								blocked[key(ix, iz)] = true
								if isFurniture then
									furniture[key(ix, iz)] = true
								end
							end
						end
					end
				end
			end
		end
	end

	-- 2. Grow every obstacle by a person, and flood-fill the rest from the lift.
	local radius = BODY + MARGIN
	local grown: { [number]: boolean } = {}
	local offsets = {}
	for dx = -2, 2 do
		for dz = -2, 2 do
			if dx * dx + dz * dz <= radius * radius + 0.5 then
				table.insert(offsets, { dx, dz })
			end
		end
	end
	for k in pairs(blocked) do
		local ix, iz = k % NX, math.floor(k / NX)
		for _, o in ipairs(offsets) do
			local nx, nz = ix + o[1], iz + o[2]
			if inGrid(nx, nz) then
				grown[key(nx, nz)] = true
			end
		end
	end

	local reachable: { [number]: boolean } = {}
	local startX, startZ = cellOf(Plan.Spawn.X, Plan.Spawn.Z)
	local function flood()
		if grown[key(startX, startZ)] then
			return
		end
		local queue = { { startX, startZ } }
		reachable[key(startX, startZ)] = true
		local head = 1
		while head <= #queue do
			local cell = queue[head]
			head += 1
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, nz = cell[1] + d[1], cell[2] + d[2]
				if inGrid(nx, nz) and not grown[key(nx, nz)] and not reachable[key(nx, nz)] then
					reachable[key(nx, nz)] = true
					table.insert(queue, { nx, nz })
				end
			end
		end
	end
	flood()

	-- Is there a reachable cell within `distance` studs of this point?
	local function canWalkUpTo(x: number, z: number, distance: number): boolean
		local cx, cz = cellOf(x, z)
		local reach = math.ceil(distance)
		for dx = -reach, reach do
			for dz = -reach, reach do
				local nx, nz = cx + dx, cz + dz
				if inGrid(nx, nz) and reachable[key(nx, nz)] then
					local px, pz = centre(nx, nz)
					if (px - x) ^ 2 + (pz - z) ^ 2 <= distance * distance then
						return true
					end
				end
			end
		end
		return false
	end

	t.test("the investigator arrives on a free patch of floor", function()
		expect.falsy(grown[key(startX, startZ)])
		expect.truthy(reachable[key(startX, startZ)])
	end)

	t.test("every room can be walked into and has floor to walk on", function()
		for _, room in ipairs(Plan.Rooms) do
			-- Floor that could be open: at least a person's width in from the walls.
			local total, walkable = 0, 0
			for ix = 0, NX - 1 do
				for iz = 0, NZ - 1 do
					local x, z = centre(ix, iz)
					if Plan.roomHolds(room, x, z, radius) then
						total += 1
						if reachable[key(ix, iz)] then
							walkable += 1
						end
					end
				end
			end
			expect.truthy(total > 0)
			-- Half of every room's usable floor, at least, is open to walk on (a
			-- storeroom with wall-to-wall shelving would fail this).
			if walkable / total < 0.5 then
				error(`{room.name}: only {walkable} of {total} usable floor cells are open to walk on`)
			end
		end
	end)

	t.test("the lift car, and every doorway, can be walked through", function()
		local car = Plan.Lift.car
		expect.truthy(canWalkUpTo((car.x0 + car.x1) / 2, (car.z0 + car.z1) / 2, 1))
		for _, w in ipairs(Plan.Walls) do
			for _, o in ipairs(w.openings) do
				if o.kind ~= "window" then
					local x = if w.axis == "x" then o.center else w.at
					local z = if w.axis == "x" then w.at else o.center
					if not canWalkUpTo(x, z, 1.5) then
						error(`the doorway of {w.name} at ({x}, {z}) is blocked or too narrow`)
					end
				end
			end
		end
	end)

	local function objectPosition(instance: Instance): Vector3?
		if instance:IsA("BasePart") then
			return instance.Position
		elseif instance:IsA("Model") then
			return instance:GetPivot().Position
		end
		return nil
	end

	t.test("every interactable object can be walked up to", function()
		local checked = 0
		for _, instance in ipairs(CollectionService:GetTagged("Interactable")) do
			if instance:IsDescendantOf(office) and not inFolder(instance, "Suspects") then
				local p = objectPosition(instance)
				if p then
					checked += 1
					-- Close enough to examine: well inside the interaction range.
					if not canWalkUpTo(p.X, p.Z, 4.5) then
						error(`{instance.Name} at ({p.X}, {p.Z}) can't be walked up to`)
					end
				end
			end
		end
		expect.truthy(checked >= 15)
	end)

	t.test("every person can be walked up to", function()
		local case = CaseRegistry.get(Config.Game.AutoStartCase) :: any
		local checked = 0
		for _, suspect in ipairs(case.suspects) do
			local placement = suspect.npcPlacement
			if placement then
				checked += 1
				if not canWalkUpTo(placement.position.X, placement.position.Z, 4) then
					error(`{suspect.name} at ({placement.position.X}, {placement.position.Z}) can't be walked up to`)
				end
			end
		end
		expect.equal(checked, 3)
	end)

	------------------------------------------------------------------
	-- Not crowded
	------------------------------------------------------------------

	-- Per room: how much of the floor stands under furniture (not walls, and not
	-- the ring of floor against them).
	local function density(roomName: string): number
		local room = Plan.getRoom(roomName)
		local total, under = 0, 0
		for ix = 0, NX - 1 do
			for iz = 0, NZ - 1 do
				local x, z = centre(ix, iz)
				if Plan.roomHolds(room, x, z, 1) then
					total += 1
					if furniture[key(ix, iz)] then
						under += 1
					end
				end
			end
		end
		return under / total
	end

	t.test("no room is crowded: furniture stands on about a fifth of the floor, at most", function()
		-- The two storage rooms are allowed a quarter: they are wall-to-wall
		-- shelving and counters by nature, with the middle left clear. (The
		-- layout this replaced put furniture on a sixth of the floor of rooms a
		-- third the size.)
		local storage = { Archive = true, Pantry = true }
		local report = {}
		local crowded = false
		for _, room in ipairs(Plan.Rooms) do
			local d = density(room.name)
			table.insert(report, `{room.name} {math.floor(d * 100)}%`)
			if d > (if storage[room.name] then 0.27 else 0.21) then
				crowded = true
			end
		end
		if crowded then
			error("furniture share of the floor: " .. table.concat(report, ", "))
		end
	end)

	t.test("the floor is open: most of what can be walked has no furniture within three studs", function()
		local walkable, open = 0, 0
		for k in pairs(reachable) do
			local ix, iz = k % NX, math.floor(k / NX)
			walkable += 1
			local clear = true
			for dx = -3, 3 do
				for dz = -3, 3 do
					if dx * dx + dz * dz <= 9 then
						local nx, nz = ix + dx, iz + dz
						if inGrid(nx, nz) and furniture[key(nx, nz)] then
							clear = false
						end
					end
				end
			end
			if clear then
				open += 1
			end
		end
		local share = open / walkable
		-- The layout this replaced managed about half.
		if share < 0.55 then
			error(`only {math.floor(share * 100)}% of the walkable floor is clear of furniture by three studs`)
		end
	end)

	------------------------------------------------------------------
	-- The story's places
	------------------------------------------------------------------

	local function roomOf(position: Vector3): string?
		local room = Plan.roomAt(position.X, position.Z)
		return room and room.name
	end

	t.test("the evidence the case places sits in the room it belongs to", function()
		local case = CaseRegistry.get(Config.Game.AutoStartCase) :: any
		local expected = {
			["EV-004"] = "Reception",
			["EV-005"] = "Pantry",
			["EV-006"] = "DanielOffice",
			["EV-007"] = "Reception",
			["EV-008"] = "DanielOffice",
			["EV-011"] = "DanielOffice",
		}
		local found = 0
		for _, evidence in ipairs(case.evidence) do
			if expected[evidence.id] then
				found += 1
				local p = evidence.propPlacement.position
				expect.equal(roomOf(p), expected[evidence.id])
			end
		end
		expect.equal(found, 6)
	end)

	t.test("Meera stands at the corridor's window, Victor at the meeting table, Sam by the lift", function()
		local case = CaseRegistry.get(Config.Game.AutoStartCase) :: any
		local where = {}
		for _, suspect in ipairs(case.suspects) do
			where[suspect.id] = suspect.npcPlacement.position
		end
		expect.equal(roomOf(where["SUS-001"]), "Spine")
		expect.truthy(where["SUS-001"].Z < -22)
		expect.equal(roomOf(where["SUS-002"]), "MeetingRoom")
		expect.equal(roomOf(where["SUS-003"]), "Reception")
		local lift = Vector3.new(Plan.Lift.doorX, 0, Plan.Lift.doorZ)
		expect.truthy((Vector3.new(where["SUS-003"].X, 0, where["SUS-003"].Z) - lift).Magnitude < 10)
	end)

	t.test("the desk's things stand on Daniel's desk, and the door's nameplate outside its door", function()
		local DanielOffice = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("rooms"):WaitForChild("DanielOffice"))
		local desk = DanielOffice.DESK
		for _, name in ipairs({ "Phone", "LaptopBase", "Document", "Pen", "CoffeeCup" }) do
			local part
			for _, instance in ipairs(CollectionService:GetTagged("Interactable")) do
				if instance.Name == name then
					part = instance
				end
			end
			expect.truthy(part)
			local p = (part :: BasePart).Position
			expect.truthy(math.abs(p.X - desk.X) <= 4 and math.abs(p.Z - desk.Z) <= 2)
			expect.truthy(p.Y > 2.6 and p.Y < 3.2)
		end
		-- The nameplate is on the glass front, beside the door, facing the open plan.
		local case = CaseRegistry.get(Config.Game.AutoStartCase) :: any
		local sign = case.locations[1].signPlacement
		local front = Plan.getWall("DanielFront")
		local door = Plan.openingOf("DanielFront", "door") :: Plan.Opening
		expect.truthy(math.abs(sign.position.Z - front.at) < 0.5)
		expect.truthy(sign.position.X < door.center - door.width / 2 or sign.position.X > door.center + door.width / 2)
	end)
end
