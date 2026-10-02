--!strict
--[[
	TimelineView
	Case timeline overlay. Shows only the events the player has discovered.

	The timeline is a mechanic, not decoration. Until the player has
	reconstructed it, events arrive in the case's authored (non-chronological)
	order and the view offers move-up/move-down controls plus a "Confirm
	sequence" action. The client submits an ordered list of event ids and
	renders whatever the server sends back -- it never decides whether the
	order is correct. Once established, the server sends canonical
	chronological order and the view becomes read-only.

	Presentation only: it renders facts, never conclusions.
	Opened with T; dismissed by T or the menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

local TimelineView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local listFrame: Frame? = nil
local emptyLabel: TextLabel? = nil
local counterLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local confirmButton: TextButton? = nil

local rows: { Frame } = {}
local isOpen = false
local targetAlpha = 0
local currentAlpha = 0

-- The server-authoritative view state, and the player's working order (ids).
local established = false
local workingOrder: { string } = {}
-- Latest payload by id, to render rows without re-fetching.
local eventById: { [string]: Types.TimelineEventProgress } = {}

-- The last server payload's raw contents, kept so a reorder can re-render
-- without needing a fresh server message.
local lastEvents: { Types.TimelineEventProgress } = {}
local lastTotal = 0

-- Fired with the ordered id list when the player confirms the sequence.
local orderSubmitted: BindableEvent = Instance.new("BindableEvent")

function TimelineView.onOrderSubmitted(): BindableEvent
	return orderSubmitted
end

function TimelineView.isOpen(): boolean
	return isOpen
end

local function clearRows()
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	rows = {}
end

-- Move the event at `index` one step in the working order and re-render.
local function move(index: number, delta: number)
	local target = index + delta
	if target < 1 or target > #workingOrder then
		return
	end
	workingOrder[index], workingOrder[target] = workingOrder[target], workingOrder[index]
	TimelineView.update({
		events = lastEvents,
		totalEvents = lastTotal,
		established = established,
	})
end

local function renderRow(index: number, event: Types.TimelineEventProgress, reorderable: boolean)
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

	-- Timestamp marker on the left. While unconfirmed the timestamp is
	-- deliberately dimensioned down: the player orders by content, and the
	-- server is the only thing that knows the true order.
	Components.text({
		name = "Time",
		text = if reorderable then "?" else event.timestamp,
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
		size = UDim2.new(1, -94, 0, 18),
		position = UDim2.fromOffset(84, 0),
		textSize = 14,
		color = Theme.TextPrimary,
		parent = row,
	})

	local desc = Components.text({
		name = "Description",
		text = event.description,
		size = UDim2.new(1, -94, 0, 18),
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
		size = UDim2.new(1, -94, 0, 16),
		position = UDim2.fromOffset(84, 36),
		textSize = 10,
		color = Theme.TextSecondary,
		parent = row,
	})

	if reorderable then
		local up = Instance.new("TextButton")
		up.Name = "MoveUp"
		up.Size = UDim2.fromOffset(26, 26)
		up.Position = UDim2.new(1, -30, 0, 6)
		up.BackgroundColor3 = Theme.Panel
		up.BackgroundTransparency = 0.1
		up.BorderSizePixel = 0
		up.Font = Theme.FontBold
		up.TextSize = 16
		up.TextColor3 = Theme.Accent
		up.Text = "\u{25B2}"
		up.AutoButtonColor = true
		up.Parent = row
		local upCorner = Instance.new("UICorner")
		upCorner.CornerRadius = UDim.new(0, 4)
		upCorner.Parent = up
		up.Activated:Connect(function() move(index, -1) end)

		local down = Instance.new("TextButton")
		down.Name = "MoveDown"
		down.Size = UDim2.fromOffset(26, 26)
		down.Position = UDim2.new(1, -30, 0, 34)
		down.BackgroundColor3 = Theme.Panel
		down.BackgroundTransparency = 0.1
		down.BorderSizePixel = 0
		down.Font = Theme.FontBold
		down.TextSize = 16
		down.TextColor3 = Theme.Accent
		down.Text = "\u{25BC}"
		down.AutoButtonColor = true
		down.Parent = row
		local downCorner = Instance.new("UICorner")
		downCorner.CornerRadius = UDim.new(0, 4)
		downCorner.Parent = down
		down.Activated:Connect(function() move(index, 1) end)
	end
end

function TimelineView.update(payload: Types.TimelinePayload)
	if not listFrame then
		return
	end

	lastEvents = payload.events
	lastTotal = payload.totalEvents

	local wasEstablished = established
	established = payload.established == true

	eventById = {}
	for _, event in ipairs(payload.events) do
		eventById[event.id] = event
	end

	if established then
		-- Canonical order straight from the server.
		workingOrder = {}
		for _, event in ipairs(payload.events) do
			table.insert(workingOrder, event.id)
		end
	elseif wasEstablished or #workingOrder == 0 then
		-- Fresh puzzle (first render, or a replay after an established
		-- run): start from the authored order the server sent. Any other
		-- update keeps the player's arrangement -- resetting here on every
		-- update used to undo each move-up/move-down as it was made.
		workingOrder = {}
		for _, event in ipairs(payload.events) do
			table.insert(workingOrder, event.id)
		end
	else
		-- Drop anything no longer in the payload (never submit a stale id).
		local kept = {}
		for _, id in ipairs(workingOrder) do
			if eventById[id] then
				table.insert(kept, id)
			end
		end
		workingOrder = kept
	end
	-- While unconfirmed and already arranging, keep the player's working
	-- order even if a redundant update arrives (e.g. a sync request).
	-- Newly-discovered events are appended so none is ever lost.
	for _, event in ipairs(payload.events) do
		local present = false
		for _, id in ipairs(workingOrder) do
			if id == event.id then
				present = true
				break
			end
		end
		if not present then
			table.insert(workingOrder, event.id)
		end
	end

	clearRows()

	if #payload.events == 0 then
		if emptyLabel then
			emptyLabel.Visible = true
		end
	elseif emptyLabel then
		emptyLabel.Visible = false
	end

	for index, id in ipairs(workingOrder) do
		local event = eventById[id]
		if event then
			renderRow(index, event, not established)
		end
	end

	if counterLabel then
		counterLabel.Text = `EVENTS {#payload.events} / {payload.totalEvents}`
	end
	if statusLabel then
		if established then
			statusLabel.Text = "SEQUENCE ESTABLISHED"
			statusLabel.TextColor3 = Theme.Accent
		else
			statusLabel.Text = "Put the events in the order they happened, then confirm."
			statusLabel.TextColor3 = Theme.TextSecondary
		end
	end
	if confirmButton then
		confirmButton.Visible = not established and #payload.events >= 2
	end
end

-- The ordered ids the player currently has. Purely presentation -- the
-- server decides whether this order is right.
function TimelineView.getWorkingOrder(): { string }
	return workingOrder
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

	-- Tall enough for seven events (CASE-001's full night: 72 px a row) above
	-- the confirm button; fitToViewport shrinks it on a smaller screen.
	root = Components.frame({
		name = "Timeline",
		size = UDim2.fromOffset(520, 700),
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
	Components.fitToViewport(root, Vector2.new(520, 700))

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

	statusLabel = Components.text({
		name = "Status",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 64),
		textSize = 11,
		color = Theme.TextSecondary,
		parent = root,
	})

	listFrame = Components.frame({
		name = "Events",
		size = UDim2.new(1, 0, 1, -150),
		position = UDim2.fromOffset(0, 86),
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

	confirmButton = Instance.new("TextButton")
	confirmButton.Name = "Confirm"
	confirmButton.Size = UDim2.fromOffset(200, 34)
	confirmButton.Position = UDim2.new(0, 0, 1, -30)
	confirmButton.BackgroundColor3 = Theme.Panel
	confirmButton.BackgroundTransparency = 0.1
	confirmButton.BorderSizePixel = 0
	confirmButton.Font = Theme.FontBold
	confirmButton.TextSize = 13
	confirmButton.TextColor3 = Theme.Accent
	confirmButton.Text = "Confirm sequence"
	confirmButton.AutoButtonColor = true
	confirmButton.Visible = false
	confirmButton.Parent = root
	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 4)
	confirmCorner.Parent = confirmButton
	local confirmStroke = Instance.new("UIStroke")
	confirmStroke.Color = Theme.PanelStroke
	confirmStroke.Thickness = 1
	confirmStroke.Parent = confirmButton
	confirmButton.Activated:Connect(function()
		if not established then
			orderSubmitted:Fire(TimelineView.getWorkingOrder())
		end
	end)

	local hint = Components.text({
		name = "Hint",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -20),
		textSize = 11,
		color = Theme.TextSecondary,
		xAlign = Enum.TextXAlignment.Right,
		parent = root,
	})
	-- On touch the Timeline button toggles it closed.
	InputHints.bind(hint, "Timeline", "Close")

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.18
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.94
		end
	end)
end

return TimelineView
