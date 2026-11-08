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
local animationPlayerRange = 120
local animationAnimatorConnections = {}
local animationModelConnections = {}
local animationBotModelConnections = {}
local animationPlayerConnections = {}
local animationWorkspaceAddedConnection = nil
local animationPlayersAddedConnection = nil
local animationPlayersRemovingConnection = nil
-- animationEvents stores one catalogue row per actor + animation ID (player or bot).
local animationEvents = {}
local animationCatalogueByKey = {}
local animationClassesById = {}
local lastAnimationEvent = nil
local animationTotalPlays = 0
local animationPanelLastRefresh = 0
local animationDetectionStartedAt = 0
local detectorPanel = nil
local detectorStatusLabel = nil
local detectorStatsLabel = nil
local detectorLogLabel = nil
local detectorStartButton = nil
local detectorDragConnections = {}
local RefreshAnimationDetectorPanel = function() end

-- Read-only HUD monitor state; kept separate from the animation detector.
local hudMonitorEnabled = true
local hudMonitorElapsed = 0
local hudMonitorParagraph = nil
local hudMonitorPrevious = nil
local hudMonitorHistory = {}

local function IsOpponentCharacter(player, character)
    if player == nil
        or player == LocalPlayer
        or character == nil
        or not character:IsA("Model")
        or player.Character ~= character then
        return false
    end

    local localCharacter = LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local targetRoot = character:FindFirstChild("HumanoidRootPart")

    if not localRoot or not targetRoot then
        return false
    end

    return (targetRoot.Position - localRoot.Position).Magnitude <= animationPlayerRange
end

local function RecordCharacterAnimation(player, character, track, source)
    if not animationDetectionEnabled or not matchIsActive then
        return
    end

    if player == LocalPlayer or (not player and not character) then
        return
    end

    local animation = track and track.Animation
    local animationId = animation and animation.AnimationId or "Unknown"
    local actorType = player and "PLAYER" or "BOT"
    local actorName = player and player.Name or character.Name
    local actorKey = player
        and ("PLAYER:" .. tostring(player.UserId))
        or ("BOT:" .. character:GetFullName())
    local catalogueKey = actorKey .. "|" .. tostring(animationId)
    local nowElapsed = os.clock() - animationDetectionStartedAt
    local eventRecord = animationCatalogueByKey[catalogueKey]
    local isNewEntry = eventRecord == nil

    if isNewEntry then
        eventRecord = {
            Player = actorName,
            ActorType = actorType,
            ActorKey = actorKey,
            UserId = player and player.UserId or nil,
            AnimationId = animationId,
            Classification = animationClassesById[animationId] or "UNREVIEWED",
            FirstElapsed = nowElapsed,
            LastElapsed = nowElapsed,
            Count = 0,
            Priority = track and track.Priority and track.Priority.Name or "Unknown",
            Length = track and tonumber(track.Length) or 0,
            Source = source or "LIVE",
        }

        animationCatalogueByKey[catalogueKey] = eventRecord
        table.insert(animationEvents, eventRecord)

        -- Keep the catalogue bounded while allowing entries from players and bots.
        if #animationEvents > 120 then
            local removed = table.remove(animationEvents, 1)
            local removedKey = tostring(removed.ActorKey)
                .. "|" .. tostring(removed.AnimationId)
            if animationCatalogueByKey[removedKey] == removed then
                animationCatalogueByKey[removedKey] = nil
            end
        end

        print(string.format(
            "[AXScripts Animation Monitor] NEW | %s=%s | ID=%s | %s | priority=%s | length=%.2fs",
            actorType,
            actorName,
            tostring(animationId),
            eventRecord.Classification,
            eventRecord.Priority,
            eventRecord.Length
        ))
    end

    -- Replays of the same animation update its count instead of adding another row.
    eventRecord.Count += 1
    eventRecord.LastElapsed = nowElapsed
    eventRecord.Priority = track and track.Priority and track.Priority.Name or eventRecord.Priority
    eventRecord.Length = track and tonumber(track.Length) or eventRecord.Length
    eventRecord.Source = source or "LIVE"
    eventRecord.Classification = animationClassesById[animationId] or eventRecord.Classification
    lastAnimationEvent = eventRecord
    animationTotalPlays += 1

    -- Limit panel refresh work during animation-heavy moments.
    local now = os.clock()
    if isNewEntry or now - animationPanelLastRefresh >= 0.25 then
        animationPanelLastRefresh = now
        RefreshAnimationDetectorPanel()
    end
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
        RecordCharacterAnimation(player, character, track, "LIVE")
    end)

    animationAnimatorConnections[animator] = {
        Connection = connection,
        Player = player,
        Character = character,
        ActorType = "PLAYER",
    }

    -- Intentionally do not snapshot already-playing tracks here.
    -- The monitor records only AnimationPlayed events that begin after attachment,
    -- avoiding a burst of old/current server animations when the match timer appears.
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

