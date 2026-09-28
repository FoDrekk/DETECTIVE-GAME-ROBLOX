--!strict
--[[
	DialogueView
	Cinematic conversation presentation. Displays only the single current
	dialogue step the server sends (Types.DialoguePayload) -- this view never
	decides what comes next, never holds dialogue state of its own beyond
	presentation, and never renders anything the server has not authorized.

	Presentation:
	  * letterbox bars frame the conversation shot;
	  * a live portrait of the speaker (a copy of their NPC in a
	    ViewportFrame), their name and role;
	  * each line types itself out, pausing on punctuation so a "..." or a
	    trailing "—" reads as the hesitation it is; [E] completes the line,
	    a second [E] continues;
	  * the investigator's own lines are set apart (right-aligned, "YOU"),
	    and the question just asked is echoed above the reply;
	  * when the line waits for a question, the available choices appear
	    once it has finished typing. They can be picked with number keys,
	    the mouse, touch, or gamepad selection. A choice that was not on
	    offer the last time this character was spoken to is marked NEW, so
	    what the investigator has learned visibly opens new lines of
	    questioning.

	  * M9: when the investigator chooses to show something, the same list
	    becomes the evidence they have found (marked EVIDENCE) plus "Never
	    mind."; the reaction line echoes what was shown.

	The view reports the investigator's pick through onChoiceSelected (an id
	only), or what they show through onPresentSelected (an evidence id, or
	"" to back out); the server validates both.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Interactable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactable"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

local DialogueView = {}

local Theme = Config.UI.Theme
local Style = Config.UI.Dialogue

local CHOICE_ACTION = "MysteryCase_DialogueChoice"
local NUMBER_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local gui: ScreenGui? = nil
local letterTop: Frame? = nil
local letterBottom: Frame? = nil
local panel: Frame? = nil
local portraitFrame: Frame? = nil
local viewport: ViewportFrame? = nil
local nameLabel: TextLabel? = nil
local roleLabel: TextLabel? = nil
local promptLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local toast: TextLabel? = nil
local choiceList: Frame? = nil
local choicesFrame: Frame? = nil
local panelScale: UIScale? = nil
local choicesScale: UIScale? = nil

local isOpen = false
local typing = false
local typeToken = 0
local current: Types.DialoguePayload? = nil
-- M9: true while `current.choices` is the evidence picker (built from
-- `current.present`) rather than questions.
local presenting = false
local CANCEL_PRESENT = "__never_mind"
local choiceButtons: { TextButton } = {}
local portraitFor: string? = nil
-- suspectId -> choice ids already shown, to mark newly available ones.
local seenChoices: { [string]: { [string]: boolean } } = {}

local choiceSelectedEvent = Instance.new("BindableEvent")
local presentSelectedEvent = Instance.new("BindableEvent")

-- Fired with the chosen choice id.
function DialogueView.onChoiceSelected(): BindableEvent
	return choiceSelectedEvent
end

-- M9: fired with the evidence id to show, or "" to back out.
function DialogueView.onPresentSelected(): BindableEvent
	return presentSelectedEvent
end

function DialogueView.isOpen(): boolean
	return isOpen
end

-- True while the current line waits for the investigator to pick a choice.
function DialogueView.awaitingChoice(): boolean
	return isOpen and current ~= nil and current.choices ~= nil
end

--------------------------------------------------------------------------
-- Portrait
--------------------------------------------------------------------------

local function findNpcModel(suspectId: string): Model?
	for _, instance in ipairs(CollectionService:GetTagged(Interactable.TAG)) do
		if instance:GetAttribute(Interactable.AttributeName.SuspectId) == suspectId then
			local model = instance.Parent
			if model and model:IsA("Model") then
				return model
			end
		end
	end
	return nil
end

-- A still copy of the speaker's NPC, framed head-and-shoulders.
local function setPortrait(suspectId: string?)
	if not viewport or suspectId == portraitFor then
		return
	end
	portraitFor = suspectId
	viewport:ClearAllChildren()
	if not suspectId then
		return
	end
	local source = findNpcModel(suspectId)
	if not source then
		return
	end
	local wasArchivable = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = wasArchivable
	if not copy then
		return
	end
	for _, descendant in ipairs(copy:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
	local head = copy:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		copy:Destroy()
		return
	end
	-- Face the camera straight on regardless of how the NPC stands.
	local facing = head.CFrame.LookVector
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local eye = head.Position + flat.Unit * Style.PortraitDistance + Vector3.new(0, 0.1, 0)
	local camera = Instance.new("Camera")
	camera.FieldOfView = Style.PortraitFieldOfView
	camera.CFrame = CFrame.lookAt(eye, head.Position - Vector3.new(0, Style.PortraitAimDrop, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	copy.Parent = viewport
end

--------------------------------------------------------------------------
-- Typewriter
--------------------------------------------------------------------------

-- Seconds to hold after revealing the character `char`, given the next one.
local function pauseAfter(char: string, nextChar: string?): number
	if char == "." or char == "…" then
		-- A run of dots is a hesitation: each dot lingers.
		if nextChar == "." then
			return Style.EllipsisPause
		end
		return if nextChar == nil or nextChar == " " or nextChar == "\"" then Style.SentencePause else 0
	elseif char == "?" or char == "!" then
		return if nextChar == nil or nextChar == " " or nextChar == "\"" then Style.SentencePause else 0
	elseif char == "," or char == ";" or char == ":" then
		return Style.CommaPause
	elseif char == "—" or char == "–" then
		return Style.DashPause
	end
	return 0
end

local function finishTyping()
	typeToken += 1
	typing = false
	if bodyLabel then
		bodyLabel.MaxVisibleGraphemes = -1
	end
end

local refreshAfterTyping: () -> ()

local function typeOut(text: string)
	local label = bodyLabel
	if not label then
		return
	end
	typeToken += 1
	local token = typeToken
	typing = true
	label.Text = text
	label.MaxVisibleGraphemes = 0

	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end

	task.spawn(function()
		local shown = 0
		local budget = 0
		local last = os.clock()
		while shown < #chars do
			task.wait()
			if token ~= typeToken then
				return
			end
			local now = os.clock()
			budget += (now - last) * Style.CharactersPerSecond
			last = now
			while budget >= 1 and shown < #chars do
				shown += 1
				budget -= 1
				label.MaxVisibleGraphemes = shown
				local hold = pauseAfter(chars[shown], chars[shown + 1])
				if hold > 0 then
					task.wait(hold)
					if token ~= typeToken then
						return
					end
					last = os.clock()
					budget = 0
					break
				end
			end
		end
		if token == typeToken then
			typing = false
			label.MaxVisibleGraphemes = -1
			refreshAfterTyping()
		end
	end)
end

--------------------------------------------------------------------------
-- Choices
--------------------------------------------------------------------------

local function unbindChoiceKeys()
	ContextActionService:UnbindAction(CHOICE_ACTION)
end

local function choicesHeight(): number
	local n = #choiceButtons
	if n == 0 then
		return 0
	end
	return n * Style.ChoiceHeight + (n - 1) * 6
end

-- The panel's resting Position, `extra` pixels lower (used for the open
-- animation's starting point). Shared by `rescale` and `setOpen` so they
-- never compute two different answers for where the panel's bottom sits.
local function panelY(extra: number): UDim2
	local scale = if panelScale then panelScale.Scale else 1
	local inset = GuiService:GetGuiInset().Y
	return UDim2.new(0.5, 0, 1, -Style.PanelBottomOffset * scale + extra * scale + inset)
end

-- Phase 3 (R4): on a short landscape phone there isn't room for the panel
-- plus a full page of choices below the letterbox bars -- the choices were
-- found to run off the top of the screen, unreachable by touch. Shrink the
-- panel and the choices as a unit (each keeps its own UIScale, since a
-- shared scale-everything wrapper would claim 100% of the screen as its own
-- nominal size and shrink at the exact same rate as its content, never
-- gaining any relative room) so every choice stays visible and tappable,
-- rather than clipping the top rows.
local function rescale()
	if not panelScale or not choicesScale then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- The choices frame was sized for a full page (9 slots) regardless of how
	-- many choices are actually showing; shrink it to the real content so the
	-- scale math below isn't budgeting for empty space that was never drawn.
	local height = choicesHeight()
	if choicesFrame then
		choicesFrame.Size = UDim2.new(1, -32, 0, height)
	end
	local viewport = camera.ViewportSize
	local topMargin = viewport.Y * Style.LetterboxHeight + 16
	local needed = Style.PanelBottomOffset + Style.PanelHeight + 12 + height
	local available = math.max(viewport.Y - topMargin, 1)
	local scale = math.clamp(available / needed, 0.4, 1)
	panelScale.Scale = scale
	choicesScale.Scale = scale
	-- Once anything in an IgnoreGuiInset screen carries a UIScale, it renders
	-- GetGuiInset().Y pixels higher than its declared offset -- add that back
	-- so the panel and choices land where the rest of the touch HUD does.
	if panel and panel.Visible then
		panel.Position = panelY(0)
	end
	if choicesFrame then
		local inset = GuiService:GetGuiInset().Y
		choicesFrame.Position =
			UDim2.new(0.5, 0, 1, -(Style.PanelBottomOffset + Style.PanelHeight + 12) * scale + inset)
	end
end

local function clearChoices()
	unbindChoiceKeys()
	for _, button in ipairs(choiceButtons) do
		button:Destroy()
	end
	table.clear(choiceButtons)
	if choiceList then
		choiceList.Visible = false
	end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui :: ScreenGui) then
		GuiService.SelectedObject = nil
	end
	rescale()
end

local function pick(index: number)
	local payload = current
	if not payload or not payload.choices or typing then
		return
	end
	local choice = payload.choices[index]
	if not choice then
		return
	end
	clearChoices()
	if presenting then
		presentSelectedEvent:Fire(if choice.id == CANCEL_PRESENT then "" else choice.id)
	else
		choiceSelectedEvent:Fire(choice.id)
	end
end

local function styleButton(button: TextButton, highlighted: boolean)
	button.BackgroundColor3 = if highlighted then Style.ChoiceHover else Theme.Background
	button.BackgroundTransparency = if highlighted then 0.05 else 0.18
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if highlighted then Theme.Accent else Theme.PanelStroke
		stroke.Transparency = if highlighted then 0.1 else 0.45
	end
end

local function showChoices(payload: Types.DialoguePayload)
	clearChoices()
	local list = choiceList
	local choices = payload.choices
	if not list or not choices or #choices == 0 then
		return
	end
	local suspectId = payload.suspectId or ""
	local seen = seenChoices[suspectId]
	local firstVisit = seen == nil
	if not seen then
		seen = {}
		seenChoices[suspectId] = seen
	end

	local scheme = InputHints.scheme()
	for index, choice in ipairs(choices) do
		local isNew = not presenting and not firstVisit and not (seen :: { [string]: boolean })[choice.id]
		if not presenting then
			(seen :: { [string]: boolean })[choice.id] = true
		end
		local isEvidence = presenting and choice.id ~= CANCEL_PRESENT

		local button = Instance.new("TextButton")
		button.Name = `Choice{index}`
		button.AutoButtonColor = false
		button.Size = UDim2.new(1, 0, 0, Style.ChoiceHeight)
		button.LayoutOrder = index
		button.Text = ""
		button.BorderSizePixel = 0
		button.Selectable = true
		button.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button

		local key = Components.text({
			name = "Key",
			text = if scheme == "Keyboard" then tostring(index) else "›",
			size = UDim2.new(0, 34, 1, 0),
			font = Theme.FontBold,
			textSize = 15,
			color = Theme.Accent,
			xAlign = Enum.TextXAlignment.Center,
			parent = button,
		})
		key.ZIndex = 2

		local label = Components.text({
			name = "Label",
			text = choice.text,
			size = UDim2.new(1, if isNew or isEvidence then -130 else -46, 1, 0),
			position = UDim2.fromOffset(38, 0),
			textSize = 16,
			color = Theme.TextPrimary,
			parent = button,
		})
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = 2

		if isNew or isEvidence then
			local tag = Components.text({
				name = if isNew then "New" else "Evidence",
				text = if isNew then "NEW" else "EVIDENCE",
				size = UDim2.new(0, 80, 1, 0),
				position = UDim2.new(1, -88, 0, 0),
				font = Theme.FontBold,
				textSize = 11,
				color = Theme.Accent,
				xAlign = Enum.TextXAlignment.Right,
				parent = button,
			})
			tag.ZIndex = 2
		end

		styleButton(button, false)
		button.MouseEnter:Connect(function()
			styleButton(button, true)
		end)
		button.MouseLeave:Connect(function()
			styleButton(button, GuiService.SelectedObject == button)
		end)
		button.SelectionGained:Connect(function()
			styleButton(button, true)
		end)
		button.SelectionLost:Connect(function()
			styleButton(button, false)
		end)
		button.Activated:Connect(function()
			pick(index)
		end)

		-- Slide each option in, slightly staggered.
		button.Position = UDim2.fromOffset(18, 0)
		label.TextTransparency = 1
		key.TextTransparency = 1
		task.delay((index - 1) * 0.045, function()
			if button.Parent then
				TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
				TweenService:Create(key, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
			end
		end)
		table.insert(choiceButtons, button)
	end
	list.Visible = true
	rescale()

	ContextActionService:BindAction(CHOICE_ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		for index, code in ipairs(NUMBER_KEYS) do
			if input.KeyCode == code then
				pick(index)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(NUMBER_KEYS, 1, #choices))

	if scheme == "Gamepad" and choiceButtons[1] then
		GuiService.SelectedObject = choiceButtons[1]
	end
end

--------------------------------------------------------------------------
-- Line rendering
--------------------------------------------------------------------------

local function setHint()
	local label = hintLabel
	local payload = current
	if not label or not payload then
		return
	end
	if InputHints.scheme() == "Touch" then
		label.Text = ""
	elseif typing then
		label.Text = InputHints.format("Interact", "Skip")
	elseif payload.choices then
		local verb = if presenting then "Show" else "Choose"
		label.Text = if InputHints.scheme() == "Keyboard" then `{verb}  [1-9]` else verb
	else
		label.Text = InputHints.format("Interact", if payload.canContinue then "Continue" else "End conversation")
	end
end

refreshAfterTyping = function()
	local payload = current
	if payload and payload.choices then
		showChoices(payload)
	end
	setHint()
end

local function showToast(text: string)
	local label = toast
	if not label then
		return
	end
	label.Text = text
	label.Visible = true
	label.TextTransparency = 1
	label.Position = UDim2.new(0.5, 0, Style.LetterboxHeight, 6)
	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		TextTransparency = 0,
		Position = UDim2.new(0.5, 0, Style.LetterboxHeight, 18),
	}):Play()
	local stamp = text
	task.delay(3.2, function()
		if label.Text == stamp then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

-- A shallow depth of field while talking: the speaker sharp, the room
-- soft. Lives under the local camera, so it only affects this player.
local focus: DepthOfFieldEffect? = nil
local function setFocus(on: boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not focus or focus.Parent ~= camera then
		local created = Instance.new("DepthOfFieldEffect")
		created.Name = "MysteryCase_DialogueFocus"
		created.NearIntensity = 0
		created.FarIntensity = 0
		created.FocusDistance = Style.FocusDistance
		created.InFocusRadius = Style.FocusRadius
		created.Enabled = false
		created.Parent = camera
		focus = created
	end
	local effect = focus :: DepthOfFieldEffect
	if on then
		effect.Enabled = true
	end
	local tween = TweenService:Create(effect, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		FarIntensity = if on then Style.FocusBlur else 0,
	})
	if not on then
		tween.Completed:Once(function()
			if not isOpen then
				effect.Enabled = false
			end
		end)
	end
	tween:Play()
end

local function setOpen(open: boolean)
	if not gui or not panel or not letterTop or not letterBottom then
		return
	end
	if open == isOpen then
		return
	end
	isOpen = open
	setFocus(open)
	local bar = UDim2.new(1, 0, Style.LetterboxHeight, 0)
	if open then
		gui.Enabled = true
		panel.Visible = true
		panel.Position = panelY(24)
		panel.BackgroundTransparency = 1
		TweenService:Create(letterTop, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = bar }):Play()
		TweenService:Create(letterBottom, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = bar }):Play()
		TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Position = panelY(0),
			BackgroundTransparency = Style.PanelTransparency,
		}):Play()
	else
		finishTyping()
		clearChoices()
		current = nil
		local closed = UDim2.new(1, 0, 0, 0)
		TweenService:Create(letterTop, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = closed }):Play()
		TweenService:Create(letterBottom, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = closed }):Play()
		local fade = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
		fade.Completed:Once(function()
			if not isOpen and panel and gui then
				panel.Visible = false
				gui.Enabled = false
			end
		end)
		fade:Play()
	end
