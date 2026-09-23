--!strict
--[[
	CaseClosedView
	Minimal cinematic closing overlay shown during the CaseClosed phase
	(Phase 2L). Mirrors CaseBriefingView's exact visual pattern.

	Purely presentational: renders only the factual Types.CaseClosedSummary
	the server sends once it accepts the player's own conclusion request. It
	never decides whether the investigation is actually complete, and never
	states or implies who did anything -- only counts of already-authorized
	facts the player already had.
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

function CaseClosedView.show(summary: Types.CaseClosedSummary)
	if not summaryLabel then
		return
	end
	summaryLabel.Text = `Objectives completed: {summary.objectivesCompleted} / {summary.objectivesTotal}\n`
		.. `Evidence examined: {summary.evidenceExamined} / {summary.evidenceTotal}\n`
		.. `Contradictions identified: {summary.contradictionsIdentified}`
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
		size = UDim2.fromOffset(520, 300),
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
		size = UDim2.new(1, 0, 0, 100),
		position = UDim2.fromOffset(0, 92),
		textSize = 15,
		color = Theme.TextSecondary,
		parent = root,
	})
	summaryLabel.TextWrapped = true
	summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
	summaryLabel.LineHeight = 1.4

	Components.text({
		name = "Footer",
		text = "The investigation session has ended.",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 1, -24),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = root,
	})
end

return CaseClosedView
