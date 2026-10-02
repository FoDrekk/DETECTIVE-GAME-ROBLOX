--!strict
--[[
	Manual unit-test entry point. Enable this Script and press Play to run the
	whole suite; results appear in the Output window.

	It is disabled by default so it never auto-runs during normal play.
]]

local ServerStorage = game:GetService("ServerStorage")
-- Full case-playthrough tests can exceed the harness's 5-second default in
-- Studio while deferred Roblox events settle; keep a bounded but practical
-- per-test ceiling for this manual Studio runner.
local totals = require(ServerStorage:WaitForChild("UnitTest"):WaitForChild("RunUnitTest"))(nil, 15)
for _, failure in ipairs(totals.failures) do
	warn(failure)
end
