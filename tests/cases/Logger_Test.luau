--!strict
--[[
	Tests for ReplicatedStorage.Shared.Logger.
	Covers scope creation, severity gating, and the fatal contract.

	The logger's default minimum severity is INFO; cases that depend on
	emission capture console output indirectly through the public API only.
]]
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
	local expect = t.expect

	-- A scoped logger exposes the four required severities.
	t.test("exposes all four severities", function()
		local log = Logger.scoped("TestScope")
		expect.truthy(log.debug)
		expect.truthy(log.info)
		expect.truthy(log.warn)
		expect.truthy(log.error)
	end)

	-- Calling a severity with context does not raise.
	t.test("emits without raising", function()
		local log = Logger.scoped("TestScope")
		log:info("hello", { key = "value" })
		log:warn("careful", { count = 1 })
	end)

	-- setMinSeverity accepts a valid severity.
	t.test("accepts a valid minimum severity", function()
		Logger.setMinSeverity("DEBUG")
		Logger.setMinSeverity("INFO")
	end)

	-- setMinSeverity rejects an unknown severity loudly.
	t.test("rejects an unknown minimum severity", function()
		expect.throws(function()
			Logger.setMinSeverity("VERBOSE" :: any)
		end)
	end)

	-- fatal raises an error (used for unrecoverable misconfiguration).
	t.test("fatal raises an error", function()
		local message = expect.throws(function()
			Logger.fatal("TestScope", "cannot continue")
		end)
		expect.truthy(string.find(message, "cannot continue", 1, true))
	end)

	-- fatal includes structured context in the message.
	t.test("fatal includes context", function()
		local message = expect.throws(function()
			Logger.fatal("TestScope", "bad config", { caseId = "CASE-TEST-LEGACY" })
		end)
		expect.truthy(string.find(message, "caseId=CASE-TEST-LEGACY", 1, true))
	end)
end
