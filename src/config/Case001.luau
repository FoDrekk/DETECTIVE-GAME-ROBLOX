--!strict
--[[
	Case001 — THE LAST CALL
	Placeholder investigative data for the first case.
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
			alibi = "Claims she was asleep at home; phone records are unverified.",
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
			alibi = "Says he left the office at 22:30. Keycard log suggests otherwise.",
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

	evidence = {
		{
			id = "EV-001",
			name = "Phone",
			description = "Daniel's phone was left on the desk.",
			details = "The last outgoing call was made at 11:47 PM.",
			location = "Daniel's Workspace",
			importance = "Critical",
			category = "Communication",
			timestamp = "11:47 PM",
			timelineEventId = "TIMELINE-002",
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
			-- OfficeRoom.luau's evidence-prop spawner).
			propPlacement = {
				position = Vector3.new(24, 3, 15.5),
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
	},

	-- Phase 2G/2I: one deterministic linear conversation per playable suspect.
	-- Every line either uses the suspect's already-authored name (speaker
	-- attribution) or its already-authored alibi (the only real informational
	-- content revealed). The opening and closing lines are minimal procedural
	-- framing carrying no case facts of their own, reused verbatim across
	-- both suspects for exactly that reason.
	conversations = {
		{
			suspectId = "SUS-001",
			startNodeId = "SUS-001-1",
			nodes = {
				["SUS-001-1"] = {
					id = "SUS-001-1",
					speaker = "Mara Reyes",
					text = "What do you want to know?",
					next = "SUS-001-2",
				},
				["SUS-001-2"] = {
					id = "SUS-001-2",
					speaker = "Mara Reyes",
					text = "Claims she was asleep at home; phone records are unverified.",
					next = "SUS-001-3",
					statementId = "STMT-SUS-001-ALIBI",
				},
				["SUS-001-3"] = {
					id = "SUS-001-3",
					speaker = "Mara Reyes",
					text = "That's all I have to say.",
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
					text = "What do you want to know?",
					next = "SUS-002-2",
				},
				["SUS-002-2"] = {
					id = "SUS-002-2",
					speaker = "Victor Lane",
					text = "Says he left the office at 22:30. Keycard log suggests otherwise.",
					next = "SUS-002-3",
					statementId = "STMT-SUS-002-ALIBI",
				},
				["SUS-002-3"] = {
					id = "SUS-002-3",
					speaker = "Victor Lane",
					text = "That's all I have to say.",
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
	deductions = {},
}

return Case001
