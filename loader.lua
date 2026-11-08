-- // Anti-Reset Guard & Loader \\ --
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Visible startup diagnostics: this remains independent of LucidUI.
local DiagnosticGui = Instance.new("ScreenGui")
DiagnosticGui.Name = "AXScripts_Diagnostics"
DiagnosticGui.ResetOnSpawn = false
DiagnosticGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local DiagnosticLabel = Instance.new("TextLabel")
DiagnosticLabel.Size = UDim2.fromOffset(300, 58)
DiagnosticLabel.Position = UDim2.new(0.5, -150, 0, 18)
DiagnosticLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
DiagnosticLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DiagnosticLabel.TextWrapped = true
DiagnosticLabel.TextSize = 14
DiagnosticLabel.Font = Enum.Font.GothamBold
DiagnosticLabel.Text = "AXScripts: starting loader..."
DiagnosticLabel.Parent = DiagnosticGui

local function SetDiagnostic(message)
    DiagnosticLabel.Text = "AXScripts: " .. message
    warn("[AXScripts] " .. message)
end

SetDiagnostic("diagnostics active; loading LucidUI")

if _G.AKScriptsLoaded then
    pcall(function() _G.AKScriptsLoaded() end)
end

local success, LucidUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
    ))()
end)

if not success or not LucidUI then
    SetDiagnostic("LucidUI load failed: " .. tostring(LucidUI))
    return
end

SetDiagnostic("LucidUI loaded; creating window")

-- // Services \\ --
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camera = Workspace.CurrentCamera

-- Protected container to survive match resets and teleports
local ProtectedGui = Instance.new("ScreenGui")
ProtectedGui.Name = "AKScripts_ProtectedContainer"
ProtectedGui.ResetOnSpawn = false
ProtectedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    ProtectedGui.Parent = CoreGui
end)
if not ProtectedGui.Parent then
    ProtectedGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

_G.AKScriptsLoaded = function()
    ProtectedGui:Destroy()
end

-- // Dynamic Generic Combat & Remote Discovery (Getc Method) \\ --
local function GetAvailableCombatRemotes()
    local remotes = {}
    local possibleFolders = {ReplicatedStorage, ReplicatedStorage:FindFirstChild("Remotes"), ReplicatedStorage:FindFirstChild("Packages")}
    
    for _, folder in ipairs(possibleFolders) do
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local nameLower = obj.Name:lower()
                    if nameLower:find("combat") or nameLower:find("attack") or nameLower:find("skill") or nameLower:find("punch") or nameLower:find("ability") or nameLower:find("action") then
                        table.insert(remotes, obj)
                    end
                end
            end
        end
    end
    return remotes
end

local function FireDynamicCombat(actionType, ...)
    local args = {...}
    task.spawn(function()
        local remotes = GetAvailableCombatRemotes()
        for _, remote in ipairs(remotes) do
            pcall(function()
                remote:FireServer(actionType, table.unpack(args))
            end)
        end
    end)
end

-- Automatically activates any equipped Tool in Character or Backpack
local function ActivateEquippedTools()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function() tool:Activate() end)
            end
        end
    end
    
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function() 
                    tool.Parent = char 
                    tool:Activate() 
                end)
            end
        end
    end
end

-- // Simulated Key Press Utility \\ --
local function SimulateKeyPress(keyCode)
    task.spawn(function()
        if keypress and keyrelease then
            pcall(function()
                keypress(keyCode.Value)
                task.wait(0.05)
                keyrelease(keyCode.Value)
            end)
        else
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end)
        end
    end)
end

-- // Window Setup \\ --
local windowOk, Window = pcall(function()
    return LucidUI:CreateWindow({
        Name = "AKScripts",
        Size = UDim2.new(0, 260, 0, 160),
        CompactMode = true,
        Theme = "Void"
    })
end)

if not windowOk or not Window then
    SetDiagnostic("CreateWindow failed: " .. tostring(Window))
    return
end

SetDiagnostic("window created; building settings panel")

local settingsOk, settingsError = pcall(function()
    Window:BuildSettingsPanel()
end)

if not settingsOk then
    SetDiagnostic("settings panel error: " .. tostring(settingsError))
    return
end

SetDiagnostic("settings built; creating tabs")

pcall(function()
    if LucidUI.SetTheme then
        LucidUI:SetTheme("Void")
    elseif Window.SetTheme then
        Window:SetTheme("Void")
    end
end)

-- // Mobile Toggle Button (Persistent) \\ --
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
    if Window.SetVisible then
        Window:SetVisible(isOpen)
    elseif Window.Toggle then
        Window:Toggle(isOpen)
    end
    ToggleButton.Text = isOpen and "AK" or "Open"
end)

-- // Global States \\ --
local godModeEnabled = false
local infiniteJumpEnabled = false
local espEnabled = true
local boxEspEnabled = false
local selectedPlayer = nil
local playerDropdown = nil
local stickToPlayerEnabled = false
local stickConnection = nil

-- // Optimized Auto-Fight & Generic Skill States \\ --
local autoFightEnabled = false
local autoFightConnection = nil
local attackRange = 7
local targetMode = "Players"

