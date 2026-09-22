--!strict
--[[
	Manual unit-test entry point. Enable this Script and press Play to run the
	whole suite; results appear in the Output window.

	It is disabled by default so it never auto-runs during normal play.
]]

local ServerStorage = game:GetService("ServerStorage")
require(ServerStorage:WaitForChild("UnitTest"):WaitForChild("RunUnitTest"))()
