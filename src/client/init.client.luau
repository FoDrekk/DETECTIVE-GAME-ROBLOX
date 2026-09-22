--!strict
--[[
	ClientBootstrap
	Single entry point for the client. Wires input, interaction, views and
	the remote signal listeners.
]]

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
local CaseBriefingView = require(Modules:WaitForChild("CaseBriefingView"))
local ObjectiveView = require(Modules:WaitForChild("ObjectiveView"))
local TimelineView = require(Modules:WaitForChild("TimelineView"))
local CameraController = require(Modules:WaitForChild("CameraController"))

local player = Players.LocalPlayer

local phaseChanged = Signals.wait(Signals.Names.PhaseChanged)
local evidenceDiscovered = Signals.wait(Signals.Names.EvidenceDiscovered)
local timelineUpdated = Signals.wait(Signals.Names.TimelineUpdated)
local objectiveUpdated = Signals.wait(Signals.Names.ObjectiveUpdated)
local objectiveCompleted = Signals.wait(Signals.Names.ObjectiveCompleted)
local caseBriefingLoaded = Signals.wait(Signals.Names.CaseBriefingLoaded)
local requestPhaseChange = Signals.wait(Signals.Names.RequestPhaseChange)
local requestCase = Signals.wait(Signals.Names.RequestCase)
local requestObjectives = Signals.wait(Signals.Names.RequestObjectives)
local requestTimeline = Signals.wait(Signals.Names.RequestTimeline)

local currentPhase: Types.GamePhase = "MainMenu"
local lastBriefing: Types.CaseBriefing? = nil

local function applyPhase(phase: Types.GamePhase)
	currentPhase = phase
	-- The E key is active during the briefing (to begin) and investigation.
	local interactEnabled = phase == "CaseBriefing" or phase == "Investigation"

	InputController.setInteractEnabled(interactEnabled)

	if phase == "CaseBriefing" then
		if lastBriefing then
			CaseBriefingView.show(lastBriefing)
		end
	else
		CaseBriefingView.hide()
	end

	if phase == "Investigation" then
		EvidencePanel.close()
		TimelineView.close()
		CameraController.stopExamining()
	elseif phase == "CaseClosed" or phase == "MainMenu" then
		EvidencePanel.close()
		TimelineView.close()
	end
end

local function bootstrap()
	Logger.setMinSeverity(Config.Logging.MinSeverity :: Logger.Severity)

	-- Input bindings (E = interact, ESC = close) must exist before any phase.
	InputController.start()

	-- Views first so they exist before the first phase arrives.
	InteractionPromptView.start()
	EvidencePanel.start()
	CaseBriefingView.start()
	ObjectiveView.start()
	TimelineView.start()
	CameraController.start()

	-- Interaction scanning.
	InteractionController.start()
	InteractionController.onPromptChanged().Event:Connect(function(prompt)
		if currentPhase ~= "Investigation" then
			InteractionPromptView.setPrompt(nil, nil)
			return
		end
		if prompt then
			InteractionPromptView.setPrompt(prompt.key, prompt.label)
		else
			InteractionPromptView.setPrompt(nil, nil)
		end
	end)

	-- Input intents.
	-- Primary interact key (E) is routed by phase: begin briefing, or interact.
	InputController.onInteract(function()
		if currentPhase == "CaseBriefing" then
			requestPhaseChange:FireServer("Investigation")
		elseif currentPhase == "Investigation" then
			InteractionController.requestInteract()
		end
	end)

	-- Timeline is a non-modal information overlay: it can be opened while
	-- exploring and is dismissed with T or ESC.
	InputController.onToggleTimeline(function()
		if currentPhase ~= "Investigation" then
			return
		end
		TimelineView.toggle()
	end)

	InputController.onClose(function()
		-- Close whichever overlay is open, then always return to exploration so
		-- the examine camera can never get stuck.
		if EvidencePanel.isOpen() then
			EvidencePanel.close()
		end
		TimelineView.close()
		CameraController.stopExamining()
		InteractionController.resumeScan()
	end)

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

	objectiveUpdated.OnClientEvent:Connect(function(payload: Types.ObjectivePayload)
		ObjectiveView.update(payload)
	end)

	objectiveCompleted.OnClientEvent:Connect(function(payload: Types.ObjectivePayload)
		ObjectiveView.showCompleted(payload)
	end)

	-- Join race guard: the server fires the phase/case on PlayerAdded, which can
	-- happen before these listeners are connected. Re-request both now that the
	-- handlers above are wired, so late-loading clients still receive state.
	requestCase:FireServer()
	requestObjectives:FireServer()
	requestTimeline:FireServer()

	log:info("client ready", { player = player.Name })
end

bootstrap()
