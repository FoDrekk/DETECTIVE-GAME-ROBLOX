--!strict
--[[
	InteractionPromptView
	Small, subtle "[E] Examine" prompt shown near the bottom-centre of screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))

local InteractionPromptView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local container: Frame? = nil
local keyLabel: TextLabel? = nil
local actionLabel: TextLabel? = nil
local targetAlpha = 0
local currentAlpha = 0

function InteractionPromptView.start()
	gui = Components.screenGui("MysteryCase_Prompt", 10)

	container = Components.frame({
		name = "Prompt",
		size = UDim2.fromOffset(190, 34),
		position = UDim2.new(0.5, 0, 1, -96),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.PromptBackground,
		transparency = 0.1,
		radius = 5,
		border = true,
		parent = gui,
	})
	container.BackgroundTransparency = 1

	keyLabel = Components.text({
		name = "Key",
		text = "[E]",
		size = UDim2.fromOffset(46, 34),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 13,
		color = Theme.Accent,
		xAlign = Enum.TextXAlignment.Center,
		parent = container,
	})
	actionLabel = Components.text({
		name = "Action",
		text = "Examine",
		size = UDim2.new(1, -50, 1, 0),
		position = UDim2.fromOffset(46, 0),
		textSize = 13,
		color = Theme.TextPrimary,
		parent = container,
	})

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.2
		if container then
			container.BackgroundTransparency = 1 - currentAlpha * 0.9
			container.Visible = currentAlpha > 0.01
		end
	end)
end

function InteractionPromptView.setPrompt(key: string?, label: string?)
	if not key or not label then
		targetAlpha = 0
		return
	end
	if keyLabel then
		keyLabel.Text = `[{key}]`
	end
	if actionLabel then
		actionLabel.Text = label
	end
	targetAlpha = 1
end

return InteractionPromptView
