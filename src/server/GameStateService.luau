--!strict
--[[
	GameStateService
	Server-authoritative game phase machine, backed by GameStateMachine.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameStateMachine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameStateMachine"))
local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signals"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))

local GameStateService = {}

local ACTIVE_CASE = Config.Game.AutoStartCase

local machine = GameStateMachine.new("MainMenu")
machine
	:allowBoth("MainMenu", "CaseBriefing")
	:allowBoth("CaseBriefing", "Investigation")
	:allowBoth("Investigation", "CaseClosed")
	:allowBoth("CaseClosed", "MainMenu")

local phaseChanged = Signals.get(Signals.Names.PhaseChanged)
local caseBriefingLoaded = Signals.get(Signals.Names.CaseBriefingLoaded)
local requestPhaseChange = Signals.get(Signals.Names.RequestPhaseChange)
local requestCase = Signals.get(Signals.Names.RequestCase)

local function broadcast(phase: Types.GamePhase)
	phaseChanged:FireAllClients(phase)
end

function GameStateService.getPhase(): Types.GamePhase
	return machine.current :: Types.GamePhase
end

-- Force a phase on the shared machine (used by server logic).
function GameStateService.setPhase(phase: Types.GamePhase): boolean
	return machine:transition(phase)
end

local function grantCase(player: Player)
	local payload = CaseService.buildClientPayload(player)
	if payload then
		caseBriefingLoaded:FireClient(player, payload)
	end
end

-- Entry point used by the server bootstrap when a player joins.
-- Initialises the player's phase and grants the current case.
function GameStateService.enterBriefingFor(player: Player)
	player:SetAttribute("ActiveCaseId", ACTIVE_CASE)
	-- Ensure at least the briefing phase is active so the case is presented.
	if GameStateService.getPhase() == "MainMenu" then
		GameStateService.setPhase("CaseBriefing")
	end
	PlayerDataService.setPhase(player, GameStateService.getPhase())
	phaseChanged:FireClient(player, GameStateService.getPhase())
	grantCase(player)
end

function GameStateService.start()
	machine:onEnter("CaseBriefing", function()
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			grantCase(player)
		end
	end)

	requestPhaseChange.OnServerEvent:Connect(function(player: Player, phase: Types.GamePhase)
		if type(phase) ~= "string" then
			return
		end
		if not PlayerDataService.get(player) then
			return
		end
		-- Only allow the shared, server-validated transition.
		if GameStateService.setPhase(phase) then
			for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
				PlayerDataService.setPhase(p, phase)
			end
			broadcast(phase)
		end
	end)

	requestCase.OnServerEvent:Connect(function(player: Player)
		if PlayerDataService.get(player) then
			-- Resend both phase and case so clients that finished wiring their
			-- listeners after the initial PlayerAdded push still sync up.
			phaseChanged:FireClient(player, GameStateService.getPhase())
			grantCase(player)
		end
	end)
end

return GameStateService
