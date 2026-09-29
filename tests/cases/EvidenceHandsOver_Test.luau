--!strict
--[[
	Phase 5.4: evidence that hands over other evidence
	(EvidenceDefinition.grantsEvidence -> EvidenceService.grant).

	One object, one action, several clues: examining (or being handed) the
	first also discovers the others, with the same consequences as any
	discovery. Uses a synthetic fixture case; no CASE-001 story content.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local CaseRegistry = require(game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local CASE_ID = "CASE-TEST-HANDSOVER"

	local fixture = {
		id = CASE_ID,
		title = "Hands-over Fixture",
		description = "",
		suspects = {},
		locations = {},
		evidence = {
			{
				id = "EV-PHONE",
				name = "Unlocked Phone",
				description = "A phone.",
				location = "Desk",
				importance = "High",
				grantsEvidence = { "EV-MSG", "EV-DATA" },
			},
			{
				id = "EV-MSG",
				name = "Message",
				description = "A message.",
				location = "Desk",
				importance = "High",
				timestamp = "11:48 PM",
				timelineEventId = "TL-MSG",
			},
			{ id = "EV-DATA", name = "Watch Data", description = "A watch.", location = "Desk", importance = "Medium" },
		},
		timeline = {
			{
				id = "TL-MSG",
				timestamp = "11:48 PM",
				timeMinutes = 1428,
				title = "The message",
				description = "Written, never sent.",
				sourceEvidenceIds = { "EV-MSG" },
			},
		},
		objectives = {},
		conversations = {},
		statements = {},
		contradictions = {},
		deductions = {},
	}
	CaseRegistry.register(fixture :: any)

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `HO{id}` }
		PlayerDataService.initialize(player, CASE_ID)
		return player
	end

	-- Every EvidencePayload sent to `player` while `fn` runs, in order.
	local function collect(player: any, fn: () -> ()): { any }
		local sent = {}
		-- A BindableEvent hands a listener a copy of a table: match a mock
		-- player by its UserId.
		local connection = EvidenceService.onDiscovered().Event:Connect(function(who, payload)
			if who.UserId == player.UserId then
				table.insert(sent, payload)
			end
		end)
		fn()
		-- BindableEvent delivery is deferred: let it land before counting (a
		-- few frames, since the events arrive together).
		for _ = 1, 4 do
			task.wait()
		end
		connection:Disconnect()
		return sent
	end

	t.test("examining one item discovers the others it hands over", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-PHONE"))
		expect.truthy(EvidenceService.isDiscovered(player, "EV-PHONE"))
		expect.truthy(EvidenceService.isDiscovered(player, "EV-MSG"))
		expect.truthy(EvidenceService.isDiscovered(player, "EV-DATA"))
	end)

	t.test("the readout is the examined item's, and names what was also added", function()
		local player = makePlayer()
		local sent = collect(player, function()
			EvidenceService.discover(player, "EV-PHONE")
		end)
		expect.equal(#sent, 3)
		expect.equal(sent[1].evidence.id, "EV-PHONE")
		expect.equal(sent[1].granted, nil)
		expect.deepEqual(sent[1].alsoAdded, { "Message", "Watch Data" })
		-- The handed-over ones are announced quietly: no framing, no readout.
		expect.equal(sent[2].evidence.id, "EV-MSG")
		expect.equal(sent[2].granted, true)
		expect.equal(sent[3].evidence.id, "EV-DATA")
		expect.equal(sent[3].granted, true)
		-- The readout counts what it is about to hand over, so its "x / y" is
		-- what the Case File will say a moment later; the quiet ones count up.
		expect.equal(sent[1].totalDiscovered, 3)
		expect.equal(sent[2].totalDiscovered, 2)
		expect.equal(sent[3].totalDiscovered, 3)
	end)

	t.test("a handed-over item reveals its timeline event, like any discovery", function()
		local player = makePlayer()
		local sent = collect(player, function()
			EvidenceService.discover(player, "EV-PHONE")
		end)
		expect.truthy(sent[2].revealedEvent)
		expect.equal((sent[2].revealedEvent :: any).id, "TL-MSG")
	end)

	t.test("only the newly added are named: known ones are skipped, and never re-announced", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-MSG"))
		local sent = collect(player, function()
			EvidenceService.discover(player, "EV-PHONE")
		end)
		expect.equal(#sent, 2)
		expect.deepEqual(sent[1].alsoAdded, { "Watch Data" })
		expect.equal(sent[2].evidence.id, "EV-DATA")
	end)

	t.test("nothing new to add means no 'also added' line", function()
		local player = makePlayer()
		EvidenceService.grant(player, "EV-MSG")
		EvidenceService.grant(player, "EV-DATA")
		local sent = collect(player, function()
			EvidenceService.discover(player, "EV-PHONE")
		end)
		expect.equal(#sent, 1)
		expect.equal(sent[1].alsoAdded, nil)
	end)

	t.test("it is idempotent: a second examine adds nothing", function()
		local player = makePlayer()
		EvidenceService.discover(player, "EV-PHONE")
		local sent = collect(player, function()
			local ok, reason = EvidenceService.discover(player, "EV-PHONE")
			expect.falsy(ok)
			expect.equal(reason, "already-discovered")
		end)
		expect.equal(#sent, 0)
	end)

	t.test("being handed the item by a conversation hands over the others too", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.grant(player, "EV-PHONE"))
		expect.truthy(EvidenceService.isDiscovered(player, "EV-MSG"))
		expect.truthy(EvidenceService.isDiscovered(player, "EV-DATA"))
	end)

	t.test("evidence that hands nothing over is untouched", function()
		local player = makePlayer()
		local sent = collect(player, function()
			EvidenceService.discover(player, "EV-DATA")
		end)
		expect.equal(#sent, 1)
		expect.equal(sent[1].alsoAdded, nil)
		expect.falsy(EvidenceService.isDiscovered(player, "EV-MSG"))
	end)

	t.test("the validator rejects unknown ids, a self-grant and a loop", function()
		local function problemsFor(evidence: { any }): { string }
			local broken = table.clone(fixture) :: any
			broken.evidence = evidence
			return ConversationService.validate(broken)
		end
		local unknown = problemsFor({
			{ id = "A", name = "A", description = "", location = "", importance = "Low", grantsEvidence = { "GHOST" } },
		})
		expect.equal(#unknown, 1)
		expect.truthy(string.find(unknown[1], "GHOST", 1, true))

		local selfGrant = problemsFor({
			{ id = "A", name = "A", description = "", location = "", importance = "Low", grantsEvidence = { "A" } },
		})
		expect.truthy(#selfGrant >= 1)
		expect.truthy(string.find(selfGrant[1], "grants itself", 1, true))

		local loop = problemsFor({
			{ id = "A", name = "A", description = "", location = "", importance = "Low", grantsEvidence = { "B" } },
			{ id = "B", name = "B", description = "", location = "", importance = "Low", grantsEvidence = { "A" } },
		})
		expect.truthy(#loop >= 1)
		expect.truthy(string.find(loop[1], "through a chain", 1, true))

		expect.equal(#ConversationService.validate(fixture :: any), 0)
	end)
end
