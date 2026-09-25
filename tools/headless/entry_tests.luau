-- Entry: run the unit-test suite (tests/cases) headlessly.
local filter = Shim.env.TEST_FILTER
local ServerStorage = game:GetService("ServerStorage")
-- Like pressing Play in Studio: the server bootstrap runs first.
Shim.runScript(game:GetService("ServerScriptService"):WaitForChild("Server"))
Shim.settle(5)
local results
task.spawn(function()
	results = require(ServerStorage:WaitForChild("UnitTest"):WaitForChild("RunUnitTest"))(filter, 5)
end)
Shim.settle(600)
if not results then
	print("RESULT runner did not finish")
	error("runner did not finish")
end
print(string.format("RESULT %d run, %d passed, %d failed, %d unexpected thread errors (%d FireClient-to-mock-player errors, as in Studio)", results.run, results.passed, results.failed, #Shim.errors, Shim.mockPlayerFireErrors))
