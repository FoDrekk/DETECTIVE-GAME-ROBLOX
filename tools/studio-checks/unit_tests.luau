--!nocheck
--[[
	Studio check: runs the unit suite inside a Play session and reports it.

	Press Play, then run this on the SERVER (the Studio MCP's execute_luau with
	datamodel_type "Server", or the command bar with the Server view selected).
	It switches on ServerScriptService.UnitTestRunner, the place's own copy of the
	suite, so the tests run against the services the game started; a `require`
	from here would get fresh, never-started copies. The [PASS]/[FAIL]/[TIMEOUT]/
	[SUMMARY] lines are collected as they print, because a full run prints far
	more than the 512 lines LogService keeps.

	A run takes about 25 s and an MCP call gives up after about half a minute, so
	this waits at most WAIT seconds. If the suite is still going, run this again
	to read the result. A finished run is only reported again; press Play afresh
	for a new one.

	The suite drives the server-wide phase and fires remotes at the real client,
	so stop Play afterwards rather than playing on (run cutscenes.luau first if
	you want both from one session). Switching the runner on is a Play-time
	change, gone when Play stops.
]]

local WAIT = 20
local ATTRIBUTE = "UnitCheck"
local MAX_LISTED = 10

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

if not (RunService:IsRunning() and RunService:IsServer()) then
	return "Press Play first, then run this on the Server."
end

local runner = game:GetService("ServerScriptService"):FindFirstChild("UnitTestRunner")
if not runner then
	return "ServerScriptService.UnitTestRunner is missing."
end

if runner:GetAttribute(ATTRIBUTE) == nil then
	local state = {
		done = false,
		passed = 0,
		failed = 0,
		failures = {},
		mockPlayerErrors = 0,
		otherErrors = 0,
		errors = {},
		-- On already means it ran when Play started; it is run again so this
		-- can collect it.
		restarted = runner.Enabled,
	}
	local connection

	local function save()
		runner:SetAttribute(ATTRIBUTE, HttpService:JSONEncode(state))
	end

	connection = LogService.MessageOut:Connect(function(message, messageType)
		if string.sub(message, 1, 6) == "[PASS]" then
			state.passed += 1
		elseif string.sub(message, 1, 6) == "[FAIL]" or string.sub(message, 1, 9) == "[TIMEOUT]" then
			state.failed += 1
			if #state.failures < MAX_LISTED then
				table.insert(state.failures, message)
			end
		elseif string.sub(message, 1, 9) == "[SUMMARY]" then
			state.summary = string.sub(message, 11)
			state.done = true
			connection:Disconnect()
		elseif messageType == Enum.MessageType.MessageError then
			-- The tests use plain tables as players, so every remote the services
			-- fire at one fails with this cast error. Expected; anything else isn't.
			if message == "Unable to cast value to Object" then
				state.mockPlayerErrors += 1
			else
				state.otherErrors += 1
				if #state.errors < MAX_LISTED then
					table.insert(state.errors, string.sub(message, 1, 240))
				end
			end
		else
			return
		end
		save()
	end)
	save()

	if runner.Enabled then
		runner.Enabled = false
	end
	runner.Enabled = true
end

local function read()
	return HttpService:JSONDecode(runner:GetAttribute(ATTRIBUTE))
end

local state = read()
local deadline = os.clock() + WAIT
while not state.done and os.clock() < deadline do
	task.wait(0.5)
	state = read()
end

local lines = {}
if state.done then
	table.insert(lines, state.summary)
else
	table.insert(lines, string.format("Still running: %d passed, %d failed so far. Run this again for the result.", state.passed, state.failed))
end
for _, failure in ipairs(state.failures) do
	table.insert(lines, "  " .. failure)
end
if state.failed > #state.failures then
	table.insert(lines, string.format("  ...and %d more in the Output", state.failed - #state.failures))
end
table.insert(lines, string.format("Remote errors from the mock players: %d (expected)", state.mockPlayerErrors))
table.insert(lines, string.format("Other errors: %d", state.otherErrors))
for _, err in ipairs(state.errors) do
	table.insert(lines, "  " .. err)
end
if state.restarted then
	table.insert(lines, "UnitTestRunner was already on when this started, so it ran the suite a second time.")
end

local report = table.concat(lines, "\n")
print(report)
return report
