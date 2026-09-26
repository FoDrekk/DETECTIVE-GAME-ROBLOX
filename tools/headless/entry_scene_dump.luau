--[[
	Entry: boot the server (office, interior, evidence props, suspects) and
	print every visible part and light, one per line, for offline layout
	previews (tools/headless/render_scene.py).
]]
Shim.quiet = true
Shim.runScript(game:GetService("ServerScriptService"):WaitForChild("Server"))
Shim.settle(3)
local function fmt(n: number): string
	return string.format("%.3f", n)
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency < 0.98 then
		local cf = d.CFrame
		local comps = { cf:GetComponents() }
		for i, v in ipairs(comps) do
			comps[i] = fmt(v)
		end
		local shape = if d:IsA("Part") then d.Shape.Name else "Block"
		local c = d.Color
		local path = d:GetFullName()
		Shim.rawPrint(table.concat({
			"PART",
			path,
			shape,
			fmt(d.Size.X), fmt(d.Size.Y), fmt(d.Size.Z),
			table.concat(comps, ","),
			string.format("%d,%d,%d", c.R * 255, c.G * 255, c.B * 255),
			fmt(d.Transparency),
			d.Material.Name,
			tostring(d:HasTag("Interactable")),
		}, "|"))
	elseif d:IsA("Light") and d.Enabled then
		local part = d.Parent :: BasePart
		local c = d.Color
		local face = "none"
		if d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			face = (d :: any).Face.Name
		end
		local cf = part.CFrame
		Shim.rawPrint(table.concat({
			"LIGHT",
			d.ClassName,
			fmt(cf.X), fmt(cf.Y), fmt(cf.Z),
			string.format("%d,%d,%d", c.R * 255, c.G * 255, c.B * 255),
			fmt(d.Brightness), fmt(d.Range), face,
			table.concat({ fmt(cf.RightVector.X), fmt(cf.RightVector.Y), fmt(cf.RightVector.Z), fmt(cf.UpVector.X), fmt(cf.UpVector.Y), fmt(cf.UpVector.Z), fmt(cf.LookVector.X), fmt(cf.LookVector.Y), fmt(cf.LookVector.Z) }, ","),
			tostring(d.Shadows),
		}, "|"))
	end
end
Shim.rawPrint("DONE", #Shim.errors)
