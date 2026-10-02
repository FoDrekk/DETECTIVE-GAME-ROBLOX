--[[
	Entry: a scripted end-to-end playthrough of CASE-001.

	Runs the real server bootstrap and the real client LocalScript together
	(one shared process: RemoteEvents deliver server -> client and back), then
	plays the case the way a player does: stands next to things, checks the
	on-screen prompt is the thing it means to use, presses the interact key,
	reads what the UI shows, clicks dialogue choices, reorders the timeline
	with its buttons and clicks ACCUSE. Nothing is called on the server
	directly. Prints a transcript and a PASS/FAIL line per step.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")

local failures = 0
local steps = 0
local transcript: { string } = {}

local function check(ok: any, label: string)
	steps += 1
	if ok then
		print("[PASS] " .. label)
	else
		failures += 1
		print("[FAIL] " .. label)
	end
	return ok
end

local function say(line: string)
	table.insert(transcript, line)
end

-- Boot: server first (as in Studio), then a player joins and the client
-- script starts on their machine.
Shim.runScript(ServerScriptService:WaitForChild("Server"))
Shim.settle(2)
local player = Shim.addPlayer("Detective")
player:LoadCharacter()
Shim.settle(1)
Shim.isServer = false
Shim.localPlayer = player
local clientScript = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
Shim.runScript(clientScript)
Shim.advance(2)

local Client = clientScript
local InputController = Shim.require(Client:WaitForChild("InputController"))
local InteractionController = Shim.require(Client:WaitForChild("InteractionController"))
local DialogueView = Shim.require(Client:WaitForChild("DialogueView"))
local EvidencePanel = Shim.require(Client:WaitForChild("EvidencePanel"))
local TitleScreenView = Shim.require(Client:WaitForChild("TitleScreenView"))
local playerGui = player:WaitForChild("PlayerGui")

-- Everything the server sent this client, by remote name.
local function lastSent(remote: string): { any }?
	for i = #Shim.remoteLog, 1, -1 do
		local entry = Shim.remoteLog[i]
		if entry.remote == remote then
			return entry.args
		end
	end
	return nil
end
local function sentCount(remote: string): number
	local n = 0
	for _, entry in ipairs(Shim.remoteLog) do
		if entry.remote == remote then
			n += 1
		end
	end
	return n
end

-- Record every dialogue line the client is sent.
Shim.clientHandlers.DialogueUpdated = function(_, payload)
	if payload.active then
		if payload.prompt then
			say(`    > YOU: {payload.prompt}`)
		end
		if payload.present then
			-- The line is held while the investigator picks what to show.
			say(`    ({payload.present.prompt} {#payload.present.options} items found)`)
			return
		end
		if payload.presented then
			say(`    [shows: {payload.presented}]`)
		end
		local who = if payload.isPlayer then "YOU" else payload.speaker
		say(`    {who}: {payload.text}`)
		if payload.unlockedStatement then
			say(`      [statement recorded: {payload.unlockedStatement.label}]`)
		end
	end
end
Shim.clientHandlers.EvidenceDiscovered = function(_, payload)
	local ev = payload.evidence
	if not payload.revisited then
		say(`  [EVIDENCE] {ev.name}: {ev.details or ev.description}`)
	end
end
Shim.clientHandlers.ObservationShown = function(_, payload)
	say(`  [LOOK] {payload.title}: {payload.body}`)
end
Shim.clientHandlers.ReasoningUpdated = function(_, payload)
	for _, c in ipairs(payload.contradictions) do
		say(`  [CONTRADICTION] {c.label}`)
	end
	for _, d in ipairs(payload.deductions) do
		say(`  [DEDUCTION] {d.label}`)
	end
end
Shim.clientHandlers.ObjectiveUpdated = function(_, payload)
	if not payload.objective.completed then
		say(`  [OBJECTIVE] {payload.objective.title}: {payload.objective.description}`)
	end
end

local function pressInteract()
	InputController.invoke("Interact")
	Shim.advance(0.5)
end

local camera = workspace.CurrentCamera :: Camera

-- Phase 5.5: the case opens on its intro, not a briefing screen. `expectFrom` is
-- the shot it should start at (the top on a first run, the lift doors on a
-- replay). Lets it run for `watch` seconds, then either holds E to skip or waits
-- for the end, and checks the investigation is handed back cleanly.
local function throughIntro(label: string, expectFrom: string, watch: number, skip: boolean)
	local sent = lastSent("CutsceneUpdated")
	local payload = sent and sent[1]
	check(payload and payload.active and payload.id == "CUT-INTRO" and payload.isIntro, `{label}: the intro plays`)
	check(payload and payload.shots and payload.shots[1].id == expectFrom, `{label}: it starts at {expectFrom}`)
	local discovered = sentCount("EvidenceDiscovered")
	Shim.advance(watch)
	check(camera.CameraType == Enum.CameraType.Scriptable, `{label}: the scene has the camera`)
	check(InteractionController.getCurrent() == nil, `{label}: nothing can be examined during the scene`)
	if skip then
		-- A tap does nothing; a held E skips.
		InputController.invoke("Interact")
		Shim.advance(0.3)
		InputController.release("Interact")
		Shim.advance(0.5)
		check(lastSent("CutsceneUpdated")[1].active, `{label}: a tap doesn't skip the intro`)
		InputController.invoke("Interact")
		Shim.advance(1.6)
		InputController.release("Interact")
	else
		local total = 0
		for _, shot in ipairs(payload and payload.shots or {}) do
			total += shot.duration
		end
		Shim.advance(total - watch + 1)
	end
	Shim.advance(2)
	local ended = lastSent("CutsceneUpdated")
	check(ended and ended[1].active == false and ended[1].id == "CUT-INTRO", `{label}: the server ends the intro`)
	check(sentCount("EvidenceDiscovered") == discovered, `{label}: the intro hands over no evidence`)
	check(camera.CameraType == Enum.CameraType.Custom, `{label}: the camera is back with the player`)
	check(workspace:FindFirstChild("MysteryCase_CutsceneSets") == nil, `{label}: the scene's sets are taken down`)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	check(head and head.LocalTransparencyModifier == 0, `{label}: the avatar is visible again`)
end

-- Title screen, then the intro.
check(TitleScreenView.isOpen(), "title screen is showing on join")
check(playerGui:FindFirstChild("MysteryCase_Briefing", true) == nil
	or not (playerGui:FindFirstChild("MysteryCase_Briefing", true) :: ScreenGui).Enabled, "no briefing screen for CASE-001")
pressInteract()
Shim.advance(1.5) -- the title fades to black, then out
check(not TitleScreenView.isOpen(), "E dismisses the title screen")
local phase = lastSent("PhaseChanged")
check(phase and phase[1] == "Investigation", "Play goes straight into the investigation")
do
	-- The dispatch is on the radio a little way in: subtitles show under the bars.
	local sent = lastSent("CutsceneUpdated")
	local seconds = 0
	for _, shot in ipairs(sent and sent[1].shots or {}) do
		if shot.id == "CITY-DISPATCH" then
			break
		end
		seconds += shot.duration
	end
	Shim.advance(seconds + 1)
	local line = playerGui:FindFirstChild("MysteryCase_Cutscene", true)
	line = line and line:FindFirstChild("Line", true)
	check(line and string.find((line :: TextLabel).Text, "Wisma Delima", 1, true), "the dispatch is subtitled")
end
throughIntro("first run", "BED-WIDE", 2, true)

-- Every set a scene can be framed in builds, does each action the config says
-- it knows, stands the investigator's double on its floor, and leaves nothing
-- behind (the lift's hidden office parts shown again).
do
	local Config = Shim.require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
	local CutsceneSets = Shim.require(Client:WaitForChild("CutsceneSets"))
	for _, name in ipairs(CutsceneSets.names()) do
		local handle = CutsceneSets.enter(name)
		if check(handle, `set {name} builds`) then
			for _, action in ipairs(Config.Cutscene.Sets[name].actions) do
				local ok, err = pcall(handle.act, action, nil)
				check(ok, `set {name} does {action}` .. (if ok then "" else `: {err}`))
			end
			Shim.advance(4)
			local folder = workspace:FindFirstChild("MysteryCase_CutsceneSets")
			-- A dressed set is built round its own origin, far from the office: a
			-- part placed in world coordinates by mistake would stand in the office.
			if not CutsceneSets.isWorld(name) and folder and folder:FindFirstChild(name) then
				local strays = 0
				for _, d in ipairs(folder[name]:GetDescendants()) do
					if d:IsA("BasePart") and math.abs(d.Position.X) < 60 and math.abs(d.Position.Z) < 60 then
						strays += 1
					end
				end
				check(strays == 0, `set {name}: nothing stands in the office ({strays} parts)`)
			end
			local double = folder and folder:FindFirstChild(name) and folder[name]:FindFirstChild("Double")
			-- The mirror's double stands in the reflection, the car's sits: only the
			-- standing ones on a set's own floor are checked here.
			if double and (name == "Lobby" or name == "Forecourt") then
				local lowest = math.huge
				for _, d in ipairs(double:GetDescendants()) do
					if d:IsA("BasePart") then
						lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
					end
				end
				check(math.abs(lowest - CutsceneSets.origin(name).Y) < 0.3, `set {name}: the double stands on the floor`)
			end
		end
	end
	CutsceneSets.leaveAll()
	check(workspace:FindFirstChild("MysteryCase_CutsceneSets") == nil, "sets: all taken down")
	local hidden = 0
	for _, d in ipairs(workspace:WaitForChild("Office"):GetDescendants()) do
		if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 0 then
			hidden += 1
		end
	end
	check(hidden == 0, "sets: no office part left hidden")
end

--------------------------------------------------------------------------
-- Moving around
--------------------------------------------------------------------------

local function character(): Model
	return player.Character :: Model
end

local function findInteractable(match: (Instance) -> boolean): Instance?
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if match(inst) then
			return inst
		end
	end
	return nil
end

local function partOf(inst: Instance): BasePart
	return if inst:IsA("BasePart") then inst else inst:FindFirstChildWhichIsA("BasePart") :: BasePart
end

-- Stand beside `target` (trying a ring of spots) until the on-screen prompt
-- picks it. Fails if no spot within reach makes it the prompt.
local function approach(target: Instance, label: string): boolean
	local part = partOf(target)
	local center = part.Position
	local floorY = 3
	for _, radius in ipairs({ 2.5, 3.5, 1.8, 5 }) do
		for step = 0, 15 do
			local angle = step / 16 * math.pi * 2
			local spot = Vector3.new(center.X + math.cos(angle) * radius, floorY, center.Z + math.sin(angle) * radius)
			local look = Vector3.new(center.X, floorY, center.Z)
			character():PivotTo(CFrame.lookAt(spot, look))
			workspace.CurrentCamera.CFrame = CFrame.lookAt(spot + Vector3.new(0, 2, 0) - (look - spot).Unit * 6, center)
			Shim.advance(0.3)
			local current = InteractionController.getCurrent()
			if current and current.instance == target then
				return true
			end
		end
	end
	check(false, `the prompt can target {label}`)
	return false
end

local function examine(target: Instance, label: string): boolean
	if not approach(target, label) then
		return false
	end
	local before = #Shim.remoteLog
	pressInteract()
	local answered = #Shim.remoteLog > before
	check(answered, `examining {label} gets a response`)
	if EvidencePanel.isOpen() then
		pressInteract() -- [E] Continue
		check(not EvidencePanel.isOpen(), `{label}: the readout closes with E`)
	end
	Shim.advance(0.5)
	return answered
end

local function evidenceProp(id: string): Instance
	local inst = findInteractable(function(i)
		return i:GetAttribute("EvidenceId") == id
	end)
	assert(inst, `no interactable carries {id}`)
	return inst :: Instance
end

local function named(name: string): Instance?
	return findInteractable(function(i)
		return i.Name == name
	end)
end

local function suspect(id: string): Instance
	local inst = findInteractable(function(i)
		return i:GetAttribute("SuspectId") == id
	end)
	assert(inst, `no NPC for {id}`)
	return inst :: Instance
end

--------------------------------------------------------------------------
-- Conversations through the dialogue UI
--------------------------------------------------------------------------

local function choiceButtons(): { TextButton }
	local list = playerGui:FindFirstChild("MysteryCase_Dialogue")
	local inner = list and list:FindFirstChild("Inner", true)
	local out = {}
	if inner and inner.Visible then
		for _, child in ipairs(inner:GetChildren()) do
			if child:IsA("TextButton") then
				table.insert(out, child)
			end
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end

local function buttonText(button: TextButton): string
	local label = button:FindFirstChild("Label") :: TextLabel
	return label.Text
end

-- Wait out the typewriter; the choices appear once the line has typed.
local function settleLine()
	for _ = 1, 40 do
		Shim.advance(0.25)
		if not DialogueView.isOpen() or #choiceButtons() > 0 or not DialogueView.awaitingChoice() then
			break
		end
	end
	Shim.advance(0.5)
end

-- Talk to a character and ask the questions whose text contains each of
-- `asks`, in order, continuing through lines with E. Then leave with the
-- choice containing `leave` (or let the conversation end).
local function converse(id: string, label: string, asks: { string }, leave: string?)
	say(`\n== {label} ==`)
	if not approach(suspect(id), label) then
		return
	end
	pressInteract()
	check(DialogueView.isOpen(), `talking to {label} opens the dialogue`)
	local queue = table.clone(asks)
	if leave then
		table.insert(queue, leave)
	end
	for _ = 1, 80 do
		if not DialogueView.isOpen() then
			break
		end
		settleLine()
		local buttons = choiceButtons()
		if #buttons > 0 then
			local want = queue[1]
			if not want then
				check(false, `{label}: conversation ended with choices still on screen`)
				InputController.invoke("Close")
				break
			end
			local clicked = false
			for _, button in ipairs(buttons) do
				if string.find(buttonText(button), want, 1, true) then
					Shim.fireSignal(button.Activated)
					clicked = true
					break
				end
			end
			local offered = {}
			for _, button in ipairs(buttons) do
				table.insert(offered, buttonText(button))
			end
			if not check(clicked, `{label}: "{want}" is on offer`) then
				say("      offered: " .. table.concat(offered, " | "))
				InputController.invoke("Close")
				break
			end
			table.remove(queue, 1)
			Shim.advance(0.3)
		else
			-- First press finishes typing (if still typing), second continues.
			pressInteract()
			if DialogueView.isOpen() and not DialogueView.awaitingChoice() then
				pressInteract()
			end
		end
	end
	Shim.advance(1)
	check(not DialogueView.isOpen(), `{label}: the conversation closes`)
end

local function objective(): string?
	local sent = lastSent("ObjectiveUpdated")
	if not sent then
		return nil
	end
	local payload = sent[1]
	return if payload.objective.completed then "(completed) " .. payload.objective.id else payload.objective.id
end

local function reasoning(): any
	local sent = lastSent("ReasoningUpdated")
	return sent and sent[1]
end

local function hasFact(kind: string, label: string): boolean
	local payload = reasoning()
	if not payload then
		return false
	end
	for _, entry in ipairs(payload[kind]) do
		if entry.label == label then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------
-- The case
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- M9: the case file and the accusation, through their own buttons
--------------------------------------------------------------------------

local function gui(name: string): Instance?
	return playerGui:FindFirstChild(name)
end

local function find(root: Instance?, name: string): Instance?
	return if root then root:FindFirstChild(name, true) else nil
end

local function click(button: Instance?, label: string): boolean
	if check(button and button:IsA("GuiButton"), `{label}: the button is there`) then
		Shim.fireSignal((button :: GuiButton).Activated)
		Shim.advance(0.5)
		return true
	end
	return false
end

local function withCaseFile(fn: (Instance) -> ())
	InputController.invoke("CaseFile")
	Shim.advance(0.8)
	local file = gui("MysteryCase_CaseFile") :: Instance
	fn(file)
	InputController.invoke("CaseFile")
	Shim.advance(0.5)
end

local function feedback(): string
	local label = find(gui("MysteryCase_CaseFile"), "Feedback")
	return if label and label:IsA("TextLabel") then label.Text else ""
end

-- Set two facts side by side and press "These don't add up".
local function claimPair(a: string, b: string, label: string): string
	local result = ""
	withCaseFile(function(file)
		click(find(file, a), `{label}: select {a}`)
		click(find(file, b), `{label}: select {b}`)
		click(find(file, "Claim"), `{label}: claim`)
		Shim.advance(1)
		result = feedback()
	end)
	say(`  [CASE FILE] {label}: {result}`)
	return result
end

local function answerQuestion(deductionId: string, optionId: string, label: string): string
	local result = ""
	withCaseFile(function(file)
		local question = find(file, "Question_" .. deductionId)
		if check(question, `{label}: the question is open`) then
			click(find(question, "Option_" .. optionId), `{label}: answer`)
			Shim.advance(1)
			result = feedback()
		end
	end)
	say(`  [CASE FILE] {label}: {result}`)
	return result
end

local function isOpenQuestion(deductionId: string): boolean
	local payload = reasoning()
	for _, question in ipairs(payload and payload.openQuestions or {}) do
		if question.id == deductionId then
			return true
		end
	end
	return false
end

local function accuse(accusationId: string, motiveId: string, proofId: string)
	InputController.invoke("Accuse")
	Shim.advance(1)
	local accuseGui = gui("MysteryCase_Accusation")
	if check(accuseGui and (accuseGui :: ScreenGui).Enabled, "Q opens the accusation") then
		click(find(accuseGui, "Suspect_" .. accusationId), "accusation: who")
		click(find(accuseGui, "Motive_" .. motiveId), "accusation: why")
		click(find(accuseGui, "Proof_" .. proofId), "accusation: proof")
		click(find(accuseGui, "Accuse"), "accusation: ACCUSE")
	end
	Shim.advance(3)
end

local function closingText(name: string): string
	local label = find(gui("MysteryCase_CaseClosed"), name)
	return if label and label:IsA("TextLabel") then label.Text else ""
end

--------------------------------------------------------------------------
-- The case: first run, solved properly
--------------------------------------------------------------------------

say("== The lobby ==")
check(objective() == "OBJ-000", "first objective: the night guard")
-- Phase 5.3: the badge log is only on the counter once Sam has printed it.
check(
	not evidenceProp("EV-004"):IsDescendantOf(workspace),
	"the badge log isn't on the counter before Sam prints it"
)
converse(
	"SUS-003",
	"Sam Gurung",
	{ "You found him?", "anyone else", "Has anyone been in his office", "get in after hours", "cameras" },
	"That's all"
)
Shim.advance(3)
check(objective() == "OBJ-001", "talking to Sam moves on to Daniel's office")
check(evidenceProp("EV-004"):IsDescendantOf(workspace), "once Sam has printed it, the badge log is on the counter")

say("\n== Daniel's office ==")
examine(evidenceProp("EV-001"), "the phone")
examine(evidenceProp("EV-002"), "the laptop")
examine(evidenceProp("EV-003"), "the agenda")
examine(evidenceProp("EV-006"), "the second cup")
for _, flavour in ipairs({ "CoffeeCup", "Pen", "DeskDrawer" }) do
	local inst = named(flavour)
	if check(inst, `{flavour} exists`) then
		examine(inst :: Instance, flavour)
	end
end
Shim.advance(3)
check(objective() == "OBJ-002", "searching the office moves on to the suspects")

-- Phase 5.3: three optional finds. The ambulance tag by the numbered marker,
-- and the two records-room objects that used to carry only flavour text.
say("\n== The scene, and the records room ==")
examine(evidenceProp("EV-008"), "the ambulance tag")
local shelves = named("Shelf_Frame")
local cabinet = named("FileCabinet_1")
if check(shelves and cabinet, "the records room shelves and file cabinet are in the world") then
	examine(shelves :: Instance, "the shelves")
	examine(cabinet :: Instance, "the file cabinet")
end
check(sentCount("EvidenceDiscovered") >= 4, "the marked floor, the photo and the drawer were all found by examining")
check(
	string.find(
		answerQuestion("DEDUCT-005", "struggle", "the credenza"),
		"BY THE CREDENZA",
		1,
		true
	) ~= nil,
	"answering the credenza question: 'By the Credenza'"
)

say("\n== Around the floor ==")
examine(evidenceProp("EV-005"), "the coffee machine")
Shim.advance(1)
check(not hasFact("deductions", "Daniel Wasn't Alone"), "nothing concludes itself: no deduction yet")
check(isOpenQuestion("DEDUCT-003") and isOpenQuestion("DEDUCT-002"), "two questions open in the case file")
-- Re-examining a found clue re-opens it quietly.
local discoveries = sentCount("EvidenceDiscovered")
examine(evidenceProp("EV-005"), "the coffee machine again")
local again = lastSent("EvidenceDiscovered")
check(
	sentCount("EvidenceDiscovered") == discoveries + 1 and again and again[1].revisited,
	"a found clue re-opens as 'on file'"
)
check(
	string.find(answerQuestion("DEDUCT-003", "visitor", "the two espressos"), "DANIEL WASN'T ALONE", 1, true) ~= nil,
	"answering the espresso question: 'Daniel Wasn't Alone'"
)
check(
	string.find(answerQuestion("DEDUCT-002", "dissolve", "the midnight meeting"), "ENDING THE PARTNERSHIP", 1, true)
		~= nil,
	"answering the meeting question: 'Daniel Was Ending the Partnership'"
)
check(
	string.find(answerQuestion("DEDUCT-006", "leverage", "why midnight"), "WHY IT COULDN'T WAIT", 1, true) ~= nil,
	"answering why midnight: 'Why It Couldn't Wait'"
)

say("\n== Reception ==")
examine(evidenceProp("EV-004"), "the badge log")
examine(evidenceProp("EV-007"), "the camera monitor")

converse(
	"SUS-002",
	"Victor Lim",
	{ "When did you leave", "confirm", "dissolving", "spoken to Meera", "Take a look", "Camera Monitor" },
	"That's all"
)
Shim.advance(1)
check(hasFact("contradictions", "The Footage"), "showing Victor his own note: 'The Footage'")
converse(
	"SUS-001",
	"Meera Rozario",
	{ "sorry", "Where were you", "ending the partnership", "about Victor" },
	"let you be"
)
Shim.advance(3)
check(objective() == "OBJ-003", "both spoken to: test Victor's story")
-- Phase 5.3: Victor's own words against Sam's account of the tape.
check(not hasFact("contradictions", "Nobody Told Him"), "the slip isn't announced: it has to be noticed")
check(
	string.find(
		claimPair("Fact_Statement_STMT-SUS-002-MEERA", "Fact_Statement_STMT-SUS-003-TAPE", "Victor on Meera × Sam's tape"),
		"NOBODY TOLD HIM",
		1,
		true
	) ~= nil,
	"pairing Victor's words with Sam's tape statement: 'Nobody Told Him'"
)
Shim.advance(2.5)
check(not hasFact("contradictions", "Half Past Ten"), "the badge log alone proves nothing")
check(not hasFact("contradictions", "Meera's Missed Call"), "the phone alone proves nothing")
check(
	string.find(
		claimPair("Fact_Statement_STMT-SUS-002-ALIBI", "Fact_Evidence_EV-004", "Victor's 'half ten' × the badge log"),
		"HALF PAST TEN",
		1,
		true
	) ~= nil,
	"setting his alibi against the badge log: 'Half Past Ten'"
)
Shim.advance(3)
check(objective() == "OBJ-004", "then: the call nobody answered")

-- Meera, shown the phone and pressed too hard: she shuts down, then an
-- apology.
converse("SUS-001", "Meera Rozario (pressed)", { "look at something", "Phone", "Why lie" }, nil)
check(hasFact("contradictions", "Meera's Missed Call"), "showing Meera the phone: 'Meera's Missed Call'")
-- Phase 5.4, route A: once she has admitted the call (and isn't upset), she
-- opens his phone for the investigator, and both clues are handed over.
local handedOver = sentCount("EvidenceDiscovered")
converse(
	"SUS-001",
	"Meera Rozario (again)",
	{ "I'm sorry. I need to understand", "open his phone" },
	"let you be"
)
Shim.advance(2)
check(sentCount("EvidenceDiscovered") == handedOver + 2, "route A: she opens his phone, and the message and the watch data arrive")
check(hasFact("statements", "Coming Home"), "route A: 'Coming Home' is on the record")
check(
	string.find(answerQuestion("DEDUCT-001", "victor", "who came back"), "VICTOR CAME BACK", 1, true) ~= nil,
	"answering who came back: 'Victor Came Back'"
)
Shim.advance(3)
check(objective() == "OBJ-005", "then: the last ten minutes")

converse("SUS-002", "Victor Lim (the log)", { "Take a look", "Badge Log" }, "That's all")
converse("SUS-002", "Victor Lim (the phone)", { "Take a look", "Phone" }, nil)
Shim.advance(2)
check(hasFact("contradictions", "A Call That Never Connected"), "showing him the phone: 'A Call That Never Connected'")
check(
	string.find(
		claimPair("Fact_Statement_STMT-SUS-002-REVISED", "Fact_Evidence_EV-012", "Victor's story × the watch"),
		"STILL IN THE BUILDING",
		1,
		true
	) ~= nil,
	"setting his revised story against the watch data: 'Still in the Building'"
)
Shim.advance(2.5)
check(
	string.find(answerQuestion("DEDUCT-004", "after", "when he left"), "THERE AT THE END", 1, true) ~= nil,
	"answering when he left: 'Victor Was There at the End'"
)
Shim.advance(3)
check(objective() == "OBJ-006", "confrontation done: reconstruct the night")

--------------------------------------------------------------------------
-- Timeline, through its buttons
--------------------------------------------------------------------------

say("\n== Timeline ==")
InputController.invoke("Timeline")
Shim.advance(1)
local timelineGui = playerGui:FindFirstChild("MysteryCase_Timeline")
local canonical = {
	"TIMELINE-005",
	"TIMELINE-001",
	"TIMELINE-002",
	"TIMELINE-006",
	"TIMELINE-007",
	"TIMELINE-004",
	"TIMELINE-003",
}
local function rowOrder(): { string }
	local rows = {}
	for _, d in ipairs((timelineGui :: Instance):GetDescendants()) do
		if d:IsA("Frame") and string.sub(d.Name, 1, 6) == "Event_" then
			table.insert(rows, d)
		end
	end
	table.sort(rows, function(a, b)
		return a.Position.Y.Offset < b.Position.Y.Offset
	end)
	local ids = {}
	for _, row in ipairs(rows) do
		table.insert(ids, string.sub(row.Name, 7))
	end
	return ids, rows
end
if check(timelineGui, "the timeline opens with T") then
	for target, id in ipairs(canonical) do
		for _ = 1, 10 do
			local ids, rows = rowOrder()
			local at = table.find(ids, id)
			if not at or at <= target then
				break
			end
			local up = rows[at]:FindFirstChild("MoveUp")
			Shim.fireSignal(up.Activated)
			Shim.advance(0.2)
		end
	end
	local ordered = rowOrder()
	check(table.concat(ordered, ",") == table.concat(canonical, ","), "rows reordered into the night's order")
	for _, d in ipairs((timelineGui :: Instance):GetDescendants()) do
		if d:IsA("TextButton") and d.Name ~= "MoveUp" and d.Name ~= "MoveDown" and d.Visible then
			Shim.fireSignal(d.Activated)
		end
	end
	Shim.advance(2)
	local tl = lastSent("TimelineUpdated")
	check(tl and tl[1].established, "the server accepts the reconstructed timeline")
	InputController.invoke("Timeline")
	Shim.advance(1)
end

--------------------------------------------------------------------------
-- Accusation and the ending
--------------------------------------------------------------------------

say("\n== Accusation ==")
-- Phase 5.3: the new motive (what Daniel found in the invoices) and the new
-- proof (the slip), chosen from what this run established.
local closedBefore = sentCount("CaseClosedSummary")
accuse("ACC-001", "DEDUCT-006", "CONTRA-005")

-- Phase 5.4: a Solved close plays the dawn outro first; the summary waits.
say("\n== The dawn outro ==")
local outro = lastSent("CutsceneUpdated")
check(outro and outro[1].active and outro[1].id == "CUT-DAWN-HOME", "a solved case with the message read plays the phone's dawn outro")
check(sentCount("CaseClosedSummary") == closedBefore, "the closing summary is held back while the outro plays")
local closedPhase0 = lastSent("PhaseChanged")
check(closedPhase0 and closedPhase0[1] == "CaseClosed", "the case is closed while the outro plays")
if outro and outro[1].shots then
	local caption = outro[1].shots[2].lines[1].text
	say("  [OUTRO] " .. outro[1].shots[1].lines[1].text .. " / " .. caption)
	check(caption == "She turns it face up.", "the second shot's caption is the phone's")
end
-- The investigator is behind the camera, not in the shot.
local head = character():FindFirstChild("Head") :: BasePart
check(head and head.LocalTransparencyModifier == 1, "the investigator's avatar is out of the outro's shots")
Shim.advance(20) -- the scene runs its 18 seconds
check(head and head.LocalTransparencyModifier == 0, "the avatar is back once the outro is over")
local outroOver = lastSent("CutsceneUpdated")
check(outroOver and outroOver[1].active == false, "the outro ends by itself")
check(sentCount("CaseClosedSummary") == closedBefore + 1, "the closing summary follows the outro")
local summary = lastSent("CaseClosedSummary")
local verdict = summary and summary[1].verdict
check(verdict and verdict.grade == "Solved", "the verdict: solved")
check(summary and summary[1].mistakes == 0, "no missteps on the clean run")
if verdict then
	say(`  [VERDICT] {verdict.grade}: {verdict.epilogue or ""}`)
	say("  [WHAT HAPPENED] " .. verdict.reveal)
end
local closedPhase = lastSent("PhaseChanged")
check(closedPhase and closedPhase[1] == "CaseClosed", "phase CaseClosed")
Shim.advance(3)
check(closingText("Title") == "Case solved.", "the closing screen: 'Case solved.'")
check(
	string.find(closingText("Epilogue"), "turns it face up", 1, true) ~= nil
		and string.find(closingText("Epilogue"), "word for word", 1, true) ~= nil,
	"the closing screen tells what happened next: the fullest ending"
)
-- Phase 3 (R6): objectives read as leads, not a score.
check(
	string.find(closingText("Stats"), "Leads followed", 1, true) ~= nil
		and string.find(closingText("Stats"), "Objectives", 1, true) == nil,
	"the closing stats count leads followed, not objectives"
)
-- Phase 3 (R7): this run reconstructed the timeline, so the closing stats
-- reward it.
check(
	string.find(closingText("Stats"), "Timeline reconstructed", 1, true) ~= nil,
	"the closing stats credit reconstructing the timeline"
)
-- Phase 3 (R1): the fixed-size panels shrink to fit a phone held sideways.
do
	local function fitScale(guiName: string, panelName: string): number?
		local panel = find(gui(guiName), panelName)
		local scale = panel and panel:FindFirstChildOfClass("UIScale")
		return scale and (scale :: UIScale).Scale
	end
	check(fitScale("MysteryCase_CaseClosed", "CaseClosed") == 1, "on a desktop screen the closing panel is full size")
	camera.ViewportSize = Vector2.new(844, 390)
	Shim.advance(0.1)
	local closed = fitScale("MysteryCase_CaseClosed", "CaseClosed")
	local timeline = fitScale("MysteryCase_Timeline", "Timeline")
	local evidence = fitScale("MysteryCase_Evidence", "EvidencePanel")
	say(`  [FIT 844x390] closing {closed} / timeline {timeline} / evidence {evidence}`)
	check(
		closed and closed * 580 <= 390 - 40 and timeline and timeline * 500 <= 390 - 40 and evidence and evidence * 310 <= 390 - 40,
		"on a phone in landscape the closing, timeline and evidence panels fit the screen"
	)
	camera.ViewportSize = Vector2.new(1280, 720)
	Shim.advance(0.1)
	check(fitScale("MysteryCase_CaseClosed", "CaseClosed") == 1, "back on a desktop screen, full size again")
end

-- Investigate again: a clean second run. The intro replays from the lift doors.
pressInteract()
Shim.advance(2)
local replayPhase = lastSent("PhaseChanged")
check(replayPhase and replayPhase[1] == "Investigation", "E on the closing screen starts the investigation again")
throughIntro("replay", "LIFT-OPEN", 3, false)
-- Phase 3 (R3): nothing from the solved run carries into the second.
do
	local fresh = reasoning()
	check(
		fresh and #fresh.statements == 0 and #fresh.contradictions == 0 and #fresh.deductions == 0 and #fresh.evidence == 0,
		"the replay starts with an empty case file"
	)
	check(objective() == "OBJ-000", "the replay starts at the first objective")
	check(
		not evidenceProp("EV-004"):IsDescendantOf(workspace),
		"the replay holds the badge log's printout back again"
	)
	check(
		not evidenceProp("EV-011"):IsDescendantOf(workspace),
		"the replay keeps the phone's lit screen off again"
	)
	local accusationFresh = lastSent("AccusationUpdated")
	check(accusationFresh and not accusationFresh[1].open, "the replay starts with accusing closed")
	local timelineFresh = lastSent("TimelineUpdated")
	check(
		timelineFresh and #timelineFresh[1].events == 0 and not timelineFresh[1].established,
		"the replay starts with an empty timeline"
	)
end

--------------------------------------------------------------------------
-- Second run (Phase 5.4, route B): harsh with Meera and never thawed, the
-- phone's code worked out from the drawer photo, the message read alone
--------------------------------------------------------------------------

say("\n== Second run: the harsh road, and the code worked out ==")
converse(
	"SUS-003",
	"Sam Gurung (route B)",
	{ "You found him?", "Has anyone been in his office", "get in after hours" },
	"That's all"
)
Shim.advance(2)
examine(evidenceProp("EV-001"), "the phone")
examine(evidenceProp("EV-002"), "the laptop")
examine(evidenceProp("EV-003"), "the agenda")
examine(evidenceProp("EV-006"), "the second cup")
check(not isOpenQuestion("DEDUCT-007"), "with only the locked phone, the code isn't yet a question")
local drawer = named("DeskDrawer")
if check(drawer, "the desk drawer is in the world") then
	local before = sentCount("EvidenceDiscovered")
	examine(drawer :: Instance, "the desk drawer")
	local photo = lastSent("EvidenceDiscovered")
	check(
		sentCount("EvidenceDiscovered") == before + 1 and photo and photo[1].evidence.id == "EV-013",
		"the drawer gives the photo of Meera"
	)
end
check(isOpenQuestion("DEDUCT-007"), "the phone and the photo together open the question of the code")
check(
	not evidenceProp("EV-011"):IsDescendantOf(workspace),
	"the phone's screen is still dark before the code is worked out"
)
check(
	string.find(answerQuestion("DEDUCT-007", "wedding", "the phone's code"), "DANIEL'S CODE", 1, true) ~= nil,
	"answering the code: 'Daniel's Code'"
)
Shim.advance(2)
check(evidenceProp("EV-011"):IsDescendantOf(workspace), "the right code lights the phone's screen")
do
	local lit = evidenceProp("EV-011")
	check(lit:GetAttribute("PromptLabel") == "Read Unlocked Phone", "the lit screen's prompt: 'Read Unlocked Phone'")
	if approach(lit, "the phone's lit screen") then
		local found = sentCount("EvidenceDiscovered")
		pressInteract()
		check(sentCount("EvidenceDiscovered") == found + 2, "reading the message also hands over the watch data")
		local shown = find(gui("MysteryCase_Evidence"), "Related")
		check(
			shown and shown:IsA("TextLabel") and string.find(shown.Text, "ALSO ADDED  Watch Data", 1, true) ~= nil,
			"the readout says the watch data was also added"
		)
		if EvidencePanel.isOpen() then
			pressInteract()
		end
	end
end
Shim.advance(1)
examine(evidenceProp("EV-004"), "the badge log")
converse("SUS-002", "Victor Lim (route B, the log)", { "When did you leave", "Take a look", "Badge Log" }, "That's all")
-- Meera pressed too hard, and never thawed.
converse(
	"SUS-001",
	"Meera Rozario (route B, pressed)",
	{ "Where were you", "look at something", "Phone", "Why lie" },
	nil
)
Shim.advance(1)
check(not hasFact("statements", "Coming Home"), "she is still cold: nothing yet about coming home")
-- The message is the way back to her.
converse("SUS-001", "Meera Rozario (route B, the message)", { "He left a message for you" }, "let you be")
Shim.advance(2)
check(hasFact("statements", "Coming Home"), "route B: shown the message, she says it: 'Coming Home'")
-- Victor, and the watch.
converse("SUS-002", "Victor Lim (route B, the watch)", { "Take a look", "Watch Data" }, nil)
Shim.advance(2)
check(hasFact("contradictions", "Still in the Building"), "showing Victor the watch data: 'Still in the Building'")
answerQuestion("DEDUCT-002", "dissolve", "the midnight meeting")

say("\n== Accusation (route B) ==")
local closedBeforeB = sentCount("CaseClosedSummary")
accuse("ACC-001", "DEDUCT-002", "CONTRA-006")
outro = lastSent("CutsceneUpdated")
check(outro and outro[1].active and outro[1].id == "CUT-DAWN-HOME", "route B: the same dawn outro plays")
check(sentCount("CaseClosedSummary") == closedBeforeB, "route B: the summary waits for the outro")
-- Skipped with two presses: the first asks, the second skips.
pressInteract()
check(sentCount("CaseClosedSummary") == closedBeforeB, "one press only asks to skip")
pressInteract()
Shim.advance(1)
check(sentCount("CaseClosedSummary") == closedBeforeB + 1, "skipping the outro opens the summary")
summary = lastSent("CaseClosedSummary")
verdict = summary and summary[1].verdict
check(verdict and verdict.grade == "Solved", "route B: the verdict: solved")
check(
	verdict and string.find(verdict.epilogue or "", "turns it face up", 1, true) ~= nil,
	"route B reaches the same ending: she turned it face up"
)
Shim.advance(3)
check(closingText("Title") == "Case solved.", "route B: the closing screen: 'Case solved.'")
pressInteract()
Shim.advance(2)
throughIntro("third run", "LIFT-OPEN", 1, true)
check(
	not evidenceProp("EV-011"):IsDescendantOf(workspace) and not evidenceProp("EV-004"):IsDescendantOf(workspace),
	"the next run holds the lit screen and the printout back again"
)

--------------------------------------------------------------------------
-- Third run: sloppy, and an early accusation of the wrong person
--------------------------------------------------------------------------

say("\n== Third run: in a hurry ==")
converse("SUS-003", "Sam Gurung (second run)", {}, "That's all")
examine(evidenceProp("EV-001"), "the phone")
examine(evidenceProp("EV-002"), "the laptop")
examine(evidenceProp("EV-003"), "the agenda")
examine(evidenceProp("EV-006"), "the second cup")
converse("SUS-002", "Victor Lim (second run)", { "Take a look", "Laptop" }, "That's all")
check(sentCount("DialogueUpdated") > 0, "shown something that means nothing, Victor shrugs")
converse("SUS-001", "Meera Rozario (second run)", { "Where were you" }, "let you be")
Shim.advance(3)
local accusationState = lastSent("AccusationUpdated")
check(accusationState and accusationState[1].open, "with both suspects spoken to, accusing is open")
local observation = gui("MysteryCase_Observation")
local announced = false
for _, d in ipairs(observation and observation:GetDescendants() or {}) do
	if d:IsA("TextLabel") and string.find(string.lower(d.Text), "accusation", 1, true) then
		announced = true
	end
end
check(announced, "the player is told, once, that they can accuse")

check(
	claimPair("Fact_Statement_STMT-SUS-001-ALIBI", "Fact_Evidence_EV-002", "Meera's alibi × the laptop")
		== "Those two don't conflict.",
	"a pairing that doesn't conflict is only told so"
)
Shim.advance(2.5)
check(
	string.find(
		claimPair("Fact_Statement_STMT-SUS-001-ALIBI", "Fact_Evidence_EV-001", "Meera's alibi × the phone"),
		"MEERA'S MISSED CALL",
		1,
		true
	) ~= nil,
	"then a pairing that holds: 'Meera's Missed Call'"
)
Shim.advance(2.5)
-- A guess, then straight away the right answer: the second has to wait.
local guessed, rushed = "", ""
withCaseFile(function(file)
	local question = find(file, "Question_DEDUCT-002")
	if check(question, "the meeting question is open") then
		click(find(question, "Option_client"), "a guess")
		guessed = feedback()
		click(find(file, "Option_dissolve"), "straight away, the right answer")
		rushed = feedback()
	end
end)
say(`  [CASE FILE] a guess: {guessed} / straight away: {rushed}`)
check(guessed == "That doesn't hold up.", "a wrong answer is only told so")
check(rushed == "Take a moment. Look again.", "straight after a miss, the next try waits")
Shim.advance(2.5)
answerQuestion("DEDUCT-002", "dissolve", "the midnight meeting")

say("\n== Accusation (second run) ==")
accuse("ACC-002", "DEDUCT-002", "CONTRA-003")
summary = lastSent("CaseClosedSummary")
verdict = summary and summary[1].verdict
check(verdict and verdict.grade == "Wrong", "accusing Meera: the wrong person")
check(summary and summary[1].mistakes == 2, "two missteps on the record")
check(summary and summary[1].objectivesCompleted < summary[1].objectivesTotal, "accused with the case still open")
-- Phase 3 (R7): this rushed run never opened the timeline, so nothing to reward.
check(summary and summary[1].timelineReconstructed == false, "no timeline credit without reconstructing it")
if verdict then
	say(`  [VERDICT] {verdict.grade}: {verdict.epilogue or ""}`)
end
Shim.advance(3)
check(closingText("Title") == "The wrong person was charged.", "the closing screen: 'The wrong person was charged.'")
check(string.find(closingText("Stats"), "Missteps 2", 1, true) ~= nil, "the closing screen counts the missteps")
check(
	string.find(closingText("Stats"), "Timeline reconstructed", 1, true) == nil,
	"the closing screen never claims a timeline credit that wasn't earned"
)

print("\n---- TRANSCRIPT ----")
print(table.concat(transcript, "\n"))
print("---- END ----")
print(string.format("RESULT %d checks, %d failed, %d unexpected thread errors", steps, failures, #Shim.errors))
