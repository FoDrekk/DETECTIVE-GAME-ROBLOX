--!strict
--[[
	ObjectiveView
	Minimal, dark, cinematic current-objective display.

	Shows the active objective title, its authored description as a hint, and
	its checklist. Requirements tick from `□` to `✓` as the server confirms
	progress. This view is presentation only: it never decides completion.

	The server sends a completed objective and the next objective in the same
	frame, so a non-final completion is held on screen briefly before the next
	objective replaces it -- otherwise the player never sees it.

	Only shown while the investigation phase is active (see setActive).
	Intentionally restrained: no XP, levels, tracker panels or RPG HUD.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

local ObjectiveView = {}

local Theme = Config.UI.Theme

local ROW_HEIGHT = 22
local COMPLETION_HOLD_SECONDS = 2.2

local gui: ScreenGui? = nil
local root: Frame? = nil
local titleLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local listFrame: Frame? = nil
local completedBanner: Frame? = nil
local completedTitleLabel: TextLabel? = nil
local concludeHintLabel: TextLabel? = nil

local requirementRows: { [string]: TextLabel } = {}
local targetAlpha = 0
local currentAlpha = 0

local active = false
local hasContent = false
local holdUntil = 0
local pendingPayload: Types.ObjectivePayload? = nil

local CHECK_OPEN = "\u{25A1}" -- □
local CHECK_DONE = "\u{2713}" -- ✓

local function refreshVisibility()
	targetAlpha = if active and hasContent then 1 else 0
end

local function layoutRequirements(requirements: { Types.ObjectiveRequirementProgress })
	if not listFrame then
		return
	end

	-- Drop rows from a previous objective first, so new rows are laid out
	-- from the top rather than below the rows they replace.
	local seen: { [string]: boolean } = {}
	for _, requirement in ipairs(requirements) do
		seen[requirement.id] = true
	end
	for id, row in pairs(requirementRows) do
		if not seen[id] then
			row:Destroy()
			requirementRows[id] = nil
		end
	end

	for index, requirement in ipairs(requirements) do
		local row = requirementRows[requirement.id]
		if not row then
			row = Components.text({
				name = "Req_" .. requirement.id,
				text = "",
				size = UDim2.new(1, 0, 0, 20),
				position = UDim2.fromOffset(0, 0),
				textSize = 13,
				color = Theme.TextSecondary,
				parent = listFrame,
			})
			requirementRows[requirement.id] = row
		end
		local mark = if requirement.completed then CHECK_DONE else CHECK_OPEN
		row.Text = `{mark}  {requirement.label}`
		row.TextColor3 = if requirement.completed then Theme.Accent else Theme.TextSecondary
		row.Position = UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT)
	end
end

local function render(payload: Types.ObjectivePayload)
	if not titleLabel or not hintLabel or not listFrame or not completedBanner then
		return
	end

	local objective = payload.objective
	titleLabel.Text = objective.title
	hintLabel.Text = objective.description
	layoutRequirements(objective.requirements)

	local completed = objective.completed
	completedBanner.Visible = completed
	listFrame.Visible = not completed
	hintLabel.Visible = not completed
	if completedTitleLabel then
		completedTitleLabel.Text = if payload.allComplete then "INVESTIGATION COMPLETE" else "OBJECTIVE COMPLETE"
	end
	-- Only once every objective is done does concluding become a real,
	-- player-initiated option. The server re-validates this regardless.
	if concludeHintLabel then
		concludeHintLabel.Visible = completed and payload.allComplete
	end

	hasContent = true
	refreshVisibility()
end

function ObjectiveView.update(payload: Types.ObjectivePayload)
	if os.clock() < holdUntil and not payload.objective.completed then
		-- Latest state wins; applied when the completion hold ends.
		pendingPayload = payload
		return
	end
	render(payload)
end

function ObjectiveView.showCompleted(payload: Types.ObjectivePayload)
	render(payload)
	if payload.allComplete then
		holdUntil = 0
		pendingPayload = nil
		return
	end
	holdUntil = os.clock() + COMPLETION_HOLD_SECONDS
	task.delay(COMPLETION_HOLD_SECONDS, function()
		if os.clock() < holdUntil then
			return -- a later completion extended the hold
		end
		local pending = pendingPayload
		pendingPayload = nil
		if pending then
			render(pending)
		end
	end)
end

-- The objective panel is only shown while the investigation is in progress
-- (not over the briefing or the closing screen).
function ObjectiveView.setActive(isActive: boolean)
	active = isActive
	refreshVisibility()
end

function ObjectiveView.hide()
	ObjectiveView.setActive(false)
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
	root.Visible = false

	-- The ScreenGui ignores the GUI inset, so sit below Roblox's own top-bar
	-- buttons (menu, chat). The top bar initialises after this script, so
	-- follow its inset as it changes rather than reading it once.
	local function placeBelowTopbar()
		if root then
			root.Position = UDim2.fromOffset(28, math.max(28, GuiService.TopbarInset.Height + 12))
		end
	end
	placeBelowTopbar()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeBelowTopbar)

	Components.padding(root, 16)

	Components.text({
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

	-- The active objective's own authored description, as a hint.
	hintLabel = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 56),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = root,
	})
	hintLabel.TextWrapped = true
	hintLabel.TextYAlignment = Enum.TextYAlignment.Top

	listFrame = Components.frame({
		name = "Checklist",
		size = UDim2.new(1, 0, 0, 0),
		position = UDim2.fromOffset(0, 90),
		transparency = 1,
		parent = root,
	})
	listFrame.BackgroundTransparency = 1
	listFrame.AutomaticSize = Enum.AutomaticSize.Y

	completedBanner = Components.frame({
		name = "CompletedBanner",
		size = UDim2.new(1, 0, 0, 32),
		position = UDim2.fromOffset(0, 62),
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

	concludeHintLabel = Components.text({
		name = "ConcludeHint",
		text = "",
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 104),
		font = Theme.FontBold,
		textSize = 13,
		color = Theme.TextPrimary,
		xAlign = Enum.TextXAlignment.Center,
		parent = root,
	})
	concludeHintLabel.Visible = false
	-- On touch this matches the "Name Suspect" touch button.
	InputHints.bind(concludeHintLabel, "Accuse", "Name the suspect", "Tap Name Suspect")

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.15
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.75
			root.Visible = currentAlpha > 0.01
		end
	end)
end

return ObjectiveView
