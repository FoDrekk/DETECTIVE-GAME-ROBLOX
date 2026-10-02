--!strict
--[[
	GameStateService
	Server-authoritative game phase machine, backed by GameStateMachine.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))
local GameStateMachine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameStateMachine"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local AccusationService = require(script.Parent:WaitForChild("AccusationService"))
local TimelineService = require(script.Parent:WaitForChild("TimelineService"))
local ReasoningService = require(script.Parent:WaitForChild("ReasoningService"))
local CutsceneService = require(script.Parent:WaitForChild("CutsceneService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local GameStateService = {}

local ACTIVE_CASE = Config.Game.AutoStartCase

local machine = GameStateMachine.new("MainMenu")
machine
	:allowBoth("MainMenu", "CaseBriefing")
	:allowBoth("CaseBriefing", "Investigation")
	:allowBoth("Investigation", "CaseClosed")
	:allowBoth("CaseClosed", "MainMenu")

local phaseChanged = Signals.get(Signals.Names.PhaseChanged)
local caseBriefingLoaded = Signals.get(Signals.Names.CaseBriefingLoaded)
local requestPhaseChange = Signals.get(Signals.Names.RequestPhaseChange)
local requestCase = Signals.get(Signals.Names.RequestCase)

-- Fired with (player, summary) once a conclusion is accepted. A
-- BindableEvent, not the CaseClosedSummary RemoteEvent directly -- mirrors
-- ReasoningService/ObjectiveService's own onUpdated() pattern exactly, so
-- requestConclude stays a plain, unit-testable function (a RemoteEvent's
-- FireClient requires a real Player Instance and would reject a test's mock
-- player table; init.server.luau's bridge is the only thing that ever
-- touches the real RemoteEvent, same as every other service's bridge).
local caseClosedEvent: BindableEvent = Instance.new("BindableEvent")

function GameStateService.onCaseClosed(): BindableEvent
	return caseClosedEvent
end

-- Phase 5.4: a Solved close that plays a scene first (an outro) holds the
-- summary back until that scene is over -- finished, skipped or timed out --
-- and only then announces the close. Keyed by UserId, not by the player
-- table: a BindableEvent hands its listeners a copy of a table, so a mock
-- player (the unit tests') would never match itself; a UserId always does.
local pendingClose: { [number]: { cutsceneId: string, summary: Types.CaseClosedSummary } } = {}

StoryEvents.on("CutsceneFinished", function(player: Player, data: { [string]: any })
	local pending = pendingClose[player.UserId]
	if pending and pending.cutsceneId == data.cutsceneId then
		pendingClose[player.UserId] = nil
		caseClosedEvent:Fire(player, pending.summary)
	end
end)

-- True while this player's close is waiting on its outro.
function GameStateService.isClosingScenePlaying(player: Player): boolean
	return pendingClose[player.UserId] ~= nil
end

-- Fired with (player) once a replay is accepted (M4). The bootstrap bridge
-- respawns the character and re-pushes the fresh state -- both need a real
-- Player, so neither happens here (same reasoning as caseClosedEvent).
local replayEvent: BindableEvent = Instance.new("BindableEvent")

function GameStateService.onReplay(): BindableEvent
	return replayEvent
end

local function broadcast(phase: Types.GamePhase)
	phaseChanged:FireAllClients(phase)
end

--[[
	Phase 2L gameplay authorization for the Investigation -> CaseClosed edge,
	extended in Phase 2N to require a formal accusation.

	The state machine (GameStateMachine) only ever validates graph legality --
	whether this edge exists at all -- never whether a specific player is
	currently allowed to use it. That's a different question, answered here,
	at the same server boundary that already owns "is this phase change
	request valid": never from a client-supplied claim, always from this
	player's own server-side state (ObjectiveService / AccusationService,
	which read PlayerDataService -- the client never supplies or influences
	it).

	Two conditions, both server-side:
	  1. accusing is open for this player (every objective complete, or,
	     M9, the case's `accusationRules.opensAfter` objective), and
	  2. the player has made a formal accusation (AccusationService).
]]
local function canConclude(player: Player): boolean
	-- A player with no case state at all trivially has "no active
	-- objective" (ObjectiveService.getActiveObjectiveId returns nil for
	-- that reason too), which would otherwise let a data-less player
	-- conclude for the wrong reason. Require real progress to exist first.
	if not PlayerDataService.get(player) then
		return false
	end
	-- M9: accusing may open before every objective is done
	-- (accusationRules.opensAfter); without rules this is still "no
	-- objective left".
	if not AccusationService.isOpen(player) then
		return false
	end
	-- Phase 2N: an investigation is only concluded on the player's own
	-- accusation, never automatically and never on the mere absence of work.
	return AccusationService.hasAccusation(player)
end

-- A summary of this player's own case progress, computed entirely from
-- server-side state at the moment their conclusion is accepted, plus the
-- case's verdict on their accusation (M2). Every count is a real total.
--
-- Public (matching ObjectiveService.getActiveObjectiveId's pattern) so the
-- exact summary shown at the close is directly, synchronously testable --
-- the onCaseClosed BindableEvent that also carries it fires deferred.
function GameStateService.getClosingSummary(player: Player): Types.CaseClosedSummary?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	local caseDef = CaseService.getCase(data.caseState.caseId)
	if not caseDef then
		return nil
	end
	-- Phase 2O: restate the case at the close. Both lists are built from
	-- already-authorized state: only discovered timeline events, and only the
	-- player's own unlocked contradiction.
	local reasoning = ReasoningService.getPayload(player)
	return {
		objectivesCompleted = Util.count(data.caseState.completedObjectives),
		objectivesTotal = #caseDef.objectives,
		evidenceExamined = Util.count(data.caseState.discovered),
		evidenceTotal = #caseDef.evidence,
		contradictionsIdentified = Util.count(data.caseState.unlockedContradictions),
		-- Phase 2N: the player's own accusation and whether the evidence they
		-- actually unlocked is consistent with it.
		accusation = AccusationService.getResolution(player),
		-- Phase 2P: always chronological here, even if the accusation opened
		-- (M9) before OBJ-006 reconstructed the puzzle order -- the closing
		-- record restates what happened, not the shuffled presentation.
		timeline = TimelineService.getChronological(player),
		contradiction = if #reasoning.contradictions > 0 then reasoning.contradictions[1] else nil,
		verdict = AccusationService.getVerdict(player),
		mistakes = data.caseState.reasoningMistakes or 0,
		timelineReconstructed = TimelineService.isEstablished(player),
	}
end

function GameStateService.getPhase(): Types.GamePhase
	return machine.current :: Types.GamePhase
end

-- Force a phase on the shared machine (used by server logic).
function GameStateService.setPhase(phase: Types.GamePhase): boolean
	return machine:transition(phase)
end

--[[
	Phase 5.4: announce a close that has been accepted. A Solved case may play a
	scene first (its outro); the closing summary then follows when that scene
	is over. If no scene is authored, or it can't play (another is on), the
	summary comes at once, as it always did. Public so the hand-off can be
	tested without walking the whole phase machine (requestConclude calls it).
]]
function GameStateService.announceClose(player: Player)
	local summary = GameStateService.getClosingSummary(player)
	if not summary then
		return
	end
	local outroId = AccusationService.getOutroCutsceneId(player)
	if outroId and CutsceneService.play(player, outroId) then
		pendingClose[player.UserId] = { cutsceneId = outroId, summary = summary }
	else
		caseClosedEvent:Fire(player, summary)
	end
end

--[[
	Phase 2L: attempt to conclude this player's investigation
	(Investigation -> CaseClosed). Public and directly callable/testable,
	matching this codebase's established pattern (e.g. ObjectiveService.
	recordInteraction, ConversationService.begin): business logic lives in a
	plain function, the RemoteEvent handler is a thin dispatcher around it.

	Returns true only if the transition actually happened. Never trusts
	anything from the caller beyond which player is asking -- canConclude
	reads only this player's own server-side objective state.
]]
function GameStateService.requestConclude(player: Player): boolean
	if not canConclude(player) then
		return false
	end
	if not GameStateService.setPhase("CaseClosed") then
		return false
	end
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		PlayerDataService.setPhase(p, "CaseClosed")
	end
	broadcast("CaseClosed")
	GameStateService.announceClose(player)
	return true
end

--[[
	M4: start the case over from the closing screen. Only valid from
	CaseClosed, and only for a player with case data. Wipes this player's case
	state (evidence, statements, reasoning, objectives, accusation) and returns
	to the briefing via the graph's own edges (CaseClosed -> MainMenu ->
	CaseBriefing). Like every other transition, the phase itself is the
	server-wide singleton (single-player scope).
]]
function GameStateService.requestReplay(player: Player): boolean
	if not PlayerDataService.get(player) then
		return false
	end
	if GameStateService.getPhase() ~= "CaseClosed" then
		return false
	end
	if not GameStateService.setPhase("MainMenu") or not GameStateService.setPhase("CaseBriefing") then
		return false
	end

	pendingClose[player.UserId] = nil
	PlayerDataService.clear(player)
	PlayerDataService.initialize(player, ACTIVE_CASE)
	PlayerDataService.setPhase(player, "CaseBriefing")
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		PlayerDataService.setPhase(p, "CaseBriefing")
	end
	broadcast("CaseBriefing")
	replayEvent:Fire(player)
	return true
end

--[[
	Phase 5.5: the investigation has begun for this player. A case that names an
	opening scene (CaseDefinition.intro) starts it here, after the phase has been
	broadcast, so the client already knows it is in the investigation when the
	scene arrives. A case without one opens straight onto the investigation, as it
	always did. Only the player's own request to begin ever reaches this (the
	RequestPhaseChange handler below): nothing that sets the phase directly, a
	test or server logic, starts a scene as a side effect.
	Returns true if a scene was started.
]]
function GameStateService.beginInvestigation(player: Player): boolean
	return (CutsceneService.playIntro(player))
end

--[[
	The player asks to begin (Play on the title screen, or Begin on a briefing).
	Only valid from CaseBriefing: a client can't use this to walk the shared
	phase back into a briefing, or reopen a closed case. Returns true if the
	investigation began.
]]
function GameStateService.requestBegin(player: Player): boolean
	if not PlayerDataService.get(player) or GameStateService.getPhase() ~= "CaseBriefing" then
		return false
	end
	if not GameStateService.setPhase("Investigation") then
		return false
	end
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		PlayerDataService.setPhase(p, "Investigation")
	end
	broadcast("Investigation")
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		GameStateService.beginInvestigation(p)
	end
	return true
end

local function grantCase(player: Player)
	local payload = CaseService.buildClientPayload(player)
	if payload then
		caseBriefingLoaded:FireClient(player, payload)
	end
end

-- Entry point used by the server bootstrap when a player joins.
-- Initialises the player's phase and grants the current case.
function GameStateService.enterBriefingFor(player: Player)
	player:SetAttribute("ActiveCaseId", ACTIVE_CASE)
	-- Ensure at least the briefing phase is active so the case is presented.
	if GameStateService.getPhase() == "MainMenu" then
		GameStateService.setPhase("CaseBriefing")
	end
	PlayerDataService.setPhase(player, GameStateService.getPhase())
	phaseChanged:FireClient(player, GameStateService.getPhase())
	grantCase(player)
end

function GameStateService.start()
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		pendingClose[player.UserId] = nil
	end)
	machine:onEnter("CaseBriefing", function()
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			grantCase(player)
		end
	end)

	requestPhaseChange.OnServerEvent:Connect(function(player: Player, phase: Types.GamePhase)
		-- A client asks for exactly three moves, each checked by the function that
		-- owns it: begin the investigation, conclude it (which also needs an
		-- accusation, Phase 2L), and start again from the closing screen (M4).
		-- Any other phase it names is ignored.
		if phase == "Investigation" then
			GameStateService.requestBegin(player)
		elseif phase == "CaseClosed" then
			GameStateService.requestConclude(player)
		elseif phase == "CaseBriefing" then
			GameStateService.requestReplay(player)
		end
	end)

	requestCase.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			-- Resend both phase and case so clients that finished wiring their
			-- listeners after the initial PlayerAdded push still sync up.
			phaseChanged:FireClient(player, GameStateService.getPhase())
			grantCase(player)
		end
	end)
end

return GameStateService
