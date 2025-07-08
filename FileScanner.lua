-- Zentry/Modules/FileScanner.lua
local FileScanner = {}

local Services = {
	Workspace = game:GetService("Workspace"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterGui = game:GetService("StarterGui"),
	StarterPlayer = game:GetService("StarterPlayer"),
	ServerStorage = game:GetService("ServerStorage"),
	Lighting = game:GetService("Lighting"),
	SoundService = game:GetService("SoundService")
}

-- Sanitize instance names to avoid path issues (e.g., dots in names)
local function sanitize(name)
	return name:gsub("%.", "_")
end

-- Build a dot-notation path for an instance (e.g. game.Workspace.Part)
local function buildDotPath(basePath, name)
	return basePath .. "." .. sanitize(name)
end

-- Scan children recursively
function FileScanner.scanInstanceChildren(instance, basePath, depth)
	if depth > 6 then return {} end -- Prevent deep recursion

	local items = {}
	for _, child in ipairs(instance:GetChildren()) do
		local fullPath = buildDotPath(basePath, child.Name)

		local entry = {
			name = child.Name,
			full_path = fullPath,
			class = child.ClassName,
		}

		-- Preview first few lines of script source (if readable)
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			local success, source = pcall(function() return child.Source end)
			if success and source then
				entry.sourceStart = source:sub(1, 120) .. (source:len() > 120 and "..." or "")
			end
		end

		-- If the child can have children, scan it
		if #child:GetChildren() > 0 and (
			child:IsA("Folder") or child:IsA("Model") or child:IsA("Tool") or
				child:IsA("GuiBase2d") or child:IsA("GuiObject") or
				child:IsA("Configuration") or child:IsA("Actor")) then
			entry.children = FileScanner.scanInstanceChildren(child, fullPath, depth + 1)
		end

		table.insert(items, entry)
	end
	return items
end

function FileScanner.getGameFileStructure()
	local structure = {}

	for name, service in pairs(Services) do
		if service then
			structure[name] = FileScanner.scanInstanceChildren(service, "game." .. name, 1)
		end
	end

	-- Special scan for StarterPlayer subfolders
	local sp = Services.StarterPlayer
	if sp then
		local sps = sp:FindFirstChild("StarterPlayerScripts")
		if sps then
			structure["StarterPlayerScripts"] = FileScanner.scanInstanceChildren(sps, "game.StarterPlayer.StarterPlayerScripts", 1)
		end
		local scs = sp:FindFirstChild("StarterCharacterScripts")
		if scs then
			structure["StarterCharacterScripts"] = FileScanner.scanInstanceChildren(scs, "game.StarterPlayer.StarterCharacterScripts", 1)
		end
	end

	return structure
end

return FileScanner
