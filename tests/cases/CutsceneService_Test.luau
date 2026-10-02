--!strict
--[[
	Phase 5.1: server-authoritative scripted scenes (CutsceneService).

	A synthetic fixture case. Proves that the server alone starts a scene,
	that it blocks the world and conversations while it plays, that it
	checks the client's report of the end (a skip only where allowed, the end
	no sooner than the scene's length, only the scene actually playing),
	that it ends a scene itself if the client goes quiet, and that it
	remembers what was seen across a replay so a replay can start part-way
	through.

	Phase 5.5 adds the intro: a case names its opening scene, the server plays
	it when the investigation begins and marks it (isIntro) so the client skips
	it by holding; the validator checks every new field a shot can carry.

	Time is a test clock (CutsceneService.useClock): it moves only when a
	test says so, so nothing here waits in real time and the suite behaves
	the same headless as inside a live Studio session. The real timer that
	calls the backstop, and the client side (shots, subtitles, the two-press
	skip), are checked end to end in tools/headless/entry_engine.luau.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local CutsceneService = require(Server:WaitForChild("CutsceneService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local InteractionService = require(Server:WaitForChild("InteractionService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local StoryEvents = require(Server:WaitForChild("StoryEvents"))
	local GameStateService = require(Server:WaitForChild("GameStateService"))
	local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local CaseRegistry = require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local CASE_ID = "CASE-TEST-CUTSCENE"

	local function point(x: number): { position: Vector3, lookAt: Vector3 }
		return { position = Vector3.new(x, 6, 0), lookAt = Vector3.new(x, 4, -10) }
	end

	local fixture = {
		id = CASE_ID,
		title = "Cutscene Fixture",
		description = "",
		suspects = {
			{ id = "WIT", name = "Witness", role = "Night Security", alibi = "Rounds." },
		},
		locations = {},
		evidence = {
			{ id = "EV-DESK", name = "Desk", description = "", location = "Office", importance = "Low" },
		},
		timeline = {},
		objectives = {},
		conversations = {
			{
				suspectId = "WIT",
				startNodeId = "HI",
				nodes = { HI = { id = "HI", speaker = "Witness", text = "Hi." } },
			},
		},
		statements = {},
		contradictions = {},
		deductions = {},
		cutscenes = {
			{
				-- Three shots, 6 s in all; a replay starts at the second (4 s).
				id = "CUT-OPEN",
				replayFrom = "S2",
				shots = {
					{
						id = "S1",
						duration = 2,
						fadeIn = 0.5,
						camera = { from = point(0), to = point(1), fieldOfView = 50 },
						lines = { { at = 0, duration = 2, speaker = "Radio", text = "Unit, respond." } },
					},
					{ id = "S2", duration = 3, camera = { from = point(2) } },
					{ id = "S3", duration = 1, fadeOut = 0.5, camera = { from = point(3) } },
				},
			},
			{
				id = "CUT-LOCKED",
				skippable = false,
				shots = { { id = "L1", duration = 6, camera = { from = point(4) } } },
			},
			{ id = "CUT-EMPTY", shots = {} },
		},
	}
	CaseRegistry.register(fixture :: any)

	-- A case that opens on a scene: three shots (a replay starts at the third),
	-- using a set, a lighting preset, a bed, a one-shot, an action and a card that
	-- all really exist in Config (the validator checks that), plus an ordinary
	-- scene that isn't its intro.
	local INTRO_CASE_ID = "CASE-TEST-INTRO"
	local introFixture = table.clone(fixture)
	introFixture.id = INTRO_CASE_ID
	introFixture.title = "Intro Fixture"
	introFixture.intro = { cutsceneId = "CUT-INTRO", replacesBriefing = true }
	introFixture.cutscenes = {
		{
			id = "CUT-INTRO",
			replayFrom = "I3",
			shots = {
				{
					id = "I1",
					duration = 2,
					set = "Street",
					lighting = "CityNight",
					camera = { from = point(0), to = point(1), ease = "Out", handheld = 0.3, fieldOfViewTo = 60 },
					focus = { distance = 20, toDistance = 12, blur = 0.5 },
					sounds = { { at = 0, cue = "RainStreet", fade = 0.5 } },
					actions = { { at = 1, name = "TrainPasses" } },
				},
				{
					id = "I2",
					duration = 2,
					camera = { from = point(2) },
					sounds = { { at = 0, cue = "RainStreet" }, { at = 1, cue = "Thunder" } },
				},
				{
					id = "I3",
					duration = 2,
					set = "LiftCar",
					mouseLook = true,
					camera = { from = point(3) },
					actions = { { at = 1, name = "DoorsOpen" } },
					titleCard = { at = 0.5, duration = 1, title = "CASE 001" },
				},
			},
		},
		{ id = "CUT-PLAIN", shots = { { id = "P1", duration = 2, camera = { from = point(4) } } } },
	}
	CaseRegistry.register(introFixture :: any)

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `CS{id}` }
		PlayerDataService.initialize(player, CASE_ID)
		return player
	end

	local function makeIntroPlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `CI{id}` }
		PlayerDataService.initialize(player, INTRO_CASE_ID)
		return player
	end

	-- BindableEvent delivery is deferred: give it a frame to land.
	local function settle(done: () -> boolean)
		for _ = 1, 30 do
			task.wait()
			if done() then
				return
			end
		end
	end

	-- The scene payloads the server sent `player` while fn ran.
	local function withPayloads(player: any, fn: () -> ()): { any }
		local sent = {}
		local connection = CutsceneService.onUpdated().Event:Connect(function(who, payload)
			if who.UserId == player.UserId then
				table.insert(sent, payload)
			end
		end)
		fn()
		settle(function()
			return #sent >= 1
		end)
		connection:Disconnect()
		return sent
	end

	local function active(player: any): any
		return (PlayerDataService.get(player) :: any).caseState.activeCutscene
	end

	-- A test clock for the duration of fn: time moves only by `advance`. It
	-- starts from the real clock, and every test here leaves nothing playing,
	-- so the real backstops these scenes schedule find nothing to end.
	local function withClock(fn: (advance: (seconds: number) -> ()) -> ())
		local now = os.clock()
		CutsceneService.useClock(function()
			return now
		end)
		local ok, err = pcall(fn, function(seconds: number)
			now += seconds
		end)
		CutsceneService.useClock(nil)
		if not ok then
			error(err, 0)
		end
	end

	-- Records `player`'s StoryEvents for the duration of fn. Everyone else's
	-- go through untouched (the suite can also run inside a live game).
	local function withPublishSpy(player: any, fn: (calls: { { kind: string, data: any } }) -> ())
		local calls = {}
		local original = StoryEvents.publish
		StoryEvents.publish = function(kind, who, data)
			if who == player then
				table.insert(calls, { kind = kind, data = data })
			else
				original(kind, who, data)
			end
		end
		local ok, err = pcall(fn, calls)
		StoryEvents.publish = original
		if not ok then
			error(err, 0)
		end
	end

	local function finishedEvents(calls: { { kind: string, data: any } }): { any }
		local out = {}
		for _, call in ipairs(calls) do
			if call.kind == "CutsceneFinished" then
				table.insert(out, call.data)
			end
		end
		return out
	end

	-- Skip a skippable scene a test left playing.
	local function tidy(player: any)
		local id = CutsceneService.getActiveId(player)
		if id then
			CutsceneService.finish(player, id, true)
		end
	end

	t.test("the fixture's scenes validate, apart from the one with nothing in it", function()
		local problems = CutsceneService.validate(fixture :: any)
		expect.equal(#problems, 1)
		expect.truthy(string.find(problems[1], "CUT-EMPTY", 1, true))
	end)

	t.test("playing a scene marks it on, for its whole length", function()
		local player = makePlayer()
		expect.falsy(CutsceneService.isPlaying(player))
		local ok, reason = CutsceneService.play(player, "CUT-OPEN")
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.truthy(CutsceneService.isPlaying(player))
		expect.equal(CutsceneService.getActiveId(player), "CUT-OPEN")
		expect.near(active(player).duration, 6, 1e-6)
		expect.equal(active(player).grace, Config.Cutscene.EndGrace)
		tidy(player)
	end)

	t.test("one scene at a time", function()
		local player = makePlayer()
		CutsceneService.play(player, "CUT-OPEN")
		local ok, reason = CutsceneService.play(player, "CUT-LOCKED")
		expect.falsy(ok)
		expect.equal(reason, "cutscene-in-progress")
		expect.equal(CutsceneService.getActiveId(player), "CUT-OPEN")
		tidy(player)
	end)

	t.test("unknown and empty scenes are refused", function()
		local player = makePlayer()
		local ok, reason = CutsceneService.play(player, "CUT-NOPE")
		expect.falsy(ok)
		expect.equal(reason, "unknown-cutscene")
		ok, reason = CutsceneService.play(player, "CUT-EMPTY")
		expect.falsy(ok)
		expect.equal(reason, "malformed-cutscene")
		expect.falsy(CutsceneService.isPlaying(player))
		local nobody = { UserId = t.nextUserId(), Name = "Nobody" } :: any
		ok, reason = CutsceneService.play(nobody, "CUT-OPEN")
		expect.falsy(ok)
		expect.equal(reason, "no-player-data")
	end)

	t.test("a scene can't start during a conversation, nor a conversation during a scene", function()
		local talking = makePlayer()
		expect.truthy(ConversationService.begin(talking, "WIT"))
		local ok, reason = CutsceneService.play(talking, "CUT-OPEN")
		expect.falsy(ok)
		expect.equal(reason, "conversation-in-progress")

		local watching = makePlayer()
		CutsceneService.play(watching, "CUT-OPEN")
		ok, reason = ConversationService.begin(watching, "WIT")
		expect.falsy(ok)
		expect.equal(reason, "cutscene-in-progress")
		ConversationService.leave(talking)
		tidy(watching)
	end)

	t.test("nothing in the world can be used while a scene plays", function()
		local player = makePlayer()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(300, 0, 300)
		part:SetAttribute("InteractionKind", "Examine")
		part:SetAttribute("EvidenceId", "EV-DESK")
		CollectionService:AddTag(part, Interactable.TAG)
		part.Parent = workspace
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = part.Position
		root.Parent = character
		character.Parent = workspace
		player.Character = character

		CutsceneService.play(player, "CUT-OPEN")
		InteractionService.handleRequest(player, part, "Examine")
		expect.falsy(EvidenceService.isDiscovered(player, "EV-DESK"))
		-- The same request once the scene is over goes through: it was the
		-- scene, not anything else, that held it back.
		expect.truthy(CutsceneService.finish(player, "CUT-OPEN", true))
		InteractionService.handleRequest(player, part, "Examine")
		expect.truthy(EvidenceService.isDiscovered(player, "EV-DESK"))
		part:Destroy()
		character:Destroy()
	end)

	t.test("the end can't be claimed before the scene has had time to play", function()
		local player = makePlayer()
		local tolerance = Config.Cutscene.EndTolerance
		withClock(function(advance)
			CutsceneService.play(player, "CUT-LOCKED") -- 6 s
			local ok, reason = CutsceneService.finish(player, "CUT-LOCKED", false)
			expect.falsy(ok)
			expect.equal(reason, "too-early")
			advance(6 - tolerance - 0.1) -- just short, even allowing the tolerance
			ok, reason = CutsceneService.finish(player, "CUT-LOCKED", false)
			expect.falsy(ok)
			expect.equal(reason, "too-early")
			expect.truthy(CutsceneService.isPlaying(player))
			advance(0.2) -- inside the tolerance of the end: believed
			ok, reason = CutsceneService.finish(player, "CUT-LOCKED", false)
			expect.truthy(ok)
			expect.equal(reason, nil)
		end)
		expect.falsy(CutsceneService.isPlaying(player))
	end)

	t.test("a skip only where the scene allows one", function()
		local player = makePlayer()
		withClock(function(advance)
			CutsceneService.play(player, "CUT-LOCKED")
			local ok, reason = CutsceneService.finish(player, "CUT-LOCKED", true)
			expect.falsy(ok)
			expect.equal(reason, "not-skippable")
			expect.truthy(CutsceneService.isPlaying(player))
			advance(6)
			expect.truthy(CutsceneService.finish(player, "CUT-LOCKED", false))
		end)

		local other = makePlayer()
		CutsceneService.play(other, "CUT-OPEN")
		expect.truthy(CutsceneService.finish(other, "CUT-OPEN", true))
		expect.falsy(CutsceneService.isPlaying(other))
	end)

	t.test("only the scene actually playing can be reported", function()
		local player = makePlayer()
		local ok, reason = CutsceneService.finish(player, "CUT-OPEN", true)
		expect.falsy(ok)
		expect.equal(reason, "not-playing")
		CutsceneService.play(player, "CUT-OPEN")
		ok, reason = CutsceneService.finish(player, "CUT-LOCKED", true)
		expect.falsy(ok)
		expect.equal(reason, "not-playing")
		ok, reason = CutsceneService.finish(player, 42 :: any, true)
		expect.falsy(ok)
		expect.equal(reason, "not-playing")
		expect.truthy(CutsceneService.isPlaying(player))
		tidy(player)
	end)

	t.test("every end is published once, saying how it ended", function()
		local player = makePlayer()
		withPublishSpy(player, function(calls)
			CutsceneService.play(player, "CUT-OPEN")
			CutsceneService.finish(player, "CUT-OPEN", true)
			CutsceneService.finish(player, "CUT-OPEN", true) -- already over
			local ended = finishedEvents(calls)
			expect.equal(#ended, 1)
			expect.equal(ended[1].cutsceneId, "CUT-OPEN")
			expect.equal(ended[1].skipped, true)
			expect.equal(ended[1].timedOut, false)
		end)
	end)

	t.test("the server ends a scene itself if the client never reports", function()
		local player = makePlayer()
		withPublishSpy(player, function(calls)
			withClock(function(advance)
				CutsceneService.play(player, "CUT-OPEN")
				local grace = active(player).grace
				advance(6) -- the scene's length: the client may still report
				expect.falsy(CutsceneService.expire(player))
				advance(grace - 0.1) -- still inside the grace
				expect.falsy(CutsceneService.expire(player))
				expect.truthy(CutsceneService.isPlaying(player))
				advance(0.2) -- past length and grace: the backstop ends it
				expect.truthy(CutsceneService.expire(player))
				expect.falsy(CutsceneService.isPlaying(player))
				expect.falsy(CutsceneService.expire(player)) -- nothing left to end
			end)
			local ended = finishedEvents(calls)
			expect.equal(#ended, 1)
			expect.equal(ended[1].timedOut, true)
			expect.equal(ended[1].skipped, false)
		end)
		expect.truthy(CutsceneService.hasSeen(player, "CUT-OPEN"))
	end)

	t.test("a backstop from an earlier playing never ends a later one", function()
		local player = makePlayer()
		withClock(function(advance)
			CutsceneService.play(player, "CUT-OPEN") -- its backstop is due at 6 s + grace
			local grace = active(player).grace
			CutsceneService.finish(player, "CUT-OPEN", true)
			advance(5)
			CutsceneService.play(player, "CUT-LOCKED") -- 6 s from here
			advance(1 + grace + 0.1) -- past the first playing's backstop, inside the second's
			-- What the first playing's backstop does when it goes off now:
			expect.falsy(CutsceneService.expire(player))
			expect.equal(CutsceneService.getActiveId(player), "CUT-LOCKED")
			advance(6)
			expect.truthy(CutsceneService.finish(player, "CUT-LOCKED", false))
		end)
	end)

	t.test("seen this session: a second showing starts at replayFrom, even after a replay", function()
		local player = makePlayer()
		expect.falsy(CutsceneService.hasSeen(player, "CUT-OPEN"))
		CutsceneService.play(player, "CUT-OPEN")
		CutsceneService.finish(player, "CUT-OPEN", true)
		expect.truthy(CutsceneService.hasSeen(player, "CUT-OPEN"))
		-- "Investigate again" wipes the case state, not the session.
		PlayerDataService.clear(player)
		PlayerDataService.initialize(player, CASE_ID)
		expect.truthy(CutsceneService.hasSeen(player, "CUT-OPEN"))
		CutsceneService.play(player, "CUT-OPEN")
		expect.near(active(player).duration, 4, 1e-6) -- S2 + S3
		tidy(player)
	end)

	t.test("a scene without replayFrom plays from the top again", function()
		local player = makePlayer()
		withClock(function(advance)
			CutsceneService.play(player, "CUT-LOCKED")
			advance(6)
			expect.truthy(CutsceneService.finish(player, "CUT-LOCKED", false))
			CutsceneService.play(player, "CUT-LOCKED")
			expect.near(active(player).duration, 6, 1e-6)
			advance(6)
			expect.truthy(CutsceneService.finish(player, "CUT-LOCKED", false))
		end)
	end)

	t.test("the validator reports what would break a scene", function()
		local broken = {
			cutscenes = {
				{
					id = "BAD",
					replayFrom = "NOWHERE",
					shots = {
						{
							id = "A",
							duration = 1,
							fadeIn = 0.8,
							fadeOut = 0.8,
							camera = { from = point(0), fieldOfView = 170 },
							lines = {
								{ at = 0.5, duration = 1, text = "Too long." },
								{ at = 0, duration = 0.2, text = "" },
							},
						},
						{ id = "A", duration = 0, camera = { from = point(1) } },
						{ id = "C", duration = 1, camera = {} },
					},
				},
				{ id = "BAD", shots = {} },
			},
		}
		local problems = CutsceneService.validate(broken :: any)
		local text = table.concat(problems, "\n")
		for _, expected in ipairs({
			"field of view",
			"fades don't fit",
			"runs outside its shot",
			"has no text",
			"duplicate shot id",
			"duration must be positive",
			"camera needs a 'from' point",
			"replayFrom 'NOWHERE'",
			"duplicate cutscene id",
			"has no shots",
		}) do
			expect.truthy(string.find(text, expected, 1, true))
		end
	end)

	t.test("CASE-001's intro and dawn scenes validate clean, and its Solved close names only real ones", function()
		local case001 = CaseRegistry.get("CASE-001") :: any
		local ids = {}
		for _, cutscene in ipairs(case001.cutscenes) do
			table.insert(ids, cutscene.id)
		end
		expect.deepEqual(ids, { "CUT-INTRO", "CUT-DAWN", "CUT-DAWN-HOME" })
		expect.equal(#CutsceneService.validate(case001), 0)
	end)

	t.test("CASE-001's opening keeps its timed story beats and replays at the lift handoff", function()
		local case001 = CaseRegistry.get("CASE-001") :: any
		local intro = case001.cutscenes[1]
		local duration = 0
		local dialogue = ""
		for _, shot in ipairs(intro.shots) do
			duration += shot.duration
			for _, line in ipairs(shot.lines or {}) do
				dialogue ..= line.text .. "\n"
			end
		end
		expect.equal(case001.intro.replacesBriefing, true)
		expect.equal(intro.replayFrom, "LIFT-OPEN")
		expect.equal(#intro.shots, 21)
		expect.equal(duration, 169)
		for _, beat in ipairs({
			"Wisma Delima, level nine",
			"Believe the room.",
			"I'll be asleep. Call me when you know.",
			"Tingkat sembilan, Inspektor.",
			"Access logged 12:38 AM.",
			"Jangan lupa makan.",
		}) do
			expect.truthy(string.find(dialogue, beat, 1, true))
		end
	end)

	-- The screenplay's music rule: silence in the cold open, then one motif from
	-- the city to the lift. A bed fades at any cut whose shot doesn't list it, so
	-- a shot that forgets it would restart the music from the top.
	t.test("CASE-001's motif is silent in the cold open, then unbroken until the lift stops it", function()
		local intro = (CaseRegistry.get("CASE-001") :: any).cutscenes[1]
		local entered, stopped = false, false
		for _, shot in ipairs(intro.shots) do
			local lists, stops = false, false
			for _, cue in ipairs(shot.sounds or {}) do
				if cue.cue == "Motif" then
					lists = true
					stops = stops or cue.stop == true
				end
			end
			if string.sub(shot.id, 1, 4) == "BED-" then
				expect.falsy(lists)
			elseif not stopped then
				entered = entered or lists
				if entered and not lists then
					error(`the motif drops out at {shot.id}`, 0)
				end
				stopped = stops
			end
		end
		expect.truthy(entered and stopped)
	end)

	t.test("the validator reports a Solved close that names a scene that isn't there", function()
		local broken = table.clone(CaseRegistry.get("CASE-001") :: any)
		broken.solution = table.clone(broken.solution)
		broken.solution.solvedCutscenes = { { cutsceneId = "CUT-GHOST" } }
		local problems = CutsceneService.validate(broken)
		expect.equal(#problems, 1)
		expect.truthy(string.find(problems[1], "CUT-GHOST", 1, true))
	end)

	-- Phase 5.5: the intro.

	t.test("the intro fixture validates clean, including every set, preset, cue and action it names", function()
		expect.equal(#CutsceneService.validate(introFixture :: any), 0)
	end)

	t.test("a case's intro is found and played, and its payload says it is the intro", function()
		local player = makeIntroPlayer()
		expect.equal(CutsceneService.getIntroId(player), "CUT-INTRO")
		local sent = withPayloads(player, function()
			local ok, reason = CutsceneService.playIntro(player)
			expect.truthy(ok)
			expect.equal(reason, nil)
		end)
		expect.equal(CutsceneService.getActiveId(player), "CUT-INTRO")
		expect.equal(#sent, 1)
		expect.equal(sent[1].active, true)
		expect.equal(sent[1].id, "CUT-INTRO")
		expect.equal(sent[1].isIntro, true)
		expect.equal(sent[1].skippable, true)
		expect.equal(#sent[1].shots, 3)
		tidy(player)
	end)

	t.test("an ordinary scene of the same case is not marked as the intro", function()
		local player = makeIntroPlayer()
		local sent = withPayloads(player, function()
			expect.truthy(CutsceneService.play(player, "CUT-PLAIN"))
		end)
		expect.equal(#sent, 1)
		expect.equal(sent[1].isIntro, nil)
		tidy(player)
	end)

	t.test("a case without an intro plays nothing when the investigation begins", function()
		local player = makePlayer()
		expect.equal(CutsceneService.getIntroId(player), nil)
		local ok, reason = CutsceneService.playIntro(player)
		expect.falsy(ok)
		expect.equal(reason, "no-intro")
		expect.falsy(GameStateService.beginInvestigation(player))
		expect.falsy(CutsceneService.isPlaying(player))
	end)

	t.test("beginning the investigation starts the intro, and only for a case that has one", function()
		local player = makeIntroPlayer()
		expect.truthy(GameStateService.beginInvestigation(player))
		expect.equal(CutsceneService.getActiveId(player), "CUT-INTRO")
		tidy(player)
	end)

	t.test("a player with no case data starts nothing", function()
		local nobody = { UserId = t.nextUserId(), Name = "Nobody" } :: any
		expect.equal(CutsceneService.getIntroId(nobody), nil)
		expect.falsy(GameStateService.beginInvestigation(nobody))
	end)

	t.test("the intro's second showing starts at its replayFrom shot", function()
		local player = makeIntroPlayer()
		withClock(function(advance)
			CutsceneService.playIntro(player)
			expect.near(active(player).duration, 6, 1e-6)
			expect.truthy(CutsceneService.finish(player, "CUT-INTRO", true)) -- a skip counts as seen
			CutsceneService.playIntro(player)
			expect.near(active(player).duration, 2, 1e-6) -- I3 alone
			advance(2)
			expect.truthy(CutsceneService.finish(player, "CUT-INTRO", false))
		end)
	end)

	t.test("the intro's first showing plays from the top, in full", function()
		local player = makeIntroPlayer()
		local sent = withPayloads(player, function()
			CutsceneService.playIntro(player)
		end)
		expect.equal(sent[1].shots[1].id, "I1")
		tidy(player)
	end)

	t.test("the validator reports an intro that names no scene, or one that can't be skipped", function()
		local ghost = table.clone(introFixture)
		ghost.intro = { cutsceneId = "CUT-NOPE" }
		local problems = CutsceneService.validate(ghost :: any)
		expect.equal(#problems, 1)
		expect.truthy(string.find(problems[1], "unknown cutscene 'CUT-NOPE'", 1, true))

		local locked = table.clone(introFixture)
		locked.intro = { cutsceneId = "CUT-INTRO" }
		locked.cutscenes = {
			{ id = "CUT-INTRO", skippable = false, shots = { { id = "L", duration = 2, camera = { from = point(0) } } } },
		}
		problems = CutsceneService.validate(locked :: any)
		expect.equal(#problems, 1)
		expect.truthy(string.find(problems[1], "must be skippable", 1, true))
	end)

	t.test("the validator reports what would silently do nothing on screen", function()
		local broken = {
			cutscenes = {
				{
					id = "BAD",
					shots = {
						{
							id = "A",
							duration = 4,
							set = "Nowhere",
							lighting = "Neon",
							mouseLook = true,
							camera = { from = point(0), to = point(9), fieldOfViewTo = 0, ease = "Bouncy", handheld = 2 },
							focus = { distance = -1, blur = 3, radius = -2 },
							sounds = {
								{ at = 0, cue = "NoSuchCue" },
								{ at = 9, cue = "RainStreet" },
								{ at = 0, cue = "RainStreet", volume = 50, fade = -1, from = -3 },
								{ at = 1, cue = "Thunder", stop = true },
							},
							actions = { { at = 9, name = "TrainPasses" } },
							titleCard = { at = 3, duration = 5, title = "" },
						},
						{
							id = "B",
							duration = 2,
							set = "Street",
							camera = { from = point(0) },
							actions = { { at = 0, name = "DoorsOpen" } },
						},
						{
							id = "C",
							duration = 2,
							camera = { from = point(0) },
							actions = { { at = 0, name = "Anything" } },
						},
					},
				},
			},
		}
		local text = table.concat(CutsceneService.validate(broken :: any), "\n")
		for _, expected in ipairs({
			"unknown set 'Nowhere'",
			"unknown lighting preset 'Neon'",
			"can't also move the camera",
			"field of view 0 is out of range",
			"unknown ease 'Bouncy'",
			"handheld must be between 0 and 1",
			"focus distance must be positive",
			"focus blur must be between 0 and 1",
			"focus radius can't be negative",
			"unknown cue 'NoSuchCue'",
			"starts outside its shot",
			"volume must be between 0 and 10",
			"fade can't be negative",
			"'from' can't be negative",
			"'Anything' needs the shot to name a set",
			"happens outside its shot",
			"set 'Street' has no action 'DoorsOpen'",
			"title card has no title",
			"title card runs outside its shot",
		}) do
			if not string.find(text, expected, 1, true) then
				error(`the validator did not report '{expected}'; it said:\n{text}`, 0)
			end
		end
		-- Stopping a cue is allowed, whatever the cue is (sound 4 is a valid stop).
		expect.falsy(string.find(text, "sound 4", 1, true))
	end)

	t.test("every set, preset and cue the config names is well formed", function()
		for name, set in pairs(Config.Cutscene.Sets) do
			expect.truthy(type(set.actions) == "table" and #set.actions > 0)
			if not set.world then
				expect.truthy(typeof(set.origin) == "Vector3")
			end
			for _, action in ipairs(set.actions) do
				expect.equal(type(action), "string")
			end
			expect.truthy(type(name) == "string")
		end
		for _, spec in pairs(Config.Audio.Cutscene) do
			expect.truthy(string.match(spec.id, "^rbxassetid://%d+$") ~= nil)
			expect.truthy(spec.volume > 0 and spec.volume <= 10)
		end
		for _, preset in pairs(Config.Cutscene.LightingPresets) do
			expect.truthy(type(preset) == "table")
		end
	end)
end
