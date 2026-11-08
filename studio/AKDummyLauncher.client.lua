-- AKScripts Studio-only test feature
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Add the "LaunchDummy" tag to a dummy model in Workspace.
-- The dummy model should contain a HumanoidRootPart.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("AKLaunchDummy")

local gui = Instance.new("ScreenGui")
gui.Name = "AKDummyLauncher"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "LaunchDummyButton"
button.Size = UDim2.fromOffset(170, 44)
button.Position = UDim2.new(0, 16, 0.5, -22)
button.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
button.TextColor3 = Color3.fromRGB(240, 240, 245)
button.Text = "Launch Test Dummy"
button.TextSize = 14
button.Font = Enum.Font.GothamBold
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

button.Activated:Connect(function()
    local dummy = workspace:FindFirstChild("TestDummy")
    if not dummy or not dummy:IsA("Model") then
        button.Text = "TestDummy not found"
        task.delay(1.5, function()
            if button.Parent then
                button.Text = "Launch Test Dummy"
            end
        end)
        return
    end

    event:FireServer(dummy)
end)
