--!strict
--[[
	InputGlyphs
	Pure mapping from a player action to its binding and on-screen hint for
	each input scheme (keyboard, gamepad, touch). No state and no services,
	so it is unit-testable from the server-side harness; the client's
	InputHints tracks which scheme is active and calls into this.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local InputGlyphs = {}

export type Scheme = "Keyboard" | "Gamepad" | "Touch"
export type Action = "Interact" | "Timeline" | "CaseFile" | "Accuse" | "Close"

InputGlyphs.Actions = { "Interact", "Timeline", "CaseFile", "Accuse", "Close" } :: { Action }

local KEYBOARD: { [Action]: string } = {
	Interact = Config.Interaction.PrimaryKey,
	Timeline = Config.Interaction.TimelineKey,
	CaseFile = Config.Interaction.CaseFileKey,
	Accuse = Config.Interaction.ConcludeKey,
	Close = Config.Interaction.ClosePanelKey,
}

-- Short, font-safe labels for gamepad buttons.
local GAMEPAD_LABELS: { [string]: string } = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
}

-- The KeyCode enum name bound to `action` under `scheme` (nil for touch,
-- which uses on-screen buttons instead of keys).
function InputGlyphs.keyName(scheme: Scheme, action: Action): string?
	if scheme == "Keyboard" then
		return KEYBOARD[action]
	elseif scheme == "Gamepad" then
		return (Config.Interaction.Gamepad :: any)[action]
	end
	return nil
end

-- Every KeyCode that triggers `action`, across keyboard and gamepad.
function InputGlyphs.keyCodes(action: Action): { Enum.KeyCode }
	local codes = {}
	for _, scheme in ipairs({ "Keyboard", "Gamepad" } :: { Scheme }) do
		local name = InputGlyphs.keyName(scheme, action)
		if name then
			table.insert(codes, (Enum.KeyCode :: any)[name])
		end
	end
	return codes
end

-- The bracketed hint for `action`, e.g. "[E]" or "(X)". Nil on touch.
function InputGlyphs.glyph(scheme: Scheme, action: Action): string?
	local name = InputGlyphs.keyName(scheme, action)
	if not name then
		return nil
	end
	if scheme == "Gamepad" then
		return `({GAMEPAD_LABELS[name] or name})`
	end
	if name == "Escape" then
		return "[Esc]"
	end
	return `[{name}]`
end

-- "[E]  Continue" / "(X)  Continue" / "Continue" (touch).
function InputGlyphs.format(scheme: Scheme, action: Action, text: string): string
	local glyph = InputGlyphs.glyph(scheme, action)
	if glyph then
		return `{glyph}  {text}`
	end
	return text
end

-- Which scheme an input event belongs to; nil for events that say nothing
-- about the device in hand (focus, text input, ...).
function InputGlyphs.schemeFor(inputType: Enum.UserInputType): Scheme?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	if inputType.Name:match("^Gamepad%d+$") then
		return "Gamepad"
	end
	if
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "Keyboard"
	end
	return nil
end

return InputGlyphs
