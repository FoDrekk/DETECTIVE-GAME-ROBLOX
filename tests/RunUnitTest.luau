--!strict
--[[
	RunUnitTest
	Lightweight headless unit-test runner for Mystery Case.

	Discovers case modules under ServerStorage.UnitTest.Cases and runs each in
	isolation with a per-case timeout.

	Usage:
	  require(ServerStorage.UnitTest.RunUnitTest)(filter?, timeout?)
	    filter   optional string; runs only case modules whose name contains it
	    timeout  optional seconds per case (default 5)

	Each case module returns: function(t) ... end
	  t.test(name, fn)  registers one case
	  t.expect          matchers (equal, truthy, falsy, near, throws, deepEqual)
]]

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function fmt(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local expect = {}

function expect.equal(actual: any, expectedValue: any)
	if actual ~= expectedValue then
		error(string.format("expected %s, got %s", fmt(expectedValue), fmt(actual)), 2)
	end
end

function expect.truthy(value: any)
	if not value then
		error(string.format("expected truthy, got %s", fmt(value)), 2)
	end
end

function expect.falsy(value: any)
	if value then
		error(string.format("expected falsy, got %s", fmt(value)), 2)
	end
end

function expect.near(actual: number, expectedValue: number, tolerance: number?)
	tolerance = tolerance or 1e-6
	if type(actual) ~= "number" or math.abs(actual - expectedValue) > tolerance then
		error(string.format("expected %s within %s of %s", fmt(actual), fmt(tolerance), fmt(expectedValue)), 2)
	end
end

function expect.throws(fn: () -> ()): string
	local ok, err = pcall(fn)
	if ok then
		error("expected the function to throw, but it returned normally", 2)
	end
	return tostring(err)
end

function expect.deepEqual(actual: any, expectedValue: any)
	local function eq(a: any, b: any): boolean
		if a == b then
			return true
		end
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		for k, v in pairs(a) do
			if not eq(v, b[k]) then
				return false
			end
		end
		for k in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	if not eq(actual, expectedValue) then
		error("tables are not deeply equal", 2)
	end
end

export type Expect = typeof(expect)

export type Context = {
	expect: Expect,
	test: (name: string, fn: () -> ()) -> (),
	-- A mock Player UserId guaranteed unique for the lifetime of this run
	-- AND never reused by an earlier or later run in the same session (see
	-- the harness-level counter below). Always negative, so it can never
	-- collide with a real Roblox Player.UserId (always positive).
	nextUserId: () -> number,
}

-- Runs one test in isolation with a yield-based timeout.
local function runOne(fn: () -> (), timeout: number): (string, number, string?)
	local done, ok, err = false, false, nil
	local cpuStart = os.clock()
	task.spawn(function()
		ok, err = pcall(fn)
		done = true
	end)
	local waited = 0
	while not done and waited < timeout do
		waited += task.wait()
	end
	local elapsed = if waited > 0 then waited else (os.clock() - cpuStart)
	if not done then
		return "timeout", elapsed, string.format("exceeded %.1fs", timeout)
	elseif ok then
		return "pass", elapsed, nil
	else
		return "fail", elapsed, tostring(err)
	end
end

-- Ever-incrementing, always-negative mock-player UserId counter. Module
-- scoped, so it is never reset by a repeated call to the function this
-- module returns within the same session -- only a fresh Play session
-- resets it. This is what guarantees mock UserIds can never collide with
-- (or accidentally read) PlayerDataService state left behind by an earlier
-- run: every run gets a disjoint slice of the id space.
local nextMockUserId = 0

return function(filter: string?, timeout: number?)
	timeout = timeout or 5
	local totals = { run = 0, passed = 0, failed = 0 }
	local sessionStart = os.clock()

	local cases = ServerStorage:FindFirstChild("UnitTest")
		and ServerStorage.UnitTest:FindFirstChild("Cases")
	if not cases then
		warn("[UnitTest] ServerStorage.UnitTest.Cases not found")
		return totals
	end

	-- Mock UserIds handed out during this specific run, so they can be
	-- cleaned out of PlayerDataService once the run finishes -- repeated
	-- runs in the same session never accumulate stale mock player data.
	local mockUserIdsThisRun: { number } = {}
	local function nextUserId(): number
		nextMockUserId -= 1
		table.insert(mockUserIdsThisRun, nextMockUserId)
		return nextMockUserId
	end

	for _, module in ipairs(cases:GetDescendants()) do
		if module:IsA("ModuleScript") and (filter == nil or string.find(module.Name, filter, 1, true)) then
			local okRequire, caseFn = pcall(require, module)
			if not okRequire or type(caseFn) ~= "function" then
				totals.run += 1
				totals.failed += 1
				warn(string.format("[FAIL] %s | case did not return a function: %s", module.Name, tostring(caseFn)))
			else
				local t: Context = { expect = expect, test = nil :: any, nextUserId = nextUserId }
				t.test = function(name: string, fn: () -> ())
					totals.run += 1
					local status, elapsed, message = runOne(fn, timeout)
					if status == "pass" then
						totals.passed += 1
						print(string.format("[PASS] %s > %s (%.3fs)", module.Name, name, elapsed))
					else
						totals.failed += 1
						warn(string.format("[%s] %s > %s (%.3fs) | %s",
							string.upper(status), module.Name, name, elapsed, message))
					end
				end
				local okRun, runErr = pcall(caseFn, t)
				if not okRun then
					totals.run += 1
					totals.failed += 1
					warn(string.format("[FAIL] %s | error while building cases: %s", module.Name, tostring(runErr)))
				end
			end
		end
	end

	-- Clean up this run's mock player data so a later run in the same
	-- session never inherits it. Only ever touches the negative mock
	-- UserIds this run itself dispensed -- never a real Player.
	if #mockUserIdsThisRun > 0 then
		local okRequire, PlayerDataService = pcall(function()
			return require(ServerScriptService:WaitForChild("Server"):WaitForChild("PlayerDataService"))
		end)
		if okRequire then
			for _, id in ipairs(mockUserIdsThisRun) do
				PlayerDataService.clear({ UserId = id } :: any)
			end
		end
	end

	print(string.format("[SUMMARY] %d run, %d passed, %d failed, %.3fs",
		totals.run, totals.passed, totals.failed, os.clock() - sessionStart))
	return totals
end
