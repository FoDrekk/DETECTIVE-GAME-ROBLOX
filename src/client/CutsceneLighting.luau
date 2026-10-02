--!strict
--[[
	CutsceneLighting
	The look of a scripted scene: the sky and ambient light, a colour grade, bloom,
	a vignette and depth of field. Client-side only -- nothing here is ever seen by
	another player or saved anywhere.

	A shot asks for a NAMED preset (Config.Cutscene.LightingPresets), never for
	numbers, so every shot in a place is lit the same way and a look can be
	retuned in one spot. A preset lists only what it means to change: what it
	leaves out keeps the world's own value. Besides the Lighting properties it may
	change the world's Atmosphere (the haze that drowns the far distance: a city
	seen through rain wants far less of it than an office window does), and the
	sky's stars.

	The first `apply` of a scene remembers the world's lighting and `restore`
	puts every property back and switches the effects off. The bootstrap calls
	restore whenever a scene ends -- finished, skipped, or ended by the server --
	so a scene can never leave the office lit like a bedroom.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Components = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Components"))

local CutsceneLighting = {}

-- The Lighting properties a preset may set (and so the ones put back).
local WORLD_PROPS = {
	"ClockTime",
	"Brightness",
	"Ambient",
	"OutdoorAmbient",
	"ExposureCompensation",
	"FogColor",
	"FogStart",
	"FogEnd",
}

-- The Atmosphere properties a preset may set (in a table of that name).
local ATMOSPHERE_PROPS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }

local EFFECT_PREFIX = "MysteryCase_Scene"

-- How dark the vignette's edge gets at strength 1.
local VIGNETTE_MAX = 0.85

local saved: { [string]: any }? = nil
local savedAtmosphere: { [string]: any }? = nil
local savedStars: number? = nil
local currentName: string? = nil
local grade: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local depth: DepthOfFieldEffect? = nil
local vignetteGui: ScreenGui? = nil
local vignetteEdges: { Frame } = {}
-- One tween per target at a time, so a new value never fights an old tween.
local running: { [Instance]: Tween } = {}
-- Bumped by apply/restore so a focus rack or a delayed switch-off from an
-- earlier shot never lands on a later one.
local token = 0

local function setProps(target: Instance, goal: { [string]: any }, seconds: number)
	local old = running[target]
	if old then
		old:Cancel()
		running[target] = nil
	end
	if seconds > 0 then
		local tween = TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Sine), goal)
		running[target] = tween
		tween:Play()
	else
		for key, value in pairs(goal) do
			(target :: any)[key] = value
		end
	end
end

local function ensureEffects()
	if not grade then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = `{EFFECT_PREFIX}Grade`
		effect.Enabled = false
		effect.Parent = Lighting
		grade = effect
	end
	if not bloom then
		local effect = Instance.new("BloomEffect")
		effect.Name = `{EFFECT_PREFIX}Bloom`
		effect.Enabled = false
		effect.Parent = Lighting
		bloom = effect
	end
	if not depth then
		local effect = Instance.new("DepthOfFieldEffect")
		effect.Name = `{EFFECT_PREFIX}Focus`
		effect.Enabled = false
		effect.Parent = Lighting
		depth = effect
	end
end

-- Four edge gradients, transparent toward the middle: a vignette needs no image.
local function ensureVignette()
	if vignetteGui then
		return
	end
	local gui = Components.screenGui("MysteryCase_Vignette", 24)
	gui.Enabled = false
	vignetteGui = gui
	local edges = {
		{ name = "Top", anchor = Vector2.new(0, 0), size = UDim2.fromScale(1, 0.4), rotation = 90 },
		{ name = "Bottom", anchor = Vector2.new(0, 1), size = UDim2.fromScale(1, 0.4), rotation = 270 },
		{ name = "Left", anchor = Vector2.new(0, 0), size = UDim2.fromScale(0.3, 1), rotation = 0 },
		{ name = "Right", anchor = Vector2.new(1, 0), size = UDim2.fromScale(0.3, 1), rotation = 180 },
	}
	for _, edge in ipairs(edges) do
		local frame = Instance.new("Frame")
		frame.Name = edge.name
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.AnchorPoint = edge.anchor
		frame.Position = UDim2.fromScale(edge.anchor.X, edge.anchor.Y)
		frame.Size = edge.size
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(vignetteEdges, frame)
	end
end

local function setVignette(strength: number, seconds: number)
	ensureVignette()
	local gui = vignetteGui :: ScreenGui
	if strength > 0 then
		gui.Enabled = true
	end
	local transparency = 1 - math.clamp(strength, 0, 1) * VIGNETTE_MAX
	for _, frame in ipairs(vignetteEdges) do
		setProps(frame, { BackgroundTransparency = transparency }, seconds)
	end
	if strength <= 0 then
		local closing = token
		task.delay(seconds, function()
			if closing == token and vignetteGui then
				vignetteGui.Enabled = false
			end
		end)
	end
end

-- The preset a shot asked for, if the config has it.
local function presetOf(name: string): { [string]: any }?
	return (Config.Cutscene.LightingPresets :: any)[name]
