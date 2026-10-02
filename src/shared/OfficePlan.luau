--!strict
--[[
	OfficePlan
	The floor plan of Level 9 -- Rozario & Lim's office -- as data. One source
	of truth for the architecture (OfficeShell builds the walls, floors, windows
	and the lift from it), the furnishing (OfficeInterior places rooms' contents
	relative to it) and the checks (OfficePlan_Test measures it: room sizes,
	passage widths, that every door leads somewhere).

	Pure data and arithmetic: no instances, so it runs anywhere (server,
	client, the headless tests).

	Conventions
	  * Studs. +X is east, +Z is south, -Z is north (the city windows).
	  * A wall is a line (`at` on its axis, from..to along it), one stud thick.
	    `axis = "x"` runs along X at Z = at; `axis = "z"` runs along Z at X = at.
	  * A room is its clear floor: the area between wall faces.
	  * Openings are named cut-outs in a wall (a doorway, a pass-through, a
	    window, the lift doors); they are where a wall is not.

	The layout, north to south:

	    NORTH (windows onto the city)
	    Daniel's office | Archive  |  SPINE  |  Meeting room
	                    | Pantry   |         |  (glass onto the spine)
	    ----------------+----------+         |  Studio (open to the spine)
	    Open plan                  |         |
	                               |         |  Reception, and the lift core
	                          (entrance)     |  in the south-east corner
	    SOUTH

	The spine is the long axis: from the entrance you look the length of the
	floor to the north window; the meeting room's glass and Daniel's lit office
	front onto it.
]]

export type Rect = { x0: number, x1: number, z0: number, z1: number }

export type OpeningKind = "door" | "pass" | "window" | "lift" | "entrance"

export type Opening = {
	center: number, -- along the wall's axis
	width: number,
	kind: OpeningKind,
}

export type WallKind = "solid" | "glass" | "low" | "exterior"

export type Wall = {
	name: string,
	axis: "x" | "z",
	at: number,
	from: number,
	to: number,
	kind: WallKind,
	openings: { Opening },
}

export type Room = {
	name: string,
	label: string,
	-- The room's bounding rectangle.
	rect: Rect,
	-- Parts of that rectangle that are not its floor (a lift core standing in
	-- one corner of reception).
	holes: { Rect }?,
}

local OfficePlan = {}

--------------------------------------------------------------------------
-- Envelope
--------------------------------------------------------------------------

-- The centre lines of the exterior walls.
OfficePlan.Footprint = { x0 = -36, x1 = 36, z0 = -28, z1 = 28 } :: Rect

-- Every wall is this thick, and rises to the underside of the suspended
-- ceiling. Daniel's office and the meeting room have a dropped ceiling.
OfficePlan.WallThickness = 1
OfficePlan.CeilingY = 12
OfficePlan.DroppedCeilingY = 11

-- Doorways are this tall (the wall above is a lintel).
OfficePlan.DoorHeight = 8.6

-- Window glass runs from the sill to the head.
OfficePlan.WindowSill = 3
OfficePlan.WindowHead = 11

--------------------------------------------------------------------------
-- Rooms (clear floor)
--------------------------------------------------------------------------

local function room(name: string, label: string, x0: number, x1: number, z0: number, z1: number, holes: { Rect }?): Room
	return { name = name, label = label, rect = { x0 = x0, x1 = x1, z0 = z0, z1 = z1 }, holes = holes }
end

-- The lift core: the car and the wall bodies round it, out to its west face.
OfficePlan.LiftCore = { x0 = 27.0, x1 = 35.5, z0 = 19.0, z1 = 27.5 } :: Rect

OfficePlan.Rooms = {
	room("DanielOffice", "Daniel's Office", -35.5, -16.5, -27.5, -8.5),
	room("Archive", "Records Room", -15.5, -6.5, -27.5, -18.5),
	room("Pantry", "Pantry", -15.5, -6.5, -17.5, -8.5),
	room("Spine", "Corridor", -5.5, 5.5, -27.5, 27.5),
	room("MeetingRoom", "Meeting Room", 6.5, 35.5, -27.5, -8.5),
	room("Studio", "Studio", 6.5, 35.5, -7.5, 7.5),
	room("Reception", "Reception", 6.5, 35.5, 8.5, 27.5, { OfficePlan.LiftCore }),
	room("OpenPlan", "Open Plan", -35.5, -5.5, -7.5, 27.5),
} :: { Room }

