--!strict
--[[
	CaseClosedView
	Cinematic closing overlay shown during the CaseClosed phase (Phase 2L).
	Mirrors CaseBriefingView's visual pattern.

	Purely presentational: renders the Types.CaseClosedSummary the server sends
	once it accepts the player's accusation. M2: leads with the verdict --
	whether the player named the culprit -- and what actually happened, then
	the sequence of events they uncovered and their stats. A case without an
	authored solution falls back to reporting whether the evidence supports
	the accusation (Phase 2N).
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
local titleLabel: TextLabel? = nil
local verdictLabel: TextLabel? = nil
local revealHeader: TextLabel? = nil
local revealLabel: TextLabel? = nil
local timelineLabel: TextLabel? = nil
local statsLabel: TextLabel? = nil

local function setVisible(visible: boolean)
	if not gui or not root then
		return
	end
	if visible then
		gui.Enabled = true
		root.Visible = true
		root.BackgroundTransparency = 1
		TweenService:Create(root, TweenInfo.new(0.5), { BackgroundTransparency = 0.08 }):Play()
		-- Reveal the text top to bottom, like the briefing.
		for index, label in ipairs({ titleLabel, verdictLabel, revealHeader, revealLabel, timelineLabel, statsLabel }) do
			if label then
				label.TextTransparency = 1
				TweenService:Create(
					label,
					TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.2 + index * 0.25),
					{ TextTransparency = 0 }
				):Play()
			end
		end
	else
		local tween = TweenService:Create(root, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			root.Visible = false
			gui.Enabled = false
		end)
		tween:Play()
	end
end

-- The sequence of events the player actually revealed, already sorted by the
-- server. Never includes an undiscovered event.
local function buildTimelineText(summary: Types.CaseClosedSummary): string
	if #summary.timeline == 0 then
		return "No timeline events were recorded."
	end
	local lines = {}
	for _, event in ipairs(summary.timeline) do
		table.insert(lines, `{event.timestamp}   {event.title}`)
	end
	return table.concat(lines, "\n")
end

local function applyHeadline(summary: Types.CaseClosedSummary)
	if not titleLabel or not verdictLabel or not revealHeader or not revealLabel then
		return
	end
	local accusation = summary.accusation
	local verdict = summary.verdict
	local accusedName = if accusation then accusation.suspectName else "no one"

	if verdict then
		if verdict.correct then
			titleLabel.Text = "Case solved."
			titleLabel.TextColor3 = Theme.Accent
			verdictLabel.Text = `You accused {accusedName}. You were right.`
		else
			titleLabel.Text = "The wrong person was charged."
			titleLabel.TextColor3 = Theme.TextPrimary
			verdictLabel.Text = `You accused {accusedName}. The killer was {verdict.culpritName}.`
		end
		revealHeader.Visible = true
		revealLabel.Visible = true
		revealLabel.Text = verdict.reveal
		return
	end

	-- No authored solution: report only whether the evidence supports the
	-- accusation.
	titleLabel.Text = "Investigation concluded."
	titleLabel.TextColor3 = Theme.TextPrimary
	if accusation then
		verdictLabel.Text = if accusation.supported
			then `You accused {accusedName}. The evidence you found supports it.`
			else `You accused {accusedName}. The evidence you found does not support it.`
	else
		verdictLabel.Text = ""
	end
	revealHeader.Visible = false
	revealLabel.Visible = false
end

function CaseClosedView.show(summary: Types.CaseClosedSummary)
	if not timelineLabel or not statsLabel then
		return
	end
	applyHeadline(summary)
	timelineLabel.Text = buildTimelineText(summary)
	statsLabel.Text = `Evidence {summary.evidenceExamined}/{summary.evidenceTotal}`
		.. `   ·   Objectives {summary.objectivesCompleted}/{summary.objectivesTotal}`
		.. `   ·   Contradictions {summary.contradictionsIdentified}`
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
		size = UDim2.fromOffset(600, 520),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Background,
		transparency = 0.08,
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

	titleLabel = Components.text({
		name = "Title",
		text = "",
		size = UDim2.new(1, 0, 0, 32),
		position = UDim2.fromOffset(0, 42),
		font = Theme.FontBold,
		textSize = 26,
		color = Theme.TextPrimary,
		parent = root,
	})

	verdictLabel = Components.text({
		name = "Verdict",
		text = "",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 80),
		textSize = 15,
		color = Theme.TextPrimary,
		parent = root,
	})
	verdictLabel.TextWrapped = true

	revealHeader = Components.text({
		name = "RevealHeader",
		text = "WHAT HAPPENED",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 120),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	revealLabel = Components.text({
		name = "Reveal",
		text = "",
		size = UDim2.new(1, 0, 0, 120),
		position = UDim2.fromOffset(0, 140),
		textSize = 14,
		color = Theme.TextSecondary,
		parent = root,
	})
	revealLabel.TextWrapped = true
	revealLabel.TextYAlignment = Enum.TextYAlignment.Top
	revealLabel.LineHeight = 1.3

	Components.text({
		name = "TimelineHeader",
		text = "THE SEQUENCE OF EVENTS",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 274),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	timelineLabel = Components.text({
		name = "Timeline",
		text = "",
		size = UDim2.new(1, 0, 0, 96),
		position = UDim2.fromOffset(0, 294),
		textSize = 13,
		color = Theme.TextPrimary,
		parent = root,
	})
	timelineLabel.TextWrapped = true
	timelineLabel.TextYAlignment = Enum.TextYAlignment.Top
	timelineLabel.LineHeight = 1.3

	statsLabel = Components.text({
		name = "Stats",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -20),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = root,
	})

	-- M4: the ending has a next step.
	Components.text({
		name = "ReplayHint",
		text = `[{Config.Interaction.PrimaryKey}]  Investigate again`,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -20),
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.Accent,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})
end

return CaseClosedView
