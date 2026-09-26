--!strict
--[[
	AccusationView
	The player's formal accusation (Phase 2N; M9: making a case).

	The player names a suspect and, when the case asks for it (M9,
	`requiresCase`), why they did it (one of the deductions the player has
	established) and what proves it (one of the contradictions the player has
	established). ACCUSE only enables once every part is chosen, and nothing
	on screen says which motive or proof fits which suspect.

	Presentation only: it renders exactly the spoiler-safe
	Types.AccusationPayload the server sends and reports the chosen ids back.
	It never decides eligibility, never decides whether the case holds, and
	never holds authoritative state.

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

type Section = "Suspect" | "Motive" | "Proof"

local gui: ScreenGui? = nil
local root: Frame? = nil
local body: ScrollingFrame? = nil
local titleLabel: TextLabel? = nil
local introLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local accuseButton: TextButton? = nil

local rows: { Instance } = {}
-- Keyed by Section.
local buttons: { [string]: { [string]: TextButton } } = { Suspect = {}, Motive = {}, Proof = {} }
local chosen: { [string]: string? } = {}
local current: Types.AccusationPayload? = nil
local isOpen = false
local targetAlpha = 0
local currentAlpha = 0

-- Fired with (accusationId, motiveId?, proofId?) when the player accuses.
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
	buttons = { Suspect = {}, Motive = {}, Proof = {} }
end

local function complete(): boolean
	local payload = current
	if not payload or payload.selected or not payload.open or not chosen.Suspect then
		return false
	end
	if payload.requiresCase then
		return chosen.Motive ~= nil and chosen.Proof ~= nil
	end
	return true
end

local function styleOption(button: TextButton, selected: boolean)
	button.BackgroundColor3 = if selected then Color3.fromRGB(40, 36, 28) else Theme.Background
	button.BackgroundTransparency = if selected then 0.05 else 0.35
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Theme.Accent else Theme.PanelStroke
		stroke.Transparency = if selected then 0.05 else 0.4
	end
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = if selected then Theme.Accent else Theme.TextPrimary
	end
end

local function refreshAccuse()
	local button = accuseButton
	if not button then
		return
	end
	local ready = complete()
	button.AutoButtonColor = ready
	button.Active = ready
	button.BackgroundTransparency = if ready then 0 else 0.7
	button.TextTransparency = if ready then 0 else 0.45
	button.Visible = current ~= nil and current.selected == nil
end

local function choose(section: Section, id: string)
	if not current or current.selected then
		return
	end
	chosen[section] = id
	for optionId, button in pairs(buttons[section]) do
		styleOption(button, optionId == id)
	end
	refreshAccuse()
end

local function addHeader(y: number, text: string): number
	local label = Components.text({
		name = "Header",
		text = text,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, y),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = body,
	})
	table.insert(rows, label)
	return y + 22
end

local function addNote(y: number, text: string): number
	local label = Components.text({
		name = "Note",
		text = text,
		size = UDim2.new(1, 0, 0, 32),
		position = UDim2.fromOffset(0, y),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = body,
	})
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	table.insert(rows, label)
	return y + 38
end

-- One selectable option. `x`/`width` let suspects sit side by side.
local function addOption(
	section: Section,
	id: string,
	text: string,
	subtext: string?,
	position: UDim2,
	size: UDim2,
	selectable: boolean
): TextButton
	local button = Instance.new("TextButton")
	button.Name = `{section}_{id}`
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = size
	button.Position = position
	button.BorderSizePixel = 0
	button.Selectable = selectable
	button.Active = selectable
	button.Parent = body
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	Components.padding(button, 10)

	local label = Components.text({
		name = "Label",
		text = text,
		size = UDim2.new(1, 0, if subtext then 0.55 else 1, 0),
		font = Theme.FontBold,
		textSize = 14,
		color = Theme.TextPrimary,
		parent = button,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if subtext then
		Components.text({
			name = "Sub",
			text = subtext,
			size = UDim2.new(1, 0, 0.45, 0),
			position = UDim2.fromScale(0, 0.55),
			textSize = 12,
			color = Theme.TextSecondary,
			parent = button,
		})
	end

	styleOption(button, false)
	if selectable then
		button.Activated:Connect(function()
			choose(section, id)
		end)
		button.SelectionGained:Connect(function()
			if chosen[section] ~= id then
				local stroke2 = button:FindFirstChildOfClass("UIStroke")
				if stroke2 then
					stroke2.Transparency = 0.1
				end
			end
		end)
		button.SelectionLost:Connect(function()
			styleOption(button, chosen[section] == id)
		end)
	end
	buttons[section][id] = button
	table.insert(rows, button)
	return button
end

local function applyHint()
	if not hintLabel then
		return
	end
	local payload = current
	if payload and payload.selected then
		hintLabel.Text = if InputHints.scheme() == "Touch"
			then "Accusation recorded."
			else `Accusation recorded. {InputHints.format("Accuse", "Close")}`
	elseif InputHints.scheme() == "Touch" then
		hintLabel.Text = "Choose, then ACCUSE."
	else
		hintLabel.Text = `Choose, then ACCUSE. {InputHints.format("Accuse", "Cancel")}`
	end
end

-- With a gamepad, start on the first suspect so the D-pad can move between
-- options and A picks (Roblox's built-in GUI navigation).
local function selectForGamepad()
	if InputHints.scheme() ~= "Gamepad" then
		return
	end
	for _, button in pairs(buttons.Suspect) do
		if button.Selectable then
			GuiService.SelectedObject = button
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

-- Renders the server-authorized accusation state. Once the player has
-- accused someone the view is read-only and shows the committed choice.
function AccusationView.update(payload: Types.AccusationPayload)
	if not body or not titleLabel or not introLabel then
		return
	end
	-- Keep what the player had picked if it is still on offer.
	current = payload
	clearRows()
	local selectable = payload.selected == nil and payload.open

	local y = 0
	y = addHeader(y, "WHO")
	if #payload.options == 0 then
		y = addNote(y, "There is no one to accuse in this case.")
	else
		local count = #payload.options
		for index, option in ipairs(payload.options) do
			local committed = payload.selected and payload.selected.id == option.id
			local column = (index - 1) % 2
			local rowIndex = math.floor((index - 1) / 2)
			local width = if count == 1 then UDim2.new(1, 0, 0, 52) else UDim2.new(0.5, -5, 0, 52)
			addOption(
				"Suspect",
				option.id,
				string.upper(option.suspectName),
				if committed then "ACCUSED" else option.suspectRole,
				UDim2.new(column * 0.5, column * 5, 0, y + rowIndex * 60),
				width,
				selectable
			)
		end
		y += math.ceil(count / 2) * 60 + 6
	end

	if payload.requiresCase then
		y = addHeader(y, "WHY")
		if #payload.motives == 0 then
			y = addNote(y, "Nothing established yet. Your case file's open questions are where a motive comes from.")
		else
			for _, motive in ipairs(payload.motives) do
				addOption(
					"Motive",
					motive.id,
					motive.label,
					nil,
					UDim2.fromOffset(0, y),
					UDim2.new(1, 0, 0, 36),
					selectable
				)
				y += 42
			end
			y += 6
		end

		y = addHeader(y, "WHAT PROVES IT")
		if #payload.proofs == 0 then
			y = addNote(
				y,
				"No contradiction established yet. Catch someone out: in conversation, or in your case file."
			)
		else
			for _, proof in ipairs(payload.proofs) do
				addOption(
					"Proof",
					proof.id,
					proof.label,
					nil,
					UDim2.fromOffset(0, y),
					UDim2.new(1, 0, 0, 36),
					selectable
				)
				y += 42
			end
		end
	end
	body.CanvasSize = UDim2.fromOffset(0, y)

	-- Re-apply what was picked, when it is still on offer.
	for _, section in ipairs({ "Suspect", "Motive", "Proof" }) do
		local id = chosen[section]
		if id and buttons[section][id] then
			styleOption(buttons[section][id], true)
		else
			chosen[section] = nil
		end
	end
	local committed = payload.selected and buttons.Suspect[payload.selected.id]
	if committed then
		styleOption(committed, true)
	end

	titleLabel.Text = if payload.selected then "Accusation Made" else "Make Your Case"
	introLabel.Text = if payload.selected
		then "It's on the record."
		elseif payload.requiresCase then "Name who did it, why, and what proves it. There is no taking it back."
		else "Accusing a suspect is final."

	refreshAccuse()
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
	local screen = gui :: ScreenGui
	screen.Enabled = false

	root = Components.frame({
		name = "Accusation",
		size = UDim2.fromOffset(580, 600),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Panel,
		transparency = 0.06,
		radius = 10,
		border = true,
		parent = screen,
	})
	local panel = root :: Frame
	panel.Visible = false
	Components.padding(panel, 26)
	-- Fit shorter screens.
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(580, 600)
	fit.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp((camera.ViewportSize.Y - 40) / 600, 0.6, 1)
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 46, 0, 2),
		position = UDim2.fromOffset(0, 2),
		color = Theme.Accent,
		radius = 1,
		parent = panel,
	})
	accent.BackgroundTransparency = 0

	Components.text({
		name = "Header",
		text = "FORMAL ACCUSATION",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.Accent,
		parent = panel,
	})

	titleLabel = Components.text({
		name = "Title",
		text = "Make Your Case",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 36),
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.TextPrimary,
		parent = panel,
	})

	introLabel = Components.text({
		name = "Body",
		text = "",
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 66),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = panel,
	})

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Options"
	scroller.Size = UDim2.new(1, 0, 1, -170)
	scroller.Position = UDim2.fromOffset(0, 96)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Accent
	scroller.CanvasSize = UDim2.fromOffset(0, 0)
	scroller.Parent = panel
	body = scroller

	local button = Instance.new("TextButton")
	button.Name = "Accuse"
	button.Size = UDim2.new(0, 180, 0, 40)
	button.Position = UDim2.new(0, 0, 1, -64)
	button.BackgroundColor3 = Theme.Accent
	button.BorderSizePixel = 0
	button.Font = Theme.FontBold
	button.TextSize = 15
	button.TextColor3 = Theme.Background
	button.Text = "ACCUSE"
	button.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	button.Activated:Connect(function()
		if not complete() then
			return
		end
		local payload = current :: Types.AccusationPayload
		local motive = if payload.requiresCase then chosen.Motive else nil
		local proof = if payload.requiresCase then chosen.Proof else nil
		selectionRequested:Fire(chosen.Suspect, motive, proof)
	end)
	accuseButton = button

	hintLabel = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, -190, 0, 16),
		position = UDim2.new(0, 190, 1, -52),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = panel,
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
	refreshAccuse()
end

return AccusationView
