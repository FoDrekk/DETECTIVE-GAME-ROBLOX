--!strict
--[[
	Tests for ReplicatedStorage.Shared.InputGlyphs: the per-scheme bindings
	and on-screen hints for keyboard, gamepad and touch.
]]
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local InputGlyphs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InputGlyphs"))
	local expect = t.expect

	t.test("keyboard hints use the configured keys", function()
		expect.equal(InputGlyphs.glyph("Keyboard", "Interact"), "[E]")
		expect.equal(InputGlyphs.glyph("Keyboard", "Timeline"), "[T]")
		expect.equal(InputGlyphs.glyph("Keyboard", "CaseFile"), "[C]")
		expect.equal(InputGlyphs.glyph("Keyboard", "Accuse"), "[Q]")
		expect.equal(InputGlyphs.format("Keyboard", "Interact", "Continue"), "[E]  Continue")
	end)

	t.test("gamepad hints use short button names", function()
		expect.equal(InputGlyphs.glyph("Gamepad", "Interact"), "(X)")
		expect.equal(InputGlyphs.glyph("Gamepad", "CaseFile"), "(Y)")
		expect.equal(InputGlyphs.glyph("Gamepad", "Timeline"), "(LB)")
		expect.equal(InputGlyphs.glyph("Gamepad", "Accuse"), "(RB)")
		expect.equal(InputGlyphs.glyph("Gamepad", "Close"), "(B)")
		expect.equal(InputGlyphs.format("Gamepad", "Interact", "Continue"), "(X)  Continue")
	end)

	-- Touch has no keys: the hint is just the action, and the on-screen
	-- button is what the player presses.
	t.test("touch hints carry no key", function()
		for _, action in ipairs(InputGlyphs.Actions) do
			expect.falsy(InputGlyphs.glyph("Touch", action))
		end
		expect.equal(InputGlyphs.format("Touch", "Interact", "Continue"), "Continue")
	end)

	-- Every action is reachable from both a keyboard and a gamepad, and each
	-- binding is a real KeyCode.
	t.test("every action binds a real keyboard key and gamepad button", function()
		for _, action in ipairs(InputGlyphs.Actions) do
			local codes = InputGlyphs.keyCodes(action)
			expect.equal(#codes, 2)
			for _, code in ipairs(codes) do
				expect.truthy(typeof(code) == "EnumItem")
			end
		end
	end)

	-- Two actions sharing a button would make one of them unreachable.
	t.test("no two actions share a binding within a scheme", function()
		for _, scheme in ipairs({ "Keyboard", "Gamepad" } :: { InputGlyphs.Scheme }) do
			local seen: { [string]: boolean } = {}
			for _, action in ipairs(InputGlyphs.Actions) do
				local name = InputGlyphs.keyName(scheme, action)
				expect.truthy(name)
				expect.falsy(seen[name :: string])
				seen[name :: string] = true
			end
		end
	end)

	-- A stays jump and GUI-confirm on gamepads, so nothing may claim it.
	t.test("no action is bound to gamepad A", function()
		for _, action in ipairs(InputGlyphs.Actions) do
			expect.falsy(InputGlyphs.keyName("Gamepad", action) == "ButtonA")
		end
	end)

	t.test("input types map to the right scheme", function()
		expect.equal(InputGlyphs.schemeFor(Enum.UserInputType.Keyboard), "Keyboard")
		expect.equal(InputGlyphs.schemeFor(Enum.UserInputType.MouseButton1), "Keyboard")
		expect.equal(InputGlyphs.schemeFor(Enum.UserInputType.MouseMovement), "Keyboard")
		expect.equal(InputGlyphs.schemeFor(Enum.UserInputType.Gamepad1), "Gamepad")
		expect.equal(InputGlyphs.schemeFor(Enum.UserInputType.Gamepad4), "Gamepad")
		expect.equal(InputGlyphs.schemeFor(Enum.UserInputType.Touch), "Touch")
		expect.falsy(InputGlyphs.schemeFor(Enum.UserInputType.Focus))
	end)
end