local function HasBotAnimationController(model)
    if not model or not model:IsA("Model") then
        return false
    end

    return model:FindFirstChildOfClass("Humanoid") ~= nil
        or model:FindFirstChildWhichIsA("AnimationController", true) ~= nil
end

local function GetBotCharacterFromDescendant(descendant)
    local current = descendant
    if current and not current:IsA("Model") then
        current = current.Parent
    end

    while current and current ~= Workspace do
        if HasBotAnimationController(current)
            and Players:GetPlayerFromCharacter(current) == nil
            and current ~= LocalPlayer.Character then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function AttachBotAnimator(character, animator)
    if not animationDetectionEnabled
        or not matchIsActive
        or not character
        or Players:GetPlayerFromCharacter(character) ~= nil
        or not animator:IsA("Animator")
        or animationAnimatorConnections[animator] then
        return
    end

    local connection = animator.AnimationPlayed:Connect(function(track)
        RecordCharacterAnimation(nil, character, track, "LIVE")
    end)

    animationAnimatorConnections[animator] = {
        Connection = connection,
        Player = nil,
        Character = character,
        BotCharacter = character,
        ActorType = "BOT",
    }
end

local function DetachBotCharacter(character)
    local connections = animationBotModelConnections[character]
    if connections then
        for _, connection in pairs(connections) do
            connection:Disconnect()
        end
        animationBotModelConnections[character] = nil
    end

    for animator, entry in pairs(animationAnimatorConnections) do
        if entry.BotCharacter == character then
            entry.Connection:Disconnect()
            animationAnimatorConnections[animator] = nil
        end
    end
end

local function AttachBotCharacter(character)
    if not animationDetectionEnabled
        or not matchIsActive
        or not character
        or not character:IsA("Model")
        or not character:IsDescendantOf(Workspace)
        or not HasBotAnimationController(character)
        or Players:GetPlayerFromCharacter(character) ~= nil
        or character == LocalPlayer.Character
        or animationBotModelConnections[character] then
        return
    end

    local connections = {}
    animationBotModelConnections[character] = connections

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Animator") then
            AttachBotAnimator(character, descendant)
        end
    end

    connections.DescendantAdded = character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Animator") then
            AttachBotAnimator(character, descendant)
        end
    end)

    connections.AncestryChanged = character.AncestryChanged:Connect(function()
        if not character:IsDescendantOf(Workspace) then
            DetachBotCharacter(character)
        end
    end)
end

local function AttachAllBotCharacters()
    if not animationDetectionEnabled or not matchIsActive then
        return
    end

    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Model") and HasBotAnimationController(descendant) then
            AttachBotCharacter(descendant)
        end
    end
end

local function DetachAllBotCharacters()
    local characters = {}
    for character in pairs(animationBotModelConnections) do
        table.insert(characters, character)
    end

    for _, character in ipairs(characters) do
        DetachBotCharacter(character)
    end
end

local function IsWorldEventTimerContext(object, playerGui)
    local blockedWords = {
        "world", "event", "coin", "gem", "boost", "double", "2x"
    }

    local function containsBlockedWord(value)
        local normalized = string.lower(tostring(value or ""))
        for _, word in ipairs(blockedWords) do
            if string.find(normalized, word, 1, true) then
                return true
            end
        end
        return false
    end

    local current = object
    local depth = 0
    while current and current ~= playerGui and depth < 4 do
        if containsBlockedWord(current.Name) then
            return true
        end

        -- Event panels commonly place their title and countdown as siblings.
        -- Keep sibling checks local to avoid unrelated lobby labels elsewhere on the HUD.
        if depth <= 1 and current.Parent then
            for _, sibling in ipairs(current.Parent:GetChildren()) do
                if sibling ~= current
                    and (sibling:IsA("TextLabel") or sibling:IsA("TextButton") or sibling:IsA("TextBox"))
                    and containsBlockedWord(sibling.Text) then
                    return true
                end
            end
        end

        current = current.Parent
        depth += 1
    end

    return false
