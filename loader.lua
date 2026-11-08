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

-- Read-only monitor for character animations replicated to this client.
-- Uses documented Animator events/properties only; it does not call combat remotes.
local animationDetectionEnabled = false
local matchIsActive = false
local matchPollConnection = nil
local matchPollElapsed = 0
local animationAnimatorConnections = {}
local animationModelConnections = {}
local animationPlayerConnections = {}
local animationPlayersAddedConnection = nil
local animationPlayersRemovingConnection = nil
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
local RefreshAnimationDetectorPanel = function() end

local function IsOpponentCharacter(player, character)
    return player ~= nil
        and player ~= LocalPlayer
        and character ~= nil
        and character:IsA("Model")
        and player.Character == character
end

local function RecordOpponentAnimation(player, track, source)
    if not animationDetectionEnabled or not matchIsActive or not player or player == LocalPlayer then
        return
    end

    local animation = track and track.Animation
    local animationId = animation and animation.AnimationId or "Unknown"
    local eventRecord = {
        Player = player.Name,
        AnimationId = animationId,
        Classification = animationClassesById[animationId] or "UNREVIEWED",
        Elapsed = os.clock() - animationDetectionStartedAt,
        Priority = track and track.Priority and track.Priority.Name or "Unknown",
        Length = track and tonumber(track.Length) or 0,
        Source = source or "LIVE",
    }

    table.insert(animationEvents, eventRecord)
    if #animationEvents > 80 then
        table.remove(animationEvents, 1)
    end
    lastAnimationEvent = eventRecord

    print(string.format(
        "[AXScripts Animation Monitor] %s | Player=%s | ID=%s | +%.0fms | %s | priority=%s | length=%.2fs",
        eventRecord.Classification,
        eventRecord.Player,
        tostring(animationId),
        eventRecord.Elapsed * 1000,
        eventRecord.Source,
        eventRecord.Priority,
        eventRecord.Length
    ))

    RefreshAnimationDetectorPanel()
end

local function AttachOpponentAnimator(player, character, animator)
    if not animationDetectionEnabled
        or not matchIsActive
        or not IsOpponentCharacter(player, character)
        or not animator:IsA("Animator")
        or animationAnimatorConnections[animator] then
        return
    end

    local connection = animator.AnimationPlayed:Connect(function(track)
        RecordOpponentAnimation(player, track, "LIVE")
    end)

    animationAnimatorConnections[animator] = {
        Connection = connection,
        Player = player,
        Character = character,
    }

    -- Snapshot current tracks separately so they are not mistaken for fresh starts.
    local ok, tracks = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if ok and type(tracks) == "table" then
        for _, track in ipairs(tracks) do
            if track and track.IsPlaying then
                RecordOpponentAnimation(player, track, "ACTIVE")
            end
        end
    end
end

local function AttachOpponentCharacter(player, character)
    if not animationDetectionEnabled
        or not IsOpponentCharacter(player, character)
        or animationModelConnections[character] then
        return
    end

    local connections = {}
    animationModelConnections[character] = connections

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Animator") then
            AttachOpponentAnimator(player, character, descendant)
        end
    end

    connections.DescendantAdded = character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Animator") then
            AttachOpponentAnimator(player, character, descendant)
        end
    end)
end

local function AttachOpponentPlayer(player)
    if not animationDetectionEnabled or player == LocalPlayer then
        return
    end

    if not animationPlayerConnections[player] then
        animationPlayerConnections[player] = player.CharacterAdded:Connect(function(character)
            if matchIsActive then
                AttachOpponentCharacter(player, character)
            end
        end)
    end

    if matchIsActive and player.Character then
        AttachOpponentCharacter(player, player.Character)
    end
end

