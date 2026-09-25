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
local briefingGui = playerGui:FindFirstChild("MysteryCase_Briefing", true)
pressInteract() -- Begin investigation
Shim.advance(1)
local phase = lastSent("PhaseChanged")
check(phase and phase[1] == "Investigation", "E begins the investigation (phase Investigation)")

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
		check(not EvidencePanel.isOpen(), `the {label} readout closes with E`)
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

say("== The lobby ==")
check(objective() == "OBJ-000", "first objective: the night guard")
converse("SUS-003", "Sam Okafor", { "You found him?", "anyone else", "get in after hours", "cameras" }, "That's all")
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
check(hasFact("deductions", "Daniel Wasn't Alone"), "coffee machine + second cup: 'Daniel Wasn't Alone'")
-- Re-examining a found clue re-opens it quietly.
local discoveries = sentCount("EvidenceDiscovered")
examine(evidenceProp("EV-005"), "the coffee machine again")
local again = lastSent("EvidenceDiscovered")
check(sentCount("EvidenceDiscovered") == discoveries + 1 and again and again[1].revisited, "a found clue re-opens as 'on file'")

converse("SUS-002", "Victor Lane", { "When did you leave", "confirm", "dissolving" }, "That's all")
converse("SUS-001", "Mara Reyes", { "sorry", "Where were you", "ending the partnership" }, "let you be")
Shim.advance(3)
check(objective() == "OBJ-003", "both spoken to: test Victor's story")
check(hasFact("contradictions", "Mara's Missed Call"), "Mara's alibi breaks against the phone (red herring)")

say("\n== Reception ==")
examine(evidenceProp("EV-004"), "the badge log")
examine(evidenceProp("EV-007"), "the camera monitor")
Shim.advance(3)
check(hasFact("contradictions", "Half Past Ten"), "badge log breaks Victor's alibi")
check(hasFact("contradictions", "The Footage"), "the monitor note breaks 'pull the footage'")
check(objective() == "OBJ-004", "then: the call nobody answered")

-- Mara, pressed too hard first: she shuts down, then an apology.
converse("SUS-001", "Mara Reyes (pressed)", { "declined", "Why lie" }, nil)
converse("SUS-001", "Mara Reyes (again)", { "I'm sorry. I need to understand" }, "let you be")
Shim.advance(3)
check(hasFact("deductions", "Victor Came Back"), "Mara's lead + badge log: 'Victor Came Back'")
check(objective() == "OBJ-005", "then: the last ten minutes")

converse("SUS-002", "Victor Lane (badge)", { "Your badge came back in" }, "That's all")
Shim.advance(2)
check(hasFact("contradictions", "A Call That Never Connected"), "his revised story breaks against the phone")
converse("SUS-002", "Victor Lane (confrontation)", { "never connected" }, nil)
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
InputController.invoke("Accuse")
Shim.advance(1)
local accuseGui = playerGui:FindFirstChild("MysteryCase_Accusation")
local accused = false
if check(accuseGui, "Q opens the accusation picker") then
	for _, d in ipairs((accuseGui :: Instance):GetDescendants()) do
		if d:IsA("TextButton") and d.Text == "ACCUSE" then
			local row = d.Parent :: Instance
			local texts = {}
			for _, t in ipairs(row:GetDescendants()) do
				if t:IsA("TextLabel") then
					table.insert(texts, t.Text)
				end
			end
			if string.find(string.upper(table.concat(texts, " ")), "VICTOR", 1, true) then
				Shim.fireSignal(d.Activated)
				accused = true
				break
			end
		end
	end
end
check(accused, "clicked ACCUSE beside Victor Lane")
Shim.advance(3)
local summary = lastSent("CaseClosedSummary")
check(summary and summary[1].verdict and summary[1].verdict.correct, "the verdict: correct")
if summary and summary[1].verdict then
	say("  [VERDICT] " .. summary[1].verdict.reveal)
end
local closedPhase = lastSent("PhaseChanged")
check(closedPhase and closedPhase[1] == "CaseClosed", "phase CaseClosed")

-- Investigate again: a clean second run.
pressInteract()
Shim.advance(2)
local replayPhase = lastSent("PhaseChanged")
check(replayPhase and replayPhase[1] == "CaseBriefing", "E on the closing screen starts again at the briefing")

print("\n---- TRANSCRIPT ----")
print(table.concat(transcript, "\n"))
print("---- END ----")
print(string.format("RESULT %d checks, %d failed, %d unexpected thread errors", steps, failures, #Shim.errors))
