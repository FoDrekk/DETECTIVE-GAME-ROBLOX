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
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))
local AccusationService = require(script.Parent:WaitForChild("AccusationService"))
local TimelineService = require(script.Parent:WaitForChild("TimelineService"))
local ReasoningService = require(script.Parent:WaitForChild("ReasoningService"))

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
	  1. no active objective remains (every objective complete), and
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
	if ObjectiveService.getActiveObjectiveId(player) ~= nil then
		return false
	end
	-- Phase 2N: an investigation is only concluded on the player's own
	-- accusation, never automatically and never on the mere absence of work.
	return AccusationService.hasAccusation(player)
end

-- A factual summary of this player's own case progress, computed entirely
-- from server-side state at the moment their conclusion is accepted. Never
-- a verdict; every field is a real count, not a CASE-001-specific number.
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
	-- Phase 2O: restate the case factually at the close. Both lists are built
	-- from already-authorized state: only discovered timeline events, and only
	-- the player's own unlocked contradiction. Never hidden content, never a
	-- verdict.
	local reasoning = ReasoningService.getPayload(player)
	return {
		objectivesCompleted = Util.count(data.caseState.completedObjectives),
		objectivesTotal = #caseDef.objectives,
		evidenceExamined = Util.count(data.caseState.discovered),
		evidenceTotal = #caseDef.evidence,
		contradictionsIdentified = Util.count(data.caseState.unlockedContradictions),
		-- Phase 2N: the player's own accusation and whether the evidence they
		-- actually unlocked is consistent with it. Never a verdict.
		accusation = AccusationService.getResolution(player),
		timeline = TimelineService.getDiscovered(player),
		contradiction = if #reasoning.contradictions > 0 then reasoning.contradictions[1] else nil,
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
	local summary = GameStateService.getClosingSummary(player)
	if summary then
		caseClosedEvent:Fire(player, summary)
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
	machine:onEnter("CaseBriefing", function()
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			grantCase(player)
		end
	end)

	requestPhaseChange.OnServerEvent:Connect(function(player: Player, phase: Types.GamePhase)
		if type(phase) ~= "string" then
			return
		end
		if not PlayerDataService.get(player) then
			return
		end
		-- CaseClosed additionally requires gameplay authorization (Phase
		-- 2L), not just graph legality -- dispatched to the dedicated,
		-- independently-testable function that owns it.
		if phase == "CaseClosed" then
			GameStateService.requestConclude(player)
			return
		end
		-- Only allow the shared, server-validated transition.
		if GameStateService.setPhase(phase) then
			for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
				PlayerDataService.setPhase(p, phase)
			end
			broadcast(phase)
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
