-- AKScripts: Single-script test dummy launcher
-- Place this Script in ServerScriptService in YOUR Roblox Studio experience.
-- Add a Model named "TestDummy" to Workspace with a HumanoidRootPart.
-- This script creates the ProximityPrompt and handles the launch on the server.
-- It only affects the tagged test dummy, never players.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local DUMMY_NAME = "TestDummy"
local PROMPT_NAME = "AKLaunchPrompt"
local MAX_DISTANCE = 12
local COOLDOWN = 2

local cooldowns = {}

local function setupDummy(dummy)
    if not dummy:IsA("Model") then
        return
    end

    local root = dummy:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        warn("[AKScripts] TestDummy needs a HumanoidRootPart.")
        return
    end

    if not CollectionService:HasTag(dummy, "LaunchDummy") then
        CollectionService:AddTag(dummy, "LaunchDummy")
    end

    local existing = root:FindFirstChild(PROMPT_NAME)
    if existing then
        existing:Destroy()
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = PROMPT_NAME
    prompt.ActionText = "Launch Dummy"
    prompt.ObjectText = "AKScripts Test Dummy"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.25
    prompt.MaxActivationDistance = MAX_DISTANCE
    prompt.RequiresLineOfSight = false
    prompt.Parent = root

    prompt.Triggered:Connect(function(player)
        if not dummy:IsDescendantOf(workspace) then
            return
        end

        local character = player.Character
        local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
        local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")

        if not playerRoot or not dummyRoot or not dummyRoot:IsA("BasePart") then
            return
        end

        if (playerRoot.Position - dummyRoot.Position).Magnitude > MAX_DISTANCE + 2 then
            return
        end

        local now = os.clock()
        if cooldowns[player] and now - cooldowns[player] < COOLDOWN then
            return
        end
        cooldowns[player] = now

        dummyRoot:SetNetworkOwner(nil)
        local impulse = (Vector3.new(0, 65, 0) + playerRoot.CFrame.LookVector * 45)
            * dummyRoot.AssemblyMass
        dummyRoot:ApplyImpulse(impulse)
    end)

    print("[AKScripts] Test dummy launcher ready.")
end

local dummy = workspace:FindFirstChild(DUMMY_NAME)
if dummy then
    setupDummy(dummy)
else
    workspace.ChildAdded:Connect(function(child)
        if child.Name == DUMMY_NAME then
            task.wait(0.2)
            setupDummy(child)
        end
    end)
end

Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)
