--!strict
--[[
	EnvironmentBake
	Builds the world (Workspace.Office) and, in Edit mode, bakes it into the
	place file.

	The environment is generated: OfficeShell makes the architecture from
	OfficePlan, and OfficeRoom, OfficeDetailing, OfficeInterior, CitySkyline
	and SuspectSpawner dress and populate it. `buildAll` runs them in the one
	order that works; the server bootstrap and the bake both call it, so they
	can never disagree.

	Baked content is adopted, not rebuilt: every builder skips geometry when
	its generated folder already exists, so a place saved after a bake loads
	fast and author edits to baked props survive. That only holds while the
	bake is CURRENT -- stamped with the same `Config.Environment.BuilderVersion`
	as the code. A bake from an older plan (or the Studio-authored office the
	game started as) is discarded and rebuilt (`ensureCurrent`), with a
	warning that the place should be re-baked and saved: the game is right
	either way, only Edit mode shows the old map until it is.

	Runtime-only wiring (the records-room flicker, the aviation-light blink,
	suspect idle animations, the conversation listener) is gated on
	RunService:IsRunning() in the builders, so a bake never leaves loops or
	tweens running in Edit mode.

	Usage (Edit mode only), e.g. from the command bar or via MCP:

		require(game.ServerScriptService.Server.EnvironmentBake).bake()      -- incremental
		require(game.ServerScriptService.Server.EnvironmentBake).bake(true)  -- force: rebuild

	Without `force`, the bake is an incremental fill: anything current that
	exists is adopted, anything missing is built. `force` discards everything
	first. The result persists only when the place is saved (Ctrl+S).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local log = Logger.scoped("EnvironmentBake")

local EnvironmentBake = {}

-- Children of Workspace.Office that survive a reset: the builders adopt them
-- and place them again (the spawn pad is moved into the lift). Everything else
-- under the office is either generated or the legacy Studio-authored asset, and
-- is discarded -- including the old authored skyline backdrop, which stood
-- where the plan's windows no longer are and hid the city behind it.
local KEPT = { InvestigatorSpawn = true }

local function office(): Instance?
	return workspace:FindFirstChild(Config.Environment.OfficeModelName)
end

-- Is this office a bake of the current plan?
function EnvironmentBake.isCurrent(target: Instance): boolean
	return target:GetAttribute("Baked") == true and target:GetAttribute("BuilderVersion") == Config.Environment.BuilderVersion
end

-- Discard everything the builders (or the legacy asset) put under the office,
-- and the stamps that said it was baked. The builders start from clean.
function EnvironmentBake.reset(target: Instance)
	for _, child in ipairs(target:GetChildren()) do
		if not KEPT[child.Name] then
			child:Destroy()
		end
	end
	target:SetAttribute("Baked", nil)
	target:SetAttribute("BuilderVersion", nil)
end

--[[
	If Workspace.Office holds anything that is not a current bake -- a bake of
	an older plan, or the legacy authored asset -- discard it so the builders
	make the current one. A place with no office, or an empty one, has nothing
	to discard. Returns true if it discarded something.
]]
function EnvironmentBake.ensureCurrent(): boolean
	local target = office()
	if not target or EnvironmentBake.isCurrent(target) then
		return false
	end
	local stale = target:GetAttribute("Baked") == true
	local legacy = false
	for _, child in ipairs(target:GetChildren()) do
		if not KEPT[child.Name] then
			legacy = true
			break
		end
	end
	if not stale and not legacy then
		return false
	end
	log:warn("Workspace.Office is not a bake of the current plan; rebuilding it (re-bake and save the place in Edit mode)", {
		stampedVersion = target:GetAttribute("BuilderVersion"),
		currentVersion = Config.Environment.BuilderVersion,
		legacy = legacy,
	})
	EnvironmentBake.reset(target)
	return true
end

--[[
	Build the whole environment, in dependency order: the shell first (walls
	and floors), then the world's evidence props and signs, the crime scene,
	the furnishing, the observations and validation (which need the furniture's
	interactables), the skyline and the suspects (which stand on the floor).

	Required here rather than at the top so merely requiring this module never
	pulls in the whole builder chain.
]]
function EnvironmentBake.buildAll()
	local OfficeShell = require(script.Parent:WaitForChild("OfficeShell"))
	local OfficeRoom = require(script.Parent:WaitForChild("OfficeRoom"))
	local OfficeDetailing = require(script.Parent:WaitForChild("OfficeDetailing"))
	local OfficeInterior = require(script.Parent:WaitForChild("OfficeInterior"))
	local CitySkyline = require(script.Parent:WaitForChild("CitySkyline"))
	local SuspectSpawner = require(script.Parent:WaitForChild("SuspectSpawner"))

	EnvironmentBake.ensureCurrent()
	OfficeShell.start()
	OfficeRoom.start()
	OfficeDetailing.start()
	OfficeInterior.start()
	OfficeRoom.finalize()
	CitySkyline.start()
	SuspectSpawner.start()
end

function EnvironmentBake.bake(force: boolean?): boolean
	if RunService:IsRunning() then
		log:warn("EnvironmentBake is Edit-mode only; a running game already builds at bootstrap")
		return false
	end

	local target = office()
	if target and force then
		EnvironmentBake.reset(target)
	end

	EnvironmentBake.buildAll()

	target = office()
	if not target then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} was not built; nothing to bake`)
		return false
	end
	target:SetAttribute("Baked", true)
	-- Stamp the builder version this bake was produced by, so a later boot (this
	-- bake's `.rbxl`, opened fresh) can tell whether the generated folders it is
	-- adopting still match the current builder code.
	target:SetAttribute("BuilderVersion", Config.Environment.BuilderVersion)
	log:info("environment baked", { office = target.Name, force = force == true, builderVersion = Config.Environment.BuilderVersion })
	return true
end

return EnvironmentBake
