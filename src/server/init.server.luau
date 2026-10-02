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
local CutsceneService = require(Services:WaitForChild("CutsceneService"))
local RevealService = require(Services:WaitForChild("RevealService"))
local InteractionService = require(Services:WaitForChild("InteractionService"))
local GameStateService = require(Services:WaitForChild("GameStateService"))
local EnvironmentBake = require(Services:WaitForChild("EnvironmentBake"))
local SessionGuard = require(Services:WaitForChild("SessionGuard"))

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

	-- 0. The world: the office (shell, evidence props, furnishing, skyline) and
	-- its suspects. A place saved after an Edit-mode bake has it already and
	-- adopts it; an older or missing bake is built here (EnvironmentBake).
	EnvironmentBake.buildAll()

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
	local reasoningFeedbackEvent = Signals.get(Signals.Names.ReasoningFeedback)
	local cutsceneEvent = Signals.get(Signals.Names.CutsceneUpdated)
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
	-- Scripted scenes, and evidence props held back until the
	-- story reveals them (after the environment built them, step 0).
	CutsceneService.start()
	RevealService.start()
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

	ReasoningService.onFeedback().Event:Connect(function(player: Player, payload)
		reasoningFeedbackEvent:FireClient(player, payload)
	end)

	AccusationService.onUpdated().Event:Connect(function(player: Player, payload)
		accusationEvent:FireClient(player, payload)
	end)

	-- Flavour observation for a non-evidence interactable. Purely
	-- presentational; carries no story state.
	InteractionService.onObservation().Event:Connect(function(player: Player, payload)
		observationEvent:FireClient(player, payload)
	end)

	GameStateService.onCaseClosed().Event:Connect(function(player: Player, summary)
		caseClosedSummaryEvent:FireClient(player, summary)
	end)

	-- A scene to play, or the server ending the current one.
	CutsceneService.onUpdated().Event:Connect(function(player: Player, payload)
		cutsceneEvent:FireClient(player, payload)
	end)

	-- A replay starts the investigator back in the lobby with a clean
	-- case, pushing the same fresh state a newly joined player receives.
	GameStateService.onReplay().Event:Connect(function(player: Player)
		-- Props the last run revealed go back out of the world.
		RevealService.refresh(player)
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
	--    One investigator per server (see SessionGuard); the
	--    guard also absorbs the PlayerAdded/startup-sweep double report.
	local guard = SessionGuard.new(Config.Game.MaxInvestigators)
	local function onPlayerAdded(player: Player)
		local result = guard:admit(player.UserId)
		if result == "Duplicate" then
			return
		elseif result == "Full" then
			log:warn("server full; turning a second investigator away", { player = player.Name })
			player:Kick(Config.Game.FullServerMessage)
			return
		end
		PlayerDataService.initialize(player, Config.Game.AutoStartCase)
		RevealService.refresh(player)
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
		guard:release(player.UserId)
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

	-- 8b. Timeline reconstruction. The client sends only an ordered list
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

	-- The investigator picked a question. Only the choice id travels; the
	-- server re-checks that it is on the current line and available to this
	-- player before following it.
	local requestDialogueChoose = Signals.get(Signals.Names.DialogueChoose)
	requestDialogueChoose.OnServerEvent:Connect(function(player: Player, choiceId)
		if type(choiceId) ~= "string" then
			return
		end
		ConversationService.choose(player, choiceId)
	end)

	-- Showing evidence in a conversation. Only the evidence id travels
	-- (or nothing, to back out); the server checks the player has found it
	-- and that a presenting choice is waiting.
	local requestDialoguePresent = Signals.get(Signals.Names.DialoguePresent)
	requestDialoguePresent.OnServerEvent:Connect(function(player: Player, evidenceId)
		if evidenceId ~= nil and type(evidenceId) ~= "string" then
			return
		end
		ConversationService.present(player, evidenceId)
	end)

	-- The investigator pairs two facts in the case file, or answers an
	-- open question. ReasoningService checks the facts are the player's own
	-- and judges the connection against case data.
	local requestClaim = Signals.get(Signals.Names.ClaimContradiction)
	requestClaim.OnServerEvent:Connect(function(player: Player, a, b)
		ReasoningService.claimContradiction(player, a, b)
	end)

	local requestAnswer = Signals.get(Signals.Names.AnswerDeduction)
	requestAnswer.OnServerEvent:Connect(function(player: Player, deductionId, optionId)
		ReasoningService.answerDeduction(player, deductionId, optionId)
	end)

	-- 10. Reasoning (Case File) sync requests (join-race guard).
	local requestReasoning = Signals.get(Signals.Names.RequestReasoning)
	requestReasoning.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			ReasoningService.sendCurrent(player)
		end
	end)

	-- 11. Accusation. `RequestAccusation` is the join-race sync
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
	submitAccusation.OnServerEvent:Connect(function(player: Player, accusationId, motiveId, proofId)
		if type(accusationId) ~= "string" then
			return
		end
		-- The motive and proof, when the case asks for them. Anything
		-- that isn't a string is treated as not given.
		local motive = if type(motiveId) == "string" then motiveId else nil
		local proof = if type(proofId) == "string" then proofId else nil
		if AccusationService.accuse(player, accusationId, motive, proof) then
			-- The accusation was accepted (all objectives complete, valid id).
			-- Now — and only now — the case may conclude.
			GameStateService.requestConclude(player)
		end
	end)

	-- 12. The client reached the end of a scene, or the
	-- investigator skipped it. Only the id and the skip flag travel;
	-- CutsceneService checks it is the scene playing, that it may be
	-- skipped, and that it has actually had time to finish.
	local cutsceneFinished = Signals.get(Signals.Names.CutsceneFinished)
	cutsceneFinished.OnServerEvent:Connect(function(player: Player, cutsceneId, skipped)
		CutsceneService.finish(player, cutsceneId, skipped == true)
	end)

	log:info("server ready", {
		signals = #signals:GetChildren(),
		phase = GameStateService.getPhase(),
		caseId = Config.Game.AutoStartCase,
	})
end

bootstrap()
