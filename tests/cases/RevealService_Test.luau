--!strict
--[[
	Phase 5.1: evidence props revealed by a condition
	(EvidenceDefinition.propPlacement.revealWhen -> RevealService).

	Uses a synthetic fixture case and its own stand-in props, built in the
	same shape OfficeRoom builds them (a part named after the evidence id
	carrying the Interactable contract, plus a `<id>_Look` model) inside the
	EvidenceProps folder, and removed again after each test so the shared
	world is left as it was.
]]
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local RevealService = require(Server:WaitForChild("RevealService"))
	local ConversationService = require(Server:WaitForChild("ConversationService"))
	local PlayerDataService = require(Server:WaitForChild("PlayerDataService"))
	local EvidenceService = require(Server:WaitForChild("EvidenceService"))
	local InteractionService = require(Server:WaitForChild("InteractionService"))
	local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local CaseRegistry = require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local expect = t.expect

	local CASE_ID = "CASE-TEST-REVEAL"
	local AT = Vector3.new(0, -500, 0)

	CaseRegistry.register({
		id = CASE_ID,
		title = "Reveal Fixture",
		description = "",
		suspects = {
			{ id = "WIT", name = "Witness", role = "Night Security", alibi = "Rounds." },
		},
		locations = {},
		evidence = {
			{
				id = "EV-PRINT",
				name = "Printout",
				description = "",
				location = "Desk",
				importance = "High",
				propPlacement = {
					position = AT,
					style = "Printout",
					revealWhen = { { kind = "Statement", id = "STMT-OFFER" } },
				},
			},
			{
				id = "EV-FLAGGED",
				name = "Folder",
				description = "",
				location = "Desk",
				importance = "Low",
				propPlacement = { position = AT, revealWhen = { { kind = "Flag", id = "asked" } } },
			},
			{ id = "EV-OPEN", name = "Mug", description = "", location = "Desk", importance = "Low", propPlacement = { position = AT } },
		},
		timeline = {},
		objectives = {},
		conversations = {
			{
				suspectId = "WIT",
				startNodeId = "HUB",
				nodes = {
					HUB = {
						id = "HUB",
						speaker = "Witness",
						text = "Yes?",
						choices = {
							{ id = "offer", text = "The log?", next = "OFFER" },
							{ id = "ask", text = "The folder?", next = "ASK" },
							{ id = "forget", text = "Never mind.", next = "FORGET" },
						},
					},
					OFFER = {
						id = "OFFER",
						speaker = "Witness",
						text = "I'll print it.",
						statementId = "STMT-OFFER",
						choicesFrom = "HUB",
					},
					ASK = { id = "ASK", speaker = "Witness", text = "Over there.", setFlags = { "asked" }, choicesFrom = "HUB" },
					FORGET = { id = "FORGET", speaker = "Witness", text = "Fine.", clearFlags = { "asked" }, choicesFrom = "HUB" },
				},
			},
		},
		statements = {
			{ id = "STMT-OFFER", suspectId = "WIT", label = "Offered to print the log", text = "Offered to print it." },
		},
		contradictions = {},
		deductions = {},
	} :: any)

	local function makePlayer(): any
		local id = t.nextUserId()
		local player = { UserId = id, Name = `RV{id}` }
		PlayerDataService.initialize(player, CASE_ID)
		return player
	end

	local function propsFolder(): Instance
		local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
		return ((office or workspace) :: Instance):FindFirstChild("EvidenceProps") :: Instance
	end

	-- Stand-in props, shaped like OfficeRoom's, for the duration of `fn`.
	local function withProps(fn: (props: { [string]: BasePart }, looks: { [string]: Model }) -> ())
		local folder = propsFolder()
		local props: { [string]: BasePart } = {}
		local looks: { [string]: Model } = {}
		for _, id in ipairs({ "EV-PRINT", "EV-FLAGGED", "EV-OPEN" }) do
			local look = Instance.new("Model")
			look.Name = `{id}_Look`
			look.Parent = folder
			looks[id] = look
			local part = Instance.new("Part")
			part.Name = id
			part.Anchored = true
			part.Position = AT
			part.Parent = folder
			CollectionService:AddTag(part, Interactable.TAG)
			part:SetAttribute(Interactable.AttributeName.Kind, "Read")
			part:SetAttribute(Interactable.AttributeName.PromptLabel, `Read {id}`)
			part:SetAttribute(Interactable.AttributeName.EvidenceId, id)
			props[id] = part
		end
		local ok, err = pcall(fn, props, looks)
		for id, part in pairs(props) do
			part:Destroy()
			looks[id]:Destroy()
		end
		if not ok then
			error(err, 0)
		end
	end

	local function say(player: any, choiceId: string)
		if not ConversationService.isTalking(player) then
			expect.truthy(ConversationService.begin(player, "WIT"))
		end
		expect.truthy(ConversationService.choose(player, choiceId))
	end

	t.test("a gated prop is held out of the world, where no client can see it", function()
		withProps(function(props, looks)
			local player = makePlayer()
			RevealService.refresh(player)
			expect.falsy(props["EV-PRINT"]:IsDescendantOf(workspace))
			expect.falsy(looks["EV-PRINT"]:IsDescendantOf(workspace))
			expect.truthy(props["EV-PRINT"]:IsDescendantOf(ServerStorage))
			expect.falsy(RevealService.isRevealed(player, "EV-PRINT"))
			expect.falsy(RevealService.isInWorld("EV-PRINT"))
		end)
	end)

	t.test("a prop without revealWhen is never touched", function()
		withProps(function(props)
			local player = makePlayer()
			RevealService.refresh(player)
			expect.equal(props["EV-OPEN"].Parent, propsFolder())
		end)
	end)

	t.test("it appears once its condition holds, back exactly where it was", function()
		withProps(function(props, looks)
			local player = makePlayer()
			RevealService.refresh(player)
			say(player, "offer")
			local newly = RevealService.refresh(player)
			expect.deepEqual(newly, { "EV-PRINT" })
			expect.equal(props["EV-PRINT"].Parent, propsFolder())
			expect.equal(looks["EV-PRINT"].Parent, propsFolder())
			expect.truthy(RevealService.isRevealed(player, "EV-PRINT"))
			expect.truthy(CollectionService:HasTag(props["EV-PRINT"], Interactable.TAG))
			-- Only that one: the flag-gated prop is still held.
			expect.falsy(props["EV-FLAGGED"]:IsDescendantOf(workspace))
		end)
	end)

	t.test("refresh reports a reveal once, and is safe to repeat", function()
		withProps(function(props)
			local player = makePlayer()
			say(player, "offer")
			expect.equal(#RevealService.refresh(player), 1)
			expect.equal(#RevealService.refresh(player), 0)
			expect.equal(props["EV-PRINT"].Parent, propsFolder())
		end)
	end)

	t.test("a dialogue flag reveals too, and the reveal holds after the flag is cleared", function()
		withProps(function(props)
			local player = makePlayer()
			say(player, "ask")
			RevealService.refresh(player)
			expect.truthy(props["EV-FLAGGED"]:IsDescendantOf(workspace))
			say(player, "forget")
			local data = PlayerDataService.get(player) :: any
			expect.falsy(data.caseState.dialogueFlags.asked)
			RevealService.refresh(player)
			expect.truthy(props["EV-FLAGGED"]:IsDescendantOf(workspace))
		end)
	end)

	t.test("a replay (a fresh case state) holds the prop back again", function()
		withProps(function(props)
			local player = makePlayer()
			say(player, "offer")
			RevealService.refresh(player)
			expect.truthy(props["EV-PRINT"]:IsDescendantOf(workspace))
			ConversationService.leave(player)
			PlayerDataService.clear(player)
			PlayerDataService.initialize(player, CASE_ID)
			RevealService.refresh(player)
			expect.falsy(props["EV-PRINT"]:IsDescendantOf(workspace))
			expect.falsy(RevealService.isRevealed(player, "EV-PRINT"))
		end)
	end)

	t.test("a held prop can't be used: the server refuses anything outside the world", function()
		withProps(function(props)
			local player = makePlayer()
			RevealService.refresh(player)
			InteractionService.handleRequest(player, props["EV-PRINT"], "Read")
			expect.falsy(EvidenceService.isDiscovered(player, "EV-PRINT"))
		end)
	end)

	t.test("only the prop is gated: the evidence can still be reached another way", function()
		withProps(function(props)
			local player = makePlayer()
			RevealService.refresh(player)
			expect.truthy(EvidenceService.discover(player, "EV-PRINT"))
			-- The prop keeps to its own condition.
			RevealService.refresh(player)
			expect.falsy(props["EV-PRINT"]:IsDescendantOf(workspace))
		end)
	end)

	t.test("holdAll holds back every gated prop of a case", function()
		withProps(function(props)
			expect.equal(RevealService.holdAll(CASE_ID), 4) -- two parts, two looks
			expect.falsy(props["EV-PRINT"]:IsDescendantOf(workspace))
			expect.falsy(props["EV-FLAGGED"]:IsDescendantOf(workspace))
			expect.truthy(props["EV-OPEN"]:IsDescendantOf(workspace))
			expect.equal(RevealService.holdAll(CASE_ID), 0) -- already held
		end)
	end)

	t.test("CASE-001 gates exactly one prop: the badge log's printout, held until Sam prints it", function()
		local evidenceList = (CaseRegistry.get("CASE-001") :: any).evidence
		local gated = {}
		for _, evidence in ipairs(evidenceList) do
			local placement = evidence.propPlacement
			if placement and placement.revealWhen then
				table.insert(gated, evidence.id)
				expect.deepEqual(placement.revealWhen, { { kind = "Statement", id = "STMT-SUS-003-BADGE" } })
			end
		end
		expect.deepEqual(gated, { "EV-004" })
		RevealService.holdAll("CASE-001")
		for _, evidence in ipairs(evidenceList) do
			if evidence.propPlacement then
				expect.equal(RevealService.isInWorld(evidence.id), evidence.id ~= "EV-004")
			end
		end
	end)

	t.test("conditionsHold: every condition must hold; negate inverts; no data holds nothing", function()
		local player = makePlayer()
		expect.truthy(ConversationService.conditionsHold(player, nil))
		expect.truthy(ConversationService.conditionsHold(player, {}))
		expect.falsy(ConversationService.conditionsHold(player, { { kind = "Statement", id = "STMT-OFFER" } }))
		expect.truthy(
			ConversationService.conditionsHold(player, { { kind = "Statement", id = "STMT-OFFER", negate = true } })
		)
		say(player, "offer")
		expect.truthy(ConversationService.conditionsHold(player, { { kind = "Statement", id = "STMT-OFFER" } }))
		expect.falsy(ConversationService.conditionsHold(player, {
			{ kind = "Statement", id = "STMT-OFFER" },
			{ kind = "Flag", id = "asked" },
		}))
		expect.falsy(ConversationService.conditionsHold({ UserId = t.nextUserId(), Name = "Nobody" } :: any, {}))
	end)
end
