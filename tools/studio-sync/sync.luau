--!nocheck
--[[
	Studio half of tools/studio-sync. Run it in EDIT mode (the command bar, or the
	Studio MCP's execute_luau) while `node tools/studio-sync/serve.js` is running.

	  APPLY = false  report what differs from the repo, change nothing (the default)
	  APPLY = true   write the repo's source into every script that differs, create
	                 the ones the place lacks (and any Folder they need), then verify
	                 every one it touched against the repo's fingerprint
	  PRUNE = true   with APPLY: also delete a script the repo no longer has, but only
	                 under the folders the project maps whole (Shared, UI, Server,
	                 Client, Config, UnitTest)

	The fingerprint is the byte length plus h = (h * 31 + byte) mod 2^32, over the
	source with "\r" stripped -- the same one manifest.js computes.

	In Edit mode `require` caches a module for the whole session, so after a sync
	require a :Clone() of the ModuleScript (same parent) to run its new source.
]]

local PORT = 34873
local APPLY = false
local PRUNE = false

local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local base = "http://127.0.0.1:" .. PORT

local function fingerprint(source: string): (number, number)
	local h = 0
	for i = 1, #source do
		h = (h * 31 + string.byte(source, i)) % 4294967296
	end
	return #source, h
end

local function cleanSource(script: LuaSourceContainer): string
	return (script.Source:gsub("\r", ""))
end

local function resolve(studioPath: string): Instance?
	local segments = string.split(studioPath, ".")
	local current: Instance? = game:GetService(segments[1])
	for index = 2, #segments do
		current = current and current:FindFirstChild(segments[index])
	end
	return current
end

-- The parent of a script, creating Folders for any segment that is missing.
local function parentFor(studioPath: string): Instance
	local segments = string.split(studioPath, ".")
	local current: Instance = game:GetService(segments[1])
	for index = 2, #segments - 1 do
		local child = current:FindFirstChild(segments[index])
		if not child then
			child = Instance.new("Folder")
			child.Name = segments[index]
			child.Parent = current
		end
		current = child
	end
	return current
end

local function write(script: LuaSourceContainer, source: string)
	local ok = pcall(function()
		ScriptEditorService:UpdateSourceAsync(script, function()
			return source
		end)
	end)
	if not ok or cleanSource(script) ~= source then
		script.Source = source
	end
end

local manifest = HttpService:JSONDecode(HttpService:GetAsync(base .. "/manifest"))
local wanted: { [string]: boolean } = {}
local report = { same = 0, changed = {}, missing = {}, extra = {}, failed = {}, wrote = 0 }

for _, entry in ipairs(manifest) do
	wanted[entry.path] = true
	local script = resolve(entry.path)
	if not script then
		table.insert(report.missing, entry.path)
	elseif not script:IsA("LuaSourceContainer") then
		table.insert(report.failed, entry.path .. " (not a script in the place)")
	else
		local length, hash = fingerprint(cleanSource(script))
		if length == entry.length and hash == entry.hash then
			report.same += 1
		else
			table.insert(report.changed, entry.path)
		end
	end
end

-- Scripts the place has under a whole-mapped folder that the repo does not.
local roots = {
	"ReplicatedStorage.Shared",
	"ReplicatedStorage.UI",
	"ServerScriptService.Server",
	"StarterPlayer.StarterPlayerScripts.Client",
	"ServerStorage.Config",
	"ServerStorage.UnitTest",
}
for _, rootPath in ipairs(roots) do
	local root = resolve(rootPath)
	if root then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("LuaSourceContainer") then
				local full = descendant:GetFullName()
				if not wanted[full] then
					table.insert(report.extra, full)
				end
			end
		end
	end
end

if APPLY then
	local todo = {}
	for _, path in ipairs(report.changed) do
		table.insert(todo, path)
	end
	for _, path in ipairs(report.missing) do
		table.insert(todo, path)
	end
	local byPath = {}
	for _, entry in ipairs(manifest) do
		byPath[entry.path] = entry
	end
	table.sort(todo)
	for _, path in ipairs(todo) do
		local entry = byPath[path]
		local source = HttpService:GetAsync(base .. "/source?path=" .. HttpService:UrlEncode(path))
		local length, hash = fingerprint(source)
		if length ~= entry.length or hash ~= entry.hash then
			table.insert(report.failed, path .. " (download does not match the manifest)")
			continue
		end
		local script = resolve(path)
		if not script then
			script = Instance.new(entry.class)
			script.Name = string.split(path, ".")[#string.split(path, ".")]
			script.Parent = parentFor(path)
		end
		write(script, source)
		local writtenLength, writtenHash = fingerprint(cleanSource(script))
		if writtenLength == entry.length and writtenHash == entry.hash then
			report.wrote += 1
		else
			table.insert(report.failed, path .. " (written source does not verify)")
		end
	end
	if PRUNE then
		for _, path in ipairs(report.extra) do
			local script = resolve(path)
			if script then
				script:Destroy()
			end
		end
	end
end

local lines = {
	`in sync: {report.same}   differ: {#report.changed}   missing: {#report.missing}   extra: {#report.extra}   wrote: {report.wrote}   failed: {#report.failed}`,
}
for label, list in { changed = report.changed, missing = report.missing, extra = report.extra, failed = report.failed } do
	for _, path in ipairs(list) do
		table.insert(lines, `  {label}: {path}`)
	end
end
return table.concat(lines, "\n")
