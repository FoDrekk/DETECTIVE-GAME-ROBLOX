-- Entry: how crowded is the office? Builds the world as Studio Play would,
-- rasterises every collidable part onto a one-stud grid and prints how much
-- of the floor is solid and how much room the walkable floor leaves.
--
-- It reads only what any layout has (the Interior's carpet for the bounds, the
-- spawn pad for where to start), so the same script measures the redesigned
-- office and an older commit alike:
--
--   node tools/headless/build.js tools/headless/entry_layout_metrics.luau /tmp/metrics.luau
--   luau /tmp/metrics.luau
--
-- "Clearance" of a walkable cell is the distance to the nearest solid thing.
-- A comfortable third-person walk wants three studs; a doorway-wide gap is two.
Shim.runScript(game:GetService("ServerScriptService"):WaitForChild("Server"))
Shim.settle(5)

local office = workspace:FindFirstChild("Office")
local carpet = office.Interior.Floors.Carpet
local x0, z0 = math.floor(carpet.Position.X - carpet.Size.X / 2), math.floor(carpet.Position.Z - carpet.Size.Z / 2)
local nx, nz = math.ceil(carpet.Size.X), math.ceil(carpet.Size.Z)

local function key(ix, iz)
	return iz * nx + ix
end
local function inGrid(ix, iz)
	return ix >= 0 and ix < nx and iz >= 0 and iz < nz
end

