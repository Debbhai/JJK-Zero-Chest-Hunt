-- JujutsuZero_ChestModule.lua
-- Event-based Chest Detection for Jujutsu Zero
-- Works with server-side spawned chests
-- Author: Debbhai

-- ==============================
-- SERVICES
-- ==============================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local ChestModule = {}

-- ==============================
-- CONFIG
-- ==============================
ChestModule.Enabled = false
ChestModule.AutoTeleport = false

ChestModule.RarityColors = {
    Common = Color3.fromRGB(200, 200, 200),
    Rare = Color3.fromRGB(80, 150, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 200, 60),
    Unknown = Color3.fromRGB(255, 255, 255),
}

-- ==============================
-- INTERNAL STATE
-- ==============================
local discoveredChests = {}

-- ==============================
-- UTIL
-- ==============================
local function getPartFromPrompt(prompt)
    local p = prompt.Parent
    if not p then return nil end

    if p:IsA("BasePart") then return p end
    if p:IsA("Model") then
        return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart")
    end

    return p:FindFirstChildWhichIsA("BasePart")
end

-- ==============================
-- VISUALS
-- ==============================
local function markChest(prompt)
    if discoveredChests[prompt] then return end

    local part = getPartFromPrompt(prompt)
    if not part then return end

    local color = ChestModule.RarityColors.Unknown

    local highlight = Instance.new("Highlight")
    highlight.Adornee = part.Parent:IsA("Model") and part.Parent or part
    highlight.FillColor = color
    highlight.FillTransparency = 0.35
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = part

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 160, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "📦 Chest Discovered"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextStrokeTransparency = 0
    label.TextColor3 = color
    label.Parent = billboard

    discoveredChests[prompt] = {
        part = part,
        highlight = highlight,
        billboard = billboard,
    }
end

-- ==============================
-- TELEPORT
-- ==============================
function ChestModule:TeleportToNearest()
    local closest, dist = nil, math.huge

    for _, data in pairs(discoveredChests) do
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
        TweenInfo.new(0.4, Enum.EasingStyle.Quint),
        { CFrame = closest.part.CFrame * CFrame.new(0, 3, 3) }
    ):Play()
end

-- ==============================
-- EVENT HOOK (THE IMPORTANT PART)
-- ==============================
ProximityPromptService.PromptShown:Connect(function(prompt)
    if not ChestModule.Enabled then return end

    -- ignore NPC/player prompts
    if prompt.Parent:FindFirstAncestorOfClass("Humanoid") then return end

    markChest(prompt)
end)

-- ==============================
-- PUBLIC API
-- ==============================
function ChestModule:Enable()
    ChestModule.Enabled = true
end

function ChestModule:Disable()
    ChestModule.Enabled = false
end

function ChestModule:SetAutoTeleport(state)
    ChestModule.AutoTeleport = state
end

return ChestModule
