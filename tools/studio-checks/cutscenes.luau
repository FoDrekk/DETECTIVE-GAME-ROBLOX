--!nocheck
--[[
	Studio check for the scripted scenes: each scene played in this Play session,
	the shot it started from, its length, how long it actually ran and how
	CutsceneService ended it ("finished", "skipped" or "timeout"), plus any
	warning or error logged while it ran.

	Press Play, then run this on the SERVER (the Studio MCP's execute_luau with
	datamodel_type "Server", or the command bar with the Server view selected).
	The first run starts listening and picks up what is already in the log. Then
	start the intro: press E or click Play on the title screen (from the MCP,
	user_keyboard_input with keyPress E on the Client). Run this again whenever
	you want to know where things stand. The intro is about three minutes and an
	MCP call gives up after about half a minute, so this never waits for a scene
	to end.

	Run on the CLIENT, it lists the game's client-side warnings and errors since
	Play started instead: a set that failed to build, an action that threw. The
	server never hears about those, and a scene with a broken set still ends
	"finished".

	What it records is a Play-time attribute on LogService, gone when Play stops.
]]

local ATTRIBUTE = "SceneCheck"
local MAX_PROBLEMS = 20

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

if not RunService:IsRunning() then
	return "Press Play first."
end

local onServer = RunService:IsServer()

local function now(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

-- The key=value pairs Logger appends to a line.
local function fields(message: string): { [string]: string }
	local out = {}
	for key, value in string.gmatch(message, "(%w+)=(%S+)") do
		out[key] = value
	end
	return out
end

local function isProblem(message: string, messageType: Enum.MessageType): boolean
	if messageType == Enum.MessageType.MessageError then
		return true
	end
	-- Only the game's own warnings: plugins (Rojo, for one) warn into the same log.
	return messageType == Enum.MessageType.MessageWarning and string.find(message, "[MysteryCase/", 1, true) ~= nil
end

-- Start listening, once per Play session. The listener belongs to the context
-- that ran this, so it outlives the run and keeps the attribute current.
if LogService:GetAttribute(ATTRIBUTE) == nil then
	local state = { scenes = {}, problems = {} }
	local playing = nil

	local function save()
		LogService:SetAttribute(ATTRIBUTE, HttpService:JSONEncode(state))
	end

	local function handle(message: string, messageType: Enum.MessageType, at: number)
		if onServer and string.find(message, "CutsceneService: cutscene playing", 1, true) then
			local f = fields(message)
			playing = { id = f.cutsceneId, from = f.from, seconds = tonumber(f.seconds), intro = f.intro == "true", started = at }
			table.insert(state.scenes, playing)
			save()
		elseif onServer and string.find(message, "CutsceneService: cutscene ended", 1, true) then
			local f = fields(message)
			if playing and playing.id == f.cutsceneId then
				playing.ended = at
				playing.reason = f.reason
				playing = nil
				save()
			end
		elseif (playing or not onServer) and #state.problems < MAX_PROBLEMS and isProblem(message, messageType) then
			table.insert(state.problems, { scene = playing and playing.id, text = string.sub(message, 1, 240) })
			save()
		end
	end

	for _, entry in ipairs(LogService:GetLogHistory()) do
		handle(entry.message, entry.messageType, entry.timestamp)
	end
	LogService.MessageOut:Connect(function(message, messageType)
		handle(message, messageType, now())
	end)
	save()
end

local state = HttpService:JSONDecode(LogService:GetAttribute(ATTRIBUTE))
local lines = {}

if onServer then
	if #state.scenes == 0 then
		table.insert(lines, "No scene has played yet. Start the intro: press E or click Play on the title screen.")
	end
	for _, scene in ipairs(state.scenes) do
		local head = string.format("%s from %s (%s s%s)", scene.id, scene.from, tostring(scene.seconds), if scene.intro then ", intro" else "")
		if scene.reason then
			table.insert(lines, string.format("%s: %s after %d s", head, scene.reason, math.floor(scene.ended - scene.started + 0.5)))
		else
			table.insert(lines, string.format("%s: playing, %d s in", head, math.floor(now() - scene.started)))
		end
	end
end

local where = if onServer then "Server warnings and errors during scenes" else "Client warnings and errors since Play started"
if #state.problems == 0 then
	table.insert(lines, where .. ": none")
else
	table.insert(lines, string.format("%s: %d%s", where, #state.problems, if #state.problems >= MAX_PROBLEMS then " (stopped counting)" else ""))
	for _, problem in ipairs(state.problems) do
		table.insert(lines, string.format("  %s%s", if problem.scene then `[{problem.scene}] ` else "", problem.text))
	end
end

local report = table.concat(lines, "\n")
print(report)
return report
