--!strict
--[[
	LegacyCase — a frozen copy of CASE-001 as it stood before the
	storytelling overhaul (linear dialogue, two suspects, four clues), kept as
	a unit-test fixture. The service tests were written against this exact
	graph; pinning them to a frozen copy keeps them testing the mechanics
	they were written for, while CASE-001's live content has its own tests
	(Case001_Test). Never loaded by the game (not under ServerStorage.Config).

	The story (M2 canon): Daniel Reyes was ending his partnership with Victor
	Lane; the papers were to be signed at a midnight meeting. Victor claims he
	left at 22:30, but he was still in the building when Daniel made his last,
	unanswered call to his wife Mara at 11:47 PM. Minutes later Daniel was
	dead, and Victor's badge was the last to leave at 11:52 PM. Daniel was
	found shortly after midnight. Mara, asleep at home, is innocent: her
	account is unverifiable, but nothing contradicts it.
]]

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local LegacyCase: Types.CaseDefinition = {
	id = "CASE-TEST-LEGACY",
	title = "THE LAST CALL",
	description = "Daniel Reyes was found dead in his office shortly after midnight. "
		.. "His last call, placed minutes before his death, went unanswered. "
		.. "Determine what happened.",

	suspects = {
		{
			id = "SUS-001",
			name = "Mara Reyes",
			role = "Spouse",
			alibi = "I was home, asleep. I never heard his call. I only saw it when your people woke me. "
				.. "No one can tell you I was there but me.",
			-- Standing near the meeting table, waiting to be questioned.
			npcPlacement = {
				position = Vector3.new(16.5, 3, -19),
				lookAt = Vector3.new(20, 3, -14),
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
			},
		},
		{
			id = "SUS-002",
			name = "Victor Lane",
			role = "Business Partner",
			alibi = "I left at half ten. Daniel was still at his desk, working late like always. "
				.. "Whatever happened, it happened after I'd gone.",
			-- Opposite side of the meeting table from Mara, facing its center.
			npcPlacement = {
				position = Vector3.new(24, 3, -17.5),
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
			},
		},
	},

	locations = {
		{
			id = "LOC-001",
			name = "Office",
			description = "Daniel's private office. Where the body was discovered.",
			-- M3: a nameplate beside the office door, mounted on the corridor
			-- side so it reads facing into the room from the approach. The
			-- victim's name is already public (stated in the case briefing
			-- every player reads first); this only makes it findable in the
			-- world. Technical staging, like npcPlacement/propPlacement.
			-- Part_Daniel_South_B spans Z -2.5..-1.5 (1-stud wall centered at
			-- -2); -1.45 sits the 0.06-thick plaque just proud of its
			-- corridor face instead of embedded inside it.
			signPlacement = {
				position = Vector3.new(-16.3, 5.5, -1.45),
				lookAt = Vector3.new(-16.3, 5.5, 6),
				text = "Daniel Reyes",
			},
		},
	},

	-- Phase 2O: authored flavour text for the office's non-evidence
	-- interactables, applied at runtime by instance name (OfficeRoom).
	-- Atmosphere only -- these objects carry no evidence and point at no one.
	observations = {
		{
			instanceName = "ReceptionDesk",
			text = "The reception desk is tidy, its chair pushed in. The visitor log lies closed. "
				.. "Nothing about the front of the office suggests anything hurried or out of place.",
		},
		{
			instanceName = "DeskDrawer",
			text = "The drawer slides open easily: pens, paperclips, a half-used notepad. Ordinary. "
				.. "Whatever mattered to this case was left in plain sight on the desk, not filed away.",
		},
		{
			instanceName = "FileCabinet_1",
			text = "Filing cabinet drawers, neatly labelled. Everything is where it should be. "
				.. "No drawer is open, nothing has been forced; the papers of the business are undisturbed.",
		},
		{
			instanceName = "Whiteboard",
			text = "The whiteboard carries the faint ghosts of meetings past -- schedules, initials, "
				.. "a diagram rubbed out and written over. Nothing on it points to the night in question.",
		},
		{
			instanceName = "CoffeeCup",
			text = "A coffee cup, long cold, left where it stood. Whoever last drank from it "
				.. "did not come back to finish it or to clear it away.",
		},
		{
			instanceName = "Pen",
			text = "A pen, laid down mid-thought rather than capped and put away. "
				.. "The small untidiness of someone interrupted, on an otherwise orderly desk.",
		},
		{
			instanceName = "Shelf_Frame",
			text = "The shelves are lined with binders and a few framed photographs of the business "
				.. "in better days. Office history, carefully kept. None of it speaks to tonight.",
		},
	},

	evidence = {
		{
			id = "EV-001",
			name = "Phone",
			description = "Daniel's phone was left on the desk.",
			details = "His last outgoing call, at 11:47 PM, was to Mara Reyes. It went unanswered.",
			location = "Daniel's Workspace",
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
			description = "Daniel's laptop was left open.",
			details = "A draft titled \"Reyes & Lane: dissolution of partnership\" was last saved at 11:42 PM.",
			location = "Daniel's Workspace",
			importance = "High",
			category = "Digital Activity",
			timestamp = "11:42 PM",
			timelineEventId = "TIMELINE-001",
			relatedEvidenceIds = { "EV-001" },
		},
		{
			id = "EV-003",
			name = "Document",
			description = "A meeting agenda was left on Daniel's desk.",
			details = "12:00 AM, with Victor Lane: \"Sign the dissolution. No more delays.\"",
			location = "Daniel's Workspace",
			importance = "Medium",
			category = "Document",
			timestamp = "12:00 AM",
			timelineEventId = "TIMELINE-003",
		},
		{
			id = "EV-004",
			name = "Keycard Log",
			description = "A printed keycard access record for the office door.",
			details = "The last badge to leave the building tonight was Victor Lane's, at 11:52 PM.",
			location = "Reception",
			importance = "High",
			category = "Security",
			timestamp = "11:52 PM",
			timelineEventId = "TIMELINE-004",
			-- No hand-placed counterpart exists in the Studio-authored office
			-- asset; OfficeRoom spawns a minimal physical prop for it, next to
			-- the reception desk at the point of entry.
			propPlacement = {
				position = Vector3.new(24, 3, 16.5),
				lookAt = Vector3.new(24, 3, 20),
			},
		},
	},

	timeline = {
		{
			id = "TIMELINE-001",
			timestamp = "11:42 PM",
			timeMinutes = 1422,
			title = "Partnership draft saved",
			description = "Daniel saves a draft dissolving his partnership with Victor Lane.",
			sourceEvidenceIds = { "EV-002" },
		},
		{
			id = "TIMELINE-002",
			timestamp = "11:47 PM",
			timeMinutes = 1427,
			title = "The last call",
			description = "Daniel calls Mara. She does not answer.",
			sourceEvidenceIds = { "EV-001" },
		},
		{
			id = "TIMELINE-004",
			timestamp = "11:52 PM",
			timeMinutes = 1432,
			title = "Victor Lane leaves",
			description = "Victor Lane's badge is the last to exit the building.",
			sourceEvidenceIds = { "EV-004" },
		},
		{
			id = "TIMELINE-003",
			timestamp = "12:00 AM",
			timeMinutes = 1440,
			title = "The midnight meeting",
			description = "Daniel was due to meet Victor Lane to sign the dissolution.",
			sourceEvidenceIds = { "EV-003" },
		},
	},

	-- M5: the order a not-yet-reconstructed timeline presents its events in.
	-- Deliberately NOT chronological (canonical: 11:42 -> 11:47 -> 11:52 ->
	-- 12:00), so putting the night in order is a real step the player must
	-- perform. The `timeline` array above stays readable in chronological
	-- order; this only controls the puzzle's presentation.
	timelineChallengeOrder = { "TIMELINE-004", "TIMELINE-001", "TIMELINE-003", "TIMELINE-002" },

	objectives = {
		{
			id = "OBJ-001",
			title = "Investigate Daniel's office",
			description = "Survey the scene and catalogue the key items on the desk.",
			requiredEvidence = { "EV-001", "EV-002", "EV-003" },
			requiredInteractions = { "EV-001", "EV-002", "EV-003" },
			requirements = {
				{ id = "REQ-001", label = "Inspect the phone", evidence = "EV-001" },
				{ id = "REQ-002", label = "Inspect the laptop", evidence = "EV-002" },
				{ id = "REQ-003", label = "Read the document", interaction = "Read", evidence = "EV-003" },
			},
		},
		{
			-- `target` matches SUS-002's spawned NPC root part, which
			-- SuspectSpawner names after the suspect id.
			id = "OBJ-002",
			title = "Question Victor Lane",
			description = "Find and speak with Daniel's business partner.",
			requiredEvidence = {},
			requiredInteractions = { "Talk" },
			requirements = {
				{ id = "REQ-004", label = "Talk to Victor Lane", interaction = "Talk", target = "SUS-002" },
			},
			prerequisites = { "OBJ-001" },
		},
		{
			-- Completes the moment CONTRA-001 unlocks.
			id = "OBJ-003",
			title = "Review Victor Lane's Statement",
			description = "Cross-reference what Victor said against the evidence you've found.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{ id = "REQ-005", label = "Review the contradiction in his account", contradiction = "CONTRA-001" },
			},
			prerequisites = { "OBJ-002" },
		},
		{
			-- Completes the moment DEDUCT-001 unlocks, which requires Mara's
			-- statement: no one concludes the case without hearing her.
			id = "OBJ-004",
			title = "Close the Investigation",
			description = "Make sure both suspects have given their account before drawing conclusions.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{
					id = "REQ-006",
					label = "Weigh both suspects' statements against the evidence",
					deduction = "DEDUCT-001",
				},
			},
			prerequisites = { "OBJ-003" },
		},
		{
			-- M5: the timeline is a mechanic, not decoration. The player must
			-- put the discovered events in order themselves; the server accepts
			-- only the canonical chronological order. This is the last step
			-- before an accusation can be made.
			id = "OBJ-005",
			title = "Reconstruct the Timeline",
			description = "Open the case timeline and put the events in the order they happened.",
			requiredEvidence = {},
			requiredInteractions = {},
			requirements = {
				{
					id = "REQ-007",
					label = "Establish the sequence of events",
					timelineEstablished = true,
				},
			},
			prerequisites = { "OBJ-004" },
		},
	},

	-- One linear conversation per suspect. Each suspect's informational line
	-- is their `alibi`, spoken in their own voice; the opening and closing
	-- lines are framing only.
	conversations = {
		{
			suspectId = "SUS-001",
			startNodeId = "SUS-001-1",
			nodes = {
				["SUS-001-1"] = {
					id = "SUS-001-1",
					speaker = "Mara Reyes",
					text = "You're the one asking the questions, then. Go on.",
					next = "SUS-001-2",
				},
				["SUS-001-2"] = {
					id = "SUS-001-2",
					speaker = "Mara Reyes",
					text = "I was home, asleep. I never heard his call. I only saw it when your people woke me. "
						.. "No one can tell you I was there but me.",
					next = "SUS-001-3",
					statementId = "STMT-SUS-001-ALIBI",
				},
				["SUS-001-3"] = {
					id = "SUS-001-3",
					speaker = "Mara Reyes",
					text = "That's all I have to say to you.",
					next = nil,
				},
			},
		},
		{
			suspectId = "SUS-002",
			startNodeId = "SUS-002-1",
			nodes = {
				["SUS-002-1"] = {
					id = "SUS-002-1",
					speaker = "Victor Lane",
					text = "Let's keep this quick. I've told the police everything already.",
					next = "SUS-002-2",
				},
				["SUS-002-2"] = {
					id = "SUS-002-2",
					speaker = "Victor Lane",
					text = "I left at half ten. Daniel was still at his desk, working late like always. "
						.. "Whatever happened, it happened after I'd gone.",
					next = "SUS-002-3",
					statementId = "STMT-SUS-002-ALIBI",
				},
				["SUS-002-3"] = {
					id = "SUS-002-3",
					speaker = "Victor Lane",
					text = "I've said my piece. We're done here.",
					next = nil,
				},
			},
		},
	},

	-- Statement text is resolved from each suspect's `alibi` at unlock time,
	-- so a statement can never drift from the suspect data.
	statements = {
		{
			id = "STMT-SUS-001-ALIBI",
			suspectId = "SUS-001",
			label = "Alibi",
		},
		{
			id = "STMT-SUS-002-ALIBI",
			suspectId = "SUS-002",
			label = "Alibi",
		},
	},

	-- Opportunity: Victor's own account against the keycard log.
	contradictions = {
		{
			id = "CONTRA-001",
			label = "Victor's Departure Time",
			left = { kind = "Statement", id = "STMT-SUS-002-ALIBI" },
			right = { kind = "Evidence", id = "EV-004" },
			reason = "Victor says he left at half past ten. His badge left the building at 11:52 PM, "
				.. "five minutes after Daniel's last call.",
		},
	},

	deductions = {
		{
			-- Having heard both suspects: Mara's account cannot be verified,
			-- but only Victor's is contradicted by the evidence.
			id = "DEDUCT-001",
			label = "Only Victor's Account Breaks",
			requiredFacts = {
				{ kind = "Statement", id = "STMT-SUS-001-ALIBI" },
				{ kind = "Statement", id = "STMT-SUS-002-ALIBI" },
				{ kind = "Evidence", id = "EV-004" },
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
		},
	},

	-- The suspects the player may formally accuse once every objective is
	-- complete. `supportedBy` names the reasoning that points at a suspect;
	-- the verdict itself comes from `solution`.
	accusations = {
		{
			id = "ACC-001",
			suspectId = "SUS-002",
			label = "Accuse Victor Lane",
			supportedBy = {
				contradictions = { "CONTRA-001" },
				deductions = { "DEDUCT-001", "DEDUCT-002" },
			},
		},
		{
			id = "ACC-002",
			suspectId = "SUS-001",
			label = "Accuse Mara Reyes",
		},
	},

	-- Server-only (this module lives in ServerStorage). Revealed at the close.
	solution = {
		culpritSuspectId = "SUS-002",
		reveal = "Daniel spent his last evening finishing the papers that would end his partnership "
			.. "with Victor Lane, to be signed at midnight. Victor never left at half past ten. He was "
			.. "still in the building at 11:47 PM, when Daniel called Mara and she slept through it. "
			.. "Minutes later Daniel was dead, and at 11:52 PM Victor's badge was the last to leave "
			.. "the building. His alibi was the only one the evidence could break.",
	},
}

return LegacyCase
