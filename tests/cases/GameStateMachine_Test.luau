--!strict
--[[
	Tests for ReplicatedStorage.Shared.GameStateMachine.
	Covers legal transitions, illegal transition rejection, self-transition
	rejection, and onEnter/onExit callbacks.
]]
return function(t)
	local GameStateMachine = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameStateMachine"))
	local expect = t.expect

	-- Builds a fresh machine with the project's phase topology.
	local function makeMachine()
		return GameStateMachine.new("MainMenu")
			:allowBoth("MainMenu", "CaseBriefing")
			:allowBoth("CaseBriefing", "Investigation")
	end

	-- A new machine starts in its initial state.
	t.test("starts in the initial state", function()
		local m = makeMachine()
		expect.equal(m.current, "MainMenu")
	end)

	-- An explicitly allowed transition succeeds and updates current.
	t.test("allows a declared transition", function()
		local m = makeMachine()
		expect.truthy(m:transition("CaseBriefing"))
		expect.equal(m.current, "CaseBriefing")
	end)

	-- A declared bidirectional transition works in the reverse direction.
	t.test("allows a declared bidirectional transition", function()
		local m = makeMachine()
		m:transition("CaseBriefing")
		expect.truthy(m:transition("MainMenu"))
		expect.equal(m.current, "MainMenu")
	end)

	-- An undeclared transition is rejected and leaves state unchanged.
	t.test("rejects an undeclared transition", function()
		local m = makeMachine()
		expect.falsy(m:transition("Investigation"))
		expect.equal(m.current, "MainMenu")
	end)

	-- Transitioning to the current state is rejected as a no-op.
	t.test("rejects a self transition", function()
		local m = makeMachine()
		expect.falsy(m:transition("MainMenu"))
	end)

	-- canTransition agrees with transition without mutating state.
	t.test("canTransition reports without mutating state", function()
		local m = makeMachine()
		expect.truthy(m:canTransition("CaseBriefing"))
		expect.equal(m.current, "MainMenu")
	end)

	-- onEnter fires with the previous state after a successful transition.
	t.test("fires onEnter with the source state", function()
		local m = makeMachine()
		local enteredFrom = "unset"
		m:onEnter("CaseBriefing", function(from)
			enteredFrom = from
		end)
		m:transition("CaseBriefing")
		expect.equal(enteredFrom, "MainMenu")
	end)

	-- onExit fires with the destination state after a successful transition.
	t.test("fires onExit with the destination state", function()
		local m = makeMachine()
		local exitedTo = "unset"
		m:onExit("MainMenu", function(to)
			exitedTo = to
		end)
		m:transition("CaseBriefing")
		expect.equal(exitedTo, "CaseBriefing")
	end)

	-- Callbacks do not fire when a transition is rejected.
	t.test("does not fire callbacks on a rejected transition", function()
		local m = makeMachine()
		local fired = false
		m:onEnter("Investigation", function()
			fired = true
		end)
		m:transition("Investigation")
		expect.falsy(fired)
	end)

	-- reset returns the machine to its initial state.
	t.test("reset returns to the initial state", function()
		local m = makeMachine()
		m:transition("CaseBriefing")
		m:transition("Investigation")
		m:reset()
		expect.equal(m.current, "MainMenu")
	end)

	-- Builds a machine with GameStateService's actual production topology.
	-- A fresh, local instance -- never the live singleton -- so these tests
	-- cannot affect a running game.
	local function makeProductionMachine()
		return GameStateMachine.new("MainMenu")
			:allowBoth("MainMenu", "CaseBriefing")
			:allowBoth("CaseBriefing", "Investigation")
			:allowBoth("Investigation", "CaseClosed")
			:allowBoth("CaseClosed", "MainMenu")
	end

	-- A client-requested jump straight to "Investigation" from "MainMenu"
	-- (skipping the briefing; an illegal client-side state transition) must
	-- be rejected. Note MainMenu -> CaseClosed IS a declared edge (the
	-- reverse of CaseClosed <-> MainMenu's reset path), so it is not a valid
	-- illegal-jump example here.
	t.test("rejects an illegal jump in the production phase topology", function()
		local m = makeProductionMachine()
		expect.falsy(m:transition("Investigation"))
		expect.equal(m.current, "MainMenu")
	end)

	-- Skipping "Investigation" entirely (CaseBriefing -> CaseClosed) is also
	-- illegal and must be rejected.
	t.test("rejects skipping from CaseBriefing straight to CaseClosed", function()
		local m = makeProductionMachine()
		m:transition("CaseBriefing")
		expect.falsy(m:transition("CaseClosed"))
		expect.equal(m.current, "CaseBriefing")
	end)
end
