--!strict
--[[
	TouchControls
	On-screen buttons for touch devices, shown only while the touch scheme is
	active (InputHints). Presentation only: every button calls
	InputController.invoke, the same entry point the keyboard and gamepad
	bindings use, so touch can never do anything a key cannot.

	  - a context-sensitive primary action beside the jump button (examine,
	    continue, begin, investigate again), labelled by the bootstrap;
	  - a column of Case File / Timeline / Accuse buttons, each shown only
	    when the bootstrap says that action is available.

	State is polled from the bootstrap's providers a few times a second
	rather than pushed from every place it can change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local InputGlyphs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InputGlyphs"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))

local InputController = require(script.Parent:WaitForChild("InputController"))
local InputHints = require(script.Parent:WaitForChild("InputHints"))

local TouchControls = {}

local Theme = Config.UI.Theme

export type Providers = {
	primaryLabel: () -> string?,
	showInvestigationButtons: () -> boolean,
	showAccuse: () -> boolean,
	-- True while the primary button should act on press and release
	-- (the intro's hold to skip) rather than on a tap. Optional.
	primaryHold: (() -> boolean)?,
}

local POLL_INTERVAL = 0.1

local gui: ScreenGui? = nil

local function button(name: string, text: string, size: UDim2, position: UDim2, anchor: Vector2, primary: boolean): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = position
	b.AnchorPoint = anchor
	b.BackgroundColor3 = if primary then Theme.Accent else Theme.Panel
	b.BackgroundTransparency = if primary then 0.05 else 0.15
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Theme.FontBold
	b.TextSize = if primary then 16 else 13
	b.TextColor3 = if primary then Theme.Background else Theme.TextPrimary
	b.TextWrapped = true
	b.Text = text
	b.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = if primary then Theme.Accent else Theme.PanelStroke
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	Components.padding(b, 6)
	return b
end

function TouchControls.start(providers: Providers)
	gui = Components.screenGui("MysteryCase_Touch", 30)

	-- Left of Roblox's jump button (bottom-right), which is at most ~120px
	-- wide and inset ~50px from the edge on large screens.
	local primary = button(
		"Primary",
		"",
		UDim2.fromOffset(180, 56),
		UDim2.new(1, -190, 1, -40),
		Vector2.new(1, 1),
		true
	)
	primary.Parent = gui
	local function holding(): boolean
		local provider = providers.primaryHold
		return provider ~= nil and provider()
	end
	primary.Activated:Connect(function()
		-- A held button already acted when it was pressed.
		if holding() then
			return
		end
		InputController.invoke("Interact")
	end)
	primary.InputBegan:Connect(function(input: InputObject)
		if not holding() then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		InputController.invoke("Interact")
		local connection: RBXScriptConnection? = nil
		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				if connection then
					connection:Disconnect()
				end
				InputController.release("Interact")
			end
		end)
	end)

	-- Secondary column on the right edge, above the jump button.
	local secondary: { { button: TextButton, show: () -> boolean } } = {}
	local entries: { { name: string, text: string, action: InputGlyphs.Action, show: () -> boolean } } = {
		{ name = "CaseFile", text = "Case File", action = "CaseFile", show = providers.showInvestigationButtons },
		{ name = "Timeline", text = "Timeline", action = "Timeline", show = providers.showInvestigationButtons },
		{ name = "Accuse", text = "Name Suspect", action = "Accuse", show = providers.showAccuse },
	}
	for index, entry in ipairs(entries) do
		local b = button(
			entry.name,
			entry.text,
			UDim2.fromOffset(120, 42),
			UDim2.new(1, -20, 0.5, -70 + (index - 1) * 50),
			Vector2.new(1, 0),
			false
		)
		b.Parent = gui
		b.Activated:Connect(function()
			InputController.invoke(entry.action)
		end)
		table.insert(secondary, { button = b, show = entry.show })
	end

	local elapsed = POLL_INTERVAL
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < POLL_INTERVAL then
			return
		end
		elapsed = 0

		local touch = InputHints.scheme() == "Touch"
		local label = if touch then providers.primaryLabel() else nil
		primary.Visible = label ~= nil
		if label then
			primary.Text = label
		end
		for _, item in ipairs(secondary) do
			item.button.Visible = touch and item.show()
		end
	end)
end

return TouchControls
