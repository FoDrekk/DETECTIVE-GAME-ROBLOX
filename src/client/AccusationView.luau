--!strict
--[[
	AccusationView
	The player's formal accusation picker (Phase 2N). Presented once every
	objective is complete; the player names a suspect.

	Presentation only: it renders exactly the spoiler-safe
	Types.AccusationPayload the server sends (the case's authored accusations
	-- suspects the player can already see) and reports the chosen id back to
	the server. It never decides eligibility, never decides which choice is
	supported, and never holds authoritative state.

	Opened with Q, dismissed with Q or ESC.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

local AccusationView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local listFrame: Frame? = nil
local hintLabel: TextLabel? = nil
local emptyLabel: TextLabel? = nil

local rows: { Instance } = {}
local isOpen = false
local accused = false
local targetAlpha = 0
local currentAlpha = 0

-- Fired with the chosen accusation id when the player selects an option.
local selectionRequested: BindableEvent = Instance.new("BindableEvent")

function AccusationView.onSelectionRequested(): BindableEvent
	return selectionRequested
end

function AccusationView.isOpen(): boolean
	return isOpen
end

local function clearRows()
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	rows = {}
end

local function addOptionRow(index: number, option: Types.AccusationOption, selectable: boolean)
	if not listFrame then
		return
	end

	local row = Components.frame({
		name = "Option_" .. option.id,
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, (index - 1) * 60),
		color = Theme.Background,
		transparency = 0.35,
		radius = 5,
		border = true,
		parent = listFrame,
	})
	Components.padding(row, 12)
	table.insert(rows, row)

	Components.text({
		name = "Label",
		text = string.upper(option.suspectName),
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 14,
		color = Theme.TextPrimary,
		parent = row,
	})

	Components.text({
		name = "Role",
		text = option.suspectRole or "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 20),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = row,
	})

	if selectable then
		local button = Instance.new("TextButton")
		button.Name = "Select"
		button.Size = UDim2.new(0, 96, 0, 30)
		button.Position = UDim2.new(1, -96, 0.5, -15)
		button.BackgroundColor3 = Theme.Panel
		button.BackgroundTransparency = 0.1
		button.BorderSizePixel = 0
		button.Font = Theme.FontBold
		button.TextSize = 13
		button.TextColor3 = Theme.Accent
		button.Text = "ACCUSE"
		button.AutoButtonColor = true
		button.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.PanelStroke
		stroke.Thickness = 1
		stroke.Parent = button
		button.Activated:Connect(function()
			selectionRequested:Fire(option.id)
		end)
	else
		Components.text({
			name = "Committed",
			text = "ACCUSED",
			size = UDim2.new(0, 96, 0, 18),
			position = UDim2.new(1, -96, 0.5, -9),
			font = Theme.FontBold,
			textSize = 12,
			color = Theme.Accent,
			xAlign = Enum.TextXAlignment.Right,
			parent = row,
		})
	end
end

local function applyHint()
	if not hintLabel then
		return
	end
	if InputHints.scheme() == "Touch" then
		hintLabel.Text = if accused then "Accusation recorded." else "Tap ACCUSE to name a suspect."
	elseif accused then
		hintLabel.Text = `Accusation recorded. {InputHints.format("Accuse", "Close")}`
	else
		hintLabel.Text = `Select a suspect to accuse, or {InputHints.format("Accuse", "Cancel")}`
	end
end

-- With a gamepad, highlight the first ACCUSE button so the D-pad can move
-- between suspects and A confirms (Roblox's built-in GUI navigation).
local function selectForGamepad()
	if InputHints.scheme() ~= "Gamepad" or not listFrame then
		return
	end
	for _, row in ipairs(rows) do
		local select = row:FindFirstChild("Select")
		if select and select:IsA("GuiButton") then
			GuiService.SelectedObject = select
			return
		end
	end
end

local function releaseGamepadSelection()
	local selected = GuiService.SelectedObject
	if selected and root and selected:IsDescendantOf(root) then
		GuiService.SelectedObject = nil
	end
end

-- Renders the server-authorized accusation options. Once the player has
-- accused someone, the picker becomes read-only (their choice is permanent)
-- and shows which option they committed to.
function AccusationView.update(payload: Types.AccusationPayload)
	if not listFrame or not emptyLabel then
		return
	end

	clearRows()

	local options = payload.options
	emptyLabel.Visible = #options == 0
	for index, option in ipairs(options) do
		addOptionRow(index, option, payload.selected == nil)
	end

	accused = payload.selected ~= nil
	applyHint()
	if isOpen then
		selectForGamepad()
	end
end

local function setVisible(visible: boolean)
	if not gui or not root then
		return
	end
	isOpen = visible
	targetAlpha = visible and 1 or 0
	if visible then
		gui.Enabled = true
		root.Visible = true
	else
		task.delay(0.3, function()
			if not isOpen and gui then
				gui.Enabled = false
			end
		end)
	end
end

function AccusationView.open()
	if not root then
		return
	end
	root.Visible = true
	setVisible(true)
	selectForGamepad()
end

function AccusationView.close()
	if not isOpen then
		return
	end
	releaseGamepadSelection()
	setVisible(false)
end

function AccusationView.toggle()
	if isOpen then
		AccusationView.close()
	else
		AccusationView.open()
	end
end

function AccusationView.start()
	gui = Components.screenGui("MysteryCase_Accusation", 23)
	gui.Enabled = false

	root = Components.frame({
		name = "Accusation",
		size = UDim2.fromOffset(520, 320),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Panel,
		transparency = 0.06,
		radius = 10,
		border = true,
		parent = gui,
	})
	root.Visible = false
	Components.padding(root, 26)

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 46, 0, 2),
		position = UDim2.fromOffset(0, 2),
		color = Theme.Accent,
		radius = 1,
		parent = root,
	})
	accent.BackgroundTransparency = 0

	Components.text({
		name = "Header",
		text = "FORMAL ACCUSATION",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	Components.text({
		name = "Title",
		text = "Name the Suspect",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 36),
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.TextPrimary,
		parent = root,
	})

	Components.text({
		name = "Body",
		text = "The investigation is complete. Accusing a suspect is final.",
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 66),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = root,
	})

	listFrame = Components.frame({
		name = "Options",
		size = UDim2.new(1, 0, 0, 0),
		position = UDim2.fromOffset(0, 92),
		transparency = 1,
		parent = root,
	})
	listFrame.BackgroundTransparency = 1
	listFrame.AutomaticSize = Enum.AutomaticSize.Y

	emptyLabel = Components.text({
		name = "Empty",
		text = "There is no one to accuse in this case.",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 0),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = listFrame,
	})
	emptyLabel.TextWrapped = true
	emptyLabel.Visible = false

	hintLabel = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -20),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})

	InputHints.changed().Event:Connect(function()
		applyHint()
		if isOpen then
			selectForGamepad()
		end
	end)

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.18
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.94
		end
	end)
end

return AccusationView
