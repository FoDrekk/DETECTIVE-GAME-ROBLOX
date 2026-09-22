--!strict
--[[
	TimelineView
	Case timeline overlay. Shows only the events the player has discovered,
	ordered chronologically by the server. Presentation only: it renders facts,
	never conclusions.

	Opened with T and dismissed with ESC through the existing InputController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local TimelineView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local listFrame: Frame? = nil
local emptyLabel: TextLabel? = nil
local counterLabel: TextLabel? = nil

local rows: { Frame } = {}
local isOpen = false
local targetAlpha = 0
local currentAlpha = 0

function TimelineView.isOpen(): boolean
	return isOpen
end

local function clearRows()
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	rows = {}
end

local function renderEvent(index: number, event: Types.TimelineEventProgress)
	if not listFrame then
		return
	end

	local row = Components.frame({
		name = "Event_" .. event.id,
		size = UDim2.new(1, 0, 0, 64),
		position = UDim2.fromOffset(0, (index - 1) * 72),
		color = Theme.Background,
		transparency = 0.4,
		radius = 5,
		parent = listFrame,
	})
	Components.padding(row, 12)
	table.insert(rows, row)

	-- Timestamp marker on the left.
	Components.text({
		name = "Time",
		text = event.timestamp,
		size = UDim2.fromOffset(78, 18),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 13,
		color = Theme.Accent,
		parent = row,
	})

	Components.text({
		name = "Title",
		text = event.title,
		size = UDim2.new(1, -84, 0, 18),
		position = UDim2.fromOffset(84, 0),
		textSize = 14,
		color = Theme.TextPrimary,
		parent = row,
	})

	local desc = Components.text({
		name = "Description",
		text = event.description,
		size = UDim2.new(1, -84, 0, 18),
		position = UDim2.fromOffset(84, 18),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = row,
	})
	desc.TextWrapped = true

	local sourceText = if #event.sources > 0 then table.concat(event.sources, ", ") else "—"
	Components.text({
		name = "Source",
		text = `Source: {sourceText}`,
		size = UDim2.new(1, -84, 0, 16),
		position = UDim2.fromOffset(84, 36),
		textSize = 10,
		color = Theme.TextSecondary,
		parent = row,
	})
end

function TimelineView.update(payload: Types.TimelinePayload)
	if not listFrame then
		return
	end

	clearRows()

	local events = payload.events
	if #events == 0 then
		if emptyLabel then
			emptyLabel.Visible = true
		end
	else
		if emptyLabel then
			emptyLabel.Visible = false
		end
		for index, event in ipairs(events) do
			renderEvent(index, event)
		end
	end

	if counterLabel then
		counterLabel.Text = `EVENTS {#events} / {payload.totalEvents}`
	end
end

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

function TimelineView.open()
	if not root then
		return
	end
	root.Visible = true
	setVisible(true)
end

function TimelineView.close()
	if not isOpen then
		return
	end
	setVisible(false)
end

function TimelineView.toggle()
	if isOpen then
		TimelineView.close()
	else
		TimelineView.open()
	end
end

function TimelineView.start()
	gui = Components.screenGui("MysteryCase_Timeline", 16)
	gui.Enabled = false

	root = Components.frame({
		name = "Timeline",
		size = UDim2.fromOffset(520, 460),
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
		text = "CASE TIMELINE",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	counterLabel = Components.text({
		name = "Counter",
		text = "EVENTS 0 / 0",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})

	Components.text({
		name = "Title",
		text = "Sequence of Events",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 36),
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.TextPrimary,
		parent = root,
	})

	listFrame = Components.frame({
		name = "Events",
		size = UDim2.new(1, 0, 1, -110),
		position = UDim2.fromOffset(0, 78),
		transparency = 1,
		parent = root,
	})
	listFrame.BackgroundTransparency = 1
	listFrame.ClipsDescendants = false

	emptyLabel = Components.text({
		name = "Empty",
		text = "No events recorded yet.\nDiscover evidence to build the timeline.",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 4),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = listFrame,
	})
	emptyLabel.TextWrapped = true
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Top

	Components.text({
		name = "Hint",
		text = "[T] Close",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -20),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.18
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.94
		end
	end)
end

return TimelineView
