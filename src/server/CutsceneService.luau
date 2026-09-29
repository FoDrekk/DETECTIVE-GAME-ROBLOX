--!strict
--[[
	CutsceneService (Phase 5.1)
	Server-authoritative scripted scenes: camera shots, subtitles and dips to
	black, authored as data in the case (CaseDefinition.cutscenes).

	The server decides everything that matters:
	  * what plays and when -- only `play` starts a scene; there is no client
	    request to start one;
	  * that a scene is on -- while one plays, the investigator can't touch
	    the world (InteractionService) and no conversation can begin;
	  * when it is over -- the client reports reaching the end, or a skip,
	    and the server checks both: a skip only where the scene allows it,
	    and "the end" no earlier than the scene's own length. If the client
	    goes quiet, the server ends the scene itself shortly after its last
	    shot (Config.Cutscene.EndGrace), so the story never waits on it.

	The client only presents what it is sent (CutsceneView): the shots from
	the one the scene starts at, and nothing about what follows.

	Replay-aware: scenes seen in this session are remembered outside the
	case state, which a replay wipes. A scene that authors `replayFrom`
	starts at that shot the second time round (the intro's "replays start at
	the lift doors"); without it, a scene plays from the top again.

	Every end -- reached, skipped, or timed out -- publishes the
	"CutsceneFinished" StoryEvent, which is how whatever follows a scene
	(future: the intro handing over to the investigation) picks up.

	Time comes from one source (os.clock; `useClock` lets a test supply its
	own), and the backstop is a plain check (`expire`) that `play` schedules,
	so every rule here can be tested without waiting in real time.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))
local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))

local log = Logger.scoped("CutsceneService")

local CutsceneService = {}

local updatedEvent: BindableEvent = Instance.new("BindableEvent")

-- Fired with (player, Types.CutscenePayload): a scene to play, or
-- `active = false` when the current one is over. Bridged to the client by
-- the bootstrap, like every other service's onUpdated.
function CutsceneService.onUpdated(): BindableEvent
	return updatedEvent
end

-- userId -> cutscene ids seen (reached, skipped or timed out) this session.
local seenThisSession: { [number]: { [string]: boolean } } = {}

-- The time source for a scene's start and the checks against it.
local clock: () -> number = os.clock

-- For tests: supply the time source (nil restores os.clock).
function CutsceneService.useClock(source: (() -> number)?)
	clock = source or os.clock
end

local function findCutscene(caseId: string, cutsceneId: string): Types.CutsceneDefinition?
	local caseDef = CaseService.getCase(caseId)
	for _, cutscene in ipairs(caseDef and caseDef.cutscenes or {}) do
		if cutscene.id == cutsceneId then
			return cutscene
		end
	end
	return nil
end

-- The shots from `startId` on (all of them when nil or unknown), and how
-- long they run.
local function shotsFrom(cutscene: Types.CutsceneDefinition, startId: string?): ({ Types.CutsceneShot }, number)
	local startIndex = 1
	if startId then
		for index, shot in ipairs(cutscene.shots) do
			if shot.id == startId then
				startIndex = index
				break
			end
		end
	end
	local shots = {}
	local duration = 0
	for index = startIndex, #cutscene.shots do
		local shot = cutscene.shots[index]
		table.insert(shots, shot)
		duration += shot.duration
	end
	return shots, duration
end

function CutsceneService.hasSeen(player: Player, cutsceneId: string): boolean
	local seen = seenThisSession[player.UserId]
	return seen ~= nil and seen[cutsceneId] == true
end

function CutsceneService.isPlaying(player: Player): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.caseState.activeCutscene ~= nil
end

-- The id of the scene this player is watching, if any.
function CutsceneService.getActiveId(player: Player): string?
	local data = PlayerDataService.get(player)
	local active = data and data.caseState.activeCutscene
	return active and active.id
end

type EndReason = "finished" | "skipped" | "timeout"

local function endScene(player: Player, data: Types.PlayerData, reason: EndReason)
	local active = data.caseState.activeCutscene
	if not active then
		return
	end
	data.caseState.activeCutscene = nil
	local seen = seenThisSession[player.UserId]
	if not seen then
		seen = {}
		seenThisSession[player.UserId] = seen
	end
	seen[active.id] = true
	log:info("cutscene ended", { player = player.Name, cutsceneId = active.id, reason = reason })
	updatedEvent:Fire(player, { active = false, id = active.id } :: Types.CutscenePayload)
	StoryEvents.publish("CutsceneFinished", player, {
		cutsceneId = active.id,
		skipped = reason == "skipped",
		timedOut = reason == "timeout",
	})
end

