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

-- Known Jujutsu Zero chest identifiers
ChestModule.NameKeywords = {
    "chest",
    "loot",
    "curse",
}

-- Rarity colors
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
local function nameMatches(name)
    name = name:lower()
    for _, k in ipairs(ChestModule.NameKeywords) do
        if name:find(k) then
            return true
        end
    end
    return false
end

local function getChestPart(model)
    return model:FindFirstChild("PrimaryPart")
        or model:FindFirstChildWhichIsA("BasePart")
end

local function getRarity(model)
    -- Attribute check
    local attr = model:GetAttribute("Rarity")
    if typeof(attr) == "string" then
        return attr
    end

    -- ValueObject check
    local rarityValue = model:FindFirstChild("Rarity")
    if rarityValue and rarityValue:IsA("StringValue") then
        return rarityValue.Value
    end

    -- Name fallback
    for rarity, _ in pairs(ChestModule.RarityColors) do
        if model.Name:lower():find(rarity:lower()) then
            return rarity
        end
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
    billboard.Size = UDim2.new(0, 140, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "📦 " .. rarity .. " Chest"
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.Parent = billboard

    trackedChests[model] = {
        model = model,
        part = part,
        rarity = rarity,
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
-- SCANNING (OPTIMIZED)
-- ==============================
local function scan()
    if not ChestModule.Enabled then return end
    if tick() - lastScan < ChestModule.ScanInterval then return end
    lastScan = tick()

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and nameMatches(obj.Name) then
            createESP(obj)
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
        {CFrame = targetCF}
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
