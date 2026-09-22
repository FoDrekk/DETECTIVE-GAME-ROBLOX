--!strict
--[[
	CaseRegistry
	Maps case ids to case definitions. Config only — no gameplay logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local log = Logger.scoped("CaseRegistry")

local CaseRegistry = {}

local cases: { [string]: Types.CaseDefinition } = {}
local loaded = false

local function loadCase(module: ModuleScript)
	local ok, caseDef = pcall(require, module)
	if ok and type(caseDef) == "table" and caseDef.id then
		cases[caseDef.id] = caseDef :: Types.CaseDefinition
	else
		log:warn("failed to load case module", { module = module.Name, error = tostring(caseDef) })
	end
end

-- Eagerly load all numbered case modules found in Config.
local function loadAll()
	if loaded then
		return
	end
	loaded = true

	local configFolder = ReplicatedStorage:WaitForChild("Config")
	local casesFolder = configFolder:FindFirstChild("Cases") :: Folder?
	local scanRoot = casesFolder or configFolder
	for _, child in ipairs(scanRoot:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("^Case%d+$") then
			loadCase(child)
		end
	end

	local loadedCount = 0
	for _ in pairs(cases) do
		loadedCount += 1
	end
	log:debug("case registry loaded", { count = loadedCount })
end

function CaseRegistry.get(caseId: string): Types.CaseDefinition?
	loadAll()
	return cases[caseId]
end

function CaseRegistry.getAll(): { [string]: Types.CaseDefinition }
	loadAll()
	return cases
end

-- Register a case definition directly, without a Config file. Intended for
-- the test harness and future authoring tooling; does not touch or replace
-- file-backed cases.
function CaseRegistry.register(caseDef: Types.CaseDefinition)
	loadAll()
	cases[caseDef.id] = caseDef
end

return CaseRegistry
