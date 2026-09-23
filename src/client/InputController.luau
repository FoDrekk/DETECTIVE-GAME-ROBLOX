--!strict
--[[
	InputController
	Centralised input. Uses UserInputService / ContextActionService.
	Emits intent, never performs gameplay directly.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local InputController = {}

local ACTION_INTERACT = "MysteryCase_Interact"
local ACTION_CLOSE = "MysteryCase_ClosePanel"
local ACTION_TIMELINE = "MysteryCase_ToggleTimeline"
local ACTION_CASE_FILE = "MysteryCase_ToggleCaseFile"

local interactCallback: (() -> ())? = nil
local closeCallback: (() -> ())? = nil
local timelineCallback: (() -> ())? = nil
local caseFileCallback: (() -> ())? = nil
local interactEnabled = false

function InputController.onInteract(fn: () -> ())
	interactCallback = fn
end

function InputController.onClose(fn: () -> ())
	closeCallback = fn
end

function InputController.onToggleTimeline(fn: () -> ())
	timelineCallback = fn
end

function InputController.onToggleCaseFile(fn: () -> ())
	caseFileCallback = fn
end

function InputController.start()
	ContextActionService:BindAction(ACTION_INTERACT, function(_, state)
		if not interactEnabled then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and interactCallback then
			interactCallback()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode[Config.Interaction.PrimaryKey])

	ContextActionService:BindAction(ACTION_CLOSE, function(_, state)
		if state == Enum.UserInputState.Begin and closeCallback then
			closeCallback()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode[Config.Interaction.ClosePanelKey])

	ContextActionService:BindAction(ACTION_TIMELINE, function(_, state)
		if state == Enum.UserInputState.Begin and timelineCallback then
			timelineCallback()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode[Config.Interaction.TimelineKey])

	ContextActionService:BindAction(ACTION_CASE_FILE, function(_, state)
		if state == Enum.UserInputState.Begin and caseFileCallback then
			caseFileCallback()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode[Config.Interaction.CaseFileKey])

	-- Explicitly ignore game-processed input in Phase 1.
	UserInputService.InputBegan:Connect(function(_, processed)
		if processed then
			return
		end
	end)
end

function InputController.setInteractEnabled(enabled: boolean)
	interactEnabled = enabled
end

return InputController