--------------------------------------------------------------------------
-- The lift
--------------------------------------------------------------------------

--[[
	A real car in the south-east corner, its doors facing west into reception.
	The investigator arrives in it (the intro plays there) and steps out of it.
	The car's own clear floor:
]]
OfficePlan.Lift = {
	car = { x0 = 28, x1 = 35.5, z0 = 20, z1 = 27.5 } :: Rect,
	-- The plane of the doors and the doorway's centre and width.
	doorX = 27.5,
	doorZ = 23.75,
	doorWidth = 5,
	-- The car's ceiling: lower than the office's.
	ceilingY = 9.6,
}

--------------------------------------------------------------------------
-- Walls
--------------------------------------------------------------------------

local function wall(name: string, axis: "x" | "z", at: number, from: number, to: number, kind: WallKind, openings: { Opening }?): Wall
	return { name = name, axis = axis, at = at, from = from, to = to, kind = kind, openings = openings or {} }
end

local function opening(center: number, width: number, kind: OpeningKind): Opening
	return { center = center, width = width, kind = kind }
end

OfficePlan.Walls = {
	-- Exterior. The north wall is the city side: three windows.
	wall("North", "x", -28, -36.5, 36.5, "exterior", {
		opening(-26, 15, "window"),
		opening(0, 11, "window"),
		opening(21, 22, "window"),
	}),
	-- The suite entrance is at the south end of the spine.
	wall("South", "x", 28, -36.5, 36.5, "exterior", { opening(0, 8, "entrance") }),
	wall("West", "z", -36, -27.5, 27.5, "exterior"),
	wall("East", "z", 36, -27.5, 27.5, "exterior"),

	-- Daniel's office: a glazed front onto the open plan (the light is on, the
	-- tape is across the door, and both read from the floor), a solid wall to
	-- the archive with a door between them.
	wall("DanielFront", "x", -8, -36, -16, "glass", { opening(-21.5, 6, "door") }),
	wall("DanielEast", "z", -16, -28, -8, "solid", { opening(-23, 4.5, "door") }),

	-- The utility column between Daniel's office and the spine: the archive
	-- (reached through Daniel's office) and the pantry (open to the spine).
	wall("ArchiveSouth", "x", -18, -16, -6, "solid"),
	wall("PantrySouth", "x", -8, -16, -6, "solid"),
	wall("SpineWest", "z", -6, -28, -8, "solid", { opening(-13, 8, "pass") }),

	-- The meeting room: glass onto the spine, a door in it.
	wall("MeetingWest", "z", 6, -28, -8, "glass", { opening(-18, 6, "door") }),
	wall("MeetingSouth", "x", -8, 6, 36, "solid"),

	-- The studio: open to the spine behind a low glass screen.
	wall("StudioScreen", "z", 6, -8, 8, "low", { opening(0, 10, "pass") }),

	-- Reception: a wall to the studio, a glass screen to the entrance hall.
	wall("ReceptionNorth", "x", 8, 6, 36, "solid", { opening(20, 9, "pass") }),
	wall("ReceptionWest", "z", 6, 8, 28, "glass", { opening(19, 10, "pass") }),

	-- The lift core.
	wall("LiftFront", "z", 27.5, 19.5, 28, "solid", { opening(23.75, 5, "lift") }),
	wall("LiftBack", "x", 19.5, 27.5, 36, "solid"),
} :: { Wall }

--------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------

function OfficePlan.getRoom(name: string): Room
	for _, r in ipairs(OfficePlan.Rooms) do
		if r.name == name then
			return r
		end
	end
	error(`OfficePlan: no room named {name}`)
end

function OfficePlan.rect(name: string): Rect
	return OfficePlan.getRoom(name).rect
end

