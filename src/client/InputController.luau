--!strict
--[[
	InputController
	Centralised input. Emits intent, never performs gameplay directly.

	Every action is bound to its keyboard key and its gamepad button (see
	Config.Interaction / InputGlyphs), and can be triggered directly by the
	on-screen touch controls via InputController.invoke -- so all three input
	schemes drive exactly the same callbacks.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputGlyphs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InputGlyphs"))

local InputController = {}

type Action = InputGlyphs.Action

local callbacks: { [Action]: (() -> ())? } = {}
local interactEnabled = false

function InputController.onInteract(fn: () -> ())
	callbacks.Interact = fn
end

function InputController.onClose(fn: () -> ())
	callbacks.Close = fn
end

function InputController.onToggleTimeline(fn: () -> ())
	callbacks.Timeline = fn
end

function InputController.onToggleCaseFile(fn: () -> ())
	callbacks.CaseFile = fn
end

-- Requests the accusation picker. Always bound during Investigation; whether
-- it does anything is decided by the callback (gated on the server having
-- told the client every objective is done) and re-validated server-side.
function InputController.onConcludeInvestigation(fn: () -> ())
	callbacks.Accuse = fn
end

-- Trigger an action as if its key were pressed (used by touch buttons).
function InputController.invoke(action: Action)
	if action == "Interact" and not interactEnabled then
		return
	end
	local fn = callbacks[action]
	if fn then
		fn()
	end
end

local function bind(action: Action, sink: boolean)
	ContextActionService:BindAction(`MysteryCase_{action}`, function(_, state)
		if action == "Interact" and not interactEnabled then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			local fn = callbacks[action]
			if fn then
				fn()
			end
		end
		return if sink then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end, false, table.unpack(InputGlyphs.keyCodes(action)))
end

function InputController.start()
	bind("Interact", true)
	bind("Close", false)
	bind("Timeline", true)
	bind("CaseFile", true)
	bind("Accuse", true)
end

function InputController.setInteractEnabled(enabled: boolean)
	interactEnabled = enabled
end

return InputController
