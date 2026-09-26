--!strict
--[[
	ConversationService
	Authoritative, data-driven suspect conversations (Phase 2G).

	Conversations are authored in case data (CaseDefinition.conversations) as
	a small per-suspect graph of DialogueNodeDefinitions. No dialogue content
	is authored here -- this service only walks the graph the case data
	describes and reports state changes.

	Branching (interrogation): a node may offer the investigator choices.
	Which choices are offered depends on what this player already knows
	(evidence, statements, contradictions, deductions) and on what happened
	earlier in their conversations (flags set by nodes, `once` questions
	already asked). Where a conversation starts is chosen the same way
	(`entries`), so a character can greet the investigator differently the
	second time, or stay cold after being called a liar. A graph without
	choices/entries/flags behaves exactly like the original linear chain.

	The client never decides which node is next, whether a conversation is
	complete, or what statement unlocks. It only ever receives the single
	current node (Types.DialoguePayload) -- plus the words of the choices it
	may pick, never where they lead -- and sends a "continue"/"close"/"choose
	<id>" intent with no state of its own. A choice id is re-validated
	against the player's own state before it is honoured.

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
local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))

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
		text = statement.text or suspect.alibi,
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

--------------------------------------------------------------------------
-- Conditions and choices
--------------------------------------------------------------------------

local function conditionHolds(data: Types.PlayerData, condition: Types.DialogueCondition): boolean
	local state = data.caseState
	local known: boolean
	if condition.kind == "Evidence" then
		known = state.discovered[condition.id] ~= nil
	elseif condition.kind == "Statement" then
		known = state.unlockedStatements[condition.id] == true
	elseif condition.kind == "Contradiction" then
		known = state.unlockedContradictions[condition.id] == true
	elseif condition.kind == "Deduction" then
		known = state.unlockedDeductions[condition.id] == true
	elseif condition.kind == "Flag" then
		known = state.dialogueFlags[condition.id] == true
	else
		return false
	end
	if condition.negate then
		return not known
	end
	return known
end

local function conditionsHold(data: Types.PlayerData, conditions: { Types.DialogueCondition }?): boolean
	if not conditions then
		return true
	end
	for _, condition in ipairs(conditions) do
		if not conditionHolds(data, condition) then
			return false
		end
	end
	return true
end

local function choiceKey(suspectId: string, choiceId: string): string
	return `{suspectId}/{choiceId}`
end

-- The choices a node offers (its own, or borrowed via `choicesFrom`).
local function nodeChoices(
	conversation: Types.ConversationDefinition,
	node: Types.DialogueNodeDefinition
): { Types.DialogueChoiceDefinition }?
	if node.choices then
		return node.choices
	end
	if node.choicesFrom then
		local source = conversation.nodes[node.choicesFrom]
		return source and source.choices
	end
	return nil
end

-- The choices this player may pick at `node` right now.
local function availableChoices(
	data: Types.PlayerData,
	conversation: Types.ConversationDefinition,
	node: Types.DialogueNodeDefinition
): { Types.DialogueChoiceDefinition }
	local out = {}
	local choices = nodeChoices(conversation, node)
	if not choices then
		return out
	end
	for _, choice in ipairs(choices) do
		local used = choice.once and data.caseState.usedChoices[choiceKey(conversation.suspectId, choice.id)]
		if not used and conditionsHold(data, choice.requires) then
			table.insert(out, choice)
		end
	end
	return out
end