local blocked = {} -- anything solid
local furniture = {} -- solid, but not a wall (not under Shell)
local suspects = office:FindFirstChild("Suspects")
local shell = office:FindFirstChild("Shell")
for _, d in ipairs(office:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and not (suspects and d:IsDescendantOf(suspects)) then
		local isFurniture = not (shell and d:IsDescendantOf(shell))
		local half = d.Size / 2
		local top, bottom = d.Position.Y + half.Y, d.Position.Y - half.Y
		if top > 0.8 and bottom < 6 then
			local cf = d.CFrame
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = cf * Vector3.new(half.X * sx, 0, half.Z * sz)
					minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
					minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
				end
			end
			for ix = math.floor(minX) - x0, math.floor(maxX) - x0 do
				for iz = math.floor(minZ) - z0, math.floor(maxZ) - z0 do
					if inGrid(ix, iz) then
						local local_ = cf:PointToObjectSpace(Vector3.new(x0 + ix + 0.5, d.Position.Y, z0 + iz + 0.5))
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

-- Walk from the spawn pad, a person's width (1 stud radius) clear of everything.
-- `solid` is the set of cells that count (all of them, or only the furniture).
local function clearanceIn(solid, ix, iz, limit)
	for r = 0, limit do
		for dx = -r, r do
			for dz = -r, r do
				if math.max(math.abs(dx), math.abs(dz)) == r then
					local cx, cz = ix + dx, iz + dz
					if not inGrid(cx, cz) or solid[key(cx, cz)] then
						return math.sqrt(dx * dx + dz * dz)
					end
				end
			end
		end
	end
	return limit
end
local function clearanceAt(ix, iz, limit)
	return clearanceIn(blocked, ix, iz, limit)
end

local spawn = office:FindFirstChild("InvestigatorSpawn")
local sx, sz = math.floor(spawn.Position.X) - x0, math.floor(spawn.Position.Z) - z0
local reach = {}
local queue = { { sx, sz } }
reach[key(sx, sz)] = true
local head = 1
while head <= #queue do
	local cell = queue[head]
	head += 1
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local cx, cz = cell[1] + d[1], cell[2] + d[2]
		if inGrid(cx, cz) and not reach[key(cx, cz)] and clearanceAt(cx, cz, 1) >= 1 then
			reach[key(cx, cz)] = true
			table.insert(queue, { cx, cz })
		end
	end
end

local total, solid, walkable, furnished = nx * nz, 0, 0, 0
for _ in pairs(blocked) do
	solid += 1
end
for _ in pairs(furniture) do
	furnished += 1
end
local buckets = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [6] = 0 }
local roomy = { [3] = 0, [4] = 0, [6] = 0 }
local sum = 0
for k in pairs(reach) do
	walkable += 1
	local ix, iz = k % nx, math.floor(k / nx)
	local c = clearanceAt(ix, iz, 8)
	sum += c
	for threshold in pairs(buckets) do
		if c >= threshold then
			buckets[threshold] += 1
		end
	end
	-- Room to spare from the FURNITURE (walls don't count): is the floor here
	-- open, or crowded with things?
	local f = clearanceIn(furniture, ix, iz, 8)
	for threshold in pairs(roomy) do
		if f >= threshold then
			roomy[threshold] += 1
		end
	end
end

print(string.format("LAYOUT floor %dx%d studs (%d cells)", nx, nz, total))
print(string.format("LAYOUT solid at walking height: %.1f%% of the floor (furniture alone: %.1f%%)", 100 * solid / total, 100 * furnished / total))
print(string.format("LAYOUT walkable from the spawn: %.1f%% of the floor (%d cells)", 100 * walkable / total, walkable))
print(string.format("LAYOUT mean clearance of the walkable floor: %.2f studs", sum / walkable))
for _, threshold in ipairs({ 1, 2, 3, 4, 6 }) do
	print(string.format("LAYOUT clearance >= %d studs: %.1f%% of the walkable floor", threshold, 100 * buckets[threshold] / walkable))
end
for _, threshold in ipairs({ 3, 4, 6 }) do
	print(string.format("LAYOUT no furniture within %d studs: %.1f%% of the walkable floor", threshold, 100 * roomy[threshold] / walkable))
end

-- The routes. For every object worth walking up to (each interactable, each
-- person) the WIDEST way there from the spawn: the route whose narrowest point
-- is widest ("bottleneck"), and how much longer the shortest walk is than
-- a straight line ("detour"). A layout people can move through has wide
-- bottlenecks and little detour.
local CollectionService = game:GetService("CollectionService")
local clearanceCache = {}
local function clear(ix, iz)
	local k = key(ix, iz)
	local c = clearanceCache[k]
	if c == nil then
		c = clearanceAt(ix, iz, 8)
		clearanceCache[k] = c
	end
	return c
end

-- Widest-path search from the spawn: best[k] = the largest possible minimum
-- clearance along a route to cell k (bucket queue, clearances 0..8).
local best = {}
local buckets2 = {}
for level = 0, 9 do
	buckets2[level] = {}
end
local startClear = math.min(9, math.floor(clear(sx, sz)))
best[key(sx, sz)] = clear(sx, sz)
table.insert(buckets2[startClear], { sx, sz })
for level = 9, 0, -1 do
	local list = buckets2[level]
	local i = 1
	while i <= #list do
		local cell = list[i]
		i += 1
		local here = best[key(cell[1], cell[2])]
		if math.min(9, math.floor(here)) == level then
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local cx, cz = cell[1] + d[1], cell[2] + d[2]
				if inGrid(cx, cz) and reach[key(cx, cz)] then
					local candidate = math.min(here, clear(cx, cz))
					local k = key(cx, cz)
					if best[k] == nil or candidate > best[k] + 1e-9 then
						best[k] = candidate
						table.insert(buckets2[math.min(9, math.floor(candidate))], { cx, cz })
					end
				end
			end
		end
	end
end

-- Shortest walking distance (cells) from the spawn.
local dist = { [key(sx, sz)] = 0 }
do
	local q = { { sx, sz } }
	local h = 1
	while h <= #q do
		local cell = q[h]
		h += 1
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local cx, cz = cell[1] + d[1], cell[2] + d[2]
			local k = key(cx, cz)
			if inGrid(cx, cz) and reach[k] and dist[k] == nil then
				dist[k] = dist[key(cell[1], cell[2])] + 1
				table.insert(q, { cx, cz })
			end
		end
	end
end

local goals = {}
for _, instance in ipairs(CollectionService:GetTagged("Interactable")) do
	if instance:IsDescendantOf(office) and not (suspects and instance:IsDescendantOf(suspects)) and instance:IsA("BasePart") then
		table.insert(goals, { name = instance.Name, position = instance.Position })
	end
end
if suspects then
	for _, model in ipairs(suspects:GetChildren()) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(goals, { name = model.Name, position = root.Position })
		end
	end
end

local widths, detours = {}, {}
for _, goal in ipairs(goals) do
	local gx, gz = math.floor(goal.position.X) - x0, math.floor(goal.position.Z) - z0
	-- Getting within five studs of the object is close enough to use it: of
	-- the cells that close, the one reached by the widest route, and the one
	-- reached by the shortest walk.
	local widest, shortest = -1, nil
	for dx = -5, 5 do
		for dz = -5, 5 do
			local cx, cz = gx + dx, gz + dz
			local k = key(cx, cz)
			if inGrid(cx, cz) and reach[k] and dx * dx + dz * dz <= 25 then
				widest = math.max(widest, best[k] or 0)
				if not shortest or dist[k] < shortest.walk then
					shortest = { walk = dist[k], straight = math.sqrt((cx - sx) ^ 2 + (cz - sz) ^ 2) }
				end
			end
		end
	end
	table.insert(widths, math.max(widest, 0))
	if ({ ... })[1] == "routes" then
		print(string.format("ROUTE %-18s (%6.1f, %6.1f)  widest %.1f", goal.name, goal.position.X, goal.position.Z, math.max(widest, 0)))
	end
	if shortest then
		table.insert(detours, shortest.walk / math.max(shortest.straight, 1))
	end
end
table.sort(widths)
table.sort(detours)
local function pick(list, fraction)
	return list[math.max(1, math.min(#list, math.ceil(#list * fraction)))]
end
print(string.format("LAYOUT routes: %d objects and people to walk up to", #goals))
print(string.format("LAYOUT widest route to within reach of each: narrowest point, min %.1f / lower quartile %.1f / median %.1f studs", widths[1], pick(widths, 0.25), pick(widths, 0.5)))
print(string.format("LAYOUT shortest walk vs straight line: median x%.2f / worst quartile x%.2f", pick(detours, 0.5), pick(detours, 0.75)))

-- With the argument `map` (luau metrics.luau -a map), the grid itself (for
-- tools/headless/plot_clearance.py): one line per cell, its column, row and
-- clearance (-1 where solid, 0 where the floor is not reachable).
if ({ ... })[1] == "map" then
	for iz = 0, nz - 1 do
		for ix = 0, nx - 1 do
			local value = 0
			if blocked[key(ix, iz)] then
				value = -1
			elseif reach[key(ix, iz)] then
				value = clearanceAt(ix, iz, 8)
			end
			print(string.format("CELL|%d|%d|%d", ix, iz, value))
		end
	end
	print(string.format("ORIGIN|%d|%d|%d|%d", x0, z0, nx, nz))
end
