-- Zentry/Modules/FileScanner.lua
local FileScanner = {}

-- Roblox Services (obtained directly within the module)
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

-- Recursive function to scan children of an instance
function FileScanner.scanInstanceChildren(instance, path, depth)
	if depth > 5 then return {} end -- Limit recursion depth

	local items = {}
	if not instance then return items end

	for _, child in ipairs(instance:GetChildren()) do
		local childPath = path .. "/" .. child.Name
		local itemEntry = {
			name = child.Name,
			path = childPath,
			type = child.ClassName
		}
		-- Optionally, could add first few lines of code or a hash here for scripts
		-- if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
		-- itemEntry.sourceStart = child.Source:sub(1, 50)
		-- end

		-- If it's a container type that typically holds other instances, recurse
		if #child:GetChildren() > 0 and
			(child:IsA("Folder") or
				child:IsA("Model") or
				child:IsA("Actor") or
				child:IsA("Tool") or -- Added Tool
				child.ClassName == "ScreenGui" or
				child.ClassName == "Frame" or
				child.ClassName == "ScrollingFrame" or
				child.ClassName == "GuiObject" or -- General Gui container
				child.ClassName == "Configuration") then -- Added Configuration
			itemEntry.children = FileScanner.scanInstanceChildren(child, childPath, depth + 1)
		end
		table.insert(items, itemEntry)
	end
	return items
end

-- Main function to get the game's file structure
function FileScanner.getGameFileStructure()
	local structure = {}
	local servicesToScan = {
		Workspace = Workspace,
		ReplicatedStorage = ReplicatedStorage,
		ServerScriptService = ServerScriptService,
		StarterGui = StarterGui,
		StarterPlayer = StarterPlayer,
		ServerStorage = ServerStorage,
		Lighting = Lighting,
		SoundService = SoundService
		-- Add other services if needed, e.g., game:GetService("Chat")
	}

	for serviceName, serviceInstance in pairs(servicesToScan) do
		if serviceInstance then
			-- Use FileScanner.scanInstanceChildren for consistency
			structure[serviceName] = FileScanner.scanInstanceChildren(serviceInstance, serviceName, 1)
		end
	end

	-- Also scan StarterPlayer sub-services if StarterPlayer exists
	if servicesToScan.StarterPlayer then
		local sp = servicesToScan.StarterPlayer
		local sps = sp:FindFirstChild("StarterPlayerScripts")
		if sps then
			structure["StarterPlayerScripts"] = FileScanner.scanInstanceChildren(sps, "StarterPlayer/StarterPlayerScripts", 1)
		end
		local scs = sp:FindFirstChild("StarterCharacterScripts")
		if scs then
			structure["StarterCharacterScripts"] = FileScanner.scanInstanceChildren(scs, "StarterPlayer/StarterCharacterScripts", 1)
		end
	end

	return structure
end

return FileScanner
