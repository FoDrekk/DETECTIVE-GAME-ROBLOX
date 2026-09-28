--!strict
--[[
	SessionGuard
	Phase 3 (R2): the game is single-player. The phase machine (briefing,
	investigation, case closed) is server-wide, so a second investigator in
	the same server would share -- and break -- the first one's session.

	This is a safety net, not a matchmaking rule: the place's Max Players
	should also be set to 1 when it is published, so Roblox never puts a
	second player here in the first place. When one arrives anyway, the
	bootstrap turns them away with `Config.Game.FullServerMessage`.

	Pure bookkeeping over user ids, so it can be tested without real players.
]]

local SessionGuard = {}
SessionGuard.__index = SessionGuard

export type Result = "Admitted" | "Duplicate" | "Full"

export type Guard = typeof(setmetatable(
	{} :: { limit: number, admitted: { [number]: boolean }, count: number },
	SessionGuard
))

function SessionGuard.new(limit: number): Guard
	return setmetatable({ limit = limit, admitted = {}, count = 0 }, SessionGuard)
end

-- "Duplicate" when this user is already in (PlayerAdded and the startup
-- sweep can both report the same player); "Full" when the server already
-- holds `limit` investigators.
function SessionGuard.admit(self: Guard, userId: number): Result
	if self.admitted[userId] then
		return "Duplicate"
	end
	if self.count >= self.limit then
		return "Full"
	end
	self.admitted[userId] = true
	self.count += 1
	return "Admitted"
end

-- Frees the seat. A user who was turned away was never admitted, so their
-- leaving changes nothing.
function SessionGuard.release(self: Guard, userId: number)
	if self.admitted[userId] then
		self.admitted[userId] = nil
		self.count -= 1
	end
end

return SessionGuard
