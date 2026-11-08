-- AXScripts Loader
-- Stable LucidUI startup with visible diagnostics.
-- Farm tab is limited to NPC/dummy monitoring in a place you own.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
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

-- Detect touch devices directly so landscape phones are still treated as mobile.
local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local isMobile = UserInputService.TouchEnabled

local windowWidth = isMobile
    and math.floor(math.clamp(viewport.X * 0.92, 320, 420))
    or 680
local windowHeight = isMobile
    and math.floor(math.clamp(viewport.Y * 0.78, 350, 500))
    or 500

local windowOk, Window = pcall(function()
    local window = LucidUI:CreateWindow({
        Name = "AKScripts",
        Width = windowWidth,
        Height = windowHeight,
        Theme = "Void",
        IntroEnabled = false
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

-- Auto Fight only targets NPCs/dummies in this place.
-- The game's own combat module must expose these methods:
-- _G.AXScriptsCombat.LightAttack(targetModel)
-- _G.AXScriptsCombat.UseAvailableSkills(targetModel)
local autoM1Enabled = false
local autoSkillsEnabled = false
-- These two are configuration placeholders; no block/counter actions are connected.
local smartBlockEnabled = false
local autoCounterEnabled = false
local autoFightElapsed = 0
local autoFightStatus = "Waiting for game combat integration"

-- Animation detector is limited to tagged practice NPCs in Roblox Studio.
local PRACTICE_NPC_TAG = "AXPracticeNPC"
local animationDetectionEnabled = false
local animationAnimatorConnections = {}
local animationModelConnections = {}
local animationTagAddedConnection = nil
local animationEvents = {}
local animationClassesById = {}
local lastAnimationEvent = nil
local animationDetectionStartedAt = 0
local detectorPanel = nil
local detectorStatusLabel = nil
local detectorStatsLabel = nil
local detectorLogLabel = nil
local detectorStartButton = nil
local detectorDragConnections = {}
local manualTimingSession = false
local manualSessionStartedAt = 0
local manualAttackStartedAt = nil
local manualTimingRecords = {}
local lastManualTimingMs = nil
local RefreshAnimationDetectorPanel = function() end

local function IsPracticeNPC(model)
    return typeof(model) == "Instance"
        and model:IsA("Model")
        and model:IsDescendantOf(Workspace)
        and CollectionService:HasTag(model, PRACTICE_NPC_TAG)
        and Players:GetPlayerFromCharacter(model) == nil
end

local function RecordPracticeAnimation(model, track)
    if not animationDetectionEnabled or not IsPracticeNPC(model) then
        return
    end

    local animation = track and track.Animation
    local animationId = animation and animation.AnimationId or "Unknown"
    local classification = animationClassesById[animationId] or "UNREVIEWED"
    local eventRecord = {
        Model = model.Name,
        AnimationId = animationId,
        Classification = classification,
        Elapsed = os.clock() - animationDetectionStartedAt,
        Priority = track and track.Priority and track.Priority.Name or "Unknown",
        Length = track and tonumber(track.Length) or 0,
    }

    table.insert(animationEvents, eventRecord)
    lastAnimationEvent = eventRecord

    print(string.format(
        "[AXScripts Detector] %s | NPC=%s | ID=%s | t=%.0fms | priority=%s | length=%.2fs",
        classification,
        eventRecord.Model,
        tostring(animationId),
        eventRecord.Elapsed * 1000,
        eventRecord.Priority,
        eventRecord.Length
    ))
    RefreshAnimationDetectorPanel()
end

local function AttachPracticeAnimator(model, animator)
    if not animationDetectionEnabled
        or not IsPracticeNPC(model)
        or not animator:IsA("Animator")
        or animationAnimatorConnections[animator] then
        return
    end

    animationAnimatorConnections[animator] = animator.AnimationPlayed:Connect(function(track)
        RecordPracticeAnimation(model, track)
    end)
end

local function AttachPracticeNPC(model)
    if not animationDetectionEnabled or not IsPracticeNPC(model) or animationModelConnections[model] then
        return
    end

    local modelConnections = {}
    animationModelConnections[model] = modelConnections

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("Animator") then
            AttachPracticeAnimator(model, descendant)
        end
    end

    modelConnections.DescendantAdded = model.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Animator") then
            AttachPracticeAnimator(model, descendant)
        end
    end)
end

local function StopAnimationDetector()
    animationDetectionEnabled = false

    for _, connection in pairs(animationAnimatorConnections) do
        connection:Disconnect()
    end
    table.clear(animationAnimatorConnections)

    for _, connections in pairs(animationModelConnections) do
        for _, connection in pairs(connections) do
            connection:Disconnect()
        end
    end
    table.clear(animationModelConnections)

    if animationTagAddedConnection then
        animationTagAddedConnection:Disconnect()
        animationTagAddedConnection = nil
    end
    RefreshAnimationDetectorPanel()
end

local function StartAnimationDetector()
    if not RunService:IsStudio() then
        return false, "Studio-only: use this tester in a place you control."
    end

    StopAnimationDetector()
    table.clear(animationEvents)
    lastAnimationEvent = nil
    animationDetectionStartedAt = os.clock()
    animationDetectionEnabled = true

    for _, model in ipairs(CollectionService:GetTagged(PRACTICE_NPC_TAG)) do
        AttachPracticeNPC(model)
    end

    animationTagAddedConnection = CollectionService:GetInstanceAddedSignal(PRACTICE_NPC_TAG):Connect(function(instance)
        if instance:IsA("Model") then
            AttachPracticeNPC(instance)
        end
    end)

    RefreshAnimationDetectorPanel()
    return true, "Watching tagged practice NPCs."
end

local function ClassifyLastAnimation(classification)
    if not lastAnimationEvent then
        return false, "No animation has been observed yet."
    end

    local animationId = lastAnimationEvent.AnimationId
    if animationId == "Unknown" then
        return false, "The last animation has no readable asset ID."
    end

    animationClassesById[animationId] = classification
    for _, eventRecord in ipairs(animationEvents) do
        if eventRecord.AnimationId == animationId then
            eventRecord.Classification = classification
        end
    end

    lastAnimationEvent.Classification = classification
    RefreshAnimationDetectorPanel()
    return true, "Saved " .. classification .. " label for " .. animationId
end

local function GetAnimationDetectorStatus()
    local attackCount, otherCount, unreviewedCount = 0, 0, 0
    for _, eventRecord in ipairs(animationEvents) do
        if eventRecord.Classification == "ATTACK" then
            attackCount += 1
        elseif eventRecord.Classification == "OTHER" then
            otherCount += 1
        else
            unreviewedCount += 1
        end
    end

    local lastId = lastAnimationEvent and lastAnimationEvent.AnimationId or "none"
    return string.format(
        "Observed: %d | Attack labels: %d | Other labels: %d | Unreviewed: %d | Last ID: %s",
        #animationEvents,
        attackCount,
        otherCount,
        unreviewedCount,
        tostring(lastId)
    )
end

local function CreateDetectorPanelButton(parent, name, caption, position, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = caption
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color or Color3.fromRGB(42, 42, 52)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextColor3 = Color3.fromRGB(240, 240, 245)
    button.TextSize = 11
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    return button
end

local function CreateDetectorPanelLabel(parent, name, caption, position, size, textSize)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = caption
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextColor3 = Color3.fromRGB(225, 225, 235)
    label.TextSize = textSize or 11
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function CreateAnimationDetectorPanel()
    if detectorPanel or not ProtectedGui then
        return
    end

    detectorPanel = Instance.new("Frame")
    detectorPanel.Name = "AnimationDetectorPanel"
    detectorPanel.Size = UDim2.fromOffset(350, 285)
    detectorPanel.Position = UDim2.new(0, 14, 1, -300)
    detectorPanel.BackgroundColor3 = Color3.fromRGB(17, 17, 22)
    detectorPanel.BorderSizePixel = 0
    detectorPanel.Visible = false
    detectorPanel.Parent = ProtectedGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = detectorPanel

    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(75, 75, 88)
    outline.Thickness = 1
    outline.Parent = detectorPanel

    local title = CreateDetectorPanelLabel(
        detectorPanel,
        "Title",
        "AXScripts  /  Attack Animation Tester",
        UDim2.fromOffset(12, 7),
        UDim2.new(1, -48, 0, 24),
        13
    )
    title.Font = Enum.Font.GothamBold
    title.Active = true

    -- Drag the secondary tester panel by its title area (mouse or touch).
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local panelStart = nil

    table.insert(detectorDragConnections, title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
            dragStart = input.Position
            panelStart = detectorPanel.AbsolutePosition
        end
    end))

    table.insert(detectorDragConnections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        local isDragMovement = input.UserInputType == Enum.UserInputType.MouseMovement
            or (dragInput ~= nil and input == dragInput)

        if not isDragMovement then
            return
        end

        local delta = input.Position - dragStart
        local currentCamera = Workspace.CurrentCamera
        local currentViewport = currentCamera and currentCamera.ViewportSize or viewport
        local maxX = math.max(0, currentViewport.X - detectorPanel.AbsoluteSize.X)
        local maxY = math.max(0, currentViewport.Y - detectorPanel.AbsoluteSize.Y)

        detectorPanel.Position = UDim2.fromOffset(
            math.clamp(panelStart.X + delta.X, 0, maxX),
            math.clamp(panelStart.Y + delta.Y, 0, maxY)
        )
    end))

    table.insert(detectorDragConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragInput = nil
        end
    end))

    local closeButton = CreateDetectorPanelButton(
        detectorPanel,
        "Close",
        "X",
        UDim2.new(1, -34, 0, 7),
        UDim2.fromOffset(24, 24),
        Color3.fromRGB(80, 40, 44)
    )
    closeButton.MouseButton1Click:Connect(function()
        detectorPanel.Visible = false
    end)

    detectorStatusLabel = CreateDetectorPanelLabel(
        detectorPanel,
        "Status",
        "Status: stopped",
        UDim2.fromOffset(12, 34),
        UDim2.new(1, -24, 0, 30),
        10
    )
    detectorStatusLabel.TextColor3 = Color3.fromRGB(165, 200, 255)

    detectorStartButton = CreateDetectorPanelButton(
        detectorPanel,
        "StartStop",
        "START DETECTOR",
        UDim2.fromOffset(12, 70),
        UDim2.new(1, -24, 0, 30),
        Color3.fromRGB(42, 65, 90)
    )
    detectorStartButton.MouseButton1Click:Connect(function()
        manualTimingSession = not manualTimingSession
        manualAttackStartedAt = nil
        if manualTimingSession then
            manualSessionStartedAt = os.clock()
            table.clear(manualTimingRecords)
            lastManualTimingMs = nil
            detectorStatusLabel.Text = "Live manual timing session started."
        else
            detectorStatusLabel.Text = "Manual timing session stopped."
        end
        RefreshAnimationDetectorPanel()
    end)

    local attackButton = CreateDetectorPanelButton(
        detectorPanel,
        "MarkAttackStart",
        "MARK ANIMATION START",
        UDim2.fromOffset(12, 107),
        UDim2.new(0.5, -18, 0, 28),
        Color3.fromRGB(35, 75, 58)
    )
    attackButton.MouseButton1Click:Connect(function()
        if not manualTimingSession then
            detectorStatusLabel.Text = "Start a timing session first."
            return
        end

        manualAttackStartedAt = os.clock()
        table.insert(manualTimingRecords, {
            Kind = "ANIMATION START",
            SessionElapsed = manualAttackStartedAt - manualSessionStartedAt,
        })
        detectorStatusLabel.Text = "Animation start marked. Mark when the hit lands."
        RefreshAnimationDetectorPanel()
    end)

    local otherButton = CreateDetectorPanelButton(
        detectorPanel,
        "MarkHitLanded",
        "MARK HIT LANDED",
        UDim2.new(0.5, 6, 0, 107),
        UDim2.new(0.5, -18, 0, 28),
        Color3.fromRGB(82, 58, 43)
    )
    otherButton.MouseButton1Click:Connect(function()
        if not manualTimingSession then
            detectorStatusLabel.Text = "Start a timing session first."
            return
        end
        if not manualAttackStartedAt then
            detectorStatusLabel.Text = "Mark animation start before marking the hit."
            return
        end

        local now = os.clock()
        local elapsedMs = (now - manualAttackStartedAt) * 1000
        lastManualTimingMs = elapsedMs
        table.insert(manualTimingRecords, {
            Kind = "HIT LANDED",
            SessionElapsed = now - manualSessionStartedAt,
            LatencyMs = elapsedMs,
        })
        manualAttackStartedAt = nil
        detectorStatusLabel.Text = string.format("Measured animation-to-hit: %.0f ms", elapsedMs)
        RefreshAnimationDetectorPanel()
    end)

    detectorStatsLabel = CreateDetectorPanelLabel(
        detectorPanel,
        "Stats",
        "Hits measured: 0 | Last: -- | Average: --",
        UDim2.fromOffset(12, 140),
        UDim2.new(1, -24, 0, 27),
        9
    )

    detectorLogLabel = CreateDetectorPanelLabel(
        detectorPanel,
        "RecentEvents",
        "No events yet. Tag a practice dummy with AXPracticeNPC.",
        UDim2.fromOffset(12, 170),
        UDim2.new(1, -24, 1, -180),
        9
    )
    detectorLogLabel.Font = Enum.Font.Code
    detectorLogLabel.TextYAlignment = Enum.TextYAlignment.Top

    RefreshAnimationDetectorPanel()
