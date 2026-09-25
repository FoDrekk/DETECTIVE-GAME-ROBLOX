--!strict
--[[
	SoundController (M6)
	Client-side audio: two looping ambience layers (rain, a low drone) and
	named one-shot cues, all data-driven from Config.Audio. Presentation only
	-- it reacts to what the bootstrap tells it and decides nothing about the
	game.

	Ambience ducks (fades down) behind dialogue and the closing screen so
	voices and the verdict sit on top of it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SoundController = {}

export type Cue = "EvidenceDiscovered" | "Tick" | "Reasoning" | "VerdictCorrect" | "VerdictWrong"

local ambienceGroup: SoundGroup? = nil
local cues: { [string]: Sound } = {}
local ducked = false

local function makeSound(name: string, spec: { id: string, volume: number }, parent: Instance, group: SoundGroup): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.SoundGroup = group
	sound.Parent = parent
	return sound
end

function SoundController.play(cue: Cue)
	local sound = cues[cue]
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Fade ambience down (true) or back up (false).
function SoundController.setDucked(shouldDuck: boolean)
	if not ambienceGroup or ducked == shouldDuck then
		return
	end
	ducked = shouldDuck
	local target = if shouldDuck then Config.Audio.DuckedAmbience else 1
	TweenService:Create(ambienceGroup, TweenInfo.new(0.8), { Volume = target }):Play()
end

function SoundController.start()
	local folder = Instance.new("Folder")
	folder.Name = "MysteryCase_Audio"
	folder.Parent = SoundService

	local ambience = Instance.new("SoundGroup")
	ambience.Name = "Ambience"
	ambience.Volume = 1
	ambience.Parent = folder
	ambienceGroup = ambience

	local effects = Instance.new("SoundGroup")
	effects.Name = "Effects"
	effects.Volume = 1
	effects.Parent = folder

	for name, spec in pairs(Config.Audio.Ambience) do
		local loop = makeSound(name, spec, folder, ambience)
		loop.Looped = true
		loop:Play()
	end

	for name, spec in pairs(Config.Audio.Cues) do
		cues[name] = makeSound(name, spec, folder, effects)
	end
end

return SoundController
