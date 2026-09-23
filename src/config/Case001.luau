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
			-- No npcPlacement: not a playable suspect yet (Phase 2G is a
			-- one-suspect vertical slice).
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
	},

	-- Phase 2G vertical slice: one suspect, one deterministic linear
	-- conversation. Every line either uses SUS-001's already-authored name
	-- (speaker attribution) or its already-authored alibi (the only real
	-- informational content revealed). The opening and closing lines are
	-- minimal procedural framing carrying no case facts of their own.
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
	},

	-- STMT-SUS-001-ALIBI has no separate text of its own: ConversationService
	-- resolves its content from SUS-001's authored `alibi` field at unlock
	-- time, so the statement can never drift from the suspect data.
	statements = {
		{
			id = "STMT-SUS-001-ALIBI",
			suspectId = "SUS-001",
			label = "Alibi",
		},
	},

	-- Phase 2H audit: CASE-001 does not yet contain two independently
	-- discoverable facts that genuinely conflict, nor a conclusion
	-- expressible without authoring new narrative prose. SUS-002's alibi
	-- text ("Keycard log suggests otherwise") hints at a contradiction, but
	-- the "keycard log" is only a phrase inside that one alibi string -- not
	-- a separate, independently discoverable, ID-referenceable fact -- and
	-- SUS-002 has no conversation to unlock anything from at all. Left
	-- empty deliberately rather than manufactured; see ARCHITECTURE.md and
	-- ReasoningService_Test.luau's synthetic fixture for the proven
	-- contract.
	contradictions = {},
	deductions = {},
}

return Case001
