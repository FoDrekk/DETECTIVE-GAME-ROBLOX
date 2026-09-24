--!strict
--[[
	DialogueView
	Full-screen investigation-style conversation presentation. Displays only
	the single current dialogue step the server sends (Types.DialoguePayload)
	-- this view never decides what comes next, never holds its own dialogue
	state, and never renders anything the server has not authorized.

	[E] continues (mirrors the interact key) and ends the conversation on its
	last line. Escape is not advertised: it is reserved by the Roblox menu in
	live clients (opening the menu still closes the conversation).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local DialogueView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local backdrop: Frame? = nil
local root: Frame? = nil
local speakerLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local statementLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local isOpen = false

function DialogueView.isOpen(): boolean
	return isOpen
end

local function setVisible(visible: boolean)
	if not gui or not root or not backdrop then
		return
	end
	isOpen = visible
	if visible then
		gui.Enabled = true
		root.Visible = true
		backdrop.BackgroundTransparency = 1
		root.BackgroundTransparency = 1
		TweenService:Create(backdrop, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 0.45,
		}):Play()
		TweenService:Create(root, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 0.08,
		}):Play()
	else
		local tween = TweenService:Create(backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
		TweenService:Create(root, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		}):Play()
		tween.Completed:Once(function()
			if not isOpen then
				root.Visible = false
				gui.Enabled = false
			end
		end)
		tween:Play()
	end
end

-- Renders the single authorized dialogue step. `payload.active == false`
-- closes the view (used for both natural completion and an early close).
function DialogueView.update(payload: Types.DialoguePayload)
	if not speakerLabel or not bodyLabel or not hintLabel or not statementLabel then
		return
	end

	if not payload.active then
		setVisible(false)
		return
	end

	speakerLabel.Text = string.upper(payload.suspectName or payload.speaker or "")
	bodyLabel.Text = payload.text or ""
	local key = Config.Interaction.PrimaryKey
	hintLabel.Text = if payload.canContinue then `[{key}] Continue` else `[{key}] End conversation`

	if payload.unlockedStatement then
		statementLabel.Text = `STATEMENT RECORDED — {string.upper(payload.unlockedStatement.label)}`
		statementLabel.Visible = true
	else
		statementLabel.Visible = false
	end

	setVisible(true)
end

function DialogueView.close()
	setVisible(false)
end

function DialogueView.start()
	gui = Components.screenGui("MysteryCase_Dialogue", 22)
	gui.Enabled = false

	local backdropFrame = Components.frame({
		name = "Backdrop",
		size = UDim2.fromScale(1, 1),
		color = Color3.new(0, 0, 0),
		transparency = 1,
		radius = 0,
		parent = gui,
	})
	backdropFrame.BorderSizePixel = 0
	backdrop = backdropFrame

	root = Components.frame({
		name = "Dialogue",
		size = UDim2.fromOffset(620, 220),
		position = UDim2.new(0.5, 0, 1, -60),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Background,
		transparency = 0.08,
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

	speakerLabel = Components.text({
		name = "Speaker",
		text = "",
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 14),
		font = Theme.FontBold,
		textSize = 15,
		color = Theme.Accent,
		parent = root,
	})

	bodyLabel = Components.text({
		name = "Body",
		text = "",
		size = UDim2.new(1, 0, 0, 90),
		position = UDim2.fromOffset(0, 44),
		textSize = 18,
		color = Theme.TextPrimary,
		parent = root,
	})
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.LineHeight = 1.3

	statementLabel = Components.text({
		name = "StatementNotice",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -46),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})
	statementLabel.Visible = false

	hintLabel = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -18),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})
end

return DialogueView
