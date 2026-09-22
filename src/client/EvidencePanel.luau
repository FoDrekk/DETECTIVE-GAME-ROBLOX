--!strict
--[[
	EvidencePanel
	Investigation-style evidence panel. Dark, minimal, dismissible with ESC.
	Displayed when evidence is discovered.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local EvidencePanel = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local titleLabel: TextLabel? = nil
local locationLabel: TextLabel? = nil
local timeLabel: TextLabel? = nil
local categoryLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local detailsLabel: TextLabel? = nil
local importanceLabel: TextLabel? = nil
local counterLabel: TextLabel? = nil
local isOpen = false

local openedEvent: BindableEvent = Instance.new("BindableEvent")
local closedEvent: BindableEvent = Instance.new("BindableEvent")

function EvidencePanel.onOpened(): BindableEvent
	return openedEvent
end

function EvidencePanel.onClosed(): BindableEvent
	return closedEvent
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
		TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 0.08,
		}):Play()
	else
		local tween = TweenService:Create(root, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
		tween.Completed:Once(function()
			root.Visible = false
			gui.Enabled = false
		end)
		tween:Play()
	end
end

function EvidencePanel.isOpen(): boolean
	return isOpen
end

function EvidencePanel.show(payload: Types.EvidencePayload)
	if not titleLabel then
		return
	end
	local ev = payload.evidence
	titleLabel.Text = ev.name
	locationLabel.Text = string.upper(ev.location)
	bodyLabel.Text = ev.description
	importanceLabel.Text = string.upper(ev.importance)
	counterLabel.Text = `{payload.totalDiscovered} / {payload.totalEvidence}`

	-- Optional fields are only shown when authored, keeping the panel clean.
	if timeLabel then
		timeLabel.Text = if ev.timestamp then `TIME  {ev.timestamp}` else ""
		timeLabel.Visible = ev.timestamp ~= nil
	end
	if categoryLabel then
		categoryLabel.Text = if ev.category then string.upper(ev.category) else ""
		categoryLabel.Visible = ev.category ~= nil
	end
	if detailsLabel then
		detailsLabel.Text = if ev.details then `DETAILS  {ev.details}` else ""
		detailsLabel.Visible = ev.details ~= nil
	end

	setVisible(true)
	openedEvent:Fire(payload)
end

function EvidencePanel.close()
	if not isOpen then
		return
	end
	setVisible(false)
	closedEvent:Fire()
end

function EvidencePanel.start()
	gui = Components.screenGui("MysteryCase_Evidence", 20)
	gui.Enabled = false

	root = Components.frame({
		name = "EvidencePanel",
		size = UDim2.fromOffset(470, 310),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Panel,
		transparency = 0.08,
		radius = 8,
		border = true,
		parent = gui,
	})
	root.Visible = false
	Components.padding(root, 22)

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 40, 0, 2),
		position = UDim2.fromOffset(0, 2),
		color = Theme.Accent,
		radius = 1,
		parent = root,
	})
	accent.BackgroundTransparency = 0

	Components.text({
		name = "Header",
		text = "EVIDENCE DISCOVERED",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	counterLabel = Components.text({
		name = "Counter",
		text = "0 / 0",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})

	titleLabel = Components.text({
		name = "Title",
		text = "Evidence",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 34),
		font = Theme.FontBold,
		textSize = 24,
		color = Theme.TextPrimary,
		parent = root,
	})

	locationLabel = Components.text({
		name = "Location",
		text = "",
		size = UDim2.new(0.6, 0, 0, 16),
		position = UDim2.fromOffset(0, 66),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	categoryLabel = Components.text({
		name = "Category",
		text = "",
		size = UDim2.new(0.4, 0, 0, 16),
		position = UDim2.new(0.6, 0, 0, 66),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})

	timeLabel = Components.text({
		name = "Time",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 86),
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.TextPrimary,
		parent = root,
	})

	bodyLabel = Components.text({
		name = "Body",
		text = "",
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 110),
		textSize = 14,
		color = Theme.TextSecondary,
		parent = root,
	})
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top

	detailsLabel = Components.text({
		name = "Details",
		text = "",
		size = UDim2.new(1, 0, 0, 56),
		position = UDim2.fromOffset(0, 148),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = root,
	})
	detailsLabel.TextWrapped = true
	detailsLabel.TextYAlignment = Enum.TextYAlignment.Top

	importanceLabel = Components.text({
		name = "Importance",
		text = "",
		size=UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -34),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = root,
	})

	local hint = Components.text({
		name = "Hint",
		text = "[ESC] Close",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -14),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})
	hint.Name = "Hint"
end

return EvidencePanel
