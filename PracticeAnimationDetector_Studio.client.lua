-- AXScripts Practice Animation Detector
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Run it in Roblox Studio in a place you control.
-- Tag practice dummy Models with CollectionService tag "AXPracticeNPC".
-- This script only observes tagged NPC animation starts. It never attacks,
-- blocks, sends remotes, or reads player-character animations.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TAG = "AXPracticeNPC"
local MAX_VISIBLE_LOGS = 10

local previous = PlayerGui:FindFirstChild("AXScripts_AnimationTester")
if previous then
    previous:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AXScripts_AnimationTester"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(340, 330)
panel.Position = UDim2.new(1, -360, 0.5, -165)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 75, 90)
stroke.Thickness = 1
stroke.Parent = panel

local function makeLabel(name, text, position, size, textSize)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.TextColor3 = Color3.fromRGB(230, 230, 238)
    label.TextSize = textSize or 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.Parent = panel
    return label
end

local title = makeLabel(
    "Title",
    "AXScripts  /  Animation Tester",
    UDim2.fromOffset(14, 8),
    UDim2.new(1, -28, 0, 28),
    15
)
title.Font = Enum.Font.GothamBold

local statusLabel = makeLabel(
    "Status",
    "Status: stopped",
    UDim2.fromOffset(14, 39),
    UDim2.new(1, -28, 0, 30),
    11
)
statusLabel.TextColor3 = Color3.fromRGB(170, 200, 255)

local function makeButton(name, text, position, size)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(245, 245, 250)
    button.TextSize = 11
    button.AutoButtonColor = true
    button.Parent = panel

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button
    return button
end

local startButton = makeButton(
    "StartStop",
    "START DETECTOR",
    UDim2.fromOffset(14, 76),
    UDim2.new(1, -28, 0, 32)
)

local attackButton = makeButton(
    "MarkAttack",
    "MARK LAST: ATTACK",
    UDim2.fromOffset(14, 116),
    UDim2.new(0.5, -20, 0, 30)
)
attackButton.BackgroundColor3 = Color3.fromRGB(35, 75, 58)

local otherButton = makeButton(
    "MarkOther",
    "MARK LAST: OTHER",
    UDim2.new(0.5, 6, 0, 116),
    UDim2.new(0.5, -20, 0, 30)
)
otherButton.BackgroundColor3 = Color3.fromRGB(80, 55, 42)

local statsLabel = makeLabel(
    "Stats",
    "Observed: 0 | Attack: 0 | Other: 0 | Unreviewed: 0",
    UDim2.fromOffset(14, 151),
    UDim2.new(1, -28, 0, 28),
    10
)

local logLabel = makeLabel(
    "Log",
    "No animation events yet. Start the detector and trigger animations on a tagged practice NPC.",
    UDim2.fromOffset(14, 184),
    UDim2.new(1, -28, 1, -194),
    10
)
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code

local detectorEnabled = false
local animatorConnections = {}
local modelConnections = {}
local tagAddedConnection = nil
local events = {}
local classesById = {}
local lastEvent = nil
local startedAt = 0

local function isPracticeNPC(model)
    return typeof(model) == "Instance"
        and model:IsA("Model")
        and model:IsDescendantOf(workspace)
        and CollectionService:HasTag(model, TAG)
        and Players:GetPlayerFromCharacter(model) == nil
end

