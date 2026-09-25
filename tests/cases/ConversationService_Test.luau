--!strict
--[[
	Tests for ServerScriptService.Server.ConversationService.
	Covers conversation start/advance/leave, completion idempotency,
	statement unlock, spoiler-safe payload shape, StoryEvent publication,
	per-player isolation/cleanup, and the movement lock that keeps a
	conversation from going stale (Phase 2G / 2G.1).

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local StoryEvents = require(Server:WaitForChild("StoryEvents"))
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `CONV{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-LEGACY")
		return player
	end

	-- A minimal real character (Humanoid only) for movement-lock tests.
	-- Non-default starting values prove the lock restores the CAPTURED
	-- values, not hardcoded defaults.
	local function makeCharacter(): Model
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.WalkSpeed = 24
		humanoid.JumpPower = 60
		humanoid.Parent = character
		character.Parent = workspace
		return character
	end

	-- Swaps StoryEvents.publish for a spy for the duration of fn, always
	-- restoring the original afterward (even if fn throws). See Phase 2F's
	-- StoryEvents_Test for why this is used instead of listening on the
	-- real (deferred) BindableEvent from inside a test.
	local function withPublishSpy(fn: (calls: { { kind: string, player: any, data: any } }) -> ())
		local calls = {}
		local original = StoryEvents.publish
		StoryEvents.publish = function(kind, player, data)
			table.insert(calls, { kind = kind, player = player, data = data })
		end
		local ok, err = pcall(fn, calls)
		StoryEvents.publish = original
		if not ok then
			error(err, 0)
		end
	end

	t.test("begin starts SUS-001's conversation at its start node", function()
		local player = makePlayer()
		local ok = ConversationService.begin(player, "SUS-001")
		expect.truthy(ok)
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.activeConversation)
		expect.equal(data.caseState.activeConversation.suspectId, "SUS-001")
		expect.equal(data.caseState.activeConversation.nodeId, "SUS-001-1")
	end)

	t.test("begin rejects an unknown suspect id", function()
		local player = makePlayer()
		local ok, reason = ConversationService.begin(player, "SUS-999")
		expect.falsy(ok)
		expect.equal(reason, "unknown-suspect")
	end)

	-- Both of CASE-001's suspects now author a conversation (Phase 2I), so
	-- this rejection path is proven against a synthetic fixture suspect
	-- instead -- the underlying "known suspect, no conversation" case the
	-- service must still handle safely, without touching real case data.
	t.test("begin rejects a suspect with no authored conversation", function()
		CaseRegistry.register({
			id = "CASE-TEST-NO-CONVERSATION",
			title = "No-Conversation Fixture",
			description = "",
			suspects = { { id = "SUS-FIXTURE", name = "Fixture Suspect", role = "Fixture", alibi = "" } },
			locations = {},
			evidence = {},
			timeline = {},
			objectives = {},
			conversations = {},
			statements = {},
		})
		local id = t.nextUserId()
		local player = { UserId = id, Name = `CONV{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-NO-CONVERSATION")

		local ok, reason = ConversationService.begin(player, "SUS-FIXTURE")
		expect.falsy(ok)
		expect.equal(reason, "no-conversation")
	end)

	t.test("begin rejects starting a second conversation while one is active", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		local ok, reason = ConversationService.begin(player, "SUS-001")
		expect.falsy(ok)
		expect.equal(reason, "conversation-in-progress")
	end)

	t.test("advance walks the linear conversation node by node", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		local data = PlayerDataService.get(player)
		expect.equal(data.caseState.activeConversation.nodeId, "SUS-001-1")

		ConversationService.advance(player)
		expect.equal(data.caseState.activeConversation.nodeId, "SUS-001-2")

		ConversationService.advance(player)
		expect.equal(data.caseState.activeConversation.nodeId, "SUS-001-3")
	end)

	t.test("advancing past the final node completes the conversation", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- -> node 2
		ConversationService.advance(player) -- -> node 3 (final)
		ConversationService.advance(player) -- -> completes
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.activeConversation)
		expect.truthy(data.caseState.completedConversations["SUS-001"])
	end)

	t.test("advance rejects when there is no active conversation", function()
		local player = makePlayer()
		local ok, reason = ConversationService.advance(player)
		expect.falsy(ok)
		expect.equal(reason, "no-active-conversation")
	end)

	-- Duplicate/invalid state rejection: once a conversation has ended,
	-- advancing again (without restarting) is rejected the same way as
	-- never having started one.
	t.test("advance rejects a stale advance after completion", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player)
		ConversationService.advance(player)
		ConversationService.advance(player) -- completes
		local ok, reason = ConversationService.advance(player)
		expect.falsy(ok)
		expect.equal(reason, "no-active-conversation")
	end)

	t.test("reaching the alibi node unlocks the statement exactly once", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.unlockedStatements["STMT-SUS-001-ALIBI"])
		ConversationService.advance(player) -- node 2: unlocks the alibi statement
		expect.truthy(data.caseState.unlockedStatements["STMT-SUS-001-ALIBI"])
	end)

	t.test("completion is idempotent: ConversationCompleted publishes exactly once", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			ConversationService.begin(player, "SUS-001")
			ConversationService.advance(player)
			ConversationService.advance(player)
			ConversationService.advance(player) -- completes (1st time)
			-- Replay the whole conversation once more.
			ConversationService.begin(player, "SUS-001")
			ConversationService.advance(player)
			ConversationService.advance(player)
			ConversationService.advance(player) -- "completes" again, already recorded

			local completions = 0
			for _, call in ipairs(calls) do
				if call.kind == "ConversationCompleted" and call.player == player then
					completions += 1
				end
			end
			expect.equal(completions, 1)
		end)
	end)

	t.test("begin publishes ConversationStarted with the suspect id", function()
		local player = makePlayer()
		withPublishSpy(function(calls)
			ConversationService.begin(player, "SUS-001")
			expect.equal(#calls, 1)
			expect.equal(calls[1].kind, "ConversationStarted")
			expect.equal(calls[1].player, player)
			expect.equal(calls[1].data.suspectId, "SUS-001")
		end)
	end)

	t.test("leave clears the active conversation without completing it", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		withPublishSpy(function(calls)
			ConversationService.leave(player)
			expect.equal(#calls, 0)
		end)
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.activeConversation)
		expect.falsy(data.caseState.completedConversations["SUS-001"])
	end)

	t.test("leave is safe to call with no active conversation", function()
		local player = makePlayer()
		local ok = ConversationService.leave(player)
		expect.truthy(ok)
	end)

	t.test("leaving early preserves an already-unlocked statement", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- unlocks the alibi statement
		ConversationService.leave(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.unlockedStatements["STMT-SUS-001-ALIBI"])
	end)

	-- Spoiler safety: the synchronous payload accessor returns the same
	-- shape `onUpdated` delivers. It must carry only what is needed to
	-- render this one line -- never the raw node graph.
	t.test("current dialogue payload is spoiler-safe", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		local payload = ConversationService.getCurrentPayload(player)
		expect.truthy(payload.active)
		expect.equal(payload.nodeId, "SUS-001-1")
		expect.equal(payload.speaker, "Mara Reyes")
		-- The line matches the case's own authored start node -- never a
		-- hardcoded prose copy, so dialogue can be authored freely.
		local caseDef = CaseRegistry.get("CASE-TEST-LEGACY")
		local startNode = nil
		for _, conversation in ipairs(caseDef.conversations) do
			if conversation.suspectId == "SUS-001" then
				startNode = conversation.nodes[conversation.startNodeId]
			end
		end
		expect.truthy(startNode)
		expect.equal(payload.text, startNode.text)
		expect.falsy((payload :: any).next)
		expect.falsy((payload :: any).statementId)
		expect.falsy((payload :: any).nodes)
	end)

	t.test("getCurrentPayload reports inactive with no active conversation", function()
		local player = makePlayer()
		local payload = ConversationService.getCurrentPayload(player)
		expect.falsy(payload.active)
		expect.falsy(payload.text)
	end)

	-- Cross-player isolation: conversation state never leaks between
	-- players, and one player's requests cannot affect another's state.
	t.test("conversation state does not leak across players", function()
		local playerA = makePlayer()
		local playerB = makePlayer()
		ConversationService.begin(playerA, "SUS-001")
		ConversationService.advance(playerA)

		expect.falsy(ConversationService.isTalking(playerB))
		local dataB = PlayerDataService.get(playerB)
		expect.falsy(dataB.caseState.activeConversation)
		expect.falsy(dataB.caseState.unlockedStatements["STMT-SUS-001-ALIBI"])

		-- playerB has no active conversation to advance; playerA's is unaffected.
		local ok = ConversationService.advance(playerB)
		expect.falsy(ok)
		local dataA = PlayerDataService.get(playerA)
		expect.equal(dataA.caseState.activeConversation.nodeId, "SUS-001-2")
	end)

	-- Player leaves cleanup: PlayerDataService.clear (PlayerRemoving) wipes
	-- the whole caseState, including any active conversation, with no
	-- separate cleanup code required.
	t.test("player data clear wipes active conversation state", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		PlayerDataService.clear(player)
		expect.falsy(PlayerDataService.get(player))
		PlayerDataService.initialize(player, "CASE-TEST-LEGACY")
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.activeConversation)
	end)

	-- -----------------------------------------------------------------
	-- Movement lock (Phase 2G.1): a conversation structurally prevents
	-- walking away instead of detecting it after the fact, so it can never
	-- go stale without polling or distance checks.
	-- -----------------------------------------------------------------

	t.test("begin locks the player's movement while talking", function()
		local player = makePlayer()
		local character = makeCharacter()
		player.Character = character
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		ConversationService.begin(player, "SUS-001")

		expect.equal(humanoid.WalkSpeed, 0)
		expect.equal(humanoid.JumpPower, 0)
		expect.equal(humanoid.JumpHeight, 0)

		character:Destroy()
	end)

	-- Restores the CAPTURED values (24/60 from makeCharacter), not
	-- hardcoded Roblox defaults -- proving it saves/restores rather than
	-- assuming a fixed "normal" speed.
	t.test("completing a conversation restores the player's original movement", function()
		local player = makePlayer()
		local character = makeCharacter()
		player.Character = character
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- -> node 2
		ConversationService.advance(player) -- -> node 3 (final)
		ConversationService.advance(player) -- -> completes

		expect.equal(humanoid.WalkSpeed, 24)
		expect.equal(humanoid.JumpPower, 60)

		character:Destroy()
	end)

	t.test("leaving early also restores the player's original movement", function()
		local player = makePlayer()
		local character = makeCharacter()
		player.Character = character
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		ConversationService.begin(player, "SUS-001")
		expect.equal(humanoid.WalkSpeed, 0)

		ConversationService.leave(player)

		expect.equal(humanoid.WalkSpeed, 24)
		expect.equal(humanoid.JumpPower, 60)

		character:Destroy()
	end)

	-- Every other test in this file uses a characterless mock player; this
	-- makes the guarantee explicit: the movement lock is a no-op (not an
	-- error) when there is nothing to lock.
	t.test("movement lock is a no-op for a player with no character", function()
		local player = makePlayer()
		local ok = ConversationService.begin(player, "SUS-001")
		expect.truthy(ok)
		local ok2 = ConversationService.leave(player)
		expect.truthy(ok2)
	end)

	-- -----------------------------------------------------------------
	-- Read-only statement accessors (Phase 2H): what ReasoningService uses
	-- to resolve a "Statement"-kind fact reference, without duplicating the
	-- unlock/lookup logic above.
	-- -----------------------------------------------------------------

	t.test("isStatementUnlocked / getUnlockedStatement hide a locked statement", function()
		local player = makePlayer()
		expect.falsy(ConversationService.isStatementUnlocked(player, "STMT-SUS-001-ALIBI"))
		expect.falsy(ConversationService.getUnlockedStatement(player, "STMT-SUS-001-ALIBI"))
	end)

	t.test("isStatementUnlocked / getUnlockedStatement expose an unlocked statement", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- unlocks the alibi statement

		expect.truthy(ConversationService.isStatementUnlocked(player, "STMT-SUS-001-ALIBI"))
		local payload = ConversationService.getUnlockedStatement(player, "STMT-SUS-001-ALIBI")
		expect.truthy(payload)
		expect.equal(payload.id, "STMT-SUS-001-ALIBI")
		expect.equal(payload.suspectId, "SUS-001")
		expect.equal(payload.suspectName, "Mara Reyes")
		expect.equal(payload.label, "Alibi")
	end)

	-- Source consistency: the accessor's text is never a copy -- it always
	-- resolves live from the suspect's own authored alibi field.
	t.test("getUnlockedStatement text matches the suspect's authored alibi exactly", function()
		local ServerScriptService = game:GetService("ServerScriptService")
		local CaseService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("CaseService"))
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player)

		local payload = ConversationService.getUnlockedStatement(player, "STMT-SUS-001-ALIBI")
		local suspect = CaseService.getSuspect("CASE-TEST-LEGACY", "SUS-001")
		expect.truthy(payload)
		expect.truthy(suspect)
		expect.equal(payload.text, suspect.alibi)
	end)

	t.test("getUnlockedStatement returns nil for an unknown statement id", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player)
		expect.falsy(ConversationService.getUnlockedStatement(player, "STMT-DOES-NOT-EXIST"))
	end)

	-- -----------------------------------------------------------------
	-- SUS-002 / Victor Lane (Phase 2I): the same conversation mechanics
	-- proven above for Mara, now exercised against Victor's own real,
	-- already-authored data -- not a duplicate contract, the same service
	-- and the same case's second suspect.
	-- -----------------------------------------------------------------

	t.test("begin starts SUS-002's conversation at its start node", function()
		local player = makePlayer()
		local ok = ConversationService.begin(player, "SUS-002")
		expect.truthy(ok)
		local data = PlayerDataService.get(player)
		expect.truthy(data and data.caseState.activeConversation)
		expect.equal(data.caseState.activeConversation.suspectId, "SUS-002")
		expect.equal(data.caseState.activeConversation.nodeId, "SUS-002-1")
	end)

	t.test("advancing SUS-002's conversation unlocks his alibi statement and completes", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-002")
		ConversationService.advance(player) -- -> alibi node (SUS-002-2), unlocks the statement
		expect.truthy(ConversationService.isStatementUnlocked(player, "STMT-SUS-002-ALIBI"))

		ConversationService.advance(player) -- -> closing node (SUS-002-3, final)
		ConversationService.advance(player) -- -> completes
		local data = PlayerDataService.get(player)
		expect.falsy(data.caseState.activeConversation)
		expect.truthy(data.caseState.completedConversations["SUS-002"])
	end)

	t.test("SUS-002's unlocked statement text matches his authored alibi exactly", function()
		local ServerScriptService = game:GetService("ServerScriptService")
		local CaseService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("CaseService"))
		local player = makePlayer()
		ConversationService.begin(player, "SUS-002")
		ConversationService.advance(player)

		local payload = ConversationService.getUnlockedStatement(player, "STMT-SUS-002-ALIBI")
		local suspect = CaseService.getSuspect("CASE-TEST-LEGACY", "SUS-002")
		expect.truthy(payload)
		expect.truthy(suspect)
		expect.equal(payload.text, suspect.alibi)
		expect.equal(payload.suspectName, "Victor Lane")
	end)

	t.test("SUS-001 and SUS-002 conversations do not interfere with each other", function()
		local player = makePlayer()
		ConversationService.begin(player, "SUS-001")
		local ok = ConversationService.begin(player, "SUS-002")
		expect.falsy(ok) -- already talking to Mara; matches the existing single-active-conversation rule

		ConversationService.leave(player)
		local startedVictor = ConversationService.begin(player, "SUS-002")
		expect.truthy(startedVictor)
		local data = PlayerDataService.get(player)
		expect.equal(data.caseState.activeConversation.suspectId, "SUS-002")
	end)
end
