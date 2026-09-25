--!strict
--[[
	InputHints
	Tracks which input scheme the player is using (keyboard, gamepad, touch),
	following their most recent input, and keeps on-screen hints in sync.

	QA override: setting the LocalPlayer attribute `InputSchemeOverride` to
	"Keyboard", "Gamepad" or "Touch" forces that scheme (e.g. to review the
	touch layout from a desktop Studio session). Clearing it resumes
	auto-detection.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputGlyphs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InputGlyphs"))

local InputHints = {}

export type Scheme = InputGlyphs.Scheme
export type Action = InputGlyphs.Action

local OVERRIDE_ATTRIBUTE = "InputSchemeOverride"

local detected: Scheme = "Keyboard"
local current: Scheme = "Keyboard"
local changedEvent: BindableEvent = Instance.new("BindableEvent")

local function readOverride(): Scheme?
	local value = Players.LocalPlayer:GetAttribute(OVERRIDE_ATTRIBUTE)
	if value == "Keyboard" or value == "Gamepad" or value == "Touch" then
		return value
	end
	return nil
end

local function refresh()
	local nextScheme = readOverride() or detected
	if nextScheme ~= current then
		current = nextScheme
		changedEvent:Fire(current)
	end
end

function InputHints.scheme(): Scheme
	return current
end

function InputHints.changed(): BindableEvent
	return changedEvent
end

function InputHints.glyph(action: Action): string?
	return InputGlyphs.glyph(current, action)
end

function InputHints.format(action: Action, text: string): string
	return InputGlyphs.format(current, action, text)
end

--[[
	Keep `label` showing `text` with the current scheme's key hint. On touch
	there is no key: the label shows `touchText` if given, otherwise nothing
	(the touch controls offer that action as a button instead). Only the text
	is managed -- a label's visibility stays with the view that owns it.
]]
function InputHints.bind(label: TextLabel | TextButton, action: Action, text: string, touchText: string?)
	local function apply()
		if current == "Touch" then
			label.Text = touchText or ""
		else
			label.Text = InputGlyphs.format(current, action, text)
		end
	end
	apply()
	changedEvent.Event:Connect(apply)
end

function InputHints.start()
	local initial = InputGlyphs.schemeFor(UserInputService:GetLastInputType())
	if initial then
		detected = initial
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		detected = "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		detected = "Gamepad"
	end
	current = readOverride() or detected

	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local scheme = InputGlyphs.schemeFor(inputType)
		if scheme then
			detected = scheme
			refresh()
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal(OVERRIDE_ATTRIBUTE):Connect(refresh)
end

return InputHints
