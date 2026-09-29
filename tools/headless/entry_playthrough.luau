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

-- Title screen, then the briefing.
check(TitleScreenView.isOpen(), "title screen is showing on join")
pressInteract()
Shim.advance(1.5) -- the title fades to black, then out
check(not TitleScreenView.isOpen(), "E dismisses the title screen")
-- The briefing: words over a shot of the crime scene, and a Begin button.
local briefingGui = playerGui:FindFirstChild("MysteryCase_Briefing", true) :: ScreenGui
Shim.advance(3) -- the lines arrive one after another
local function briefingText(name: string): string
	local label = briefingGui:FindFirstChild(name, true)
	return if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then label.Text else ""
end
check(briefingGui.Enabled, "the briefing shows once the title is gone")
check(briefingText("CaseNumber") == "CASE 001", "briefing: case number")
check(briefingText("Title") == "THE LAST CALL", "briefing: title")
check(string.find(briefingText("Hook"), "never answered", 1, true) ~= nil, "briefing: story hook")
local settingLine = briefingText("Setting")
check(
	string.find(settingLine, "12:40 AM", 1, true) and string.find(settingLine, "Rozario &amp; Lim", 1, true),
	"briefing: time and place (rich text, escaped)"
)
local camera = workspace.CurrentCamera :: Camera
check(camera.CameraType == Enum.CameraType.Scriptable, "briefing: the camera holds the crime-scene shot")
say(`  [BRIEFING] {briefingText("CaseNumber")} / {briefingText("Title")} / {briefingText("Hook")}`)
local beginButton = briefingGui:FindFirstChild("Begin", true) :: TextButton
check(beginButton and beginButton.Text ~= "", "briefing: the Begin button is labelled")
Shim.fireSignal(beginButton.Activated) -- click Begin investigation
Shim.advance(1.5)
local phase = lastSent("PhaseChanged")
check(phase and phase[1] == "Investigation", "clicking Begin starts the investigation (phase Investigation)")
check(camera.CameraType == Enum.CameraType.Custom, "the camera is back with the player")
check(not briefingGui.Enabled, "the briefing is gone")

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
converse("SUS-003", "Sam Gurung", { "You found him?", "anyone else", "get in after hours", "cameras" }, "That's all")
Shim.advance(3)
check(objective() == "OBJ-001", "talking to Sam moves on to Daniel's office")

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

say("\n== Reception ==")
examine(evidenceProp("EV-004"), "the badge log")
examine(evidenceProp("EV-007"), "the camera monitor")

converse(
	"SUS-002",
	"Victor Lim",
	{ "When did you leave", "confirm", "dissolving", "Take a look", "Camera Monitor" },
	"That's all"
)
Shim.advance(1)
check(hasFact("contradictions", "The Footage"), "showing Victor his own note: 'The Footage'")
converse("SUS-001", "Meera Rozario", { "sorry", "Where were you", "ending the partnership" }, "let you be")
Shim.advance(3)
check(objective() == "OBJ-003", "both spoken to: test Victor's story")
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
converse("SUS-001", "Meera Rozario (again)", { "I'm sorry. I need to understand" }, "let you be")
Shim.advance(2)
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
local canonical = { "TIMELINE-005", "TIMELINE-001", "TIMELINE-002", "TIMELINE-004", "TIMELINE-003" }
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
accuse("ACC-001", "DEDUCT-002", "CONTRA-002")
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
check(string.find(closingText("Epilogue"), "unsigned", 1, true) ~= nil, "the closing screen tells what happened next")
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

-- Investigate again: a clean second run.
pressInteract()
Shim.advance(2)
local replayPhase = lastSent("PhaseChanged")
check(replayPhase and replayPhase[1] == "CaseBriefing", "E on the closing screen starts again at the briefing")
check(
	briefingGui.Enabled and camera.CameraType == Enum.CameraType.Scriptable,
	"the replay opens on the briefing shot again"
)
pressInteract() -- [E] Begin investigation
Shim.advance(1.5)
local secondRun = lastSent("PhaseChanged")
check(
	secondRun and secondRun[1] == "Investigation" and camera.CameraType == Enum.CameraType.Custom,
	"E begins the second run, camera back with the player"
)
-- Phase 3 (R3): nothing from the solved run carries into the second.
do
	local fresh = reasoning()
	check(
		fresh and #fresh.statements == 0 and #fresh.contradictions == 0 and #fresh.deductions == 0 and #fresh.evidence == 0,
		"the replay starts with an empty case file"
	)
	check(objective() == "OBJ-000", "the replay starts at the first objective")
	local accusationFresh = lastSent("AccusationUpdated")
	check(accusationFresh and not accusationFresh[1].open, "the replay starts with accusing closed")
	local timelineFresh = lastSent("TimelineUpdated")
	check(
		timelineFresh and #timelineFresh[1].events == 0 and not timelineFresh[1].established,
		"the replay starts with an empty timeline"
	)
end

--------------------------------------------------------------------------
-- Second run: sloppy, and an early accusation of the wrong person
--------------------------------------------------------------------------

say("\n== Second run: in a hurry ==")
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
