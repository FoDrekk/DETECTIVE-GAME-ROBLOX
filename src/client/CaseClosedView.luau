--!strict
--[[
	CaseClosedView
	Minimal cinematic closing overlay shown during the CaseClosed phase
	(Phase 2L). Mirrors CaseBriefingView's visual pattern.

	Purely presentational: renders only the factual Types.CaseClosedSummary
	the server sends once it accepts the player's own conclusion request. It
	never decides whether the investigation is actually complete, and never
	states or implies who did anything.

	Phase 2O: in addition to the counts, it now restates the case back to the
	player using only already-discovered facts -- the timeline they actually
	revealed, the contradiction they actually unlocked, and their own
	accusation. This is a factual recap of the player's evidence, never a
	verdict.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local CaseClosedView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local summaryLabel: TextLabel? = nil
local timelineLabel: TextLabel? = nil
local contradictionLabel: TextLabel? = nil

local function setVisible(visible: boolean)
	if not gui or not root then
		return
	end
	if visible then
		gui.Enabled = true
		root.Visible = true
		TweenService:Create(root, TweenInfo.new(0.4), { BackgroundTransparency = 0.15 }):Play()
	else
		local tween = TweenService:Create(root, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			root.Visible = false
			gui.Enabled = false
		end)
		tween:Play()
	end
end

-- The factual sequence of events the player actually revealed, in the order
-- the server already sorted them. Never includes an undiscoved event.
local function buildTimelineText(summary: Types.CaseClosedSummary): string
	if #summary.timeline == 0 then
		return "No timeline events were recorded."
	end
	local lines = {}
	for _, event in ipairs(summary.timeline) do
		table.insert(lines, `{event.timestamp}  {event.title}`)
	end
	return table.concat(lines, "\n")
end

-- The contradiction the player actually unlocked, stated factually from the
-- authored label/summaries/reason. Never a conclusion about guilt.
local function buildContradictionText(summary: Types.CaseClosedSummary): string
	local contradiction = summary.contradiction
	if not contradiction then
		return "No contradiction was established."
	end
	local text = `{contradiction.leftSummary}  vs.  {contradiction.rightSummary}`
	if contradiction.reason then
		text ..= `\n{contradiction.reason}`
	end
	return text
end

function CaseClosedView.show(summary: Types.CaseClosedSummary)
	if not summaryLabel or not timelineLabel or not contradictionLabel then
		return
	end

	-- Counts the player accumulated, all of them real server-side totals.
	local counts = `Objectives completed: {summary.objectivesCompleted} / {summary.objectivesTotal}\n`
		.. `Evidence examined: {summary.evidenceExamined} / {summary.evidenceTotal}\n`
		.. `Contradictions identified: {summary.contradictionsIdentified}`

	-- The player's own accusation, stated factually. `supported` says only
	-- whether the evidence they unlocked is consistent with the choice --
	-- never that the accusation is the truth.
	local accusation = summary.accusation
	if accusation then
		counts ..= `\n\nAccusation: {accusation.suspectName}\n`
		if accusation.supported then
			local basedOn = if #accusation.basedOn > 0
				then table.concat(accusation.basedOn, ", ")
				else "the case evidence"
			counts ..= `Consistent with the evidence you found ({basedOn}).`
		else
			counts ..= "Not supported by the evidence you found."
		end
	end
	summaryLabel.Text = counts

	timelineLabel.Text = buildTimelineText(summary)
	contradictionLabel.Text = buildContradictionText(summary)

	setVisible(true)
end

function CaseClosedView.hide()
	setVisible(false)
end

function CaseClosedView.start()
	gui = Components.screenGui("MysteryCase_CaseClosed", 24)
	gui.Enabled = false

	root = Components.frame({
		name = "CaseClosed",
		size = UDim2.fromOffset(560, 480),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Background,
		transparency = 0.15,
		radius = 8,
		border = true,
		parent = gui,
	})
	root.Visible = false
	Components.padding(root, 28)

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 46, 0, 2),
		position = UDim2.fromOffset(0, 4),
		color = Theme.Accent,
		radius = 1,
		parent = root,
	})
	accent.BackgroundTransparency = 0

	Components.text({
		name = "Header",
		text = "CASE CLOSED",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 22),
		textSize = 12,
		color = Theme.Accent,
		parent = root,
	})

	Components.text({
		name = "Body",
		text = "Investigation concluded.",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 42),
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.TextPrimary,
		parent = root,
	})

	summaryLabel = Components.text({
		name = "Summary",
		text = "",
		size = UDim2.new(1, 0, 0, 130),
		position = UDim2.fromOffset(0, 84),
		textSize = 14,
		color = Theme.TextSecondary,
		parent = root,
	})
	summaryLabel.TextWrapped = true
	summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
	summaryLabel.LineHeight = 1.35

	-- Factual case restatement (Phase 2O): the sequence of events the player
	-- revealed, then the contradiction they unlocked.
	Components.text({
		name = "TimelineHeader",
		text = "THE SEQUENCE OF EVENTS",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 224),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	timelineLabel = Components.text({
		name = "Timeline",
		text = "",
		size = UDim2.new(1, 0, 0, 72),
		position = UDim2.fromOffset(0, 242),
		textSize = 13,
		color = Theme.TextPrimary,
		parent = root,
	})
	timelineLabel.TextWrapped = true
	timelineLabel.TextYAlignment = Enum.TextYAlignment.Top
	timelineLabel.LineHeight = 1.3

	Components.text({
		name = "ContradictionHeader",
		text = "THE CONTRADICTION",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 322),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	contradictionLabel = Components.text({
		name = "Contradiction",
		text = "",
		size = UDim2.new(1, 0, 0, 56),
		position = UDim2.fromOffset(0, 340),
		textSize = 13,
		color = Theme.TextPrimary,
		parent = root,
	})
	contradictionLabel.TextWrapped = true
	contradictionLabel.TextYAlignment = Enum.TextYAlignment.Top
	contradictionLabel.LineHeight = 1.3

	Components.text({
		name = "Footer",
		text = "The investigation session has ended. The evidence above is what you found.",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 1, -24),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = root,
	})
end

return CaseClosedView
