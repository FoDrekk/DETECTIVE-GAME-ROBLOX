--!strict
--[[
	ObjectiveView
	Minimal, dark, cinematic current-objective display.

	Shows the active objective title and its checklist. Requirements tick from
	`□` to `✓` as the server confirms progress. This view is presentation only:
	it never decides completion.

	Intentionally restrained: no XP, levels, tracker panels or RPG HUD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ObjectiveView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local headerLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local listFrame: Frame? = nil
local completedBanner: Frame? = nil
local completedTitleLabel: TextLabel? = nil

local requirementRows: { [string]: TextLabel } = {}
local targetAlpha = 0
local currentAlpha = 0

local CHECK_OPEN = "\u{25A1}" -- □
local CHECK_DONE = "\u{2713}" -- ✓

local function setVisible(visible: boolean)
	targetAlpha = visible and 1 or 0
end

local function ensureRow(requirementId: string): TextLabel?
	if not listFrame then
		return nil
	end
	local existing = requirementRows[requirementId]
	if existing then
		return existing
	end
	local row = Components.text({
		name = "Req_" .. requirementId,
		text = "",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 0),
		textSize = 13,
		color = Theme.TextSecondary,
		parent = listFrame,
	})
	-- Stack rows using a UIListLayout-equivalent manual order.
	local count = 0
	for _ in pairs(requirementRows) do
		count += 1
	end
	row.Position = UDim2.fromOffset(0, count * 22)
	requirementRows[requirementId] = row
	return row
end

local function showCompletedBanner(show: boolean)
	if not completedBanner or not root or not listFrame then
		return
	end
	completedBanner.Visible = show
	if show then
		-- Collapse the checklist and surface the completion state.
		listFrame.Visible = false
		if completedTitleLabel then
			completedTitleLabel.Visible = true
		end
	else
		listFrame.Visible = true
		if completedTitleLabel then
			completedTitleLabel.Visible = false
		end
	end
end

function ObjectiveView.update(payload: Types.ObjectivePayload)
	if not titleLabel then
		return
	end

	local objective = payload.objective
	titleLabel.Text = objective.title
	showCompletedBanner(false)

	local seen: { [string]: boolean } = {}
	for _, requirement in ipairs(objective.requirements) do
		seen[requirement.id] = true
		local row = ensureRow(requirement.id)
		if row then
			local mark = requirement.completed and CHECK_DONE or CHECK_OPEN
			row.Text = `{mark}  {requirement.label}`
			row.TextColor3 = requirement.completed and Theme.Accent or Theme.TextSecondary
		end
	end

	-- Remove rows that no longer belong to the objective.
	for id, row in pairs(requirementRows) do
		if not seen[id] then
			row:Destroy()
			requirementRows[id] = nil
		end
	end

	if objective.completed then
		showCompletedBanner(true)
	end

	setVisible(true)
end

function ObjectiveView.showCompleted(payload: Types.ObjectivePayload)
	if not completedTitleLabel then
		return
	end
	-- Phase 2K: when this was the last objective, say so -- otherwise the
	-- panel silently stops updating with no acknowledgment that there is
	-- nothing further to do yet.
	if payload.allComplete then
		completedTitleLabel.Text = `INVESTIGATION COMPLETE\n{payload.objective.title}`
	else
		completedTitleLabel.Text = `OBJECTIVE COMPLETE\n{payload.objective.title}`
	end
	setVisible(true)
end

function ObjectiveView.hide()
	setVisible(false)
end

function ObjectiveView.start()
	gui = Components.screenGui("MysteryCase_Objective", 8)

	root = Components.frame({
		name = "Objective",
		size = UDim2.fromOffset(280, 160),
		position = UDim2.fromOffset(28, 28),
		color = Theme.Background,
		transparency = 0.25,
		radius = 6,
		border = true,
		parent = gui,
	})
	root.BackgroundTransparency = 1
	root.AutomaticSize = Enum.AutomaticSize.Y

	Components.padding(root, 16)

	headerLabel = Components.text({
		name = "Header",
		text = "CURRENT OBJECTIVE",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 0),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 34, 0, 2),
		position = UDim2.fromOffset(0, 18),
		color = Theme.Accent,
		radius = 1,
		parent = root,
	})
	accent.BackgroundTransparency = 0

	titleLabel = Components.text({
		name = "Title",
		text = "",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 26),
		font = Theme.FontBold,
		textSize = 16,
		color = Theme.TextPrimary,
		parent = root,
	})

	listFrame = Components.frame({
		name = "Checklist",
		size = UDim2.new(1, 0, 0, 0),
		position = UDim2.fromOffset(0, 60),
		transparency = 1,
		parent = root,
	})
	listFrame.BackgroundTransparency = 1
	listFrame.AutomaticSize = Enum.AutomaticSize.Y

	completedBanner = Components.frame({
		name = "CompletedBanner",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 60),
		color = Theme.Panel,
		transparency = 0.1,
		radius = 4,
		border = true,
		parent = root,
	})
	completedBanner.Visible = false

	completedTitleLabel = Components.text({
		name = "CompletedTitle",
		text = "",
		size = UDim2.new(1, 0, 1, 0),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 13,
		color = Theme.Accent,
		xAlign = Enum.TextXAlignment.Center,
		parent = completedBanner,
	})
	completedTitleLabel.TextWrapped = true

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.15
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.75
			root.Visible = currentAlpha > 0.01
		end
	end)
end

return ObjectiveView
