-- JujutsuZero_ChestModule.lua
-- Chest / Crate ESP + Teleport (JJK Zero FIXED)
-- Author: Debbhai

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
repeat task.wait() until player.Character
local character = player.Character
local rootPart = character:WaitForChild("HumanoidRootPart")

local ChestModule = {}

-- ==============================
-- CONFIG
-- ==============================
ChestModule.Enabled = false
ChestModule.AutoTeleport = false
ChestModule.ScanInterval = 1.5
ChestModule.MaxDistance = 3000

-- ==============================
-- INTERNAL STATE
-- ==============================
local tracked = {}
local lastScan = 0
local ScanRoots = {}

-- ==============================
-- SETUP SCAN ROOTS (SAFE)
-- ==============================
task.spawn(function()
	repeat task.wait() until game:IsLoaded()

	local function safe(path)
		local cur = workspace
		for _, name in ipairs(path) do
			cur = cur:FindFirstChild(name)
			if not cur then return nil end
		end
		return cur
	end

	local r1 = safe({"Map","Geometry","Map","Folder"})
	if r1 then table.insert(ScanRoots, r1) end

	local r2 = safe({"Container","Models"})
	if r2 then table.insert(ScanRoots, r2) end
end)

-- ==============================
-- UTIL
-- ==============================
local function getBasePart(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end
end

-- ==============================
-- ESP CREATION
-- ==============================
local function createESP(model)
	if tracked[model] then return end

	local part = getBasePart(model)
	if not part then return end

	local dist = (rootPart.Position - part.Position).Magnitude
	if dist > ChestModule.MaxDistance then return end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = Color3.fromRGB(255, 200, 60)
	highlight.OutlineColor = Color3.new(1,1,1)
	highlight.FillTransparency = 0.3
	highlight.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Adornee = part
	gui.Size = UDim2.new(0,150,0,35)
	gui.StudsOffset = Vector3.new(0,3,0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1,1)
	txt.BackgroundTransparency = 1
	txt.Text = "📦 CRATE"
	txt.Font = Enum.Font.GothamBold
	txt.TextSize = 16
	txt.TextStrokeTransparency = 0
	txt.TextColor3 = Color3.fromRGB(255,200,60)
	txt.Parent = gui

	tracked[model] = {
		part = part,
		gui = gui,
		hl = highlight
	}
end

local function clear()
	for _, v in pairs(tracked) do
		pcall(function()
			v.gui:Destroy()
			v.hl:Destroy()
		end)
	end
	tracked = {}
end

-- ==============================
-- SCAN (CORRECT)
-- ==============================
local function scan()
	if not ChestModule.Enabled then return end
	if tick() - lastScan < ChestModule.ScanInterval then return end
	lastScan = tick()

	for _, root in ipairs(ScanRoots) do
		for _, obj in ipairs(root:GetDescendants()) do
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
-- TELEPORT
-- ==============================
function ChestModule:TeleportToNearest()
	local best, dist = nil, math.huge

	for _, v in pairs(tracked) do
		local d = (rootPart.Position - v.part.Position).Magnitude
		if d < dist then
			dist = d
			best = v
		end
	end

	if not best then return end

	local cf = best.part.CFrame * CFrame.new(0,3,3)
	TweenService:Create(
		rootPart,
		TweenInfo.new(dist/140, Enum.EasingStyle.Quint),
		{CFrame = cf}
	):Play()
end

-- ==============================
-- API
-- ==============================
function ChestModule:Enable()
	ChestModule.Enabled = true
end

function ChestModule:Disable()
	ChestModule.Enabled = false
	clear()
end

function ChestModule:SetAutoTeleport(b)
	ChestModule.AutoTeleport = b
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