local function refreshDisplay()
    local attackCount, otherCount, unreviewedCount = 0, 0, 0
    for _, eventRecord in ipairs(events) do
        if eventRecord.Classification == "ATTACK" then
            attackCount += 1
        elseif eventRecord.Classification == "OTHER" then
            otherCount += 1
        else
            unreviewedCount += 1
        end
    end

    statsLabel.Text = string.format(
        "Observed: %d | Attack: %d | Other: %d | Unreviewed: %d",
        #events,
        attackCount,
        otherCount,
        unreviewedCount
    )

    local lines = {}
    local first = math.max(1, #events - MAX_VISIBLE_LOGS + 1)
    for index = #events, first, -1 do
        local eventRecord = events[index]
        table.insert(lines, string.format(
            "%s  %s  ID:%s  +%.0fms",
            eventRecord.Classification,
            eventRecord.Model,
            eventRecord.AnimationId,
            eventRecord.Elapsed * 1000
        ))
    end
    if #lines == 0 then
        table.insert(lines, "No animation events yet.")
    end
    logLabel.Text = table.concat(lines, "\n")
end

local function recordAnimation(model, track)
    if not detectorEnabled or not isPracticeNPC(model) then
        return
    end

    local animation = track and track.Animation
    local animationId = animation and animation.AnimationId or "Unknown"
    local record = {
        Model = model.Name,
        AnimationId = animationId,
        Classification = classesById[animationId] or "UNREVIEWED",
        Elapsed = os.clock() - startedAt,
    }

    table.insert(events, record)
    lastEvent = record

    print(string.format(
        "[AXScripts Detector] %s | NPC=%s | ID=%s | t=%.0fms",
        record.Classification,
        record.Model,
        tostring(animationId),
        record.Elapsed * 1000
    ))

    refreshDisplay()
end

local function attachAnimator(model, animator)
    if not detectorEnabled
        or not isPracticeNPC(model)
        or not animator:IsA("Animator")
        or animatorConnections[animator] then
        return
    end

    animatorConnections[animator] = animator.AnimationPlayed:Connect(function(track)
        recordAnimation(model, track)
    end)
end

local function attachNPC(model)
    if not detectorEnabled or not isPracticeNPC(model) or modelConnections[model] then
        return
    end

    local connections = {}
    modelConnections[model] = connections

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("Animator") then
            attachAnimator(model, descendant)
        end
    end

    connections.DescendantAdded = model.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Animator") then
            attachAnimator(model, descendant)
        end
    end)
end

local function stopDetector()
    detectorEnabled = false

    for _, connection in pairs(animatorConnections) do
        connection:Disconnect()
    end
    table.clear(animatorConnections)

    for _, connections in pairs(modelConnections) do
        for _, connection in pairs(connections) do
            connection:Disconnect()
        end
    end
    table.clear(modelConnections)

    if tagAddedConnection then
        tagAddedConnection:Disconnect()
        tagAddedConnection = nil
    end

    startButton.Text = "START DETECTOR"
    statusLabel.Text = "Status: stopped"
end

local function startDetector()
    if not RunService:IsStudio() then
        statusLabel.Text = "Studio-only tester. Open a place you control in Studio."
        return false
    end

    stopDetector()
    table.clear(events)
    lastEvent = nil
    startedAt = os.clock()
    detectorEnabled = true

    for _, model in ipairs(CollectionService:GetTagged(TAG)) do
        attachNPC(model)
    end

    tagAddedConnection = CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
        if instance:IsA("Model") then
            attachNPC(instance)
        end
    end)

    startButton.Text = "STOP DETECTOR"
    statusLabel.Text = "Watching tagged practice NPCs"
    refreshDisplay()
    return true
end

local function markLast(classification)
    if not lastEvent then
        statusLabel.Text = "No animation to label yet."
        return
    end

    local animationId = lastEvent.AnimationId
    if animationId == "Unknown" then
        statusLabel.Text = "Last animation has no readable ID."
        return
    end

    classesById[animationId] = classification
    for _, record in ipairs(events) do
        if record.AnimationId == animationId then
            record.Classification = classification
        end
    end

    statusLabel.Text = "Saved " .. classification .. " label for " .. animationId
    refreshDisplay()
end

startButton.MouseButton1Click:Connect(function()
    if detectorEnabled then
        stopDetector()
    else
        startDetector()
    end
end)

attackButton.MouseButton1Click:Connect(function()
    markLast("ATTACK")
end)

otherButton.MouseButton1Click:Connect(function()
    markLast("OTHER")
end)

script.Destroying:Connect(function()
    stopDetector()
    if gui then
        gui:Destroy()
    end
end)

if not RunService:IsStudio() then
    statusLabel.Text = "Studio-only tester. This will not monitor a live game."
end