local function IsMatchTimerVisible()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return false, nil
    end

    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            local timerText = tostring(object.Text or ""):gsub("%s+", "")
            if string.match(timerText, "^%d+:%d%d$") then
                local visible = object.Visible
                local ancestor = object.Parent

                while visible and ancestor and ancestor ~= playerGui do
                    if ancestor:IsA("GuiObject") and not ancestor.Visible then
                        visible = false
                        break
                    end
                    if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
                        visible = false
                        break
                    end
                    ancestor = ancestor.Parent
                end

                if visible then
                    return true, timerText
                end
            end
        end
    end

    return false, nil
end

local function DetachOpponentPlayer(player)
    local playerConnection = animationPlayerConnections[player]
    if playerConnection then
        playerConnection:Disconnect()
        animationPlayerConnections[player] = nil
    end

    for character, connections in pairs(animationModelConnections) do
        if Players:GetPlayerFromCharacter(character) == player then
            for _, connection in pairs(connections) do
                connection:Disconnect()
            end
            animationModelConnections[character] = nil
        end
    end

    for animator, entry in pairs(animationAnimatorConnections) do
        if entry.Player == player then
            entry.Connection:Disconnect()
            animationAnimatorConnections[animator] = nil
        end
    end
end

local function StopAnimationDetector()
    animationDetectionEnabled = false
    matchIsActive = false
    matchPollElapsed = 0

    if matchPollConnection then
        matchPollConnection:Disconnect()
        matchPollConnection = nil
    end

    for _, entry in pairs(animationAnimatorConnections) do
        entry.Connection:Disconnect()
    end
    table.clear(animationAnimatorConnections)

    for _, connections in pairs(animationModelConnections) do
        for _, connection in pairs(connections) do
            connection:Disconnect()
        end
    end
    table.clear(animationModelConnections)

    for _, connection in pairs(animationPlayerConnections) do
        connection:Disconnect()
    end
    table.clear(animationPlayerConnections)

    if animationPlayersAddedConnection then
        animationPlayersAddedConnection:Disconnect()
        animationPlayersAddedConnection = nil
    end
    if animationPlayersRemovingConnection then
        animationPlayersRemovingConnection:Disconnect()
        animationPlayersRemovingConnection = nil
    end

    RefreshAnimationDetectorPanel()
end

local function StartAnimationDetector()
    StopAnimationDetector()
    table.clear(animationEvents)
    lastAnimationEvent = nil
    animationDetectionStartedAt = os.clock()
    animationDetectionEnabled = true

    local timerVisible = IsMatchTimerVisible()
    matchIsActive = timerVisible

    for _, player in ipairs(Players:GetPlayers()) do
        AttachOpponentPlayer(player)
    end

    animationPlayersAddedConnection = Players.PlayerAdded:Connect(function(player)
        AttachOpponentPlayer(player)
    end)

    animationPlayersRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        DetachOpponentPlayer(player)
    end)

    matchPollConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not animationDetectionEnabled then
            return
        end

        matchPollElapsed += deltaTime
        if matchPollElapsed < 0.25 then
            return
        end
        matchPollElapsed = 0

        local timerNowVisible = IsMatchTimerVisible()
        if timerNowVisible ~= matchIsActive then
            matchIsActive = timerNowVisible

            if matchIsActive then
                for _, player in ipairs(Players:GetPlayers()) do
                    AttachOpponentPlayer(player)
                end
                detectorStatusLabel.Text = "Match timer found. Monitoring opponent animations."
            else
                for _, player in ipairs(Players:GetPlayers()) do
                    DetachOpponentPlayer(player)
                end
                detectorStatusLabel.Text = "Match timer hidden. Lobby monitoring paused."
            end

            RefreshAnimationDetectorPanel()
        end
    end)

    RefreshAnimationDetectorPanel()
    if matchIsActive then
        return true, "Match timer found. Watching opponent animations."
    end
    return true, "Waiting for the match timer to appear."
end

