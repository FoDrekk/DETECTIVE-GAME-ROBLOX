--!strict
--[[
	Phase 5.4: the phone, and the ending.

	EV-011 Unsent Message, EV-012 Watch Data and EV-013 Photo of Meera;
	STMT-SUS-001-HOME; the two ways into the phone (Meera opens it, or its code
	is worked out from the photo) and the third way back to Meera for whoever
	upset her; Victor's watch-data confrontation; CONTRA-006 and DEDUCT-007;
	the 11:48 and 11:49 timeline events; the reveal, the four Solved endings
	and the dawn outro -- each proved through the real services, not by
	reading data alone.

	The world checks read whatever is in Workspace.Office, so they run against
	the freshly built world headless and against the patched baked place in
	Studio.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local ReasoningService = require(Server:WaitForChild("ReasoningService"))
	local AccusationService = require(Server:WaitForChild("AccusationService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local RevealService = require(Server:WaitForChild("RevealService"))
	local TimelineService = require(Server:WaitForChild("TimelineService"))
	local CutsceneService = require(Server:WaitForChild("CutsceneService"))
	local GameStateService = require(Server:WaitForChild("GameStateService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local CaseRegistry = require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local expect = t.expect

	local caseDef = CaseRegistry.get("CASE-001") :: any

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `C54-{id}` }
		PlayerDataService.initialize(player, "CASE-001")
		return player
	end

	local function evidenceById(id: string): any
		for _, evidence in ipairs(caseDef.evidence) do
			if evidence.id == id then
				return evidence
			end
		end
		error(`no evidence {id}`)
	end

	local function nodeText(suspectId: string, nodeId: string): string
		for _, conversation in ipairs(caseDef.conversations) do
			if conversation.suspectId == suspectId then
				return conversation.nodes[nodeId].text
			end
		end
		error(`no conversation for {suspectId}`)
	end

	local function byId(list: { any }, id: string): any
		for _, entry in ipairs(list) do
			if entry.id == id then
				return entry
			end
		end
		error(`no entry {id}`)
	end

	-- Conversation helpers (as CaseContent53_Test).
	local function toChoice(player: any): boolean
		for _ = 1, 30 do
			local payload = ConversationService.getCurrentPayload(player)
			if not payload.active then
				return false
			end
			if payload.choices then
				return true
			end
			ConversationService.advance(player)
		end
		error("conversation never reached a choice")
	end

	local function choiceIds(player: any): { [string]: boolean }
		local ids = {}
		for _, choice in ipairs(ConversationService.getCurrentPayload(player).choices or {}) do
			ids[choice.id] = true
		end
		return ids
	end

	local function meet(player: any, suspectId: string)
		expect.truthy(ConversationService.begin(player, suspectId))
		expect.truthy(toChoice(player))
	end

	local function ask(player: any, choiceId: string)
		local ok, reason = ConversationService.choose(player, choiceId)
		if not ok then
			error(`could not ask '{choiceId}': {reason}`)
		end
		toChoice(player)
	end

	-- Show a piece of evidence and listen to the whole reply.
	local function show(player: any, evidenceId: string)
		local ok, reason = ConversationService.choose(player, "show")
		if not ok then
			error(`could not offer to show: {reason}`)
		end
		ok, reason = ConversationService.present(player, evidenceId)
		if not ok then
			error(`could not show {evidenceId}: {reason}`)
		end
		toChoice(player)
	end

	-- The node ids from the current line to the next question (or the end).
	local function follow(player: any): { string }
		local ids = {}
		for _ = 1, 40 do
			local payload = ConversationService.getCurrentPayload(player)
			if not payload.active then
				break
			end
			table.insert(ids, payload.nodeId :: string)
			if payload.choices then
				break
			end
			ConversationService.advance(player)
			task.wait()
		end
		return ids
	end

	-- Choose a question and return the lines it plays.
	local function askAndFollow(player: any, choiceId: string): { string }
		local ok, reason = ConversationService.choose(player, choiceId)
		if not ok then
			error(`could not ask '{choiceId}': {reason}`)
		end
		return follow(player)
	end

	-- BindableEvent delivery is deferred: give it a frame to land. With a
	-- condition, wait (up to a limit) until it holds. Frames are dear in
	-- Studio, where every FireClient to a mock player logs an error, so a
	-- check that something did NOT happen waits just the one.
	local function settle(done: (() -> boolean)?)
		for _ = 1, 30 do
			task.wait()
			if not done or done() then
				return
			end
		end
	end

	local function known(player: any, statementId: string): boolean
		return ConversationService.isStatementUnlocked(player, statementId)
	end

	-- Find a clue (a repeat is not an error here: a route may have found it).
	local function find(player: any, evidenceId: string)
		EvidenceService.discover(player, evidenceId)
	end

	local function discovered(player: any, evidenceId: string): boolean
		return EvidenceService.isDiscovered(player, evidenceId)
	end

	local function openQuestion(player: any, id: string): any
		for _, question in ipairs(ReasoningService.getPayload(player).openQuestions) do
			if question.id == id then
				return question
			end
		end
		return nil
	end

	local function unlockedContradiction(player: any, id: string): boolean
		return ((PlayerDataService.get(player) :: any).caseState.unlockedContradictions)[id] == true
	end

	-- Up to Meera's admission by the gentle door: her alibi, then the phone's
	-- call log shown to her, then "tell me what really happened".
	local function gentleToAdmission(player: any)
		find(player, "EV-001")
		meet(player, "SUS-001")
		ask(player, "where")
		show(player, "EV-001")
		ask(player, "gentle")
	end

	-- Upset her: the same route, the harsh door. The conversation closes.
	local function upsetMeera(player: any)
		find(player, "EV-001")
		meet(player, "SUS-001")
		ask(player, "where")
		show(player, "EV-001")
		expect.equal(toChoice(player), true)
		ConversationService.choose(player, "harsh")
		follow(player)
		expect.falsy(ConversationService.isTalking(player))
	end

	-- The phone's code, worked out: the locked phone and the photo, then the
	-- right answer.
	local function workOutTheCode(player: any)
		find(player, "EV-001")
		find(player, "EV-013")
		ReasoningService.evaluate(player)
		expect.equal(ReasoningService.answerDeduction(player, "DEDUCT-007", "wedding"), "correct")
	end

	------------------------------------------------------------------
	-- The evidence
	------------------------------------------------------------------

	t.test("the case has thirteen pieces of evidence; the three new ones follow 5.3's ten", function()
		local ids = {}
		for _, evidence in ipairs(caseDef.evidence) do
			table.insert(ids, evidence.id)
		end
		expect.deepEqual(ids, {
			"EV-001", "EV-002", "EV-003", "EV-004", "EV-005", "EV-006", "EV-007",
			"EV-008", "EV-009", "EV-010", "EV-011", "EV-012", "EV-013",
		})
	end)

	t.test("the phone is fixed (no v1 name) and locked beyond its call log", function()
		expect.equal(
			evidenceById("EV-001").details,
			"Last call: 11:47 PM, to MEERA ♥. Rang for 31 seconds. Declined. The screen is locked beyond the call log."
		)
	end)

	t.test("the new clues read as approved", function()
		local message = evidenceById("EV-011")
		expect.equal(message.name, "Unsent Message")
		expect.equal(message.description, "A message on Daniel's phone that was never sent.")
		expect.equal(
			message.details,
			[[Draft to MEERA ♥, 11:48 PM: "I'm sorry about tonight. I'm finishing it with V. He's taking it badly. Then I'm coming home."]]
		)
		expect.equal(message.timestamp, "11:48 PM")
		expect.equal(message.timelineEventId, "TIMELINE-006")
		expect.equal(message.importance, "High")

		local watch = evidenceById("EV-012")
		expect.equal(watch.name, "Watch Data")
		expect.equal(watch.description, "Daniel's watch data, synced to his phone.")
		expect.equal(watch.details, "Heart rate recorded until 11:49 PM. Nothing after.")
		expect.equal(watch.timestamp, "11:49 PM")
		expect.equal(watch.timelineEventId, "TIMELINE-007")
		expect.equal(watch.importance, "Medium")

		local photo = evidenceById("EV-013")
		expect.equal(photo.name, "Photo of Meera")
		expect.equal(photo.description, "A photo in Daniel's desk drawer, one he never put on the desk.")
		expect.equal(
			photo.details,
			[[Meera in a songket, holding flowers. She's laughing at whoever held the camera. On the back, in Daniel's hand: "For M. — 07.12.09."]]
		)
		expect.equal(photo.importance, "Medium")
		for _, id in ipairs({ "EV-011", "EV-012", "EV-013" }) do
			expect.equal(evidenceById(id).location, "Daniel's Office")
		end
	end)

	t.test("the photo's clue is the whole hint: no other evidence or line names the wedding date", function()
		for _, evidence in ipairs(caseDef.evidence) do
			local text = `{evidence.description} {evidence.details or ""}`
			if evidence.id ~= "EV-013" then
				expect.falsy(string.find(text, "07.12.09", 1, true))
			end
		end
		expect.falsy(string.find(evidenceById("EV-001").details, "wedding", 1, true))
	end)

	t.test("the phone's evidence is optional: no objective needs it", function()
		expect.equal(#caseDef.objectives, 7)
		local needed = { ["EV-001"] = true, ["EV-002"] = true, ["EV-003"] = true, ["EV-006"] = true }
		for _, objective in ipairs(caseDef.objectives) do
			for _, requirement in ipairs(objective.requirements) do
				if requirement.evidence then
					expect.truthy(needed[requirement.evidence])
				end
			end
		end
	end)

	t.test("the coming-home statement is neutral about how she read it", function()
		local statement = byId(caseDef.statements, "STMT-SUS-001-HOME")
		expect.equal(statement.suspectId, "SUS-001")
		expect.equal(statement.label, "Coming Home")
		expect.equal(statement.text, [["He was coming home." Meera has read Daniel's last message.]])
	end)

	------------------------------------------------------------------
	-- One examine, two clues
	------------------------------------------------------------------

	t.test("the message hands over the watch data with it, and the readout says so", function()
		local player = makePlayer()
		expect.deepEqual(evidenceById("EV-011").grantsEvidence, { "EV-012" })
		local sent = {}
		local connection = EvidenceService.onDiscovered().Event:Connect(function(who, payload)
			if who.UserId == player.UserId then
				table.insert(sent, payload)
			end
		end)
		expect.truthy(EvidenceService.discover(player, "EV-011"))
		settle(function()
			return #sent >= 2
		end)
		connection:Disconnect()
		expect.truthy(discovered(player, "EV-011"))
		expect.truthy(discovered(player, "EV-012"))
		expect.equal(#sent, 2)
		expect.equal(sent[1].evidence.id, "EV-011")
		expect.deepEqual(sent[1].alsoAdded, { "Watch Data" })
		expect.equal(sent[2].granted, true)
		-- Both timeline events open with them.
		local ids = {}
		for _, event in ipairs(TimelineService.getChronological(player)) do
			table.insert(ids, event.id)
		end
		expect.deepEqual(ids, { "TIMELINE-006", "TIMELINE-007" })
	end)

	------------------------------------------------------------------
	-- Route A: Meera opens the phone
	------------------------------------------------------------------

	t.test("route A: the question is only offered after her admission, and hands over both clues", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-001"))
		meet(player, "SUS-001")
		expect.falsy(choiceIds(player).phone)
		ask(player, "where")
		expect.falsy(choiceIds(player).phone)
		show(player, "EV-001")
		ask(player, "gentle")
		expect.truthy(known(player, "STMT-SUS-001-ADMISSION"))
		expect.truthy(choiceIds(player).phone)

		expect.deepEqual(askAndFollow(player, "phone"), {
			"MARA-OPENPHONE-1",
			"MARA-OPENPHONE-2",
			"MARA-OPENPHONE-3",
			"MARA-OPENPHONE-4",
			"MARA-OPENPHONE-5",
		})
		expect.truthy(known(player, "STMT-SUS-001-HOME"))
		expect.truthy(discovered(player, "EV-011"))
		expect.truthy(discovered(player, "EV-012"))
		-- Done: it is not offered again, and she carries on at her hub.
		expect.falsy(choiceIds(player).phone)
		ConversationService.leave(player)
	end)

	t.test("route A reads as approved, word for word", function()
		expect.equal(nodeText("SUS-001", "MARA-OPENPHONE-1"), "...Give it here. He used the same code for everything.")
		expect.equal(nodeText("SUS-001", "MARA-OPENPHONE-2"), "Zero-seven, one-two, zero-nine. Our wedding.")
		expect.equal(nodeText("SUS-001", "MARA-OPENPHONE-3"), "There's a message. He never sent it.")
		expect.equal(
			nodeText("SUS-001", "MARA-OPENPHONE-4"),
			[["I'm sorry about tonight. I'm finishing it with V. He's taking it badly. Then I'm coming home."]]
		)
		expect.equal(nodeText("SUS-001", "MARA-OPENPHONE-5"), "He was coming home.")
		-- The line itself hands over both clues (each also hands over the other).
		for _, conversation in ipairs(caseDef.conversations) do
			if conversation.suspectId == "SUS-001" then
				expect.deepEqual(conversation.nodes["MARA-OPENPHONE-5"].grantsEvidence, { "EV-011", "EV-012" })
			end
		end
	end)

	t.test("route A: the question is gone once the message is already in hand", function()
		local player = makePlayer()
		gentleToAdmission(player)
		expect.truthy(choiceIds(player).phone)
		ConversationService.leave(player)
		expect.truthy(EvidenceService.discover(player, "EV-011"))
		meet(player, "SUS-001")
		expect.falsy(choiceIds(player).phone)
		ConversationService.leave(player)
	end)

	------------------------------------------------------------------
	-- Route B: the code, worked out from the room
	------------------------------------------------------------------

	t.test("'Daniel's Code' opens only with the locked phone and the photo together", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-001"))
		ReasoningService.evaluate(player)
		expect.falsy(openQuestion(player, "DEDUCT-007"))
		local other = makePlayer()
		expect.truthy(EvidenceService.discover(other, "EV-013"))
		ReasoningService.evaluate(other)
		expect.falsy(openQuestion(other, "DEDUCT-007"))

		expect.truthy(EvidenceService.discover(player, "EV-013"))
		ReasoningService.evaluate(player)
		local question = openQuestion(player, "DEDUCT-007")
		expect.truthy(question)
		expect.equal(question.prompt, "Daniel's phone is locked. What would he choose as the code?")
		expect.equal(#question.options, 4)
		expect.falsy(question.answer)
		local texts = {}
		for _, option in ipairs(question.options) do
			table.insert(texts, option.text)
		end
		expect.deepEqual(texts, {
			"Meera's birthday.",
			"Their wedding date.",
			"The day the firm opened.",
			"The day Daniel was born.",
		})
	end)

	t.test("a wrong code says only that it doesn't hold, and counts", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-001"))
		expect.truthy(EvidenceService.discover(player, "EV-013"))
		ReasoningService.evaluate(player)
		expect.equal(ReasoningService.answerDeduction(player, "DEDUCT-007", "birthday"), "wrong")
		expect.equal((PlayerDataService.get(player) :: any).caseState.reasoningMistakes, 1)
		expect.falsy(((PlayerDataService.get(player) :: any).caseState.unlockedDeductions)["DEDUCT-007"])
		expect.falsy(discovered(player, "EV-011"))
	end)

	t.test("route B: the right code lights the phone, and reading it hands over both clues", function()
		local player = makePlayer()
		RevealService.refresh(player)
		expect.falsy(RevealService.isInWorld("EV-011"))
		workOutTheCode(player)
		RevealService.refresh(player)
		expect.truthy(RevealService.isInWorld("EV-011"))
		-- The evidence itself was never gated by the prop.
		expect.falsy(discovered(player, "EV-011"))
		expect.truthy(EvidenceService.discover(player, "EV-011"))
		expect.truthy(discovered(player, "EV-012"))
		RevealService.refresh(makePlayer())
	end)

	t.test("route B: shown the message, Meera reads it twice, then says it", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-011"))
		meet(player, "SUS-001")
		expect.falsy(known(player, "STMT-SUS-001-HOME"))
		expect.truthy(ConversationService.choose(player, "show"))
		expect.truthy(ConversationService.present(player, "EV-011"))
		expect.deepEqual(follow(player), { "MARA-MSG-0", "MARA-MSG-1", "MARA-MSG-2", "MARA-MSG-3" })
		expect.truthy(known(player, "STMT-SUS-001-HOME"))
		ConversationService.leave(player)
	end)

	t.test("route B lines read as approved, word for word", function()
		expect.equal(nodeText("SUS-001", "MARA-MSG-0"), "He wrote this to you at 11:48. He never sent it.")
		expect.equal(nodeText("SUS-001", "MARA-MSG-1"), "...")
		expect.equal(nodeText("SUS-001", "MARA-MSG-2"), "Let me read it again.")
		expect.equal(nodeText("SUS-001", "MARA-MSG-3"), "...He was coming home.")
		expect.equal(nodeText("SUS-001", "MARA-MSG-KNOWN"), "I know what it says. Keep it safe for me.")
	end)

	t.test("the message shown to Meera after she has already read it gets her quiet answer", function()
		local player = makePlayer()
		gentleToAdmission(player)
		ask(player, "phone")
		expect.truthy(known(player, "STMT-SUS-001-HOME"))
		expect.truthy(ConversationService.choose(player, "show"))
		expect.truthy(ConversationService.present(player, "EV-011"))
		expect.deepEqual(follow(player), { "MARA-MSG-KNOWN" })
		ConversationService.leave(player)
	end)

	------------------------------------------------------------------
	-- The harsh road, never thawed
	------------------------------------------------------------------

	t.test("upset and never thawed: the message is the way back, and it clears her upset", function()
		local player = makePlayer()
		upsetMeera(player)
		expect.truthy(ConversationService.conditionsHold(player, { { kind = "Flag", id = "mara_upset" } }))

		-- Without the message she is cold, and offers only the two old questions.
		meet(player, "SUS-001")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "MARA-COLD")
		expect.truthy(choiceIds(player).apologise)
		expect.truthy(choiceIds(player).insist)
		expect.falsy(choiceIds(player).message)
		ConversationService.leave(player)

		-- The code worked out on her own: the phone was never opened for her.
		workOutTheCode(player)
		expect.truthy(EvidenceService.discover(player, "EV-011"))
		meet(player, "SUS-001")
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "MARA-COLD")
		expect.truthy(choiceIds(player).message)
		expect.deepEqual(askAndFollow(player, "message"), {
			"MARA-MSG-COLD-1",
			"MARA-MSG-COLD-2",
			"MARA-MSG-COLD-3",
			"MARA-MSG-1",
			"MARA-MSG-2",
			"MARA-MSG-3",
		})
		expect.truthy(known(player, "STMT-SUS-001-HOME"))
		expect.falsy(ConversationService.conditionsHold(player, { { kind = "Flag", id = "mara_upset" } }))
		ConversationService.leave(player)
		-- She is no longer cold when spoken to again.
		meet(player, "SUS-001")
		expect.falsy(ConversationService.getCurrentPayload(player).nodeId == "MARA-COLD")
		ConversationService.leave(player)
	end)

	t.test("the cold line's new question reads as approved", function()
		expect.equal(nodeText("SUS-001", "MARA-MSG-COLD-1"), "...What message?")
		expect.equal(nodeText("SUS-001", "MARA-MSG-COLD-2"), "It's on his phone. He wrote it at 11:48.")
		expect.equal(nodeText("SUS-001", "MARA-MSG-COLD-3"), "...Show me.")
		local cold = (function()
			for _, conversation in ipairs(caseDef.conversations) do
				if conversation.suspectId == "SUS-001" then
					return conversation.nodes["MARA-COLD"]
				end
			end
			error("no Meera")
		end)()
		local texts = {}
		for _, choice in ipairs(cold.choices) do
			texts[choice.id] = choice.text
		end
		expect.equal(texts.message, "He left a message for you. I found it.")
	end)

	------------------------------------------------------------------
	-- Victor and the watch
	------------------------------------------------------------------

	-- Up to Victor's revised story: the alibi, then the badge log shown to him.
	local function toRevisedStory(player: any)
		expect.truthy(EvidenceService.discover(player, "EV-004"))
		meet(player, "SUS-002")
		ask(player, "left")
		show(player, "EV-004")
		expect.truthy(known(player, "STMT-SUS-002-REVISED"))
	end

	t.test("shown the watch data before he has told his revised story, Victor is unmoved", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.grant(player, "EV-012"))
		meet(player, "SUS-002")
		expect.truthy(ConversationService.choose(player, "show"))
		expect.truthy(ConversationService.present(player, "EV-012"))
		expect.equal(ConversationService.getCurrentPayload(player).nodeId, "VIC-SHOW-NOTHING")
		expect.falsy(unlockedContradiction(player, "CONTRA-006"))
		ConversationService.leave(player)
	end)

	t.test("shown the watch data after his revised story, Victor breaks, and CONTRA-006 is claimed", function()
		local player = makePlayer()
		toRevisedStory(player)
		expect.truthy(EvidenceService.grant(player, "EV-012"))
		expect.truthy(ConversationService.choose(player, "show"))
		expect.truthy(ConversationService.present(player, "EV-012"))
		-- Three new lines, then the same break as the phone's: his own words
		-- run out, and he asks for a lawyer.
		expect.deepEqual(follow(player), {
			"VIC-WATCH-0", "VIC-WATCH-1", "VIC-WATCH-2",
			"VIC-CONF-3", "VIC-CONF-4", "VIC-CONF-5", "VIC-CONF-6", "VIC-CONF-7",
		})
		expect.truthy(unlockedContradiction(player, "CONTRA-006"))
		expect.truthy(known(player, "STMT-SUS-002-BREAK"))
	end)

	t.test("Victor's watch-data lines read as approved, word for word", function()
		expect.equal(nodeText("SUS-002", "VIC-WATCH-0"), "Daniel's watch stopped recording at 11:49. Your badge left at 11:52.")
		expect.equal(nodeText("SUS-002", "VIC-WATCH-1"), "Aiya, those things lose signal all the time. It means nothing.")
		expect.equal(
			nodeText("SUS-002", "VIC-WATCH-2"),
			"It means he was alive at 11:48 and gone by 11:49. You were still in the building."
		)
	end)

	t.test("CONTRA-006 is claimed in the case file by pairing his story with the watch, in either order", function()
		local story = { kind = "Statement", id = "STMT-SUS-002-REVISED" }
		local watch = { kind = "Evidence", id = "EV-012" }
		local contradiction = byId(caseDef.contradictions, "CONTRA-006")
		expect.equal(contradiction.label, "Still in the Building")
		expect.equal(
			contradiction.reason,
			"Victor says Daniel was alive when he left. Daniel's watch records his last heartbeat at 11:49. Victor's badge didn't leave until 11:52."
		)

		local early = makePlayer()
		expect.truthy(EvidenceService.grant(early, "EV-012"))
		expect.equal(ReasoningService.claimContradiction(early, story, watch), "invalid") -- no revised story yet

		local forward = makePlayer()
		toRevisedStory(forward)
		ConversationService.leave(forward)
		expect.truthy(EvidenceService.grant(forward, "EV-012"))
		expect.equal(ReasoningService.claimContradiction(forward, story, watch), "claimed")
		expect.equal(ReasoningService.claimContradiction(forward, watch, story), "already")

		local backward = makePlayer()
		toRevisedStory(backward)
		ConversationService.leave(backward)
		expect.truthy(EvidenceService.grant(backward, "EV-012"))
		expect.equal(ReasoningService.claimContradiction(backward, watch, story), "claimed")
	end)

	------------------------------------------------------------------
	-- The timeline: seven events once everything is found
	------------------------------------------------------------------

	local CANONICAL = {
		"TIMELINE-005", "TIMELINE-001", "TIMELINE-002", "TIMELINE-006", "TIMELINE-007", "TIMELINE-004", "TIMELINE-003",
	}

	t.test("the night has seven events, and the two new ones fall between the call and the badge", function()
		expect.equal(#caseDef.timeline, 7)
		local six = byId(caseDef.timeline, "TIMELINE-006")
		expect.equal(six.timestamp, "11:48 PM")
		expect.equal(six.title, "A message never sent")
		expect.equal(six.description, "Daniel starts a message to Meera. He never sends it.")
		expect.deepEqual(six.sourceEvidenceIds, { "EV-011" })
		local seven = byId(caseDef.timeline, "TIMELINE-007")
		expect.equal(seven.timestamp, "11:49 PM")
		expect.equal(seven.title, "The last heartbeat")
		expect.equal(seven.description, "Daniel's watch records its last heart rate. Nothing after.")
		expect.deepEqual(seven.sourceEvidenceIds, { "EV-012" })
	end)

	t.test("the approved challenge order holds, and differs from the canonical order at every place", function()
		expect.deepEqual(caseDef.timelineChallengeOrder, {
			"TIMELINE-004", "TIMELINE-003", "TIMELINE-007", "TIMELINE-005", "TIMELINE-006", "TIMELINE-002", "TIMELINE-001",
		})
		for index, id in ipairs(caseDef.timelineChallengeOrder) do
			expect.falsy(id == caseDef.timeline[index].id)
			expect.falsy(id == CANONICAL[index])
		end
	end)

	t.test("with everything found the player is shown the shuffled night and can put it in order", function()
		local player = makePlayer()
		for _, evidence in ipairs(caseDef.evidence) do
			EvidenceService.discover(player, evidence.id)
		end
		local shown = {}
		for _, event in ipairs(TimelineService.getDiscovered(player)) do
			table.insert(shown, event.id)
		end
		expect.deepEqual(shown, caseDef.timelineChallengeOrder)
		expect.falsy(TimelineService.submitSequence(player, shown))
		expect.truthy(TimelineService.submitSequence(player, CANONICAL))
	end)

	t.test("without the phone the night is still the original five, in the original order", function()
		local player = makePlayer()
		for _, id in ipairs({ "EV-001", "EV-002", "EV-003", "EV-004", "EV-005" }) do
			EvidenceService.discover(player, id)
		end
		expect.truthy(TimelineService.submitSequence(player, {
			"TIMELINE-005", "TIMELINE-001", "TIMELINE-002", "TIMELINE-004", "TIMELINE-003",
		}))
	end)

	------------------------------------------------------------------
	-- The accusation (grading untouched)
	------------------------------------------------------------------

	local function establish(player: any, deductions: { string }, contradictions: { string })
		local data = PlayerDataService.get(player) :: any
		data.caseState.completedObjectives["OBJ-000"] = true
		data.caseState.completedObjectives["OBJ-001"] = true
		data.caseState.completedObjectives["OBJ-002"] = true
		for _, id in ipairs(deductions) do
			data.caseState.unlockedDeductions[id] = true
		end
		for _, id in ipairs(contradictions) do
			data.caseState.unlockedContradictions[id] = true
		end
	end

	t.test("CONTRA-006 joins ACC-001's proofs; motives, support and the other accusation don't move", function()
		local one = byId(caseDef.accusations, "ACC-001")
		expect.deepEqual(one.proofs, { "CONTRA-001", "CONTRA-002", "CONTRA-005", "CONTRA-006" })
		expect.deepEqual(one.motives, { "DEDUCT-002", "DEDUCT-001", "DEDUCT-006" })
		expect.deepEqual(one.supportedBy.contradictions, { "CONTRA-001", "CONTRA-002" })
		expect.deepEqual(one.supportedBy.deductions, { "DEDUCT-001", "DEDUCT-002", "DEDUCT-004" })
		local two = byId(caseDef.accusations, "ACC-002")
		expect.deepEqual(two.supportedBy.contradictions, { "CONTRA-003" })
		expect.equal(caseDef.accusationRules.opensAfter, "OBJ-002")
	end)

	t.test("the watch is listed as a proof once established, and holds: Solved", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-002" }, { "CONTRA-006" })
		local payload = AccusationService.getPayload(player)
		expect.equal(#payload.proofs, 1)
		expect.equal(payload.proofs[1].id, "CONTRA-006")
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-006"))
		expect.equal((AccusationService.getVerdict(player) :: any).grade, "Solved")
	end)

	t.test("the code question is not a motive or a proof", function()
		for _, accusation in ipairs(caseDef.accusations) do
			for _, id in ipairs(accusation.motives or {}) do
				expect.falsy(id == "DEDUCT-007")
			end
		end
	end)

	------------------------------------------------------------------
	-- The reveal, the four Solved endings, and the dawn outro
	------------------------------------------------------------------

	local function solvedVerdict(homeKnown: boolean, breakKnown: boolean): any
		local player = makePlayer()
		establish(player, { "DEDUCT-002" }, { "CONTRA-005" })
		local data = PlayerDataService.get(player) :: any
		if homeKnown then
			data.caseState.unlockedStatements["STMT-SUS-001-HOME"] = true
		end
		if breakKnown then
			data.caseState.unlockedStatements["STMT-SUS-002-BREAK"] = true
		end
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-005"))
		return { player = player, verdict = AccusationService.getVerdict(player) }
	end

	t.test("the four Solved endings, by what the investigator learned", function()
		local both = solvedVerdict(true, true).verdict
		expect.equal(
			both.epilogue,
			"Victor Lim is charged before sunrise. What he said in that meeting room goes into the file word for word. "
				.. "The folder is in the boot of his car. Meera takes Daniel's phone home, and on the train she turns it face up."
		)
		local home = solvedVerdict(true, false).verdict
		expect.equal(
			home.epilogue,
			"Victor Lim is charged before sunrise. The folder is in the boot of his car. "
				.. "Meera takes Daniel's phone home, and on the train she turns it face up."
		)
		local broke = solvedVerdict(false, true).verdict
		expect.equal(
			broke.epilogue,
			"Victor Lim is charged before sunrise. What he said in that meeting room goes into the file word for word, "
				.. "and his lawyer can't take it back. The folder is in the boot of his car. "
				.. "The papers are still on Daniel's desk, unsigned."
		)
		local base = solvedVerdict(false, false).verdict
		expect.equal(
			base.epilogue,
			"Victor Lim is charged before sunrise. The folder is in the boot of his car. "
				.. "The papers are still on Daniel's desk, unsigned."
		)
	end)

	t.test("the reveal is the approved telling, and is the same at every verdict", function()
		expect.truthy(string.find(caseDef.solution.reveal, "Victor Lim had been paying himself through a joinery firm that existed only on paper.", 1, true))
		expect.truthy(string.find(caseDef.solution.reveal, "A minute later they were fighting over the drawer, and Daniel fell against the credenza.", 1, true))
		expect.truthy(string.find(caseDef.solution.reveal, "his badge left at 11:52.", 1, true))
		expect.equal((solvedVerdict(false, false).verdict :: any).reveal, caseDef.solution.reveal)
	end)

	t.test("the unproven and wrong endings are unchanged", function()
		expect.equal(
			caseDef.solution.unprovenEpilogue,
			"Victor Lim walks out at three in the morning with his lawyer. You know what happened in that office. You couldn't make it hold."
		)
		local wrong = makePlayer()
		establish(wrong, { "DEDUCT-006" }, { "CONTRA-003" })
		expect.truthy(AccusationService.accuse(wrong, "ACC-002", "DEDUCT-006", "CONTRA-003"))
		expect.equal((AccusationService.getVerdict(wrong) :: any).epilogue, byId(caseDef.accusations, "ACC-002").wrongEpilogue)
	end)

	t.test("the outro is the phone one only when she has read the message, and only for a Solved case", function()
		local base = solvedVerdict(false, true)
		expect.equal(AccusationService.getOutroCutsceneId(base.player), "CUT-DAWN")
		local home = solvedVerdict(true, false)
		expect.equal(AccusationService.getOutroCutsceneId(home.player), "CUT-DAWN-HOME")

		-- Unproven: the right person but no case that holds.
		local unproven = makePlayer()
		establish(unproven, { "DEDUCT-003" }, { "CONTRA-004" })
		expect.truthy(AccusationService.accuse(unproven, "ACC-001", "DEDUCT-003", "CONTRA-004"))
		expect.equal((AccusationService.getVerdict(unproven) :: any).grade, "Unproven")
		expect.equal(AccusationService.getOutroCutsceneId(unproven), nil)

		local wrong = makePlayer()
		establish(wrong, { "DEDUCT-006" }, { "CONTRA-005", "CONTRA-003" })
		expect.truthy(AccusationService.accuse(wrong, "ACC-002", "DEDUCT-006", "CONTRA-005"))
		expect.equal(AccusationService.getOutroCutsceneId(wrong), nil)
		expect.equal(AccusationService.getOutroCutsceneId(makePlayer()), nil) -- no accusation
	end)

	t.test("the two dawn scenes are the same shots, apart from one caption", function()
		local plain, home
		for _, cutscene in ipairs(caseDef.cutscenes) do
			if cutscene.id == "CUT-DAWN" then
				plain = cutscene
			elseif cutscene.id == "CUT-DAWN-HOME" then
				home = cutscene
			end
		end
		expect.truthy(plain and home)
		expect.equal(#plain.shots, 3)
		expect.equal(#home.shots, 3)
		local seconds = 0
		for index, shot in ipairs(plain.shots) do
			seconds += shot.duration
			expect.equal(shot.id, home.shots[index].id)
			expect.equal(shot.duration, home.shots[index].duration)
			if shot.id ~= "WINDOW" then
				expect.deepEqual(shot.lines, home.shots[index].lines)
			end
		end
		expect.equal(seconds, 18)
		expect.equal(plain.skippable, nil) -- skippable, by default
		expect.equal(plain.shots[1].lines[1].text, "First light over Kota Arwana.")
		expect.equal(plain.shots[2].lines[1].text, "She stays at the window.")
		expect.equal(home.shots[2].lines[1].text, "She turns it face up.")
		expect.equal(#CutsceneService.validate(caseDef), 0)
	end)

	-- Drive the single shared phase machine to "Investigation" (as
	-- GameStateService_Test does), so requestConclude has its edge.
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
	end

	-- A solved close, announced: the outro plays first, and the summary is
	-- held until it is over. `announceClose` is the hand-off itself; going
	-- through requestConclude as well needs the whole phase machine walked
	-- (slow in Studio, where the real client reacts to every phase), so only
	-- one test does.
	local function announce(homeKnown: boolean): any
		local result = solvedVerdict(homeKnown, false)
		local player = result.player
		local closed = {}
		local connection = GameStateService.onCaseClosed().Event:Connect(function(who, summary)
			if who.UserId == player.UserId then
				table.insert(closed, summary)
			end
		end)
		GameStateService.announceClose(player)
		return { player = player, closed = closed, connection = connection }
	end

	t.test("a Solved close plays the dawn outro first, and holds the summary back", function()
		local now = 0
		CutsceneService.useClock(function()
			return now
		end)
		local run = announce(true)
		expect.equal(CutsceneService.getActiveId(run.player), "CUT-DAWN-HOME")
		expect.truthy(GameStateService.isClosingScenePlaying(run.player))
		expect.equal(#run.closed, 0)
		-- Too early to be over: the server doesn't take the client's word.
		now = 5
		expect.falsy(CutsceneService.finish(run.player, "CUT-DAWN-HOME", false))
		expect.truthy(GameStateService.isClosingScenePlaying(run.player))
		run.connection:Disconnect()
		CutsceneService.useClock(nil)
	end)

	t.test("when the outro has run its length, the summary follows, once", function()
		local now = 0
		CutsceneService.useClock(function()
			return now
		end)
		local run = announce(true)
		expect.equal(#run.closed, 0)
		now = 18
		expect.truthy(CutsceneService.finish(run.player, "CUT-DAWN-HOME", false))
		settle(function()
			return #run.closed >= 1
		end)
		run.connection:Disconnect()
		CutsceneService.useClock(nil)
		expect.equal(#run.closed, 1)
		expect.equal(run.closed[1].verdict.grade, "Solved")
		expect.falsy(GameStateService.isClosingScenePlaying(run.player))
		expect.equal(CutsceneService.getActiveId(run.player), nil)
	end)

	t.test("skipping the outro opens the summary at once, and only once", function()
		local run = announce(false)
		expect.equal(CutsceneService.getActiveId(run.player), "CUT-DAWN")
		expect.equal(#run.closed, 0)
		expect.truthy(CutsceneService.finish(run.player, "CUT-DAWN", true))
		-- A second report of the same end is refused at once, so it can't
		-- announce the close again.
		expect.falsy(CutsceneService.finish(run.player, "CUT-DAWN", true))
		settle(function()
			return #run.closed >= 1
		end)
		run.connection:Disconnect()
		expect.equal(#run.closed, 1)
	end)

	t.test("an outro the client never reports still ends, and the summary follows", function()
		local now = 0
		CutsceneService.useClock(function()
			return now
		end)
		local run = announce(false)
		expect.equal(#run.closed, 0)
		now = 60
		expect.truthy(CutsceneService.expire(run.player))
		settle(function()
			return #run.closed >= 1
		end)
		run.connection:Disconnect()
		CutsceneService.useClock(nil)
		expect.equal(#run.closed, 1)
	end)

	t.test("a case that didn't hold closes straight onto its summary, with no scene", function()
		resetToInvestigation()
		local player = makePlayer()
		establish(player, { "DEDUCT-006" }, { "CONTRA-005", "CONTRA-003" })
		expect.truthy(AccusationService.accuse(player, "ACC-002", "DEDUCT-006", "CONTRA-005"))
		local closed = {}
		local connection = GameStateService.onCaseClosed().Event:Connect(function(who, summary)
			if who.UserId == player.UserId then
				table.insert(closed, summary)
			end
		end)
		expect.truthy(GameStateService.requestConclude(player))
		settle(function()
			return #closed >= 1
		end)
		connection:Disconnect()
		expect.equal(#closed, 1)
		expect.equal(CutsceneService.getActiveId(player), nil)
		expect.falsy(GameStateService.isClosingScenePlaying(player))
	end)

	t.test("a Solved close concluded for real plays its outro, and only then closes", function()
		resetToInvestigation()
		local player = makePlayer()
		establish(player, { "DEDUCT-002" }, { "CONTRA-005" })
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-005"))
		local closed = {}
		local connection = GameStateService.onCaseClosed().Event:Connect(function(who, summary)
			if who.UserId == player.UserId then
				table.insert(closed, summary)
			end
		end)
		expect.truthy(GameStateService.requestConclude(player))
		expect.equal(GameStateService.getPhase(), "CaseClosed")
		expect.equal(CutsceneService.getActiveId(player), "CUT-DAWN")
		expect.truthy(GameStateService.isClosingScenePlaying(player))
		expect.truthy(CutsceneService.finish(player, "CUT-DAWN", true))
		settle(function()
			return #closed >= 1
		end)
		connection:Disconnect()
		expect.equal(#closed, 1)
		expect.equal(closed[1].verdict.grade, "Solved")
	end)

	------------------------------------------------------------------
	-- The world (built fresh headless; the patched baked place in Studio)
	------------------------------------------------------------------

	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)

	local function boundInteractable(instanceName: string): Instance?
		for _, instance in ipairs(CollectionService:GetTagged("Interactable")) do
			if instance.Name == instanceName then
				return instance
			end
		end
		return nil
	end

	t.test("the desk drawer carries EV-013, its prompt kept and no old flavour text", function()
		local drawer = boundInteractable("DeskDrawer")
		expect.truthy(drawer)
		expect.equal((drawer :: Instance):GetAttribute("EvidenceId"), "EV-013")
		expect.equal((drawer :: Instance):GetAttribute("ObservationText"), nil)
		expect.truthy(#tostring((drawer :: Instance):GetAttribute("PromptLabel")) > 0)
	end)

	t.test("the phone's lit screen is a prop on the desk phone, held until its code is worked out", function()
		expect.truthy(office)
		RevealService.holdAll("CASE-001")
		expect.falsy(RevealService.isInWorld("EV-011"))
		-- Held out of the world it is still in the place, waiting in storage:
		-- find it by its contract, not by where it sits.
		local prop: Instance? = nil
		for _, instance in ipairs(CollectionService:GetTagged("Interactable")) do
			if instance.Name == "EV-011" then
				prop = instance
			end
		end
		expect.truthy(prop)
		expect.equal((prop :: Instance):GetAttribute("EvidenceId"), "EV-011")
		expect.equal((prop :: Instance):GetAttribute("PromptLabel"), "Read Unlocked Phone")
		local text = (prop :: Instance):FindFirstChildWhichIsA("TextLabel", true)
		expect.truthy(text)
		-- It lies on the desk phone's face, at its top.
		local phone = boundInteractable("Phone") :: BasePart?
		if phone then
			local part = prop :: BasePart
			expect.truthy(math.abs(part.Position.X - phone.Position.X) < 0.05)
			expect.truthy(math.abs(part.Position.Z - phone.Position.Z) < 0.05)
			expect.truthy(part.Position.Y > phone.Position.Y + phone.Size.Y / 2)
			expect.truthy(part.Position.Y < phone.Position.Y + phone.Size.Y / 2 + 0.1)
		end
		-- Never left revealed for the next test.
		RevealService.holdAll("CASE-001")
	end)
end