--[[
	Play a scene of the player's case for them. Refused while another scene
	or a conversation is on. Returns (true) once the scene has been sent.
]]
function CutsceneService.play(player: Player, cutsceneId: string): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end
	if data.caseState.activeCutscene then
		return false, "cutscene-in-progress"
	end
	if data.caseState.activeConversation then
		return false, "conversation-in-progress"
	end
	local cutscene = findCutscene(data.caseState.caseId, cutsceneId)
	if not cutscene then
		log:warn("unknown cutscene requested", { player = player.Name, cutsceneId = cutsceneId })
		return false, "unknown-cutscene"
	end

	local startAt = if CutsceneService.hasSeen(player, cutsceneId) then cutscene.replayFrom else nil
	local shots, duration = shotsFrom(cutscene, startAt)
	if #shots == 0 or duration <= 0 then
		log:warn("cutscene has nothing to play", { cutsceneId = cutsceneId })
		return false, "malformed-cutscene"
	end

	-- The grace is fixed now, so the backstop and its check always agree.
	local grace = Config.Cutscene.EndGrace
	data.caseState.activeCutscene = { id = cutscene.id, startedAt = clock(), duration = duration, grace = grace }
	log:info("cutscene playing", {
		player = player.Name,
		cutsceneId = cutscene.id,
		from = shots[1].id,
		seconds = duration,
	})
	updatedEvent:Fire(player, {
		active = true,
		id = cutscene.id,
		shots = shots,
		skippable = cutscene.skippable ~= false,
	} :: Types.CutscenePayload)

	-- The backstop: a scene the client never reports on still ends. `expire`
	-- only ends a scene that is actually overdue, so this is a no-op if the
	-- scene ended meanwhile or another one is playing by then.
	task.delay(duration + grace, function()
		CutsceneService.expire(player)
	end)
	return true, nil
end

--[[
	The backstop's check: end this player's scene if it has run past its
	length plus its grace without the client reporting the end. Scheduled by
	`play`; safe to call at any time -- a scene still inside its time, or no
	scene at all, is left alone. Returns true if it ended one.
]]
function CutsceneService.expire(player: Player): boolean
	local data = PlayerDataService.get(player)
	local active = data and data.caseState.activeCutscene
	if not data or not active then
		return false
	end
	-- A millisecond of slack for the timer landing on the dot.
	if clock() - active.startedAt < active.duration + active.grace - 1e-3 then
		return false
	end
	log:warn("client never reported the end of a cutscene; ending it", {
		player = player.Name,
		cutsceneId = active.id,
	})
	endScene(player, data, "timeout")
	return true
end

--[[
	The client reports the scene is over: it reached the end, or the
	investigator skipped it. Only the scene actually playing can be
	reported; a skip only where the scene allows one; and the end no sooner
	than the scene's own length (Config.Cutscene.EndTolerance for clock
	granularity).
]]
function CutsceneService.finish(player: Player, cutsceneId: any, skipped: any): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end
	local active = data.caseState.activeCutscene
	if type(cutsceneId) ~= "string" or not active or active.id ~= cutsceneId then
		return false, "not-playing"
	end
	local cutscene = findCutscene(data.caseState.caseId, cutsceneId)
	if skipped == true then
		if cutscene and cutscene.skippable == false then
			return false, "not-skippable"
		end
		endScene(player, data, "skipped")
		return true, nil
	end
	if clock() - active.startedAt < active.duration - Config.Cutscene.EndTolerance then
		return false, "too-early"
	end
	endScene(player, data, "finished")
	return true, nil
end

--[[
	Structural check of a case's scenes. Returns human-readable problems
	(empty when sound). Pure: no player state.
]]
function CutsceneService.validate(caseDef: Types.CaseDefinition): { string }
	local problems = {}
	local ids: { [string]: boolean } = {}
	for index, cutscene in ipairs(caseDef.cutscenes or {}) do
		local label = if type(cutscene.id) == "string" then cutscene.id else `cutscene {index}`
		if ids[label] then
			table.insert(problems, `{label}: duplicate cutscene id`)
		end
		ids[label] = true
		if #cutscene.shots == 0 then
			table.insert(problems, `{label}: has no shots`)
		end
		local shotIds: { [string]: boolean } = {}
		for shotIndex, shot in ipairs(cutscene.shots) do
			local where = `{label}/{shot.id or shotIndex}`
			if shotIds[shot.id] then
				table.insert(problems, `{where}: duplicate shot id`)
			end
			shotIds[shot.id] = true
			if type(shot.duration) ~= "number" or shot.duration <= 0 then
				table.insert(problems, `{where}: duration must be positive`)
			end
			local camera = shot.camera
			if not camera or not camera.from then
				table.insert(problems, `{where}: camera needs a 'from' point`)
			end
			if camera and camera.fieldOfView and (camera.fieldOfView < 1 or camera.fieldOfView > 120) then
				table.insert(problems, `{where}: field of view {camera.fieldOfView} is out of range`)
			end
			local fades = (shot.fadeIn or 0) + (shot.fadeOut or 0)
			if (shot.fadeIn or 0) < 0 or (shot.fadeOut or 0) < 0 or fades > shot.duration then
				table.insert(problems, `{where}: fades don't fit in the shot`)
			end
			for lineIndex, line in ipairs(shot.lines or {}) do
				local at = `{where} line {lineIndex}`
				if line.text == nil or line.text == "" then
					table.insert(problems, `{at}: has no text`)
				end
				if line.at < 0 or line.duration <= 0 or line.at + line.duration > shot.duration + 1e-6 then
					table.insert(problems, `{at}: runs outside its shot`)
				end
			end
		end
		if cutscene.replayFrom and not shotIds[cutscene.replayFrom] then
			table.insert(problems, `{label}: replayFrom '{cutscene.replayFrom}' is not one of its shots`)
		end
	end
	return problems
end

function CutsceneService.start()
	for caseId, caseDef in pairs(CaseRegistry.getAll()) do
		for _, problem in ipairs(CutsceneService.validate(caseDef)) do
			log:warn("cutscene problem", { caseId = caseId, problem = problem })
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		seenThisSession[player.UserId] = nil
	end)
	log:debug("started")
end

return CutsceneService