function OfficePlan.contains(rect: Rect, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= rect.x0 + m and x <= rect.x1 - m and z >= rect.z0 + m and z <= rect.z1 - m
end

-- Is this point on the room's clear floor (in its rectangle, not in a hole)?
function OfficePlan.roomHolds(r: Room, x: number, z: number, margin: number?): boolean
	if not OfficePlan.contains(r.rect, x, z, margin) then
		return false
	end
	for _, hole in ipairs(r.holes or {}) do
		if OfficePlan.contains(hole, x, z) then
			return false
		end
	end
	return true
end

-- The room whose clear floor holds this point, if any. The lift car is a room
-- of its own.
function OfficePlan.roomAt(x: number, z: number): Room?
	local car = OfficePlan.Lift.car
	if OfficePlan.contains(car, x, z) then
		return { name = "LiftCar", label = "Lift", rect = car }
	end
	for _, r in ipairs(OfficePlan.Rooms) do
		if OfficePlan.roomHolds(r, x, z) then
			return r
		end
	end
	return nil
end

function OfficePlan.width(rect: Rect): number
	return rect.x1 - rect.x0
end

function OfficePlan.depth(rect: Rect): number
	return rect.z1 - rect.z0
end

function OfficePlan.center(rect: Rect): (number, number)
	return (rect.x0 + rect.x1) / 2, (rect.z0 + rect.z1) / 2
end

-- The solid stretches of a wall: its length between the openings, as
-- (from, to) pairs along its axis, in order.
function OfficePlan.solidSpans(w: Wall): { { number } }
	local spans: { { number } } = {}
	local ordered = table.clone(w.openings)
	table.sort(ordered, function(a, b)
		return a.center < b.center
	end)
	local cursor = w.from
	for _, o in ipairs(ordered) do
		local o0, o1 = o.center - o.width / 2, o.center + o.width / 2
		if o0 > cursor + 1e-6 then
			table.insert(spans, { cursor, o0 })
		end
		cursor = math.max(cursor, o1)
	end
	if cursor < w.to - 1e-6 then
		table.insert(spans, { cursor, w.to })
	end
	return spans
end

-- The wall whose body (a stud thick, its whole length, and half a stud
-- further at each end: that is how a corner closes) holds this point,
-- doorways and windows included.
function OfficePlan.wallAt(x: number, z: number): Wall?
	local half = OfficePlan.WallThickness / 2
	for _, w in ipairs(OfficePlan.Walls) do
		local along, across = if w.axis == "x" then x else z, if w.axis == "x" then z else x
		if math.abs(across - w.at) <= half and along >= w.from - half and along <= w.to + half then
			return w
		end
	end
	return nil
end

-- Is this point inside a wall's solid body (a stud thick, minus openings)?
-- Windows count as wall here: nobody walks through a window.
function OfficePlan.insideWall(x: number, z: number): boolean
	local w = OfficePlan.wallAt(x, z)
	if not w then
		return false
	end
	local along = if w.axis == "x" then x else z
	for _, o in ipairs(w.openings) do
		if o.kind ~= "window" and math.abs(along - o.center) < o.width / 2 then
			return false
		end
	end
	return true
end

-- The named wall.
function OfficePlan.getWall(name: string): Wall
	for _, w in ipairs(OfficePlan.Walls) do
		if w.name == name then
			return w
		end
	end
	error(`OfficePlan: no wall named {name}`)
end

-- A wall's opening by kind (the first) -- e.g. the door of a glazed front.
function OfficePlan.openingOf(wallName: string, kind: OpeningKind?): Opening?
	for _, o in ipairs(OfficePlan.getWall(wallName).openings) do
		if kind == nil or o.kind == kind then
			return o
		end
	end
	return nil
end

--------------------------------------------------------------------------
-- Anchors: places the story and the cameras refer to
--------------------------------------------------------------------------

--[[
	The investigator's arrival: the middle of the lift car, facing west out of
	its doors. Also the spawn.
]]
OfficePlan.Spawn = Vector3.new(31.75, 0.2, OfficePlan.Lift.doorZ)

return OfficePlan