end

-- Renders the single authorized dialogue step. `payload.active == false`
-- closes the view (used for both natural completion and an early close).
function DialogueView.update(payload: Types.DialoguePayload)
	if not nameLabel or not roleLabel or not bodyLabel or not promptLabel or not portraitFrame then
		return
	end

	if not payload.active then
		presenting = false
		setOpen(false)
		setPortrait(nil)
		return
	end

	-- M9: showing evidence. The picker is the same choice list: the
	-- evidence found so far, then a way to back out. The line becomes the
	-- investigator's own "Show Victor…".
	local present = payload.present
	presenting = present ~= nil
	if present then
		local options = {}
		for _, evidence in ipairs(present.options) do
			table.insert(options, { id = evidence.id, text = evidence.name })
		end
		table.insert(options, { id = CANCEL_PRESENT, text = "Never mind." })
		local picker = table.clone(payload)
		picker.choices = options
		picker.text = present.prompt
		picker.isPlayer = true
		payload = picker
	end

	current = payload
	clearChoices()
	setOpen(true)

	local isPlayer = payload.isPlayer == true
	if isPlayer then
		nameLabel.Text = "YOU"
		nameLabel.TextColor3 = Theme.TextSecondary
		roleLabel.Text = ""
		bodyLabel.TextColor3 = Style.PlayerText
		bodyLabel.Font = Style.PlayerFont
	else
		nameLabel.Text = string.upper(payload.speaker or payload.suspectName or "")
		nameLabel.TextColor3 = Theme.Accent
		roleLabel.Text = if payload.suspectRole then string.upper(payload.suspectRole) else ""
		bodyLabel.TextColor3 = Theme.TextPrimary
		bodyLabel.Font = Theme.Font
	end
	-- Name, then role beside it.
	local nameWidth = TextService:GetTextSize(nameLabel.Text, nameLabel.TextSize, nameLabel.Font, Vector2.new(1000, 40)).X
	roleLabel.Position = UDim2.fromOffset(nameWidth + 12, 3)

	setPortrait(payload.suspectId)
	portraitFrame.Visible = not isPlayer or presenting

	if payload.presented and not isPlayer then
		-- The reaction to what was just shown.
		promptLabel.Text = `You show: {payload.presented}`
		promptLabel.Visible = true
		bodyLabel.Position = UDim2.fromOffset(0, Style.BodyTopWithPrompt)
	elseif payload.prompt and not isPlayer then
		promptLabel.Text = `“{payload.prompt}”`
		promptLabel.Visible = true
		bodyLabel.Position = UDim2.fromOffset(0, Style.BodyTopWithPrompt)
	else
		promptLabel.Visible = false
		bodyLabel.Position = UDim2.fromOffset(0, Style.BodyTop)
	end
	bodyLabel.TextXAlignment = if isPlayer then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	nameLabel.TextXAlignment = if isPlayer then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left

	if payload.unlockedStatement then
		local statement = payload.unlockedStatement
		showToast(`STATEMENT RECORDED  ·  {string.upper(statement.suspectName)}  ·  {string.upper(statement.label)}`)
	end

	typeOut(payload.text or "")
	setHint()
