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
		},
		{
			id = "SUS-002",
			name = "Victor Lane",
			role = "Business Partner",
			alibi = "Says he left the office at 22:30. Keycard log suggests otherwise.",
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
}

return Case001
