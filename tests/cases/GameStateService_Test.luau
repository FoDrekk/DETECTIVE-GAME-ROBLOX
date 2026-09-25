--!strict
--[[
	Tests for ServerScriptService.Server.GameStateService.
	Covers Phase 2L: the Investigation -> CaseClosed edge's gameplay
	authorization. GameStateMachine_Test already covers graph-level
	transition validity in isolation; this file covers the additional,
	player-specific gameplay boundary GameStateService.requestConclude owns
	on top of that -- never trusting a client-supplied completion claim,
	always reading the requesting player's own server-side objective state.

	GameStateService's phase machine is a single, server-wide singleton (not
	per-player, not per-test), matching the game's real single-player-session
	architecture. Every test that needs "Investigation" as the starting phase
	drives it there explicitly via the same public GameStateService.setPhase
	real production code uses, rather than assuming what state an earlier
	test or real gameplay in this session left it in.

	Each case uses a unique mock UserId for isolation.
]]
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local GameStateService = require(Server:WaitForChild("GameStateService"))
	local ObjectiveService = require(Server:WaitForChild("ObjectiveService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local AccusationService = require(Server:WaitForChild("AccusationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local expect = t.expect

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `GSS{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	-- Drives the single shared phase machine to "Investigation" via the
	-- same valid graph edges real gameplay uses, regardless of what phase
	-- an earlier test (or real gameplay this session) left it in.
	local function resetToInvestigation()
		local phase = GameStateService.getPhase()
		if phase == "CaseClosed" then
			GameStateService.setPhase("MainMenu")
			phase = "MainMenu"
		end
		if phase == "MainMenu" then
			GameStateService.setPhase("CaseBriefing")
			phase = "CaseBriefing"
		end
		if phase == "CaseBriefing" then
			GameStateService.setPhase("Investigation")
		end
		expect.equal(GameStateService.getPhase(), "Investigation")
	end

	-- Completes OBJ-001 only.
	local function completeObj001(player: any)
		ObjectiveService.recordInteraction(player, "Examine", "EV-001")
		ObjectiveService.recordInteraction(player, "Examine", "EV-002")
		ObjectiveService.recordInteraction(player, "Read", "EV-003")
	end

	-- Completes OBJ-001 and OBJ-002 (talks to Victor, does not advance his
	-- dialogue -- his statement, and therefore CONTRA-001/OBJ-003, stay
	-- locked).
	local function completeObj002(player: any)
		completeObj001(player)
		ConversationService.begin(player, "SUS-002")
		ObjectiveService.recordInteraction(player, "Talk", nil, "SUS-002")
	end

	-- Completes OBJ-001/002/003 only -- deliberately never speaks to Mara, so
	-- DEDUCT-001/OBJ-004 stay locked. Used to test the OBJ-004 boundary.
	local function completeThroughObj003(player: any)
		completeObj002(player)
		ConversationService.advance(player) -- unlocks STMT-SUS-002-ALIBI
		EvidenceService.discover(player, "EV-004")
		ReasoningService.evaluate(player) -- unlocks CONTRA-001
		ObjectiveService.recordFact(player, "Contradiction", "CONTRA-001") -- completes OBJ-003
	end

	-- Completes every currently-authored CASE-001 objective (OBJ-001/002/003/004).
	local function completeEverything(player: any)
		completeThroughObj003(player)
		-- Victor's conversation is still active (only advanced once above) --
		-- leave it before starting Mara's, or begin() is a silent no-op.
		ConversationService.leave(player)
		ConversationService.begin(player, "SUS-001")
		ConversationService.advance(player) -- unlocks STMT-SUS-001-ALIBI
		ReasoningService.evaluate(player) -- unlocks DEDUCT-001
		ObjectiveService.recordFact(player, "Deduction", "DEDUCT-001") -- completes OBJ-004
	end

	-- Phase 2N: completes every objective AND makes a formal accusation, the
	-- full precondition for concluding.
	local function completeAndAccuse(player: any)
		completeEverything(player)
		AccusationService.accuse(player, "ACC-001")
	end

	t.test("a fresh/incomplete player cannot conclude", function()
		resetToInvestigation()
		local player = makePlayer()
		local concluded = GameStateService.requestConclude(player)
		expect.falsy(concluded)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	t.test("a player with only OBJ-001 complete cannot conclude", function()
		resetToInvestigation()
		local player = makePlayer()
		completeObj001(player)
		local concluded = GameStateService.requestConclude(player)
		expect.falsy(concluded)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	t.test("a player with only OBJ-002 complete cannot conclude", function()
		resetToInvestigation()
		local player = makePlayer()
		completeObj002(player)
		local concluded = GameStateService.requestConclude(player)
		expect.falsy(concluded)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	-- Phase 2M: OBJ-001/002/003 complete but Mara never spoken to -- DEDUCT-001
	-- and therefore OBJ-004 stay locked, so conclusion must stay blocked too.
	t.test("a player with OBJ-001/002/003 complete but not OBJ-004 cannot conclude", function()
		resetToInvestigation()
		local player = makePlayer()
		completeThroughObj003(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.completedObjectives["OBJ-003"])
		expect.falsy(data.caseState.completedObjectives["OBJ-004"])
		local concluded = GameStateService.requestConclude(player)
		expect.falsy(concluded)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	-- Completing objectives (even all of them) must never auto-transition the
	-- phase -- only an explicit requestConclude call may, and only with an
	-- accusation.
	t.test("objective completion alone does not transition to CaseClosed", function()
		resetToInvestigation()
		local player = makePlayer()
		completeEverything(player)
		local data = PlayerDataService.get(player)
		expect.truthy(data.caseState.completedObjectives["OBJ-003"])
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	-- Phase 2N: every objective complete but no accusation made -- the player
	-- has not committed to anything, so the case must not be conclusion-able.
	t.test("a player with every objective complete but no accusation cannot conclude", function()
		resetToInvestigation()
		local player = makePlayer()
		completeEverything(player)
		expect.falsy(AccusationService.hasAccusation(player))
		local concluded = GameStateService.requestConclude(player)
		expect.falsy(concluded)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	t.test("a player with every objective complete can conclude once they accuse", function()
		resetToInvestigation()
		local player = makePlayer()
		completeEverything(player)
		expect.truthy(AccusationService.accuse(player, "ACC-001"))
		local concluded = GameStateService.requestConclude(player)
		expect.truthy(concluded)
		expect.equal(GameStateService.getPhase(), "CaseClosed")
	end)

	-- Proves the check is genuinely per-requesting-player, not some other
	-- global or shared flag: player B's full completion + accusation cannot
	-- let player A (freshly initialized, nothing done) conclude.
	t.test("one player's completion cannot be used to conclude for another player", function()
		resetToInvestigation()
		local playerA = makePlayer()
		local playerB = makePlayer()
		completeAndAccuse(playerB)

		local concludedA = GameStateService.requestConclude(playerA)
		expect.falsy(concludedA)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	-- A player with no PlayerDataService entry at all must not be treated
	-- as eligible -- "no active objective" is also trivially true for a
	-- data-less player, for the wrong reason.
	t.test("a player with no case data at all cannot conclude", function()
		resetToInvestigation()
		local stranger = { UserId = 999999998, Name = "Stranger" }
		local concluded = GameStateService.requestConclude(stranger)
		expect.falsy(concluded)
		expect.equal(GameStateService.getPhase(), "Investigation")
	end)

	t.test("a valid conclusion is idempotent: requesting again is safely rejected", function()
		resetToInvestigation()
		local player = makePlayer()
		completeAndAccuse(player)
		expect.truthy(GameStateService.requestConclude(player))
		expect.equal(GameStateService.getPhase(), "CaseClosed")

		-- Already in CaseClosed: the Investigation -> CaseClosed edge no
		-- longer applies (graph legality), so a second request is rejected
		-- the same way an invalid one is -- no error, no double transition.
		local concludedAgain = GameStateService.requestConclude(player)
		expect.falsy(concludedAgain)
		expect.equal(GameStateService.getPhase(), "CaseClosed")
	end)

	-- Phase 2O: the closing summary restates the case from already-discovered
	-- facts -- the player's revealed timeline and unlocked contradiction --
	-- and never invents one. Read synchronously via getClosingSummary (the
	-- onCaseClosed BindableEvent fires deferred).
	t.test("closing summary carries the discovered timeline and unlocked contradiction", function()
		resetToInvestigation()
		local player = makePlayer()
		completeAndAccuse(player)
		-- The objective chain above drives objectives directly; discover the
		-- desk evidence too so a timeline event is actually revealed (EV-001
		-- -> TIMELINE-002), matching a real playthrough.
		EvidenceService.discover(player, "EV-001")

		local summary = GameStateService.getClosingSummary(player)
		expect.truthy(summary)
		expect.truthy(#summary.timeline >= 1)
		for _, event in ipairs(summary.timeline) do
			expect.truthy(type(event.timestamp) == "string" and #event.timestamp > 0)
		end
		expect.truthy(summary.contradiction)
		expect.equal(summary.contradiction.id, "CONTRA-001")
		expect.truthy(summary.accusation)
		-- M2: the verdict on the committed accusation (ACC-001, Victor).
		expect.truthy(summary.verdict)
		expect.truthy(summary.verdict.correct)
		expect.equal(summary.verdict.culpritName, "Victor Lane")
	end)

	-- Before an accusation exists there is nothing to judge, so no verdict.
	t.test("closing summary carries no verdict without an accusation", function()
		resetToInvestigation()
		local player = makePlayer()
		completeEverything(player)
		local summary = GameStateService.getClosingSummary(player)
		expect.truthy(summary)
		expect.falsy(summary.verdict)
	end)
end
