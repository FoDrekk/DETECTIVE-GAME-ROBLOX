--!strict
--[[
	RevealService
	Evidence props that appear when the story says so.

	An evidence item whose `propPlacement` authors `revealWhen` has its prop
	(built by OfficeRoom into the EvidenceProps folder, or adopted from a
	baked place) held out of the world until every condition holds for the
	investigator -- e.g. a printout that only exists once someone has
	offered to print it. The conditions are the dialogue's own
	(Types.DialogueCondition, checked by ConversationService.conditionsHold),
	so "once they have said X" and "once you know Y" read the same way here
	as they do in a conversation.

	Server-authoritative by construction: a held prop is parented to
	ServerStorage, which never replicates, so a client can neither see nor
	target it, and InteractionService already refuses anything outside
	Workspace. The prop comes back to exactly where it was.

	Only the prop is gated. The evidence itself is untouched: it can still be
	reached another way (a line of dialogue that grants it), and discovery
	stays idempotent whichever route comes first.

	A reveal is latched in `caseState.revealedProps`: once a prop is out it
	stays for the rest of the case, even if a condition later stops holding
	(a cleared dialogue flag). A replay starts a new case state, and
	`refresh` holds the prop back again.

	Re-evaluated when the investigator learns something (the StoryEvents that
	change what the conditions read) and on every conversation step (which is
	where dialogue flags change). Cheap: only gated props are looked at.

	Scope: one investigator per server (SessionGuard), so the shared world
	follows that investigator's state. Per-player visibility would come with
	per-player sessions (WORLD_SCALABILITY.md A1).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CaseService = require(script.Parent:WaitForChild("CaseService"))
local ConversationService = require(script.Parent:WaitForChild("ConversationService"))
local StoryEvents = require(script.Parent:WaitForChild("StoryEvents"))

local log = Logger.scoped("RevealService")

local RevealService = {}

-- Must match OfficeRoom's folder for code-spawned evidence props.
local PROPS_FOLDER_NAME = "EvidenceProps"
local HIDDEN_FOLDER_NAME = "MysteryCase_HeldProps"

-- Where each held instance came from, so it goes back to the same place.
local homes: { [Instance]: Instance } = {}

local function propsFolder(): Instance?
	local office = workspace:FindFirstChild(Config.Environment.OfficeModelName)
	local parent = office or workspace
	return parent:FindFirstChild(PROPS_FOLDER_NAME)
end

local function heldFolder(): Instance
	local existing = ServerStorage:FindFirstChild(HIDDEN_FOLDER_NAME)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = HIDDEN_FOLDER_NAME
	folder.Parent = ServerStorage
	return folder
end

-- Everything OfficeRoom builds for one evidence prop: the part carrying the
-- Interactable contract (named after the evidence id) and, for a styled
-- prop, the rest of its look (`<id>_Look`). Found wherever it is now.
local function propInstances(evidenceId: string): { Instance }
	local found = {}
	local names = { [evidenceId] = true, [`{evidenceId}_Look`] = true }
	local containers: { Instance } = { heldFolder() }
	local inWorld = propsFolder()
	if inWorld then
		table.insert(containers, inWorld)
	end
	for _, container in ipairs(containers) do
		for _, child in ipairs(container:GetChildren()) do
			if names[child.Name] then
				table.insert(found, child)
			end
		end
	end
	return found
end

local function setShown(evidenceId: string, shown: boolean): number
	local moved = 0
	local held = heldFolder()
	for _, instance in ipairs(propInstances(evidenceId)) do
		if shown and instance.Parent == held then
			instance.Parent = homes[instance] or propsFolder() or workspace
			homes[instance] = nil
			moved += 1
		elseif not shown and instance.Parent ~= held then
			homes[instance] = instance.Parent :: Instance
			instance.Parent = held
			moved += 1
		end
	end
	return moved
end

-- The case's evidence whose prop is gated.
local function gated(caseDef: Types.CaseDefinition): { Types.EvidenceDefinition }
	local out = {}
	for _, evidence in ipairs(caseDef.evidence) do
		local placement = evidence.propPlacement
		if placement and placement.revealWhen then
			table.insert(out, evidence)
		end
	end
	return out
end

-- Whether this evidence's prop has been revealed for this player.
function RevealService.isRevealed(player: Player, evidenceId: string): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.caseState.revealedProps[evidenceId] == true
end

-- Whether the prop is in the world right now (for tests and diagnostics).
function RevealService.isInWorld(evidenceId: string): boolean
	for _, instance in ipairs(propInstances(evidenceId)) do
		if instance.Name == evidenceId then
			return instance:IsDescendantOf(workspace)
		end
	end
	return false
end

--[[
	Bring the world in line with this player's case: reveal (and latch) any
	gated prop whose conditions now hold, and hold back any gated prop not
	revealed in this case state (a replay). Returns the evidence ids newly
	revealed by this call. Safe to call at any time, any number of times.
]]
function RevealService.refresh(player: Player): { string }
	local newly = {}
	local data = PlayerDataService.get(player)
	local caseDef = data and CaseService.getCase(data.caseState.caseId)
	if not data or not caseDef then
		return newly
	end
	local revealed = data.caseState.revealedProps
	for _, evidence in ipairs(gated(caseDef)) do
		local placement = evidence.propPlacement :: any
		if not revealed[evidence.id] and ConversationService.conditionsHold(player, placement.revealWhen) then
			revealed[evidence.id] = true
			table.insert(newly, evidence.id)
			log:info("prop revealed", { player = player.Name, evidenceId = evidence.id })
		end
		setShown(evidence.id, revealed[evidence.id] == true)
	end
	return newly
end

-- Hold back every gated prop of a case before anyone plays it.
function RevealService.holdAll(caseId: string): number
	local caseDef = CaseService.getCase(caseId)
	if not caseDef then
		return 0
	end
	local held = 0
	for _, evidence in ipairs(gated(caseDef)) do
		if #propInstances(evidence.id) == 0 then
			log:warn("revealWhen prop has nothing in the world to hold back", { evidenceId = evidence.id })
		end
		held += setShown(evidence.id, false)
	end
	return held
end

function RevealService.start()
	local held = RevealService.holdAll(Config.Game.AutoStartCase)
	if held > 0 then
		log:info("gated props held back", { count = held })
	end
	local function onLearned(player: Player, _data: { [string]: any })
		RevealService.refresh(player)
	end
	StoryEvents.on("EvidenceDiscovered", onLearned)
	StoryEvents.on("StatementUnlocked", onLearned)
	StoryEvents.on("ContradictionUnlocked", onLearned)
	StoryEvents.on("DeductionUnlocked", onLearned)
	-- Dialogue flags change as lines are reached; there is no StoryEvent for
	-- that, so follow the conversation itself.
	ConversationService.onUpdated().Event:Connect(function(player: Player, _payload)
		RevealService.refresh(player)
	end)
	log:debug("started")
end

return RevealService
