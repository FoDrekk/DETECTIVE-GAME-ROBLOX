--!strict
--[[
	Phase 5.2: CASE-001's localisation and continuity fixes.

	Guards two things that are easy to get half right:
	  * nothing from v1's cast, firm or place survives in what a player can
	    read, in case data or in the world (signs, printouts, name tags);
	  * the night's times agree with each other: the badge log, its printed
	    copy, the lift's trip log and what Sam remembers.

	The world checks read whatever is in Workspace.Office, so they run against
	the freshly built world in the headless harness and against the baked
	place in Studio -- which is what makes them the check that a baked place
	really was patched.
]]
return function(t)
	local ServerStorage = game:GetService("ServerStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Server = ServerScriptService:WaitForChild("Server")
	local PropKit = require(Server:WaitForChild("PropKit"))
	local CaseRegistry = require(ServerStorage:WaitForChild("Config"):WaitForChild("CaseRegistry"))
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local expect = t.expect

	local caseDef = CaseRegistry.get("CASE-001") :: any

	-- Word-bounded and case-sensitive on purpose: ids such as MARA-OPEN and
	-- flags such as mara_upset are identifiers, not text a player reads.
	local BANNED = {
		"%f[%w]Reyes%f[%W]",
		"%f[%w]REYES%f[%W]",
		"%f[%w]Lane%f[%W]",
		"%f[%w]LANE%f[%W]",
		"%f[%w]Mara%f[%W]",
		"%f[%w]Okafor%f[%W]",
		"%f[%w]OKAFOR%f[%W]",
		"Mrs%.",
		"[Nn]inth floor",
		"[Cc]halk",
		"[Ll]obby camera",
		"[Ll]obby footage",
		"twenty past",
	}

	local function bannedIn(text: string): string?
		for _, pattern in ipairs(BANNED) do
			if string.find(text, pattern) then
				return pattern
			end
		end
		return nil
	end

	local function collectStrings(value: any, out: { string })
		if type(value) == "string" then
			table.insert(out, value)
		elseif type(value) == "table" then
			for _, child in pairs(value) do
				collectStrings(child, out)
			end
		end
	end

	-- "10:28 PM" style to minutes after 6 PM, so a night that crosses
	-- midnight sorts correctly.
	local function nightMinutes(hour: number, minute: number, meridiem: string): number
		local h = hour % 12
		if meridiem == "PM" then
			h += 12
		end
		if h < 12 then
			h += 24 -- after midnight
		end
		return h * 60 + minute
	end

	local function nodeText(suspectId: string, nodeId: string): string
		for _, conversation in ipairs(caseDef.conversations) do
			if conversation.suspectId == suspectId then
				return conversation.nodes[nodeId].text
			end
		end
		error(`no conversation for {suspectId}`)
	end

	local function statementText(statementId: string): string
		for _, statement in ipairs(caseDef.statements) do
			if statement.id == statementId then
				return statement.text
			end
		end
		error(`no statement {statementId}`)
	end

	local function evidenceDetails(evidenceId: string): string
		for _, evidence in ipairs(caseDef.evidence) do
			if evidence.id == evidenceId then
				return evidence.details
			end
		end
		error(`no evidence {evidenceId}`)
	end

	-- Victor's badge events from the EV-004 text.
	local function badgeEvents(): { { minutes: number, direction: string } }
		local events = {}
		for hour, minute, meridiem, direction in
			string.gmatch(evidenceDetails("EV-004"), "(%d+):(%d+) (%a%a)%s+LIM, V%.%s+(%a+)%.")
		do
			table.insert(events, { minutes = nightMinutes(tonumber(hour) :: number, tonumber(minute) :: number, meridiem), direction = direction })
		end
		return events
	end

	------------------------------------------------------------------
	-- Case data
	------------------------------------------------------------------

	t.test("nothing from v1's cast, firm or place is left in CASE-001's text", function()
		local strings: { string } = {}
		collectStrings(caseDef, strings)
		expect.truthy(#strings > 200)
		for _, text in ipairs(strings) do
			local pattern = bannedIn(text)
			if pattern then
				error(`v1 text survives ({pattern}): {string.sub(text, 1, 90)}`)
			end
		end
	end)

	t.test("the cast is the approved one, and the briefing place line is Tingkat 9", function()
		local names = {}
		for _, suspect in ipairs(caseDef.suspects) do
			names[suspect.id] = suspect.name
		end
		expect.equal(names["SUS-001"], "Meera Rozario")
		expect.equal(names["SUS-002"], "Victor Lim")
		expect.equal(names["SUS-003"], "Sam Gurung")
		expect.equal(caseDef.setting.place, "Rozario & Lim · Tingkat 9")
	end)

	t.test("the approved skin tones are applied, and the others left alone", function()
		local skin = {}
		for _, suspect in ipairs(caseDef.suspects) do
			skin[suspect.id] = suspect.appearance.skin
		end
		expect.equal(skin["SUS-001"], Color3.fromRGB(150, 102, 72))
		expect.equal(skin["SUS-003"], Color3.fromRGB(176, 130, 96))
		expect.equal(skin["SUS-002"], Color3.fromRGB(198, 152, 122))
	end)

	t.test("every dialogue line stays a short beat after the code-switching pass", function()
		for _, conversation in ipairs(caseDef.conversations) do
			for id, node in pairs(conversation.nodes) do
				if #node.text > 130 then
					error(`{id} is {#node.text} characters`)
				end
				for _, choice in ipairs(node.choices or {}) do
					expect.truthy(#choice.text <= 80)
				end
			end
		end
	end)

	t.test("the approved code-switching lines are in, and only those", function()
		expect.equal(nodeText("SUS-003", "SAM-OPEN-2"), "Sorry ah. I've been standing here half an hour. Didn't know if I'm allowed to sit down.")
		expect.equal(nodeText("SUS-003", "SAM-AGAIN"), "Still here lah. Not going anywhere, apparently.")
		expect.truthy(string.find(nodeText("SUS-003", "SAM-FOUND-2"), "kan?", 1, true))
		expect.truthy(string.find(nodeText("SUS-003", "SAM-COFFEE-1"), "No chance lah.", 1, true))
		expect.truthy(string.find(nodeText("SUS-003", "SAM-MARA-2"), "Kesian.", 1, true))
		expect.equal(nodeText("SUS-003", "SAM-BYE"), "Okay, okay. I'll be... here. Obviously.")
		expect.equal(nodeText("SUS-002", "VIC-BADGE-1"), "Aiya. Then the system's wrong, lah.")
		expect.truthy(string.find(nodeText("SUS-001", "MARA-LAST-1"), "Sayang", 1, true))
		-- Victor is polished until he cracks, and Meera rarely switches: no
		-- other line of theirs carries a Malay or Manglish particle.
		for _, conversation in ipairs(caseDef.conversations) do
			if conversation.suspectId ~= "SUS-003" then
				local allowed = if conversation.suspectId == "SUS-002" then "VIC-BADGE-1" else "MARA-LAST-1"
				for id, node in pairs(conversation.nodes) do
					if id ~= allowed then
						for _, particle in ipairs({ " lah", "Aiya", "Sayang", " kan", "Kesian", " ah." }) do
							if string.find(node.text, particle, 1, true) then
								error(`{id} carries '{particle}': not in the approved sheet`)
							end
						end
					end
				end
			end
		end
	end)

	t.test("Sam's forms of address and timings follow the localisation map", function()
		expect.truthy(string.find(nodeText("SUS-003", "SAM-FOUND-4"), "from reception", 1, true))
		expect.truthy(string.find(nodeText("SUS-003", "SAM-MARA-1"), "half twelve", 1, true))
		expect.truthy(string.find(nodeText("SUS-003", "SAM-MARA-2"), "Puan Meera", 1, true))
		expect.truthy(string.find(nodeText("SUS-003", "SAM-COFFEE-2"), "Mr. Rozario", 1, true))
		expect.truthy(string.find(nodeText("SUS-003", "SAM-ANYONE-1"), "Mr. Lim", 1, true))
	end)

	------------------------------------------------------------------
	-- The night agrees with itself (timing decision C: 10:28 and 10:29)
	------------------------------------------------------------------

	t.test("Victor leaves at half ten: Sam, his statement and Victor's own alibi agree", function()
		expect.truthy(string.find(nodeText("SUS-003", "SAM-ANYONE-3"), "half ten", 1, true))
		expect.truthy(string.find(statementText("STMT-SUS-003-VICTOR"), "half ten", 1, true))
		local alibi
		for _, suspect in ipairs(caseDef.suspects) do
			if suspect.id == "SUS-002" then
				alibi = suspect.alibi
			end
		end
		expect.truthy(string.find(alibi, "Half ten", 1, true))
		-- ... and the contradiction keeps its title.
		local found = false
		for _, contradiction in ipairs(caseDef.contradictions) do
			if contradiction.id == "CONTRA-001" then
				expect.equal(contradiction.label, "Half Past Ten")
				found = true
			end
		end
		expect.truthy(found)
	end)

	t.test("the badge log shows Victor out, in and out again, and he can't badge in without going out", function()
		local events = badgeEvents()
		expect.equal(#events, 3)
		expect.equal(events[1].direction, "OUT")
		expect.equal(events[2].direction, "IN")
		expect.equal(events[3].direction, "OUT")
		expect.equal(events[1].minutes, nightMinutes(10, 28, "PM"))
		expect.equal(events[2].minutes, nightMinutes(11, 4, "PM"))
		expect.equal(events[3].minutes, nightMinutes(11, 52, "PM"))
		expect.truthy(events[1].minutes < events[2].minutes and events[2].minutes < events[3].minutes)
	end)

	t.test("the printed badge log agrees with the evidence text", function()
		local folder = Instance.new("Folder")
		local _, sheet = PropKit.evidence("Printout", folder, CFrame.new())
		local gui = sheet:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
		local text = (gui:FindFirstChildOfClass("TextLabel") :: TextLabel).Text
		expect.truthy(string.find(text, "TINGKAT 9", 1, true))
		expect.truthy(string.find(text, "S. GURUNG", 1, true))
		expect.falsy(bannedIn(text))
		local printed = {}
		for hour, minute, direction in string.gmatch(text, "(%d+):(%d+)%s+LIM, V%.%s+(%a+)") do
			table.insert(printed, { minutes = (tonumber(hour) :: number) * 60 + (tonumber(minute) :: number), direction = direction })
		end
		local written = badgeEvents()
		expect.equal(#printed, #written)
		for index, event in ipairs(written) do
			-- The evidence text is 12-hour, the printout 24-hour; every
			-- event is before midnight, so the two scales agree.
			expect.equal(printed[index].direction, event.direction)
			expect.equal(printed[index].minutes, event.minutes)
		end
		folder:Destroy()
	end)

	t.test("the lift's trip log follows Victor's badge: down a minute after each out, up a minute before he's in", function()
		local observation
		for _, entry in ipairs(caseDef.observations) do
			if entry.instanceName == "ElevatorPanel" then
				observation = entry.text
			end
		end
		expect.truthy(observation)
		local trips = {}
		for hour, minute, meridiem, direction in string.gmatch(observation, "(%d+):(%d+) (%a%a) (%a+)") do
			table.insert(trips, { minutes = nightMinutes(tonumber(hour) :: number, tonumber(minute) :: number, meridiem), direction = direction })
		end
		expect.equal(#trips, 8)
		for index = 2, #trips do
			expect.truthy(trips[index].minutes >= trips[index - 1].minutes)
		end
		local function tripWithin(direction: string, from: number, to: number): boolean
			for _, trip in ipairs(trips) do
				if trip.direction == direction and trip.minutes >= from and trip.minutes <= to then
					return true
				end
			end
			return false
		end
		local events = badgeEvents()
		for _, event in ipairs(events) do
			if event.direction == "OUT" then
				expect.truthy(tripWithin("down", event.minutes + 1, event.minutes + 2))
			else
				expect.truthy(tripWithin("up", event.minutes - 2, event.minutes - 1))
			end
		end
		-- The first trip is the 10:29 one: nothing before it.
		expect.equal(trips[1].minutes, nightMinutes(10, 29, "PM"))
		expect.equal(trips[1].direction, "down")
	end)

	------------------------------------------------------------------
	-- The world (built fresh headless; the baked place in Studio)
	------------------------------------------------------------------

	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)

	local function worldTexts(): { string }
		local out = {}
		for _, descendant in ipairs((office :: Instance):GetDescendants()) do
			if descendant:IsA("TextLabel") then
				table.insert(out, descendant.Text)
			end
		end
		return out
	end

	local function anyText(fragment: string): boolean
		for _, text in ipairs(worldTexts()) do
			if string.find(text, fragment, 1, true) then
				return true
			end
		end
		return false
	end

	t.test("no v1 name, firm or place is left in any sign, printout or name tag", function()
		expect.truthy(office)
		local texts = worldTexts()
		expect.truthy(#texts > 20)
		for _, text in ipairs(texts) do
			local pattern = bannedIn(text)
			if pattern then
				error(`v1 text in the world ({pattern}): {string.sub(text, 1, 90)}`)
			end
		end
	end)

	t.test("the firm, the nameplate and the name tags carry the new names", function()
		expect.truthy(anyText("ROZARIO & LIM"))
		expect.truthy(anyText("DESIGN SDN. BHD."))
		expect.truthy(anyText("DANIEL ROZARIO"))
		for _, suspect in ipairs(caseDef.suspects) do
			expect.truthy(anyText(suspect.name))
		end
	end)

	t.test("the signage is Malaysian: KELUAR, no smoking, card reader, visitors' book, surau, milk note", function()
		expect.truthy(anyText("KELUAR"))
		expect.truthy(anyText("DILARANG MEROKOK"))
		expect.truthy(anyText("Sila imbas kad"))
		expect.truthy(anyText("BUKU PELAWAT"))
		expect.truthy(anyText("SURAU"))
		expect.truthy(anyText("Label susu anda. TQ."))
		for _, text in ipairs(worldTexts()) do
			expect.falsy(text == "EXIT")
		end
	end)

	t.test("the scene is marked with tape and a numbered marker, not chalk", function()
		local detailing = (office :: Instance):FindFirstChild("Detailing")
		expect.truthy(detailing)
		local detail = detailing :: Instance
		expect.falsy(detail:FindFirstChild("ChalkOutline"))
		local outline = detail:FindFirstChild("TapeOutline")
		expect.truthy(outline)
		local strips = (outline :: Instance):GetChildren()
		expect.truthy(#strips > 20)
		for _, strip in ipairs(strips) do
			expect.equal((strip :: BasePart).Color, Color3.fromRGB(232, 197, 71))
		end
		local marker = detail:FindFirstChild("FloorMarker")
		expect.truthy(marker)
		local plates = 0
		for _, plate in ipairs((marker :: Instance):GetChildren()) do
			plates += 1
			local text = plate:FindFirstChildWhichIsA("TextLabel", true)
			expect.equal(text and (text :: TextLabel).Text, "4")
		end
		expect.equal(plates, 2)
	end)

	t.test("the characters wear their approved skin tones", function()
		local suspects = (office :: Instance):FindFirstChild("Suspects")
		expect.truthy(suspects)
		for _, suspect in ipairs(caseDef.suspects) do
			local model = (suspects :: Instance):FindFirstChild(suspect.name)
			expect.truthy(model)
			local head = (model :: Instance):FindFirstChild("Head") :: BasePart
			expect.equal(head.Color, suspect.appearance.skin)
			local hitbox = (model :: Instance):FindFirstChild(suspect.id, true)
			expect.equal((hitbox :: Instance):GetAttribute("PromptLabel"), `Talk to {suspect.name}`)
		end
	end)
end
