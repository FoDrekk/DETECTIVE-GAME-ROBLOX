--!strict
--[[
	Case001 — THE LAST CALL
	Investigative data for the first case.
	Pure data only: no gameplay logic belongs here.
]]

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Case001: Types.CaseDefinition = {
	id = "CASE-001",
	title = "THE LAST CALL",
	description = "Daniel Reyes was found dead in his office shortly after 23:00. "
		.. "A single unanswered call was placed minutes before his death. "
		.. "Determine what happened.",

	suspects = {
		{
			id = "SUS-001",
			name = "Mara Reyes",
			role = "Spouse",
			alibi = "I was home and asleep. I know the phone records don't back that up.",
			-- Standing near the meeting table, waiting to be questioned.
			-- Technical staging only -- no new location or story fact.
			npcPlacement = {
				position = Vector3.new(16.5, 3, -19),
				lookAt = Vector3.new(20, 3, -14),
			},
		},
		{
			id = "SUS-002",
			name = "Victor Lane",
			role = "Business Partner",
			alibi = "I left the office at half ten. Whatever the keycard log says, I was gone by then.",
			-- Standing at the opposite side of the meeting table from Mara,
			-- facing its center. Technical staging only, in the same room --
			-- no new location or story fact (Phase 2I).
			npcPlacement = {
				position = Vector3.new(24, 3, -17.5),
				lookAt = Vector3.new(20, 3, -14),
			},
		},
	},

	locations = {
		{
			id = "LOC-001",
			name = "Office",
			description = "Daniel's private office. Where the body was discovered.",
		},
	},

	-- Phase 2O: authored flavour text for the office's non-evidence
	-- interactables, applied at runtime by instance name (OfficeRoom).
	-- Atmosphere only -- these objects carry no evidence, and every line
	-- stays inside the case's already-authored facts (Daniel found dead
	-- shortly after 23:00; an unanswered call minutes before his death).
	-- No motive, culprit, or new event is stated or implied.
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
			details = "The last outgoing call was made at 11:47 PM. It went unanswered.",
			location = "Daniel's Workspace",
			importance = "Critical",
			category = "Communication",
			timestamp = "11:47 PM",
			timelineEventId = "TIMELINE-002",
			-- Phase 2O: the phone and the laptop both record activity at
			-- Daniel's workspace minutes apart (11:47 PM and 11:42 PM), which
			-- is the only evidence-to-evidence relationship CASE-001's authored
			-- facts actually support. A mutual link, surfaced once both are found.
			relatedEvidenceIds = { "EV-002" },
		},
		{
			id = "EV-002",
			name = "Laptop",
			description = "Daniel's laptop was left open.",
			details = "A work document was modified at 11:42 PM.",
			location = "Daniel's Workspace",
			importance = "High",
			category = "Digital Activity",
			timestamp = "11:42 PM",
			timelineEventId = "TIMELINE-001",
			-- Phase 2O: see EV-001 -- the same workspace, minutes earlier.
			relatedEvidenceIds = { "EV-001" },
		},
		{
			id = "EV-003",
			name = "Document",
			description = "A meeting document was left on Daniel's desk.",
			details = "It indicates a meeting scheduled for 12:00 AM.",
			location = "Daniel's Workspace",
			importance = "Medium",
			category = "Document",
			timestamp = "12:00 AM",
			timelineEventId = "TIMELINE-003",
		},
		{
			-- Phase 2I: the independently discoverable access record already
			-- implied by SUS-002's own authored alibi ("Keycard log suggests
			-- otherwise"). No new timestamp is invented for it: `details`
			-- states only that the record disagrees with Victor's own
			-- already-authored claim, and stays silent on what it actually
			-- shows. No timelineEventId/timestamp: a chronological timeline
			-- entry would require inventing a precise clock time this case
			-- does not specify anywhere.
			id = "EV-004",
			name = "Keycard Log",
			description = "A printed keycard access record for the office door.",
			details = "The recorded exit time does not match Victor Lane's stated departure of 22:30.",
			location = "Reception",
			importance = "High",
			category = "Security",
			-- No hand-placed counterpart exists in the Studio-authored office
			-- asset; OfficeRoom spawns a minimal physical prop for it (see
			-- OfficeRoom.luau's evidence-prop spawner). Positioned close
			-- against the reception desk/panel cluster (Phase 2L-A office
			-- redesign) so it reads as an access-control terminal at the
			-- point of entry, without any change to what it means.
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
			title = "Laptop activity",
			description = "A work document was modified on Daniel's laptop.",
			sourceEvidenceIds = { "EV-002" },
		},
		{
			id = "TIMELINE-002",
			timestamp = "11:47 PM",
			timeMinutes = 1427,
			title = "Outgoing phone call",
			description = "The last outgoing call was made from Daniel's phone.",
			sourceEvidenceIds = { "EV-001" },
		},
		{
			id = "TIMELINE-003",
			timestamp = "12:00 AM",
			timeMinutes = 1440,
			title = "Scheduled meeting",
			description = "A meeting document indicates a meeting scheduled for 12:00 AM.",
			sourceEvidenceIds = { "EV-003" },
		},
	},

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
			-- Phase 2I: directs the player to the second suspect once the
			-- scene has been surveyed. Talk+target was already proven generic
			-- by a synthetic fixture in Phase 2F/2G; this is its first real
			-- use. `target` matches SUS-002's spawned NPC root part, which
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
			-- Phase 2J: gives CONTRA-001 a real gameplay consequence.
			-- Completes the moment the contradiction unlocks -- no further
			-- interaction required, no new evidence, no new dialogue.
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
			-- Phase 2M: gives DEDUCT-001 a real gameplay consequence, and in
			-- doing so closes a real gap -- nothing before this objective ever
			-- required speaking to Mara. Completes the moment the deduction
			-- unlocks, same pattern as OBJ-003 -- no further interaction
			-- required, no new evidence, no new dialogue.
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
	},

	-- Phase 2G/2I/2O: one deterministic linear conversation per playable
	-- suspect. Each suspect's one informational line is their already-authored
	-- `alibi`, spoken in their own voice; the opening and closing lines are
	-- minimal procedural framing carrying no case facts of their own. The two
	-- suspects are given distinct registers, but neither says anything the
	-- case data does not already state.
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
					text = "I was home and asleep. I know the phone records don't back that up.",
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
					text = "I left the office at half ten. Whatever the keycard log says, I was gone by then.",
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

	-- Neither statement has separate text of its own: ConversationService
	-- resolves each one's content from its suspect's authored `alibi` field
	-- at unlock time, so a statement can never drift from the suspect data.
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

	-- Phase 2I: the first real contradiction. Both referenced facts are
	-- already-authored content -- Victor's own alibi statement and the
	-- keycard log evidence's own `details` text -- neither is duplicated
	-- here, only referenced by id. See ARCHITECTURE.md for why CASE-001
	-- shipped zero of these through Phase 2H, and ReasoningService_Test.luau
	-- for the synthetic fixture that originally proved the mechanism before
	-- any real content existed.
	contradictions = {
		{
			id = "CONTRA-001",
			label = "Victor's Departure Time",
			left = { kind = "Statement", id = "STMT-SUS-002-ALIBI" },
			right = { kind = "Evidence", id = "EV-004" },
			reason = "Victor claims he left at 22:30; the keycard log does not match.",
		},
	},
	-- Phase 2M: the first real deduction. Unlike CONTRA-001, these facts don't
	-- need to conflict -- the deduction fires once all three are known. Every
	-- referenced fact is already-authored content (see STMT-SUS-001-ALIBI,
	-- STMT-SUS-002-ALIBI, EV-004 above); neither is duplicated here, only
	-- referenced by id. Deliberately includes Mara's statement alongside
	-- Victor's: nothing before this closes the gap where a player could
	-- conclude the case without ever speaking to her.
	deductions = {
		{
			id = "DEDUCT-001",
			label = "Both Accounts, One Contradiction",
			requiredFacts = {
				{ kind = "Statement", id = "STMT-SUS-001-ALIBI" },
				{ kind = "Statement", id = "STMT-SUS-002-ALIBI" },
				{ kind = "Evidence", id = "EV-004" },
			},
		},
	},
	-- Phase 2N: the two suspects the player may formally accuse once every
	-- objective is complete. This is not a verdict and invents no story fact:
	-- it only records which already-authored contradiction/deduction, if the
	-- player has actually unlocked it, makes that accusation consistent with
	-- the evidence they gathered. Victor is the suspect CONTRA-001 and
	-- DEDUCT-001 both speak to; Mara is the only other person in the case, so
	-- she is selectable but named by no authored contradiction or deduction.
	accusations = {
		{
			id = "ACC-001",
			suspectId = "SUS-002",
			label = "Accuse Victor Lane",
			supportedBy = {
				contradictions = { "CONTRA-001" },
				deductions = { "DEDUCT-001" },
			},
		},
		{
			id = "ACC-002",
			suspectId = "SUS-001",
			label = "Accuse Mara Reyes",
		},
	},
}

return Case001
