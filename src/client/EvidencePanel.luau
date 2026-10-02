--!strict
--[[
	EvidencePanel
	Investigation-style evidence panel. Dark, minimal, dismissed with the
	primary key or its continue control.
	Displayed when evidence is discovered.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

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
local relatedLabel: TextLabel? = nil
local importanceLabel: TextLabel? = nil
local counterLabel: TextLabel? = nil
local headerLabel: TextLabel? = nil
local isOpen = false

local openedEvent: BindableEvent = Instance.new("BindableEvent")
local continueRequested: BindableEvent = Instance.new("BindableEvent")

function EvidencePanel.onOpened(): BindableEvent
	return openedEvent
end

-- Fired when the player clicks the panel's continue control.
function EvidencePanel.onContinueRequested(): BindableEvent
	return continueRequested
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
	if headerLabel then
		headerLabel.Text = if payload.revisited then "EVIDENCE — ON FILE" else "EVIDENCE DISCOVERED"
	end

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

	-- Authored cross-references to already-discovered evidence.
	-- Evidence handed over with this one gets a line of its own
	-- above the cross-references; its full readout lives in the Case File.
	if relatedLabel then
		local lines = {}
		if payload.alsoAdded and #payload.alsoAdded > 0 then
			table.insert(lines, `ALSO ADDED  {table.concat(payload.alsoAdded, ", ")}`)
		end
		if payload.related and #payload.related > 0 then
			table.insert(lines, `RELATED  {table.concat(payload.related, ", ")}`)
		end
		relatedLabel.Text = table.concat(lines, "\n")
		relatedLabel.Visible = #lines > 0
	end

	setVisible(true)
	openedEvent:Fire(payload)
end

function EvidencePanel.close()
	if not isOpen then
		return
	end
	setVisible(false)
end

function EvidencePanel.start()
	gui = Components.screenGui("MysteryCase_Evidence", 20)
	gui.Enabled = false

	root = Components.frame({
		name = "EvidencePanel",
		size = UDim2.fromOffset(470, 310),
		-- Offset to the left so the panel sits beside the examined object rather
		-- than covering it. The examine camera frames the object slightly right
		-- of centre, keeping both readable.
		position = UDim2.new(0, 40, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = Theme.Panel,
		transparency = 0.08,
		radius = 8,
		border = true,
		parent = gui,
	})
	root.Visible = false
	Components.padding(root, 22)
	-- Horizontal margin covers the 40px left offset on both sides.
	Components.fitToViewport(root, Vector2.new(470, 310), Vector2.new(80, 40))

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 40, 0, 2),
		position = UDim2.fromOffset(0, 2),
		color = Theme.Accent,
		radius = 1,
		parent = root,
	})
	accent.BackgroundTransparency = 0

	headerLabel = Components.text({
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

	relatedLabel = Components.text({
		name = "Related",
		text = "",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 210),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})
	relatedLabel.TextWrapped = true
	relatedLabel.TextYAlignment = Enum.TextYAlignment.Top
	relatedLabel.Visible = false

	importanceLabel = Components.text({
		name = "Importance",
		text = "",
		size=UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -34),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = root,
	})

	-- Escape is reserved by the Roblox menu in live clients, so the panel is
	-- dismissed with the primary key or by clicking this hint.
	local continueButton = Instance.new("TextButton")
	continueButton.Name = "Hint"
	continueButton.AnchorPoint = Vector2.new(1, 0)
	continueButton.Size = UDim2.fromOffset(120, 18)
	continueButton.Position = UDim2.new(1, 0, 1, -16)
	continueButton.BackgroundTransparency = 1
	continueButton.Font = Theme.Font
	continueButton.TextSize = 11
	continueButton.TextColor3 = Theme.Accent
	continueButton.TextXAlignment = Enum.TextXAlignment.Right
	continueButton.AutoButtonColor = false
	continueButton.Parent = root
	-- Tappable as-is on touch, so it keeps a label there too.
	InputHints.bind(continueButton, "Interact", "Continue", "Continue")
	continueButton.Activated:Connect(function()
		continueRequested:Fire()
	end)
end

return EvidencePanel
