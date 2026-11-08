-- AKScripts Studio-only test feature
-- Place this Script in ServerScriptService.
-- Only models tagged "LaunchDummy" can be launched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local event = ReplicatedStorage:FindFirstChild("AKLaunchDummy")
if not event then
    event = Instance.new("RemoteEvent")
    event.Name = "AKLaunchDummy"
    event.Parent = ReplicatedStorage
end

local cooldowns = {}

event.OnServerEvent:Connect(function(player, dummy)
    if typeof(dummy) ~= "Instance" or not dummy:IsA("Model") then
        return
    end

    if not dummy:IsDescendantOf(workspace) then
        return
    end

    if not CollectionService:HasTag(dummy, "LaunchDummy") then
        return
    end

    local character = player.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")

    if not playerRoot or not dummyRoot or not dummyRoot:IsA("BasePart") then
        return
    end

    if (playerRoot.Position - dummyRoot.Position).Magnitude > 18 then
        return
    end

    local now = os.clock()
    if cooldowns[player] and now - cooldowns[player] < 2 then
        return
    end
    cooldowns[player] = now

    dummyRoot:SetNetworkOwner(nil)
    local launchVelocity = Vector3.new(0, 65, 0) + playerRoot.CFrame.LookVector * 45
    dummyRoot:ApplyImpulse(launchVelocity * dummyRoot.AssemblyMass)
end)

Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)
