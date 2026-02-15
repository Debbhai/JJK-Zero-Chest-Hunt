-- JujutsuZero_AutoQuestCombat.lua
-- Auto Quest + Auto Combat + Skill Executor
-- Author: Debbhai

-- ============================
-- SERVICES
-- ============================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ============================
-- MODULE
-- ============================
local Module = {}

-- ============================
-- CONFIG
-- ============================
Module.Enabled = false
Module.AutoQuest = false
Module.AutoAttack = false
Module.KillAura = false

Module.AttackRange = 25
Module.TargetNPCNames = {
    "Curse",
    "Enemy",
    "Bandit",
}

-- SKILLS YOU WANT TO USE
-- these should match tool names or keybinds
Module.SelectedSkills = {
    -- examples:
    -- "Black Flash",
    -- "Cursed Strike",
}

-- delay between skill uses
Module.SkillCooldown = 1.2

-- ============================
-- INTERNAL
-- ============================
local lastSkill = 0

-- ============================
-- UTILS
-- ============================
local function nameMatches(name)
    name = name:lower()
    for _, v in ipairs(Module.TargetNPCNames) do
        if name:find(v:lower()) then
            return true
        end
    end
    return false
end

local function getEnemies()
    local enemies = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model")
            and obj:FindFirstChild("Humanoid")
            and obj ~= character
            and nameMatches(obj.Name) then

            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp then
                table.insert(enemies, obj)
            end
        end
    end

    return enemies
end

local function getClosestEnemy()
    local closest, dist = nil, math.huge

    for _, enemy in ipairs(getEnemies()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        local hum = enemy:FindFirstChild("Humanoid")

        if hrp and hum and hum.Health > 0 then
            local d = (rootPart.Position - hrp.Position).Magnitude
            if d < dist and d <= Module.AttackRange then
                dist = d
                closest = enemy
            end
        end
    end

    return closest
end

-- ============================
-- ATTACK
-- ============================
local function basicAttack()
    -- left click
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ============================
-- SKILLS
-- ============================
local function useSkill(name)
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == name then
            humanoid:EquipTool(tool)
            task.wait(0.1)
            tool:Activate()
            return true
        end
    end
    return false
end

local function executeSkills()
    if tick() - lastSkill < Module.SkillCooldown then return end
    lastSkill = tick()

    for _, skill in ipairs(Module.SelectedSkills) do
        if useSkill(skill) then
            task.wait(0.2)
        end
    end
end

-- ============================
-- AUTO QUEST
-- ============================
local function autoQuest()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt")
            and obj.Parent
            and obj.Parent.Name:lower():find("quest") then

            fireproximityprompt(obj)
        end
    end
end

-- ============================
-- MAIN LOOP
-- ============================
RunService.Heartbeat:Connect(function()
    if not Module.Enabled then return end

    if Module.AutoQuest then
        autoQuest()
    end

    local enemy = getClosestEnemy()
    if enemy then
        local hrp = enemy.HumanoidRootPart

        if Module.KillAura then
            rootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
        end

        if Module.AutoAttack then
            basicAttack()
        end

        executeSkills()
    end
end)

-- ============================
-- API
-- ============================
function Module:Enable()
    Module.Enabled = true
end

function Module:Disable()
    Module.Enabled = false
end

function Module:SetAutoQuest(v)
    Module.AutoQuest = v
end

function Module:SetAutoAttack(v)
    Module.AutoAttack = v
end

function Module:SetKillAura(v)
    Module.KillAura = v
end

function Module:SetSkills(skillTable)
    Module.SelectedSkills = skillTable
end

return Module
