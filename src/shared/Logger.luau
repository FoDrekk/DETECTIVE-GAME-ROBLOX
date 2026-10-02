--!strict
--[[
	Logger
	Lightweight, severity-based runtime logging shared by server and client.

	Design constraints:
	  * No noisy per-frame logging.
	  * No giant framework.
	  * Fatal bootstrap/configuration failures must still fail loudly.
	  * Recoverable failures must be observable with useful context.
	  * Never log hidden case/story data.

	Usage:
	  local Logger = require(ReplicatedStorage.Shared.Logger)
	  local log = Logger.scoped("EvidenceService")
	  log:info("discovered", { player = player.Name, evidenceId = id })
]]

local RunService = game:GetService("RunService")

local Logger = {}

export type Severity = "DEBUG" | "INFO" | "WARN" | "ERROR"

export type Scope = {
	debug: (self: Scope, message: string, context: { [string]: any }?) -> (),
	info: (self: Scope, message: string, context: { [string]: any }?) -> (),
	warn: (self: Scope, message: string, context: { [string]: any }?) -> (),
	error: (self: Scope, message: string, context: { [string]: any }?) -> (),
}

local ORDER: { [Severity]: number } = {
	DEBUG = 10,
	INFO = 20,
	WARN = 30,
	ERROR = 40,
}

-- Minimum severity that is emitted. DEBUG is suppressed by default so that
-- verbose diagnostics never spam production runs.
local minSeverity: Severity = "INFO"

local function isServer(): boolean
	return RunService:IsServer()
end

local function prefix(): string
	return if isServer() then "[MysteryCase/s]" else "[MysteryCase/c]"
end

local function render(context: { [string]: any }?): string
	if not context then
		return ""
	end
	local keys = {}
	for key in pairs(context) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, `{key}={tostring(context[key])}`)
	end
	return " " .. table.concat(parts, " ")
end

local function emit(scope: string, severity: Severity, message: string, context: { [string]: any }?)
	if ORDER[severity] < ORDER[minSeverity] then
		return
	end
	local line = `{prefix()} [{severity}] {scope}: {message}{render(context)}`
	if severity == "ERROR" then
		task.spawn(error, line, 0)
	elseif severity == "WARN" then
		warn(line)
	else
		print(line)
	end
end

function Logger.setMinSeverity(severity: Severity)
	assert(ORDER[severity] ~= nil, `Unknown log severity '{severity}'`)
	minSeverity = severity
end

-- Create a scoped logger (one per service/module).
function Logger.scoped(scope: string): Scope
	local scoped = {}
	function scoped.debug(_, message: string, context: { [string]: any }?)
		emit(scope, "DEBUG", message, context)
	end
	function scoped.info(_, message: string, context: { [string]: any }?)
		emit(scope, "INFO", message, context)
	end
	function scoped.warn(_, message: string, context: { [string]: any }?)
		emit(scope, "WARN", message, context)
	end
	function scoped.error(_, message: string, context: { [string]: any }?)
		emit(scope, "ERROR", message, context)
	end
	return scoped :: Scope
end

--[[
	Fail loudly on a fatal, unrecoverable bootstrap/configuration error.
	Use for misconfiguration that makes the game unplayable (missing case
	registry, missing remote folder, etc). Recoverable conditions should use
	`Logger.scoped(...):warn(...)` instead.
]]
function Logger.fatal(scope: string, message: string, context: { [string]: any }?): never
	error(`{prefix()} [FATAL] {scope}: {message}{render(context)}`, 0)
end

return Logger
