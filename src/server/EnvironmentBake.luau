--!strict
--[[
	EnvironmentBake
	Edit-mode bake of the runtime world builders into the place file.

	The environment staging modules (OfficeRoom, OfficeDetailing,
	OfficeInterior, CitySkyline, SuspectSpawner) normally build their
	geometry when the server bootstraps, which means Workspace.Office looks
	like an empty authored shell while designing in Edit mode. Running the
	same builders once from this module in Edit mode generates that geometry
	into the place, so what you see while editing is what Play will show.

	Baked content is adopted, not rebuilt: every builder skips geometry when
	its generated folder already exists (and guards one-shot edits like the
	floor sink and the labels on authored parts), so re-running the bake --
	with or without `force` -- never duplicates anything and author edits to
	baked props survive. Runtime-only wiring (the records-room flicker, the
	aviation-light blink, suspect idle animations and the conversation
	listener) is gated on RunService:IsRunning() in the builders, so a bake
	never leaves loops or tweens running in Edit mode.

	Usage (Edit mode only), e.g. from the command bar or via MCP:

		require(game.ServerScriptService.Server.EnvironmentBake).bake()
		require(game.ServerScriptService.Server.EnvironmentBake).bake(true) -- force

	`force` first destroys the generated folders (Interior, Detailing,
	Skyline, Suspects, EvidenceProps, LocationSigns) and clears the markers
	that make one-shot edits idempotent, then rebuilds everything from
	scratch. Without force, the bake is an incremental fill: anything that
	exists is adopted, anything missing is (re)built.

	The result persists only when the place is saved (Ctrl+S).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local log = Logger.scoped("EnvironmentBake")

local EnvironmentBake = {}

-- Everything the builders generate under Workspace.Office.
local GENERATED_FOLDERS = { "Interior", "Detailing", "Skyline", "Suspects", "EvidenceProps", "LocationSigns" }

function EnvironmentBake.bake(force: boolean?): boolean
	if RunService:IsRunning() then
		log:warn("EnvironmentBake is Edit-mode only; a running game already builds at bootstrap")
		return false
	end

	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	if not office then
		log:warn(`Workspace.{Config.Environment.OfficeModelName} not found; nothing to bake`)
		return false
	end

	if force then
		for _, name in ipairs(GENERATED_FOLDERS) do
			local child = office:FindFirstChild(name)
			if child then
				child:Destroy()
			end
		end
		-- Clear the one-shot markers so a forced rebuild starts from the
		-- authored state (the floor sink is a relative move; it must not
		-- compound across bakes).
		local shell = office:FindFirstChild("Shell")
		local floor = shell and shell:FindFirstChild("Floor")
		if floor then
			floor:SetAttribute("FloorSunk", nil)
		end
		office:SetAttribute("Baked", nil)
	end

	-- Required here rather than at the top so merely requiring this module
	-- never pulls in the whole builder chain.
	local OfficeRoom = require(script.Parent:WaitForChild("OfficeRoom"))
	local OfficeDetailing = require(script.Parent:WaitForChild("OfficeDetailing"))
	local OfficeInterior = require(script.Parent:WaitForChild("OfficeInterior"))
	local CitySkyline = require(script.Parent:WaitForChild("CitySkyline"))
	local SuspectSpawner = require(script.Parent:WaitForChild("SuspectSpawner"))

	-- Same order as ServerBootstrap.bootstrap().
	OfficeRoom.start()
	OfficeDetailing.start()
	OfficeInterior.start()
	OfficeRoom.finalize()
	CitySkyline.start()
	SuspectSpawner.start()

	office:SetAttribute("Baked", true)
	log:info("environment baked", { office = office.Name, force = force == true })
	return true
end

return EnvironmentBake