local function ClassifyLastAnimation(classification)
    if not lastAnimationEvent then
        return false, "No opponent animation has been observed yet."
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
        "Observed: %d | Attack IDs: %d | Other IDs: %d | Unreviewed: %d | Last ID: %s",
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
        "AXScripts  /  Opponent Animation Monitor",
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
        if animationDetectionEnabled then
            StopAnimationDetector()
        else
            local started, message = StartAnimationDetector()
            if not started then
                detectorStatusLabel.Text = message
            end
        end
        RefreshAnimationDetectorPanel()
    end)

    local attackButton = CreateDetectorPanelButton(
        detectorPanel,
        "MarkAttack",
        "MARK LAST: ATTACK",
        UDim2.fromOffset(12, 107),
        UDim2.new(0.5, -18, 0, 28),
        Color3.fromRGB(35, 75, 58)
    )
    attackButton.MouseButton1Click:Connect(function()
        local ok, message = ClassifyLastAnimation("ATTACK")
        detectorStatusLabel.Text = message
        RefreshAnimationDetectorPanel()
    end)

    local otherButton = CreateDetectorPanelButton(
        detectorPanel,
        "MarkOther",
        "MARK LAST: OTHER",
        UDim2.new(0.5, 6, 0, 107),
        UDim2.new(0.5, -18, 0, 28),
        Color3.fromRGB(82, 58, 43)
    )
    otherButton.MouseButton1Click:Connect(function()
        local ok, message = ClassifyLastAnimation("OTHER")
        detectorStatusLabel.Text = message
        RefreshAnimationDetectorPanel()
    end)

    detectorStatsLabel = CreateDetectorPanelLabel(
        detectorPanel,
        "Stats",
        "Events: 0 | Attack: 0 | Other: 0 | Unreviewed: 0",
        UDim2.fromOffset(12, 140),
        UDim2.new(1, -24, 0, 27),
        9
    )

    detectorLogLabel = CreateDetectorPanelLabel(
        detectorPanel,
        "RecentEvents",
        "No opponent animation events yet. Start the monitor first.",
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

    if not animationDetectionEnabled then
        detectorStatusLabel.Text = "Stopped | Start to watch opponent animations."
    elseif matchIsActive then
        detectorStatusLabel.Text = "Match timer detected | Monitoring opponents."
    else
        detectorStatusLabel.Text = "Waiting for match timer | Lobby paused."
    end

    detectorStartButton.Text = animationDetectionEnabled and "STOP MONITOR" or "START MONITOR"

    local attacks, others, unreviewed = 0, 0, 0
    local visible = {}
    local first = math.max(1, #animationEvents - 7)

    for index, eventRecord in ipairs(animationEvents) do
        if eventRecord.Classification == "ATTACK" then
            attacks += 1
        elseif eventRecord.Classification == "OTHER" then
            others += 1
        else
            unreviewed += 1
        end

        if index >= first then
            table.insert(visible, string.format(
                "%s | %s | %s | +%.0fms%s",
                eventRecord.Classification,
                eventRecord.Player,
                tostring(eventRecord.AnimationId),
                eventRecord.Elapsed * 1000,
                eventRecord.Source == "ACTIVE" and " [already active]" or ""
            ))
        end
    end

    detectorStatsLabel.Text = string.format(
        "Events: %d | Attack: %d | Other: %d | Unreviewed: %d",
        #animationEvents,
        attacks,
        others,
        unreviewed
    )
    detectorLogLabel.Text = #visible > 0
        and table.concat(visible, "\n")
        or "No events yet. Start monitoring and watch a nearby opponent."
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

    local DetectorSection = FarmTab:CreateSection({Name = "Opponent Animation Monitor"})

    DetectorSection:CreateButton({
        Name = "Open Opponent Animation Panel",
        Callback = function()
            if detectorPanel then
                detectorPanel.Visible = true
                RefreshAnimationDetectorPanel()
            end
        end,
    })

    DetectorSection:CreateButton({
        Name = "Opponent Animation Status",
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