local function buildNodePayload(
	suspect: Types.SuspectDefinition,
	node: Types.DialogueNodeDefinition,
	unlockedStatement: Types.StatementPayload?,
	choices: { Types.DialogueChoiceDefinition },
	prompt: string?
): Types.DialoguePayload
	local offered: { Types.DialogueChoicePayload }? = nil
	if #choices > 0 then
		local list = {}
		for _, choice in ipairs(choices) do
			table.insert(list, { id = choice.id, text = choice.text })
		end
		offered = list
	end
	return {
		active = true,
		suspectId = suspect.id,
		suspectName = suspect.name,
		suspectRole = suspect.role,
		nodeId = node.id,
		speaker = node.speaker,
		text = node.text,
		isPlayer = node.isPlayer == true,
		canContinue = offered == nil,
		completed = false,
		unlockedStatement = unlockedStatement,
		choices = offered,
		prompt = prompt,
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

-- Make `node` the player's current line: remember what it sets, unlock its
-- statement, and send it (with whatever choices it now offers).
local function enterNode(
	player: Player,
	data: Types.PlayerData,
	suspect: Types.SuspectDefinition,
	conversation: Types.ConversationDefinition,
	node: Types.DialogueNodeDefinition,
	prompt: string?
)
	data.caseState.activeConversation = { suspectId = suspect.id, nodeId = node.id }
	if node.setFlags then
		for _, flag in ipairs(node.setFlags) do
			data.caseState.dialogueFlags[flag] = true
		end
	end
	if node.clearFlags then
		for _, flag in ipairs(node.clearFlags) do
			data.caseState.dialogueFlags[flag] = nil
		end
	end
	local unlocked = if node.statementId then unlockStatement(player, data, node.statementId) else nil
	dialogueUpdatedEvent:Fire(
		player,
		buildNodePayload(suspect, node, unlocked, availableChoices(data, conversation, node), prompt)
	)
end

-- Where this player's conversation with the suspect starts right now.
local function entryNodeId(data: Types.PlayerData, conversation: Types.ConversationDefinition): string
	if conversation.entries then
		for _, entry in ipairs(conversation.entries) do
			if conditionsHold(data, entry.requires) then
				return entry.node
			end
		end
	end
	return conversation.startNodeId
end

-- Fail safe for a graph that points somewhere that does not exist: clear
-- state and release the player rather than leaving them frozen.
local function abandon(player: Player, data: Types.PlayerData): (boolean, string?)
	data.caseState.activeConversation = nil
	unlockMovement(player)
	dialogueUpdatedEvent:Fire(player, inactivePayload(false))
	return false, "malformed-conversation"
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

	local startId = entryNodeId(data, conversation)
	local node = conversation.nodes[startId]
	if not node then
		log:warn("conversation start node is missing", {
			suspectId = suspectId,
			startNodeId = startId,
		})
		return false, "malformed-conversation"
	end

	data.caseState.metSuspects[suspectId] = true
	lockMovement(player)
	enterNode(player, data, suspect, conversation, node, nil)
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
		-- Config vanished under us (should not happen).
		return abandon(player, data)
	end

	local currentNode = conversation.nodes[active.nodeId]
	if not currentNode then
		return abandon(player, data)
	end

	-- A line that is waiting for the investigator to pick a question cannot
	-- be skipped past with "continue".
	if #availableChoices(data, conversation, currentNode) > 0 then
		return false, "choice-required"
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
		return abandon(player, data)
	end

	enterNode(player, data, suspect, conversation, nextNode, nil)
	return true, nil
end

-- The investigator picks one of the choices on the current line. Only a
-- choice that is currently available to this player (its conditions hold
-- and, if `once`, it has not been used) is honoured.
function ConversationService.choose(player: Player, choiceId: string): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "no-player-data"
	end
	local active = data.caseState.activeConversation
	if not active then
		return false, "no-active-conversation"
	end
	if type(choiceId) ~= "string" then
		return false, "invalid-choice"
	end

	local conversation = findConversation(data.caseState.caseId, active.suspectId)
	local suspect = CaseService.getSuspect(data.caseState.caseId, active.suspectId)
	local currentNode = conversation and conversation.nodes[active.nodeId]
	if not conversation or not suspect or not currentNode then
		return abandon(player, data)
	end

	local picked: Types.DialogueChoiceDefinition? = nil
	for _, choice in ipairs(availableChoices(data, conversation, currentNode)) do
		if choice.id == choiceId then
			picked = choice
			break
		end
	end
	if not picked then
		return false, "invalid-choice"
	end

	local target = conversation.nodes[picked.next]
	if not target then
		log:warn("dialogue choice references an unknown node", {
			suspectId = active.suspectId,
			choiceId = picked.id,
			next = picked.next,
		})
		return abandon(player, data)
	end

	if picked.once then
		data.caseState.usedChoices[choiceKey(active.suspectId, picked.id)] = true
	end
	enterNode(player, data, suspect, conversation, target, picked.text)
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
	if not suspect or not node or not conversation then
		return inactivePayload(false)
	end

	return buildNodePayload(suspect, node, nil, availableChoices(data, conversation, node), nil)
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

--[[
	Structural check of a case's conversations: every node, choice, entry and
	condition must point at something that exists. Returns human-readable
	problems (empty when the graph is sound). Pure: no player state.
]]
function ConversationService.validate(caseDef: Types.CaseDefinition): { string }
	local problems = {}
	local statements: { [string]: boolean } = {}
	for _, statement in ipairs(caseDef.statements) do
		statements[statement.id] = true
	end
	local known: { [string]: { [string]: boolean } } = {
		Evidence = {},
		Statement = statements,
		Contradiction = {},
		Deduction = {},
	}
	for _, evidence in ipairs(caseDef.evidence) do
		known.Evidence[evidence.id] = true
	end
	for _, contradiction in ipairs(caseDef.contradictions or {}) do
		known.Contradiction[contradiction.id] = true
	end
	for _, deduction in ipairs(caseDef.deductions or {}) do
		known.Deduction[deduction.id] = true
	end

	-- Flags must be set somewhere to be worth testing.
	local flagsSet: { [string]: boolean } = {}
	for _, conversation in ipairs(caseDef.conversations) do
		for _, node in pairs(conversation.nodes) do
			for _, flag in ipairs(node.setFlags or {}) do
				flagsSet[flag] = true
			end
		end
	end

	local function checkConditions(where: string, conditions: { Types.DialogueCondition }?)
		for _, condition in ipairs(conditions or {}) do
			if condition.kind == "Flag" then
				if not flagsSet[condition.id] then
					table.insert(problems, `{where}: flag '{condition.id}' is never set`)
				end
			elseif not known[condition.kind] then
				table.insert(problems, `{where}: unknown condition kind '{condition.kind}'`)
			elseif not known[condition.kind][condition.id] then
				table.insert(problems, `{where}: unknown {condition.kind} '{condition.id}'`)
			end
		end
	end

	for _, conversation in ipairs(caseDef.conversations) do
		local nodes = conversation.nodes
		local label = conversation.suspectId
		if not nodes[conversation.startNodeId] then
			table.insert(problems, `{label}: start node '{conversation.startNodeId}' is missing`)
		end
		for index, entry in ipairs(conversation.entries or {}) do
			if not nodes[entry.node] then
				table.insert(problems, `{label}: entry {index} points at missing node '{entry.node}'`)
			end
			checkConditions(`{label} entry {index}`, entry.requires)
		end
		for key, node in pairs(nodes) do
			local where = `{label}/{key}`
			if node.id ~= key then
				table.insert(problems, `{where}: node id '{node.id}' does not match its key`)
			end
			if node.next and not nodes[node.next] then
				table.insert(problems, `{where}: next '{node.next}' is missing`)
			end
			if node.statementId and not statements[node.statementId] then
				table.insert(problems, `{where}: unknown statement '{node.statementId}'`)
			end
			if node.choicesFrom then
				local source = nodes[node.choicesFrom]
				if not source then
					table.insert(problems, `{where}: choicesFrom '{node.choicesFrom}' is missing`)
				elseif not source.choices then
					table.insert(problems, `{where}: choicesFrom '{node.choicesFrom}' has no choices`)
				end
			end
			local seen: { [string]: boolean } = {}
			for _, choice in ipairs(node.choices or {}) do
				if seen[choice.id] then
					table.insert(problems, `{where}: duplicate choice id '{choice.id}'`)
				end
				seen[choice.id] = true
				if not nodes[choice.next] then
					table.insert(problems, `{where}/{choice.id}: next '{choice.next}' is missing`)
				end
				checkConditions(`{where}/{choice.id}`, choice.requires)
			end
		end
	end
	return problems
end

function ConversationService.start()
	for caseId, caseDef in pairs(CaseRegistry.getAll()) do
		for _, problem in ipairs(ConversationService.validate(caseDef)) do
			log:warn("conversation graph problem", { caseId = caseId, problem = problem })
		end
	end
	-- Belt-and-suspenders: the character is destroyed on disconnect anyway
	-- (so there is nothing left to unlock), but this keeps savedMovement
	-- from accumulating an entry for a player who disconnected mid-dialogue.
	Players.PlayerRemoving:Connect(function(player: Player)
		savedMovement[player.UserId] = nil
	end)
	log:debug("started")
end

return ConversationService
