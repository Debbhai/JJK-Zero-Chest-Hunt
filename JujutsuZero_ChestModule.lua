-- JujutsuZero_ChestModule.lua
-- Standalone Chest / Loot ESP + Teleport Module
-- Designed for Jujutsu Zero
-- Author: Debbhai

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local ChestModule = {}

-- ==============================
-- CONFIG
-- ==============================
ChestModule.Enabled = false
ChestModule.AutoTeleport = false
ChestModule.ScanInterval = 1.5
ChestModule.MaxDistance = 2500

-- Rarity colors (used if game provides rarity data)
ChestModule.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(80, 255, 80),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 200, 60),
	Mythic = Color3.fromRGB(255, 80, 80),
	Unknown = Color3.fromRGB(255, 255, 255),
}

-- ==============================
-- INTERNAL STATE
-- ==============================
local trackedChests = {}
local lastScan = 0

-- ==============================
-- SCAN ROOTS (JJK ZERO SPECIFIC)
-- ==============================
local ScanRoots = {}

task.spawn(function()
	-- Wait safely for map containers
	local mapFolder = workspace:WaitForChild("Map", 10)
	if mapFolder then
		local geometry = mapFolder:WaitForChild("Geometry", 10)
		if geometry then
			local map = geometry:WaitForChild("Map", 10)
			if map then
				local folder = map:WaitForChild("Folder", 10)
				if folder then
					table.insert(ScanRoots, folder)
				end
			end
		end
	end

	local container = workspace:WaitForChild("Container", 10)
	if container then
		local models = container:WaitForChild("Models", 10)
		if models then
			table.insert(ScanRoots, models)
		end
	end
end)

-- ==============================
-- UTIL
-- ==============================
local function getChestPart(model)
	return model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart")
end

local function getRarity(model)
	local attr = model:GetAttribute("Rarity")
	if typeof(attr) == "string" then
		return attr
	end

	local rarityValue = model:FindFirstChild("Rarity")
	if rarityValue and rarityValue:IsA("StringValue") then
		return rarityValue.Value
	end

	return "Unknown"
end

-- ==============================
-- ESP CREATION
-- ==============================
local function createESP(model)
	if trackedChests[model] then return end

	local part = getChestPart(model)
	if not part then return end

	if (rootPart.Position - part.Position).Magnitude > ChestModule.MaxDistance then
		return
	end

	local rarity = getRarity(model)
	local color = ChestModule.RarityColors[rarity] or ChestModule.RarityColors.Unknown

	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = part
	billboard.Size = UDim2.new(0, 150, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "📦 Crate"
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Parent = billboard

	trackedChests[model] = {
		model = model,
		part = part,
		highlight = highlight,
		billboard = billboard,
	}
end

local function clearAll()
	for _, data in pairs(trackedChests) do
		pcall(function()
			data.highlight:Destroy()
			data.billboard:Destroy()
		end)
	end
	trackedChests = {}
end

-- ==============================
-- SCANNING (OPTIMIZED & TARGETED)
-- ==============================
local function scan()
	if not ChestModule.Enabled then return end
	if tick() - lastScan < ChestModule.ScanInterval then return end
	lastScan = tick()

	for _, root in ipairs(ScanRoots) do
		for _, obj in ipairs(root:GetChildren()) do
			if obj:IsA("Model") then
				local n = obj.Name:lower()
				if n == "crate" or n == "crates" or n == "twocrates" then
					createESP(obj)
				end
			end
		end
	end
end

-- ==============================
-- AUTO TELEPORT
-- ==============================
function ChestModule:TeleportToNearest()
	local closest, dist = nil, math.huge

	for _, data in pairs(trackedChests) do
		local d = (rootPart.Position - data.part.Position).Magnitude
		if d < dist then
			dist = d
			closest = data
		end
	end

	if not closest then return end

	local targetCF = closest.part.CFrame * CFrame.new(0, 3, 3)
	local tween = TweenService:Create(
		rootPart,
		TweenInfo.new(dist / 120, Enum.EasingStyle.Quint),
		{ CFrame = targetCF }
	)
	tween:Play()
end

-- ==============================
-- PUBLIC API
-- ==============================
function ChestModule:Enable()
	ChestModule.Enabled = true
end

function ChestModule:Disable()
	ChestModule.Enabled = false
	clearAll()
end

function ChestModule:SetAutoTeleport(state)
	ChestModule.AutoTeleport = state
end

-- ==============================
-- LOOP
-- ==============================
RunService.Heartbeat:Connect(function()
	scan()
	if ChestModule.Enabled and ChestModule.AutoTeleport then
		ChestModule:TeleportToNearest()
	end
end)

return ChestModule
