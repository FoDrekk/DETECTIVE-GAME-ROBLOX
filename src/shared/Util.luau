--!strict
--[[
	Util
	Small shared helpers. Keep this free of game-specific logic.
]]

local Util = {}

function Util.count<T>(t: { [any]: T }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function Util.timestamp(): number
	return os.time()
end

return Util
