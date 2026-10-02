--!strict
--[[
	SoundController (M6, Phase 5.5)
	Client-side audio: two looping ambience layers (rain, a low drone) and
	named one-shot cues, all data-driven from Config.Audio. Presentation only
	-- it reacts to what the bootstrap tells it and decides nothing about the
	game.

	Ambience ducks (fades down) behind dialogue and the closing screen so
	voices and the verdict sit on top of it.

	Phase 5.5: the sound of a scripted scene. A scene asks for cues by name
	(Config.Audio.Cutscene) at moments of its own shots, and never carries an
	asset id. There are two kinds:
	  * a BED (the cue's config says `loops`): rain, traffic, the music. It plays
	    until something ends it, and is carried across cuts -- a shot that asks
	    for a bed already playing leaves it alone (only its level moves), and the
	    first shot that doesn't ask for it fades it out (`keepBeds`);
	  * a ONE-SHOT: a door, a beep, a clap of thunder. It plays once from wherever
	    `from` says in the recording and cleans itself up. A shot can `stop` one
	    early too (a recording cut before the part that would give the game away).

	Everything a scene starts lives in one sound group and is ended together by
	`endScene`, however the scene ends. The game's own ambience is silenced while
	an intro plays (its rain would be a second rain under the scene's) and
	brought back when control returns.
]]

local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SoundController = {}

export type Cue = "EvidenceDiscovered" | "Tick" | "Reasoning" | "VerdictCorrect" | "VerdictWrong"

-- What a scene may say about one cue (a subset of Types.CutsceneSoundCue).
export type SceneCueOptions = { volume: number?, fade: number?, from: number? }

local DEFAULT_FADE_IN = 0.4
local DEFAULT_FADE_OUT = 0.8
-- How long to wait for a recording to load before starting it anyway.
local LOAD_WAIT = 1.5

local folder: Folder? = nil
local ambienceGroup: SoundGroup? = nil
local sceneGroup: SoundGroup? = nil
local cues: { [string]: Sound } = {}
local ducked = false
-- Phase 5.5: the ambience is silenced under an intro, not merely ducked.
local ambienceSilenced = false

-- The scene's own sounds. Templates hold each recording loaded (and are what a
-- play is cloned from); beds are the loops playing now, one per cue.
local templates: { [string]: Sound } = {}
local beds: { [string]: Sound } = {}
local oneShots: { [Sound]: string } = {}
-- Bumped by every beginScene/endScene so a load that was waited for by an earlier
-- scene never starts a sound in the next.
local sceneToken = 0

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

local function ambienceLevel(): number
	if ambienceSilenced then
		return 0
	end
	return if ducked then Config.Audio.DuckedAmbience else 1
end

local function moveAmbience(seconds: number)
	if ambienceGroup then
		TweenService:Create(ambienceGroup, TweenInfo.new(seconds), { Volume = ambienceLevel() }):Play()
	end
end

-- Fade ambience down (true) or back up (false).
function SoundController.setDucked(shouldDuck: boolean)
	if not ambienceGroup or ducked == shouldDuck then
		return
	end
	ducked = shouldDuck
	moveAmbience(0.8)
end

--[[
	Phase 5.5: a scene begins. `silenceAmbience` takes the game's own rain and
	drone down to nothing for its length (an intro brings its own).
]]
function SoundController.beginScene(silenceAmbience: boolean)
	sceneToken += 1
	ambienceSilenced = silenceAmbience
	if silenceAmbience then
		moveAmbience(0.6)
	end
end

-- The named cue's config, if the case may ask for it.
local function specOf(name: string): { id: string, volume: number, loops: boolean? }?
	return (Config.Audio.Cutscene :: any)[name]
end

local function templateFor(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local spec = specOf(name)
	local parent, group = folder, sceneGroup
	if not spec or not parent or not group then
		return nil
	end
	local template = makeSound(`Template_{name}`, spec, parent, group)
	template.Volume = 0
	templates[name] = template
	return template
end

--[[
	Phase 5.5: load the recordings a scene will use before it starts, so no cue
	arrives late. Yields until they are loaded (or the platform gives up on them).
]]
function SoundController.preload(names: { string })
	local wanted = {}
	local seen = {}
	for _, name in ipairs(names) do
		if not seen[name] then
			seen[name] = true
			local template = templateFor(name)
			if template then
				table.insert(wanted, template)
			end
		end
	end
	if #wanted > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(wanted)
		end)
	end
end

local function fadeTo(sound: Sound, volume: number, seconds: number)
	if seconds <= 0 then
		sound.Volume = volume
		return
	end
	TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

-- Start `sound` at `from` seconds in once it can be heard (a recording that
-- hasn't loaded ignores a start position), unless the scene has moved on.
local function startAt(sound: Sound, from: number?, token: number)
	local function begin()
		if token ~= sceneToken or not sound.Parent then
			return
		end
		if from and from > 0 then
			sound.TimePosition = from
		end
		sound:Play()
	end
	if sound.IsLoaded then
		begin()
		return
	end
	task.spawn(function()
		local waited = 0
		while not sound.IsLoaded and waited < LOAD_WAIT and token == sceneToken do
			waited += task.wait()
		end
		begin()
	end)
end

--[[
	Phase 5.5: play a scene's cue. A bed already going only has its level moved;
	otherwise the cue starts (`fade` seconds in, for a bed). Unknown cues do
	nothing (the server checks names at boot; a client never trusts one).
]]
function SoundController.playCue(name: string, options: SceneCueOptions?)
	local spec = specOf(name)
	local parent, group = folder, sceneGroup
	if not spec or not parent or not group then
		return
	end
	local opts = options or {}
	local volume = opts.volume or spec.volume
	if spec.loops then
		local playing = beds[name]
		if playing then
			fadeTo(playing, volume, opts.fade or DEFAULT_FADE_IN)
			return
		end
		local template = templateFor(name)
		if not template then
			return
		end
		local bed = template:Clone()
		bed.Name = name
		bed.Looped = true
		bed.Volume = 0
		bed.Parent = parent
		beds[name] = bed
		startAt(bed, opts.from, sceneToken)
		fadeTo(bed, volume, opts.fade or DEFAULT_FADE_IN)
		return
	end
	local template = templateFor(name)
	if not template then
		return
	end
	local shot = template:Clone()
	shot.Name = name
	shot.Looped = false
	shot.Volume = volume
	shot.Parent = parent
	oneShots[shot] = name
	shot.Ended:Connect(function()
		oneShots[shot] = nil
		shot:Destroy()
	end)
	-- Whatever happens to it, it's gone in a while.
	Debris:AddItem(shot, math.max(template.TimeLength, 1) + 30)
	startAt(shot, opts.from, sceneToken)
end

-- Fade a cue out (a `stop` in a shot) and let it go: the bed of that name, and
-- any of its one-shots still sounding.
function SoundController.stopCue(name: string, fade: number?)
	local seconds = fade or DEFAULT_FADE_OUT
	local bed = beds[name]
	if bed then
		beds[name] = nil
		fadeTo(bed, 0, seconds)
		Debris:AddItem(bed, seconds + 0.2)
	end
	for shot, cue in pairs(table.clone(oneShots)) do
		if cue == name then
			oneShots[shot] = nil
			fadeTo(shot, 0, seconds)
			Debris:AddItem(shot, seconds + 0.2)
		end
	end
end

--[[
	Phase 5.5: at the start of a shot, keep the beds it asks for and fade out the
	rest. `keep` is the set of cue names the new shot lists.
]]
function SoundController.keepBeds(keep: { [string]: boolean }, fade: number?)
	for name in pairs(table.clone(beds)) do
		if not keep[name] then
			SoundController.stopCue(name, fade)
		end
	end
end

-- The names of the beds playing now (for tests).
function SoundController.playingBeds(): { string }
	local names = {}
	for name in pairs(beds) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--[[
	Phase 5.5: the scene is over, however it ended. Every bed fades, any cue still
	sounding is let go, and the game's own ambience comes back.
]]
function SoundController.endScene(fade: number?)
	sceneToken += 1
	local seconds = fade or DEFAULT_FADE_OUT
	for name in pairs(table.clone(beds)) do
		SoundController.stopCue(name, seconds)
	end
	for shot in pairs(table.clone(oneShots)) do
		oneShots[shot] = nil
		fadeTo(shot, 0, seconds)
		Debris:AddItem(shot, seconds + 0.2)
	end
	if ambienceSilenced then
		ambienceSilenced = false
		-- The world's rain returns gently: control is the moment the room is
		-- meant to be heard.
		moveAmbience(math.max(seconds, 1.5))
	end
end

function SoundController.start()
	local root = Instance.new("Folder")
	root.Name = "MysteryCase_Audio"
	root.Parent = SoundService
	folder = root

	local ambience = Instance.new("SoundGroup")
	ambience.Name = "Ambience"
	ambience.Volume = 1
	ambience.Parent = root
	ambienceGroup = ambience

	local effects = Instance.new("SoundGroup")
	effects.Name = "Effects"
	effects.Volume = 1
	effects.Parent = root

	local scene = Instance.new("SoundGroup")
	scene.Name = "Scene"
	scene.Volume = 1
	scene.Parent = root
	sceneGroup = scene

	for name, spec in pairs(Config.Audio.Ambience) do
		local loop = makeSound(name, spec, root, ambience)
		loop.Looped = true
		loop:Play()
	end

	for name, spec in pairs(Config.Audio.Cues) do
		cues[name] = makeSound(name, spec, root, effects)
	end
end

return SoundController
