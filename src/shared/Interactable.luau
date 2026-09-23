--!strict
--[[
	Interactable
	The single authoritative contract for interactable objects.

	Interactables are CollectionService-tagged "Interactable" instances carrying
	attributes. Both the client (for prompts/presentation) and the server (for
	validation) read them through this module, so the contract can never drift
	between the two sides.

	Attribute contract:
	  InteractionKind : string  ("Examine" | "Read" | "PickUp" | "Talk")
	  PromptLabel     : string  (e.g. "Examine Phone")
	  EvidenceId      : string  (optional, e.g. "EV-001")
	  ReadableText    : string  (optional, reserved for Read presentation)
	  ObservationText : string  (optional, Phase 2O; authored flavour text
	                    shown when a non-evidence object is examined. Purely
	                    presentational -- it never creates evidence, timeline,
	                    objective or reasoning state.)
	  SuspectId       : string  (optional, e.g. "SUS-001"; identifies which
	                    suspect a Talk-kind interactable represents. Read the
	                    same way as EvidenceId. No NPC behaviour consumes this
	                    yet -- it exists so future NPC interactables can use
	                    this same contract instead of a parallel one.)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local Interactable = {}

Interactable.TAG = "Interactable"

Interactable.AttributeName = table.freeze({
	Kind = "InteractionKind",
	PromptLabel = "PromptLabel",
	EvidenceId = "EvidenceId",
	ReadableText = "ReadableText",
	ObservationText = "ObservationText",
	SuspectId = "SuspectId",
})

-- Interaction kinds that are enabled in the current phase.
-- Declared here so client and server agree on what is actionable.
local ENABLED_KINDS: { [string]: boolean } = {
	Examine = true,
	Read = true,
	PickUp = true,
	Talk = true,
}
Interactable.EnabledKinds = table.freeze(ENABLED_KINDS)

export type Descriptor = {
	instance: Instance,
	kind: Types.InteractionKind,
	label: string,
	evidenceId: string?,
	suspectId: string?,
	-- Authored flavour text for a non-evidence interactable, if any (Phase
	-- 2O). Optional; nil means the object carries no authored observation.
	observation: string?,
}

local function readString(instance: Instance, attribute: string): string?
	local value = instance:GetAttribute(attribute)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

function Interactable.isKind(value: string): boolean
	return Interactable.EnabledKinds[value] == true
end

--[[
	Describe an interactable from its attributes.

	Returns nil when the instance is not a well-formed, enabled interactable.
	This is the single source of truth for parsing an interactable; it performs
	no distance/tag validation (those are the server's job).
]]
function Interactable.describe(instance: Instance): Descriptor?
	local kindName = readString(instance, Interactable.AttributeName.Kind)
	if not kindName or not Interactable.isKind(kindName) then
		return nil
	end

	return {
		instance = instance,
		kind = kindName :: Types.InteractionKind,
		label = readString(instance, Interactable.AttributeName.PromptLabel) or kindName,
		evidenceId = readString(instance, Interactable.AttributeName.EvidenceId),
		suspectId = readString(instance, Interactable.AttributeName.SuspectId),
		observation = readString(instance, Interactable.AttributeName.ObservationText),
	}
end

function Interactable.isInteractable(instance: Instance): boolean
	return CollectionService:HasTag(instance, Interactable.TAG)
end

function Interactable.getAll(): { Instance }
	return CollectionService:GetTagged(Interactable.TAG)
end

-- The nearest BasePart that represents this interactable's physical location.
function Interactable.getPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("BasePart")
end

return Interactable
