--[[
	RobloxShim
	A small, headless stand-in for the parts of the Roblox engine API this
	project's server code, client UI code and unit tests touch. It exists so
	the game's Luau can be executed and its unit tests run outside Roblox
	Studio (see tools/headless/README.md). It is NOT an engine: there is no
	physics, rendering, replication or networking. Data types, the instance
	tree, attributes, tags, signals, a virtual-time task scheduler, deferred
	BindableEvent delivery, tweens (applied at completion), ray casts against
	part boxes, and R15 rig generation are modelled closely enough for the
	game's logic to run.

	Loaded by the generated bundle (build.js); returns the environment table
	every module chunk runs in.
]]

local Shim = {}

local realPrint = print
Shim.rawPrint = realPrint
local unexpectedErrors: { string } = {}
Shim.errors = unexpectedErrors
Shim.warnings = {} :: { string }
Shim.quiet = false

local function shimWarn(...)
	local parts = table.pack(...)
	local out = {}
	for i = 1, parts.n do
		out[i] = tostring(parts[i])
	end
	local line = table.concat(out, " ")
	table.insert(Shim.warnings, line)
	if not Shim.quiet then
		realPrint("WARN  " .. line)
	end
end

local function shimPrint(...)
	if not Shim.quiet then
		realPrint(...)
	end
end

--------------------------------------------------------------------------
-- typeof
--------------------------------------------------------------------------

local TYPE_KEY = {} -- metatable field naming a Roblox datatype

local function rtypeof(v: any): string
	local t = type(v)
	if t == "table" or t == "userdata" then
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, TYPE_KEY) then
			return rawget(mt, TYPE_KEY)
		end
	end
	return typeof(v)
end

--------------------------------------------------------------------------
-- Vector3 / Vector2
--------------------------------------------------------------------------

local Vector3 = {}
local V3 = { [TYPE_KEY] = "Vector3" }
local function v3(x: number, y: number, z: number)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif key == "x" then
		return self.X
	elseif key == "y" then
		return self.Y
	elseif key == "z" then
		return self.Z
	end
	local method = rawget(Vector3, "__methods")[key]
	if method then
		return method
	end
	error(`{key} is not a valid member of Vector3`, 2)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return `{a.X}, {a.Y}, {a.Z}`
end
rawset(Vector3, "__methods", {
	Dot = function(a, b)
		return a.X * b.X + a.Y * b.Y + a.Z * b.Z
	end,
	Cross = function(a, b)
		return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
	end,
	Lerp = function(a, b, t)
		return a + (b - a) * t
	end,
	Abs = function(a)
		return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
	end,
	Min = function(a, b)
		return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	end,
	Max = function(a, b)
		return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	end,
	FuzzyEq = function(a, b, eps)
		return (a - b).Magnitude <= (eps or 1e-5)
	end,
})
Vector3.new = function(x: number?, y: number?, z: number?)
	return v3(x or 0, y or 0, z or 0)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

local Vector2 = {}
local V2 = { [TYPE_KEY] = "Vector2" }
local function v2(x: number, y: number)
	return setmetatable({ X = x, Y = y }, V2)
end
V2.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y)
		return v2(self.X / m, self.Y / m)
	elseif key == "Lerp" then
		return function(a, b, t)
			return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
		end
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y
		end
	elseif key == "Cross" then
		return function(a, b)
			return a.X * b.Y - a.Y * b.X
		end
	end
	error(`{key} is not a valid member of Vector2`, 2)
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	elseif type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2.__tostring = function(a)
	return `{a.X}, {a.Y}`
end
Vector2.new = function(x: number?, y: number?)
	return v2(x or 0, y or 0)
end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)

--------------------------------------------------------------------------
-- CFrame (position + 3x3 rotation, row-major r00..r22)
--------------------------------------------------------------------------

local CFrame = {}
local CF = { [TYPE_KEY] = "CFrame" }
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		x = x, y = y, z = z,
		r00 = r00, r01 = r01, r02 = r02,
		r10 = r10, r11 = r11, r12 = r12,
		r20 = r20, r21 = r21, r22 = r22,
	}, CF)
end
local function cfMul(a, b)
	return cf(
		a.r00 * b.x + a.r01 * b.y + a.r02 * b.z + a.x,
		a.r10 * b.x + a.r11 * b.y + a.r12 * b.z + a.y,
		a.r20 * b.x + a.r21 * b.y + a.r22 * b.z + a.z,
		a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20,
		a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21,
		a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22,
		a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20,
		a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21,
		a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22,
		a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20,
		a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21,
		a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22
	)
end
local function cfInverse(a)
	-- Orthonormal rotation: inverse is the transpose.
	local x, y, z = a.x, a.y, a.z
	return cf(
		-(a.r00 * x + a.r10 * y + a.r20 * z),
		-(a.r01 * x + a.r11 * y + a.r21 * z),
		-(a.r02 * x + a.r12 * y + a.r22 * z),
		a.r00, a.r10, a.r20,
		a.r01, a.r11, a.r21,
		a.r02, a.r12, a.r22
	)
end
local function cfPoint(a, p)
	return v3(
		a.r00 * p.X + a.r01 * p.Y + a.r02 * p.Z + a.x,
		a.r10 * p.X + a.r11 * p.Y + a.r12 * p.Z + a.y,
		a.r20 * p.X + a.r21 * p.Y + a.r22 * p.Z + a.z
	)
end
local function cfVector(a, p)
	return v3(
		a.r00 * p.X + a.r01 * p.Y + a.r02 * p.Z,
		a.r10 * p.X + a.r11 * p.Y + a.r12 * p.Z,
		a.r20 * p.X + a.r21 * p.Y + a.r22 * p.Z
	)
end
local function fromAxes(pos, right, up, back)
	return cf(pos.X, pos.Y, pos.Z, right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z)
end
local function lookAt(at, target, upVector)
	upVector = upVector or v3(0, 1, 0)
	local forward = target - at
	if forward.Magnitude < 1e-9 then
		return cf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	forward = forward.Unit
	local right = forward:Cross(upVector)
	if right.Magnitude < 1e-6 then
		right = forward:Cross(v3(0, 0, -1))
		if right.Magnitude < 1e-6 then
			right = forward:Cross(v3(1, 0, 0))
		end
	end
	right = right.Unit
	local up = right:Cross(forward).Unit
	return fromAxes(at, right, up, -forward)
