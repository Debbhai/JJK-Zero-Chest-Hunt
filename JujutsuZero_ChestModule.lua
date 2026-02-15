-- JujutsuZero_ChestModule.lua
-- ProximityPrompt-based Chest ESP + Teleport
-- No admin / no explorer required
-- Author: Debbhai

-- ==============================
-- SERVICES
-- ==============================
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
ChestModule.ScanInterval = 1
ChestModule.MaxDistance = 3000

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
-- UTIL
-- ==============================
local function getRootFromPrompt(prompt)
    local parent = prompt.Parent
    if not parent then return nil end

    if parent:IsA("BasePart") then
        return parent
    end

    if parent:IsA("Model") then
        return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
    end

    return parent:FindFirstChildWhichIsA("BasePart")
end

local function getRarity(obj)
    local attr = obj:GetAttribute("Rarity")
    if typeof(attr) == "string" then
        return attr
    end

    for rarity, _ in pairs(ChestModule.RarityColors) do
        if obj.Name:lower():find(rarity:lower()) then
            return rarity
        end
    end

    return "Unknown"
end

-- ==============================
-- ESP CREATION
-- ==============================
local function createESP(prompt)
    if trackedChests[prompt] then return end

    local part = getRootFromPrompt(prompt)
    if not part then return end

    if (rootPart.Position - part.Position).Magnitude > ChestModule.MaxDistance then
        return
    end

    local rarity = getRarity(prompt.Parent)
    local color = ChestModule.RarityColors[rarity] or ChestModule.RarityColors.Unknown

    local highlight = Instance.new("Highlight")
    highlight.Adornee = prompt.Parent:IsA("Model") and prompt.Parent or part
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.35
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = prompt.Parent

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 160, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "📦 Chest"
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.Parent = billboard

    trackedChests[prompt] = {
        prompt = prompt,
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
-- SCANNING (THE KEY FIX)
-- ==============================
local function scan()
    if not ChestModule.Enabled then return end
    if tick() - lastScan < ChestModule.ScanInterval then return end
    lastScan = tick()

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            -- Ignore NPC / player prompts
            if not obj.Parent:FindFirstAncestorOfClass("Humanoid") then
                createESP(obj)
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
        if data.part and data.part:IsDescendantOf(workspace) then
            local d = (rootPart.Position - data.part.Position).Magnitude
            if d < dist then
                dist = d
                closest = data
            end
        end
    end

    if not closest then return end

    TweenService:Create(
        rootPart,
        TweenInfo.new(math.clamp(dist / 120, 0.3, 3), Enum.EasingStyle.Quint),
        { CFrame = closest.part.CFrame * CFrame.new(0, 3, 3) }
    ):Play()
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
