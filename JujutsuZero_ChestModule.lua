-- JujutsuZero_ChestModule.lua
-- Robust Chest / Loot ESP + Teleport Module
-- Fixed structure handling for Jujutsu Zero
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
ChestModule.ScanInterval = 1.5
ChestModule.MaxDistance = 3000

-- Name keywords (still useful, but no longer required)
ChestModule.NameKeywords = {
    "chest",
    "loot",
    "box",
    "crate",
    "curse",
}

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

-- Determine if an object "looks like" a chest
local function isChestCandidate(obj)
    if obj:IsA("Model") then
        if nameMatches(obj.Name) then
            return true
        end

        -- Structural check: models with at least one BasePart
        return obj:FindFirstChildWhichIsA("BasePart") ~= nil
    end

    if obj:IsA("BasePart") then
        return nameMatches(obj.Name)
    end

    return false
end

local function getChestPart(obj)
    if obj:IsA("Model") then
        if obj.PrimaryPart then
            return obj.PrimaryPart
        end

        local part = obj:FindFirstChildWhichIsA("BasePart")
        if part then
            pcall(function()
                obj.PrimaryPart = part
            end)
            return part
        end
    elseif obj:IsA("BasePart") then
        return obj
    end

    return nil
end

local function getRarity(obj)
    local attr = obj:GetAttribute("Rarity")
    if typeof(attr) == "string" then
        return attr
    end

    local rarityValue = obj:FindFirstChild("Rarity")
    if rarityValue and rarityValue:IsA("StringValue") then
        return rarityValue.Value
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
local function createESP(obj)
    if trackedChests[obj] then return end

    local part = getChestPart(obj)
    if not part then return end

    if (rootPart.Position - part.Position).Magnitude > ChestModule.MaxDistance then
        return
    end

    local rarity = getRarity(obj)
    local color = ChestModule.RarityColors[rarity] or ChestModule.RarityColors.Unknown

    -- Highlight
    local highlight = Instance.new("Highlight")
    highlight.Adornee = obj:IsA("Model") and obj or part
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.35
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = obj

    -- Billboard
    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
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

    trackedChests[obj] = {
        obj = obj,
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
-- SCANNING (FIXED)
-- ==============================
local function scan()
    if not ChestModule.Enabled then return end
    if tick() - lastScan < ChestModule.ScanInterval then return end
    lastScan = tick()

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isChestCandidate(obj) then
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
        if data.part and data.part:IsDescendantOf(workspace) then
            local d = (rootPart.Position - data.part.Position).Magnitude
            if d < dist then
                dist = d
                closest = data
            end
        end
    end

    if not closest then return end

    local targetCF = closest.part.CFrame * CFrame.new(0, 3, 3)
    TweenService:Create(
        rootPart,
        TweenInfo.new(math.clamp(dist / 120, 0.3, 3), Enum.EasingStyle.Quint),
        { CFrame = targetCF }
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
