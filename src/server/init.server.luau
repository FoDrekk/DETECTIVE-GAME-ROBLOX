--!strict
--[[
	ServerBootstrap
	Single entry point. Initialises services in dependency order and wires
	player lifecycle. Loaded by Rojo as Server/index.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))

local log = Logger.scoped("ServerBootstrap")

local Services = script

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local CaseService = require(Services:WaitForChild("CaseService"))
local EvidenceService = require(Services:WaitForChild("EvidenceService"))
local TimelineService = require(Services:WaitForChild("TimelineService"))
local ObjectiveService = require(Services:WaitForChild("ObjectiveService"))
local ConversationService = require(Services:WaitForChild("ConversationService"))
local ReasoningService = require(Services:WaitForChild("ReasoningService"))
local AccusationService = require(Services:WaitForChild("AccusationService"))
local InteractionService = require(Services:WaitForChild("InteractionService"))
local GameStateService = require(Services:WaitForChild("GameStateService"))
local OfficeRoom = require(Services:WaitForChild("OfficeRoom"))
local OfficeDetailing = require(Services:WaitForChild("OfficeDetailing"))
local SuspectSpawner = require(Services:WaitForChild("SuspectSpawner"))

--[[
	Fail loudly on unrecoverable configuration errors. A missing active case is
	a fatal misconfiguration: the game cannot present any content.
]]
local function assertConfiguration()
	local activeCase = CaseRegistry.get(Config.Game.AutoStartCase)
	if not activeCase then
		Logger.fatal("ServerBootstrap", "active case is not registered", {
			caseId = Config.Game.AutoStartCase,
		})
	end
end

