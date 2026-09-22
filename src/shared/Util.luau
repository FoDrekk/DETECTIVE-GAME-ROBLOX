--!strict
--[[
	Util
	Small shared helpers. Keep this free of game-specific logic.
]]

local Util = {}

-- Deep-freeze a table in place to protect configuration data.
function Util.deepFreeze<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	for _, value in pairs(t :: any) do
		Util.deepFreeze(value)
	end
	return table.freeze(t :: any) :: T
end

function Util.deepCopy<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t :: any) do
		out[k] = Util.deepCopy(v)
	end
	return out :: T
end

function Util.count<T>(t: { [any]: T }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function Util.now(): number
	return os.clock()
end

function Util.timestamp(): number
	return os.time()
end

return Util
