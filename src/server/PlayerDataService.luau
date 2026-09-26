--!strict
--[[
	PlayerDataService
	Authoritative, in-memory player data. No persistence/auth by design (Phase 1).

	Provides a clean PlayerData structure and lifecycle events.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))

local PlayerDataService = {}

local store: { [number]: Types.PlayerData } = {}
local initialized: { [number]: boolean } = {}

local playerReadyEvent: BindableEvent? = nil

local function createCaseState(caseId: string): Types.PlayerCaseState
	return {
		caseId = caseId,
		discovered = {},
		discoveredTimeline = {},
		objectiveProgress = {},
		completedObjectives = {},
		startedAt = Util.timestamp(),
		activeConversation = nil,
		completedConversations = {},
		dialogueFlags = {},
		usedChoices = {},
		metSuspects = {},
		unlockedStatements = {},
		unlockedContradictions = {},
		unlockedDeductions = {},
		accusationId = nil,
		accusationMotive = nil,
		accusationProof = nil,
		reasoningMistakes = 0,
		timelineEstablished = nil,
	}
end

function PlayerDataService.getSource(): BindableEvent
	if not playerReadyEvent then
		playerReadyEvent = Instance.new("BindableEvent")
	end
	return playerReadyEvent :: BindableEvent
end

function PlayerDataService.get(player: Player): Types.PlayerData?
	return store[player.UserId]
end

function PlayerDataService.require(player: Player): Types.PlayerData
	local data = store[player.UserId]
	if not data then
		error(`No PlayerData for {player.Name}`)
	end
	return data
end

function PlayerDataService.initialize(player: Player, caseId: string): Types.PlayerData
	if initialized[player.UserId] then
		return store[player.UserId]
	end

	local data: Types.PlayerData = {
		userId = player.UserId,
		name = player.Name,
		phase = "MainMenu",
		caseState = createCaseState(caseId),
		createdAt = Util.timestamp(),
	}

	store[player.UserId] = data
	initialized[player.UserId] = true

	PlayerDataService.getSource():Fire(player, data)
	return data
end

function PlayerDataService.setPhase(player: Player, phase: Types.GamePhase)
	local data = store[player.UserId]
	if data then
		data.phase = phase
	end
end

function PlayerDataService.clear(player: Player)
	store[player.UserId] = nil
	initialized[player.UserId] = nil
end

function PlayerDataService.start()
	-- Signal bootstrap completion for other services awaiting players.
	PlayerDataService.getSource()

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.clear(player)
	end)
end

return PlayerDataService
