local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AXScriptsUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 170)
frame.Position = UDim2.new(0.5, -140, 0.5, -85)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.BackgroundTransparency = 1
title.Text = "AXScripts"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 22
title.Font = Enum.Font.GothamBold
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 35)
status.Position = UDim2.fromOffset(0, 55)
status.BackgroundTransparency = 1
status.Text = "UI loaded successfully"
status.TextColor3 = Color3.fromRGB(120, 220, 150)
status.TextSize = 14
status.Font = Enum.Font.Gotham
status.Parent = frame
