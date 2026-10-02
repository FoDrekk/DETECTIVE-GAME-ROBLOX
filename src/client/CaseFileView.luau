--!strict
--[[
	CaseFileView
	The investigator's case file (C). Presentation only: it renders exactly
	the spoiler-safe Types.ReasoningPayload the server sends and reports what
	the player tries back to the server, which judges it.

	This is where the player does the thinking.
	  * OPEN QUESTIONS: a conclusion waiting on the player. Each question
	    appears once its facts are known, with its options; the server says
	    whether the answer holds.
	  * SIDE BY SIDE: what people said (left) and what was found (right).
	    Selecting two and pressing "These don't add up" claims a
	    contradiction. A pairing that doesn't conflict is only told so.
	  * ESTABLISHED: the contradictions and deductions the player has made,
	    then the evidence cross-references.

	Opened and dismissed with C, and dismissed with ESC (mirrors TimelineView).
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

local CaseFileView = {}

local Theme = Config.UI.Theme
local SELECTED_FILL = Color3.fromRGB(40, 36, 28)
local ROW_GAP = 8

local gui: ScreenGui? = nil
local root: Frame? = nil
local content: ScrollingFrame? = nil
local emptyLabel: TextLabel? = nil
local feedbackLabel: TextLabel? = nil
local feedbackScale: UIScale? = nil
local selectionLabel: TextLabel? = nil
local claimButton: TextButton? = nil

local rows: { Instance } = {}
local isOpen = false
local targetAlpha = 0
local currentAlpha = 0

-- Up to two facts set side by side, oldest first.
type Fact = { kind: "Evidence" | "Statement", id: string, name: string }
local selected: { Fact } = {}
local factButtons: { [string]: TextButton } = {}
local firstSelectable: GuiObject? = nil

local claimRequested: BindableEvent = Instance.new("BindableEvent")
local answerRequested: BindableEvent = Instance.new("BindableEvent")

-- Fired with two fact references ({ kind, id }) the player says conflict.
function CaseFileView.onClaimRequested(): BindableEvent
	return claimRequested
end

-- Fired with (deductionId, optionId).
function CaseFileView.onAnswerRequested(): BindableEvent
	return answerRequested
end

function CaseFileView.isOpen(): boolean
	return isOpen
end

local function factKey(kind: string, id: string): string
	return `{kind}:{id}`
end

local function clearRows()
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	rows = {}
	factButtons = {}
	firstSelectable = nil
end

--------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------

local function addHeader(y: number, text: string, x: number?, width: number?): number
	local label = Components.text({
		name = "Header",
		text = text,
		size = UDim2.new(width or 1, if width then -6 else 0, 0, 18),
		position = UDim2.new(x or 0, if x and x > 0 then 6 else 0, 0, y),
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.Accent,
		parent = content,
	})
	table.insert(rows, label)
	return y + 24
end

local function card(name: string, y: number, height: number, x: number?, width: number?): Frame
	local row = Components.frame({
		name = name,
		size = UDim2.new(width or 1, if width then -6 else 0, 0, height),
		position = UDim2.new(x or 0, if x and x > 0 then 6 else 0, 0, y),
		color = Theme.Background,
		transparency = 0.4,
		radius = 5,
		parent = content,
	})
	Components.padding(row, 10)
	table.insert(rows, row)
	return row
end

local function cardText(
	parent: Instance,
	name: string,
	text: string,
	y: number,
	height: number,
	props: { bold: boolean?, size: number?, color: Color3? }
): TextLabel
	local label = Components.text({
		name = name,
		text = text,
		size = UDim2.new(1, 0, 0, height),
		position = UDim2.fromOffset(0, y),
		font = if props.bold then Theme.FontBold else Theme.Font,
		textSize = props.size or 13,
		color = props.color or Theme.TextPrimary,
		parent = parent,
	})
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function styleFact(button: TextButton, isSelected: boolean)
	button.BackgroundColor3 = if isSelected then SELECTED_FILL else Theme.Background
	button.BackgroundTransparency = if isSelected then 0.05 else 0.4
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if isSelected then Theme.Accent else Theme.PanelStroke
		stroke.Transparency = if isSelected then 0.05 else 0.6
	end
end

local function isSelected(kind: string, id: string): boolean
	for _, fact in ipairs(selected) do
		if fact.kind == kind and fact.id == id then
			return true
		end
	end
	return false
end

local function refreshSelection()
	for key, button in pairs(factButtons) do
		local kind, id = string.match(key, "^(%a+):(.+)$")
		styleFact(button, kind ~= nil and id ~= nil and isSelected(kind, id))
	end
	if selectionLabel then
		if #selected == 0 then
			selectionLabel.Text = "Pick two things that don't fit together."
		elseif #selected == 1 then
			selectionLabel.Text = `{selected[1].name}  ×  …`
		else
			selectionLabel.Text = `{selected[1].name}  ×  {selected[2].name}`
		end
	end
	if claimButton then
		local ready = #selected == 2
		claimButton.Active = ready
		claimButton.AutoButtonColor = ready
		claimButton.BackgroundTransparency = if ready then 0 else 0.7
		claimButton.TextTransparency = if ready then 0 else 0.45
	end
end

local function toggleFact(fact: Fact)
	for index, existing in ipairs(selected) do
		if existing.kind == fact.kind and existing.id == fact.id then
			table.remove(selected, index)
			refreshSelection()
			return
		end
	end
	table.insert(selected, fact)
	if #selected > 2 then
		table.remove(selected, 1)
	end
	refreshSelection()
end

-- A fact the player can set beside another: a statement or a clue.
local function addFactRow(y: number, x: number, fact: Fact, heading: string, text: string): number
	local height = 74
	local button = Instance.new("TextButton")
	button.Name = `Fact_{fact.kind}_{fact.id}`
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = UDim2.new(0.5, -6, 0, height)
	button.Position = UDim2.new(x, if x > 0 then 6 else 0, 0, y)
	button.BorderSizePixel = 0
	button.Selectable = true
	button.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	Components.padding(button, 10)
	cardText(button, "Heading", heading, 0, 14, { bold = true, size = 11, color = Theme.Accent })
	local body = cardText(button, "Text", text, 17, height - 38, { size = 12 })
	body.TextTruncate = Enum.TextTruncate.AtEnd
	button.Activated:Connect(function()
		toggleFact(fact)
	end)
	button.SelectionGained:Connect(function()
		stroke.Color = Theme.TextPrimary
		stroke.Transparency = 0.2
	end)
	button.SelectionLost:Connect(function()
		styleFact(button, isSelected(fact.kind, fact.id))
	end)
	factButtons[factKey(fact.kind, fact.id)] = button
	table.insert(rows, button)
	firstSelectable = firstSelectable or button
	return y + height + ROW_GAP
end

local function addQuestion(y: number, question: Types.DeductionQuestionPayload): number
	local optionHeight = 32
	local height = 20 + 20 + #question.options * (optionHeight + 6) + 12
	local row = card("Question_" .. question.id, y, height)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Accent
	stroke.Transparency = 0.55
	stroke.Parent = row
	cardText(row, "Prompt", question.prompt, 0, 18, { bold = true, size = 14 })
	local basedOn = if #question.basedOn > 0 then table.concat(question.basedOn, " · ") else "—"
	cardText(row, "BasedOn", `From: {basedOn}`, 20, 16, { size = 11, color = Theme.TextSecondary })
	for index, option in ipairs(question.options) do
		local button = Instance.new("TextButton")
		button.Name = `Option_{option.id}`
		button.AutoButtonColor = true
		button.Size = UDim2.new(1, 0, 0, optionHeight)
		button.Position = UDim2.fromOffset(0, 42 + (index - 1) * (optionHeight + 6))
		button.BackgroundColor3 = Theme.Panel
		button.BackgroundTransparency = 0.1
		button.BorderSizePixel = 0
		button.Font = Theme.Font
		button.TextSize = 13
		button.TextColor3 = Theme.TextPrimary
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = `   {option.text}`
		button.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button
		local optionStroke = Instance.new("UIStroke")
		optionStroke.Color = Theme.PanelStroke
		optionStroke.Transparency = 0.4
		optionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		optionStroke.Parent = button
		button.Activated:Connect(function()
			answerRequested:Fire(question.id, option.id)
		end)
		firstSelectable = firstSelectable or button
	end
	return y + height + ROW_GAP
end

local function addContradictionRow(y: number, contradiction: Types.ContradictionPayload): number
	local height = if contradiction.reason then 88 else 56
	local row = card("Contradiction_" .. contradiction.id, y, height)
	cardText(row, "Label", string.upper(contradiction.label), 0, 14, { bold = true, size = 11, color = Theme.Accent })
	cardText(row, "Summary", `{contradiction.leftSummary}  ×  {contradiction.rightSummary}`, 16, 16, { size = 13 })
	if contradiction.reason then
		cardText(row, "Reason", contradiction.reason, 36, 34, { size = 11, color = Theme.TextSecondary })
	end
	return y + height + ROW_GAP
end

local function addDeductionRow(y: number, deduction: Types.DeductionPayload): number
	local row = card("Deduction_" .. deduction.id, y, 56)
	cardText(row, "Label", string.upper(deduction.label), 0, 14, { bold = true, size = 11, color = Theme.Accent })
	local basedOn = if #deduction.basedOn > 0 then table.concat(deduction.basedOn, " · ") else "—"
	cardText(row, "BasedOn", `From: {basedOn}`, 16, 30, { size = 12, color = Theme.TextSecondary })
	return y + 56 + ROW_GAP
end

local function addRelatedRow(y: number, entry: Types.RelatedEvidencePayload): number
	local row = card("Related_" .. entry.id, y, 44)
	cardText(row, "Label", string.upper(entry.name), 0, 14, { bold = true, size = 11 })
	local related = if #entry.related > 0 then table.concat(entry.related, ", ") else "—"
	cardText(row, "Related", `Linked to: {related}`, 16, 16, { size = 12, color = Theme.TextSecondary })
	return y + 44 + ROW_GAP
end

--------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------

-- Renders exactly the server-authorized reasoning state. A section with no
-- entries is simply not drawn.
function CaseFileView.update(payload: Types.ReasoningPayload)
	if not content or not emptyLabel then
		return
	end
	clearRows()

	local y = 0
	local hasContent = #payload.statements > 0 or #payload.evidence > 0 or #payload.openQuestions > 0
	emptyLabel.Visible = not hasContent

	if #payload.openQuestions > 0 then
		y = addHeader(y, "OPEN QUESTIONS")
		for _, question in ipairs(payload.openQuestions) do
			y = addQuestion(y, question)
		end
		y += 8
	end

	-- Side by side: statements on the left, evidence on the right.
	if #payload.statements > 0 or #payload.evidence > 0 then
		local top = y
		local left = addHeader(top, "WHAT PEOPLE SAID", 0, 0.5)
		local right = addHeader(top, "WHAT YOU FOUND", 0.5, 0.5)
		for _, statement in ipairs(payload.statements) do
			left = addFactRow(left, 0, {
				kind = "Statement",
				id = statement.id,
				name = `{statement.suspectName}: {statement.label}`,
			}, `{string.upper(statement.suspectName)} · {string.upper(statement.label)}`, statement.text)
		end
		for _, evidence in ipairs(payload.evidence) do
			right = addFactRow(right, 0.5, {
				kind = "Evidence",
				id = evidence.id,
				name = evidence.name,
			}, string.upper(evidence.name), evidence.details)
		end
		y = math.max(left, right) + 8
	end

	if #payload.contradictions > 0 or #payload.deductions > 0 then
		y = addHeader(y, "ESTABLISHED")
		for _, contradiction in ipairs(payload.contradictions) do
			y = addContradictionRow(y, contradiction)
		end
		for _, deduction in ipairs(payload.deductions) do
			y = addDeductionRow(y, deduction)
		end
		y += 8
	end

	-- Discovered evidence cross-references. Only pairs where both
	-- items are already discovered ever arrive in this payload.
	if #payload.relatedEvidence > 0 then
		y = addHeader(y, "EVIDENCE LINKS")
		for _, entry in ipairs(payload.relatedEvidence) do
			y = addRelatedRow(y, entry)
		end
	end

	content.CanvasSize = UDim2.new(0, 0, 0, y)

	-- Keep only selections that are still on the page.
	local kept = {}
	for _, fact in ipairs(selected) do
		if factButtons[factKey(fact.kind, fact.id)] then
			table.insert(kept, fact)
		end
	end
	selected = kept
	refreshSelection()
end

local FEEDBACK: { [string]: string } = {
	["no-conflict"] = "Those two don't conflict.",
	wrong = "That doesn't hold up.",
	already = "Already in the file.",
	cooldown = "Take a moment. Look again.",
	invalid = "That can't be set against anything yet.",
}

-- What the server made of the last claim or answer.
function CaseFileView.showFeedback(result: Types.ReasoningFeedbackPayload)
	local label = feedbackLabel
	if not label then
		return
	end
	local landed = result.result == "claimed" or result.result == "correct"
	-- A pairing the server has judged (either way) is done with: clear it
	-- so the next one starts fresh. A "wait" keeps it to try again.
	if result.kind == "Claim" and result.result ~= "cooldown" then
		selected = {}
		refreshSelection()
	end
	if landed then
		local kind = if result.kind == "Claim" then "CONTRADICTION" else "DEDUCTION"
		label.Text = `{kind} ESTABLISHED  ·  {string.upper(result.label or "")}`
		label.TextColor3 = Theme.Accent
		-- A stamp: in large, settling.
		local scale = feedbackScale
		if scale then
			scale.Scale = 1.35
			TweenService
				:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
	else
		label.Text = FEEDBACK[result.result] or ""
		label.TextColor3 = Theme.TextSecondary
	end
	label.TextTransparency = 0
end

--------------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------------

local function setVisible(visible: boolean)
	isOpen = visible
	targetAlpha = visible and 1 or 0
	if visible and gui then
		gui.Enabled = true
	end
	if not visible and gui then
		task.delay(0.3, function()
			if not isOpen and gui then
				gui.Enabled = false
			end
		end)
	end
end

function CaseFileView.open()
	if not root then
		return
	end
	root.Visible = true
	if feedbackLabel then
		feedbackLabel.Text = ""
	end
	setVisible(true)
	if InputHints.scheme() == "Gamepad" and firstSelectable then
		GuiService.SelectedObject = firstSelectable
	end
end

function CaseFileView.close()
	if not isOpen then
		return
	end
	local current = GuiService.SelectedObject
	if current and root and current:IsDescendantOf(root) then
		GuiService.SelectedObject = nil
	end
	setVisible(false)
end

function CaseFileView.toggle()
	if isOpen then
		CaseFileView.close()
	else
		CaseFileView.open()
	end
end

function CaseFileView.start()
	gui = Components.screenGui("MysteryCase_CaseFile", 18)
	local screen = gui :: ScreenGui
	screen.Enabled = false

	root = Components.frame({
		name = "CaseFile",
		size = UDim2.fromOffset(780, 600),
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
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(math.min((viewport.X - 40) / 780, (viewport.Y - 40) / 600), 0.5, 1)
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
		text = "CASE FILE",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.Accent,
		parent = panel,
	})

	Components.text({
		name = "Title",
		text = "Investigation Notes",
		size = UDim2.new(0.5, 0, 0, 30),
		position = UDim2.fromOffset(0, 36),
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.TextPrimary,
		parent = panel,
	})

	-- The result of the last claim or answer, top right.
	local feedback = Components.text({
		name = "Feedback",
		text = "",
		size = UDim2.new(0.55, 0, 0, 20),
		position = UDim2.new(0.45, 0, 0, 42),
		font = Theme.FontBold,
		textSize = 13,
		color = Theme.Accent,
		xAlign = Enum.TextXAlignment.Right,
		parent = panel,
	})
	local stampScale = Instance.new("UIScale")
	stampScale.Parent = feedback
	feedbackLabel = feedback
	feedbackScale = stampScale

	-- A ScrollingFrame: the file grows over play.
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Content"
	scroller.Size = UDim2.new(1, 0, 1, -140)
	scroller.Position = UDim2.fromOffset(0, 78)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Accent
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroller.Parent = panel
	content = scroller

	emptyLabel = Components.text({
		name = "Empty",
		text = "Nothing on file yet. Talk to people. Look around.",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 4),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = scroller,
	})
	local empty = emptyLabel :: TextLabel
	empty.TextWrapped = true
	empty.TextYAlignment = Enum.TextYAlignment.Top

	-- The action bar: what is set side by side, and the claim.
	local selection = Components.text({
		name = "Selection",
		text = "",
		size = UDim2.new(1, -250, 0, 18),
		position = UDim2.new(0, 0, 1, -46),
		textSize = 12,
		color = Theme.TextPrimary,
		parent = panel,
	})
	selection.TextTruncate = Enum.TextTruncate.AtEnd
	selectionLabel = selection

	local button = Instance.new("TextButton")
	button.Name = "Claim"
	button.Size = UDim2.new(0, 230, 0, 34)
	button.Position = UDim2.new(1, -230, 1, -54)
	button.BackgroundColor3 = Theme.Accent
	button.BorderSizePixel = 0
	button.Font = Theme.FontBold
	button.TextSize = 14
	button.TextColor3 = Theme.Background
	button.Text = "THESE DON'T ADD UP"
	button.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	button.Activated:Connect(function()
		if #selected ~= 2 then
			return
		end
		claimRequested:Fire(
			{ kind = selected[1].kind, id = selected[1].id },
			{ kind = selected[2].kind, id = selected[2].id }
		)
	end)
	claimButton = button

	local hint = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, -250, 0, 16),
		position = UDim2.new(0, 0, 1, -20),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = panel,
	})
	-- On touch the Case File button toggles it closed.
	InputHints.bind(hint, "CaseFile", "Close")

	refreshSelection()

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.18
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.94
		end
	end)
end

return CaseFileView
