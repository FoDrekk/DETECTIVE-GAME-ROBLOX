--!strict
--[[
	GameStateMachine
	A minimal, reusable finite state machine. No scattered boolean flags.

	Transitions are explicit and validated against a transition table.
]]

local GameStateMachine = {}
GameStateMachine.__index = GameStateMachine

export type StateId = string

export type StateMachine = {
	current: StateId,
	_transitions: { [StateId]: { [StateId]: boolean } },
	_onEnter: { [StateId]: ((from: StateId) -> ())? },
	_onExit: { [StateId]: ((to: StateId) -> ())? },
	_initial: StateId,
}

function GameStateMachine.new(initial: StateId): StateMachine
	local self = setmetatable({}, GameStateMachine)
	self._initial = initial
	self.current = initial
	self._transitions = {}
	self._onEnter = {}
	self._onExit = {}
	return self
end

-- Register a valid transition from one state to another.
function GameStateMachine.allow(self: StateMachine, from: StateId, to: StateId): StateMachine
	local set = self._transitions[from]
	if not set then
		set = {}
		self._transitions[from] = set
	end
	set[to] = true
	return self
end

-- Register a chain of bidirectional transitions: a <-> b.
function GameStateMachine.allowBoth(self: StateMachine, a: StateId, b: StateId): StateMachine
	self:allow(a, b)
	self:allow(b, a)
	return self
end

function GameStateMachine.onEnter(self: StateMachine, state: StateId, fn: (from: StateId) -> ()): StateMachine
	self._onEnter[state] = fn
	return self
end

function GameStateMachine.onExit(self: StateMachine, state: StateId, fn: (to: StateId) -> ()): StateMachine
	self._onExit[state] = fn
	return self
end

function GameStateMachine.canTransition(self: StateMachine, to: StateId): boolean
	if to == self.current then
		return false
	end
	local set = self._transitions[self.current]
	return set ~= nil and set[to] == true
end

-- Attempt a transition. Returns true if the state changed.
function GameStateMachine.transition(self: StateMachine, to: StateId): boolean
	if not self:canTransition(to) then
		return false
	end
	local from = self.current
	local exitFn = self._onExit[from]
	if exitFn then
		exitFn(to)
	end
	self.current = to
	local enterFn = self._onEnter[to]
	if enterFn then
		enterFn(from)
	end
	return true
end

function GameStateMachine.reset(self: StateMachine): ()
	local from = self.current
	local exitFn = self._onExit[from]
	if exitFn then
		exitFn(self._initial)
	end
	self.current = self._initial
	local enterFn = self._onEnter[self._initial]
	if enterFn then
		enterFn(from)
	end
end

return GameStateMachine