end

local function IsMatchTimerVisible()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local camera = Workspace.CurrentCamera
    if not playerGui or not camera then
        return false, nil, "PlayerGui or camera unavailable"
    end

    local viewport = camera.ViewportSize
    local candidates = {}

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

                if visible and not IsWorldEventTimerContext(object, playerGui) then
                    local center = object.AbsolutePosition + object.AbsoluteSize / 2
                    local normalizedX = center.X / math.max(viewport.X, 1)
                    local normalizedY = center.Y / math.max(viewport.Y, 1)
                    local normalizedWidth = object.AbsoluteSize.X / math.max(viewport.X, 1)
                    local normalizedHeight = object.AbsoluteSize.Y / math.max(viewport.Y, 1)

                    -- The match clock in the supplied HUD is in the upper-center area.
                    -- Require a reasonably sized label there to reject most event timers.
                    local inMatchClockZone = normalizedX >= 0.38
                        and normalizedX <= 0.80
                        and normalizedY <= 0.18
                        and normalizedWidth >= 0.045
                        and normalizedHeight >= 0.025

                    if inMatchClockZone then
                        table.insert(candidates, {
                            Text = timerText,
                            X = normalizedX,
                            Y = normalizedY,
                        })
                    end
                end
            end
        end
    end

    if #candidates > 0 then
        table.sort(candidates, function(a, b)
            local aScore = math.abs(a.X - 0.60) + a.Y
            local bScore = math.abs(b.X - 0.60) + b.Y
            return aScore < bScore
        end)

        local best = candidates[1]
        return true, best.Text, string.format(
            "HUD clock %s at %.2f, %.2f",
            best.Text,
            best.X,
            best.Y
        )
    end

    return false, nil, "No match clock found in upper-center HUD zone"
end

local function DetachOpponentCharacter(player, character)
    if not character then
        return
    end

    local connections = animationModelConnections[character]
    if connections then
        for _, connection in pairs(connections) do
            connection:Disconnect()
        end
        animationModelConnections[character] = nil
    end

    for animator, entry in pairs(animationAnimatorConnections) do
        if entry.Player == player and entry.Character == character then
            entry.Connection:Disconnect()
            animationAnimatorConnections[animator] = nil
        end
    end
end

local function DetachOpponentPlayer(player)
    local playerConnection = animationPlayerConnections[player]
    if playerConnection then
        playerConnection:Disconnect()
        animationPlayerConnections[player] = nil
    end

    DetachOpponentCharacter(player, player.Character)

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

    if animationWorkspaceAddedConnection then
        animationWorkspaceAddedConnection:Disconnect()
        animationWorkspaceAddedConnection = nil
    end

    DetachAllBotCharacters()
    RefreshAnimationDetectorPanel()
end

