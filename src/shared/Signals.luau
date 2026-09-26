--!strict
--[[
	Signals
	Lightweight typed remote-event wrappers.

	The folder is expected to exist under ReplicatedStorage (declared in
	default.project.json). If it does not, it is created at runtime.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = {}

local RunService = game:GetService("RunService")

local FOLDER_NAME = "Signals"

-- Server: create-if-missing. Client: wait for replication (clients cannot
-- create instances under ReplicatedStorage).
local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 15) :: Folder
end

-- Returns a shared RemoteEvent, creating it on first use (server only).
function Signals.get(name: string): RemoteEvent
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if not existing and game:GetService("RunService"):IsServer() then
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	error(`Signal '{name}' is not available on the client yet`)
end

-- Client-side: yield until the server-created RemoteEvent replicates in.
function Signals.wait(name: string): RemoteEvent
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	return folder:WaitForChild(name, 10) :: RemoteEvent
end

function Signals.getFolder(): Folder
	return getFolder()
end

Signals.Names = table.freeze({
	-- Server -> Client
	PhaseChanged = "PhaseChanged",
	EvidenceDiscovered = "EvidenceDiscovered",
	TimelineUpdated = "TimelineUpdated",
	ObjectiveUpdated = "ObjectiveUpdated",
	ObjectiveCompleted = "ObjectiveCompleted",
	CaseBriefingLoaded = "CaseBriefingLoaded",
	DialogueUpdated = "DialogueUpdated",
	ReasoningUpdated = "ReasoningUpdated",
	AccusationUpdated = "AccusationUpdated",
	ObservationShown = "ObservationShown",
	CaseClosedSummary = "CaseClosedSummary",
	-- Client -> Server
	InteractionRequest = "InteractionRequest",
	RequestCase = "RequestCase",
	RequestObjectives = "RequestObjectives",
	RequestTimeline = "RequestTimeline",
	RequestPhaseChange = "RequestPhaseChange",
	DialogueAdvance = "DialogueAdvance",
	DialogueClose = "DialogueClose",
	DialogueChoose = "DialogueChoose",
	RequestReasoning = "RequestReasoning",
	RequestAccusation = "RequestAccusation",
	SubmitAccusation = "SubmitAccusation",
	SubmitTimelineOrder = "SubmitTimelineOrder",
})

return Signals
