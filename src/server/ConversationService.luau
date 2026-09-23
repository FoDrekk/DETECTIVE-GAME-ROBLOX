--!strict
--[[
	ConversationService
	Authoritative, data-driven suspect conversations (Phase 2G).

	Conversations are authored in case data (CaseDefinition.conversations) as
	a small per-suspect graph of DialogueNodeDefinitions. This phase is a
	deterministic, linear vertical slice: no branching/choices, and no
	dialogue content is authored here -- this service only walks the graph
	the case data describes and reports state changes.

	The client never decides which node is next, whether a conversation is
	complete, or what statement unlocks. It only ever receives the single
	current node (Types.DialoguePayload) and sends a "continue"/"close"
	intent with no state of its own.

	Conversation mode: while a conversation is active, the player's Humanoid
	is speed/jump-locked server-side (see lockMovement/unlockMovement below).
	This is what keeps a conversation from going stale if the player would
	otherwise walk away mid-line -- it is structurally impossible, not
	detected after the fact, so no polling or distance checking is needed.
	Dialogue input (continue/close) is untouched; only walking/jumping is
	suspended, and only for the duration of the conversation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local log = Logger.scoped("ConversationService")

local ConversationService = {}

local dialogueUpdatedEvent: BindableEvent = Instance.new("BindableEvent")

function ConversationService.onUpdated(): BindableEvent
	return dialogueUpdatedEvent
end

--------------------------------------------------------------------------
-- Movement lock (controlled dialogue mode)
--------------------------------------------------------------------------

type SavedMovement = { walkSpeed: number, jumpPower: number, jumpHeight: number }
local savedMovement: { [number]: SavedMovement } = {}

-- Freeze the player's character for the duration of a conversation. A no-op
-- for mock/characterless players (tests), so this never affects test state.
local function lockMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	savedMovement[player.UserId] = {
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
end

-- Restore whatever movement values were captured by lockMovement. Safe to
-- call even if the player was never locked (e.g. no active conversation).
local function unlockMovement(player: Player)
	local saved = savedMovement[player.UserId]
	savedMovement[player.UserId] = nil
	if not saved then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = saved.walkSpeed
	humanoid.JumpPower = saved.jumpPower
	humanoid.JumpHeight = saved.jumpHeight
end

--------------------------------------------------------------------------
-- Data lookups (always through CaseService; never a raw case table)
--------------------------------------------------------------------------

local function findConversation(caseId: string, suspectId: string): Types.ConversationDefinition?
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return nil
	end
	for _, conversation in ipairs(caseDef.conversations) do
		if conversation.suspectId == suspectId then
			return conversation
		end
	end
	return nil
end

local function findStatement(caseId: string, statementId: string): Types.StatementDefinition?
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return nil
	end
	for _, statement in ipairs(caseDef.statements) do
		if statement.id == statementId then
			return statement
		end
	end
	return nil
end

-- A statement's client-facing content is never authored on the statement
-- itself: it is read from the source suspect's own data, so it can never
-- drift from the fact it represents.
local function buildStatementPayload(caseId: string, statement: Types.StatementDefinition): Types.StatementPayload?
	local suspect = CaseService.getSuspect(caseId, statement.suspectId)
	if not suspect then
		return nil
	end
	return {
		id = statement.id,
		suspectId = statement.suspectId,
		suspectName = suspect.name,
		label = statement.label,
		text = suspect.alibi,
	}
end

-- Unlock a statement for a player if not already unlocked. Returns the
-- payload only when this call newly unlocked it (nil on repeat).
local function unlockStatement(player: Player, data: Types.PlayerData, statementId: string): Types.StatementPayload?
	if data.caseState.unlockedStatements[statementId] then
		return nil
	end
	local statement = findStatement(data.caseState.caseId, statementId)
	if not statement then
		log:warn("dialogue node references an unknown statement", {
			player = player.Name,
			statementId = statementId,
		})
		return nil
	end
	local payload = buildStatementPayload(data.caseState.caseId, statement)
	if not payload then
		return nil
	end
	data.caseState.unlockedStatements[statementId] = true
	log:info("statement unlocked", { player = player.Name, statementId = statementId })
	StoryEvents.publish("StatementUnlocked", player, { statementId = statementId })
	return payload
end

local function buildNodePayload(
	suspect: Types.SuspectDefinition,
	node: Types.DialogueNodeDefinition,
	unlockedStatement: Types.StatementPayload?
): Types.DialoguePayload
	return {
		active = true,
		suspectId = suspect.id,
		suspectName = suspect.name,
		nodeId = node.id,
		speaker = node.speaker,
		text = node.text,
		canContinue = true,
		completed = false,
		unlockedStatement = unlockedStatement,
	}
end

local function inactivePayload(completed: boolean): Types.DialoguePayload
	return {
		active = false,
		suspectId = nil,
		suspectName = nil,
		nodeId = nil,
		speaker = nil,
		text = nil,
		canContinue = false,
		completed = completed,
		unlockedStatement = nil,
	}
end

-- Clears the active conversation and marks it complete exactly once
-- (idempotent: safe even if somehow reached twice for the same suspect).
local function completeConversation(player: Player, data: Types.PlayerData, suspectId: string)
	data.caseState.activeConversation = nil
	unlockMovement(player)

	if not data.caseState.completedConversations[suspectId] then
		data.caseState.completedConversations[suspectId] = true
		StoryEvents.publish("ConversationCompleted", player, { suspectId = suspectId })
		log:info("conversation completed", { player = player.Name, suspectId = suspectId })
	end

	dialogueUpdatedEvent:Fire(player, inactivePayload(true))
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Begin a conversation with a suspect. Rejects if the player already has an
-- active conversation, or if the suspect has no authored conversation.
function ConversationService.begin(player: Player, suspectId: string): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end

	if data.caseState.activeConversation then
		return false, "conversation-in-progress"
	end

	local suspect = CaseService.getSuspect(data.caseState.caseId, suspectId)
	if not suspect then
		return false, "unknown-suspect"
	end

	local conversation = findConversation(data.caseState.caseId, suspectId)
	if not conversation then
		return false, "no-conversation"
	end

	local node = conversation.nodes[conversation.startNodeId]
	if not node then
		log:warn("conversation start node is missing", {
			suspectId = suspectId,
			startNodeId = conversation.startNodeId,
		})
		return false, "malformed-conversation"
	end

	data.caseState.activeConversation = { suspectId = suspectId, nodeId = node.id }
	lockMovement(player)

	local unlocked = if node.statementId then unlockStatement(player, data, node.statementId) else nil
	dialogueUpdatedEvent:Fire(player, buildNodePayload(suspect, node, unlocked))
	StoryEvents.publish("ConversationStarted", player, { suspectId = suspectId })
	log:info("conversation started", { player = player.Name, suspectId = suspectId })
	return true, nil
end

-- Advance the player's active conversation by one step. Continuing past the
-- final node (next == nil) completes the conversation instead.
function ConversationService.advance(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end

	local active = data.caseState.activeConversation
	if not active then
		return false, "no-active-conversation"
	end

	local conversation = findConversation(data.caseState.caseId, active.suspectId)
	local suspect = CaseService.getSuspect(data.caseState.caseId, active.suspectId)
	if not conversation or not suspect then
		-- Config vanished under us (should not happen). Fail safe: clear
		-- state and release the player rather than leaving them frozen.
		data.caseState.activeConversation = nil
		unlockMovement(player)
		return false, "malformed-conversation"
	end

	local currentNode = conversation.nodes[active.nodeId]
	if not currentNode then
		data.caseState.activeConversation = nil
		unlockMovement(player)
		return false, "malformed-conversation"
	end

	if not currentNode.next then
		completeConversation(player, data, active.suspectId)
		return true, nil
	end

	local nextNode = conversation.nodes[currentNode.next]
	if not nextNode then
		log:warn("dialogue node references an unknown next node", {
			suspectId = active.suspectId,
			nodeId = currentNode.id,
			next = currentNode.next,
		})
		data.caseState.activeConversation = nil
		unlockMovement(player)
		return false, "malformed-conversation"
	end

	data.caseState.activeConversation = { suspectId = active.suspectId, nodeId = nextNode.id }

	local unlocked = if nextNode.statementId then unlockStatement(player, data, nextNode.statementId) else nil
	dialogueUpdatedEvent:Fire(player, buildNodePayload(suspect, nextNode, unlocked))
	return true, nil
end

-- Leave the active conversation early (the player closed the dialogue
-- before reaching the end). Does not mark the conversation complete and
-- does not publish ConversationCompleted; already-unlocked statements stay
-- unlocked. Safe to call with no active conversation.
function ConversationService.leave(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end
	if not data.caseState.activeConversation then
		return true, nil
	end
	data.caseState.activeConversation = nil
	unlockMovement(player)
	dialogueUpdatedEvent:Fire(player, inactivePayload(false))
	return true, nil
end

-- The player's current dialogue step, recomputed synchronously (no event
-- wait needed) -- the same spoiler-safe shape `onUpdated` delivers, minus
-- the transient `unlockedStatement` (this is a re-read, not a fresh
-- unlock). Useful for resync and for callers that need the answer directly.
function ConversationService.getCurrentPayload(player: Player): Types.DialoguePayload
	local data = PlayerDataService.get(player)
	local active = data and data.caseState.activeConversation
	if not data or not active then
		return inactivePayload(false)
	end

	local suspect = CaseService.getSuspect(data.caseState.caseId, active.suspectId)
	local conversation = findConversation(data.caseState.caseId, active.suspectId)
	local node = conversation and conversation.nodes[active.nodeId]
	if not suspect or not node then
		return inactivePayload(false)
	end

	return buildNodePayload(suspect, node, nil)
end

function ConversationService.isTalking(player: Player): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.caseState.activeConversation ~= nil
end

-- Read-only statement accessors for other systems (ReasoningService) that
-- need to know whether a statement is known, without duplicating the
-- unlock/lookup logic above. Never expose a statement before it is unlocked.

function ConversationService.isStatementUnlocked(player: Player, statementId: string): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.caseState.unlockedStatements[statementId] == true
end

function ConversationService.getUnlockedStatement(player: Player, statementId: string): Types.StatementPayload?
	local data = PlayerDataService.get(player)
	if not data or not data.caseState.unlockedStatements[statementId] then
		return nil
	end
	local statement = findStatement(data.caseState.caseId, statementId)
	if not statement then
		return nil
	end
	return buildStatementPayload(data.caseState.caseId, statement)
end

function ConversationService.start()
	-- Belt-and-suspenders: the character is destroyed on disconnect anyway
	-- (so there is nothing left to unlock), but this keeps savedMovement
	-- from accumulating an entry for a player who disconnected mid-dialogue.
	Players.PlayerRemoving:Connect(function(player: Player)
		savedMovement[player.UserId] = nil
	end)
	log:debug("started")
end

return ConversationService
