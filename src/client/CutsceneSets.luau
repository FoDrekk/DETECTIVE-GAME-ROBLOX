--!strict
--[[
	CutsceneSets
	The places a scripted scene is framed in. A shot names its set
	(Types.CutsceneShot.set); the client builds it here, for the length of the
	scene, and takes it down again when the scene is over.

	There are two kinds (Config.Cutscene.Sets):
	  * a DRESSED SET (a bedroom, a street, a car, a forecourt, a lobby, the city
	    from the air) is built from parts far from the office, in a corner of the
	    map nobody walks to, and exists only on this client, only while a scene
	    needs it. Its shots' camera points are relative to its `origin`, so a set
	    is authored in its own coordinates and can be moved by changing one number;
	  * a WORLD SET (the lift car, the office at dawn) is the real office. It only
	    ever adds to it (a pair of closed doors, a reflection) and undoes every
	    change when it is taken down; its shots' camera points are world
	    coordinates.

	What happens in a set is named, not scripted here: a shot lists actions
	(Types.CutsceneAction) and the set performs them (a phone buzzing, a door
	sliding, a floor number changing). The config lists the actions each set
	knows; the server checks a scene against it at boot, and the headless
	playthrough (tools/headless) checks every set really does each one.

	Each set is a module in `sets/` named for it, returning
	`build(origin: Vector3, parent: Folder): SetHandle`. A set that errors while
	building or acting is logged and skipped: a scene is never broken by its own
	scenery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local log = Logger.scoped("CutsceneSets")

local CutsceneSets = {}

export type SetHandle = {
	-- Perform one of the set's named actions (an unknown one is a no-op).
	act: (name: string, args: { [string]: any }?) -> (),
	-- Take the set down: every part it made, every change it made to the world.
	destroy: () -> (),
}

type SetDefinition = { world: boolean?, origin: Vector3?, actions: { string } }

local CONTAINER_NAME = "MysteryCase_CutsceneSets"

local built: { [string]: SetHandle } = {}
-- Sets that failed to build during this scene: not retried on every shot and
-- action that names them (the warning is logged once).
local failed: { [string]: boolean } = {}
local container: Folder? = nil

local function definitionOf(name: string): SetDefinition?
	return (Config.Cutscene.Sets :: any)[name]
end

local function moduleFor(name: string): ModuleScript?
	local folder = script.Parent:FindFirstChild("sets")
	local module = folder and folder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		return module
	end
	return nil
end

-- The names of every set the config knows, sorted.
function CutsceneSets.names(): { string }
	local names = {}
	for name in pairs(Config.Cutscene.Sets) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- True for a set that is the real office (its points are world coordinates).
function CutsceneSets.isWorld(name: string?): boolean
	local definition = if name then definitionOf(name) else nil
	return definition == nil or definition.world == true
end

-- Where a dressed set stands (zero for a world set, or no set at all).
function CutsceneSets.origin(name: string?): Vector3
	local definition = if name then definitionOf(name) else nil
	if not definition or definition.world then
		return Vector3.zero
	end
	return definition.origin or Vector3.zero
end

-- A shot's camera point in world coordinates: a dressed set's points are its
-- own, so they move by its origin; anything else's are already world ones.
function CutsceneSets.toWorld(name: string?, point: Types.CutsceneCameraPoint): Types.CutsceneCameraPoint
	local origin = CutsceneSets.origin(name)
	if origin == Vector3.zero then
		return point
	end
	return { position = point.position + origin, lookAt = point.lookAt + origin }
end

local function getContainer(): Folder
	local existing = container
	if existing and existing.Parent then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = workspace
	container = folder
	return folder
end

--[[
	Build the set (if it isn't already) and return its handle; nil when there is no
	such set or it failed to build.
]]
function CutsceneSets.enter(name: string?): SetHandle?
	if not name then
		return nil
	end
	local existing = built[name]
	if existing or failed[name] then
		return existing
	end
	local definition = definitionOf(name)
	local module = moduleFor(name)
	if not definition or not module then
		log:warn("no such set", { set = name })
		failed[name] = true
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = getContainer()
	local ok, result = pcall(function()
		local builder = (require :: any)(module)
		return builder.build(CutsceneSets.origin(name), folder)
	end)
	if not ok or type(result) ~= "table" then
		log:warn("set failed to build", { set = name, error = tostring(result) })
		failed[name] = true
		folder:Destroy()
		return nil
	end
	built[name] = result :: SetHandle
	return built[name]
end

--[[
	Build several sets before a scene starts, yielding between them so no one
	frame carries all of it. Duplicates and unknown names are ignored.
]]
function CutsceneSets.prepare(names: { string })
	local seen: { [string]: boolean } = {}
	for _, name in ipairs(names) do
		if not seen[name] then
			seen[name] = true
			CutsceneSets.enter(name)
			task.wait()
		end
	end
end

-- Ask a set to perform one of its named actions.
function CutsceneSets.act(name: string?, action: string, args: { [string]: any }?)
	local handle = CutsceneSets.enter(name)
	if not handle then
		return
	end
	local ok, err = pcall(handle.act, action, args)
	if not ok then
		log:warn("set action failed", { set = name, action = action, error = tostring(err) })
	end
end

-- Take one set down (a scene is past its last shot in it).
function CutsceneSets.release(name: string)
	local handle = built[name]
	if not handle then
		return
	end
	built[name] = nil
	local ok, err = pcall(handle.destroy)
	if not ok then
		log:warn("set failed to come down", { set = name, error = tostring(err) })
	end
	local folder = container and container:FindFirstChild(name)
	if folder then
		folder:Destroy()
	end
end

-- Take every set down. Called however a scene ends.
function CutsceneSets.leaveAll()
	table.clear(failed)
	for name in pairs(table.clone(built)) do
		CutsceneSets.release(name)
	end
	if container then
		container:Destroy()
		container = nil
	end
end

return CutsceneSets
