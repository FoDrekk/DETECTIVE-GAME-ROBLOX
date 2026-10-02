--!strict
--[[
	CutsceneService
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
	(the outro handing over to the closing summary) picks up.

	A case can name its opening scene (CaseDefinition.intro).
	GameStateService plays it when the investigation begins; `play` marks it
	(CutscenePayload.isIntro) so the client skips it by holding, not by tapping
	twice. It is an ordinary scene in every other way: server-timed, skippable,
	replay-aware (a second viewing starts at its `replayFrom` shot).

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

-- The id of the scene this player's case opens with, if it has one.
function CutsceneService.getIntroId(player: Player): string?
	local data = PlayerDataService.get(player)
	local caseDef = data and CaseService.getCase(data.caseState.caseId)
	local intro = caseDef and caseDef.intro
	return intro and intro.cutsceneId
end

local function isIntroOf(caseDef: Types.CaseDefinition?, cutsceneId: string): boolean
	local intro = caseDef and caseDef.intro
	return intro ~= nil and intro.cutsceneId == cutsceneId
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
	local isIntro = isIntroOf(CaseService.getCase(data.caseState.caseId), cutscene.id)
	data.caseState.activeCutscene = { id = cutscene.id, startedAt = clock(), duration = duration, grace = grace }
	log:info("cutscene playing", {
		player = player.Name,
		cutsceneId = cutscene.id,
		from = shots[1].id,
		seconds = duration,
		intro = isIntro,
	})
	updatedEvent:Fire(player, {
		active = true,
		id = cutscene.id,
		shots = shots,
		skippable = cutscene.skippable ~= false,
		isIntro = if isIntro then true else nil,
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
	Play the scene this player's case opens with (a replay starts it
	at its `replayFrom` shot). Called by GameStateService once the investigation
	has begun. A case without an intro returns (false, "no-intro").
]]
function CutsceneService.playIntro(player: Player): (boolean, string?)
	local introId = CutsceneService.getIntroId(player)
	if not introId then
		return false, "no-intro"
	end
	return CutsceneService.play(player, introId)
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

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value
end

--[[
	What a shot may ask of the client's presentation. Every name is
	checked against the tables the client reads (Config.Cutscene.Sets and
	LightingPresets, Config.Audio.Cutscene), so a typo is a boot warning here
	rather than a silent nothing on screen.
]]
local function validateShotPresentation(problems: { string }, where: string, shot: Types.CutsceneShot)
	local camera = shot.camera
	if camera then
		local fovTo = camera.fieldOfViewTo
		if fovTo ~= nil and (not isNumber(fovTo) or fovTo < 1 or fovTo > 120) then
			table.insert(problems, `{where}: field of view {fovTo} is out of range`)
		end
		if camera.ease ~= nil and not table.find(Config.Cutscene.Eases, camera.ease) then
			table.insert(problems, `{where}: unknown ease '{camera.ease}'`)
		end
		local handheld = camera.handheld
		if handheld ~= nil and (not isNumber(handheld) or handheld < 0 or handheld > 1) then
			table.insert(problems, `{where}: handheld must be between 0 and 1`)
		end
		if shot.mouseLook and camera.to and camera.from and camera.to.position ~= camera.from.position then
			table.insert(problems, `{where}: a mouseLook shot can't also move the camera`)
		end
	end

	local set = shot.set
	local setConfig = if set ~= nil then (Config.Cutscene.Sets :: any)[set] else nil
	if set ~= nil and setConfig == nil then
		table.insert(problems, `{where}: unknown set '{set}'`)
	end
	if shot.lighting ~= nil and (Config.Cutscene.LightingPresets :: any)[shot.lighting] == nil then
		table.insert(problems, `{where}: unknown lighting preset '{shot.lighting}'`)
	end

	local focus = shot.focus
	if focus then
		if not isNumber(focus.distance) or focus.distance <= 0 or (focus.toDistance ~= nil and (not isNumber(focus.toDistance) or focus.toDistance <= 0)) then
			table.insert(problems, `{where}: focus distance must be positive`)
		end
		if focus.blur ~= nil and (not isNumber(focus.blur) or focus.blur < 0 or focus.blur > 1) then
			table.insert(problems, `{where}: focus blur must be between 0 and 1`)
		end
		if focus.radius ~= nil and (not isNumber(focus.radius) or focus.radius < 0) then
			table.insert(problems, `{where}: focus radius can't be negative`)
		end
	end

	for index, cue in ipairs(shot.sounds or {}) do
		local at = `{where} sound {index}`
		local spec = (Config.Audio.Cutscene :: any)[cue.cue]
		if spec == nil then
			table.insert(problems, `{at}: unknown cue '{cue.cue}'`)
		end
		if not isNumber(cue.at) or cue.at < 0 or cue.at > shot.duration + 1e-6 then
			table.insert(problems, `{at}: starts outside its shot`)
		end
		if cue.volume ~= nil and (not isNumber(cue.volume) or cue.volume < 0 or cue.volume > 10) then
			table.insert(problems, `{at}: volume must be between 0 and 10`)
		end
		if cue.fade ~= nil and (not isNumber(cue.fade) or cue.fade < 0) then
			table.insert(problems, `{at}: fade can't be negative`)
		end
		if cue.from ~= nil and (not isNumber(cue.from) or cue.from < 0) then
			table.insert(problems, `{at}: 'from' can't be negative`)
		end
	end

	for index, action in ipairs(shot.actions or {}) do
		local at = `{where} action {index}`
		if not isNumber(action.at) or action.at < 0 or action.at > shot.duration + 1e-6 then
			table.insert(problems, `{at}: happens outside its shot`)
		end
		if set == nil then
			table.insert(problems, `{at}: '{action.name}' needs the shot to name a set`)
		elseif setConfig ~= nil and not table.find(setConfig.actions, action.name) then
			table.insert(problems, `{at}: set '{set}' has no action '{action.name}'`)
		end
	end

	local card = shot.titleCard
	if card then
		if type(card.title) ~= "string" or card.title == "" then
			table.insert(problems, `{where}: title card has no title`)
		end
		if not isNumber(card.at) or not isNumber(card.duration) or card.at < 0 or card.duration <= 0 or card.at + card.duration > shot.duration + 1e-6 then
			table.insert(problems, `{where}: title card runs outside its shot`)
		end
	end
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
			validateShotPresentation(problems, where, shot)
		end
		if cutscene.replayFrom and not shotIds[cutscene.replayFrom] then
			table.insert(problems, `{label}: replayFrom '{cutscene.replayFrom}' is not one of its shots`)
		end
	end
	-- The opening scene must be a real one, and one a returning player
	-- can leave (an intro is skipped by holding).
	local intro = caseDef.intro
	if intro then
		if not ids[intro.cutsceneId] then
			table.insert(problems, `intro: unknown cutscene '{intro.cutsceneId}'`)
		end
		for _, cutscene in ipairs(caseDef.cutscenes or {}) do
			if cutscene.id == intro.cutsceneId and cutscene.skippable == false then
				table.insert(problems, `intro: '{cutscene.id}' must be skippable`)
			end
		end
	end
	-- A Solved close's scenes must be real ones.
	local solution = caseDef.solution
	for index, entry in ipairs(solution and solution.solvedCutscenes or {}) do
		if not ids[entry.cutsceneId] then
			table.insert(problems, `solvedCutscenes {index}: unknown cutscene '{entry.cutsceneId}'`)
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