local autoAttackEnabled = true
local autoSkillsEnabled = true

local lastAttackTime = 0
local lastSkillTime = 0

local cachedTargetRoot = nil
local lastTargetSearchTime = 0

-- // Core Feature Loops \\ --
RunService.Stepped:Connect(function()
    if godModeEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = humanoid.MaxHealth
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infiniteJumpEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- // Main Tab \\ --
SetDiagnostic("Main tab created")

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
SetDiagnostic("Visuals tab created")

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
    end,
})

VisualsSection:CreateToggle({
    Name = "Box ESP",
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
        Camera.FieldOfView = value
    end,
})

-- // Farm Tab (Optimized Auto-Fight & Dynamic Engine) \\ --
SetDiagnostic("Farm tab created")

local FarmTab = Window:CreateTab({
    Name = "Farm",
    Icon = "sprout"
})

local FarmSection = FarmTab:CreateSection({
    Name = "Auto Fight Settings"
})

local function GetClosestTargetOptimized()
    local now = os.clock()
    if cachedTargetRoot and cachedTargetRoot.Parent and (now - lastTargetSearchTime < 0.2) then
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local tHum = cachedTargetRoot.Parent:FindFirstChildOfClass("Humanoid")
            if tHum and tHum.Health > 0 then
                local dx = cachedTargetRoot.Position.X - myRoot.Position.X
                local dz = cachedTargetRoot.Position.Z - myRoot.Position.Z
                local distSq = (dx * dx) + (dz * dz)
                return cachedTargetRoot, math.sqrt(distSq), distSq
            end
        end
    end

    lastTargetSearchTime = now
    cachedTargetRoot = nil

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, math.huge, math.huge end

    local closestRoot = nil
    local shortestDistSq = math.huge

    if targetMode == "Players" then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local tRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local tHum = player.Character:FindFirstChildOfClass("Humanoid")
                if tRoot and tHum and tHum.Health > 0 then
                    local dx = tRoot.Position.X - myRoot.Position.X
                    local dz = tRoot.Position.Z - myRoot.Position.Z
                    local distSq = (dx * dx) + (dz * dz)
                    if distSq < shortestDistSq then
                        shortestDistSq = distSq
                        closestRoot = tRoot
                    end
                end
            end
        end
    else
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar then
                local tRoot = obj:FindFirstChild("HumanoidRootPart")
                local tHum = obj:FindFirstChildOfClass("Humanoid")
                if tRoot and tHum and tHum.Health > 0 then
                    local dx = tRoot.Position.X - myRoot.Position.X
                    local dz = tRoot.Position.Z - myRoot.Position.Z
                    local distSq = (dx * dx) + (dz * dz)
                    if distSq < shortestDistSq then
                        shortestDistSq = distSq
                        closestRoot = tRoot
                    end
                end
            end
        end
    end

    cachedTargetRoot = closestRoot
    return closestRoot, math.sqrt(shortestDistSq), shortestDistSq
end

local function StartAutoFight()
    if autoFightConnection then
        autoFightConnection:Disconnect()
        autoFightConnection = nil
    end

    autoFightConnection = RunService.Heartbeat:Connect(function()
        if not autoFightEnabled then
            if autoFightConnection then
                autoFightConnection:Disconnect()
                autoFightConnection = nil
            end
            return
        end

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

        if not myRoot or not myHum then return end

        local targetRoot, distance, distanceSquared = GetClosestTargetOptimized()

        if targetRoot then
            local targetX = targetRoot.Position.X
            local currentX = myRoot.Position.X
            local distanceX = math.abs(targetX - currentX)

            if distanceX > attackRange then
                local direction = (targetX > currentX) and 1 or -1
                myRoot.CFrame = myRoot.CFrame + Vector3.new(direction * 0.45, 0, 0)
            else
                local lookDir = (targetX > currentX) and 1 or -1
                myRoot.CFrame = CFrame.new(myRoot.Position) * CFrame.Angles(0, (lookDir == 1 and math.pi/2 or -math.pi/2), 0)

                local now = os.clock()

                -- Generic Auto Attack (M1 / Tool Activation)
                if autoAttackEnabled and (now - lastAttackTime >= 0.35) then
                    lastAttackTime = now
                    FireDynamicCombat("M1")
                    FireDynamicCombat("Attack")
                    ActivateEquippedTools()
                end

                -- Generic Auto Skills (Cycles through Q, E, R simulation & dynamic remote fire)
                if autoSkillsEnabled and (now - lastSkillTime >= 1.5) then
                    lastSkillTime = now
                    FireDynamicCombat("Skill")
                    FireDynamicCombat("Ability")
                    
                    SimulateKeyPress(Enum.KeyCode.Q)
                    task.wait(0.1)
                    SimulateKeyPress(Enum.KeyCode.E)
                    task.wait(0.1)
                    SimulateKeyPress(Enum.KeyCode.R)
                end
            end
        end
    end)
end

