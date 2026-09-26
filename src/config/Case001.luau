--!strict
--[[
	Case001 — THE LAST CALL
	Investigative data for the first case.
	Pure data only: no gameplay logic belongs here.

	The story (canon):
	  Daniel Reyes was ending his partnership with Victor Lane; the papers
	  were to be signed at midnight. Victor told the night guard he was off
	  around ten, but his badge came back in at 11:04 PM. Daniel made two
	  espressos at 11:31 and tried to talk him down. At 11:47 Daniel called
	  his wife Mara. She was awake -- they had argued -- and she declined it.
	  Minutes later Daniel was dead, and at 11:52 Victor's badge was the last
	  to leave. Victor had known since Tuesday the lobby cameras were dark.

	How the player gets there (no step is handed over):
	  Sam, the night guard, is the ordinary person who found him: he points at
	  the badge log and the dead cameras without knowing what they mean.
	  Daniel's desk holds a phone, a draft, an agenda -- and a second cup on
	  the visitor's side. Victor's alibi breaks against the badge log, so he
	  revises it ("he was alive, on the phone, laughing") -- which breaks
	  against the phone itself. Mara's alibi also breaks against the phone
	  (the call was declined, not missed): a real contradiction with an
	  innocent, human explanation, and the lead that Victor was coming back.
	  Whether the investigator is gentle or accusing with her changes what
	  she does next.

	M9: nothing is concluded for the investigator. Every contradiction is
	claimed (set side by side in the case file, or shown to the person who
	said it), every deduction is a question they answer, and the accusation
	names a motive and a proof as well as a suspect. It opens once both the
	partner and the wife have been spoken to, so accusing early is possible
	and costs what it should.

	Dialogue writing rules for this file: short beats, one thought per line,
	people answer the question they want to answer, and nobody explains the
	case. Statements record what a character actually said.
]]

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

-- Condition helpers (data only; they build DialogueCondition tables).
local function knows(kind: Types.DialogueConditionKind, id: string): Types.DialogueCondition
	return { kind = kind, id = id }
end
local function lacks(kind: Types.DialogueConditionKind, id: string): Types.DialogueCondition
	return { kind = kind, id = id, negate = true }
end

local YOU = "You"

-- One thing the investigator can say: the words, where the answer starts,
-- what they must already know for it to be offered, and whether it is a
-- one-time question.
local function ask(
	id: string,
	text: string,
	nextNode: string,
	requires: { Types.DialogueCondition }?,
	once: boolean?
): Types.DialogueChoiceDefinition
	return { id = id, text = text, next = nextNode, requires = requires, once = once }
end

-- "Show them something" (M9): the evidence that lands with this character,
-- in order, and where anything else leads.
local function show(
	id: string,
	text: string,
	prompt: string,
	nothing: string,
	outcomes: { Types.DialoguePresentOutcome }
): Types.DialogueChoiceDefinition
	return { id = id, text = text, next = nothing, present = { prompt = prompt, outcomes = outcomes } }
end

