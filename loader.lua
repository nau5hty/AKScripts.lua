
local LucidUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
))()

-- // Services \\ --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui

-- // Window \\ --
local Window = LucidUI:CreateWindow({
    Name = "AKScripts",
    Size = UDim2.new(0, 260, 0, 160),
    CompactMode = true,
    Theme = "Void"
})

Window:BuildSettingsPanel()

pcall(function()
    if LucidUI.SetTheme then
        LucidUI:SetTheme("Void")
    elseif Window.SetTheme then
        Window:SetTheme("Void")
    end
end)

-- // Mobile Toggle \\ --
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AKScriptsMobileToggle"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "SideToggle"
ToggleButton.Size = UDim2.new(0, 45, 0, 40)
ToggleButton.Position = UDim2.new(1, -60, 0, 15)
ToggleButton.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
ToggleButton.BorderColor3 = Color3.fromRGB(70, 70, 80)
ToggleButton.BorderSizePixel = 2
ToggleButton.Text = "AK"
ToggleButton.TextColor3 = Color3.fromRGB(220, 220, 230)
ToggleButton.TextSize = 13
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Active = true
ToggleButton.Draggable = true
ToggleButton.ZIndex = 999
ToggleButton.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

-- // Open / Close \\ --
local isOpen = true

ToggleButton.MouseButton1Click:Connect(function()
    isOpen = not isOpen

    if Window.SetVisible then
        Window:SetVisible(isOpen)
    elseif Window.Toggle then
        Window:Toggle(isOpen)
    end

    ToggleButton.Text = isOpen and "AK" or "Open"
end)

-- // States \\ --
local godModeEnabled = false
local infiniteJumpEnabled = false
local espEnabled = true
local boxEspEnabled = false

-- // God Mode Loop \\ --
RunService.Stepped:Connect(function()
    if godModeEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = humanoid.MaxHealth
        end
    end
end)

-- // Infinite Jump \\ --
UserInputService.JumpRequest:Connect(function()
    if infiniteJumpEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- // Main Tab \\ --
local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "zap"
})

local MainSection = MainTab:CreateSection({
    Name = "Controls"
})

MainSection:CreateButton({
    Name = "Click",
    Callback = function()
        LucidUI:Notify({
            Title = "Done",
            Message = "Button clicked successfully."
        })
    end,
})

MainSection:CreateToggle({
    Name = "God Mode",
    Default = false,
    Callback = function(state)
        godModeEnabled = state
        LucidUI:Notify({
            Title = "God Mode",
            Message = "State set to: " .. tostring(state)
        })
    end,
})

MainSection:CreateToggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(state)
        infiniteJumpEnabled = state
        LucidUI:Notify({
            Title = "Infinite Jump",
            Message = "State set to: " .. tostring(state)
        })
    end,
})

-- // Visuals Tab \\ --
local VisualsTab = Window:CreateTab({
    Name = "Visuals",
    Icon = "eye"
})

local VisualsSection = VisualsTab:CreateSection({
    Name = "ESP & FOV"
})

VisualsSection:CreateToggle({
    Name = "Player ESP",
    Default = true,
    Callback = function(state)
        espEnabled = state
        print("Player ESP: " .. tostring(state))
    end,
})

VisualsSection:CreateToggle({
    Name = "Box ESP",
    Default = false,
    Callback = function(state)
        boxEspEnabled = state
        print("Box ESP: " .. tostring(state))
    end,
})

VisualsSection:CreateSlider({
    Name = "Field of View",
    Min = 70,
    Max = 120,
    Default = 70,
    Callback = function(value)
        Camera.FieldOfView = value
    end,
})

VisualsSection:CreateDropdown({
    Name = "ESP Theme",
    Options = {"Red", "Green", "Blue", "Rainbow"},
    Default = "Red",
    Callback = function(selected)
        print("ESP Theme selected: " .. tostring(selected))
    end,
})

VisualsSection:CreateColorPicker({
    Name = "ESP Color",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        print("ESP Color changed!")
    end,
})

-- // Farm Tab \\ --
local FarmTab = Window:CreateTab({
    Name = "Farm",
    Icon = "sprout"
})

local FarmSection = FarmTab:CreateSection({
    Name = "Farming"
})

-- // Troll Tab \\ --
local TrollTab = Window:CreateTab({
    Name = "Troll",
    Icon = "laugh"
})

local TrollSection = TrollTab:CreateSection({
    Name = "Troll Features"
})

-- // Player Selector \\ --
local selectedPlayer = nil

local function GetPlayers()
    local options = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(options, player.Name)
        end
    end

    return options
end

TrollSection:CreateDropdown({
    Name = "Select Player",
    Options = GetPlayers(),
    Default = nil,
    Callback = function(selected)
        selectedPlayer = Players:FindFirstChild(selected)
    end,
})

TrollSection:CreateButton({
    Name = "Refresh Players",
    Callback = function()
        LucidUI:Notify({
            Title = "Players",
            Message = "Player list refreshed."
        })
    end,
})

-- // Stick To Player \\ --
TrollSection:CreateToggle({
    Name = "Stick To Player",
    Default = false,
    Callback = function(state)
        print("Stick To Player:", state)
    end,
})

-- // Fling Nearby (Unavailable) \\ --
TrollSection:CreateToggle({
    Name = "Fling Nearby (Unavailable)",
    Default = false,
    Callback = function(state)
        if state then
            LucidUI:Notify({
                Title = "Feature Unavailable",
                Message = "This client-only script has no server-side fling handler."
            })
        end
    end,
})