end

-- The name of the look in force (nil: the world's own), for tests.
function CutsceneLighting.current(): string?
	return currentName
end

--[[
	Show the look `name` names, blending over `blend` seconds (a cut is 0).
	A nil name is a shot that doesn't ask for one: the world's own lighting comes
	back (a scene that walks back into the office stops looking like a bedroom).
]]
function CutsceneLighting.apply(name: string?, blend: number?)
	local seconds = blend or 0
	local preset = if name then presetOf(name) else nil
	if name and not preset then
		return
	end
	if not preset then
		CutsceneLighting.restore(seconds)
		return
	end

	token += 1
	ensureEffects()
	if not saved then
		local values = {}
		for _, prop in ipairs(WORLD_PROPS) do
			values[prop] = (Lighting :: any)[prop]
		end
		saved = values
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			local atmosphereValues = {}
			for _, prop in ipairs(ATMOSPHERE_PROPS) do
				atmosphereValues[prop] = (atmosphere :: any)[prop]
			end
			savedAtmosphere = atmosphereValues
		end
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			savedStars = sky.StarCount
		end
	end
	currentName = name

	local goal = {}
	for _, prop in ipairs(WORLD_PROPS) do
		local value = preset[prop]
		if value ~= nil then
			goal[prop] = value
		elseif saved then
			goal[prop] = saved[prop]
		end
	end
	setProps(Lighting, goal, seconds)

	-- The haze, and the stars: back to the world's own unless the preset says.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and savedAtmosphere then
		local atmosphereGoal = {}
		for _, prop in ipairs(ATMOSPHERE_PROPS) do
			local value = if preset.Atmosphere then preset.Atmosphere[prop] else nil
			atmosphereGoal[prop] = if value ~= nil then value else savedAtmosphere[prop]
		end
		setProps(atmosphere, atmosphereGoal, seconds)
	end
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky and savedStars ~= nil then
		sky.StarCount = if preset.Stars ~= nil then preset.Stars else savedStars
	end

	local bloomSpec = preset.Bloom
	local bloomEffect = bloom :: BloomEffect
	if bloomSpec then
		bloomEffect.Enabled = true
		setProps(bloomEffect, { Intensity = bloomSpec.intensity, Size = bloomSpec.size, Threshold = bloomSpec.threshold }, seconds)
	else
		bloomEffect.Enabled = false
	end

	local gradeSpec = preset.Grade
	local gradeEffect = grade :: ColorCorrectionEffect
	if gradeSpec then
		gradeEffect.Enabled = true
		setProps(gradeEffect, {
			Contrast = gradeSpec.contrast,
			Saturation = gradeSpec.saturation,
			TintColor = gradeSpec.tint,
			Brightness = gradeSpec.brightness,
		}, seconds)
	else
		gradeEffect.Enabled = false
	end

	setVignette(preset.Vignette or 0, seconds)
end

--[[
	The shot's depth of field: what is sharp, and (with `toDistance`) a rack of
	the focus over the shot's length. nil switches it off.
]]
function CutsceneLighting.focus(spec: Types.CutsceneFocus?, duration: number)
	ensureEffects()
	local effect = depth :: DepthOfFieldEffect
	if not spec then
		effect.Enabled = false
		local old = running[effect]
		if old then
			old:Cancel()
			running[effect] = nil
		end
		return
	end
	local blur = math.clamp(spec.blur or 0.6, 0, 1)
	effect.Enabled = true
	effect.NearIntensity = blur
	effect.FarIntensity = blur
	effect.InFocusRadius = spec.radius or 8
	effect.FocusDistance = spec.distance
	if spec.toDistance then
		setProps(effect, { FocusDistance = spec.toDistance }, math.max(duration, 0.05))
	end
end

--[[
	The scene is over: the world's lighting back exactly as it was, every effect
	off, the vignette gone. Safe to call at any time, any number of times.
]]
function CutsceneLighting.restore(blend: number?)
	local seconds = blend or 0
	token += 1
	local values = saved
	saved = nil
	currentName = nil
	if values then
		setProps(Lighting, values, seconds)
	end
	local atmosphereValues = savedAtmosphere
	savedAtmosphere = nil
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and atmosphereValues then
		setProps(atmosphere, atmosphereValues, seconds)
	end
	local stars = savedStars
	savedStars = nil
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky and stars ~= nil then
		sky.StarCount = stars
	end
	if depth then
		depth.Enabled = false
	end
	local closing = token
	local function switchOff()
		if closing ~= token then
			return
		end
		if grade then
			grade.Enabled = false
		end
		if bloom then
			bloom.Enabled = false
		end
	end
	if seconds > 0 then
		-- Blend the grade and bloom back down before they are switched off.
		if grade then
			setProps(grade, { Contrast = 0, Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, seconds)
		end
		if bloom then
			setProps(bloom, { Intensity = 0 }, seconds)
		end
		task.delay(seconds, switchOff)
	else
		switchOff()
	end
	if vignetteGui then
		setVignette(0, seconds)
	end
end

return CutsceneLighting
