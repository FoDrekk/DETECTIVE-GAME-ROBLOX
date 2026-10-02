--!strict
--[[
	Components
	Reusable, theme-driven UI factories. No gameplay logic.
	Visual language: dark, cinematic, minimal, investigative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Components = {}

local Theme = Config.UI.Theme

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent: Instance, px: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Components.frame(props: {
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	radius: number?,
	border: boolean?,
	parent: Instance?,
}): Frame
	local f = Instance.new("Frame")
	f.Name = props.name or "Frame"
	f.Size = props.size or UDim2.fromScale(1, 1)
	f.Position = props.position or UDim2.fromScale(0, 0)
	f.AnchorPoint = props.anchor or Vector2.new(0, 0)
	f.BackgroundColor3 = props.color or Theme.Panel
	f.BackgroundTransparency = props.transparency or 0
	f.BorderSizePixel = 0
	f.Parent = props.parent
	corner(f, props.radius or 6)
	if props.border then
		stroke(f, Theme.PanelStroke, 1)
	end
	return f
end

function Components.text(props: {
	name: string?,
	text: string,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	font: Enum.Font?,
	textSize: number?,
	color: Color3?,
	xAlign: Enum.TextXAlignment?,
	parent: Instance?,
}): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = props.name or "Text"
	t.Text = props.text
	t.Size = props.size or UDim2.fromScale(1, 1)
	t.Position = props.position or UDim2.fromScale(0, 0)
	t.AnchorPoint = props.anchor or Vector2.new(0, 0)
	t.BackgroundTransparency = 1
	t.Font = props.font or Theme.Font
	t.TextSize = props.textSize or 14
	t.TextColor3 = props.color or Theme.TextPrimary
	t.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.RichText = false
	t.Parent = props.parent
	return t
end

function Components.screenGui(name: string, displayOrder: number, parent: Instance?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Components.padding(parent: Instance, px: number): UIPadding
	return padding(parent, px)
end

-- Shrink a fixed-size panel to fit short or narrow screens
-- (a phone in landscape), never growing it past its authored size. `margin`
-- is the room left around the panel on each axis, in screen pixels.
function Components.fitToViewport(panel: GuiObject, designSize: Vector2, margin: Vector2?, minScale: number?): UIScale
	local room = margin or Vector2.new(40, 40)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(
				math.min((viewport.X - room.X) / designSize.X, (viewport.Y - room.Y) / designSize.Y),
				minScale or 0.5,
				1
			)
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return scale
end

return Components
