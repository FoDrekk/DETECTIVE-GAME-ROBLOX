--!strict
--[[
	ClientBootstrap
	Single entry point for the client. Wires input, interaction, views and
	the remote signal listeners.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local log = Logger.scoped("ClientBootstrap")

local Modules = script

local InputController = require(Modules:WaitForChild("InputController"))
local InteractionController = require(Modules:WaitForChild("InteractionController"))
local InteractionPromptView = require(Modules:WaitForChild("InteractionPromptView"))
local EvidencePanel = require(Modules:WaitForChild("EvidencePanel"))
local ObservationPanel = require(Modules:WaitForChild("ObservationPanel"))
local CaseBriefingView = require(Modules:WaitForChild("CaseBriefingView"))
local ObjectiveView = require(Modules:WaitForChild("ObjectiveView"))
local TimelineView = require(Modules:WaitForChild("TimelineView"))
local DialogueView = require(Modules:WaitForChild("DialogueView"))
local CaseFileView = require(Modules:WaitForChild("CaseFileView"))
local AccusationView = require(Modules:WaitForChild("AccusationView"))
local CaseClosedView = require(Modules:WaitForChild("CaseClosedView"))
local CameraController = require(Modules:WaitForChild("CameraController"))
local InputHints = require(Modules:WaitForChild("InputHints"))
local SoundController = require(Modules:WaitForChild("SoundController"))
local TouchControls = require(Modules:WaitForChild("TouchControls"))
local TitleScreenView = require(Modules:WaitForChild("TitleScreenView"))
local CutsceneView = require(Modules:WaitForChild("CutsceneView"))

local player = Players.LocalPlayer

local phaseChanged = Signals.wait(Signals.Names.PhaseChanged)
local evidenceDiscovered = Signals.wait(Signals.Names.EvidenceDiscovered)
local timelineUpdated = Signals.wait(Signals.Names.TimelineUpdated)
local objectiveUpdated = Signals.wait(Signals.Names.ObjectiveUpdated)
local objectiveCompleted = Signals.wait(Signals.Names.ObjectiveCompleted)
local caseBriefingLoaded = Signals.wait(Signals.Names.CaseBriefingLoaded)
local dialogueUpdated = Signals.wait(Signals.Names.DialogueUpdated)
local reasoningUpdated = Signals.wait(Signals.Names.ReasoningUpdated)
local accusationUpdated = Signals.wait(Signals.Names.AccusationUpdated)
local observationShown = Signals.wait(Signals.Names.ObservationShown)
local caseClosedSummary = Signals.wait(Signals.Names.CaseClosedSummary)
local requestPhaseChange = Signals.wait(Signals.Names.RequestPhaseChange)
local requestCase = Signals.wait(Signals.Names.RequestCase)
local requestObjectives = Signals.wait(Signals.Names.RequestObjectives)
local requestTimeline = Signals.wait(Signals.Names.RequestTimeline)
local requestDialogueAdvance = Signals.wait(Signals.Names.DialogueAdvance)
local requestDialogueClose = Signals.wait(Signals.Names.DialogueClose)
local requestDialogueChoose = Signals.wait(Signals.Names.DialogueChoose)
local requestReasoning = Signals.wait(Signals.Names.RequestReasoning)
local requestAccusation = Signals.wait(Signals.Names.RequestAccusation)
local reasoningFeedback = Signals.wait(Signals.Names.ReasoningFeedback)
local requestDialoguePresent = Signals.wait(Signals.Names.DialoguePresent)
local requestClaim = Signals.wait(Signals.Names.ClaimContradiction)
local requestAnswer = Signals.wait(Signals.Names.AnswerDeduction)
local submitAccusation = Signals.wait(Signals.Names.SubmitAccusation)
local submitTimelineOrder = Signals.wait(Signals.Names.SubmitTimelineOrder)
local cutsceneUpdated = Signals.wait(Signals.Names.CutsceneUpdated)
local cutsceneFinished = Signals.wait(Signals.Names.CutsceneFinished)

local currentPhase: Types.GamePhase = "MainMenu"
local lastBriefing: Types.CaseBriefing? = nil
-- Phase 5.5: the case opens on a scene in place of the briefing screen. Then
-- Play (on the title screen) or Investigate again goes straight to the
-- investigation, and the server starts the scene.
local introReplacesBriefing = false
-- The begin request has gone to the server for this case run (never sent twice).
local beginRequested = false
-- The client asked to begin and is waiting for the scene the server will start:
-- it holds the investigation's screen the way a scene on screen does.
local introPending = false
local applyPhase: (phase: Types.GamePhase) -> ()
local lastCaseClosedSummary: Types.CaseClosedSummary? = nil
-- Whether the server says this player may accuse now (M9: that can be
-- before every objective is done). Purely a UX gate for offering the
-- accusation -- the server re-validates the actual request regardless.
local accusationOpen = false
-- Announce the accusation opening once per case.
local accusationAnnounced = false

-- Close whichever overlay is open and return to exploration, so the examine
-- camera and paused interaction scan can never get stuck. A dialogue close is
-- a server request (state lives server-side); the view itself closes once the
-- server confirms via DialogueUpdated.
local function closeOverlays()
	if DialogueView.isOpen() then
		requestDialogueClose:FireServer()
	end
	EvidencePanel.close()
	ObservationPanel.close()
	TimelineView.close()
	CaseFileView.close()
	AccusationView.close()
	CameraController.stopExamining()
	if currentPhase == "Investigation" and not CutsceneView.isPlaying() and not introPending then
		InteractionController.resumeScan()
	end
end

-- Phase 5.5: ask the server to begin the investigation. For a case whose intro
-- replaces its briefing this is all Play does; the scene follows from the server.
local function beginInvestigation()
	if beginRequested then
		return
	end
	beginRequested = true
	if introReplacesBriefing then
		introPending = true
		task.delay(Config.Cutscene.IntroWait, function()
			if introPending and not CutsceneView.isPlaying() then
				-- No scene came: the investigation is simply on.
				introPending = false
				TitleScreenView.release()
				applyPhase(currentPhase)
			end
		end)
	end
	requestPhaseChange:FireServer("Investigation")
end

-- Show the briefing, or (for a case whose intro replaces it) begin at once, once
-- the title screen is out of the way.
local function showBriefingOrBegin()
	local briefing = lastBriefing
	if currentPhase ~= "CaseBriefing" or not briefing or TitleScreenView.isOpen() then
		return
	end
	if introReplacesBriefing then
		beginInvestigation()
	else
		CaseBriefingView.show(briefing)
	end
end

-- Phase 5.1: a scene takes the whole screen. Everything else steps aside
-- while it plays, and comes back the way the phase has it afterwards.
local function beforeCutscene()
	introPending = false
	EvidencePanel.close()
	ObservationPanel.close()
	TimelineView.close()
	CaseFileView.close()
	AccusationView.close()
	InteractionController.pauseScan()
	InteractionPromptView.setPrompt(nil)
	ObjectiveView.setActive(false)
	SoundController.setDucked(true)
end

local function afterCutscene()
	local talking = DialogueView.isOpen()
	ObjectiveView.setActive(currentPhase == "Investigation" and not talking)
	SoundController.setDucked(talking or currentPhase == "CaseClosed")
	if currentPhase == "Investigation" and not talking then
		InteractionController.resumeScan()
	end
end

-- Dismiss an evidence readout (and its close-up) before another panel opens,
-- so panels never stack on top of each other.
local function dismissEvidence()
	if EvidencePanel.isOpen() then
		EvidencePanel.close()
		CameraController.stopExamining()
		InteractionController.resumeScan()
	end
end

-- M6: remembered so a reasoning breakthrough (a new contradiction or
-- deduction, or the timeline being established) plays its cue exactly once.
local reasoningFactCount = 0
local timelineEstablished = false

function applyPhase(phase: Types.GamePhase)
	currentPhase = phase
	-- The E key is active during the briefing (to begin), the investigation,
	-- and the closing screen (to investigate again, M4).
	local interactEnabled = phase == "CaseBriefing" or phase == "Investigation" or phase == "CaseClosed"
	local sceneUp = CutsceneView.isPlaying() or introPending

	if phase == "CaseBriefing" then
		-- A fresh case (first join or a replay): forget the last one's ending.
		beginRequested = false
		introPending = false
		sceneUp = CutsceneView.isPlaying()
		accusationOpen = false
		accusationAnnounced = false
		lastCaseClosedSummary = nil
		reasoningFactCount = 0
		timelineEstablished = false
	end

	SoundController.setDucked(phase == "CaseClosed" or sceneUp)
	InputController.setInteractEnabled(interactEnabled)
	ObjectiveView.setActive(phase == "Investigation" and not sceneUp)
	if phase == "Investigation" and not sceneUp then
		InteractionController.resumeScan()
	else
		InteractionController.pauseScan()
		InteractionPromptView.setPrompt(nil)
	end

	if phase == "CaseBriefing" then
		-- Held back while the title screen is up; shown (or, for a case whose
		-- intro replaces it, skipped past) when it closes.
		showBriefingOrBegin()
	else
		CaseBriefingView.hide()
	end

	if phase == "CaseClosed" then
		if lastCaseClosedSummary then
			CaseClosedView.show(lastCaseClosedSummary)
		end
	else
		CaseClosedView.hide()
	end

	if phase == "Investigation" then
		EvidencePanel.close()
		ObservationPanel.close()
		TimelineView.close()
		DialogueView.close()
		CaseFileView.close()
		AccusationView.close()
		CameraController.stopExamining()
	elseif phase == "CaseClosed" or phase == "MainMenu" then
		EvidencePanel.close()
		ObservationPanel.close()
		TimelineView.close()
		DialogueView.close()
		CaseFileView.close()
		AccusationView.close()
	end
end

local function bootstrap()
	Logger.setMinSeverity(Config.Logging.MinSeverity :: Logger.Severity)

	-- Input scheme detection first: views bind their key hints to it.
	InputHints.start()
	SoundController.start()
	-- Input bindings (keyboard + gamepad) must exist before any phase.
	InputController.start()

	-- Views first so they exist before the first phase arrives.
	InteractionPromptView.start()
	EvidencePanel.start()
	ObservationPanel.start()
	CaseBriefingView.start()
	ObjectiveView.start()
	TimelineView.start()
	DialogueView.start()
	CaseFileView.start()
	AccusationView.start()
	CaseClosedView.start()
	CameraController.start()
	TitleScreenView.start()
	CutsceneView.start()

	-- Touch: the primary button performs whatever [E] would do right now,
	-- labelled accordingly; the side buttons mirror T / C / Q.
	TouchControls.start({
		primaryLabel = function(): string?
			if CutsceneView.isPlaying() then
				return CutsceneView.primaryLabel()
			elseif TitleScreenView.isOpen() then
				return "Play"
			elseif DialogueView.isOpen() then
				return DialogueView.primaryLabel()
			elseif EvidencePanel.isOpen() then
				return "Continue"
			elseif currentPhase == "CaseBriefing" then
				return if introReplacesBriefing then nil else "Begin investigation"
			elseif currentPhase == "CaseClosed" then
				return "Investigate again"
			elseif currentPhase == "Investigation" and not AccusationView.isOpen() then
				local target = InteractionController.getCurrent()
				return if target then target.label else nil
			end
			return nil
		end,
		primaryHold = function(): boolean
			return CutsceneView.isPlaying() and CutsceneView.primaryHold()
		end,
		showInvestigationButtons = function(): boolean
			return currentPhase == "Investigation" and not DialogueView.isOpen() and not CutsceneView.isPlaying()
		end,
		showAccuse = function(): boolean
			return currentPhase == "Investigation"
				and accusationOpen
				and not DialogueView.isOpen()
				and not CutsceneView.isPlaying()
		end,
	})

	-- Interaction scanning.
	InteractionController.start()
	InteractionController.onPromptChanged().Event:Connect(function(prompt)
		if currentPhase ~= "Investigation" or CutsceneView.isPlaying() or introPending then
			InteractionPromptView.setPrompt(nil)
			return
		end
		if prompt then
			InteractionPromptView.setPrompt(prompt.label)
		else
			InteractionPromptView.setPrompt(nil)
		end
	end)

	-- Input intents.
	-- Primary interact key (E) is routed by phase: continue an open dialogue,
	-- begin briefing, or interact.
	InputController.onInteract(function()
		if CutsceneView.isPlaying() then
			-- Phase 5.1: a scene on screen owns the primary input (skip,
			-- with a confirming second press).
			CutsceneView.handlePrimary()
		elseif TitleScreenView.isOpen() then
			SoundController.play("Tick")
			TitleScreenView.dismiss()
		elseif DialogueView.isOpen() then
			-- The view finishes a line that is still typing, and holds a line
			-- that is waiting for a question; otherwise the server continues.
			if not DialogueView.handlePrimary() then
				SoundController.play("Tick")
				requestDialogueAdvance:FireServer()
			end
		elseif EvidencePanel.isOpen() then
			-- [E] Continue: dismiss the readout and return to exploring.
			closeOverlays()
		elseif currentPhase == "CaseClosed" then
			-- [E] Investigate again. The server validates and resets.
			requestPhaseChange:FireServer("CaseBriefing")
		elseif currentPhase == "CaseBriefing" then
			-- (With an intro in place of the briefing this begins nothing new:
			-- the title screen's Play already did.)
			beginInvestigation()
		elseif currentPhase == "Investigation" and not introPending then
			InteractionController.requestInteract()
		end
	end)
	-- Phase 5.5: letting go of the primary input ends a hold that hadn't finished.
	InputController.onInteractReleased(CutsceneView.handlePrimaryReleased)

	-- Timeline and Case File are non-modal information overlays: they can be
	-- opened while exploring and are dismissed with their own key or ESC.
	-- Not while a dialogue is open, and mutually exclusive with each other
	-- (both are full-screen centered panels; showing both at once would
	-- overlap).
	InputController.onToggleTimeline(function()
		if currentPhase ~= "Investigation" or DialogueView.isOpen() or CaseFileView.isOpen() or AccusationView.isOpen() then
			return
		end
		if CutsceneView.isPlaying() then
			return
		end
		dismissEvidence()
		TimelineView.toggle()
		SoundController.play("Tick")
	end)

	InputController.onToggleCaseFile(function()
		if currentPhase ~= "Investigation" or DialogueView.isOpen() or TimelineView.isOpen() or AccusationView.isOpen() then
			return
		end
		if CutsceneView.isPlaying() then
			return
		end
		dismissEvidence()
		CaseFileView.toggle()
		SoundController.play("Tick")
	end)

	-- Phase 2L/2N: player-initiated conclusion. [Q] only does anything once
	-- the server has said accusing is open (M9: possibly before every
	-- objective is done); it opens the accusation, and the server
	-- re-validates both eligibility and the case made regardless of what
	-- this client believes.
	InputController.onConcludeInvestigation(function()
		if currentPhase ~= "Investigation" or not accusationOpen or CutsceneView.isPlaying() then
			return
		end
		if DialogueView.isOpen() or TimelineView.isOpen() or CaseFileView.isOpen() then
			return
		end
		dismissEvidence()
		AccusationView.toggle()
		SoundController.play("Tick")
		-- The accusation is a decisive choice: no interacting behind it.
		if AccusationView.isOpen() then
			InteractionController.pauseScan()
		else
			InteractionController.resumeScan()
		end
	end)

	-- The player's chosen accusation. Only the id is sent; the server decides
	-- whether the player is eligible and records the accusation.
	AccusationView.onSelectionRequested().Event:Connect(function(accusationId: string, motive: string?, proof: string?)
		submitAccusation:FireServer(accusationId, motive, proof)
	end)

	-- M9: evidence shown in a conversation ("" backs out). Only the id is
	-- sent; the server checks the player has found it.
	DialogueView.onPresentSelected().Event:Connect(function(evidenceId: string)
		SoundController.play("Tick")
		requestDialoguePresent:FireServer(if evidenceId == "" then nil else evidenceId)
	end)

	-- M9: the case file. Two facts the player says conflict, or an answer
	-- to an open question; the server judges both.
	CaseFileView.onClaimRequested().Event:Connect(function(a, b)
		SoundController.play("Tick")
		requestClaim:FireServer(a, b)
	end)
	CaseFileView.onAnswerRequested().Event:Connect(function(deductionId: string, optionId: string)
		SoundController.play("Tick")
		requestAnswer:FireServer(deductionId, optionId)
	end)

	-- The investigator's question. Only its id is sent; the server checks
	-- it is on offer before following it.
	DialogueView.onChoiceSelected().Event:Connect(function(choiceId: string)
		SoundController.play("Tick")
		requestDialogueChoose:FireServer(choiceId)
	end)

	-- M5: the player's reconstructed timeline order. Only the ordered ids are
	-- sent; the server validates them and responds with a fresh TimelineUpdate
	-- (established, and in canonical order if correct).
	TimelineView.onOrderSubmitted().Event:Connect(function(orderedIds: { string })
		submitTimelineOrder:FireServer(orderedIds)
	end)

	InputController.onClose(closeOverlays)
	EvidencePanel.onContinueRequested().Event:Connect(closeOverlays)
	-- Escape is reserved by the Roblox menu in live clients and never reaches
	-- the game; treat the menu opening as the player's "close" instead.
	GuiService.MenuOpened:Connect(closeOverlays)

	-- Briefing "begin" intent.
	CaseBriefingView.onBeginRequested().Event:Connect(function()
		beginInvestigation()
	end)

	-- Server -> client events.
	phaseChanged.OnClientEvent:Connect(function(phase: Types.GamePhase)
		applyPhase(phase)
	end)

	caseBriefingLoaded.OnClientEvent:Connect(function(payload: Types.CasePayload)
		lastBriefing = payload.briefing
		introReplacesBriefing = payload.introReplacesBriefing == true
		TitleScreenView.setCase(payload.briefing)
		TitleScreenView.setHandoff(introReplacesBriefing)
		showBriefingOrBegin()
	end)

	evidenceDiscovered.OnClientEvent:Connect(function(payload: Types.EvidencePayload)
		-- Phase 5.1: evidence handed over in a conversation. There is no
		-- object to frame and the conversation announces it (its own
		-- notice); the readout stays in the case file.
		if payload.granted then
			SoundController.play("EvidenceDiscovered")
			return
		end
		-- Frame the examined object, then present the evidence panel.
		local target = InteractionController.getCurrent()
		if target then
			local instance = target.instance
			local part = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart")
			if part then
				CameraController.examine(part)
			end
		end
		InteractionController.pauseScan()
		EvidencePanel.show(payload)
		if payload.revisited then
			SoundController.play("Tick")
		else
			SoundController.play("EvidenceDiscovered")
		end
	end)

	timelineUpdated.OnClientEvent:Connect(function(payload: Types.TimelinePayload)
		-- M5's reconstruction confirmed: the same "it clicks" cue as reasoning.
		if payload.established and not timelineEstablished then
			SoundController.play("Reasoning")
		end
		timelineEstablished = payload.established == true
		TimelineView.update(payload)
	end)

	-- Phase 2O: flavour observation for a non-evidence object. Purely
	-- presentational -- no camera framing, no scan pause, no discovery.
	observationShown.OnClientEvent:Connect(function(payload: Types.ObservationPayload)
		if currentPhase ~= "Investigation" then
			return
		end
		ObservationPanel.show(payload)
	end)

	objectiveUpdated.OnClientEvent:Connect(function(payload: Types.ObjectivePayload)
		ObjectiveView.update(payload)
	end)

	objectiveCompleted.OnClientEvent:Connect(function(payload: Types.ObjectivePayload)
		ObjectiveView.showCompleted(payload)
	end)

	dialogueUpdated.OnClientEvent:Connect(function(payload: Types.DialoguePayload)
		SoundController.setDucked(payload.active or currentPhase == "CaseClosed")
		-- The conversation takes the screen: the objective HUD steps aside.
		ObjectiveView.setActive(currentPhase == "Investigation" and not payload.active)
		if payload.active then
			InteractionPromptView.setPrompt(nil)
		end
		if payload.active then
			EvidencePanel.close()
			-- Frame the suspect's face from the player's side.
			local target = InteractionController.getCurrent()
			if target then
				local instance = target.instance
				local part = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart")
				if part then
					CameraController.faceSubject(part)
				end
			end
			InteractionController.pauseScan()
		else
			CameraController.stopExamining()
			InteractionController.resumeScan()
		end
		DialogueView.update(payload)
	end)

	reasoningUpdated.OnClientEvent:Connect(function(payload: Types.ReasoningPayload)
		local facts = #payload.contradictions + #payload.deductions
		if facts > reasoningFactCount then
			SoundController.play("Reasoning")
		end
		reasoningFactCount = facts
		CaseFileView.update(payload)
	end)

	accusationUpdated.OnClientEvent:Connect(function(payload: Types.AccusationPayload)
		accusationOpen = payload.open and payload.selected == nil
		-- M9: accusing can open with the case still unfolding. Say so once,
		-- quietly; it is the player's call when.
		if accusationOpen and not accusationAnnounced and currentPhase == "Investigation" then
			accusationAnnounced = true
			ObservationPanel.show({
				title = "You can make an accusation",
				body = InputHints.format(
					"Accuse",
					"Whenever you're ready. Name who, why, and what proves it. It's final."
				),
			})
		end
		AccusationView.update(payload)
	end)

	-- M9: what the server made of a pairing or an answer in the case file.
	reasoningFeedback.OnClientEvent:Connect(function(payload: Types.ReasoningFeedbackPayload)
		CaseFileView.showFeedback(payload)
	end)

	-- Phase 5.1: a scene to play, or the server ending the current one.
	cutsceneUpdated.OnClientEvent:Connect(function(payload: Types.CutscenePayload)
		if payload.active then
			beforeCutscene()
			CutsceneView.play(payload)
			-- The scene has the screen: the title's held black can lift.
			TitleScreenView.release()
		elseif CutsceneView.stop(payload.id) then
			afterCutscene()
		end
	end)

	-- The scene reached its end, or the investigator skipped it. Only the id
	-- and whether it was a skip travel; the server checks both.
	CutsceneView.onFinished().Event:Connect(function(cutsceneId: string, skipped: boolean)
		cutsceneFinished:FireServer(cutsceneId, skipped)
		afterCutscene()
	end)

	caseClosedSummary.OnClientEvent:Connect(function(summary: Types.CaseClosedSummary)
		lastCaseClosedSummary = summary
		if summary.verdict then
			-- M9: only a case that held gets the resolved sting.
			SoundController.play(if summary.verdict.grade == "Solved" then "VerdictCorrect" else "VerdictWrong")
		end
		if currentPhase == "CaseClosed" then
			CaseClosedView.show(summary)
		end
	end)

	-- M6: the title screen, once per session. Closing it reveals whatever the
	-- phase shows -- the briefing, on a first join.
	TitleScreenView.onDismissed().Event:Connect(function()
		showBriefingOrBegin()
	end)
	TitleScreenView.open()

	-- Join race guard: the server fires the phase/case on PlayerAdded, which can
	-- happen before these listeners are connected. Re-request both now that the
	-- handlers above are wired, so late-loading clients still receive state.
	requestCase:FireServer()
	requestObjectives:FireServer()
	requestTimeline:FireServer()
	requestReasoning:FireServer()
	requestAccusation:FireServer()

	log:info("client ready", { player = player.Name })
end

bootstrap()
