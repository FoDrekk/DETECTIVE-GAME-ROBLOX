--!strict
--[[
	CaseFileView
	Persistent investigation case file: unlocked statements, contradictions
	and deductions. Presentation only -- renders exactly the spoiler-safe
	Types.ReasoningPayload the server sends, and decides nothing about what
	is unlocked or how facts relate to each other.

	Opened and dismissed with C, and dismissed with ESC (mirrors TimelineView).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local InputHints = require(script.Parent:WaitForChild("InputHints"))

local CaseFileView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local content: ScrollingFrame? = nil
local emptyLabel: TextLabel? = nil

local rows: { Instance } = {}
local isOpen = false
local targetAlpha = 0
local currentAlpha = 0

function CaseFileView.isOpen(): boolean
	return isOpen
end

local function clearRows()
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	rows = {}
end

local function addHeader(y: number, text: string): number
	local label = Components.text({
		name = "Header",
		text = text,
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, y),
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.Accent,
		parent = content,
	})
	table.insert(rows, label)
	return y + 24
end

local function addStatementRow(y: number, statement: Types.StatementPayload): number
	local row = Components.frame({
		name = "Statement_" .. statement.id,
		size = UDim2.new(1, 0, 0, 56),
		position = UDim2.fromOffset(0, y),
		color = Theme.Background,
		transparency = 0.4,
		radius = 5,
		parent = content,
	})
	Components.padding(row, 10)
	table.insert(rows, row)

	Components.text({
		name = "Label",
		text = `{string.upper(statement.suspectName)} — {string.upper(statement.label)}`,
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = row,
	})

	local body = Components.text({
		name = "Text",
		text = statement.text,
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 16),
		textSize = 13,
		color = Theme.TextPrimary,
		parent = row,
	})
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top

	return y + 64
end

local function addContradictionRow(y: number, contradiction: Types.ContradictionPayload): number
	local rowHeight = if contradiction.reason then 80 else 56
	local row = Components.frame({
		name = "Contradiction_" .. contradiction.id,
		size = UDim2.new(1, 0, 0, rowHeight),
		position = UDim2.fromOffset(0, y),
		color = Theme.Background,
		transparency = 0.4,
		radius = 5,
		parent = content,
	})
	Components.padding(row, 10)
	table.insert(rows, row)

	Components.text({
		name = "Label",
		text = string.upper(contradiction.label),
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = row,
	})

	Components.text({
		name = "Summary",
		text = `{contradiction.leftSummary}  vs.  {contradiction.rightSummary}`,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 16),
		textSize = 13,
		color = Theme.TextPrimary,
		parent = row,
	})

	if contradiction.reason then
		local reason = Components.text({
			name = "Reason",
			text = contradiction.reason,
			size = UDim2.new(1, 0, 0, 34),
			position = UDim2.fromOffset(0, 34),
			textSize = 11,
			color = Theme.TextSecondary,
			parent = row,
		})
		reason.TextWrapped = true
		reason.TextYAlignment = Enum.TextYAlignment.Top
	end

	return y + rowHeight + 8
end

local function addDeductionRow(y: number, deduction: Types.DeductionPayload): number
	local row = Components.frame({
		name = "Deduction_" .. deduction.id,
		size = UDim2.new(1, 0, 0, 56),
		position = UDim2.fromOffset(0, y),
		color = Theme.Background,
		transparency = 0.4,
		radius = 5,
		parent = content,
	})
	Components.padding(row, 10)
	table.insert(rows, row)

	Components.text({
		name = "Label",
		text = string.upper(deduction.label),
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.Accent,
		parent = row,
	})

	local basedOn = if #deduction.basedOn > 0 then table.concat(deduction.basedOn, ", ") else "—"
	local body = Components.text({
		name = "BasedOn",
		text = `Based on: {basedOn}`,
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 16),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = row,
	})
	body.TextWrapped = true

	return y + 64
end

local function addRelatedRow(y: number, entry: Types.RelatedEvidencePayload): number
	local row = Components.frame({
		name = "Related_" .. entry.id,
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.fromOffset(0, y),
		color = Theme.Background,
		transparency = 0.4,
		radius = 5,
		parent = content,
	})
	Components.padding(row, 10)
	table.insert(rows, row)

	Components.text({
		name = "Label",
		text = string.upper(entry.name),
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 0),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.TextPrimary,
		parent = row,
	})

	local related = if #entry.related > 0 then table.concat(entry.related, ", ") else "—"
	local body = Components.text({
		name = "Related",
		text = `Linked to: {related}`,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 16),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = row,
	})
	body.TextWrapped = true

	return y + 52
end

-- Renders exactly the server-authorized reasoning state. A section with no
-- entries is simply not drawn (no empty placeholder rows).
function CaseFileView.update(payload: Types.ReasoningPayload)
	if not content or not emptyLabel then
		return
	end

	clearRows()

	local y = 0
	local hasContent = #payload.statements > 0
		or #payload.contradictions > 0
		or #payload.deductions > 0
		or #payload.relatedEvidence > 0
	emptyLabel.Visible = not hasContent

	if #payload.statements > 0 then
		y = addHeader(y, "STATEMENTS")
		for _, statement in ipairs(payload.statements) do
			y = addStatementRow(y, statement)
		end
		y += 10
	end

	if #payload.contradictions > 0 then
		y = addHeader(y, "CONTRADICTIONS")
		for _, contradiction in ipairs(payload.contradictions) do
			y = addContradictionRow(y, contradiction)
		end
		y += 10
	end

	if #payload.deductions > 0 then
		y = addHeader(y, "DEDUCTIONS")
		for _, deduction in ipairs(payload.deductions) do
			y = addDeductionRow(y, deduction)
		end
		y += 10
	end

	-- Phase 2O: discovered evidence cross-references. Only pairs where both
	-- items are already discovered ever arrive in this payload.
	if #payload.relatedEvidence > 0 then
		y = addHeader(y, "EVIDENCE LINKS")
		for _, entry in ipairs(payload.relatedEvidence) do
			y = addRelatedRow(y, entry)
		end
	end

	if content then
		content.CanvasSize = UDim2.new(0, 0, 0, y)
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

function CaseFileView.open()
	if not root then
		return
	end
	root.Visible = true
	setVisible(true)
end

function CaseFileView.close()
	if not isOpen then
		return
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
	gui.Enabled = false

	root = Components.frame({
		name = "CaseFile",
		size = UDim2.fromOffset(560, 460),
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
		text = "CASE FILE",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 14),
		textSize = 11,
		color = Theme.Accent,
		parent = root,
	})

	Components.text({
		name = "Title",
		text = "Investigation Notes",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 36),
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.TextPrimary,
		parent = root,
	})

	-- A ScrollingFrame, not a plain Frame: the case grows over play (more
	-- statements, contradictions and deductions than any one case started
	-- with), so the panel scrolls rather than overflowing past its border.
	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -110)
	content.Position = UDim2.fromOffset(0, 78)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Theme.Accent
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.None
	content.Parent = root

	emptyLabel = Components.text({
		name = "Empty",
		text = "No statements, contradictions or deductions recorded yet.",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 4),
		textSize = 12,
		color = Theme.TextSecondary,
		parent = content,
	})
	emptyLabel.TextWrapped = true
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Top

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
	-- On touch the Case File button toggles it closed.
	InputHints.bind(hint, "CaseFile", "Close")

	RunService.RenderStepped:Connect(function()
		currentAlpha += (targetAlpha - currentAlpha) * 0.18
		if root then
			root.BackgroundTransparency = 1 - currentAlpha * 0.94
		end
	end)
end

return CaseFileView