local function StartAnimationDetector()
    StopAnimationDetector()
    table.clear(animationEvents)
    table.clear(animationCatalogueByKey)
    lastAnimationEvent = nil
    animationTotalPlays = 0
    animationPanelLastRefresh = 0
    animationDetectionStartedAt = os.clock()
    animationDetectionEnabled = true

    local timerVisible = IsMatchTimerVisible()
    matchIsActive = timerVisible

    for _, player in ipairs(Players:GetPlayers()) do
        AttachOpponentPlayer(player)
    end

    animationWorkspaceAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if animationDetectionEnabled and matchIsActive
            and (descendant:IsA("Model")
                or descendant:IsA("Animator")
                or descendant:IsA("Humanoid")
                or descendant:IsA("AnimationController")) then
            local botCharacter = GetBotCharacterFromDescendant(descendant)
            if botCharacter then
                AttachBotCharacter(botCharacter)
            end
        end
    end)

    if matchIsActive then
        AttachAllBotCharacters()
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
                AttachAllBotCharacters()
                detectorStatusLabel.Text = "Match timer found. Monitoring nearby players and bots."
            else
                for _, player in ipairs(Players:GetPlayers()) do
                    DetachOpponentPlayer(player)
                end
                DetachAllBotCharacters()
                detectorStatusLabel.Text = "Match timer hidden. Lobby monitoring paused."
            end

            RefreshAnimationDetectorPanel()
        end

        -- Re-check distance while the match is active so distant server players
        -- are detached and players entering range are attached.
        if matchIsActive then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    AttachOpponentPlayer(player)
                    if player.Character and not IsOpponentCharacter(player, player.Character) then
                        DetachOpponentCharacter(player, player.Character)
                    end
                end
            end
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
    local playerEntries, botEntries = 0, 0

    for _, eventRecord in ipairs(animationEvents) do
        if eventRecord.Classification == "ATTACK" then
            attackCount += 1
        elseif eventRecord.Classification == "OTHER" then
            otherCount += 1
        else
            unreviewedCount += 1
        end

        if eventRecord.ActorType == "BOT" then
            botEntries += 1
        else
            playerEntries += 1
        end
    end

    local lastId = lastAnimationEvent and lastAnimationEvent.AnimationId or "none"
    return string.format(
        "Plays: %d | Unique: %d (P:%d B:%d) | Attack: %d | Other: %d | New: %d | Last: %s",
        animationTotalPlays,
        #animationEvents,
        playerEntries,
        botEntries,
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
        detectorStatusLabel.Text = "Match HUD clock detected | Monitoring players + bots."
    else
        detectorStatusLabel.Text = "Waiting for match HUD clock | Lobby paused."
    end

    detectorStartButton.Text = animationDetectionEnabled and "STOP MONITOR" or "START MONITOR"

    local attacks, others, unreviewed = 0, 0, 0
    local recent = {}

    for _, eventRecord in ipairs(animationEvents) do
        if eventRecord.Classification == "ATTACK" then
            attacks += 1
        elseif eventRecord.Classification == "OTHER" then
            others += 1
        else
            unreviewed += 1
        end
        table.insert(recent, eventRecord)
    end

    table.sort(recent, function(a, b)
        return (a.LastElapsed or 0) > (b.LastElapsed or 0)
    end)

    local visible = {}
    for index = 1, math.min(8, #recent) do
        local eventRecord = recent[index]
        table.insert(visible, string.format(
            "%s | %s:%s | %s | x%d",
            eventRecord.Classification,
            eventRecord.ActorType or "PLAYER",
            eventRecord.Player,
            tostring(eventRecord.AnimationId),
            eventRecord.Count or 1
        ))
    end

    detectorStatsLabel.Text = string.format(
        "Plays: %d | Unique: %d | P:%d B:%d | ATK:%d",
        animationTotalPlays,
        #animationEvents,
        (function()
            local count = 0
            for _, eventRecord in ipairs(animationEvents) do
                if eventRecord.ActorType ~= "BOT" then count += 1 end
            end
            return count
        end)(),
        (function()
            local count = 0
            for _, eventRecord in ipairs(animationEvents) do
                if eventRecord.ActorType == "BOT" then count += 1 end
            end
            return count
        end)(),
        attacks
    )
    detectorLogLabel.Text = #visible > 0
        and table.concat(visible, "\n")
        or "No opponent animation events yet. Start the monitor first."
end
CreateAnimationDetectorPanel()


local function HUDCleanText(value)
    local textValue = tostring(value or "")
    textValue = textValue:gsub("<[^>]->", "")
    textValue = textValue:gsub("[%c]", " ")
    return textValue:gsub("^%s+", ""):gsub("%s+$", "")
end

local function HUDIsTimer(value)
    return tostring(value or ""):match("^%d+:%d%d$") ~= nil
end

local function HUDIsVisible(object)
    local current = object
    while current and current ~= PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function HUDIsTopRight(object)
    local currentCamera = Workspace.CurrentCamera
    if not currentCamera then
        return false
    end

    local view = currentCamera.ViewportSize
    local pos = object.AbsolutePosition
    local size = object.AbsoluteSize
    return pos.X + size.X / 2 >= view.X * 0.48
        and pos.Y + size.Y / 2 <= view.Y * 0.58
end

local function HUDGetScreenGui(object)
    local current = object
    while current and current ~= PlayerGui do
        if current:IsA("ScreenGui") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function HUDScreenDistance(a, b)
    local ap = a.AbsolutePosition + a.AbsoluteSize / 2
    local bp = b.AbsolutePosition + b.AbsoluteSize / 2
    return (ap - bp).Magnitude
end

local function HUDCountHearts(raw)
    local _, count = tostring(raw or ""):gsub("♥", "")
    return count
end

local function HUDGetSnapshot()
    local timerCandidates = {}

    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
            and HUDIsVisible(object) and HUDIsTopRight(object) then
            local value = HUDCleanText(object.Text)
            if HUDIsTimer(value) then
                table.insert(timerCandidates, {
                    object = object,
                    value = value,
                    score = string.lower(object.Name) == "time" and 5 or 0
                })
            end
        end
    end

    if #timerCandidates == 0 then
        return nil
    end

    local allObjects = PlayerGui:GetDescendants()
    local best = nil

    for _, timerCandidate in ipairs(timerCandidates) do
        local timerObject = timerCandidate.object
        local timerScreen = HUDGetScreenGui(timerObject)
        local snapshot = {
            timer = timerCandidate.value,
            fighter = nil,
            hp = {},
            heartsLeft = nil,
            heartsRight = nil,
            extra = nil,
            score = timerCandidate.score
        }

        local names = {}
        local hpValues = {}
        local extras = {}

        for _, object in ipairs(allObjects) do
            if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
                and object ~= timerObject and HUDIsVisible(object) then
                local distance = HUDScreenDistance(object, timerObject)
                if distance <= 900 then
                    local raw = tostring(object.Text or "")
                    local value = HUDCleanText(raw)
                    local name = string.lower(object.Name)
                    local proximity = (HUDGetScreenGui(object) == timerScreen and 250 or 0) - distance

                    if name == "name" and value ~= "" and not HUDIsTimer(value) then
                        table.insert(names, {value = value, score = proximity})
                    elseif name == "hpnum" and tonumber(value) then
                        table.insert(hpValues, {value = value, score = proximity, x = object.AbsolutePosition.X, y = object.AbsolutePosition.Y})
                    elseif name == "heartsl" and value ~= "" then
                        local hearts = HUDCountHearts(raw)
                        if snapshot.heartsLeft == nil then
                            snapshot.heartsLeft = hearts
                        end
                    elseif name == "heartsr" and value ~= "" then
                        local hearts = HUDCountHearts(raw)
                        if snapshot.heartsRight == nil then
                            snapshot.heartsRight = hearts
                        end
                    elseif name == "label" and value ~= "" then
                        table.insert(extras, {value = value, score = proximity})
                    end
                end
            end
        end

        table.sort(names, function(a, b) return a.score > b.score end)
        table.sort(hpValues, function(a, b)
            if a.y == b.y then return a.x < b.x end
            return a.y < b.y
        end)
        table.sort(extras, function(a, b) return a.score > b.score end)

        if names[1] then
            snapshot.fighter = names[1].value
            snapshot.score += 10
        end

        for index = 1, math.min(2, #hpValues) do
            table.insert(snapshot.hp, hpValues[index].value)
        end

        if #snapshot.hp >= 2 then
            snapshot.score += 4
        elseif #snapshot.hp == 1 then
            snapshot.score += 1
        end

        if snapshot.heartsLeft ~= nil or snapshot.heartsRight ~= nil then
            snapshot.score += 2
        end

        snapshot.extra = extras[1] and extras[1].value or nil

        if snapshot.score > (best and best.score or -1) then
            best = snapshot
        end
    end

    return best
end

local function HUDAddHistory(message)
    if hudMonitorHistory[1] == message then
        return
    end

    table.insert(hudMonitorHistory, 1, message)
    while #hudMonitorHistory > 3 do
        table.remove(hudMonitorHistory)
    end
end

local function HUDRenderText(statusText, snapshot)
    if not hudMonitorParagraph then
        return
    end

    local lines = {
        "STATUS: " .. statusText,
        "Fighter: " .. (snapshot and snapshot.fighter or "nil"),
        "Timer: " .. (snapshot and snapshot.timer or "nil"),
        "HP: " .. (snapshot and snapshot.hp[1] or "nil")
            .. " / " .. (snapshot and snapshot.hp[2] or "nil"),
        "Hearts: " .. (snapshot and (
            tostring(snapshot.heartsLeft or "nil") .. " / "
            .. tostring(snapshot.heartsRight or "nil")
        ) or "nil"),
        "Other HUD label: " .. (snapshot and snapshot.extra or "nil"),
        "",
        "RECENT HUD CHANGES"
    }

    if #hudMonitorHistory == 0 then
        table.insert(lines, "No recent changes.")
    else
        for _, eventText in ipairs(hudMonitorHistory) do
            table.insert(lines, eventText)
        end
    end

    hudMonitorParagraph:Set(table.concat(lines, "\n"))
end

local function HUDClearValues()
    if hudMonitorPrevious then
        hudMonitorPrevious = nil
        hudMonitorHistory = {}
    end

    HUDRenderText("LOBBY | VALUES NIL", nil)
end

local function HUDRefresh()
    if not hudMonitorParagraph then
        return
    end

    local snapshot = HUDGetSnapshot()
    local matchActive = snapshot ~= nil
        and snapshot.fighter ~= nil
        and #snapshot.hp >= 2

    if not matchActive then
        HUDClearValues()
        return
    end

    if not hudMonitorPrevious then
        hudMonitorHistory = {}
        HUDAddHistory("Match detected | " .. snapshot.fighter)
    else
        if snapshot.fighter ~= hudMonitorPrevious.fighter then
            HUDAddHistory("Fighter: " .. snapshot.fighter)
        end

        if snapshot.hp[1] ~= hudMonitorPrevious.hp[1]
            or snapshot.hp[2] ~= hudMonitorPrevious.hp[2] then
            HUDAddHistory("HP: " .. (snapshot.hp[1] or "nil")
                .. " / " .. (snapshot.hp[2] or "nil"))
        end

        if snapshot.heartsLeft ~= hudMonitorPrevious.heartsLeft
            or snapshot.heartsRight ~= hudMonitorPrevious.heartsRight then
            if snapshot.heartsLeft ~= nil or snapshot.heartsRight ~= nil then
                HUDAddHistory("Hearts: " .. tostring(snapshot.heartsLeft or "nil")
                    .. " / " .. tostring(snapshot.heartsRight or "nil"))
            end
        end
    end

    hudMonitorPrevious = snapshot
    HUDRenderText("MATCH HUD DETECTED", snapshot)
end



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
    if hudMonitorEnabled then
        hudMonitorElapsed += deltaTime
        if hudMonitorElapsed >= 0.3 then
            hudMonitorElapsed = 0
            local ok, err = pcall(HUDRefresh)
            if not ok and hudMonitorStatusLabel then
                hudMonitorStatusLabel.Text = "HUD READ ERROR"
                hudMonitorStatusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
                warn("[AXScripts HUD Monitor] " .. tostring(err))
            end
        end
    end

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
        Name = "Auto Block (practice only - not connected)",
        Default = false,
        Callback = function(state)
            smartBlockEnabled = state
            LucidUI:Notify({
                Title = "Auto Fight",
                Message = state and "Practice-only setting saved. No blocking action is connected; an official practice-NPC adapter is required." or "Auto Block setting disabled."
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

    DetectorSection:CreateSlider({
        Name = "Nearby Player Range",
        Min = 40,
        Max = 300,
        Default = 120,
        Callback = function(value)
            animationPlayerRange = value
        end,
    })

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

    local HUDMonitorSection = FarmTab:CreateSection({Name = "Opponent HUD Monitor (Read Only)"})

    hudMonitorParagraph = HUDMonitorSection:CreateParagraph({
        Text = "STATUS: LOBBY | VALUES NIL\nFighter: nil\nTimer: nil\nHP: nil / nil\nHearts: nil\nOther HUD label: nil\n\nRECENT HUD CHANGES\nNo recent changes.",
        TextSize = 11,
        PaddingX = 6,
        PaddingY = 6
    })
    hudMonitorEnabled = true
    HUDRefresh()


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
