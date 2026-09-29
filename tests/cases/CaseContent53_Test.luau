--!strict
--[[
	Phase 5.3: CASE-001 v2 content that doesn't need the phone.

	EV-008 to EV-010, three new statements, CONTRA-005, DEDUCT-005/006, the
	badge log printed on request, and the accusation's new motive and proof --
	each proved through the real services, not by reading data alone. The
	phone's evidence (EV-011/012, CONTRA-006, STMT-SUS-001-HOME) is 5.4 and is
	deliberately absent; the last test pins that.

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
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local CaseRegistry = require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local expect = t.expect

	local caseDef = CaseRegistry.get("CASE-001") :: any

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `C53-{id}` }
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

	local function statementById(id: string): any
		for _, statement in ipairs(caseDef.statements) do
			if statement.id == id then
				return statement
			end
		end
		error(`no statement {id}`)
	end

	-- Conversation helpers (as Case001_Test): keep continuing until the line
	-- waits for a question.
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

	-- Begin talking to `suspectId`, and wait at the first question list.
	local function meet(player: any, suspectId: string)
		expect.truthy(ConversationService.begin(player, suspectId))
		expect.truthy(toChoice(player))
	end

	-- Ask one question and listen to the whole answer.
	local function ask(player: any, choiceId: string)
		local ok, reason = ConversationService.choose(player, choiceId)
		if not ok then
			error(`could not ask '{choiceId}': {reason}`)
		end
		toChoice(player)
	end

	local function stepId(player: any): string?
		return ConversationService.getCurrentPayload(player).nodeId
	end

	local function known(player: any, statementId: string): boolean
		return ConversationService.isStatementUnlocked(player, statementId)
	end

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

	------------------------------------------------------------------
	-- The evidence
	------------------------------------------------------------------

	t.test("the case now has ten pieces of evidence, three of them optional new finds", function()
		local ids = {}
		for _, evidence in ipairs(caseDef.evidence) do
			table.insert(ids, evidence.id)
		end
		expect.deepEqual(ids, { "EV-001", "EV-002", "EV-003", "EV-004", "EV-005", "EV-006", "EV-007", "EV-008", "EV-009", "EV-010" })
	end)

	t.test("no objective changed shape: the same seven, needing only the original clues", function()
		expect.equal(#caseDef.objectives, 7)
		local needed = { ["EV-001"] = true, ["EV-002"] = true, ["EV-003"] = true, ["EV-006"] = true }
		for _, objective in ipairs(caseDef.objectives) do
			for _, requirement in ipairs(objective.requirements) do
				if requirement.evidence then
					expect.truthy(needed[requirement.evidence])
				end
			end
		end
		for _, objective in ipairs(caseDef.objectives) do
			if objective.id == "OBJ-003" then
				expect.truthy(string.find(objective.description, "The night guard knows how people get in and out.", 1, true))
			end
		end
	end)

	t.test("the changed and new clues read as approved", function()
		local laptop = evidenceById("EV-002").details
		expect.truthy(string.find(laptop, "Termination of Shareholders' Agreement & Buy-Out", 1, true))
		expect.truthy(string.find(laptop, "Clause 14: if a shareholder dies before completion, his shares pass to his estate.", 1, true))
		expect.equal(evidenceById("EV-003").details, '12:00 AM, with V. Lim: "Sign it. No more delays."')
		expect.truthy(string.find(evidenceById("EV-007").details, "PANTAU Sekuriti · Servis 24 Jam · Tiket #4471", 1, true))
		expect.equal(
			evidenceById("EV-008").details,
			'Patrol tape where he lay. Ambulance tag: "Pronounced 12:26 AM. Head injury. Fall against furniture." The credenza corner is chipped.'
		)
		expect.equal(
			evidenceById("EV-009").details,
			"Daniel and Victor at a ribbon-cutting, fifteen years younger. The glass is cracked and the photo has been turned face down."
		)
		expect.equal(
			evidenceById("EV-010").details,
			'Opened tonight; the folders are out of order. The divider "VENDOR INVOICES — KEMAS" has nothing behind it.'
		)
		expect.equal(evidenceById("EV-009").location, "Records Room")
		expect.equal(evidenceById("EV-010").location, "Records Room")
		-- The object each one is found on.
		expect.equal(evidenceById("EV-009").bindTo.instanceName, "Shelf_Frame")
		expect.equal(evidenceById("EV-010").bindTo.instanceName, "FileCabinet_1")
		expect.equal(evidenceById("EV-008").propPlacement.style, "AmbulanceTag")
		-- Their old flavour text is gone: a promoted object has one voice.
		for _, observation in ipairs(caseDef.observations) do
			expect.falsy(observation.instanceName == "Shelf_Frame")
			expect.falsy(observation.instanceName == "FileCabinet_1")
		end
	end)

	------------------------------------------------------------------
	-- The approved words
	------------------------------------------------------------------

	t.test("the approved lines and statements are in, word for word", function()
		expect.equal(nodeText("SUS-003", "SAM-BADGE-2"), "You nak tengok the log? I can print it now.")
		expect.equal(nodeText("SUS-003", "SAM-BADGE-3"), "Okay, it's printing. ...There. On the reception counter.")
		expect.equal(nodeText("SUS-003", "SAM-BADGE-4"), "Haven't read it. Figured that's your job.")
		expect.equal(nodeText("SUS-003", "SAM-TAPE-1"), "Nobody, since the ambulance crew.")
		expect.equal(nodeText("SUS-003", "SAM-TAPE-2"), "Mr. Lim came up with the police at half twelve. Wanted to go in the office.")
		expect.equal(nodeText("SUS-003", "SAM-TAPE-3"), "I said sorry boss, police tape. He wasn't happy.")
		expect.equal(nodeText("SUS-003", "SAM-TAPE-4"), "I told him Mr. Rozario passed. That's all I know, what else I'm going to tell him?")
		expect.equal(nodeText("SUS-002", "VIC-MEERA-1"), "Speak to her? She won't look at me.")
		expect.equal(nodeText("SUS-002", "VIC-MEERA-2"), "Ask her why she didn't pick up when he rang. That's your mystery, Detective.")
		expect.equal(nodeText("SUS-001", "MARA-VICTOR-4"), "I haven't said a word to Victor tonight. I won't.")
		expect.equal(
			statementById("STMT-SUS-003-BADGE").text,
			"Every door locks at nine. Sam printed tonight's badge log for you at reception."
		)
		expect.equal(
			statementById("STMT-SUS-003-TAPE").text,
			"Nobody past the tape since the ambulance crew. Mr. Lim asked to go in; Sam said no. Sam told him only that Daniel had passed."
		)
		expect.equal(
			statementById("STMT-SUS-002-MEERA").text,
			'"Ask her why she didn\'t pick up when he rang. That\'s your mystery, Detective."'
		)
		expect.equal(statementById("STMT-SUS-001-SILENT").text, `"I haven't said a word to Victor tonight. I won't."`)
	end)

	t.test("questions that unlock a statement are never `once`, so walking away can't lose one", function()
		for _, conversation in ipairs(caseDef.conversations) do
			for _, node in pairs(conversation.nodes) do
				for _, choice in ipairs(node.choices or {}) do
					if choice.id == "tape" or choice.id == "meera" or choice.id == "victor" then
						expect.falsy(choice.once)
					end
				end
			end
		end
	end)

	------------------------------------------------------------------
	-- The badge log, printed on request
	------------------------------------------------------------------

	t.test("the printout is only in the world once Sam has printed it", function()
		local player = makePlayer()
		RevealService.refresh(player)
		expect.falsy(RevealService.isInWorld("EV-004"))
		meet(player, "SUS-003")
		expect.truthy(choiceIds(player).badges)
		expect.truthy(ConversationService.choose(player, "badges"))
		expect.equal(stepId(player), "SAM-BADGE-1")
		ConversationService.advance(player)
		expect.equal(stepId(player), "SAM-BADGE-2") -- "You nak tengok the log?"
		expect.falsy(known(player, "STMT-SUS-003-BADGE"))
		RevealService.refresh(player)
		expect.falsy(RevealService.isInWorld("EV-004"))
		ConversationService.advance(player)
		expect.equal(stepId(player), "SAM-BADGE-3") -- "Okay, it's printing."
		expect.truthy(known(player, "STMT-SUS-003-BADGE"))
		RevealService.refresh(player)
		expect.truthy(RevealService.isRevealed(player, "EV-004"))
		expect.truthy(RevealService.isInWorld("EV-004"))
		toChoice(player)
		expect.falsy(choiceIds(player).badges) -- asked and answered
		ConversationService.leave(player)
		-- Leave the world as the case starts: held again for the next player.
		RevealService.refresh(makePlayer())
	end)

	t.test("hearing anything else from Sam never prints it", function()
		local player = makePlayer()
		meet(player, "SUS-003")
		ask(player, "found")
		ask(player, "anyone")
		ask(player, "cameras")
		ask(player, "tape")
		RevealService.refresh(player)
		expect.falsy(RevealService.isRevealed(player, "EV-004"))
		expect.falsy(RevealService.isInWorld("EV-004"))
		ConversationService.leave(player)
	end)

	------------------------------------------------------------------
	-- The new statements
	------------------------------------------------------------------

	t.test("Sam's tape: asked once, answered in four beats, then off the list", function()
		local player = makePlayer()
		meet(player, "SUS-003")
		expect.truthy(choiceIds(player).tape)
		expect.truthy(ConversationService.choose(player, "tape"))
		for _, expected in ipairs({ "SAM-TAPE-1", "SAM-TAPE-2", "SAM-TAPE-3", "SAM-TAPE-4" }) do
			expect.equal(stepId(player), expected)
			expect.falsy(known(player, "STMT-SUS-003-TAPE") and expected ~= "SAM-TAPE-4")
			ConversationService.advance(player)
		end
		expect.truthy(known(player, "STMT-SUS-003-TAPE"))
		expect.falsy(choiceIds(player).tape)
		ConversationService.leave(player)
	end)

	t.test("Victor on Meera: available from his first words, and stays clean English", function()
		local player = makePlayer()
		meet(player, "SUS-002")
		expect.truthy(choiceIds(player).meera)
		expect.truthy(ConversationService.choose(player, "meera"))
		expect.equal(stepId(player), "VIC-MEERA-1")
		expect.falsy(known(player, "STMT-SUS-002-MEERA"))
		ConversationService.advance(player)
		expect.equal(stepId(player), "VIC-MEERA-2")
		expect.truthy(known(player, "STMT-SUS-002-MEERA"))
		expect.falsy(choiceIds(player).meera)
		ConversationService.leave(player)
	end)

	t.test("Meera's 'not a word' is on her answer about Victor, even once the laptop is found", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-002"))
		meet(player, "SUS-001")
		expect.truthy(choiceIds(player).victor) -- v1 hid it after the laptop
		expect.truthy(ConversationService.choose(player, "victor"))
		expect.equal(stepId(player), "MARA-VICTOR-1")
		ConversationService.advance(player)
		ConversationService.advance(player)
		expect.equal(stepId(player), "MARA-VICTOR-3")
		expect.falsy(known(player, "STMT-SUS-001-SILENT"))
		ConversationService.advance(player)
		expect.equal(stepId(player), "MARA-VICTOR-4")
		expect.truthy(known(player, "STMT-SUS-001-SILENT"))
		expect.falsy(choiceIds(player).victor)
		ConversationService.leave(player)
	end)

	------------------------------------------------------------------
	-- CONTRA-005: Nobody Told Him
	------------------------------------------------------------------

	t.test("'Nobody Told Him' is claimed by pairing Victor's words with Sam's tape statement, in either order", function()
		local mine = { kind = "Statement", id = "STMT-SUS-002-MEERA" }
		local sams = { kind = "Statement", id = "STMT-SUS-003-TAPE" }

		local early = makePlayer()
		expect.equal(ReasoningService.claimContradiction(early, mine, sams), "invalid") -- knows neither
		meet(early, "SUS-002")
		ask(early, "meera")
		ConversationService.leave(early)
		expect.equal(ReasoningService.claimContradiction(early, mine, sams), "invalid") -- knows only one

		local forward = makePlayer()
		meet(forward, "SUS-002")
		ask(forward, "meera")
		ConversationService.leave(forward)
		meet(forward, "SUS-003")
		ask(forward, "tape")
		ConversationService.leave(forward)
		expect.equal(ReasoningService.claimContradiction(forward, mine, sams), "claimed")
		expect.equal(ReasoningService.claimContradiction(forward, sams, mine), "already")
		expect.truthy(((PlayerDataService.get(forward) :: any).caseState.unlockedContradictions)["CONTRA-005"])

		local backward = makePlayer()
		meet(backward, "SUS-003")
		ask(backward, "tape")
		ConversationService.leave(backward)
		meet(backward, "SUS-002")
		ask(backward, "meera")
		ConversationService.leave(backward)
		expect.equal(ReasoningService.claimContradiction(backward, sams, mine), "claimed")
	end)

	t.test("the same two statements say nothing when set against anything else", function()
		local player = makePlayer()
		meet(player, "SUS-002")
		ask(player, "meera")
		ConversationService.leave(player)
		expect.truthy(EvidenceService.discover(player, "EV-001"))
		expect.equal(
			ReasoningService.claimContradiction(player, { kind = "Statement", id = "STMT-SUS-002-MEERA" }, { kind = "Evidence", id = "EV-001" }),
			"no-conflict"
		)
	end)

	------------------------------------------------------------------
	-- DEDUCT-005 and DEDUCT-006
	------------------------------------------------------------------

	local function openQuestion(player: any, id: string): any
		for _, question in ipairs(ReasoningService.getPayload(player).openQuestions) do
			if question.id == id then
				return question
			end
		end
		return nil
	end

	t.test("'By the Credenza' opens with the marked floor and the photo, and never carries its answer", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-008"))
		expect.falsy(openQuestion(player, "DEDUCT-005"))
		expect.truthy(EvidenceService.discover(player, "EV-009"))
		ReasoningService.evaluate(player)
		local question = openQuestion(player, "DEDUCT-005")
		expect.truthy(question)
		expect.equal(#question.options, 4)
		expect.falsy(question.answer)
		expect.equal(ReasoningService.answerDeduction(player, "DEDUCT-005", "struggle"), "correct")
		expect.truthy(((PlayerDataService.get(player) :: any).caseState.unlockedDeductions)["DEDUCT-005"])
	end)

	t.test("'Why It Couldn't Wait' opens with the drawer and the laptop", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-010"))
		ReasoningService.evaluate(player)
		expect.falsy(openQuestion(player, "DEDUCT-006"))
		expect.truthy(EvidenceService.discover(player, "EV-002"))
		ReasoningService.evaluate(player)
		expect.truthy(openQuestion(player, "DEDUCT-006"))
		expect.equal(ReasoningService.answerDeduction(player, "DEDUCT-006", "leverage"), "correct")
	end)

	t.test("a wrong answer to either says only that it doesn't hold, and counts", function()
		local player = makePlayer()
		expect.truthy(EvidenceService.discover(player, "EV-008"))
		expect.truthy(EvidenceService.discover(player, "EV-009"))
		ReasoningService.evaluate(player)
		expect.equal(ReasoningService.answerDeduction(player, "DEDUCT-005", "alone"), "wrong")
		expect.equal((PlayerDataService.get(player) :: any).caseState.reasoningMistakes, 1)
	end)

	------------------------------------------------------------------
	-- The accusation
	------------------------------------------------------------------

	t.test("the accusation offers the new motive and proof; its grading is untouched", function()
		local accusation
		for _, entry in ipairs(caseDef.accusations) do
			if entry.id == "ACC-001" then
				accusation = entry
			end
		end
		expect.deepEqual(accusation.motives, { "DEDUCT-002", "DEDUCT-001", "DEDUCT-006" })
		expect.deepEqual(accusation.proofs, { "CONTRA-001", "CONTRA-002", "CONTRA-005" })
		-- supportedBy is exactly v1's, so "supported" means what it did.
		expect.deepEqual(accusation.supportedBy.contradictions, { "CONTRA-001", "CONTRA-002" })
		expect.deepEqual(accusation.supportedBy.deductions, { "DEDUCT-001", "DEDUCT-002", "DEDUCT-004" })
		expect.equal(caseDef.accusationRules.opensAfter, "OBJ-002")
	end)

	t.test("the new motive and proof are listed once established, and hold: Solved", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-006" }, { "CONTRA-005" })
		local payload = AccusationService.getPayload(player)
		expect.equal(#payload.motives, 1)
		expect.equal(payload.motives[1].id, "DEDUCT-006")
		expect.equal(#payload.proofs, 1)
		expect.equal(payload.proofs[1].id, "CONTRA-005")
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-006", "CONTRA-005"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.truthy(verdict.correct)
		expect.equal(verdict.grade, "Solved")
	end)

	t.test("the slip alone can prove the case: two conversations, a pairing, and an accusation", function()
		local player = makePlayer()
		meet(player, "SUS-002")
		ask(player, "meera")
		ConversationService.leave(player)
		meet(player, "SUS-003")
		ask(player, "tape")
		ConversationService.leave(player)
		expect.equal(
			ReasoningService.claimContradiction(player, { kind = "Statement", id = "STMT-SUS-002-MEERA" }, { kind = "Statement", id = "STMT-SUS-003-TAPE" }),
			"claimed"
		)
		establish(player, { "DEDUCT-002" }, {})
		expect.truthy(AccusationService.accuse(player, "ACC-001", "DEDUCT-002", "CONTRA-005"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.equal(verdict.grade, "Solved")
	end)

	t.test("the wrong person is still wrong, and the new motive doesn't rescue them", function()
		local player = makePlayer()
		establish(player, { "DEDUCT-006" }, { "CONTRA-005", "CONTRA-003" })
		expect.truthy(AccusationService.accuse(player, "ACC-002", "DEDUCT-006", "CONTRA-005"))
		local verdict = AccusationService.getVerdict(player) :: any
		expect.falsy(verdict.correct)
		expect.equal(verdict.grade, "Wrong")
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

	t.test("the shelves and the file cabinet carry EV-009 and EV-010, and no old flavour text", function()
		local shelves = boundInteractable("Shelf_Frame")
		local cabinet = boundInteractable("FileCabinet_1")
		expect.truthy(shelves)
		expect.truthy(cabinet)
		expect.equal((shelves :: Instance):GetAttribute("EvidenceId"), "EV-009")
		expect.equal((cabinet :: Instance):GetAttribute("EvidenceId"), "EV-010")
		expect.equal((shelves :: Instance):GetAttribute("ObservationText"), nil)
		expect.equal((cabinet :: Instance):GetAttribute("ObservationText"), nil)
		-- The prompt still names the object, not the clue.
		expect.equal((shelves :: Instance):GetAttribute("PromptLabel"), "Examine Shelves")
	end)

	t.test("the marked floor is a tag beside the numbered marker, and the credenza stands clear of the tape", function()
		expect.truthy(office)
		local props = (office :: Instance):FindFirstChild("EvidenceProps")
		expect.truthy(props)
		local tag = (props :: Instance):FindFirstChild("EV-008") :: BasePart
		expect.truthy(tag)
		expect.equal(tag:GetAttribute("EvidenceId"), "EV-008")
		expect.equal(tag:GetAttribute("PromptLabel"), "Examine Marked Floor")
		local text = tag:FindFirstChildWhichIsA("TextLabel", true)
		expect.truthy(text and string.find((text :: TextLabel).Text, "HEAD INJURY", 1, true))

		local room = ((office :: Instance):FindFirstChild("Interior") :: Instance):FindFirstChild("DanielOffice")
		expect.truthy(room)
		local credenza = (room :: Instance):FindFirstChild("Credenza") :: Model
		expect.truthy(credenza)
		expect.truthy(credenza:FindFirstChild("Chip", true))
		local centre, size = credenza:GetBoundingBox()
		local minX, maxX = centre.Position.X - size.X / 2, centre.Position.X + size.X / 2
		local frontZ = centre.Position.Z + size.Z / 2
		-- East of the records-room door gap (x -22..-18), inside the east wall (-14.5).
		expect.truthy(minX > -18 and maxX < -14.5)
		-- No tape stroke, and not the tag, passes through it.
		local detailing = (office :: Instance):FindFirstChild("Detailing") :: Instance
		for _, strip in ipairs((detailing:FindFirstChild("TapeOutline") :: Instance):GetChildren()) do
			expect.truthy((strip :: BasePart).Position.Z > frontZ + 0.4)
		end
		expect.truthy(tag.Position.Z > frontZ + 0.4)
	end)

	t.test("the camera monitor carries the contractor's sticker", function()
		local props = (office :: Instance):FindFirstChild("EvidenceProps") :: Instance
		local look = props:FindFirstChild("EV-007_Look")
		expect.truthy(look)
		local sticker = (look :: Instance):FindFirstChild("Sticker", true)
		expect.truthy(sticker)
		local text = (sticker :: Instance):FindFirstChildWhichIsA("TextLabel", true) :: TextLabel
		expect.truthy(string.find(text.Text, "PANTAU Sekuriti", 1, true))
		expect.truthy(string.find(text.Text, "Tiket #4471", 1, true))
	end)

	------------------------------------------------------------------
	-- What waits for 5.4
	------------------------------------------------------------------

	t.test("the phone's evidence and its consequences are not in yet", function()
		for _, evidence in ipairs(caseDef.evidence) do
			expect.falsy(evidence.id == "EV-011" or evidence.id == "EV-012")
		end
		for _, contradiction in ipairs(caseDef.contradictions) do
			expect.falsy(contradiction.id == "CONTRA-006")
		end
		for _, statement in ipairs(caseDef.statements) do
			expect.falsy(statement.id == "STMT-SUS-001-HOME")
		end
		expect.equal(#caseDef.timeline, 5)
	end)
end