local function bootstrap()
	Logger.setMinSeverity(Config.Logging.MinSeverity :: Logger.Severity)
	assertConfiguration()

	-- 0. Environment integration (lighting, ground, authored-content validation).
	OfficeRoom.start()
	OfficeDetailing.start()
	SuspectSpawner.start()

	-- 1. Create remote objects.
	local signals = Signals.getFolder()
	local evidenceEvent = Signals.get(Signals.Names.EvidenceDiscovered)
	local timelineEvent = Signals.get(Signals.Names.TimelineUpdated)
	local objectiveEvent = Signals.get(Signals.Names.ObjectiveUpdated)
	local objectiveCompletedEvent = Signals.get(Signals.Names.ObjectiveCompleted)
	local dialogueEvent = Signals.get(Signals.Names.DialogueUpdated)
	local reasoningEvent = Signals.get(Signals.Names.ReasoningUpdated)
	local accusationEvent = Signals.get(Signals.Names.AccusationUpdated)
	local observationEvent = Signals.get(Signals.Names.ObservationShown)
	local caseClosedSummaryEvent = Signals.get(Signals.Names.CaseClosedSummary)
	local requestObjectives = Signals.get(Signals.Names.RequestObjectives)
	local requestTimeline = Signals.get(Signals.Names.RequestTimeline)

	-- 2. Start stateless/registry services.
	PlayerDataService.start()
	CaseService.start()
	EvidenceService.start()
	TimelineService.start()
	ObjectiveService.start()
	ConversationService.start()
	ReasoningService.start()
	AccusationService.start()
	InteractionService.start()

	-- 3. Bridge service events to clients.
	EvidenceService.onDiscovered().Event:Connect(function(player: Player, payload)
		evidenceEvent:FireClient(player, payload)
	end)

	TimelineService.onUpdated().Event:Connect(function(player: Player, payload)
		timelineEvent:FireClient(player, payload)
	end)

	ObjectiveService.onUpdated().Event:Connect(function(player: Player, payload, justCompleted)
		objectiveEvent:FireClient(player, payload)
		if justCompleted then
			objectiveCompletedEvent:FireClient(player, payload)
		end
	end)

	ConversationService.onUpdated().Event:Connect(function(player: Player, payload)
		dialogueEvent:FireClient(player, payload)
	end)

	ReasoningService.onUpdated().Event:Connect(function(player: Player, payload)
		reasoningEvent:FireClient(player, payload)
	end)

	AccusationService.onUpdated().Event:Connect(function(player: Player, payload)
		accusationEvent:FireClient(player, payload)
	end)

	-- Phase 2O: flavour observation for a non-evidence interactable. Purely
	-- presentational; carries no story state.
	InteractionService.onObservation().Event:Connect(function(player: Player, payload)
		observationEvent:FireClient(player, payload)
	end)

	GameStateService.onCaseClosed().Event:Connect(function(player: Player, summary)
		caseClosedSummaryEvent:FireClient(player, summary)
	end)

	-- M4: a replay starts the investigator back in the lobby with a clean
	-- case, pushing the same fresh state a newly joined player receives.
	GameStateService.onReplay().Event:Connect(function(player: Player)
		-- The unit harness replays with mock player tables; only a real
		-- Player can be respawned or sent remotes.
		if typeof(player) ~= "Instance" then
			return
		end
		player:LoadCharacter()
		ObjectiveService.sendCurrent(player)
		TimelineService.sendCurrent(player)
		ReasoningService.sendCurrent(player)
		AccusationService.sendCurrent(player)
	end)

	-- 4. Phase machine (depends on cases + player data).
	GameStateService.start()

	-- 5. Player lifecycle. Initialise data, then let the phase machine
	--    grant the case and broadcast the phase.
	local handled: { [number]: boolean } = {}
	local function onPlayerAdded(player: Player)
		if handled[player.UserId] then
			return
		end
		handled[player.UserId] = true
		PlayerDataService.initialize(player, Config.Game.AutoStartCase)
		GameStateService.enterBriefingFor(player)
		ObjectiveService.sendCurrent(player)
		TimelineService.sendCurrent(player)
		ReasoningService.sendCurrent(player)
		AccusationService.sendCurrent(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		handled[player.UserId] = nil
	end)

	-- 6. Interaction requests.
	local requestEvent = Signals.get(Signals.Names.InteractionRequest)
	requestEvent.OnServerEvent:Connect(function(player: Player, instance: Instance, kind)
		InteractionService.handleRequest(player, instance, kind)
	end)

	-- 7. Objective sync requests (join-race guard, mirrors RequestCase).
	requestObjectives.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			ObjectiveService.sendCurrent(player)
		end
	end)

	-- 8. Timeline sync requests (join-race guard).
	requestTimeline.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			TimelineService.sendCurrent(player)
		end
	end)

	-- 8b. Timeline reconstruction (M5). The client sends only an ordered list
	-- of discovered event ids; TimelineService validates it against the
	-- canonical chronological order it computes server-side. Never trusts a
	-- client claim that the order is correct.
	local submitTimelineOrder = Signals.get(Signals.Names.SubmitTimelineOrder)
	submitTimelineOrder.OnServerEvent:Connect(function(player: Player, orderedIds)
		if type(orderedIds) ~= "table" then
			return
		end
		TimelineService.submitSequence(player, orderedIds)
	end)

	-- 9. Dialogue progression requests. Conversations are started via the
	-- existing InteractionRequest pipeline (Talk kind); these only continue
	-- or end an already-active conversation.
	local requestDialogueAdvance = Signals.get(Signals.Names.DialogueAdvance)
	requestDialogueAdvance.OnServerEvent:Connect(function(player: Player)
		ConversationService.advance(player)
	end)

	local requestDialogueClose = Signals.get(Signals.Names.DialogueClose)
	requestDialogueClose.OnServerEvent:Connect(function(player: Player)
		ConversationService.leave(player)
	end)

	-- 10. Reasoning (Case File) sync requests (join-race guard).
	local requestReasoning = Signals.get(Signals.Names.RequestReasoning)
	requestReasoning.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			ReasoningService.sendCurrent(player)
		end
	end)

	-- 11. Accusation (Phase 2N). `RequestAccusation` is the join-race sync
	-- guard, mirroring RequestReasoning; `SubmitAccusation` carries only the
	-- accusation id the player chose. AccusationService re-validates
	-- eligibility (all objectives complete) and the id server-side. A
	-- successfully recorded accusation is what authorizes the conclusion:
	-- GameStateService.requestConclude re-checks that authorization from
	-- server state, so this is a thin dispatch, never a client-driven verdict.
	local requestAccusation = Signals.get(Signals.Names.RequestAccusation)
	requestAccusation.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			AccusationService.sendCurrent(player)
		end
	end)

	local submitAccusation = Signals.get(Signals.Names.SubmitAccusation)
	submitAccusation.OnServerEvent:Connect(function(player: Player, accusationId)
		if type(accusationId) ~= "string" then
			return
		end
		if AccusationService.accuse(player, accusationId) then
			-- The accusation was accepted (all objectives complete, valid id).
			-- Now — and only now — the case may conclude.
			GameStateService.requestConclude(player)
		end
	end)

	log:info("server ready", {
		signals = #signals:GetChildren(),
		phase = GameStateService.getPhase(),
		caseId = Config.Game.AutoStartCase,
	})
end

bootstrap()
