--!strict
--[[
	ObservationPanel
	Lightweight, transient flavour-text readout shown when the player examines
	a non-evidence object with an authored observation (Phase 2O).

	Deliberately distinct from EvidencePanel: no dark full panel, no
	importance/category/timestamp chrome, no counter -- just a short
	observation that fades in and out near the bottom of the screen. This is
	text, not a discovery: it renders exactly the server's
	Types.ObservationPayload and decides nothing.

	Closes on ESC (via the shared close input) and auto-dismisses after a
	short read time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ObservationPanel = {}

local Theme = Config.UI.Theme

local AUTO_DISMISS_SECONDS = 6

local gui: ScreenGui? = nil
local root: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local isOpen = false
local dismissToken = 0

function ObservationPanel.isOpen(): boolean
	return isOpen
end

local function setVisible(visible: boolean)
	if not gui or not root then
		return
	end
	isOpen = visible
	if visible then
		gui.Enabled = true
		root.Visible = true
		root.BackgroundTransparency = 1
		TweenService:Create(root, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 0.35,
		}):Play()
	else
		dismissToken += 1
		local tween = TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
		tween.Completed:Once(function()
			if not isOpen then
				root.Visible = false
				gui.Enabled = false
			end
		end)
		tween:Play()
	end
end

function ObservationPanel.show(payload: Types.ObservationPayload)
	if not titleLabel or not bodyLabel then
		return
	end
	titleLabel.Text = string.upper(payload.title)
	bodyLabel.Text = payload.body
	setVisible(true)

	-- Auto-dismiss, invalidated by any later show/close.
	dismissToken += 1
	local token = dismissToken
	task.delay(AUTO_DISMISS_SECONDS, function()
		if token == dismissToken and isOpen then
			setVisible(false)
		end
	end)
end

function ObservationPanel.close()
	if not isOpen then
		return
	end
	setVisible(false)
end

function ObservationPanel.start()
	gui = Components.screenGui("MysteryCase_Observation", 11)
	gui.Enabled = false

	root = Components.frame({
		name = "Observation",
		size = UDim2.fromOffset(520, 96),
		position = UDim2.new(0.5, 0, 1, -150),
		anchor = Vector2.new(0.5, 1),
		color = Color3.fromRGB(20, 22, 27),
		transparency = 0.35,
		radius = 5,
		border = true,
		parent = gui,
	})
	root.BackgroundTransparency = 1
	root.Visible = false
	Components.padding(root, 16)

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 3, 1, -16),
		position = UDim2.fromOffset(0, 8),
		color = Theme.TextSecondary,
		radius = 2,
		parent = root,
	})
	accent.BackgroundTransparency = 0

	titleLabel = Components.text({
		name = "Title",
		text = "",
		size = UDim2.new(1, -16, 0, 16),
		position = UDim2.fromOffset(14, 0),
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.TextSecondary,
		parent = root,
	})

	bodyLabel = Components.text({
		name = "Body",
		text = "",
		size = UDim2.new(1, -16, 0, 50),
		position = UDim2.fromOffset(14, 18),
		textSize = 14,
		color = Theme.TextPrimary,
		parent = root,
	})
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.LineHeight = 1.25
end

return ObservationPanel
