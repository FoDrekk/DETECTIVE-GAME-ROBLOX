--[[
	Entry: Phase 5.1's engine features end to end -- evidence props revealed
	by a condition (revealWhen), evidence handed over in a conversation
	(grantsEvidence), and the scripted-scene player (CutsceneService /
	CutsceneView).

	Like entry_playthrough, it runs the real server bootstrap and the real
	client LocalScript together and drives the client only through player
	inputs (standing next to things, the interact key, dialogue buttons).
	The one exception is starting a scene: that is the server's decision by
	design, so the harness calls CutsceneService.play the way a story
	trigger would.

	It plays a small synthetic fixture case made active for this run only,
	so CASE-001's story content is untouched and its own playthrough
	(entry_playthrough.luau) is unaffected. The fixture's words are
	placeholders, not story.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")

local failures = 0
local steps = 0

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

--------------------------------------------------------------------------
-- The fixture, registered and made active before the server boots
--------------------------------------------------------------------------

local CASE_ID = "CASE-ENGINE"
local CaseRegistry = Shim.require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
local Config = Shim.require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WITNESS_AT = Vector3.new(19.4, 3, 4.4)
local LOG_AT = Vector3.new(23.2, 3.27, 17.4)

CaseRegistry.register({
	id = CASE_ID,
	title = "ENGINE FIXTURE",
	description = "Placeholder case for the Phase 5.1 engine checks.",
	setting = { time = "12:00 AM", place = "Test floor" },
	suspects = {
		{
			id = "WIT",
			name = "Witness",
			role = "Night Security",
			alibi = "Placeholder alibi.",
			npcPlacement = { position = WITNESS_AT, lookAt = Vector3.new(18, 3, 10) },
		},
	},
	locations = {},
	evidence = {
		{
			id = "EV-LOG",
			name = "Access Log",
			description = "A printout.",
			details = "Placeholder log.",
			location = "Reception",
			importance = "High",
			propPlacement = {
				position = LOG_AT,
				lookAt = Vector3.new(23.2, 3.27, 10),
				style = "Printout",
				revealWhen = { { kind = "Statement", id = "STMT-PRINT" } },
			},
		},
		{
			id = "EV-NOTE",
			name = "Folded Note",
			description = "A note the witness was holding.",
			details = "Placeholder note.",
			location = "Reception",
			importance = "High",
		},
	},
	timeline = {},
	objectives = {
		{
			id = "OBJ-NOTE",
			title = "The Note",
			description = "Placeholder objective.",
			requiredEvidence = { "EV-NOTE" },
			requiredInteractions = {},
			requirements = { { id = "R-NOTE", label = "Read the note", interaction = "Read", evidence = "EV-NOTE" } },
		},
	},
	conversations = {
		{
			suspectId = "WIT",
			startNodeId = "HUB",
			nodes = {
				HUB = {
					id = "HUB",
					speaker = "Witness",
					text = "Placeholder greeting.",
					choices = {
						{ id = "print", text = "Print the log?", next = "PRINT" },
						{ id = "note", text = "What are you holding?", next = "NOTE" },
						{
							id = "about",
							text = "About this note...",
							next = "ABOUT",
							requires = { { kind = "Evidence", id = "EV-NOTE" } },
						},
						{ id = "bye", text = "That's all.", next = "BYE" },
					},
				},
				PRINT = {
					id = "PRINT",
					speaker = "Witness",
					text = "Placeholder: printing.",
					statementId = "STMT-PRINT",
					choicesFrom = "HUB",
				},
				NOTE = {
					id = "NOTE",
					speaker = "Witness",
					text = "Placeholder: take it.",
					statementId = "STMT-NOTE",
					grantsEvidence = { "EV-NOTE" },
					choicesFrom = "HUB",
				},
				ABOUT = { id = "ABOUT", speaker = "Witness", text = "Placeholder: about it.", choicesFrom = "HUB" },
				BYE = { id = "BYE", speaker = "Witness", text = "Placeholder: bye." },
			},
		},
	},
	statements = {
		{ id = "STMT-PRINT", suspectId = "WIT", label = "Offered to print", text = "Placeholder." },
		{ id = "STMT-NOTE", suspectId = "WIT", label = "Handed over a note", text = "Placeholder." },
	},
	contradictions = {},
	deductions = {},
	cutscenes = {
		{
			id = "CUT-ENGINE",
			replayFrom = "B",
			shots = {
				{
					id = "A",
					duration = 2,
					fadeIn = 0.5,
					camera = {
						from = { position = Vector3.new(0, 12, 30), lookAt = Vector3.new(0, 4, 0) },
						to = { position = Vector3.new(6, 12, 30), lookAt = Vector3.new(6, 4, 0) },
					},
					lines = { { at = 0.2, duration = 1.2, speaker = "Radio", text = "Test line one." } },
				},
				{
					id = "B",
					duration = 1.5,
					fadeOut = 0.4,
					camera = {
						from = { position = Vector3.new(10, 8, 10), lookAt = Vector3.new(0, 4, 0) },
						fieldOfView = 40,
					},
					lines = { { at = 0.1, duration = 1, text = "Test caption." } },
				},
			},
		},
		{
			id = "CUT-LOCK",
			skippable = false,
			shots = {
				{ id = "L", duration = 1, camera = { from = { position = Vector3.new(0, 8, 8), lookAt = Vector3.new(0, 4, 0) } } },
			},
		},
		{
			-- Long enough to press, wait and press again inside it.
			id = "CUT-LONG",
			shots = {
				{ id = "W", duration = 8, camera = { from = { position = Vector3.new(4, 8, 8), lookAt = Vector3.new(0, 4, 0) } } },
			},
		},
	},
} :: any)
Config.Game.AutoStartCase = CASE_ID

--------------------------------------------------------------------------
-- Boot, join, title, briefing
--------------------------------------------------------------------------

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

local Server = ServerScriptService:WaitForChild("Server")
local CutsceneService = Shim.require(Server:WaitForChild("CutsceneService"))
local RevealService = Shim.require(Server:WaitForChild("RevealService"))
local EvidenceServiceModule = Shim.require(Server:WaitForChild("EvidenceService"))
local Client = clientScript
local InputController = Shim.require(Client:WaitForChild("InputController"))
local InteractionController = Shim.require(Client:WaitForChild("InteractionController"))
local DialogueView = Shim.require(Client:WaitForChild("DialogueView"))
local EvidencePanel = Shim.require(Client:WaitForChild("EvidencePanel"))
local CutsceneView = Shim.require(Client:WaitForChild("CutsceneView"))
local playerGui = player:WaitForChild("PlayerGui")

local function lastSent(remote: string): { any }?
	for i = #Shim.remoteLog, 1, -1 do
		local entry = Shim.remoteLog[i]
		if entry.remote == remote then
			return entry.args
		end
	end
	return nil
end

local function pressInteract()
	InputController.invoke("Interact")
	Shim.advance(0.5)
end

pressInteract() -- dismiss the title
Shim.advance(4)
local briefingGui = playerGui:FindFirstChild("MysteryCase_Briefing", true) :: ScreenGui
local beginButton = briefingGui:FindFirstChild("Begin", true) :: TextButton
Shim.fireSignal(beginButton.Activated)
Shim.advance(1.5)
local phase = lastSent("PhaseChanged")
check(phase and phase[1] == "Investigation", "the fixture case starts (phase Investigation)")

--------------------------------------------------------------------------
-- Helpers (as in entry_playthrough)
--------------------------------------------------------------------------

local function character(): Model
	return player.Character :: Model
end

local function partOf(inst: Instance): BasePart
	return if inst:IsA("BasePart") then inst else inst:FindFirstChildWhichIsA("BasePart") :: BasePart
end

local function standAt(spot: Vector3, look: Vector3)
	character():PivotTo(CFrame.lookAt(spot, Vector3.new(look.X, spot.Y, look.Z)))
	workspace.CurrentCamera.CFrame = CFrame.lookAt(spot + Vector3.new(0, 2, 0) - (look - spot).Unit * 6, look)
	Shim.advance(0.3)
end

local function approach(target: Instance, label: string): boolean
	local center = partOf(target).Position
	for _, radius in ipairs({ 2.5, 3.5, 1.8, 5 }) do
		for step = 0, 15 do
			local angle = step / 16 * math.pi * 2
			standAt(Vector3.new(center.X + math.cos(angle) * radius, 3, center.Z + math.sin(angle) * radius), center)
			local current = InteractionController.getCurrent()
			if current and current.instance == target then
				return true
			end
		end
	end
	check(false, `the prompt can target {label}`)
	return false
end

local function witness(): Instance
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst:GetAttribute("SuspectId") == "WIT" then
			return inst
		end
	end
	error("no NPC for WIT")
end

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
	return out
end

local function buttonText(button: TextButton): string
	return (button:FindFirstChild("Label") :: TextLabel).Text
end

local function settleLine()
	for _ = 1, 40 do
		Shim.advance(0.25)
		if not DialogueView.isOpen() or #choiceButtons() > 0 or not DialogueView.awaitingChoice() then
			break
		end
	end
	Shim.advance(0.3)
end

local function offered(): { string }
	local out = {}
	for _, button in ipairs(choiceButtons()) do
		table.insert(out, buttonText(button))
	end
	return out
end

-- Click the on-screen choice whose words contain `want`.
local function pick(want: string): boolean
	settleLine()
	for _, button in ipairs(choiceButtons()) do
		if string.find(buttonText(button), want, 1, true) then
			Shim.fireSignal(button.Activated)
			Shim.advance(0.3)
			return true
		end
	end
	check(false, `"{want}" is on offer (offered: {table.concat(offered(), " | ")})`)
	return false
end

local function talk()
	approach(witness(), "the witness")
	pressInteract()
	check(DialogueView.isOpen(), "talking opens the dialogue")
end

local function leave()
	pick("That's all.")
	settleLine()
	pressInteract()
	Shim.advance(1)
	check(not DialogueView.isOpen(), "the conversation closes")
end

local function dialogueLabel(name: string): TextLabel
	return (playerGui:FindFirstChild("MysteryCase_Dialogue") :: Instance):FindFirstChild(name, true) :: TextLabel
end

--------------------------------------------------------------------------
-- revealWhen: a printout that only exists once it's been offered
--------------------------------------------------------------------------

print("\n== revealWhen ==")
local held = ServerStorage:FindFirstChild("MysteryCase_HeldProps")
local logPart = held and held:FindFirstChild("EV-LOG") :: BasePart?
check(logPart ~= nil, "the gated printout is built, and held out of the world at boot")
check(logPart and not logPart:IsDescendantOf(workspace), "the printout is not in the world before it's offered")
standAt(LOG_AT + Vector3.new(0, -0.27, -2.5), LOG_AT)
local current = InteractionController.getCurrent()
check(not current or current.instance ~= logPart, "standing at the counter, nothing offers to read it")

talk()
pick("Print the log?")
settleLine()
check(
	string.find(dialogueLabel("StatementToast").Text, "OFFERED TO PRINT", 1, true) ~= nil,
	"the offer is recorded as a statement"
)
Shim.advance(0.5)
check(logPart and logPart:IsDescendantOf(workspace), "once offered, the printout appears in the world")
check(RevealService.isRevealed(player, "EV-LOG"), "the server records the reveal")
leave()

if logPart and approach(logPart, "the printout") then
	check(InteractionController.getCurrent().label == "Read Access Log", "its prompt reads 'Read Access Log'")
	pressInteract()
	local sent = lastSent("EvidenceDiscovered")
	check(sent and sent[1].evidence.id == "EV-LOG" and not sent[1].granted, "reading it discovers the log (an ordinary find)")
	check(EvidencePanel.isOpen(), "the ordinary readout opens")
	pressInteract()
	check(not EvidencePanel.isOpen(), "and closes with E")
end

--------------------------------------------------------------------------
-- grantsEvidence: a note handed over mid-conversation
--------------------------------------------------------------------------

print("\n== grantsEvidence ==")
talk()
check(not table.find(offered(), "About this note..."), "no question about the note before it's handed over")
-- The readout would be closed again by the next dialogue line within the
-- same frame, so count openings rather than look at the end state.
local readoutOpenings = 0
local openings = EvidencePanel.onOpened().Event:Connect(function()
	readoutOpenings += 1
end)
pick("What are you holding?")
local sent = lastSent("EvidenceDiscovered")
check(sent and sent[1].evidence.id == "EV-NOTE" and sent[1].granted == true, "the note arrives flagged as handed over")
local line = lastSent("DialogueUpdated")
local granted = line and line[1].grantedEvidence
check(granted and #granted == 1 and granted[1] == "Folded Note", "the line carries the name of what it handed over")
Shim.advance(0.5)
openings:Disconnect()
check(DialogueView.isOpen(), "the conversation carries on")
check(
	readoutOpenings == 0 and not EvidencePanel.isOpen(),
	"the evidence readout never cuts across the conversation, not even for a frame"
)
local statementToast = dialogueLabel("StatementToast")
local evidenceToast = dialogueLabel("EvidenceToast")
check(
	evidenceToast.Visible and evidenceToast.TextTransparency < 0.5
		and string.find(evidenceToast.Text, "EVIDENCE ADDED", 1, true) ~= nil
		and string.find(evidenceToast.Text, "FOLDED NOTE", 1, true) ~= nil,
	"a notice says what was added: " .. evidenceToast.Text
)
check(string.find(statementToast.Text, "HANDED OVER A NOTE", 1, true) ~= nil, "the statement notice shows as before")
check(
	evidenceToast.Position.Y.Offset > statementToast.Position.Y.Offset,
	"with a statement notice up, the evidence notice sits on the row below"
)
local objective = lastSent("ObjectiveUpdated")
check(objective and objective[1].objective.completed, "the handed-over note completes the objective that needs it")
settleLine()
check(table.find(offered(), "About this note...") ~= nil, "the question about the note is offered on the same line")
check(EvidenceServiceModule.isDiscovered(player, "EV-NOTE"), "the server holds the note as discovered")
-- Asked again: nothing new is handed over.
local before = #Shim.remoteLog
pick("What are you holding?")
local again = lastSent("DialogueUpdated")
local repeatedDiscovery = false
for i = before + 1, #Shim.remoteLog do
	if Shim.remoteLog[i].remote == "EvidenceDiscovered" then
		repeatedDiscovery = true
	end
end
check(not repeatedDiscovery and again and again[1].grantedEvidence == nil, "asking again hands nothing over twice")
leave()

--------------------------------------------------------------------------
-- Cutscenes
--------------------------------------------------------------------------

print("\n== cutscene: plays to the end ==")
local camera = workspace.CurrentCamera :: Camera
local fov = camera.FieldOfView
local cutGui = playerGui:FindFirstChild("MysteryCase_Cutscene") :: ScreenGui
local function cutLabel(name: string): TextLabel
	return cutGui:FindFirstChild(name, true) :: TextLabel
end

check(CutsceneService.play(player, "CUT-ENGINE"), "the server starts a scene")
Shim.advance(0.1)
check(CutsceneView.isPlaying(), "the client plays it")
check(cutGui.Enabled, "the scene's frame is up")
check(camera.CameraType == Enum.CameraType.Scriptable, "the camera is the scene's")
Shim.advance(0.6)
local top = cutGui:FindFirstChild("LetterboxTop") :: Frame
check(top.Size.Y.Scale > 0, "letterbox bars close in")
check(cutLabel("Line").Text == "Test line one." and cutLabel("Line").TextTransparency < 0.5, "the first subtitle is on")
check(cutLabel("Speaker").Text == "RADIO", "under its speaker")
check(InteractionController.getCurrent() == nil, "nothing in the world is offered during a scene")
Shim.advance(1.5) -- into shot B
check(camera.FieldOfView == 40, "shot B sets its own field of view")
check(cutLabel("Line").Text == "Test caption.", "the next subtitle (a caption) follows on cue")
check(not cutLabel("Speaker").Visible, "a caption has no speaker")
Shim.advance(2)
check(not CutsceneView.isPlaying(), "the scene ends on its own")
check(not CutsceneService.isPlaying(player), "the server accepts the end")
check(CutsceneService.hasSeen(player, "CUT-ENGINE"), "the server remembers it was seen")
check(camera.CameraType == Enum.CameraType.Custom, "the camera is back with the player")
check(camera.FieldOfView == fov, "the player's field of view is restored")
Shim.advance(1)
check(not cutGui.Enabled, "the frame is gone")

print("\n== cutscene: a second showing, skipped ==")
check(CutsceneService.play(player, "CUT-ENGINE"), "the scene plays again")
Shim.advance(0.2)
local payload = lastSent("CutsceneUpdated")
check(
	payload and payload[1].shots and #payload[1].shots == 1 and payload[1].shots[1].id == "B",
	"a second showing starts at its replay shot"
)
pressInteract()
check(CutsceneView.isPlaying(), "one press doesn't skip")
check(cutLabel("SkipHint").Text == "[E]  Skip" and cutLabel("SkipHint").TextTransparency < 0.5, "it shows the skip hint")
pressInteract()
check(not CutsceneView.isPlaying(), "a second press skips")
check(not CutsceneService.isPlaying(player), "the server accepts the skip")
Shim.advance(1)
check(camera.CameraType == Enum.CameraType.Custom, "the camera is back after a skip")

print("\n== cutscene: arming lapses ==")
check(CutsceneService.play(player, "CUT-LONG"), "a longer scene plays")
Shim.advance(0.2)
pressInteract()
Shim.advance(Config.Cutscene.SkipConfirmWindow + 0.2)
check(cutLabel("SkipHint").TextTransparency > 0.5, "the skip hint fades when not confirmed")
pressInteract()
check(CutsceneView.isPlaying() and CutsceneService.isPlaying(player), "a late second press only re-arms")
Shim.advance(6)
check(not CutsceneView.isPlaying() and not CutsceneService.isPlaying(player), "and the scene plays out")

print("\n== cutscene: touch ==")
player:SetAttribute("InputSchemeOverride", "Touch")
Shim.advance(0.3)
check(CutsceneService.play(player, "CUT-LONG"), "the scene plays on touch")
Shim.advance(0.3)
local touchPrimary = (playerGui:FindFirstChild("MysteryCase_Touch") :: Instance):FindFirstChild("Primary") :: TextButton
check(touchPrimary.Visible and touchPrimary.Text == "Skip", "the touch button offers Skip")
local caseFileButton = (playerGui:FindFirstChild("MysteryCase_Touch") :: Instance):FindFirstChild("CaseFile") :: TextButton
check(not caseFileButton.Visible, "the case file button steps aside")
Shim.fireSignal(touchPrimary.Activated)
Shim.advance(0.3)
check(cutLabel("SkipHint").Text == "Tap Skip again to skip", "the hint reads for touch")
Shim.fireSignal(touchPrimary.Activated)
Shim.advance(0.3)
check(not CutsceneView.isPlaying() and not CutsceneService.isPlaying(player), "a second tap skips")
player:SetAttribute("InputSchemeOverride", nil)
Shim.advance(0.5)

print("\n== cutscene: unskippable ==")
check(CutsceneService.play(player, "CUT-LOCK"), "an unskippable scene plays")
Shim.advance(0.2)
pressInteract()
InputController.invoke("Interact")
Shim.advance(0.1)
check(CutsceneView.isPlaying() and CutsceneService.isPlaying(player), "presses don't skip it")
check(cutLabel("SkipHint").TextTransparency > 0.5, "and no skip hint is offered")
Shim.advance(1)
check(not CutsceneView.isPlaying() and not CutsceneService.isPlaying(player), "it ends when it ends")

print("\n== cutscene: a client that loses track never holds the story up ==")
-- The server plays a scene, but the client ends up showing something else
-- (here: a local stand-in view pushed straight into CutsceneView) and never
-- reports the server's scene. The server's own timer ends it after its
-- length plus the grace, and says so; the client, busy with the other view,
-- ignores that stale "over" and finishes what it is actually showing.
check(CutsceneService.play(player, "CUT-LOCK"), "the server starts a scene")
Shim.advance(0.2)
CutsceneView.play({
	active = true,
	id = "LOCAL-STANDIN",
	skippable = true,
	shots = {
		{
			id = "X",
			duration = 8,
			camera = { from = { position = Vector3.new(0, 8, 8), lookAt = Vector3.new(0, 4, 0) } },
		},
	},
})
Shim.advance(1.5)
check(CutsceneService.isPlaying(player), "past the scene's length, the server still waits (the grace)")
Shim.advance(Config.Cutscene.EndGrace)
check(not CutsceneService.isPlaying(player), "after the grace, the server ends it itself")
local over = lastSent("CutsceneUpdated")
check(over and over[1].active == false and over[1].id == "CUT-LOCK", "and tells the client it's over")
check(CutsceneView.isPlaying() and CutsceneView.currentId() == "LOCAL-STANDIN", "a stale 'over' doesn't close a different view")
Shim.advance(0.3)
check(InteractionController.getCurrent() == nil, "nor hands the world back while a view is still up")
Shim.advance(2.5)
check(not CutsceneView.isPlaying(), "the view on screen finishes on its own")
check(not CutsceneService.isPlaying(player), "and its report changes nothing on the server")

print("\n== after the scenes ==")
Shim.advance(1)
standAt(WITNESS_AT + Vector3.new(0, 0, 3), WITNESS_AT)
approach(witness(), "the witness")
check(InteractionController.getCurrent() ~= nil, "the world is usable again")
talk()
check(DialogueView.isOpen(), "and conversations work again")
leave()

print(string.format("RESULT %d checks, %d failed, %d unexpected thread errors", steps, failures, #Shim.errors))
