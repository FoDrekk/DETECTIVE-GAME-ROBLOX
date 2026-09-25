--!strict
--[[
	Tests for ServerScriptService.Server.AccusationService (Phase 2N).

	Covers: the spoiler-safe option picker, eligibility (only after every
	objective is complete), unknown-id rejection, permanence/idempotency, the
	supported/unsupported resolution derived from the facts the player
	actually unlocked, per-player isolation, and that PlayerDataService.clear
	wipes an accusation.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local AccusationService = require(Server:WaitForChild("AccusationService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `ACC{id}` }
		PlayerDataService.initialize(player, "CASE-TEST-LEGACY")
		return player
	end

	-- Discovers the desk evidence as InteractionService does in real play, so
	-- the facts it carries (e.g. DEDUCT-002's motive) are actually known.
	local function discoverDesk(player: any)
		EvidenceService.discover(player, "EV-001")
		EvidenceService.discover(player, "EV-002")
		EvidenceService.discover(player, "EV-003")
	end

	-- Completes every currently-authored CASE-001 objective (OBJ-001..005).
	local function completeEverything(player: any)
		discoverDesk(player)
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		ConversationService.advance(player) -- unlocks STMT-SUS-002-ALIBI
		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player) -- unlocks CONTRA-001
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001") -- completes OBJ-003
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- unlocks STMT-SUS-001-ALIBI
		ReasoningService.evaluate(player) -- unlocks DEDUCT-001
		ObjectiveService.recordFact(player, "Deduction", "DEDUCT-001") -- completes OBJ-004
		-- M5: reconstruct the timeline (completes OBJ-005).
		TimelineService.submitSequence(player, { "TIMELINE-001", "TIMELINE-002", "TIMELINE-004", "TIMELINE-003" })
	end

	-- A player who has completed everything except speaking to Mara: OBJ-001/002/003
	-- done, DEDUCT-001/OBJ-004 still locked.
	local function completeThroughObj003(player: any)
		discoverDesk(player)
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		ConversationService.advance(player)
		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")
	end

	t.test("a fresh player has no accusation", function()
		local player = makePlayer()
		expect.falsy(AccusationService.hasAccusation(player))
		expect.falsy(AccusationService.getResolution(player))
	end)

	-- The picker lists every authored accusation (suspects the player can
	-- already see in the world), and nothing is selected yet.
	t.test("the picker lists every authored accusation with nothing selected", function()
		local player = makePlayer()
		local payload = AccusationService.getPayload(player)
		expect.equal(#payload.options, 2)
		expect.falsy(payload.selected)

		local byId = {}
		for _, option in ipairs(payload.options) do
			byId[option.id] = option
		end
		expect.equal(byId["ACC-001"].suspectId, "SUS-002")
		expect.equal(byId["ACC-001"].suspectName, "Victor Lane")
		expect.equal(byId["ACC-002"].suspectId, "SUS-001")
		expect.equal(byId["ACC-002"].suspectName, "Mara Reyes")
		expect.equal(byId["ACC-001"].suspectRole, "Business Partner")
		expect.equal(byId["ACC-002"].suspectRole, "Spouse")
	end)

	-- An accusation is only meaningful once every objective is complete.
	t.test("cannot accuse while objectives remain", function()
		local player = makePlayer()
		expect.falsy(AccusationService.accuse(player, "ACC-001"))
		expect.falsy(AccusationService.hasAccusation(player))
	end)

	t.test("cannot accuse with OBJ-001/002/003 complete but OBJ-004 still open", function()
		local player = makePlayer()
		completeThroughObj003(player)
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-004")
		expect.falsy(AccusationService.accuse(player, "ACC-001"))
		expect.falsy(AccusationService.hasAccusation(player))
	end)

	t.test("rejects an unknown accusation id even when eligible", function()
		local player = makePlayer()
		completeEverything(player)
		expect.falsy(AccusationService.accuse(player, "ACC-GHOST"))
		expect.falsy(AccusationService.hasAccusation(player))
	end)

	t.test("rejects an empty/non-string accusation id", function()
		local player = makePlayer()
		completeEverything(player)
		expect.falsy(AccusationService.accuse(player, ""))
		expect.falsy(AccusationService.accuse(player, nil :: any))
		expect.falsy(AccusationService.hasAccusation(player))
	end)

	-- Once eligible, accusing a suspect the evidence supports is accepted and
	-- resolved as supported, naming the unlocked facts it is based on.
	t.test("an eligible player can accuse Victor, resolved as supported", function()
		local player = makePlayer()
		completeEverything(player)
		expect.truthy(AccusationService.accuse(player, "ACC-001"))
		expect.truthy(AccusationService.hasAccusation(player))

		local resolution = AccusationService.getResolution(player)
		expect.truthy(resolution)
		expect.equal(resolution.suspectId, "SUS-002")
		expect.equal(resolution.suspectName, "Victor Lane")
		expect.truthy(resolution.supported)
		expect.equal(#resolution.basedOn, 3) -- CONTRA-001 + DEDUCT-001 + DEDUCT-002 labels
	end)

	-- M2: the case's true answer is resolved only once the player commits.
	t.test("there is no verdict before the player accuses", function()
		local player = makePlayer()
		completeEverything(player)
		expect.falsy(AccusationService.getVerdict(player))
	end)

	t.test("accusing Victor yields a correct verdict", function()
		local player = makePlayer()
		completeEverything(player)
		AccusationService.accuse(player, "ACC-001")

		local verdict = AccusationService.getVerdict(player)
		expect.truthy(verdict)
		expect.truthy(verdict.correct)
		expect.equal(verdict.culpritName, "Victor Lane")
		expect.truthy(#verdict.reveal > 0)
	end)

	t.test("accusing Mara yields an incorrect verdict that names the culprit", function()
		local player = makePlayer()
		completeEverything(player)
		AccusationService.accuse(player, "ACC-002")

		local verdict = AccusationService.getVerdict(player)
		expect.truthy(verdict)
		expect.falsy(verdict.correct)
		expect.equal(verdict.culpritName, "Victor Lane")
	end)

	-- The answer must never reach the client through the picker payload.
	t.test("the picker payload never carries the solution", function()
		local player = makePlayer()
		completeEverything(player)
		local payload = AccusationService.getPayload(player) :: any
		expect.falsy(payload.verdict)
		expect.falsy(payload.solution)
		for _, option in ipairs(payload.options) do
			expect.falsy(option.correct)
			expect.falsy(option.reveal)
		end
	end)

	-- Accusing the suspect no authored contradiction/deduction names is still
	-- accepted (the player is allowed to be wrong), and honestly reported as
	-- unsupported -- never as an error, never as established fact.
	t.test("an eligible player can accuse Mara, resolved as unsupported", function()
		local player = makePlayer()
		completeEverything(player)
		expect.truthy(AccusationService.accuse(player, "ACC-002"))

		local resolution = AccusationService.getResolution(player)
		expect.truthy(resolution)
		expect.equal(resolution.suspectId, "SUS-001")
		expect.falsy(resolution.supported)
		expect.equal(#resolution.basedOn, 0)
	end)

	-- Support requires every referenced fact. In the real game a player cannot
	-- reach the accusation without completing every objective -- and OBJ-001
	-- requires the desk evidence, which unlocks the motive (DEDUCT-002) -- so
	-- "unsupported Victor" is only reachable by accusing someone the evidence
	-- does not name (covered above with Mara). This test instead pins the gate
	-- itself: with the timeline (OBJ-005) unfinished, no accusation is possible.
	t.test("an accusation is rejected until every objective, including the timeline, is complete", function()
		local player = makePlayer()
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
		ConversationService.advance(player)
		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001")
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player)
		ReasoningService.evaluate(player)
		ObjectiveService.recordFact(player, "Deduction", "DEDUCT-001")

		-- OBJ-005 (reconstruct the timeline) is still open.
		expect.equal(ObjectiveService.getActiveObjectiveId(player), "OBJ-005")
		expect.falsy(AccusationService.accuse(player, "ACC-001"))
		expect.falsy(AccusationService.hasAccusation(player))

		-- Once the timeline is reconstructed, the accusation is accepted.
		-- Only EV-004 was discovered here, so the timeline is a single event.
		expect.truthy(TimelineService.submitSequence(player, { "TIMELINE-004" }))
		expect.equal(ObjectiveService.getActiveObjectiveId(player), nil)
		expect.truthy(AccusationService.accuse(player, "ACC-001"))
	end)

	-- An accusation is a commitment: repeating it or trying to change it is
	-- rejected, and the payload reflects the recorded choice.
	t.test("an accusation is permanent: re-accusing is rejected", function()
		local player = makePlayer()
		completeEverything(player)
		expect.truthy(AccusationService.accuse(player, "ACC-001"))
		-- Same choice again, and a different choice, are both no-ops.
		expect.falsy(AccusationService.accuse(player, "ACC-001"))
		expect.falsy(AccusationService.accuse(player, "ACC-002"))

		local payload = AccusationService.getPayload(player)
		expect.truthy(payload.selected)
		expect.equal(payload.selected.id, "ACC-001")
		expect.equal(AccusationService.getResolution(player).suspectId, "SUS-002")
	end)

	-- The picker payload only ever carries the suspects, never the answer:
	-- before accusing, `selected` is absent regardless of the player's facts.
	t.test("the picker payload never carries the supported answer", function()
		local player = makePlayer()
		completeEverything(player)
		local payload = AccusationService.getPayload(player)
		expect.falsy(payload.selected)
		-- No supported/unsupported field ever appears on an option.
		for _, option in ipairs(payload.options) do
			expect.falsy((option :: any).supported)
		end
	end)

	-- Per-player isolation: one player's accusation never appears for another.
	t.test("accusations do not leak across players", function()
		local playerA = makePlayer()
		local playerB = makePlayer()
		completeEverything(playerA)
		completeEverything(playerB)
		AccusationService.accuse(playerA, "ACC-001")

		expect.truthy(AccusationService.hasAccusation(playerA))
		expect.falsy(AccusationService.hasAccusation(playerB))
		expect.falsy(AccusationService.getPayload(playerB).selected)
	end)

	-- PlayerDataService.clear wipes the accusation along with everything else.
	t.test("player data clear wipes the accusation", function()
		local player = makePlayer()
		completeEverything(player)
		AccusationService.accuse(player, "ACC-001")
		expect.truthy(AccusationService.hasAccusation(player))

		PlayerDataService.clear(player)
		expect.falsy(AccusationService.hasAccusation(player))
	end)

	-- A data-less player can never be treated as eligible.
	t.test("a player with no case data cannot accuse", function()
		local stranger = { UserId = t.nextUserId(), Name = "AccStranger" }
		expect.falsy(AccusationService.accuse(stranger, "ACC-001"))
	end)
end