end

--[[
	The primary action ([E] / X / the touch button) while a conversation is
	open. Returns true if the view consumed it (finishing the line that is
	still typing, or a line that waits for a choice), false if the caller
	should ask the server to continue.
]]
function DialogueView.handlePrimary(): boolean
	if not isOpen then
		return false
	end
	if typing then
		finishTyping()
		refreshAfterTyping()
		return true
	end
	if current and current.choices then
		return true
	end
	return false
end

-- Label for the touch primary button while open.
function DialogueView.primaryLabel(): string?
	if typing then
		return "Skip"
	end
	if current and current.choices then
		return nil
	end
	return "Continue"
end

function DialogueView.close()
	presenting = false
	setOpen(false)
	setPortrait(nil)
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

function DialogueView.start()
	gui = Components.screenGui("MysteryCase_Dialogue", 22)
	local screen = gui :: ScreenGui
	screen.Enabled = false

	local function bar(name: string, anchorY: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.new(1, 0, 0, 0)
		f.ZIndex = 0
		f.Parent = screen
		return f
	end
	letterTop = bar("LetterboxTop", 0)
	letterBottom = bar("LetterboxBottom", 1)

	local root = Components.frame({
		name = "Dialogue",
		size = UDim2.new(1, -32, 0, Style.PanelHeight),
		position = UDim2.new(0.5, 0, 1, -Style.PanelBottomOffset),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Background,
		transparency = Style.PanelTransparency,
		radius = 10,
		border = true,
		parent = screen,
	})
	root.Visible = false
	panel = root
	-- Phase 3 (R4): shrinks the panel to fit a short viewport; see `rescale`.
	-- Kept off `root`'s own Position -- `rescale` sets that explicitly each
	-- time, scaled and inset-compensated, rather than relying on how a self-
	-- scaled object's own offset happens to resolve.
	panelScale = Instance.new("UIScale")
	panelScale.Parent = root
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(Style.PanelMaxWidth, Style.PanelHeight)
	sizeLimit.Parent = root
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new(0, 0.12)
	gradient.Parent = root

	-- Portrait
	local portrait = Components.frame({
		name = "Portrait",
		size = UDim2.fromOffset(Style.PortraitSize, Style.PortraitSize),
		position = UDim2.new(0, 22, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = Style.PortraitBackdrop,
		radius = 8,
		parent = root,
	})
	local portraitStroke = Instance.new("UIStroke")
	portraitStroke.Color = Theme.Accent
	portraitStroke.Transparency = 0.55
	portraitStroke.Thickness = 1
	portraitStroke.Parent = portrait
	portraitFrame = portrait
	local vp = Instance.new("ViewportFrame")
	vp.Name = "View"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Style.PortraitAmbient
	vp.LightColor = Style.PortraitLight
	vp.LightDirection = Vector3.new(-0.6, -0.4, -1)
	vp.Parent = portrait
	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 8)
	vpCorner.Parent = vp
	viewport = vp

	-- Text column
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(Style.PortraitSize + 46, 20)
	column.Size = UDim2.new(1, -(Style.PortraitSize + 46 + 28), 1, -34)
	column.Parent = root

	nameLabel = Components.text({
		name = "Speaker",
		text = "",
		size = UDim2.new(1, 0, 0, 22),
		font = Theme.FontBold,
		textSize = 17,
		color = Theme.Accent,
		parent = column,
	})
	roleLabel = Components.text({
		name = "Role",
		text = "",
		size = UDim2.new(0, 220, 0, 18),
		position = UDim2.fromOffset(120, 3),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = column,
	})
	local prompt = Components.text({
		name = "Prompt",
		text = "",
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 30),
		textSize = 14,
		color = Theme.TextSecondary,
		parent = column,
	})
	prompt.Font = Style.PlayerFont
	prompt.TextTruncate = Enum.TextTruncate.AtEnd
	prompt.Visible = false
	promptLabel = prompt

	local body = Components.text({
		name = "Body",
		text = "",
		size = UDim2.new(1, 0, 1, -(Style.BodyTopWithPrompt + 18)),
		position = UDim2.fromOffset(0, Style.BodyTop),
		textSize = Style.BodyTextSize,
		color = Theme.TextPrimary,
		parent = column,
	})
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.LineHeight = 1.22
	bodyLabel = body

	hintLabel = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -14),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = column,
	})

	-- Choices, stacked above the panel's right side.
	local list = Instance.new("Frame")
	list.Name = "Choices"
	list.BackgroundTransparency = 1
	list.AnchorPoint = Vector2.new(0.5, 1)
	list.Position = UDim2.new(0.5, 0, 1, -(Style.PanelBottomOffset + Style.PanelHeight + 12))
	list.Size = UDim2.new(1, -32, 0, 9 * (Style.ChoiceHeight + 6))
	list.Visible = false
	list.Parent = screen
	choicesFrame = list
	-- Phase 3 (R4): its own UIScale, kept in sync with the panel's by
	-- `rescale`, rather than one shared wrapper (see the comment on `rescale`).
	choicesScale = Instance.new("UIScale")
	choicesScale.Parent = list
	local listLimit = Instance.new("UISizeConstraint")
	listLimit.MaxSize = Vector2.new(Style.PanelMaxWidth, 9 * (Style.ChoiceHeight + 6))
	listLimit.Parent = list
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(1, 1)
	inner.Position = UDim2.fromScale(1, 1)
	inner.Size = UDim2.new(0.62, 0, 1, 0)
	inner.Parent = list
	local innerLimit = Instance.new("UISizeConstraint")
	innerLimit.MinSize = Vector2.new(math.min(360, Style.PanelMaxWidth), 0)
	innerLimit.Parent = inner
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = inner
	choiceList = inner
	inner.Visible = false
	list.Visible = true

	local toastLabel = Components.text({
		name = "StatementToast",
		text = "",
		size = UDim2.fromOffset(640, 20),
		position = UDim2.new(0.5, 0, Style.LetterboxHeight, 18),
		anchor = Vector2.new(0.5, 0),
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.Accent,
		xAlign = Enum.TextXAlignment.Center,
		parent = screen,
	})
	toastLabel.Visible = false
	toast = toastLabel

	InputHints.changed().Event:Connect(setHint)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	rescale()
end

return DialogueView