end
local function rotX(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function rotY(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rotZ(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end
local function toEulerXYZ(a)
	local y = math.asin(math.clamp(a.r02, -1, 1))
	local x, z
	if math.abs(a.r02) < 0.99999 then
		x = math.atan2(-a.r12, a.r22)
		z = math.atan2(-a.r01, a.r00)
	else
		x = math.atan2(a.r21, a.r11)
		z = 0
	end
	return x, y, z
end
local function toOrientation(a)
	-- YXZ order (Roblox Orientation), returns radians x, y, z.
	local x = math.asin(math.clamp(-a.r12, -1, 1))
	local y, z
	if math.abs(a.r12) < 0.99999 then
		y = math.atan2(a.r02, a.r22)
		z = math.atan2(a.r10, a.r11)
	else
		y = math.atan2(-a.r20, a.r00)
		z = 0
	end
	return x, y, z
end
local CFMethods = {
	Inverse = cfInverse,
	ToWorldSpace = function(a, b)
		return cfMul(a, b)
	end,
	ToObjectSpace = function(a, b)
		return cfMul(cfInverse(a), b)
	end,
	PointToWorldSpace = cfPoint,
	PointToObjectSpace = function(a, p)
		return cfPoint(cfInverse(a), p)
	end,
	VectorToWorldSpace = cfVector,
	VectorToObjectSpace = function(a, p)
		return cfVector(cfInverse(a), p)
	end,
	Lerp = function(a, b, t)
		-- Position lerp + rotation re-orthonormalised from lerped axes; good
		-- enough for camera blends in a headless run.
		local pos = v3(a.x, a.y, a.z):Lerp(v3(b.x, b.y, b.z), t)
		local look = v3(-a.r02, -a.r12, -a.r22):Lerp(v3(-b.r02, -b.r12, -b.r22), t)
		if look.Magnitude < 1e-6 then
			look = v3(-b.r02, -b.r12, -b.r22)
		end
		return lookAt(pos, pos + look)
	end,
	GetComponents = function(a)
		return a.x, a.y, a.z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22
	end,
	ToEulerAnglesXYZ = toEulerXYZ,
	ToOrientation = toOrientation,
	ToEulerAnglesYXZ = toOrientation,
	Orthonormalize = function(a)
		return a
	end,
}
CFMethods.components = CFMethods.GetComponents
CF.__index = function(self, key)
	if key == "Position" or key == "p" then
		return v3(self.x, self.y, self.z)
	elseif key == "X" then
		return self.x
	elseif key == "Y" then
		return self.y
	elseif key == "Z" then
		return self.z
	elseif key == "LookVector" then
		return v3(-self.r02, -self.r12, -self.r22)
	elseif key == "RightVector" or key == "XVector" then
		return v3(self.r00, self.r10, self.r20)
	elseif key == "UpVector" or key == "YVector" then
		return v3(self.r01, self.r11, self.r21)
	elseif key == "ZVector" then
		return v3(self.r02, self.r12, self.r22)
	elseif key == "Rotation" then
		return cf(0, 0, 0, self.r00, self.r01, self.r02, self.r10, self.r11, self.r12, self.r20, self.r21, self.r22)
	end
	local m = CFMethods[key]
	if m then
		return m
	end
	error(`{key} is not a valid member of CFrame`, 2)
end
CF.__mul = function(a, b)
	if rtypeof(b) == "Vector3" then
		return cfPoint(a, b)
	end
	return cfMul(a, b)
end
CF.__add = function(a, b)
	return cf(a.x + b.X, a.y + b.Y, a.z + b.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CF.__sub = function(a, b)
	return cf(a.x - b.X, a.y - b.Y, a.z - b.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CF.__eq = function(a, b)
	for _, k in ipairs({ "x", "y", "z", "r00", "r01", "r02", "r10", "r11", "r12", "r20", "r21", "r22" }) do
		if a[k] ~= b[k] then
			return false
		end
	end
	return true
end
CF.__tostring = function(a)
	return table.concat({ a:GetComponents() }, ", ")
end
CFrame.new = function(...)
	local n = select("#", ...)
	local a, b = ...
	if n == 0 then
		return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 1 then
		return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 2 then
		return lookAt(a, b)
	elseif n == 3 then
		local x, y, z = ...
		return cf(x, y, z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 7 then
		local x, y, z, qx, qy, qz, qw = ...
		local xx, yy, zz = qx * qx, qy * qy, qz * qz
		return cf(
			x, y, z,
			1 - 2 * (yy + zz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw), 1 - 2 * (xx + zz), 2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (xx + yy)
		)
	end
	return cf(...)
end
CFrame.lookAt = lookAt
CFrame.fromMatrix = function(pos, right, up, back)
	back = back or right:Cross(up).Unit
	return fromAxes(pos, right, up, back)
end
CFrame.Angles = function(x, y, z)
	return cfMul(cfMul(rotX(x), rotY(y)), rotZ(z))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.fromEulerAnglesYXZ = function(x, y, z)
	return cfMul(cfMul(rotY(y), rotX(x)), rotZ(z))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
CFrame.fromAxisAngle = function(axis, angle)
	local u = axis.Unit
	local c, s, t = math.cos(angle), math.sin(angle), 1 - math.cos(angle)
	return cf(
		0, 0, 0,
		t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
		t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
		t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c
	)
end
CFrame.identity = cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

--------------------------------------------------------------------------
-- Colour, UDim, misc value types
--------------------------------------------------------------------------

local Color3 = {}
local C3 = { [TYPE_KEY] = "Color3" }
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
C3.__index = function(self, key)
	if key == "Lerp" then
		return function(a, b, t)
			return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	elseif key == "ToHSV" then
		return function(c)
			local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
			local d = mx - mn
			local h = 0
			if d > 0 then
				if mx == c.R then
					h = ((c.G - c.B) / d) % 6
				elseif mx == c.G then
					h = (c.B - c.R) / d + 2
				else
					h = (c.R - c.G) / d + 4
				end
				h /= 6
			end
			return h, (if mx == 0 then 0 else d / mx), mx
		end
	elseif key == "ToHex" then
		return function(c)
			return string.format("%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255)
		end
	end
	error(`{key} is not a valid member of Color3`, 2)
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
C3.__tostring = function(a)
	return `{a.R}, {a.G}, {a.B}`
end
Color3.new = function(r, g, b)
	return c3(r or 0, g or 0, b or 0)
end
Color3.fromRGB = function(r, g, b)
	return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
Color3.fromHSV = function(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i %= 6
	if i == 0 then
		return c3(v, t, p)
	elseif i == 1 then
		return c3(q, v, p)
	elseif i == 2 then
		return c3(p, v, t)
	elseif i == 3 then
		return c3(p, q, v)
	elseif i == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end
Color3.fromHex = function(hex: string)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

local function valueType(name: string, fields: { string }, extra: { [string]: any }?)
	local mt = { [TYPE_KEY] = name }
	mt.__index = function(self, key)
		if extra and extra[key] then
			return extra[key]
		end
		error(`{key} is not a valid member of {name}`, 2)
	end
	mt.__eq = function(a, b)
		for _, f in ipairs(fields) do
			if a[f] ~= b[f] then
				return false
			end
		end
		return true
	end
	mt.__tostring = function(a)
		local out = {}
		for _, f in ipairs(fields) do
			table.insert(out, tostring(a[f]))
		end
		return `{name}({table.concat(out, ", ")})`
	end
	return function(...)
		local values = table.pack(...)
		local t = {}
		for i, f in ipairs(fields) do
			t[f] = values[i]
		end
		return setmetatable(t, mt)
	end
end

local makeUDim = valueType("UDim", { "Scale", "Offset" })
local UDim = {
	new = function(s, o)
		return makeUDim(s or 0, o or 0)
	end,
}
local UD2 = { [TYPE_KEY] = "UDim2" }
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = makeUDim(xs, xo), Y = makeUDim(ys, yo) }, UD2)
end
UD2.__index = function(self, key)
	if key == "Width" then
		return self.X
	elseif key == "Height" then
		return self.Y
	elseif key == "Lerp" then
		return function(a, b, t)
			return udim2(
				a.X.Scale + (b.X.Scale - a.X.Scale) * t,
				a.X.Offset + (b.X.Offset - a.X.Offset) * t,
				a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
				a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
			)
		end
	end
	error(`{key} is not a valid member of UDim2`, 2)
end
UD2.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__sub = function(a, b)
	return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UD2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
local UDim2 = {
	new = function(xs, xo, ys, yo)
		if rtypeof(xs) == "UDim" then
			return udim2(xs.Scale, xs.Offset, xo.Scale, xo.Offset)
		end
		return udim2(xs or 0, xo or 0, ys or 0, yo or 0)
	end,
	fromScale = function(x, y)
		return udim2(x or 0, 0, y or 0, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x or 0, 0, y or 0)
	end,
}

local makeTweenInfo = valueType("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" })
local TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delayTime)
		return makeTweenInfo(time or 1, style, direction, repeatCount or 0, reverses or false, delayTime or 0)
	end,
}

local makeNumberRange = valueType("NumberRange", { "Min", "Max" })
local NumberRange = {
	new = function(a, b)
		return makeNumberRange(a, b or a)
	end,
}
local makeSeqKey = valueType("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
local NumberSequenceKeypoint = {
	new = function(t, v, e)
		return makeSeqKey(t, v, e or 0)
	end,
}
local makeNumberSequence = valueType("NumberSequence", { "Keypoints" })
local NumberSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			return makeNumberSequence(a)
		end
		return makeNumberSequence({ makeSeqKey(0, a, 0), makeSeqKey(1, b or a, 0) })
	end,
}
local makeColorKey = valueType("ColorSequenceKeypoint", { "Time", "Value" })
local ColorSequenceKeypoint = {
	new = function(t, v)
		return makeColorKey(t, v)
	end,
}
local makeColorSequence = valueType("ColorSequence", { "Keypoints" })
local ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			return makeColorSequence(a)
		end
		return makeColorSequence({ makeColorKey(0, a), makeColorKey(1, b or a) })
	end,
}
local makeRectRaw = valueType("Rect", { "Min", "Max" })
local function makeRect(minV, maxV)
	local r = makeRectRaw(minV, maxV)
	local mt = getmetatable(r)
	local base = mt.__index
	mt.__index = function(self, key)
		if key == "Width" then
			return rawget(self, "Max").X - rawget(self, "Min").X
		elseif key == "Height" then
			return rawget(self, "Max").Y - rawget(self, "Min").Y
		end
		return base(self, key)
	end
	return r
end
local Rect = {
	new = function(a, b, c, d)
		if c then
			return makeRect(v2(a, b), v2(c, d))
		end
		return makeRect(a, b)
	end,
}
local makePhys = valueType("PhysicalProperties", { "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight" })
local PhysicalProperties = {
	new = function(...)
		return makePhys(...)
	end,
}
local makeFont = valueType("Font", { "Family", "Weight", "Style" })
local Font = {
	new = function(family, weight, style)
		return makeFont(family, weight, style)
	end,
	fromEnum = function(e)
		return makeFont(`rbxasset://fonts/families/{e.Name}.json`, nil, nil)
	end,
	fromName = function(name, weight, style)
		return makeFont(`rbxasset://fonts/families/{name}.json`, weight, style)
	end,
}
-- Deterministic PRNG (not Roblox's exact sequence; same API).
local RandomMT = { [TYPE_KEY] = "Random" }
RandomMT.__index = RandomMT
function RandomMT:NextNumber(a, b)
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	local r = self.state / 2147483648
	if a then
		return a + (b - a) * r
	end
	return r
end
function RandomMT:NextInteger(a, b)
	return math.floor(self:NextNumber(a, b + 1 - 1e-9))
end
function RandomMT:NextUnitVector()
	return v3(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1)).Unit
end
function RandomMT:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMT:Clone()
	return setmetatable({ state = self.state }, RandomMT)
end
local Random = {
	new = function(seed)
		return setmetatable({ state = math.floor(seed or 1) % 2147483648 }, RandomMT)
	end,
}

local BrickColor = {
	new = function(name)
		return setmetatable({ Name = tostring(name), Color = c3(0.5, 0.5, 0.5) }, { [TYPE_KEY] = "BrickColor" })
	end,
}

--------------------------------------------------------------------------
-- Enum (permissive: any Enum.Type.Item exists; items are interned)
--------------------------------------------------------------------------

local EnumItemMT = { [TYPE_KEY] = "EnumItem" }
EnumItemMT.__tostring = function(self)
	return `Enum.{self.EnumType.Name}.{self.Name}`
end
local EnumItemMethods = {
	IsA = function(self, typeName)
		return self.EnumType.Name == typeName
	end,
}
EnumItemMT.__index = EnumItemMethods
local EnumTypeMT = { [TYPE_KEY] = "Enum" }
local enumTypes = {}
EnumTypeMT.__index = function(self, key)
	if key == "GetEnumItems" then
		return function(t)
			local out = {}
			for _, item in pairs(rawget(t, "__items")) do
				table.insert(out, item)
			end
			return out
		end
	elseif key == "FromName" then
		return function(t, name)
			return t[name]
		end
	end
	local items = rawget(self, "__items")
	local item = items[key]
	if not item then
		local count = rawget(self, "__count") + 1
		rawset(self, "__count", count)
		item = setmetatable({ Name = key, Value = count, EnumType = self }, EnumItemMT)
		items[key] = item
	end
	return item
end
local Enum = setmetatable({}, {
	[TYPE_KEY] = "Enums",
	__index = function(_, typeName)
		local t = enumTypes[typeName]
		if not t then
			t = setmetatable({ Name = typeName, __items = {}, __count = -1 }, EnumTypeMT)
			enumTypes[typeName] = t
		end
		return t
	end,
})

--------------------------------------------------------------------------
-- Virtual-time scheduler
--------------------------------------------------------------------------

local Scheduler = {
	now = 0,
	frame = 0,
	deferred = {} :: { { any } },
	sleeping = {} :: { { wake: number, thread: thread, args: { any }? } },
	heartbeat = nil :: any,
}
Shim.Scheduler = Scheduler

Shim.mockPlayerFireErrors = 0
local function reportError(thread: thread, err: any)
	local message = tostring(err)
	-- The unit tests use plain tables as mock players; the server's
	-- remote bridges then FireClient them, which errors in Studio as well
	-- ("Unable to cast value to Object"). Counted, not reported.
	if string.find(message, "FireClient: player argument must be a Player", 1, true) then
		Shim.mockPlayerFireErrors += 1
		return
	end
	local trace = debug.traceback(thread)
	table.insert(unexpectedErrors, message)
	realPrint("ERROR " .. message .. "\n" .. trace)
end

local function resume(thread: thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		reportError(thread, err)
	end
end

local function toThread(fnOrThread, ...)
	if type(fnOrThread) == "thread" then
		return fnOrThread
	end
	return coroutine.create(fnOrThread)
end

local task = {}
task.spawn = function(fnOrThread, ...)
	local thread = toThread(fnOrThread)
	resume(thread, ...)
	return thread
end
task.defer = function(fnOrThread, ...)
	local thread = toThread(fnOrThread)
	table.insert(Scheduler.deferred, { thread, table.pack(...) })
	return thread
end
task.delay = function(seconds, fnOrThread, ...)
	local thread = toThread(fnOrThread)
	table.insert(Scheduler.sleeping, { wake = Scheduler.now + (seconds or 0), thread = thread, args = table.pack(...) })
	return thread
end
task.wait = function(seconds)
	local thread = coroutine.running()
	local start = Scheduler.now
	table.insert(Scheduler.sleeping, { wake = Scheduler.now + math.max(seconds or 0, 1 / 60), thread = thread })
	coroutine.yield()
	return Scheduler.now - start
end
task.cancel = function(thread)
	for i = #Scheduler.sleeping, 1, -1 do
		if Scheduler.sleeping[i].thread == thread then
			table.remove(Scheduler.sleeping, i)
		end
	end
	for i = #Scheduler.deferred, 1, -1 do
		if Scheduler.deferred[i][1] == thread then
			table.remove(Scheduler.deferred, i)
		end
	end
	pcall(coroutine.close, thread)
end
task.synchronize = function() end
task.desynchronize = function() end

local function flushDeferred()
	local guard = 0
	while #Scheduler.deferred > 0 do
		guard += 1
		if guard > 100000 then
			error("deferred queue did not settle (re-entrant event loop?)")
		end
		local entry = table.remove(Scheduler.deferred, 1)
		local thread, args = entry[1], entry[2]
		if coroutine.status(thread) == "suspended" then
			resume(thread, table.unpack(args, 1, args.n))
		end
	end
end
Shim.flushDeferred = flushDeferred

-- Advance virtual time one frame: wake due sleepers, run deferred work,
-- fire Heartbeat. Returns whether anything is still pending.
local function step(dt: number?): boolean
	local delta = dt or 1 / 60
	Scheduler.now += delta
	Scheduler.frame += 1
	flushDeferred()
	local due = {}
	for i = #Scheduler.sleeping, 1, -1 do
		local s = Scheduler.sleeping[i]
		if s.wake <= Scheduler.now + 1e-9 then
			table.remove(Scheduler.sleeping, i)
			table.insert(due, 1, s)
		end
	end
	table.sort(due, function(a, b)
		return a.wake < b.wake
	end)
	for _, s in ipairs(due) do
		if coroutine.status(s.thread) == "suspended" then
			if s.args then
				resume(s.thread, table.unpack(s.args, 1, s.args.n))
			else
				resume(s.thread)
			end
		end
		flushDeferred()
	end
	if Scheduler.heartbeat then
		Scheduler.heartbeat(delta)
	end
	flushDeferred()
	return #Scheduler.sleeping > 0 or #Scheduler.deferred > 0
end
Shim.step = step

-- Run until nothing is sleeping/deferred or `maxSeconds` of virtual time.
function Shim.settle(maxSeconds: number?)
	local limit = Scheduler.now + (maxSeconds or 30)
	flushDeferred()
	while (#Scheduler.sleeping > 0 or #Scheduler.deferred > 0) and Scheduler.now < limit do
		step()
	end
end

-- Advance exactly `seconds` of virtual time.
function Shim.advance(seconds: number)
	local target = Scheduler.now + seconds
	while Scheduler.now < target - 1e-9 do
		step()
	end
end

--------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------

local SignalMT = { [TYPE_KEY] = "RBXScriptSignal" }
SignalMT.__index = SignalMT
local ConnectionMT = { [TYPE_KEY] = "RBXScriptConnection" }
ConnectionMT.__index = ConnectionMT

local function newSignal(deferred: boolean?)
	return setmetatable({ handlers = {}, waiters = {}, deferred = deferred == true }, SignalMT)
end

function SignalMT:Connect(fn)
	local connection = setmetatable({ Connected = true, fn = fn, signal = self }, ConnectionMT)
	table.insert(self.handlers, connection)
	return connection
end
SignalMT.connect = SignalMT.Connect
function SignalMT:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end
function SignalMT:Wait()
	local thread = coroutine.running()
	table.insert(self.waiters, thread)
	return coroutine.yield()
end
function ConnectionMT:Disconnect()
	self.Connected = false
	local list = self.signal.handlers
	for i = #list, 1, -1 do
		if list[i] == self then
			table.remove(list, i)
		end
	end
end
ConnectionMT.disconnect = ConnectionMT.Disconnect

local function fireSignal(signal, ...)
	local handlers = table.clone(signal.handlers)
	local waiters = signal.waiters
	signal.waiters = {}
	local args = table.pack(...)
	for _, connection in ipairs(handlers) do
		if connection.Connected then
			local thread = coroutine.create(connection.fn)
			if signal.deferred then
				table.insert(Scheduler.deferred, { thread, args })
			else
				resume(thread, table.unpack(args, 1, args.n))
			end
		end
	end
	for _, thread in ipairs(waiters) do
		if signal.deferred then
			table.insert(Scheduler.deferred, { thread, args })
		else
			resume(thread, table.unpack(args, 1, args.n))
		end
	end
end
Shim.fireSignal = fireSignal
Shim.newSignal = newSignal

--------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------

local SUPER: { [string]: string } = {
	PVInstance = "Instance",
	BasePart = "PVInstance",
	Part = "FormFactorPart",
	FormFactorPart = "BasePart",
	WedgePart = "FormFactorPart",
	CornerWedgePart = "BasePart",
	TrussPart = "BasePart",
	MeshPart = "TriangleMeshPart",
	TriangleMeshPart = "BasePart",
	PartOperation = "TriangleMeshPart",
	UnionOperation = "PartOperation",
	NegateOperation = "PartOperation",
	SpawnLocation = "Part",
	Seat = "Part",
	VehicleSeat = "BasePart",
	Terrain = "BasePart",
	Model = "PVInstance",
	WorldModel = "WorldRoot",
	WorldRoot = "Model",
	Workspace = "WorldRoot",
	Camera = "PVInstance",
	Folder = "Instance",
	Configuration = "Instance",
	LuaSourceContainer = "Instance",
	BaseScript = "LuaSourceContainer",
	Script = "BaseScript",
	LocalScript = "Script",
	ModuleScript = "LuaSourceContainer",
	BindableEvent = "Instance",
	BindableFunction = "Instance",
	RemoteEvent = "BaseRemoteEvent",
	UnreliableRemoteEvent = "BaseRemoteEvent",
	BaseRemoteEvent = "Instance",
	RemoteFunction = "Instance",
	Humanoid = "Instance",
	HumanoidDescription = "Instance",
	Animator = "Instance",
	Animation = "Instance",
	AnimationTrack = "Instance",
	Accoutrement = "Instance",
	Accessory = "Accoutrement",
	Hat = "Accoutrement",
	Attachment = "Instance",
	Bone = "Attachment",
	JointInstance = "Instance",
	Weld = "JointInstance",
	Motor6D = "Motor",
	Motor = "JointInstance",
	WeldConstraint = "Instance",
	Constraint = "Instance",
	Light = "Instance",
	PointLight = "Light",
	SpotLight = "Light",
	SurfaceLight = "Light",
	GuiBase = "Instance",
	GuiBase2d = "GuiBase",
	LayerCollector = "GuiBase2d",
	ScreenGui = "LayerCollector",
	SurfaceGuiBase = "LayerCollector",
	SurfaceGui = "SurfaceGuiBase",
	BillboardGui = "LayerCollector",
	GuiObject = "GuiBase2d",
	Frame = "GuiObject",
	CanvasGroup = "GuiObject",
	ScrollingFrame = "GuiObject",
	ViewportFrame = "GuiObject",
	TextLabel = "GuiLabel",
	GuiLabel = "GuiObject",
	ImageLabel = "GuiLabel",
	GuiButton = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	TextBox = "GuiObject",
	UIComponent = "UIBase",
	UIBase = "Instance",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIPadding = "UIComponent",
	UIGradient = "UIComponent",
	UIScale = "UIComponent",
	UILayout = "UIComponent",
	UIGridStyleLayout = "UILayout",
	UIListLayout = "UIGridStyleLayout",
	UIGridLayout = "UIGridStyleLayout",
	UIConstraint = "UIComponent",
	UIAspectRatioConstraint = "UIConstraint",
	UISizeConstraint = "UIConstraint",
	UITextSizeConstraint = "UIConstraint",
	UIFlexItem = "UIComponent",
	FaceInstance = "Instance",
	Decal = "FaceInstance",
	Texture = "Decal",
	SurfaceAppearance = "Instance",
	DataModelMesh = "Instance",
	FileMesh = "DataModelMesh",
	SpecialMesh = "FileMesh",
	BlockMesh = "BevelMesh",
	BevelMesh = "DataModelMesh",
	Sound = "Instance",
	SoundGroup = "Instance",
	PostEffect = "Instance",
	ColorCorrectionEffect = "PostEffect",
	BloomEffect = "PostEffect",
	SunRaysEffect = "PostEffect",
	BlurEffect = "PostEffect",
	DepthOfFieldEffect = "PostEffect",
	Atmosphere = "Instance",
	Sky = "Instance",
	Clouds = "Instance",
	CharacterAppearance = "Instance",
	BodyColors = "CharacterAppearance",
	Clothing = "CharacterAppearance",
	Shirt = "Clothing",
	Pants = "Clothing",
	ShirtGraphic = "CharacterAppearance",
	ProximityPrompt = "Instance",
	Beam = "Instance",
	ParticleEmitter = "Instance",
	Highlight = "Instance",
	ValueBase = "Instance",
	StringValue = "ValueBase",
	IntValue = "ValueBase",
	NumberValue = "ValueBase",
	BoolValue = "ValueBase",
	ObjectValue = "ValueBase",
	CFrameValue = "ValueBase",
	Vector3Value = "ValueBase",
	Color3Value = "ValueBase",
	Player = "Instance",
	PlayerGui = "BasePlayerGui",
	BasePlayerGui = "Instance",
	Backpack = "Instance",
	PlayerScripts = "Instance",
	StarterPlayerScripts = "Instance",
	StarterCharacterScripts = "StarterPlayerScripts",
	Tween = "TweenBase",
	TweenBase = "Instance",
	MaterialVariant = "Instance",
	DataModel = "ServiceProvider",
	ServiceProvider = "Instance",
	Players = "Instance",
	Lighting = "Instance",
	ReplicatedStorage = "Instance",
	ServerStorage = "Instance",
	ServerScriptService = "Instance",
	StarterPlayer = "Instance",
	StarterGui = "BasePlayerGui",
	SoundService = "Instance",
	MaterialService = "Instance",
	CollectionService = "Instance",
	RunService = "Instance",
	TweenService = "Instance",
	UserInputService = "Instance",
	ContextActionService = "Instance",
	GuiService = "Instance",
	HttpService = "Instance",
	TextService = "Instance",
	Debris = "Instance",
	MarketplaceService = "Instance",
	InsertService = "Instance",
	ContentProvider = "Instance",
	TeleportService = "Instance",
	StarterPack = "Instance",
	Teams = "Instance",
	Chat = "Instance",
	TextChatService = "Instance",
	VRService = "Instance",
	HapticService = "Instance",
	AssetService = "Instance",
}
Shim.knownClasses = SUPER

local function isA(className: string, target: string): boolean
	local c: string? = className
	while c do
		if c == target then
			return true
		end
		c = SUPER[c]
	end
	return target == "Instance"
end

local DEFAULTS: { [string]: { [string]: any } } = {
	Instance = { Archivable = true },
	BasePart = {
		Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true,
		Transparency = 0, Reflectance = 0, Massless = false, Locked = false,
		Material = Enum.Material.Plastic, Color = c3(163 / 255, 162 / 255, 165 / 255),
		Size = v3(4, 1, 2), LocalTransparencyModifier = 0, CollisionGroup = "Default",
		AssemblyLinearVelocity = v3(0, 0, 0), AssemblyAngularVelocity = v3(0, 0, 0),
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	},
	Part = { Shape = Enum.PartType.Block },
	MeshPart = { MeshId = "", TextureID = "", DoubleSided = false },
	SpawnLocation = { Duration = 10, Neutral = true, Enabled = true, AllowTeamChangeOnTouch = false },
	Model = { PrimaryPart = nil, LevelOfDetail = Enum.ModelLevelOfDetail.Automatic },
	Humanoid = {
		Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, UseJumpPower = false,
		HipHeight = 2, DisplayName = "", AutoRotate = true, PlatformStand = false, Sit = false,
		RigType = Enum.HumanoidRigType.R15, MoveDirection = v3(0, 0, 0), FloorMaterial = Enum.Material.Air,
		CameraOffset = v3(0, 0, 0), BreakJointsOnDeath = true, RequiresNeck = true,
		DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer,
		HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged,
	},
	Light = { Brightness = 1, Color = c3(1, 1, 1), Enabled = true, Shadows = false, Range = 8 },
	SpotLight = { Angle = 90, Face = Enum.NormalId.Front, Range = 16 },
	SurfaceLight = { Angle = 90, Face = Enum.NormalId.Front, Range = 16 },
	GuiBase2d = { AbsoluteSize = v2(1280, 720), AbsolutePosition = v2(0, 0), AbsoluteRotation = 0 },
	LayerCollector = { Enabled = true, ResetOnSpawn = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
	ScreenGui = { DisplayOrder = 0, IgnoreGuiInset = false },
	SurfaceGui = { Face = Enum.NormalId.Front, PixelsPerStud = 50, LightInfluence = 1, AlwaysOnTop = false },
	BillboardGui = { AlwaysOnTop = false, StudsOffset = v3(0, 0, 0), MaxDistance = math.huge, LightInfluence = 0 },
	GuiObject = {
		Visible = true, Size = udim2(0, 100, 0, 100), Position = udim2(0, 0, 0, 0), AnchorPoint = v2(0, 0),
		BackgroundColor3 = c3(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 1, ZIndex = 1,
		LayoutOrder = 0, Rotation = 0, ClipsDescendants = false, Active = false, Selectable = false,
		AutomaticSize = Enum.AutomaticSize.None, Interactable = true, SelectionOrder = 0,
		BorderColor3 = c3(0.1, 0.1, 0.1),
	},
	GuiLabel = {},
	TextLabel = {
		Text = "Label", TextColor3 = c3(0, 0, 0), TextSize = 14, TextTransparency = 0, TextScaled = false,
		TextWrapped = false, RichText = false, Font = Enum.Font.Legacy, LineHeight = 1, MaxVisibleGraphemes = -1,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1, TextStrokeColor3 = c3(0, 0, 0), TextBounds = v2(0, 0), TextFits = true,
		ContentText = "",
	},
	TextButton = {
		Text = "Button", TextColor3 = c3(0, 0, 0), TextSize = 14, TextTransparency = 0, TextScaled = false,
		TextWrapped = false, RichText = false, Font = Enum.Font.Legacy, AutoButtonColor = true, LineHeight = 1,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		MaxVisibleGraphemes = -1, TextStrokeTransparency = 1, TextBounds = v2(0, 0), Selected = false,
	},
	TextBox = { Text = "", TextColor3 = c3(0, 0, 0), TextSize = 14, Font = Enum.Font.Legacy },
	ImageLabel = { Image = "", ImageColor3 = c3(1, 1, 1), ImageTransparency = 0, ScaleType = Enum.ScaleType.Stretch },
	ImageButton = { Image = "", ImageColor3 = c3(1, 1, 1), ImageTransparency = 0, AutoButtonColor = true },
	ScrollingFrame = {
		CanvasSize = udim2(0, 0, 2, 0), CanvasPosition = v2(0, 0), ScrollBarThickness = 12,
		AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.XY,
		ScrollingEnabled = true, ScrollBarImageColor3 = c3(1, 1, 1), ScrollBarImageTransparency = 0,
		AbsoluteCanvasSize = v2(0, 0), AbsoluteWindowSize = v2(0, 0),
	},
	ViewportFrame = { Ambient = c3(0.78, 0.78, 0.78), LightColor = c3(0.55, 0.55, 0.55), LightDirection = v3(-1, -1, -1), ImageTransparency = 0, ImageColor3 = c3(1, 1, 1) },
	CanvasGroup = { GroupTransparency = 0, GroupColor3 = c3(1, 1, 1) },
	UIStroke = { Color = c3(0, 0, 0), Thickness = 1, Transparency = 0, Enabled = true, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
	UICorner = { CornerRadius = makeUDim(0, 8) },
	UIPadding = { PaddingTop = makeUDim(0, 0), PaddingBottom = makeUDim(0, 0), PaddingLeft = makeUDim(0, 0), PaddingRight = makeUDim(0, 0) },
	UIListLayout = {
		Padding = makeUDim(0, 0), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top,
		AbsoluteContentSize = v2(0, 0),
	},
	UIGradient = { Rotation = 0, Enabled = true, Offset = v2(0, 0) },
	UIScale = { Scale = 1 },
	Sound = { Volume = 0.5, Looped = false, Playing = false, TimePosition = 0, PlaybackSpeed = 1, SoundId = "", IsLoaded = true, TimeLength = 1 },
	SoundGroup = { Volume = 0.5 },
	Decal = { Texture = "", Transparency = 0, Color3 = c3(1, 1, 1), Face = Enum.NormalId.Front },
	Texture = { StudsPerTileU = 2, StudsPerTileV = 2, OffsetStudsU = 0, OffsetStudsV = 0 },
	SpecialMesh = { MeshType = Enum.MeshType.Head, MeshId = "", TextureId = "", Scale = v3(1, 1, 1), Offset = v3(0, 0, 0) },
	Camera = { FieldOfView = 70, CameraType = Enum.CameraType.Custom, CFrame = CFrame.identity, Focus = CFrame.identity, ViewportSize = v2(1280, 720) },
	Player = { UserId = 1, Name = "Player", DisplayName = "Player", CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5, CameraMode = Enum.CameraMode.Classic },
	Attachment = { CFrame = CFrame.identity, Visible = false },
	WeldConstraint = { Enabled = true },
	Weld = { C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true },
	Motor6D = { C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true },
	ProximityPrompt = { Enabled = true, MaxActivationDistance = 10, HoldDuration = 0, RequiresLineOfSight = true },
	ColorCorrectionEffect = { Enabled = true, Brightness = 0, Contrast = 0, Saturation = 0, TintColor = c3(1, 1, 1) },
	BloomEffect = { Enabled = true, Intensity = 1, Size = 24, Threshold = 2 },
	SunRaysEffect = { Enabled = true, Intensity = 0.25, Spread = 1 },
	DepthOfFieldEffect = { Enabled = true, FarIntensity = 0.75, FocusDistance = 0.05, InFocusRadius = 10, NearIntensity = 0.75 },
	BlurEffect = { Enabled = true, Size = 24 },
	Atmosphere = { Density = 0.395, Offset = 0, Color = c3(0.78, 0.78, 0.78), Decay = c3(0.4, 0.44, 0.5), Glare = 0, Haze = 0 },
	Lighting = {
		Ambient = c3(0.27, 0.27, 0.27), OutdoorAmbient = c3(0.5, 0.5, 0.5), Brightness = 2, ClockTime = 14,
		TimeOfDay = "14:00:00", GlobalShadows = true, ShadowSoftness = 0.2, FogEnd = 100000, FogStart = 0,
		FogColor = c3(0.75, 0.75, 0.75), ExposureCompensation = 0, EnvironmentDiffuseScale = 0,
		EnvironmentSpecularScale = 0, ColorShift_Top = c3(0, 0, 0), ColorShift_Bottom = c3(0, 0, 0),
		GeographicLatitude = 41.73,
	},
	Highlight = { Enabled = true, FillTransparency = 0.5, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop },
	ParticleEmitter = { Enabled = true, Rate = 5 },
	Beam = { Enabled = true },
	BodyColors = {},
	ValueBase = {},
	StringValue = { Value = "" },
	NumberValue = { Value = 0 },
	IntValue = { Value = 0 },
	BoolValue = { Value = false },
	ObjectValue = {},
	Animation = { AnimationId = "" },
	LuaSourceContainer = {},
	BaseScript = { Disabled = false, Enabled = true },
	HumanoidDescription = {
		HairAccessory = "", HatAccessory = "", FaceAccessory = "", NeckAccessory = "", ShouldersAccessory = "",
		FrontAccessory = "", BackAccessory = "", WaistAccessory = "", Shirt = 0, Pants = 0, GraphicTShirt = 0,
		Face = 0, Head = 0, Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0,
		HeadColor = c3(1, 0.8, 0.6), TorsoColor = c3(1, 0.8, 0.6), LeftArmColor = c3(1, 0.8, 0.6),
		RightArmColor = c3(1, 0.8, 0.6), LeftLegColor = c3(1, 0.8, 0.6), RightLegColor = c3(1, 0.8, 0.6),
		BodyTypeScale = 0.3, DepthScale = 1, HeadScale = 1, HeightScale = 1, ProportionScale = 1, WidthScale = 1,
		IdleAnimation = 0,
	},
	Shirt = { ShirtTemplate = "", Color3 = c3(1, 1, 1) },
	Pants = { PantsTemplate = "", Color3 = c3(1, 1, 1) },
	Accessory = { AccessoryType = Enum.AccessoryType.Unknown },
	MaterialVariant = { BaseMaterial = Enum.Material.Plastic, StudsPerTile = 10 },
	SurfaceAppearance = {},
}

-- Real properties whose default value is nil (reading them must not error).
local NIL_DEFAULTS: { [string]: { [string]: boolean } } = {
	Model = { PrimaryPart = true },
	GuiService = { SelectedObject = true },
	Player = { Character = true, Team = true },
	ViewportFrame = { CurrentCamera = true },
	Camera = { CameraSubject = true },
	WeldConstraint = { Part0 = true, Part1 = true },
	JointInstance = { Part0 = true, Part1 = true },
	Sound = { SoundGroup = true },
	LayerCollector = { Adornee = true },
	Highlight = { Adornee = true },
	ObjectValue = { Value = true },
	Humanoid = { SeatPart = true },
	GuiObject = { NextSelectionUp = true, NextSelectionDown = true, NextSelectionLeft = true, NextSelectionRight = true },
	Attachment = {},
}

local function nilDefault(className: string, key: string): boolean
	local c: string? = className
	while c do
		local d = NIL_DEFAULTS[c]
		if d and d[key] then
			return true
		end
		c = SUPER[c]
	end
	return false
end

local function defaultFor(className: string, key: string): (boolean, any)
	local c: string? = className
	while c do
		local d = DEFAULTS[c]
		if d and d[key] ~= nil then
			return true, d[key]
		end
		c = SUPER[c]
	end
	local d = DEFAULTS.Instance
	if d[key] ~= nil then
		return true, d[key]
	end
	return false, nil
end

local InstanceMT = { [TYPE_KEY] = "Instance" }
local Methods: { [string]: { [string]: any } } = {}
local instanceCount = 0
local allTagged: { [string]: { [any]: boolean } } = {}
local tagAddedSignals: { [string]: any } = {}
local tagRemovedSignals: { [string]: any } = {}
Shim.allTagged = allTagged

-- Per-class special getters/setters (property name -> fn).
local Getters: { [string]: { [string]: (any) -> any } } = {}
local Setters: { [string]: { [string]: (any, any) -> () } } = {}

local function lookup(tbl, className, key)
	local c: string? = className
	while c do
		local entry = tbl[c]
		if entry and entry[key] ~= nil then
			return entry[key]
		end
		c = SUPER[c]
	end
	local base = tbl.Instance
	return base and base[key]
end

local function internal(self)
	return rawget(self, "__i")
end

local function propertySignal(self, key)
	local i = internal(self)
	local signals = i.propSignals
	local s = signals[key]
	if not s then
		s = newSignal(true)
		signals[key] = s
	end
	return s
end

local function notifyChanged(self, key)
	local i = internal(self)
	local s = i.propSignals[key]
	if s then
		fireSignal(s)
	end
	if i.changed then
		-- A value object's Changed carries the new value, not the property name.
		if key == "Value" and isA(i.className, "ValueBase") then
			fireSignal(i.changed, i.props.Value)
		else
			fireSignal(i.changed, key)
		end
	end
end

InstanceMT.__index = function(self, key)
	local i = internal(self)
	if key == "ClassName" then
		return i.className
	elseif key == "Name" then
		return i.name
	elseif key == "Parent" then
		return i.parent
	end
	local getter = lookup(Getters, i.className, key)
	if getter then
		return getter(self)
	end
	local v = i.props[key]
	if v ~= nil then
		return v
	end
	local method = lookup(Methods, i.className, key)
	if method then
		return method
	end
	-- Children are addressable by name (Instance.ChildName).
	for _, child in ipairs(i.children) do
		if internal(child).name == key then
			return child
		end
	end
	local has, default = defaultFor(i.className, key)
	if has then
		return default
	end
	if i.propsSet[key] or nilDefault(i.className, key) then
		return nil
	end
	error(`{key} is not a valid member of {i.className} "{i.name}"`, 2)
end

local setParent

InstanceMT.__newindex = function(self, key, value)
	local i = internal(self)
	if i.readOnly and i.readOnly[key] then
		error(`{key} is read-only on {i.className}`, 2)
	end
	if key == "Name" then
		i.name = tostring(value)
		notifyChanged(self, key)
		return
	elseif key == "Parent" then
		setParent(self, value)
		return
	elseif key == "ClassName" then
		error("ClassName is read-only", 2)
	end
	local setter = lookup(Setters, i.className, key)
	if setter then
		setter(self, value)
	else
		i.props[key] = value
		i.propsSet[key] = true
	end
	notifyChanged(self, key)
end

InstanceMT.__tostring = function(self)
	return internal(self).name
end

local function getFullName(self)
	local names = {}
	local cur = self
	while cur and internal(cur).className ~= "DataModel" do
		table.insert(names, 1, internal(cur).name)
		cur = internal(cur).parent
	end
	return table.concat(names, ".")
end

local function isDescendantOf(self, ancestor)
	local cur = internal(self).parent
	while cur do
		if cur == ancestor then
			return true
		end
		cur = internal(cur).parent
	end
	return false
end

local function fireDescendantAdded(ancestorStart, inst)
	local cur = ancestorStart
	while cur do
		local s = internal(cur).descendantAdded
		if s then
			fireSignal(s, inst)
		end
		cur = internal(cur).parent
	end
end

setParent = function(self, newParent)
	local i = internal(self)
	if i.destroyed and newParent ~= nil then
		error(`The Parent property of {i.name} is locked`, 3)
	end
	if newParent == self then
		error("Attempt to set parent to self", 3)
	end
	if newParent and isDescendantOf(newParent, self) then
		error("Attempt to set parent would result in circular reference", 3)
	end
	local old = i.parent
	if old == newParent then
		return
	end
	if old then
		local oi = internal(old)
		for idx, c in ipairs(oi.children) do
			if c == self then
				table.remove(oi.children, idx)
				break
			end
		end
		if oi.childRemoved then
			fireSignal(oi.childRemoved, self)
		end
	end
	i.parent = newParent
	if newParent then
		local ni = internal(newParent)
		table.insert(ni.children, self)
		if ni.childAdded then
			fireSignal(ni.childAdded, self)
		end
		fireDescendantAdded(newParent, self)
		for _, d in ipairs(self:GetDescendants()) do
			fireDescendantAdded(newParent, d)
		end
	end
	if i.ancestryChanged then
		fireSignal(i.ancestryChanged, self, newParent)
	end
	notifyChanged(self, "Parent")
end

local function newInstance(className: string, name: string?)
	instanceCount += 1
	local i = {
		className = className,
		name = name or className,
		parent = nil,
		children = {},
		props = {},
		propsSet = {},
		attributes = {},
		attrSignals = {},
		propSignals = {},
		tags = {},
		id = instanceCount,
	}
	local self = setmetatable({ __i = i }, InstanceMT)
	return self
end
Shim.newInstance = newInstance

local function signalGetter(field: string)
	return function(self)
		local i = internal(self)
		local s = i[field]
		if not s then
			s = newSignal(true)
			i[field] = s
		end
		return s
	end
end

Getters.Instance = {
	ChildAdded = signalGetter("childAdded"),
	ChildRemoved = signalGetter("childRemoved"),
	DescendantAdded = signalGetter("descendantAdded"),
	DescendantRemoving = signalGetter("descendantRemoving"),
	AncestryChanged = signalGetter("ancestryChanged"),
	Changed = signalGetter("changed"),
	Destroying = signalGetter("destroying"),
	AttributeChanged = signalGetter("attributeChanged"),
}

local function childrenOf(self)
	return internal(self).children
end

Methods.Instance = {
	GetChildren = function(self)
		return table.clone(childrenOf(self))
	end,
	GetDescendants = function(self)
		local out = {}
		local function walk(inst)
			for _, c in ipairs(childrenOf(inst)) do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(self)
		return out
	end,
	FindFirstChild = function(self, name, recursive)
		for _, c in ipairs(childrenOf(self)) do
			if internal(c).name == name then
				return c
			end
		end
		if recursive then
			for _, c in ipairs(childrenOf(self)) do
				local found = c:FindFirstChild(name, true)
				if found then
					return found
				end
			end
		end
		return nil
	end,
	FindFirstChildOfClass = function(self, className)
		for _, c in ipairs(childrenOf(self)) do
			if internal(c).className == className then
				return c
			end
		end
		return nil
	end,
	FindFirstChildWhichIsA = function(self, className, recursive)
		for _, c in ipairs(childrenOf(self)) do
			if isA(internal(c).className, className) then
				return c
			end
		end
		if recursive then
			for _, c in ipairs(childrenOf(self)) do
				local found = c:FindFirstChildWhichIsA(className, true)
				if found then
					return found
				end
			end
		end
		return nil
	end,
	FindFirstDescendant = function(self, name)
		return self:FindFirstChild(name, true)
	end,
	FindFirstAncestor = function(self, name)
		local cur = internal(self).parent
		while cur do
			if internal(cur).name == name then
				return cur
			end
			cur = internal(cur).parent
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, className)
		local cur = internal(self).parent
		while cur do
			if internal(cur).className == className then
				return cur
			end
			cur = internal(cur).parent
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, className)
		local cur = internal(self).parent
		while cur do
			if isA(internal(cur).className, className) then
				return cur
			end
			cur = internal(cur).parent
		end
		return nil
	end,
	WaitForChild = function(self, name, timeout)
		local found = self:FindFirstChild(name)
		if found then
			return found
		end
		if not coroutine.isyieldable() then
			error(`WaitForChild({name}) on {getFullName(self)} would yield outside a coroutine`, 2)
		end
		local waited = 0
		local limit = timeout or 5
		while waited < limit do
			waited += task.wait()
			found = self:FindFirstChild(name)
			if found then
				return found
			end
		end
		if timeout == nil then
			shimWarn(`Infinite yield possible on '{getFullName(self)}:WaitForChild("{name}")'`)
			-- Keep waiting like the engine would.
			while true do
				task.wait()
				found = self:FindFirstChild(name)
				if found then
					return found
				end
			end
		end
		return nil
	end,
	IsA = function(self, className)
		return isA(internal(self).className, className)
	end,
	IsDescendantOf = function(self, ancestor)
		return isDescendantOf(self, ancestor)
	end,
	IsAncestorOf = function(self, descendant)
		return isDescendantOf(descendant, self)
	end,
	GetFullName = getFullName,
	Destroy = function(self)
		local i = internal(self)
		if i.destroying then
			fireSignal(i.destroying)
		end
		for _, c in ipairs(table.clone(i.children)) do
			c:Destroy()
		end
		setParent(self, nil)
		for tag in pairs(i.tags) do
			self:RemoveTag(tag)
		end
		i.destroyed = true
	end,
	ClearAllChildren = function(self)
		for _, c in ipairs(table.clone(childrenOf(self))) do
			c:Destroy()
		end
	end,
	Remove = function(self)
		setParent(self, nil)
	end,
	Clone = function(self)
		local i = internal(self)
		if i.props.Archivable == false then
			return nil
		end
		local copy = newInstance(i.className, i.name)
		local ci = internal(copy)
		for k, v in pairs(i.props) do
			ci.props[k] = v
		end
		for k, v in pairs(i.propsSet) do
			ci.propsSet[k] = v
		end
		for k, v in pairs(i.attributes) do
			ci.attributes[k] = v
		end
		for tag in pairs(i.tags) do
			copy:AddTag(tag)
		end
		for _, c in ipairs(i.children) do
			local cc = c:Clone()
			if cc then
				setParent(cc, copy)
			end
		end
		return copy
	end,
	GetAttribute = function(self, name)
		return internal(self).attributes[name]
	end,
	SetAttribute = function(self, name, value)
		local i = internal(self)
		local t = rtypeof(value)
		local allowed = {
			["nil"] = true, string = true, boolean = true, number = true, UDim = true, UDim2 = true,
			BrickColor = true, Color3 = true, Vector2 = true, Vector3 = true, CFrame = true,
			NumberSequence = true, ColorSequence = true, NumberRange = true, Rect = true, Font = true,
			EnumItem = true,
		}
		if not allowed[t] then
			error(`{t} is not a supported attribute type`, 2)
		end
		i.attributes[name] = value
		local s = i.attrSignals[name]
		if s then
			fireSignal(s)
		end
		if i.attributeChanged then
			fireSignal(i.attributeChanged, name)
		end
	end,
	GetAttributes = function(self)
		return table.clone(internal(self).attributes)
	end,
	GetAttributeChangedSignal = function(self, name)
		local i = internal(self)
		local s = i.attrSignals[name]
		if not s then
			s = newSignal(true)
			i.attrSignals[name] = s
		end
		return s
	end,
	GetPropertyChangedSignal = function(self, key)
		return propertySignal(self, key)
	end,
	AddTag = function(self, tag)
		local i = internal(self)
		if i.tags[tag] then
			return
		end
		i.tags[tag] = true
		allTagged[tag] = allTagged[tag] or {}
		allTagged[tag][self] = true
		if tagAddedSignals[tag] then
			fireSignal(tagAddedSignals[tag], self)
		end
	end,
	RemoveTag = function(self, tag)
		local i = internal(self)
		if not i.tags[tag] then
			return
		end
		i.tags[tag] = nil
		if allTagged[tag] then
			allTagged[tag][self] = nil
		end
		if tagRemovedSignals[tag] then
			fireSignal(tagRemovedSignals[tag], self)
		end
	end,
	HasTag = function(self, tag)
		return internal(self).tags[tag] == true
	end,
	GetTags = function(self)
		local out = {}
		for tag in pairs(internal(self).tags) do
			table.insert(out, tag)
		end
		return out
	end,
	GetActor = function()
		return nil
	end,
}

-- Parts ----------------------------------------------------------------

Getters.BasePart = {
	CFrame = function(self)
		return internal(self).props.CFrame or CFrame.identity
	end,
	Position = function(self)
		return (internal(self).props.CFrame or CFrame.identity).Position
	end,
	Orientation = function(self)
		local x, y, z = toOrientation(internal(self).props.CFrame or CFrame.identity)
		return v3(math.deg(x), math.deg(y), math.deg(z))
	end,
	Rotation = function(self)
		local x, y, z = toEulerXYZ(internal(self).props.CFrame or CFrame.identity)
		return v3(math.deg(x), math.deg(y), math.deg(z))
	end,
	PivotOffset = function(self)
		return internal(self).props.PivotOffset or CFrame.identity
	end,
	Mass = function(self)
		local s = self.Size
		return s.X * s.Y * s.Z * 0.7
	end,
	AssemblyMass = function(self)
		return self.Mass
	end,
	BrickColor = function(self)
		return BrickColor.new("Medium stone grey")
	end,
	Touched = signalGetter("touched"),
	TouchEnded = signalGetter("touchEnded"),
}
local function moveWelded(self, newCFrame)
	-- Welded, unanchored parts follow their assembly root (WeldConstraints
	-- keep the relative offset they had when created).
	local i = internal(self)
	local old = i.props.CFrame or CFrame.identity
	i.props.CFrame = newCFrame
	if i.weldedTo then
		for other, offset in pairs(i.weldedTo) do
			local oi = internal(other)
			if not oi.props.Anchored and not oi.movingWithAssembly then
				oi.movingWithAssembly = true
				moveWelded(other, newCFrame * offset)
				oi.movingWithAssembly = nil
			end
		end
	end
	return old
end
Setters.BasePart = {
	CFrame = function(self, value)
		assert(rtypeof(value) == "CFrame", "CFrame expected")
		moveWelded(self, value)
	end,
	Position = function(self, value)
		assert(rtypeof(value) == "Vector3", "Vector3 expected")
		local c = internal(self).props.CFrame or CFrame.identity
		moveWelded(self, CFrame.new(value) * c.Rotation)
	end,
	Orientation = function(self, value)
		local p = self.Position
		moveWelded(self, CFrame.new(p) * CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z)))
	end,
	Rotation = function(self, value)
		local p = self.Position
		moveWelded(self, CFrame.new(p) * CFrame.Angles(math.rad(value.X), math.rad(value.Y), math.rad(value.Z)))
	end,
	Size = function(self, value)
		assert(rtypeof(value) == "Vector3", "Vector3 expected")
		local i = internal(self)
		local minimum = 0.001
		i.props.Size = v3(math.max(value.X, minimum), math.max(value.Y, minimum), math.max(value.Z, minimum))
	end,
	BrickColor = function(self, value)
		internal(self).props.Color = value.Color
	end,
	Material = function(self, value)
		assert(rtypeof(value) == "EnumItem" and value.EnumType.Name == "Material", "Material enum expected")
		internal(self).props.Material = value
	end,
	Color = function(self, value)
		assert(rtypeof(value) == "Color3", "Color3 expected")
		internal(self).props.Color = value
	end,
}
Setters.MeshPart = {
	MeshId = function()
		error("The current thread cannot write 'MeshId' (lacking capability NotAccessible)", 3)
	end,
}
Methods.BasePart = {
	GetMass = function(self)
		return self.Mass
	end,
	GetTouchingParts = function()
		return {}
	end,
	SetNetworkOwner = function() end,
	GetNetworkOwner = function()
		return nil
	end,
	CanSetNetworkOwnership = function()
		return false
	end,
	GetConnectedParts = function(self)
		return { self }
	end,
	ApplyImpulse = function() end,
	GetRootPart = function(self)
		return self
	end,
	GetPivot = function(self)
		return self.CFrame * self.PivotOffset
	end,
	PivotTo = function(self, target)
		self.CFrame = target * self.PivotOffset:Inverse()
	end,
	BreakJoints = function() end,
}

-- Models -----------------------------------------------------------------

local function partsOf(inst)
	local out = {}
	if inst:IsA("BasePart") then
		table.insert(out, inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function boundingBox(parts)
	local minV = v3(math.huge, math.huge, math.huge)
	local maxV = v3(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		local c, s = p.CFrame, p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = c * v3(s.X * sx, s.Y * sy, s.Z * sz)
					minV = minV:Min(corner)
					maxV = maxV:Max(corner)
				end
			end
		end
	end
	if minV.X == math.huge then
		return CFrame.identity, v3(0, 0, 0)
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end
Shim.boundingBox = boundingBox

local function modelPivot(self)
	local i = internal(self)
	local primary = i.props.PrimaryPart
	if primary then
		return primary.CFrame * (i.props.PrimaryPartPivotOffset or CFrame.identity)
	end
	if i.props.WorldPivot then
		return i.props.WorldPivot
	end
	local c = boundingBox(partsOf(self))
	return c
end

Getters.Model = {
	WorldPivot = modelPivot,
}
Setters.Model = {
	WorldPivot = function(self, value)
		internal(self).props.WorldPivot = value
	end,
}
Methods.Model = {
	GetPivot = modelPivot,
	PivotTo = function(self, target)
		local current = modelPivot(self)
		local delta = target * current:Inverse()
		local parts = partsOf(self)
		local oldCFrames = {}
		for _, p in ipairs(parts) do
			oldCFrames[p] = p.CFrame
		end
		for _, p in ipairs(parts) do
			internal(p).props.CFrame = delta * oldCFrames[p]
		end
		local i = internal(self)
		if not i.props.PrimaryPart then
			i.props.WorldPivot = target
		end
	end,
	GetBoundingBox = function(self)
		return boundingBox(partsOf(self))
	end,
	GetExtentsSize = function(self)
		local _, size = boundingBox(partsOf(self))
		return size
	end,
	SetPrimaryPartCFrame = function(self, target)
		self:PivotTo(target)
	end,
	GetPrimaryPartCFrame = function(self)
		return self.PrimaryPart and self.PrimaryPart.CFrame
	end,
	MoveTo = function(self, position)
		local pivot = modelPivot(self)
		self:PivotTo(pivot.Rotation + position)
	end,
	TranslateBy = function(self, delta)
		self:PivotTo(modelPivot(self) + delta)
	end,
	ScaleTo = function() end,
	GetScale = function()
		return 1
	end,
}

-- Joints -------------------------------------------------------------------

local function linkWeld(self)
	local i = internal(self)
	local a, b = i.props.Part0, i.props.Part1
	if not a or not b or not i.parent then
		return
	end
	local ai, bi = internal(a), internal(b)
	ai.weldedTo = ai.weldedTo or {}
	bi.weldedTo = bi.weldedTo or {}
	ai.weldedTo[b] = a.CFrame:Inverse() * b.CFrame
	bi.weldedTo[a] = b.CFrame:Inverse() * a.CFrame
end
Setters.WeldConstraint = {
	Part0 = function(self, v)
		internal(self).props.Part0 = v
		linkWeld(self)
	end,
	Part1 = function(self, v)
		internal(self).props.Part1 = v
		linkWeld(self)
	end,
}
Setters.JointInstance = Setters.WeldConstraint

-- Events -------------------------------------------------------------------

Getters.BindableEvent = {
	Event = signalGetter("event"),
}
Methods.BindableEvent = {
	Fire = function(self, ...)
		fireSignal(self.Event, ...)
	end,
}
Getters.BindableFunction = {}
Methods.BindableFunction = {
	Invoke = function(self, ...)
		local cb = internal(self).props.OnInvoke
		if cb then
			return cb(...)
		end
		return nil
	end,
}

-- Every RemoteEvent records what the server sends, so a headless run can
-- act as the client and inspect exactly what a real client would receive.
Shim.remoteLog = {} :: { { remote: string, player: any, args: { any } } }
Shim.clientHandlers = {} :: { [string]: (player: any, ...any) -> () }
Getters.RemoteEvent = {
	OnServerEvent = signalGetter("onServerEvent"),
	OnClientEvent = signalGetter("onClientEvent"),
}
Methods.RemoteEvent = {
	FireClient = function(self, player, ...)
		if rtypeof(player) ~= "Instance" or not player:IsA("Player") then
			error("FireClient: player argument must be a Player", 2)
		end
		local args = table.pack(...)
		table.insert(Shim.remoteLog, { remote = self.Name, player = player, args = args })
		local handler = Shim.clientHandlers[self.Name]
		if handler then
			handler(player, table.unpack(args, 1, args.n))
		end
		fireSignal(self.OnClientEvent, ...)
	end,
	FireAllClients = function(self, ...)
		local players = Shim.players or {}
		for _, player in ipairs(players) do
			self:FireClient(player, ...)
		end
	end,
	FireServer = function(self, ...)
		local player = Shim.localPlayer
		fireSignal(self.OnServerEvent, player, ...)
	end,
}

-- Sounds / animation -----------------------------------------------------------

Methods.Sound = {
	Play = function(self)
		internal(self).props.Playing = true
	end,
	Stop = function(self)
		internal(self).props.Playing = false
	end,
	Pause = function(self)
		internal(self).props.Playing = false
	end,
	Resume = function(self)
		internal(self).props.Playing = true
	end,
}
Getters.Sound = {
	Ended = signalGetter("ended"),
	Loaded = signalGetter("loaded"),
}

local AnimationTrackMT = {}
AnimationTrackMT.__index = AnimationTrackMT
function AnimationTrackMT:Play()
	self.IsPlaying = true
end
function AnimationTrackMT:Stop()
	self.IsPlaying = false
end
function AnimationTrackMT:AdjustSpeed() end
function AnimationTrackMT:AdjustWeight() end
Methods.Animator = {
	LoadAnimation = function(_, animation)
		assert(rtypeof(animation) == "Instance" and animation:IsA("Animation"), "Animation expected")
		return setmetatable({ Animation = animation, Looped = false, IsPlaying = false, Priority = Enum.AnimationPriority.Core, Stopped = newSignal(true) }, AnimationTrackMT)
	end,
	GetPlayingAnimationTracks = function()
		return {}
	end,
}
Methods.Humanoid = {
	LoadAnimation = Methods.Animator.LoadAnimation,
	SetStateEnabled = function() end,
	GetState = function()
		return Enum.HumanoidStateType.Running
	end,
	ChangeState = function() end,
	MoveTo = function() end,
	Move = function() end,
	TakeDamage = function(self, amount)
		self.Health -= amount
	end,
	ApplyDescription = function() end,
	GetAppliedDescription = function()
		return newInstance("HumanoidDescription")
	end,
	UnequipTools = function() end,
	GetPlayingAnimationTracks = function()
		return {}
	end,
}
Getters.Humanoid = {
	Died = signalGetter("died"),
	Running = signalGetter("running"),
	StateChanged = signalGetter("stateChanged"),
	MoveToFinished = signalGetter("moveToFinished"),
	RootPart = function(self)
		local model = internal(self).parent
		return model and model:FindFirstChild("HumanoidRootPart")
	end,
}

-- GUI ----------------------------------------------------------------------

local function textSize(text: string, size: number)
	return v2(#text * size * 0.5, size)
end
Getters.GuiButton = {
	Activated = signalGetter("activated"),
	MouseButton1Click = signalGetter("mouseButton1Click"),
	MouseButton1Down = signalGetter("mouseButton1Down"),
	MouseEnter = signalGetter("mouseEnter"),
	MouseLeave = signalGetter("mouseLeave"),
	SelectionGained = signalGetter("selectionGained"),
	SelectionLost = signalGetter("selectionLost"),
	InputBegan = signalGetter("inputBegan"),
	InputEnded = signalGetter("inputEnded"),
	TextBounds = function(self)
		local i = internal(self)
		return textSize(i.props.Text or "", i.props.TextSize or 14)
	end,
}
Getters.GuiObject = {
	MouseEnter = signalGetter("mouseEnter"),
	MouseLeave = signalGetter("mouseLeave"),
	InputBegan = signalGetter("inputBegan"),
	InputEnded = signalGetter("inputEnded"),
	InputChanged = signalGetter("inputChanged"),
	SelectionGained = signalGetter("selectionGained"),
	SelectionLost = signalGetter("selectionLost"),
}
Getters.TextLabel = {
	TextBounds = function(self)
		local i = internal(self)
		return textSize(i.props.Text or "", i.props.TextSize or 14)
	end,
	ContentText = function(self)
		local text = internal(self).props.Text or ""
		return (text:gsub("<[^>]->", ""))
	end,
}
Getters.TextBox = {
	FocusLost = signalGetter("focusLost"),
}
Getters.UIListLayout = {
	AbsoluteContentSize = function(self)
		local parent = internal(self).parent
		local total = 0
		if parent then
			for _, c in ipairs(parent:GetChildren()) do
				if c:IsA("GuiObject") then
					local s = c.Size
					total += s.Y.Offset
				end
			end
		end
		return v2(0, total)
	end,
}

-- Tween ----------------------------------------------------------------------

local TweenMT = { [TYPE_KEY] = "Instance" }
local tweenMethods = {}
TweenMT.__index = function(self, key)
	if tweenMethods[key] then
		return tweenMethods[key]
	end
	return rawget(self, "_" .. key)
end
function tweenMethods:Play()
	local token = {}
	rawset(self, "_token", token)
	rawset(self, "_PlaybackState", Enum.PlaybackState.Playing)
	local info = rawget(self, "_TweenInfo")
	local instance = rawget(self, "_Instance")
	local goals = rawget(self, "_goals")
	task.delay((info.Time or 0) + (info.DelayTime or 0), function()
		if rawget(self, "_token") ~= token then
			return
		end
		if rtypeof(instance) == "Instance" and internal(instance).destroyed then
			return
		end
		for k, v in pairs(goals) do
			instance[k] = v
		end
		rawset(self, "_PlaybackState", Enum.PlaybackState.Completed)
		fireSignal(rawget(self, "_Completed"), Enum.PlaybackState.Completed)
	end)
end
function tweenMethods:Cancel()
	rawset(self, "_token", nil)
	rawset(self, "_PlaybackState", Enum.PlaybackState.Cancelled)
end
function tweenMethods:Pause()
	rawset(self, "_token", nil)
end
function tweenMethods:Destroy()
	rawset(self, "_token", nil)
end
function tweenMethods:IsA(name)
	return name == "Tween" or name == "TweenBase" or name == "Instance"
end

-- R15 rig generation -------------------------------------------------------------

local R15_PARTS = {
	{ "HumanoidRootPart", v3(2, 2, 1), v3(0, 0, 0) },
	{ "LowerTorso", v3(2, 0.4, 1), v3(0, -0.2, 0) },
	{ "UpperTorso", v3(2, 1.6, 1), v3(0, 0.8, 0) },
	{ "Head", v3(1.2, 1.2, 1.2), v3(0, 2.2, 0) },
	{ "LeftUpperArm", v3(1, 1.2, 1), v3(-1.5, 1, 0) },
	{ "LeftLowerArm", v3(1, 1, 1), v3(-1.5, 0, 0) },
	{ "LeftHand", v3(1, 0.3, 1), v3(-1.5, -0.65, 0) },
	{ "RightUpperArm", v3(1, 1.2, 1), v3(1.5, 1, 0) },
	{ "RightLowerArm", v3(1, 1, 1), v3(1.5, 0, 0) },
	{ "RightHand", v3(1, 0.3, 1), v3(1.5, -0.65, 0) },
	{ "LeftUpperLeg", v3(1, 1.2, 1), v3(-0.5, -1, 0) },
	{ "LeftLowerLeg", v3(1, 1.2, 1), v3(-0.5, -2.1, 0) },
	{ "LeftFoot", v3(1, 0.3, 1), v3(-0.5, -2.85, 0) },
	{ "RightUpperLeg", v3(1, 1.2, 1), v3(0.5, -1, 0) },
	{ "RightLowerLeg", v3(1, 1.2, 1), v3(0.5, -2.1, 0) },
	{ "RightFoot", v3(1, 0.3, 1), v3(0.5, -2.85, 0) },
}

local function buildRig(description)
	local model = newInstance("Model", "Character")
	local humanoid = newInstance("Humanoid", "Humanoid")
	for _, spec in ipairs(R15_PARTS) do
		local p = newInstance(if spec[1] == "HumanoidRootPart" then "Part" else "MeshPart", spec[1])
		p.Size = spec[2]
		p.CFrame = CFrame.new(spec[3] + v3(0, 3, 0))
		if spec[1] == "HumanoidRootPart" then
			p.Transparency = 1
		end
		setParent(p, model)
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	for _, p in ipairs(model:GetChildren()) do
		if p ~= hrp then
			local weld = newInstance("Motor6D", "Joint")
			weld.Part0 = hrp
			weld.Part1 = p
			setParent(weld, p)
		end
	end
	internal(model).props.PrimaryPart = hrp
	local head = model:FindFirstChild("Head")
	local face = newInstance("Decal", "face")
	setParent(face, head)
	setParent(humanoid, model)
	setParent(newInstance("Animator", "Animator"), humanoid)
	setParent(newInstance("BodyColors", "Body Colors"), model)
	setParent(newInstance("LocalScript", "Animate"), model)
	if description then
		local hair = description.HairAccessory
		if hair and hair ~= "" then
			for id in string.gmatch(hair, "[^,]+") do
				local accessory = newInstance("Accessory", `Hair_{id}`)
				local handle = newInstance("MeshPart", "Handle")
				handle.Size = v3(1.4, 1.2, 1.4)
				handle.CFrame = head.CFrame * CFrame.new(0, 0.4, 0)
				setParent(handle, accessory)
				setParent(accessory, model)
				local weld = newInstance("Weld", "AccessoryWeld")
				weld.Part0 = handle
				weld.Part1 = head
				setParent(weld, handle)
			end
		end
		for _, field in ipairs({ "HatAccessory", "FaceAccessory", "NeckAccessory", "BackAccessory", "WaistAccessory", "FrontAccessory", "ShouldersAccessory" }) do
			local ids = description[field]
			if ids and ids ~= "" then
				for id in string.gmatch(ids, "[^,]+") do
					local accessory = newInstance("Accessory", `{field}_{id}`)
					local handle = newInstance("MeshPart", "Handle")
					handle.Size = v3(1, 1, 1)
					handle.CFrame = head.CFrame
					setParent(handle, accessory)
					setParent(accessory, model)
				end
			end
		end
		if (description.Shirt or 0) ~= 0 then
			local s = newInstance("Shirt", "Shirt")
			s.ShirtTemplate = `rbxassetid://{description.Shirt}`
			setParent(s, model)
		end
		if (description.Pants or 0) ~= 0 then
			local s = newInstance("Pants", "Pants")
			s.PantsTemplate = `rbxassetid://{description.Pants}`
			setParent(s, model)
		end
	end
	return model
end
Shim.buildRig = buildRig

-- Services -------------------------------------------------------------------

local services: { [string]: any } = {}
local game = newInstance("DataModel", "Game")
internal(game).props.PlaceId = 0
internal(game).props.GameId = 0
internal(game).props.JobId = "headless"
internal(game).props.CreatorId = 0
local workspace = newInstance("Workspace", "Workspace")
setParent(workspace, game)
services.Workspace = workspace
internal(workspace).props.Gravity = 196.2
internal(workspace).props.DistributedGameTime = 0

local camera = newInstance("Camera", "Camera")
setParent(camera, workspace)
internal(workspace).props.CurrentCamera = camera

local function service(className: string)
	local existing = services[className]
	if existing then
		return existing
	end
	if not SUPER[className] then
		error(`'{className}' is not a valid Service name`, 3)
	end
	local s = newInstance(className, className)
	setParent(s, game)
	services[className] = s
	return s
end

Methods.DataModel = {
	GetService = function(_, className)
		return service(className)
	end,
	FindService = function(_, className)
		return services[className]
	end,
	BindToClose = function() end,
	IsLoaded = function()
		return true
	end,
}
Getters.DataModel = {
	Loaded = signalGetter("loaded"),
	Workspace = function()
		return workspace
	end,
}

-- Workspace ray casts against part boxes (oriented), honouring CanQuery and
-- RaycastParams filters.
local function rayBox(origin, direction, part)
	local c = part.CFrame
	local half = part.Size / 2
	local o = c:PointToObjectSpace(origin)
	local d = c:VectorToObjectSpace(direction)
	local tmin, tmax = -math.huge, math.huge
	local normalAxis, normalSign = nil, 0
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local oa, da, h = o[axis], d[axis], half[axis]
		if math.abs(da) < 1e-12 then
			if oa < -h or oa > h then
				return nil
			end
		else
			local t1 = (-h - oa) / da
			local t2 = (h - oa) / da
			local sign = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				sign = 1
			end
			if t1 > tmin then
				tmin = t1
				normalAxis = axis
				normalSign = sign
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	if tmax < 0 or tmin > 1 then
		return nil
	end
	local t = math.max(tmin, 0)
	local localNormal = v3(0, 0, 0)
	if normalAxis == "X" then
		localNormal = v3(normalSign, 0, 0)
	elseif normalAxis == "Y" then
		localNormal = v3(0, normalSign, 0)
	elseif normalAxis == "Z" then
		localNormal = v3(0, 0, normalSign)
	end
	return t, c:VectorToWorldSpace(localNormal)
end

local makeRaycastResult = valueType("RaycastResult", { "Instance", "Position", "Normal", "Distance", "Material" })
local RaycastParamsMT = { [TYPE_KEY] = "RaycastParams" }
RaycastParamsMT.__index = RaycastParamsMT
function RaycastParamsMT:AddToFilter(inst)
	table.insert(self.FilterDescendantsInstances, inst)
end
local RaycastParams = {
	new = function()
		return setmetatable({
			FilterType = Enum.RaycastFilterType.Exclude,
			FilterDescendantsInstances = {},
			IgnoreWater = false,
			CollisionGroup = "Default",
			RespectCanCollide = false,
		}, RaycastParamsMT)
	end,
}
local function filtered(part, params)
	if not params then
		return false
	end
	local list = params.FilterDescendantsInstances or {}
	local inList = false
	for _, inst in ipairs(list) do
		if part == inst or part:IsDescendantOf(inst) then
			inList = true
			break
		end
	end
	if params.FilterType == Enum.RaycastFilterType.Include or params.FilterType == Enum.RaycastFilterType.Whitelist then
		return not inList
	end
	return inList
end
Methods.WorldRoot = {
	Raycast = function(self, origin, direction, params)
		local best, bestT, bestNormal = nil, math.huge, nil
		for _, d in ipairs(self:GetDescendants()) do
			if d:IsA("BasePart") and d.CanQuery ~= false and not filtered(d, params) then
				if not (params and params.RespectCanCollide and not d.CanCollide) then
					local t, normal = rayBox(origin, direction, d)
					if t and t < bestT then
						best, bestT, bestNormal = d, t, normal
					end
				end
			end
		end
		if not best then
			return nil
		end
		local hit = origin + direction * bestT
		return makeRaycastResult(best, hit, bestNormal, (direction * bestT).Magnitude, best.Material)
	end,
	GetPartBoundsInBox = function(self, boxCFrame, size)
		local out = {}
		local half = size / 2
		for _, d in ipairs(self:GetDescendants()) do
			if d:IsA("BasePart") then
				local p = boxCFrame:PointToObjectSpace(d.Position)
				if math.abs(p.X) <= half.X + d.Size.Magnitude / 2 and math.abs(p.Y) <= half.Y + d.Size.Magnitude / 2 and math.abs(p.Z) <= half.Z + d.Size.Magnitude / 2 then
					table.insert(out, d)
				end
			end
		end
		return out
	end,
	GetPartsInPart = function()
		return {}
	end,
	Blockcast = function()
		return nil
	end,
	Spherecast = function()
		return nil
	end,
	BulkMoveTo = function(_, parts, cframes)
		for idx, p in ipairs(parts) do
			p.CFrame = cframes[idx]
		end
	end,
}
Methods.Workspace = {
	GetServerTimeNow = function()
		return Scheduler.now
	end,
	GetRealPhysicsFPS = function()
		return 60
	end,
}

local playersList: { any } = {}
Shim.players = playersList
Methods.Players = {
	GetPlayers = function()
		return table.clone(playersList)
	end,
	GetPlayerFromCharacter = function(_, character)
		for _, p in ipairs(playersList) do
			if p.Character == character then
				return p
			end
		end
		return nil
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in ipairs(playersList) do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
	CreateHumanoidModelFromDescription = function(_, description, rigType)
		assert(rtypeof(description) == "Instance" and description:IsA("HumanoidDescription"), "HumanoidDescription expected")
		return buildRig(description)
	end,
	GetUserThumbnailAsync = function()
		return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true
	end,
	GetHumanoidDescriptionFromUserId = function()
		return newInstance("HumanoidDescription")
	end,
}
Getters.Players = {
	PlayerAdded = signalGetter("playerAdded"),
	PlayerRemoving = signalGetter("playerRemoving"),
	LocalPlayer = function()
		return Shim.localPlayer
	end,
}

Methods.CollectionService = {
	AddTag = function(_, inst, tag)
		inst:AddTag(tag)
	end,
	RemoveTag = function(_, inst, tag)
		inst:RemoveTag(tag)
	end,
	HasTag = function(_, inst, tag)
		return inst:HasTag(tag)
	end,
	GetTags = function(_, inst)
		return inst:GetTags()
	end,
	GetTagged = function(_, tag)
		local out = {}
		for inst in pairs(allTagged[tag] or {}) do
			if not internal(inst).destroyed then
				table.insert(out, inst)
			end
		end
		table.sort(out, function(a, b)
			return internal(a).id < internal(b).id
		end)
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		tagAddedSignals[tag] = tagAddedSignals[tag] or newSignal(true)
		return tagAddedSignals[tag]
	end,
	GetInstanceRemovedSignal = function(_, tag)
		tagRemovedSignals[tag] = tagRemovedSignals[tag] or newSignal(true)
		return tagRemovedSignals[tag]
	end,
}

Shim.isServer = true
Methods.RunService = {
	IsServer = function()
		return Shim.isServer
	end,
	IsClient = function()
		return not Shim.isServer
	end,
	IsStudio = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
	IsRunMode = function()
		return false
	end,
	IsEdit = function()
		return false
	end,
	BindToRenderStep = function(_, name, priority, fn)
		Shim.renderSteps = Shim.renderSteps or {}
		Shim.renderSteps[name] = fn
	end,
	UnbindFromRenderStep = function(_, name)
		if Shim.renderSteps then
			Shim.renderSteps[name] = nil
		end
	end,
}
local heartbeatSignal = newSignal(false)
local renderSteppedSignal = newSignal(false)
local steppedSignal = newSignal(false)
Getters.RunService = {
	Heartbeat = function()
		return heartbeatSignal
	end,
	RenderStepped = function()
		return renderSteppedSignal
	end,
	Stepped = function()
		return steppedSignal
	end,
	PreSimulation = function()
		return steppedSignal
	end,
	PostSimulation = function()
		return heartbeatSignal
	end,
	PreRender = function()
		return renderSteppedSignal
	end,
}
Scheduler.heartbeat = function(dt)
	fireSignal(steppedSignal, Scheduler.now, dt)
	fireSignal(heartbeatSignal, dt)
	if not Shim.isServer then
		fireSignal(renderSteppedSignal, dt)
		if Shim.renderSteps then
			for _, fn in pairs(Shim.renderSteps) do
				task.spawn(fn, dt)
			end
		end
	end
end

local EASING = {
	Linear = function(t)
		return t
	end,
	Quad = function(t)
		return t * t
	end,
	Cubic = function(t)
		return t * t * t
	end,
	Quart = function(t)
		return t ^ 4
	end,
	Quint = function(t)
		return t ^ 5
	end,
	Sine = function(t)
		return 1 - math.cos(t * math.pi / 2)
	end,
	Exponential = function(t)
		return if t == 0 then 0 else 2 ^ (10 * t - 10)
	end,
}
Methods.TweenService = {
	Create = function(_, instance, info, goals)
		assert(rtypeof(info) == "TweenInfo", "TweenInfo expected")
		for k, v in pairs(goals) do
			-- Validate the property exists (reading throws if not).
			local _ = instance[k]
			assert(v ~= nil, `tween goal {k} is nil`)
		end
		return setmetatable({
			_Instance = instance,
			_TweenInfo = info,
			_goals = goals,
			_Completed = newSignal(true),
			_PlaybackState = Enum.PlaybackState.Begin,
		}, TweenMT)
	end,
	GetValue = function(_, alpha, style, direction)
		local name = if style then style.Name else "Quad"
		local f = EASING[name] or EASING.Quad
		local dir = if direction then direction.Name else "Out"
		if dir == "In" then
			return f(alpha)
		elseif dir == "Out" then
			return 1 - f(1 - alpha)
		end
		if alpha < 0.5 then
			return f(alpha * 2) / 2
		end
		return 1 - f((1 - alpha) * 2) / 2
	end,
}

Methods.HttpService = {
	JSONEncode = function(_, value)
		local function encode(v)
			local t = type(v)
			if t == "table" then
				if #v > 0 or next(v) == nil then
					local out = {}
					for _, x in ipairs(v) do
						table.insert(out, encode(x))
					end
					return "[" .. table.concat(out, ",") .. "]"
				end
				local out = {}
				for k, x in pairs(v) do
					table.insert(out, string.format("%q:%s", tostring(k), encode(x)))
				end
				return "{" .. table.concat(out, ",") .. "}"
			elseif t == "string" then
				return string.format("%q", v)
			end
			return tostring(v)
		end
		return encode(value)
	end,
	GenerateGUID = function()
		instanceCount += 1
		return `guid-{instanceCount}`
	end,
}

Methods.TextService = {
	GetTextSize = function(_, text, size)
		return textSize(text, size)
	end,
	GetTextBoundsAsync = function(_, params)
		return textSize(params.Text or "", params.Size or 14)
	end,
}

Methods.Debris = {
	AddItem = function(_, inst, lifetime)
		task.delay(lifetime or 10, function()
			inst:Destroy()
		end)
	end,
}

Methods.ContextActionService = {
	BindAction = function(_, name, fn, createTouch, ...)
		Shim.boundActions = Shim.boundActions or {}
		Shim.boundActions[name] = { fn = fn, keys = { ... } }
	end,
	BindActionAtPriority = function(_, name, fn, createTouch, priority, ...)
		Shim.boundActions = Shim.boundActions or {}
		Shim.boundActions[name] = { fn = fn, keys = { ... } }
	end,
	UnbindAction = function(_, name)
		if Shim.boundActions then
			Shim.boundActions[name] = nil
		end
	end,
	SetTitle = function() end,
	SetImage = function() end,
	SetPosition = function() end,
	GetButton = function()
		return nil
	end,
}
Methods.UserInputService = {
	GetLastInputType = function()
		return Enum.UserInputType.Keyboard
	end,
	IsKeyDown = function()
		return false
	end,
	GetGamepadConnected = function()
		return false
	end,
	GetConnectedGamepads = function()
		return {}
	end,
	GetMouseLocation = function()
		return v2(0, 0)
	end,
	GetFocusedTextBox = function()
		return nil
	end,
}
Getters.UserInputService = {
	InputBegan = signalGetter("inputBegan"),
	InputEnded = signalGetter("inputEnded"),
	InputChanged = signalGetter("inputChanged"),
	LastInputTypeChanged = signalGetter("lastInputTypeChanged"),
	GamepadConnected = signalGetter("gamepadConnected"),
	GamepadDisconnected = signalGetter("gamepadDisconnected"),
	TouchEnabled = function()
		return false
	end,
	KeyboardEnabled = function()
		return true
	end,
	GamepadEnabled = function()
		return false
	end,
	MouseEnabled = function()
		return true
	end,
	PreferredInput = function()
		return Enum.PreferredInput.KeyboardAndMouse
	end,
}
Methods.GuiService = {
	GetGuiInset = function()
		return v2(0, 58), v2(0, 0)
	end,
	IsTenFootInterface = function()
		return false
	end,
	Select = function() end,
}
Getters.GuiService = {
	MenuOpened = signalGetter("menuOpened"),
	MenuClosed = signalGetter("menuClosed"),
	TopbarInset = function()
		return makeRect(v2(0, 0), v2(1280, 58))
	end,
}
Methods.SoundService = {
	PlayLocalSound = function() end,
	SetListener = function() end,
}
Methods.MarketplaceService = {
	GetProductInfo = function(_, id)
		error(`GetProductInfo({id}) is not available headless (no network)`, 2)
	end,
}
Methods.InsertService = {
	LoadAsset = function(_, id)
		error(`LoadAsset({id}) is not available headless (no network)`, 2)
	end,
}
Methods.ContentProvider = {
	PreloadAsync = function() end,
}

--------------------------------------------------------------------------
-- Instance.new
--------------------------------------------------------------------------

local NOT_CREATABLE = {
	Workspace = true, DataModel = true, Players = true, Lighting = true, ReplicatedStorage = true,
	ServerStorage = true, ServerScriptService = true, BasePart = true, GuiObject = true, Instance = true,
	PVInstance = true, LuaSourceContainer = true, BaseScript = true, PostEffect = true, Light = true,
}
local unknownClasses: { [string]: boolean } = {}
Shim.unknownClasses = unknownClasses

local Instance = {
	new = function(className: string, parent: any?)
		if NOT_CREATABLE[className] then
			error(`Unable to create an Instance of type "{className}"`, 2)
		end
		if not SUPER[className] then
			unknownClasses[className] = true
			shimWarn(`Instance.new: class "{className}" is not modelled by the shim`)
		end
		local inst = newInstance(className)
		if className == "Part" or className == "SpawnLocation" or className == "Seat" then
			internal(inst).props.Size = v3(4, 1, 2)
		end
		if parent then
			setParent(inst, parent)
		end
		return inst
	end,
	fromExisting = function(inst)
		return inst:Clone()
	end,
}

--------------------------------------------------------------------------
-- Players / characters (headless stand-ins for real clients)
--------------------------------------------------------------------------

local nextUserId = 1000
function Shim.addPlayer(name: string)
	nextUserId += 1
	local player = newInstance("Player", name)
	internal(player).props.UserId = nextUserId
	internal(player).props.DisplayName = name
	local gui = newInstance("PlayerGui", "PlayerGui")
	setParent(gui, player)
	setParent(newInstance("Backpack", "Backpack"), player)
	setParent(newInstance("PlayerScripts", "PlayerScripts"), player)
	setParent(player, service("Players"))
	table.insert(playersList, player)
	fireSignal(service("Players").PlayerAdded, player)
	return player
end

Methods.Player = {
	LoadCharacter = function(self)
		local old = internal(self).props.Character
		if old then
			old:Destroy()
		end
		local rig = buildRig(nil)
		rig.Name = self.Name
		local spawnPad = nil
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("SpawnLocation") then
				spawnPad = d
				break
			end
		end
		local at = if spawnPad then spawnPad.Position + v3(0, 3, 0) else v3(0, 5, 0)
		rig:PivotTo(CFrame.new(at))
		internal(self).props.Character = rig
		setParent(rig, workspace)
		local s = internal(self).characterAdded
		if s then
			fireSignal(s, rig)
		end
	end,
	Kick = function() end,
	GetMouse = function()
		return { Hit = CFrame.identity, Target = nil, X = 0, Y = 0 }
	end,
	IsInGroup = function()
		return false
	end,
	GetRankInGroup = function()
		return 0
	end,
}
Getters.Player = {
	CharacterAdded = signalGetter("characterAdded"),
	CharacterRemoving = signalGetter("characterRemoving"),
	Chatted = signalGetter("chatted"),
}

--------------------------------------------------------------------------
-- Module loading
--------------------------------------------------------------------------

local env: { [string]: any } = {}
local moduleCache: { [any]: any } = {}
local moduleLoading: { [any]: boolean } = {}
Shim.sources = {} :: { [any]: { source: string, chunk: string } }

local function runChunk(inst, extra: { [string]: any }?)
	local spec = Shim.sources[inst]
	if not spec then
		error(`no source registered for {getFullName(inst)}`, 3)
	end
	local fn, compileErr = loadstring(spec.source, "=" .. spec.chunk)
	if not fn then
		error(`compile error in {spec.chunk}: {compileErr}`, 0)
	end
	local chunkEnv = setmetatable({ script = inst }, { __index = env, __newindex = env })
	setfenv(fn, chunkEnv)
	return fn
end

local function rrequire(target)
	if rtypeof(target) ~= "Instance" then
		error(`require expects a ModuleScript instance (got {rtypeof(target)})`, 2)
	end
	if not target:IsA("ModuleScript") then
		error(`require: {getFullName(target)} is not a ModuleScript`, 2)
	end
	if moduleCache[target] ~= nil then
		return moduleCache[target]
	end
	if moduleLoading[target] then
		error(`Recursive require of {getFullName(target)}`, 2)
	end
	moduleLoading[target] = true
	local fn = runChunk(target)
	local results = table.pack(fn())
	moduleLoading[target] = nil
	if results.n ~= 1 then
		error(`Module code did not return exactly one value: {getFullName(target)}`, 2)
	end
	moduleCache[target] = results[1]
	return results[1]
end
Shim.require = rrequire

function Shim.registerSource(inst, source: string, chunk: string)
	Shim.sources[inst] = { source = source, chunk = chunk }
end

-- Run a Script/LocalScript's source in its own thread (like the engine).
function Shim.runScript(inst)
	local fn = runChunk(inst)
	return task.spawn(fn)
end

function Shim.resetModuleCache()
	table.clear(moduleCache)
end

--------------------------------------------------------------------------
-- Environment
--------------------------------------------------------------------------

env.game = game
env.Game = game
env.workspace = workspace
env.Workspace = workspace
env.Instance = Instance
env.Vector3 = Vector3
env.Vector2 = Vector2
env.CFrame = CFrame
env.Color3 = Color3
env.UDim = UDim
env.UDim2 = UDim2
env.TweenInfo = TweenInfo
env.NumberRange = NumberRange
env.NumberSequence = NumberSequence
env.NumberSequenceKeypoint = NumberSequenceKeypoint
env.ColorSequence = ColorSequence
env.ColorSequenceKeypoint = ColorSequenceKeypoint
env.Rect = Rect
env.PhysicalProperties = PhysicalProperties
env.RaycastParams = RaycastParams
env.BrickColor = BrickColor
env.Random = Random
env.Font = Font
env.Enum = Enum
env.task = task
env.typeof = rtypeof
env.require = rrequire
env.warn = shimWarn
env.print = shimPrint
env.tick = function()
	return Scheduler.now
end
env.time = function()
	return Scheduler.now
end
env.elapsedTime = env.time
env.wait = task.wait
env.delay = task.delay
env.spawn = task.defer
env.shared = {}
env.settings = function()
	return {}
end
env.os = setmetatable({
	-- Virtual: animation/typewriter timing follows the scheduler's clock,
	-- so a headless run is deterministic and fast.
	clock = function()
		return Scheduler.now
	end,
	time = function()
		return 1700000000 + math.floor(Scheduler.now)
	end,
	date = os.date,
	difftime = os.difftime,
}, { __index = os })
-- Everything else (math, string, table, ...) comes from the real globals.
setmetatable(env, { __index = getfenv(0) })

Shim.env = env
Shim.game = game
Shim.workspace = workspace
Shim.service = service
Shim.internal = internal
Shim.typeof = rtypeof
Shim.Vector3 = Vector3
Shim.CFrame = CFrame
Shim.Color3 = Color3
Shim.Enum = Enum
Shim.Instance = Instance
Shim.task = task

return Shim