local Case001: Types.CaseDefinition = {
	id = "CASE-001",
	title = "THE LAST CALL",
	description = "Daniel Reyes never went home. The night guard found him on his office floor. "
		.. "His phone shows one last call, minutes before he died. It was never answered.",
	setting = { time = "12:40 AM", place = "Reyes & Lane · Ninth floor" },

	suspects = {
		{
			id = "SUS-001",
			name = "Mara Reyes",
			role = "Daniel's Wife",
			alibi = '"Home. Asleep since ten. I never heard his call."',
			-- At the corridor's north window, looking out at the city, her back
			-- to the office.
			npcPlacement = {
				position = Vector3.new(-4, 3, -20.2),
				lookAt = Vector3.new(-4, 3, -30),
			},
			-- ROBLOX Girl ponytail (Roblox catalog), dark brown; a burgundy
			-- cardigan over dark trousers -- dressed in a hurry, woken at night.
			appearance = {
				body = "Woman",
				hair = 48474294,
				hairColor = Color3.fromRGB(58, 38, 30),
				skin = Color3.fromRGB(234, 198, 170),
				top = Color3.fromRGB(104, 38, 48),
				bottom = Color3.fromRGB(46, 46, 54),
				shoes = Color3.fromRGB(28, 26, 26),
				details = { "Scarf", "Watch" },
				accent = Color3.fromRGB(196, 178, 150),
			},
		},
		{
			id = "SUS-002",
			name = "Victor Lane",
			role = "Business Partner",
			alibi = '"Half ten. Daniel was still at his desk. Whatever happened, it happened after I\'d gone."',
			-- In the meeting room, at the end of the table where the papers
			-- were to be signed.
			npcPlacement = {
				position = Vector3.new(26.8, 3, -16.6),
				lookAt = Vector3.new(20, 3, -14),
			},
			-- Classic Male v2 hair (Roblox catalog), near black; still in the
			-- charcoal suit he wore to the office.
			appearance = {
				body = "Man",
				hair = 4637254498,
				hairColor = Color3.fromRGB(40, 36, 34),
				skin = Color3.fromRGB(198, 152, 122),
				top = Color3.fromRGB(46, 48, 56),
				bottom = Color3.fromRGB(38, 40, 46),
				shoes = Color3.fromRGB(20, 18, 18),
				details = { "Shirt", "Tie", "Watch" },
				accent = Color3.fromRGB(112, 28, 36),
			},
		},
		{
			-- Not a suspect: the ordinary person who found him. Speakable, never
			-- accusable (no AccusationDefinition names him).
			id = "SUS-003",
			name = "Sam Okafor",
			role = "Night Security",
			alibi = '"Ten past twelve, on my rounds. His light was on. It\'s always on."',
			-- Just past the lobby partition, where the investigator arrives,
			-- waiting to be asked something.
			npcPlacement = {
				position = Vector3.new(19.4, 3, 4.4),
				lookAt = Vector3.new(18, 3, 10),
			},
			-- Close-shaved head (no hair accessory); navy guard's uniform.
			appearance = {
				body = "Man",
				hairColor = Color3.fromRGB(20, 18, 18),
				skin = Color3.fromRGB(116, 78, 56),
				top = Color3.fromRGB(34, 44, 66),
				bottom = Color3.fromRGB(30, 34, 44),
				shoes = Color3.fromRGB(16, 16, 16),
				details = { "SecurityPatch", "Radio", "Lanyard" },
				accent = Color3.fromRGB(214, 190, 120),
			},
		},
	},

	locations = {
		{
			id = "LOC-001",
			name = "Office",
			description = "Daniel's private office. Where the body was discovered.",
			-- A nameplate beside the office door, on the corridor side.
			-- Part_Daniel_South_B spans Z -2.5..-1.5 (1-stud wall centred at
			-- -2); -1.45 sits the plaque just proud of its corridor face.
			signPlacement = {
				position = Vector3.new(-16.3, 5.5, -1.45),
				lookAt = Vector3.new(-16.3, 5.5, 6),
				text = "Daniel Reyes",
			},
		},
	},

	-- Flavour text for the office's non-evidence interactables, applied at
	-- runtime by instance name (OfficeRoom). None of it is a clue on its
	-- own; some of it makes a clue mean more.
	observations = {
		{
			instanceName = "ReceptionDesk",
			text = "The visitor book's last entry is a courier at 6:12 PM. After hours nobody signs in. "
				.. "The badge readers do the remembering.",
		},
		{
			instanceName = "DeskDrawer",
			text = "Pens. A phone charger. A photo of Mara he never put on the desk. Nothing anyone would come back for.",
		},
		{
			instanceName = "FileCabinet_1",
			text = "One drawer is labelled R&L — PARTNERSHIP. It was opened tonight: the folders are back in the wrong order.",
		},
		{
			instanceName = "Whiteboard",
			text = 'Last quarter\'s targets, in Daniel\'s handwriting. Someone has struck through "R&L" and written a single "R" beside it.',
		},
		{
			instanceName = "CoffeeCup",
			text = "Daniel's mug. Chamomile -- the tag still hangs over the rim. Stone cold.",
		},
		{
			instanceName = "Pen",
			text = "A fountain pen, uncapped, lying across a blank signature line.",
		},
		{
			instanceName = "Shelf_Frame",
			text = "Binders, and a framed photo: Daniel and Victor at a ribbon-cutting, younger, grinning. "
				.. "Someone has turned it face down.",
		},
		{
			instanceName = "GuardFlask",
			text = "A dented steel flask of tea, strong enough to stand a spoon in. Sam doesn't trust the office machine.",
		},
		{
			instanceName = "MeetingWater",
			text = "Two glasses of water and two pens, set out neatly. Nobody sat down to use them.",
		},
		{
			instanceName = "ElevatorPanel",
			text = "The lift is parked on this floor. Its display remembers one last trip tonight: down, 11:53 PM.",
		},
	},

	evidence = {
		{
			id = "EV-001",
			name = "Phone",
			description = "Daniel's phone, face up beside the keyboard.",
			details = "Last call: 11:47 PM, to MARA. Rang for 31 seconds. Declined.",
			location = "Daniel's Office",
			importance = "Critical",
			category = "Communication",
			timestamp = "11:47 PM",
			timelineEventId = "TIMELINE-002",
			-- Both record Daniel at his desk minutes apart (11:42 / 11:47 PM).
			relatedEvidenceIds = { "EV-002" },
		},
		{
			id = "EV-002",
			name = "Laptop",
			description = "Daniel's laptop, still awake.",
			details = 'A draft: "Reyes & Lane: Dissolution of Partnership", last saved 11:42 PM. '
				.. 'A note in the margin: "V. will fight the buy-out. Don\'t back down."',
			location = "Daniel's Office",
			importance = "High",
			category = "Digital Activity",
			timestamp = "11:42 PM",
			timelineEventId = "TIMELINE-001",
			relatedEvidenceIds = { "EV-001" },
		},
		{
			id = "EV-003",
			name = "Agenda",
			description = "A printed agenda for tonight, squared neatly on the desk.",
			details = '12:00 AM, with V. Lane: "Sign the dissolution. No more delays."',
			location = "Daniel's Office",
			importance = "Medium",
			category = "Document",
			timestamp = "12:00 AM",
			timelineEventId = "TIMELINE-003",
		},
		{
			id = "EV-004",
			name = "Badge Log",
			description = "Tonight's after-hours access log, printed at reception.",
			details = "11:04 PM  LANE, V.  IN.   11:52 PM  LANE, V.  OUT.   "
				.. "No other badge used after 9 PM except security.",
			location = "Reception",
			importance = "High",
			category = "Security",
			timestamp = "11:52 PM",
			timelineEventId = "TIMELINE-004",
			-- On the reception counter, where Sam left it.
			propPlacement = {
				position = Vector3.new(23.2, 3.27, 17.4),
				lookAt = Vector3.new(23.2, 3.27, 10),
				style = "Printout",
			},
		},
		{
			id = "EV-005",
			name = "Coffee Machine",
			description = "The pantry's espresso machine, still warm to the touch.",
			details = "Display: LAST BREW 11:31 PM · 2 × ESPRESSO.",
			location = "Pantry",
			importance = "Medium",
			category = "Environment",
			timestamp = "11:31 PM",
			timelineEventId = "TIMELINE-005",
			relatedEvidenceIds = { "EV-006" },
			propPlacement = {
				position = Vector3.new(-12.6, 3.0, -21.8),
				lookAt = Vector3.new(-5, 3.0, -21.8),
				style = "EspressoMachine",
			},
		},
		{
			id = "EV-006",
			name = "Second Cup",
			description = "An espresso cup on the visitor's side of Daniel's desk.",
			details = "Half finished. Cold. Daniel's own mug, at the other end of the desk, holds tea.",
			location = "Daniel's Office",
			importance = "Medium",
			category = "Environment",
			relatedEvidenceIds = { "EV-005" },
			propPlacement = {
				position = Vector3.new(-26.3, 2.62, -9.72),
				lookAt = Vector3.new(-26.3, 2.62, -14),
				style = "EspressoCup",
			},
		},
		{
			id = "EV-007",
			name = "Camera Monitor",
			description = "The lobby camera monitor behind the reception counter.",
			details = 'All four feeds: NO SIGNAL. A note on the bezel: "Don\'t call the contractor out. Next week. — V.L."',
			location = "Reception",
			importance = "Medium",
			category = "Security",
			propPlacement = {
				position = Vector3.new(25.8, 3.26, 18.4),
				lookAt = Vector3.new(25.8, 3.26, 10),
				style = "CameraMonitor",
			},
		},
	},

	timeline = {
		{
			id = "TIMELINE-005",
			timestamp = "11:31 PM",
			timeMinutes = 1411,
			title = "Two espressos",
			description = "The pantry machine makes two coffees. Daniel doesn't drink coffee at night.",
			sourceEvidenceIds = { "EV-005" },
		},
		{
			id = "TIMELINE-001",
			timestamp = "11:42 PM",
			timeMinutes = 1422,
			title = "The draft is saved",
			description = "Daniel saves the papers ending his partnership with Victor Lane.",
			sourceEvidenceIds = { "EV-002" },
		},
		{
			id = "TIMELINE-002",
			timestamp = "11:47 PM",
			timeMinutes = 1427,
			title = "The last call",
			description = "Daniel calls Mara. The call is declined.",
			sourceEvidenceIds = { "EV-001" },
		},
		{
			id = "TIMELINE-004",
			timestamp = "11:52 PM",
			timeMinutes = 1432,
			title = "A badge leaves",
			description = "Victor Lane's badge exits the building. It came back in at 11:04 PM.",
			sourceEvidenceIds = { "EV-004" },
		},
		{
			id = "TIMELINE-003",
			timestamp = "12:00 AM",
			timeMinutes = 1440,
			title = "The midnight meeting",
			description = "Daniel and Victor were due to sign the dissolution.",
			sourceEvidenceIds = { "EV-003" },
		},
	},

	-- The order a not-yet-reconstructed timeline presents its events in.
	-- Deliberately NOT chronological (canonical: 11:31 -> 11:42 -> 11:47 ->
	-- 11:52 -> 12:00), so putting the night in order is a real step.
	timelineChallengeOrder = { "TIMELINE-004", "TIMELINE-003", "TIMELINE-005", "TIMELINE-002", "TIMELINE-001" },

	-- The pacing spine. Each description points at a question, never at
	-- its answer. Requirements met before an objective becomes active still
	-- count once it does (ObjectiveService credits known facts).
	objectives = {
		{
			id = "OBJ-000",
			title = "The Night Guard",
			description = "The guard who called it in is waiting just past reception.",
			requiredEvidence = {},
			requiredInteractions = { "Talk" },
			requirements = {
				{ id = "REQ-000", label = "Talk to the night guard", interaction = "Talk", target = "SUS-003" },
			},
		},
		{
			id = "OBJ-001",
			title = "Daniel's Office",
			description = "West side, past the tape. Look at what's there, and at what shouldn't be.",
			requiredEvidence = { "EV-001", "EV-002", "EV-003", "EV-006" },
			requiredInteractions = { "EV-001", "EV-002", "EV-003", "EV-006" },
			requirements = {
				{ id = "REQ-001", label = "Examine the phone", evidence = "EV-001" },
				{ id = "REQ-002", label = "Examine the laptop", evidence = "EV-002" },
				{ id = "REQ-003", label = "Read the papers on the desk", interaction = "Read", evidence = "EV-003" },
				{ id = "REQ-008", label = "The visitor's side of the desk", evidence = "EV-006" },
			},
			prerequisites = { "OBJ-000" },
		},
		{
			-- `target` matches each suspect's spawned interactable, which
			-- SuspectSpawner names after the suspect id.
			id = "OBJ-002",
			title = "The People He Left",
			description = "His partner and his wife are still in the building. Ask them about tonight.",
			requiredEvidence = {},
			requiredInteractions = { "Talk" },
			requirements = {
				{ id = "REQ-004", label = "Talk to Victor Lane", interaction = "Talk", target = "SUS-002" },
				{ id = "REQ-009", label = "Talk to Mara Reyes", interaction = "Talk", target = "SUS-001" },
			},
			prerequisites = { "OBJ-001" },
		},
		{
			id = "OBJ-003",
			title = "Half Past Ten",
			description = "Victor says he was gone by half ten. If anything in this building says otherwise, "
				.. "show it to him, or set the two side by side in your case file.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{ id = "REQ-005", label = "Test Victor's account of his night", contradiction = "CONTRA-001" },
			},
			prerequisites = { "OBJ-002" },
		},
		{
			id = "OBJ-004",
			title = "The Call Nobody Answered",
			description = "Daniel's last call, at 11:47, went to Mara. She is the one person he tried to reach.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{ id = "REQ-006", label = "Find out what Daniel expected tonight", deduction = "DEDUCT-001" },
			},
			prerequisites = { "OBJ-003" },
		},
		{
			id = "OBJ-005",
			title = "The Last Ten Minutes",
			description = "Victor has a new story for the last ten minutes. Everything in it can be checked.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{ id = "REQ-010", label = "Get the truth about the last ten minutes", deduction = "DEDUCT-004" },
			},
			prerequisites = { "OBJ-004" },
		},
		{
			-- The timeline is a mechanic, not decoration: the player puts the
			-- discovered events in order; the server accepts only the
			-- canonical order. The last step before an accusation.
			id = "OBJ-006",
			title = "Reconstruct the Night",
			description = "Open the timeline and put the night in the order it happened.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{ id = "REQ-007", label = "Establish the sequence of events", timelineEstablished = true },
			},
			prerequisites = { "OBJ-005" },
		},
	},

	--------------------------------------------------------------------
	-- Conversations
	--
	-- Questions that unlock a statement are hidden once that statement is
	-- known (never `once`), so walking away mid-answer can't lose a fact.
	-- `once` is only used for questions that are pure character.
	--------------------------------------------------------------------
	conversations = {
		----------------------------------------------------------------
		-- Sam Okafor: casual, chatty, a little shaken, genuinely helpful.
		-- Knows the building, not the case.
		----------------------------------------------------------------
		{
			suspectId = "SUS-003",
			startNodeId = "SAM-OPEN",
			entries = {
				{ node = "SAM-AGAIN", requires = { knows("Flag", "sam_met") } },
			},
			nodes = {
				["SAM-OPEN"] = {
					id = "SAM-OPEN",
					speaker = "Sam Okafor",
					text = "Detective? Hey. Over here.",
					next = "SAM-OPEN-2",
					setFlags = { "sam_met" },
				},
				["SAM-OPEN-2"] = {
					id = "SAM-OPEN-2",
					speaker = "Sam Okafor",
					text = "Sorry. I've been stood here half an hour. Didn't know if I was allowed to sit down.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-AGAIN"] = {
					id = "SAM-AGAIN",
					speaker = "Sam Okafor",
					text = "Still here. Not going anywhere, apparently.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-HUB"] = {
					id = "SAM-HUB",
					speaker = "Sam Okafor",
					text = "What do you need?",
					choices = {
						ask("found", "You found him?", "SAM-FOUND-1", { lacks("Statement", "STMT-SUS-003-FOUND") }),
						ask(
							"anyone",
							"Was anyone else here tonight?",
							"SAM-ANYONE-1",
							{ lacks("Statement", "STMT-SUS-003-VICTOR") }
						),
						ask("badges", "How does anyone get in after hours?", "SAM-BADGE-1", nil, true),
						ask(
							"cameras",
							"Does the building have cameras?",
							"SAM-CAM-1",
							{ lacks("Statement", "STMT-SUS-003-CAMERAS") }
						),
						ask(
							"coffee",
							"Did you make coffee for anyone tonight?",
							"SAM-COFFEE-1",
							{ knows("Evidence", "EV-006"), lacks("Statement", "STMT-SUS-003-COFFEE") }
						),
						ask("mara", "Is Mrs. Reyes here?", "SAM-MARA-1", nil, true),
						show("show", "Does this mean anything to you?", "Show Sam…", "SAM-SHOW-NOTHING", {
							{
								evidence = "EV-006",
								next = "SAM-COFFEE-1",
								requires = { lacks("Statement", "STMT-SUS-003-COFFEE") },
							},
							{ evidence = "EV-004", next = "SAM-SHOW-LOG" },
							{ evidence = "EV-007", next = "SAM-SHOW-MONITOR" },
						}),
						ask("bye", "That's all for now.", "SAM-BYE"),
					},
				},
				["SAM-FOUND-1"] = {
					id = "SAM-FOUND-1",
					speaker = "Sam Okafor",
					text = "Ten past twelve. I do rounds on the hour. Well. Roughly on the hour.",
					next = "SAM-FOUND-2",
				},
				["SAM-FOUND-2"] = {
					id = "SAM-FOUND-2",
					speaker = "Sam Okafor",
					text = "His light was on. It's always on. I knocked, 'cause you knock, right?",
					next = "SAM-FOUND-3",
				},
				["SAM-FOUND-3"] = {
					id = "SAM-FOUND-3",
					speaker = "Sam Okafor",
					text = "Nobody said anything. So I went in, and...",
					next = "SAM-FOUND-4",
				},
				["SAM-FOUND-4"] = {
					id = "SAM-FOUND-4",
					speaker = "Sam Okafor",
					text = "Yeah. I called it in from the lobby. Didn't touch anything. I watch the shows.",
					statementId = "STMT-SUS-003-FOUND",
					choicesFrom = "SAM-HUB",
				},
				["SAM-ANYONE-1"] = {
					id = "SAM-ANYONE-1",
					speaker = "Sam Okafor",
					text = "Tonight? Just Mr. Lane. Earlier.",
					next = "SAM-ANYONE-2",
				},
				["SAM-ANYONE-2"] = {
					id = "SAM-ANYONE-2",
					speaker = YOU,
					text = "Earlier?",
					isPlayer = true,
					next = "SAM-ANYONE-3",
				},
				["SAM-ANYONE-3"] = {
					id = "SAM-ANYONE-3",
					speaker = "Sam Okafor",
					text = "He stuck his head in about ten. \"Night, Sam. I'm off.\" He always tells me. Like I'm keeping a diary.",
					next = "SAM-ANYONE-4",
				},
				["SAM-ANYONE-4"] = {
					id = "SAM-ANYONE-4",
					speaker = "Sam Okafor",
					text = "Did I actually see him go? ...No. I was up on eleven.",
					statementId = "STMT-SUS-003-VICTOR",
					choicesFrom = "SAM-HUB",
				},
				["SAM-BADGE-1"] = {
					id = "SAM-BADGE-1",
					speaker = "Sam Okafor",
					text = "Badge. Every door locks at nine.",
					next = "SAM-BADGE-2",
				},
				["SAM-BADGE-2"] = {
					id = "SAM-BADGE-2",
					speaker = "Sam Okafor",
					text = "The system keeps a log. I printed tonight's for you. It's on the reception counter.",
					next = "SAM-BADGE-3",
				},
				["SAM-BADGE-3"] = {
					id = "SAM-BADGE-3",
					speaker = "Sam Okafor",
					text = "Haven't read it. Figured that's your job.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-CAM-1"] = {
					id = "SAM-CAM-1",
					speaker = "Sam Okafor",
					text = "Has. Past tense.",
					next = "SAM-CAM-2",
				},
				["SAM-CAM-2"] = {
					id = "SAM-CAM-2",
					speaker = "Sam Okafor",
					text = "All four went dark on Tuesday. I logged it.",
					next = "SAM-CAM-3",
				},
				["SAM-CAM-3"] = {
					id = "SAM-CAM-3",
					speaker = "Sam Okafor",
					text = "Mr. Lane said leave it till next week. Contractor's expensive. It's all on the monitor, if you want to see.",
					statementId = "STMT-SUS-003-CAMERAS",
					choicesFrom = "SAM-HUB",
				},
				["SAM-COFFEE-1"] = {
					id = "SAM-COFFEE-1",
					speaker = "Sam Okafor",
					text = "From that machine? No chance. I bring a flask. That thing hates me.",
					next = "SAM-COFFEE-2",
				},
				["SAM-COFFEE-2"] = {
					id = "SAM-COFFEE-2",
					speaker = "Sam Okafor",
					text = "Mr. Reyes didn't drink it at night either. Said it kept him up.",
					next = "SAM-COFFEE-3",
				},
				["SAM-COFFEE-3"] = {
					id = "SAM-COFFEE-3",
					speaker = "Sam Okafor",
					text = "But he'd make one for whoever he was keeping late. Called it a bribe.",
					statementId = "STMT-SUS-003-COFFEE",
					choicesFrom = "SAM-HUB",
				},
				["SAM-MARA-1"] = {
					id = "SAM-MARA-1",
					speaker = "Sam Okafor",
					text = "Came in about twenty past twelve. Your lot called her.",
					next = "SAM-MARA-2",
				},
				["SAM-MARA-2"] = {
					id = "SAM-MARA-2",
					speaker = "Sam Okafor",
					text = "She's by the window at the end of the corridor. Hasn't moved. Hasn't said a word to me.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-SHOW-NOTHING"] = {
					id = "SAM-SHOW-NOTHING",
					speaker = "Sam Okafor",
					text = "Sorry. Doesn't mean anything to me. I do the doors.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-SHOW-LOG"] = {
					id = "SAM-SHOW-LOG",
					speaker = "Sam Okafor",
					text = "That's the log I printed you. Told you, I haven't read it. Didn't want to.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-SHOW-MONITOR"] = {
					id = "SAM-SHOW-MONITOR",
					speaker = "Sam Okafor",
					text = "Yeah. That note's been there since Tuesday. I wasn't going to argue with it.",
					choicesFrom = "SAM-HUB",
				},
				["SAM-BYE"] = {
					id = "SAM-BYE",
					speaker = "Sam Okafor",
					text = "Sure. I'll be... here. Obviously.",
				},
			},
		},

		----------------------------------------------------------------
		-- Mara Reyes: grieving, guarded, sharp when pushed. She lies about
		-- the call out of guilt, not guilt of the crime.
		----------------------------------------------------------------
		{
			suspectId = "SUS-001",
			startNodeId = "MARA-OPEN",
			entries = {
				{ node = "MARA-COLD", requires = { knows("Flag", "mara_upset") } },
				{ node = "MARA-AFTER", requires = { knows("Statement", "STMT-SUS-001-VICTOR") } },
				{ node = "MARA-AGAIN", requires = { knows("Flag", "mara_met") } },
			},
			nodes = {
				["MARA-OPEN"] = {
					id = "MARA-OPEN",
					speaker = "Mara Reyes",
					text = "They told me to wait here. So I'm waiting.",
					next = "MARA-OPEN-2",
					setFlags = { "mara_met" },
				},
				["MARA-OPEN-2"] = {
					id = "MARA-OPEN-2",
					speaker = "Mara Reyes",
					text = "Nobody will tell me anything. Only that I can't see him.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-AGAIN"] = {
					id = "MARA-AGAIN",
					speaker = "Mara Reyes",
					text = "You're back.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-AFTER"] = {
					id = "MARA-AFTER",
					speaker = "Mara Reyes",
					text = "I keep looking at that phone. As if it'll ring again.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-HUB"] = {
					id = "MARA-HUB",
					speaker = "Mara Reyes",
					text = "What is it?",
					choices = {
						ask("sorry", "I'm sorry about Daniel.", "MARA-SORRY-1", nil, true),
						ask(
							"where",
							"Where were you tonight?",
							"MARA-WHERE-1",
							{ lacks("Statement", "STMT-SUS-001-ALIBI") }
						),
						ask("last", "When did you last speak to him?", "MARA-LAST-1", nil, true),
						ask("victor", "Tell me about Victor.", "MARA-VICTOR-1", { lacks("Evidence", "EV-002") }, true),
						ask(
							"dissolve",
							"Did you know Daniel was ending the partnership?",
							"MARA-DISSOLVE-1",
							{ knows("Evidence", "EV-002"), lacks("Statement", "STMT-SUS-001-MOTIVE") }
						),
						show("show", "Can you look at something for me?", "Show Mara…", "MARA-SHOW-NOTHING", {
							{
								-- Her alibi against the phone: the call was
								-- declined, not missed.
								evidence = "EV-001",
								next = "MARA-CALL-0",
								requires = {
									knows("Statement", "STMT-SUS-001-ALIBI"),
									lacks("Statement", "STMT-SUS-001-VICTOR"),
								},
								claims = "CONTRA-003",
							},
							{
								evidence = "EV-001",
								next = "MARA-PHONE-KNOWN",
								requires = { knows("Statement", "STMT-SUS-001-VICTOR") },
							},
							{ evidence = "EV-001", next = "MARA-PHONE-EARLY" },
						}),
						ask("bye", "I'll let you be.", "MARA-BYE"),
					},
				},
				["MARA-SORRY-1"] = {
					id = "MARA-SORRY-1",
					speaker = "Mara Reyes",
					text = "Everyone keeps saying that.",
					next = "MARA-SORRY-2",
				},
				["MARA-SORRY-2"] = {
					id = "MARA-SORRY-2",
					speaker = "Mara Reyes",
					text = "...Thank you. I mean it. I just don't know what to do with my hands.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-WHERE-1"] = {
					id = "MARA-WHERE-1",
					speaker = "Mara Reyes",
					text = "Home. Asleep.",
					next = "MARA-WHERE-2",
				},
				["MARA-WHERE-2"] = {
					id = "MARA-WHERE-2",
					speaker = YOU,
					text = "Asleep?",
					isPlayer = true,
					next = "MARA-WHERE-3",
				},
				["MARA-WHERE-3"] = {
					id = "MARA-WHERE-3",
					speaker = "Mara Reyes",
					text = "Migraine. I took something. I was out by ten.",
					next = "MARA-WHERE-4",
				},
				["MARA-WHERE-4"] = {
					id = "MARA-WHERE-4",
					speaker = "Mara Reyes",
					text = "I never heard his call. I only saw it when the police woke me.",
					statementId = "STMT-SUS-001-ALIBI",
					choicesFrom = "MARA-HUB",
				},
				["MARA-LAST-1"] = {
					id = "MARA-LAST-1",
					speaker = "Mara Reyes",
					text = "He rang at seven to say he'd miss dinner. Again.",
					next = "MARA-LAST-2",
				},
				["MARA-LAST-2"] = {
					id = "MARA-LAST-2",
					speaker = "Mara Reyes",
					text = 'He sounded wound up. Said tonight he\'d finally "sort it out".',
					next = "MARA-LAST-3",
				},
				["MARA-LAST-3"] = {
					id = "MARA-LAST-3",
					speaker = "Mara Reyes",
					text = "I didn't ask what. I was tired of asking.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-VICTOR-1"] = {
					id = "MARA-VICTOR-1",
					speaker = "Mara Reyes",
					text = "Victor.",
					next = "MARA-VICTOR-2",
				},
				["MARA-VICTOR-2"] = {
					id = "MARA-VICTOR-2",
					speaker = "Mara Reyes",
					text = "Victor is why Daniel slept at that desk three nights a week.",
					next = "MARA-VICTOR-3",
				},
				["MARA-VICTOR-3"] = {
					id = "MARA-VICTOR-3",
					speaker = "Mara Reyes",
					text = "They built it together. Lately it felt like Daniel was the only one still building.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-DISSOLVE-1"] = {
					id = "MARA-DISSOLVE-1",
					speaker = "Mara Reyes",
					text = "...You found that.",
					next = "MARA-DISSOLVE-2",
				},
				["MARA-DISSOLVE-2"] = {
					id = "MARA-DISSOLVE-2",
					speaker = "Mara Reyes",
					text = "He'd talked about it for a year. I never thought he'd do it.",
					next = "MARA-DISSOLVE-3",
				},
				["MARA-DISSOLVE-3"] = {
					id = "MARA-DISSOLVE-3",
					speaker = "Mara Reyes",
					text = "Victor would never let him walk away clean. Daniel knew that. He used to say it like a joke.",
					statementId = "STMT-SUS-001-MOTIVE",
					choicesFrom = "MARA-HUB",
				},
				["MARA-CALL-0"] = {
					id = "MARA-CALL-0",
					speaker = YOU,
					text = "Your call wasn't missed. It was declined.",
					isPlayer = true,
					next = "MARA-CALL-1",
				},
				["MARA-PHONE-EARLY"] = {
					id = "MARA-PHONE-EARLY",
					speaker = "Mara Reyes",
					text = "That's his phone. ...Please put it away.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-PHONE-KNOWN"] = {
					id = "MARA-PHONE-KNOWN",
					speaker = "Mara Reyes",
					text = "I know what it says. I was the one holding the other end.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-SHOW-NOTHING"] = {
					id = "MARA-SHOW-NOTHING",
					speaker = "Mara Reyes",
					text = "I don't know what you want me to see.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-CALL-1"] = {
					id = "MARA-CALL-1",
					speaker = "Mara Reyes",
					text = "I—",
					next = "MARA-CALL-2",
				},
				["MARA-CALL-2"] = {
					id = "MARA-CALL-2",
					speaker = "Mara Reyes",
					text = "What are you saying?",
					choices = {
						ask("gentle", "Tell me what really happened with that call.", "MARA-ADMIT-1"),
						ask("harsh", "You were awake. Why lie to me?", "MARA-UPSET-1"),
					},
				},
				["MARA-ADMIT-1"] = {
					id = "MARA-ADMIT-1",
					speaker = "Mara Reyes",
					text = "...I was awake.",
					next = "MARA-ADMIT-2",
				},
				["MARA-ADMIT-2"] = {
					id = "MARA-ADMIT-2",
					speaker = "Mara Reyes",
					text = "We'd argued. At seven, on the phone. About him staying late. About Victor. It's always Victor.",
					next = "MARA-ADMIT-3",
				},
				["MARA-ADMIT-3"] = {
					id = "MARA-ADMIT-3",
					speaker = "Mara Reyes",
					text = "When his name came up I thought he was calling to apologise. I wanted him to wait until morning.",
					next = "MARA-ADMIT-4",
				},
				["MARA-ADMIT-4"] = {
					id = "MARA-ADMIT-4",
					speaker = "Mara Reyes",
					text = "So I pressed a button. So I wouldn't have to hear his voice.",
					statementId = "STMT-SUS-001-ADMISSION",
					next = "MARA-ADMIT-5",
				},
				["MARA-ADMIT-5"] = {
					id = "MARA-ADMIT-5",
					speaker = "Mara Reyes",
					text = 'At seven he told me Victor was coming back tonight. "To talk me out of it," he said.',
					statementId = "STMT-SUS-001-VICTOR",
					next = "MARA-ADMIT-6",
				},
				["MARA-ADMIT-6"] = {
					id = "MARA-ADMIT-6",
					speaker = "Mara Reyes",
					text = "I thought he was being dramatic.",
					choicesFrom = "MARA-HUB",
				},
				["MARA-UPSET-1"] = {
					id = "MARA-UPSET-1",
					speaker = "Mara Reyes",
					text = "Lie?",
					next = "MARA-UPSET-2",
				},
				["MARA-UPSET-2"] = {
					id = "MARA-UPSET-2",
					speaker = "Mara Reyes",
					text = "My husband is dead, and you want to talk about which button I pressed?",
					next = "MARA-UPSET-3",
				},
				["MARA-UPSET-3"] = {
					id = "MARA-UPSET-3",
					speaker = "Mara Reyes",
					text = "Leave me alone. Please. Just... give me a minute.",
					setFlags = { "mara_upset" },
				},
				["MARA-COLD"] = {
					id = "MARA-COLD",
					speaker = "Mara Reyes",
					text = "Come to call me a liar again?",
					choices = {
						ask("apologise", "I'm sorry. I need to understand that call.", "MARA-COLD-THAW"),
						ask("insist", "I need the truth, Mrs. Reyes.", "MARA-COLD-NO"),
					},
				},
				["MARA-COLD-THAW"] = {
					id = "MARA-COLD-THAW",
					speaker = "Mara Reyes",
					text = "...",
					clearFlags = { "mara_upset" },
					next = "MARA-ADMIT-1",
				},
				["MARA-COLD-NO"] = {
					id = "MARA-COLD-NO",
					speaker = "Mara Reyes",
					text = "Then you can wait for it.",
				},
				["MARA-BYE"] = {
					id = "MARA-BYE",
					speaker = "Mara Reyes",
					text = "Find out what happened to him. That's all I want from you.",
				},
			},
		},

		----------------------------------------------------------------
		-- Victor Lane: polished, overconfident, impatient. Lies, then
		-- revises the lie when cornered, then breaks.
		----------------------------------------------------------------
		{
			suspectId = "SUS-002",
			startNodeId = "VIC-OPEN",
			entries = {
				{ node = "VIC-DONE", requires = { knows("Statement", "STMT-SUS-002-BREAK") } },
				{ node = "VIC-AGAIN", requires = { knows("Flag", "victor_met") } },
			},
			nodes = {
				["VIC-OPEN"] = {
					id = "VIC-OPEN",
					speaker = "Victor Lane",
					text = "Detective.",
					next = "VIC-OPEN-2",
					setFlags = { "victor_met" },
				},
				["VIC-OPEN-2"] = {
					id = "VIC-OPEN-2",
					speaker = "Victor Lane",
					text = "I've given your officers a statement. I'd like to go home at some point tonight.",
					choicesFrom = "VIC-HUB",
				},
				["VIC-AGAIN"] = {
					id = "VIC-AGAIN",
					speaker = "Victor Lane",
					text = "Again? Fine. Quickly.",
					choicesFrom = "VIC-HUB",
				},
				["VIC-HUB"] = {
					id = "VIC-HUB",
					speaker = "Victor Lane",
					text = "Well?",
					choices = {
						ask(
							"left",
							"When did you leave tonight?",
							"VIC-LEFT-1",
							{ lacks("Statement", "STMT-SUS-002-ALIBI") }
						),
						ask(
							"confirm",
							"Can anyone confirm that?",
							"VIC-CONFIRM-1",
							{ knows("Statement", "STMT-SUS-002-ALIBI"), lacks("Statement", "STMT-SUS-002-CAMERAS") }
						),
						ask(
							"partner",
							"How were things with Daniel?",
							"VIC-FINE-1",
							{ lacks("Evidence", "EV-002") },
							true
						),
						ask(
							"dissolve",
							"Daniel was dissolving the partnership. Tonight.",
							"VIC-DISSOLVE-1",
							{ knows("Evidence", "EV-002") },
							true
						),
						show("show", "Take a look at this.", "Show Victor…", "VIC-SHOW-NOTHING", {
							{
								-- "Half ten" against the badge log.
								evidence = "EV-004",
								next = "VIC-BADGE-0",
								requires = {
									knows("Statement", "STMT-SUS-002-ALIBI"),
									lacks("Statement", "STMT-SUS-002-REVISED"),
								},
								claims = "CONTRA-001",
							},
							{
								-- "On the phone, laughing" against the phone.
								evidence = "EV-001",
								next = "VIC-CONF-0",
								requires = { knows("Statement", "STMT-SUS-002-REVISED") },
								claims = "CONTRA-002",
							},
							{
								-- "Pull the footage" against his own note.
								evidence = "EV-007",
								next = "VIC-CAM-0",
								requires = {
									knows("Statement", "STMT-SUS-002-CAMERAS"),
									lacks("Flag", "vic_cameras_shown"),
								},
								claims = "CONTRA-004",
							},
							{
								evidence = "EV-004",
								next = "VIC-SHOW-AGAIN",
								requires = { knows("Statement", "STMT-SUS-002-REVISED") },
							},
							{
								evidence = "EV-007",
								next = "VIC-SHOW-AGAIN",
								requires = { knows("Flag", "vic_cameras_shown") },
							},
						}),
						ask("bye", "That's all.", "VIC-BYE"),
					},
				},
				["VIC-LEFT-1"] = {
					id = "VIC-LEFT-1",
					speaker = "Victor Lane",
					text = "Half ten. Give or take.",
					next = "VIC-LEFT-2",
				},
				["VIC-LEFT-2"] = {
					id = "VIC-LEFT-2",
					speaker = "Victor Lane",
					text = "Daniel was still at his desk. Working late, like always. He liked an audience for it.",
					next = "VIC-LEFT-3",
				},
				["VIC-LEFT-3"] = {
					id = "VIC-LEFT-3",
					speaker = "Victor Lane",
					text = "Whatever happened, it happened after I'd gone.",
					statementId = "STMT-SUS-002-ALIBI",
					choicesFrom = "VIC-HUB",
				},
				["VIC-CONFIRM-1"] = {
					id = "VIC-CONFIRM-1",
					speaker = "Victor Lane",
					text = "Sam saw me go. Ask him.",
					next = "VIC-CONFIRM-2",
				},
				["VIC-CONFIRM-2"] = {
					id = "VIC-CONFIRM-2",
					speaker = "Victor Lane",
					text = "And if that's not good enough, pull the lobby footage. The cameras will tell you what I'm telling you.",
					statementId = "STMT-SUS-002-CAMERAS",
					choicesFrom = "VIC-HUB",
				},
				["VIC-FINE-1"] = {
					id = "VIC-FINE-1",
					speaker = "Victor Lane",
					text = "Fine. Good. Fifteen years good.",
					next = "VIC-FINE-2",
				},
				["VIC-FINE-2"] = {
					id = "VIC-FINE-2",
					speaker = "Victor Lane",
					text = "Every partnership has arguments. Ours had fewer than most.",
					choicesFrom = "VIC-HUB",
				},
				["VIC-DISSOLVE-1"] = {
					id = "VIC-DISSOLVE-1",
					speaker = "Victor Lane",
					text = "...He'd been threatening that for a year.",
					next = "VIC-DISSOLVE-2",
				},
				["VIC-DISSOLVE-2"] = {
					id = "VIC-DISSOLVE-2",
					speaker = "Victor Lane",
					text = "It was a negotiating tactic. Daniel loved a gesture. Midnight signings. Honestly.",
					next = "VIC-DISSOLVE-3",
				},
				["VIC-DISSOLVE-3"] = {
					id = "VIC-DISSOLVE-3",
					speaker = "Victor Lane",
					text = "I wasn't going to be there. I'd gone home.",
					choicesFrom = "VIC-HUB",
				},
				["VIC-SHOW-NOTHING"] = {
					id = "VIC-SHOW-NOTHING",
					speaker = "Victor Lane",
					text = "And? Am I supposed to be impressed?",
					choicesFrom = "VIC-HUB",
				},
				["VIC-SHOW-AGAIN"] = {
					id = "VIC-SHOW-AGAIN",
					speaker = "Victor Lane",
					text = "You've shown me that. It didn't improve the second time.",
					choicesFrom = "VIC-HUB",
				},
				["VIC-CAM-0"] = {
					id = "VIC-CAM-0",
					speaker = YOU,
					text = "The cameras have been dark since Tuesday. Your note's on the monitor.",
					isPlayer = true,
					setFlags = { "vic_cameras_shown" },
					next = "VIC-CAM-1",
				},
				["VIC-CAM-1"] = {
					id = "VIC-CAM-1",
					speaker = "Victor Lane",
					text = "Did I write that?",
					next = "VIC-CAM-2",
				},
				["VIC-CAM-2"] = {
					id = "VIC-CAM-2",
					speaker = "Victor Lane",
					text = "I sign forty things a week, detective. I don't memorise them.",
					choicesFrom = "VIC-HUB",
				},
				["VIC-BADGE-0"] = {
					id = "VIC-BADGE-0",
					speaker = YOU,
					text = "Your badge came back in at 11:04. It left at 11:52.",
					isPlayer = true,
					next = "VIC-BADGE-1",
				},
				["VIC-BADGE-1"] = {
					id = "VIC-BADGE-1",
					speaker = "Victor Lane",
					text = "Then the system's wrong.",
					next = "VIC-BADGE-2",
				},
				["VIC-BADGE-2"] = {
					id = "VIC-BADGE-2",
					speaker = YOU,
					text = "Twice?",
					isPlayer = true,
					next = "VIC-BADGE-3",
				},
				["VIC-BADGE-3"] = {
					id = "VIC-BADGE-3",
					speaker = "Victor Lane",
					text = "...",
					next = "VIC-BADGE-4",
				},
				["VIC-BADGE-4"] = {
					id = "VIC-BADGE-4",
					speaker = "Victor Lane",
					text = "Fine. I came back. I'd left my charger. Ten minutes, in and out.",
					next = "VIC-BADGE-5",
				},
				["VIC-BADGE-5"] = {
					id = "VIC-BADGE-5",
					speaker = "Victor Lane",
					text = "He was alive when I left. On the phone. Laughing, for God's sake.",
					statementId = "STMT-SUS-002-REVISED",
					choicesFrom = "VIC-HUB",
				},
				["VIC-CONF-0"] = {
					id = "VIC-CONF-0",
					speaker = YOU,
					text = "That call never connected, Victor. She declined it.",
					isPlayer = true,
					next = "VIC-CONF-1",
				},
				["VIC-CONF-1"] = {
					id = "VIC-CONF-1",
					speaker = "Victor Lane",
					text = "Then he was on another call.",
					next = "VIC-CONF-2",
				},
				["VIC-CONF-2"] = {
					id = "VIC-CONF-2",
					speaker = YOU,
					text = "It was his last call. It rang for thirty seconds and she declined it. Nobody was laughing.",
					isPlayer = true,
					next = "VIC-CONF-3",
				},
				["VIC-CONF-3"] = {
					id = "VIC-CONF-3",
					speaker = "Victor Lane",
					text = "...",
					next = "VIC-CONF-4",
				},
				["VIC-CONF-4"] = {
					id = "VIC-CONF-4",
					speaker = "Victor Lane",
					text = "What do you want me to say?",
					next = "VIC-CONF-5",
				},
				["VIC-CONF-5"] = {
					id = "VIC-CONF-5",
					speaker = "Victor Lane",
					text = "That I stood in that office and watched him throw away fifteen years because he was tired of me?",
					next = "VIC-CONF-6",
				},
				["VIC-CONF-6"] = {
					id = "VIC-CONF-6",
					speaker = "Victor Lane",
					text = "He wouldn't listen. He never listened.",
					next = "VIC-CONF-7",
				},
				["VIC-CONF-7"] = {
					id = "VIC-CONF-7",
					speaker = "Victor Lane",
					text = "...I'd like a lawyer now.",
					statementId = "STMT-SUS-002-BREAK",
				},
				["VIC-DONE"] = {
					id = "VIC-DONE",
					speaker = "Victor Lane",
					text = "I've said all I'm saying without a lawyer.",
				},
				["VIC-BYE"] = {
					id = "VIC-BYE",
					speaker = "Victor Lane",
					text = "Good.",
				},
			},
		},
	},

	-- What people said, as the Case File records it. Alibi statements
	-- resolve their text from the suspect's own `alibi` (no `text` here).
	statements = {
		{ id = "STMT-SUS-001-ALIBI", suspectId = "SUS-001", label = "Alibi" },
		{
			id = "STMT-SUS-001-MOTIVE",
			suspectId = "SUS-001",
			label = "On Victor",
			text = '"Victor would never let him walk away clean. Daniel knew that."',
		},
		{
			id = "STMT-SUS-001-ADMISSION",
			suspectId = "SUS-001",
			label = "The Call",
			text = '"I was awake. I saw his name and I pressed a button." She declined the 11:47 call after an argument.',
		},
		{
			id = "STMT-SUS-001-VICTOR",
			suspectId = "SUS-001",
			label = "What Daniel Told Her",
			text = 'Daniel said Victor was coming back tonight "to talk me out of it."',
		},
		{ id = "STMT-SUS-002-ALIBI", suspectId = "SUS-002", label = "Alibi" },
		{
			id = "STMT-SUS-002-CAMERAS",
			suspectId = "SUS-002",
			label = "The Footage",
			text = '"Pull the lobby footage. The cameras will tell you what I\'m telling you."',
		},
		{
			id = "STMT-SUS-002-REVISED",
			suspectId = "SUS-002",
			label = "Revised Story",
			text = '"Fine. I came back. Ten minutes." Says Daniel was alive, on the phone, laughing when he left.',
		},
		{
			id = "STMT-SUS-002-BREAK",
			suspectId = "SUS-002",
			label = "Cornered",
			text = '"I stood in that office and watched him throw away fifteen years." Then he asked for a lawyer.',
		},
		{
			id = "STMT-SUS-003-FOUND",
			suspectId = "SUS-003",
			label = "Finding Him",
			text = "Found Daniel at 12:10 AM on his rounds. The office light was on.",
		},
		{
			id = "STMT-SUS-003-VICTOR",
			suspectId = "SUS-003",
			label = "Victor Leaving",
			text = "Victor said goodnight around ten. Sam never saw him actually leave.",
		},
		{
			id = "STMT-SUS-003-CAMERAS",
			suspectId = "SUS-003",
			label = "The Cameras",
			text = "All four lobby cameras dark since Tuesday. Victor told him not to call anyone out.",
		},
		{
			id = "STMT-SUS-003-COFFEE",
			suspectId = "SUS-003",
			label = "Daniel's Coffee",
			text = "Daniel didn't drink coffee at night, but made one for whoever he kept late.",
		},
	},

	contradictions = {
		{
			-- Opportunity: Victor's own account against the badge log.
			id = "CONTRA-001",
			claim = true,
			label = "Half Past Ten",
			left = { kind = "Statement", id = "STMT-SUS-002-ALIBI" },
			right = { kind = "Evidence", id = "EV-004" },
			reason = "Victor says he left at half ten. His badge came back in at 11:04 PM and left at 11:52, "
				.. "five minutes after Daniel's last call.",
		},
		{
			-- The revised story breaks against the phone itself.
			id = "CONTRA-002",
			claim = true,
			label = "A Call That Never Connected",
			left = { kind = "Statement", id = "STMT-SUS-002-REVISED" },
			right = { kind = "Evidence", id = "EV-001" },
			reason = "Victor says Daniel was laughing on the phone when he left. Daniel's last call rang out "
				.. "and was declined. It never connected.",
		},
		{
			-- The red herring: real, and innocent.
			id = "CONTRA-003",
			claim = true,
			label = "Mara's Missed Call",
			left = { kind = "Statement", id = "STMT-SUS-001-ALIBI" },
			right = { kind = "Evidence", id = "EV-001" },
			reason = "Mara says she never heard the call. It wasn't missed. Someone declined it.",
		},
		{
			id = "CONTRA-004",
			claim = true,
			label = "The Footage",
			left = { kind = "Statement", id = "STMT-SUS-002-CAMERAS" },
			right = { kind = "Evidence", id = "EV-007" },
			reason = "Victor told you to pull the lobby footage. His own note kept the cameras dark.",
		},
	},

	deductions = {
		{
			-- Mara's lead and the badge log agree.
			id = "DEDUCT-001",
			label = "Victor Came Back",
			requiredFacts = {
				{ kind = "Statement", id = "STMT-SUS-001-VICTOR" },
				{ kind = "Evidence", id = "EV-004" },
			},
			question = {
				prompt = "Who came back to the office tonight, and why?",
				options = {
					{ id = "sam", text = "Sam, finishing his rounds." },
					{ id = "victor", text = "Victor, to talk Daniel out of signing." },
					{ id = "mara", text = "Mara, to have it out with Daniel." },
					{ id = "fault", text = "Nobody. The badge system is wrong." },
				},
				answer = "victor",
			},
		},
		{
			-- Motive: the draft on the laptop and the midnight agenda.
			id = "DEDUCT-002",
			label = "Daniel Was Ending the Partnership",
			requiredFacts = {
				{ kind = "Evidence", id = "EV-002" },
				{ kind = "Evidence", id = "EV-003" },
			},
			question = {
				prompt = "What was the midnight meeting for?",
				options = {
					{ id = "client", text = "A late call with a client abroad." },
					{ id = "dissolve", text = "Signing the end of Reyes & Lane." },
					{ id = "resign", text = "Daniel handing in his notice." },
					{ id = "mara", text = "Making it up to Mara." },
				},
				answer = "dissolve",
			},
		},
		{
			id = "DEDUCT-003",
			label = "Daniel Wasn't Alone",
			requiredFacts = {
				{ kind = "Evidence", id = "EV-005" },
				{ kind = "Evidence", id = "EV-006" },
			},
			question = {
				prompt = "Two espressos at 11:31, and a half-finished cup on the visitor's side. What does that say?",
				options = {
					{ id = "awake", text = "Daniel drank both to stay awake." },
					{ id = "visitor", text = "Someone sat with Daniel late tonight." },
					{ id = "earlier", text = "The cups were left from the afternoon." },
					{ id = "sam", text = "Sam brought him one on his rounds." },
				},
				answer = "visitor",
			},
		},
		{
			id = "DEDUCT-004",
			label = "Victor Was There at the End",
			requiredFacts = {
				{ kind = "Statement", id = "STMT-SUS-002-BREAK" },
				{ kind = "Evidence", id = "EV-004" },
			},
			question = {
				prompt = "Victor has stopped talking. When did he really leave?",
				options = {
					{ id = "ten", text = "Half past ten, as he said." },
					{ id = "after", text = "11:52, minutes after Daniel's last call." },
					{ id = "midnight", text = "Just after midnight, before Sam's rounds." },
					{ id = "never", text = "He never left the building." },
				},
				answer = "after",
			},
		},
	},

	-- Who may be formally accused. `supportedBy` names the reasoning that
	-- points at a suspect; `motives`/`proofs` (M9) are the motive and proof
	-- that make the case hold. The verdict itself comes from `solution`.
	-- Sam is not accusable. Accusing opens once the partner and the wife
	-- have both been spoken to (OBJ-002), with the rest still to find.
	accusationRules = { opensAfter = "OBJ-002", requiresCase = true },
	accusations = {
		{
			id = "ACC-001",
			suspectId = "SUS-002",
			label = "Accuse Victor Lane",
			supportedBy = {
				contradictions = { "CONTRA-001", "CONTRA-002" },
				deductions = { "DEDUCT-001", "DEDUCT-002", "DEDUCT-004" },
			},
			-- Why: the dissolution, or coming back to stop it. What proves
			-- it: either lie about the last hour. The cameras alone say he
			-- planned to be unseen, not that he was there.
			motives = { "DEDUCT-002", "DEDUCT-001" },
			proofs = { "CONTRA-001", "CONTRA-002" },
		},
		{
			id = "ACC-002",
			suspectId = "SUS-001",
			label = "Accuse Mara Reyes",
			supportedBy = {
				contradictions = { "CONTRA-003" },
			},
			wrongEpilogue = "Mara Reyes is charged at four in the morning. She doesn't say a word in the car. "
				.. "Three weeks later the case against her comes apart, and by then Victor Lane is running "
				.. "Reyes & Lane on his own.",
		},
	} :: { Types.AccusationDefinition },

	-- Server-only (this module lives in ServerStorage). Revealed at the close.
	solution = {
		culpritSuspectId = "SUS-002",
		reveal = "Victor Lane never went home. His badge came back in at 11:04 PM, to stop Daniel signing "
			.. "the papers that would end their partnership. Daniel made two coffees and tried to talk him "
			.. "down. At 11:47 he called Mara. She was awake, still angry, and let it ring. Minutes later "
			.. "Daniel was dead, and at 11:52 Victor's badge was the last to leave. He had known since "
			.. "Tuesday that no camera would see him go.",
		solvedEpilogue = "Victor Lane is charged before sunrise. The dissolution papers are still on "
			.. "Daniel's desk, unsigned, where he left them.",
		unprovenEpilogue = "Victor Lane walks out at three in the morning with his lawyer. You know what "
			.. "happened in that office. You couldn't make it hold.",
	},
}

return Case001