end

RefreshAnimationDetectorPanel = function()
    if not detectorPanel then
        return
    end

    if manualTimingSession then
        detectorStatusLabel.Text = "LIVE MANUAL TIMING | Mark animation, then hit."
    else
        detectorStatusLabel.Text = "Ready | Works in live games; marks are manual."
    end

    detectorStartButton.Text = manualTimingSession and "STOP TIMING SESSION" or "START TIMING SESSION"

    local hitCount = 0
    local totalLatency = 0
    local visible = {}
    local first = math.max(1, #manualTimingRecords - 7)
    for index, record in ipairs(manualTimingRecords) do
        if record.Kind == "HIT LANDED" and record.LatencyMs then
            hitCount += 1
            totalLatency += record.LatencyMs
        end
        if index >= first then
            if record.LatencyMs then
                table.insert(visible, string.format(
                    "HIT LANDED | %.0fms after animation",
                    record.LatencyMs
                ))
            else
                table.insert(visible, string.format(
                    "ANIMATION START | +%.2fs",
                    record.SessionElapsed
                ))
            end
        end
    end

    local average = hitCount > 0 and string.format("%.0fms", totalLatency / hitCount) or "--"
    local latest = lastManualTimingMs and string.format("%.0fms", lastManualTimingMs) or "--"
    detectorStatsLabel.Text = string.format(
        "Hits measured: %d | Last: %s | Average: %s",
        hitCount,
        latest,
        average
    )
    detectorLogLabel.Text = #visible > 0
        and table.concat(visible, "\n")
        or "Start a session, then mark animation start and hit landed."
end

CreateAnimationDetectorPanel()

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

local function GetNearestPracticeDummy()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local nearest, nearestDistance = nil, attackRange
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
            local humanoid = obj:FindFirstChildOfClass("Humanoid")
            local targetRoot = obj:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and targetRoot then
                local distance = (targetRoot.Position - root.Position).Magnitude
                if distance <= nearestDistance then
                    nearest = obj
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest
end

local function RunAutoFight()
    if not autoM1Enabled and not autoSkillsEnabled then
        return
    end

    local combat = _G.AXScriptsCombat
    if type(combat) ~= "table" then
        autoFightStatus = "Waiting for _G.AXScriptsCombat"
        return
    end

    local target = GetNearestPracticeDummy()
    if not target then
        autoFightStatus = "No practice NPC in range"
        return
    end

    local didWork = false
    if autoM1Enabled and type(combat.LightAttack) == "function" then
        local ok = pcall(combat.LightAttack, target)
        didWork = didWork or ok
    end
    if autoSkillsEnabled and type(combat.UseAvailableSkills) == "function" then
        local ok = pcall(combat.UseAvailableSkills, target)
        didWork = didWork or ok
    end

    if didWork then
        autoFightStatus = "Running on NPC: " .. target.Name
    else
        autoFightStatus = "Combat methods missing or failed"
    end
end

local monitorConnection = RunService.Heartbeat:Connect(function(deltaTime)
    if npcMonitorEnabled then
        npcMonitorElapsed += deltaTime
        if npcMonitorElapsed >= 1 then
            npcMonitorElapsed = 0
            npcCount = CountPracticeDummies()
            SetDiagnostic("NPC monitor active | practice dummies found: " .. npcCount)
        end
    end

    if autoM1Enabled or autoSkillsEnabled then
        autoFightElapsed += deltaTime
        if autoFightElapsed >= 0.2 then
            autoFightElapsed = 0
            RunAutoFight()
        end
    end
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

    -- Farm tab: NPC/dummy practice and Auto Fight integration.
    local FarmTab = Window:CreateTab({Name = "Farm", Icon = "sprout"})
    local AutoFightSection = FarmTab:CreateSection({Name = "Auto Fight (NPC Only)"})

    AutoFightSection:CreateToggle({
        Name = "Auto M1",
        Default = false,
        Callback = function(state)
            autoM1Enabled = state
            autoFightStatus = state and "Auto M1 enabled; checking combat integration" or "Auto M1 disabled"
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = state and "Auto M1 enabled for NPC practice targets." or "Auto M1 disabled."
            })
        end,
    })

    AutoFightSection:CreateToggle({
        Name = "Auto Skills",
        Default = false,
        Callback = function(state)
            autoSkillsEnabled = state
            autoFightStatus = state and "Auto Skills enabled; checking combat integration" or "Auto Skills disabled"
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = state and "Auto Skills enabled for NPC practice targets." or "Auto Skills disabled."
            })
        end,
    })

    AutoFightSection:CreateToggle({
        Name = "Smart Block (configuration only)",
        Default = false,
        Callback = function(state)
            smartBlockEnabled = state
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = state and "Smart Block setting enabled (not connected)." or "Smart Block setting disabled."
            })
        end,
    })

    AutoFightSection:CreateToggle({
        Name = "Auto Counter (configuration only)",
        Default = false,
        Callback = function(state)
            autoCounterEnabled = state
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = state and "Auto Counter setting enabled (not connected)." or "Auto Counter setting disabled."
            })
        end,
    })

    AutoFightSection:CreateButton({
        Name = "Auto Fight Status",
        Callback = function()
            LucidUI:Notify({
                Title = "Auto Fight Status",
                Message = autoFightStatus
            })
        end,
    })

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

    local DetectorSection = FarmTab:CreateSection({Name = "Live Attack Timing Tester"})

    DetectorSection:CreateButton({
        Name = "Open Animation Timing Panel",
        Callback = function()
            if detectorPanel then
                detectorPanel.Visible = true
                RefreshAnimationDetectorPanel()
            end
        end,
    })

    DetectorSection:CreateButton({
        Name = "Animation Timing Status",
        Callback = function()
            LucidUI:Notify({
                Title = "Animation Detector",
                Message = GetAnimationDetectorStatus()
            })
        end,
    })

    FarmSection:CreateSlider({
        Name = "Practice Range",
        Min = 5,
        Max = 30,
        Default = 10,
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
    StopAnimationDetector()
    for _, connection in ipairs(detectorDragConnections) do
        connection:Disconnect()
    end
    table.clear(detectorDragConnections)
    if previousCleanup then
        pcall(previousCleanup)
    end
    if ProtectedGui then
        ProtectedGui:Destroy()
    end
end