FarmSection:CreateToggle({
    Name = "Auto Fight",
    Default = false,
    Callback = function(state)
        autoFightEnabled = state
        if state then
            StartAutoFight()
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = "Dynamic Auto Fight Enabled"
            })
        else
            if autoFightConnection then
                autoFightConnection:Disconnect()
                autoFightConnection = nil
            end
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = "Auto Fight Disabled"
            })
        end
    end,
})

FarmSection:CreateToggle({
    Name = "Auto Attack (M1/Tools)",
    Default = true,
    Callback = function(state)
        autoAttackEnabled = state
    end,
})

FarmSection:CreateToggle({
    Name = "Auto Skills (Q,E,R)",
    Default = true,
    Callback = function(state)
        autoSkillsEnabled = state
    end,
})

FarmSection:CreateDropdown({
    Name = "Target Mode",
    Options = {"Players", "NPCs/Dummies"},
    Default = "Players",
    Callback = function(selected)
        targetMode = selected
    end,
})

FarmSection:CreateSlider({
    Name = "Attack Range",
    Min = 3,
    Max = 15,
    Default = 7,
    Callback = function(value)
        attackRange = value
    end,
})

-- // Troll Tab \\ --
SetDiagnostic("Troll tab created")

local TrollTab = Window:CreateTab({
    Name = "Troll",
    Icon = "laugh"
})

local TrollSection = TrollTab:CreateSection({
    Name = "Troll Features"
})

local function GetPlayerOptions()
    local options = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(options, player.Name)
        end
    end
    return options
end

local function UpdatePlayerDropdown()
    local options = GetPlayerOptions()
    if playerDropdown then
        if playerDropdown.SetOptions then
            playerDropdown:SetOptions(options)
        elseif playerDropdown.Refresh then
            playerDropdown:Refresh(options)
        end
    end
end

playerDropdown = TrollSection:CreateDropdown({
    Name = "Select Player",
    Options = GetPlayerOptions(),
    Default = nil,
    Callback = function(selected)
        selectedPlayer = Players:FindFirstChild(selected)
    end,
})

TrollSection:CreateButton({
    Name = "Refresh Players",
    Callback = function()
        UpdatePlayerDropdown()
        LucidUI:Notify({
            Title = "Players",
            Message = "Player list refreshed."
        })
    end,
})

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    UpdatePlayerDropdown()
end)

Players.PlayerRemoving:Connect(function(player)
    if selectedPlayer == player then
        selectedPlayer = nil
    end
    UpdatePlayerDropdown()
end)

local function StartStickLoop()
    if stickConnection then
        stickConnection:Disconnect()
        stickConnection = nil
    end

    stickConnection = RunService.Heartbeat:Connect(function()
        if not stickToPlayerEnabled then
            if stickConnection then
                stickConnection:Disconnect()
                stickConnection = nil
            end
            return
        end

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

        local targetChar = selectedPlayer and selectedPlayer.Character
        local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

        if myRoot and targetRoot then
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 1, 3)

            for _, part in ipairs(myChar:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

TrollSection:CreateToggle({
    Name = "Stick To Player",
    Default = false,
    Callback = function(state)
        stickToPlayerEnabled = state
        
        if state then
            if not selectedPlayer then
                LucidUI:Notify({
                    Title = "Stick To Player",
                    Message = "Please select a target player first."
                })
                return
            end

            LucidUI:Notify({
                Title = "Stick To Player",
                Message = "Sticking to " .. selectedPlayer.Name
            })
            
            StartStickLoop()
        else
            if stickConnection then
                stickConnection:Disconnect()
                stickConnection = nil
            end
            
            LucidUI:Notify({
                Title = "Stick To Player",
                Message = "Disabled."
            })
        end
    end,
})

TrollSection:CreateButton({
    Name = "Fling Player",
    Callback = function()
        if not selectedPlayer then
            LucidUI:Notify({
                Title = "Fling Player",
                Message = "Please select a player first."
            })
            return
        end

        local myChar = LocalPlayer.Character
        local targetChar = selectedPlayer.Character

        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

        if not myRoot or not targetRoot then
            LucidUI:Notify({
                Title = "Fling Player",
                Message = "Target or your character root part is missing."
            })
            return
        end

        LucidUI:Notify({
            Title = "Flinging",
            Message = "Flinging " .. selectedPlayer.Name .. "..."
        })

        task.spawn(function()
            local oldPos = myRoot.CFrame
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = myRoot

            local bav = Instance.new("BodyAngularVelocity")
            bav.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            bav.AngularVelocity = Vector3.new(0, 35000, 0)
            bav.Parent = myRoot

            local startTime = os.clock()
            while os.clock() - startTime < 1.5 and targetRoot and targetRoot.Parent do
                myRoot.CFrame = targetRoot.CFrame * CFrame.new(math.random(-1, 1), 0, math.random(-1, 1))
                bv.Velocity = Vector3.new(math.random(-500, 500), 5000, math.random(-500, 500))
                RunService.Stepped:Wait()
            end

            bv:Destroy()
            bav:Destroy()
            
            myRoot.Velocity = Vector3.new(0, 0, 0)
            myRoot.CFrame = oldPos

            LucidUI:Notify({
                Title = "Fling Complete",
                Message = "Done flinging " .. selectedPlayer.Name
            })
        end)
    end,
})