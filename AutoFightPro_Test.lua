-- AXScripts Auto Fight Pro - UI Test Build
-- Standalone UI prototype for a Roblox Studio place you control.
-- This file intentionally contains NO combat remotes, executor hooks,
-- player-targeting automation, or calls into Anime vs Anime.
-- The controls below are UI/configuration placeholders for later
-- integration with an authorised combat API.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local previous = playerGui:FindFirstChild("AXSAutoFightTest")
if previous then
    previous:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AXSAutoFightTest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local state = {
    autoM1 = false,
    autoSkills = false,
    smartBlock = false,
    autoCounter = false,
    range = 10,
}

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local panel = make("Frame", {
    Name = "Panel",
    Size = UDim2.fromOffset(320, 390),
    Position = UDim2.new(0.5, -160, 0.5, -195),
    BackgroundColor3 = Color3.fromRGB(18, 19, 25),
    BorderSizePixel = 0,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
make("UIStroke", {
    Color = Color3.fromRGB(190, 145, 55),
    Thickness = 1.5,
    Transparency = 0.15,
}, panel)

local title = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.fromOffset(12, 10),
    BackgroundTransparency = 1,
    Text = "AXSCRIPTS  /  AUTO FIGHT PRO",
    TextColor3 = Color3.fromRGB(245, 210, 130),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local subtitle = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 22),
    Position = UDim2.fromOffset(12, 43),
    BackgroundTransparency = 1,
    Text = "Standalone configuration preview",
    TextColor3 = Color3.fromRGB(155, 160, 175),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local contentFrame = make("Frame", {
    Size = UDim2.new(1, -24, 0, 210),
    Position = UDim2.fromOffset(12, 76),
    BackgroundTransparency = 1,
}, panel)
make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, contentFrame)

local status = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 42),
    Position = UDim2.new(0, 12, 1, -55),
    BackgroundColor3 = Color3.fromRGB(29, 31, 40),
    Text = "STATUS: UI READY  |  COMBAT NOT CONNECTED",
    TextColor3 = Color3.fromRGB(235, 195, 105),
    Font = Enum.Font.GothamSemibold,
    TextSize = 10,
    TextWrapped = true,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, status)

local function logChange(name, enabled)
    status.Text = name .. (enabled and ": ON" or ": OFF")
    print("[AXScripts Auto Fight Test] " .. status.Text)
end

local function addToggle(label, key)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(29, 31, 40),
        BorderSizePixel = 0,
    }, contentFrame)
    make("UICorner", {CornerRadius = UDim.new(0, 7)}, row)

    make("TextLabel", {
        Size = UDim2.new(1, -75, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(235, 237, 245),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local button = make("TextButton", {
        Size = UDim2.fromOffset(54, 24),
        Position = UDim2.new(1, -64, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(65, 68, 80),
        Text = "OFF",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        AutoButtonColor = true,
    }, row)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, button)

    button.MouseButton1Click:Connect(function()
        state[key] = not state[key]
        button.Text = state[key] and "ON" or "OFF"
        button.BackgroundColor3 = state[key]
            and Color3.fromRGB(135, 98, 35)
            or Color3.fromRGB(65, 68, 80)
        logChange(label, state[key])
    end)
end

addToggle("Auto M1 (configuration only)", "autoM1")
addToggle("Auto Skills (configuration only)", "autoSkills")
addToggle("Smart Block (configuration only)", "smartBlock")
addToggle("Auto Counter (configuration only)", "autoCounter")

local rangeRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = Color3.fromRGB(29, 31, 40),
    BorderSizePixel = 0,
}, contentFrame)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, rangeRow)

make("TextLabel", {
    Size = UDim2.new(0.55, 0, 1, 0),
    Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1,
    Text = "Practice range",
    TextColor3 = Color3.fromRGB(235, 237, 245),
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, rangeRow)

local rangeValue = make("TextLabel", {
    Size = UDim2.fromOffset(45, 30),
    Position = UDim2.new(1, -55, 0.5, -15),
    BackgroundTransparency = 1,
    Text = tostring(state.range),
    TextColor3 = Color3.fromRGB(245, 210, 130),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
}, rangeRow)

local minus = make("TextButton", {
    Size = UDim2.fromOffset(25, 25),
    Position = UDim2.new(1, -112, 0.5, -12),
    BackgroundColor3 = Color3.fromRGB(55, 58, 70),
    Text = "-",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
}, rangeRow)
make("UICorner", {CornerRadius = UDim.new(0, 5)}, minus)

local plus = make("TextButton", {
    Size = UDim2.fromOffset(25, 25),
    Position = UDim2.new(1, -82, 0.5, -12),
    BackgroundColor3 = Color3.fromRGB(55, 58, 70),
    Text = "+",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
}, rangeRow)
make("UICorner", {CornerRadius = UDim.new(0, 5)}, plus)

local function changeRange(amount)
    state.range = math.clamp(state.range + amount, 5, 30)
    rangeValue.Text = tostring(state.range)
    status.Text = "PRACTICE RANGE SET TO " .. state.range .. " STUDS"
end

minus.MouseButton1Click:Connect(function()
    changeRange(-1)
end)
plus.MouseButton1Click:Connect(function()
    changeRange(1)
end)

local close = make("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0, 10),
    BackgroundColor3 = Color3.fromRGB(55, 38, 38),
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 220, 220),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, close)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Drag support for desktop and touch.
local dragging = false
local dragInput
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

print("[AXScripts Auto Fight Test] UI loaded. No combat actions are connected.")
