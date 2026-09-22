--!strict
--[[
	CaseBriefingView
	Minimal cinematic case briefing overlay shown during the CaseBriefing phase.
	Purely presentational; phase changes are server-authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local CaseBriefingView = {}

local Theme = Config.UI.Theme

local gui: ScreenGui? = nil
local root: Frame? = nil
local caseIdLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil

local beginRequested: BindableEvent = Instance.new("BindableEvent")

function CaseBriefingView.onBeginRequested(): BindableEvent
	return beginRequested
end

local function setVisible(visible: boolean)
	if not gui or not root then
		return
	end
	if visible then
		gui.Enabled = true
		root.Visible = true
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("Frame") then
				if d.Name == "Accent" then
					continue
				end
				d.Transparency = 1
			end
		end
		TweenService:Create(root, TweenInfo.new(0.4), { BackgroundTransparency = 0.15 }):Play()
	else
		local tween = TweenService:Create(root, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			root.Visible = false
			gui.Enabled = false
		end)
		tween:Play()
	end
end

function CaseBriefingView.show(briefing: Types.CaseBriefing)
	if not titleLabel then
		return
	end
	caseIdLabel.Text = briefing.id
	titleLabel.Text = string.upper(briefing.title)
	bodyLabel.Text = briefing.description
	setVisible(true)
end

function CaseBriefingView.hide()
	setVisible(false)
end

function CaseBriefingView.start()
	gui = Components.screenGui("MysteryCase_Briefing", 15)
	gui.Enabled = false

	root = Components.frame({
		name = "Briefing",
		size = UDim2.fromOffset(560, 300),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Background,
		transparency = 0.15,
		radius = 8,
		border = true,
		parent = gui,
	})
	root.Visible = false
	Components.padding(root, 28)

	local accent = Components.frame({
		name = "Accent",
		size = UDim2.new(0, 46, 0, 2),
		position = UDim2.fromOffset(0, 4),
		color = Theme.Accent,
		radius = 1,
		parent = root,
	})

	caseIdLabel = Components.text({
		name = "CaseId",
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 22),
		textSize = 12,
		color = Theme.Accent,
		parent = root,
	})

	titleLabel = Components.text({
		name = "Title",
		text = "",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 42),
		font = Theme.FontBold,
		textSize = 30,
		color = Theme.TextPrimary,
		parent = root,
	})

	bodyLabel = Components.text({
		name = "Body",
		text = "",
		size = UDim2.new(1, 0, 0, 120),
		position = UDim2.fromOffset(0, 92),
		textSize = 15,
		color = Theme.TextSecondary,
		parent = root,
	})
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.LineHeight = 1.3

	hintLabel = Components.text({
		name = "Hint",
		text = "[ E ]  Begin Investigation",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 1, -24),
		textSize = 13,
		color = Theme.Accent,
		parent = root,
	})
end

return CaseBriefingView
