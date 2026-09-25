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
local TouchControls = require(Modules:WaitForChild("TouchControls"))

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
local requestReasoning = Signals.wait(Signals.Names.RequestReasoning)
local requestAccusation = Signals.wait(Signals.Names.RequestAccusation)
local submitAccusation = Signals.wait(Signals.Names.SubmitAccusation)
local submitTimelineOrder = Signals.wait(Signals.Names.SubmitTimelineOrder)

local currentPhase: Types.GamePhase = "MainMenu"
local lastBriefing: Types.CaseBriefing? = nil
local lastCaseClosedSummary: Types.CaseClosedSummary? = nil
-- Set once the server has told us every objective is complete (Phase 2L).
-- Purely a UX gate for offering the conclude action -- the server
-- re-validates the actual request regardless of this flag.
local investigationComplete = false

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
	if currentPhase == "Investigation" then
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

local function applyPhase(phase: Types.GamePhase)
	currentPhase = phase
	-- The E key is active during the briefing (to begin), the investigation,
	-- and the closing screen (to investigate again, M4).
	local interactEnabled = phase == "CaseBriefing" or phase == "Investigation" or phase == "CaseClosed"

	if phase == "CaseBriefing" then
		-- A fresh case (first join or a replay): forget the last one's ending.
		investigationComplete = false
		lastCaseClosedSummary = nil
	end

	InputController.setInteractEnabled(interactEnabled)
	ObjectiveView.setActive(phase == "Investigation")
	if phase == "Investigation" then
		InteractionController.resumeScan()
	else
		InteractionController.pauseScan()
		InteractionPromptView.setPrompt(nil)
	end

	if phase == "CaseBriefing" then
		if lastBriefing then
			CaseBriefingView.show(lastBriefing)
		end
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

	-- Touch: the primary button performs whatever [E] would do right now,
	-- labelled accordingly; the side buttons mirror T / C / Q.
	TouchControls.start({
		primaryLabel = function(): string?
			if DialogueView.isOpen() or EvidencePanel.isOpen() then
				return "Continue"
			elseif currentPhase == "CaseBriefing" then
				return "Begin investigation"
			elseif currentPhase == "CaseClosed" then
				return "Investigate again"
			elseif currentPhase == "Investigation" and not AccusationView.isOpen() then
				local target = InteractionController.getCurrent()
				return if target then target.label else nil
			end
			return nil
		end,
		showInvestigationButtons = function(): boolean
			return currentPhase == "Investigation" and not DialogueView.isOpen()
		end,
		showAccuse = function(): boolean
			return currentPhase == "Investigation" and investigationComplete and not DialogueView.isOpen()
		end,
	})

	-- Interaction scanning.
	InteractionController.start()
	InteractionController.onPromptChanged().Event:Connect(function(prompt)
		if currentPhase ~= "Investigation" then
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
		if DialogueView.isOpen() then
			requestDialogueAdvance:FireServer()
		elseif EvidencePanel.isOpen() then
			-- [E] Continue: dismiss the readout and return to exploring.
			closeOverlays()
		elseif currentPhase == "CaseClosed" then
			-- [E] Investigate again. The server validates and resets.
			requestPhaseChange:FireServer("CaseBriefing")
		elseif currentPhase == "CaseBriefing" then
			requestPhaseChange:FireServer("Investigation")
		elseif currentPhase == "Investigation" then
			InteractionController.requestInteract()
		end
	end)

	-- Timeline and Case File are non-modal information overlays: they can be
	-- opened while exploring and are dismissed with their own key or ESC.
	-- Not while a dialogue is open, and mutually exclusive with each other
	-- (both are full-screen centered panels; showing both at once would
	-- overlap).
	InputController.onToggleTimeline(function()
		if currentPhase ~= "Investigation" or DialogueView.isOpen() or CaseFileView.isOpen() or AccusationView.isOpen() then
			return
		end
		dismissEvidence()
		TimelineView.toggle()
	end)

	InputController.onToggleCaseFile(function()
		if currentPhase ~= "Investigation" or DialogueView.isOpen() or TimelineView.isOpen() or AccusationView.isOpen() then
			return
		end
		dismissEvidence()
		CaseFileView.toggle()
	end)

	-- Phase 2L/2N: player-initiated conclusion. [Q] only does anything once
	-- the server has told us every objective is complete; it now opens the
	-- accusation picker rather than concluding directly, and the server
	-- re-validates both eligibility and the chosen accusation regardless of
	-- what this client believes.
	InputController.onConcludeInvestigation(function()
		if currentPhase ~= "Investigation" or not investigationComplete then
			return
		end
		if DialogueView.isOpen() or TimelineView.isOpen() or CaseFileView.isOpen() then
			return
		end
		dismissEvidence()
		AccusationView.toggle()
		-- The accusation is a decisive choice: no interacting behind it.
		if AccusationView.isOpen() then
			InteractionController.pauseScan()
		else
			InteractionController.resumeScan()
		end
	end)

	-- The player's chosen accusation. Only the id is sent; the server decides
	-- whether the player is eligible and records the accusation.
	AccusationView.onSelectionRequested().Event:Connect(function(accusationId: string)
		submitAccusation:FireServer(accusationId)
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
		requestPhaseChange:FireServer("Investigation")
	end)

	-- Server -> client events.
	phaseChanged.OnClientEvent:Connect(function(phase: Types.GamePhase)
		applyPhase(phase)
	end)

	caseBriefingLoaded.OnClientEvent:Connect(function(payload: Types.CasePayload)
		lastBriefing = payload.briefing
		if currentPhase == "CaseBriefing" then
			CaseBriefingView.show(payload.briefing)
		end
	end)

	evidenceDiscovered.OnClientEvent:Connect(function(payload: Types.EvidencePayload)
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
	end)

	timelineUpdated.OnClientEvent:Connect(function(payload: Types.TimelinePayload)
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
		investigationComplete = payload.allComplete
		ObjectiveView.showCompleted(payload)
	end)

	dialogueUpdated.OnClientEvent:Connect(function(payload: Types.DialoguePayload)
		if payload.active then
			EvidencePanel.close()
			-- Frame the suspect, same technique as examining evidence.
			local target = InteractionController.getCurrent()
			if target then
				local instance = target.instance
				local part = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart")
				if part then
					CameraController.examine(part)
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
		CaseFileView.update(payload)
	end)

	accusationUpdated.OnClientEvent:Connect(function(payload: Types.AccusationPayload)
		AccusationView.update(payload)
	end)

	caseClosedSummary.OnClientEvent:Connect(function(summary: Types.CaseClosedSummary)
		lastCaseClosedSummary = summary
		if currentPhase == "CaseClosed" then
			CaseClosedView.show(summary)
		end
	end)

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
