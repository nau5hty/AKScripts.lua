-- AXScripts Loader
-- Stable LucidUI startup with visible diagnostics.
-- Farm tab is limited to NPC/dummy monitoring in a place you own.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Clean up the previous copy, if one is running.
if _G.AKScriptsLoaded then
    pcall(_G.AKScriptsLoaded)
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local DiagnosticGui = Instance.new("ScreenGui")
DiagnosticGui.Name = "AXScripts_Diagnostics"
DiagnosticGui.ResetOnSpawn = false
DiagnosticGui.Parent = PlayerGui

local DiagnosticLabel = Instance.new("TextLabel")
DiagnosticLabel.Size = UDim2.fromOffset(300, 54)
DiagnosticLabel.Position = UDim2.new(0.5, -150, 0, 16)
DiagnosticLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
DiagnosticLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DiagnosticLabel.TextWrapped = true
DiagnosticLabel.TextSize = 14
DiagnosticLabel.Font = Enum.Font.GothamBold
DiagnosticLabel.Text = "AXScripts: starting..."
DiagnosticLabel.Parent = DiagnosticGui

local function SetDiagnostic(message)
    DiagnosticLabel.Text = "AXScripts: " .. tostring(message)
    warn("[AXScripts] " .. tostring(message))
end

local function Cleanup()
    if DiagnosticGui then
        DiagnosticGui:Destroy()
    end
    local oldGui = PlayerGui:FindFirstChild("AKScripts_ProtectedContainer")
    if oldGui then
        oldGui:Destroy()
    end
end

_G.AKScriptsLoaded = Cleanup

SetDiagnostic("loading LucidUI")

local loaded, LucidUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
    ))()
end)

if not loaded or type(LucidUI) ~= "table" then
    SetDiagnostic("LucidUI failed: " .. tostring(LucidUI))
    return
end

SetDiagnostic("LucidUI loaded; creating window")

local windowOk, Window = pcall(function()
    local window = LucidUI:CreateWindow({
        Name = "AKScripts",
        Size = UDim2.new(0, 260, 0, 160),
        CompactMode = true,
        Theme = "Void"
    })
    window:BuildSettingsPanel()
    return window
end)

if not windowOk or not Window then
    SetDiagnostic("window setup failed: " .. tostring(Window))
    return
end

pcall(function()
    if LucidUI.SetTheme then
        LucidUI:SetTheme("Void")
    elseif Window.SetTheme then
        Window:SetTheme("Void")
    end
end)

-- Persistent mobile toggle.
local ProtectedGui = Instance.new("ScreenGui")
ProtectedGui.Name = "AKScripts_ProtectedContainer"
ProtectedGui.ResetOnSpawn = false
ProtectedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ProtectedGui.Parent = PlayerGui

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
ToggleButton.Parent = ProtectedGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

local isOpen = true
ToggleButton.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    pcall(function()
        if Window.SetVisible then
            Window:SetVisible(isOpen)
        elseif Window.Toggle then
            Window:Toggle(isOpen)
        end
    end)
    ToggleButton.Text = isOpen and "AK" or "Open"
end)

local espEnabled = true
local boxEspEnabled = false
local npcMonitorEnabled = false
local npcMonitorElapsed = 0
local npcCount = 0
local attackRange = 7

local function CountPracticeDummies()
    local count = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model")
            and not Players:GetPlayerFromCharacter(obj)
            and obj:FindFirstChildOfClass("Humanoid")
            and obj:FindFirstChild("HumanoidRootPart") then
            count += 1
        end
    end
    return count
end

local monitorConnection = RunService.Heartbeat:Connect(function(deltaTime)
    if not npcMonitorEnabled then
        return
    end

    npcMonitorElapsed += deltaTime
    if npcMonitorElapsed < 1 then
        return
    end

    npcMonitorElapsed = 0
    npcCount = CountPracticeDummies()
    SetDiagnostic("NPC monitor active | practice dummies found: " .. npcCount)
end)

local buildOk, buildError = xpcall(function()
    -- Main tab
    local MainTab = Window:CreateTab({Name = "Main", Icon = "zap"})
    local MainSection = MainTab:CreateSection({Name = "Controls"})

    MainSection:CreateButton({
        Name = "Test Notification",
        Callback = function()
            LucidUI:Notify({
                Title = "AXScripts",
                Message = "The interface is responding."
            })
        end,
    })

    -- Visuals tab
    local VisualsTab = Window:CreateTab({Name = "Visuals", Icon = "eye"})
    local VisualsSection = VisualsTab:CreateSection({Name = "ESP & FOV"})

    VisualsSection:CreateToggle({
        Name = "Player ESP (UI)",
        Default = true,
        Callback = function(state)
            espEnabled = state
        end,
    })

    VisualsSection:CreateToggle({
        Name = "Box ESP (UI)",
        Default = false,
        Callback = function(state)
            boxEspEnabled = state
        end,
    })

    VisualsSection:CreateSlider({
        Name = "Field of View",
        Min = 70,
        Max = 120,
        Default = 70,
        Callback = function(value)
            local camera = Workspace.CurrentCamera
            if camera then
                camera.FieldOfView = value
            end
        end,
    })

    -- Farm tab: safe NPC/dummy monitoring only.
    local FarmTab = Window:CreateTab({Name = "Farm", Icon = "sprout"})
    local FarmSection = FarmTab:CreateSection({Name = "NPC Practice Monitor"})

    FarmSection:CreateToggle({
        Name = "Monitor NPCs / Dummies",
        Default = false,
        Callback = function(state)
            npcMonitorEnabled = state
            npcMonitorElapsed = 1
            if state then
                LucidUI:Notify({
                    Title = "NPC Monitor",
                    Message = "Monitoring NPCs and training dummies in this place."
                })
            else
                SetDiagnostic("NPC monitor stopped")
                LucidUI:Notify({
                    Title = "NPC Monitor",
                    Message = "Monitoring disabled."
                })
            end
        end,
    })

    FarmSection:CreateSlider({
        Name = "Practice Range Display",
        Min = 3,
        Max = 15,
        Default = 7,
        Callback = function(value)
            attackRange = value
        end,
    })

    FarmSection:CreateButton({
        Name = "Count NPCs / Dummies",
        Callback = function()
            npcCount = CountPracticeDummies()
            LucidUI:Notify({
                Title = "Practice Dummies",
                Message = tostring(npcCount) .. " NPC/dummy model(s) found."
            })
        end,
    })

    -- Keep the original tab in the layout without player-targeting actions.
    local TrollTab = Window:CreateTab({Name = "Troll", Icon = "laugh"})
    local TrollSection = TrollTab:CreateSection({Name = "Utilities"})
    TrollSection:CreateButton({
        Name = "Status",
        Callback = function()
            LucidUI:Notify({
                Title = "AXScripts",
                Message = "Player fling and forced player-movement actions are not included."
            })
        end,
    })
end, debug.traceback)

if not buildOk then
    SetDiagnostic("UI build error: " .. tostring(buildError))
    return
end

SetDiagnostic("UI loaded successfully")

task.delay(8, function()
    if DiagnosticGui and DiagnosticGui.Parent then
        DiagnosticGui:Destroy()
    end
end)

-- Clean up background work when this loader is replaced.
local previousCleanup = _G.AKScriptsLoaded
_G.AKScriptsLoaded = function()
    if monitorConnection then
        monitorConnection:Disconnect()
        monitorConnection = nil
    end
    if previousCleanup then
        pcall(previousCleanup)
    end
    if ProtectedGui then
        ProtectedGui:Destroy()
    end
end
