--[[
    AXScripts Auto Block Practice Lab
    ---------------------------------
    Type: LocalScript for Roblox Studio
    Put this script in StarterPlayer > StarterPlayerScripts.

    This is a self-contained, local-only practice simulator.
    It creates pretend attack warnings and tests the Auto Block timing logic.
    It does NOT connect to Anime vs Anime, other players, NPCs, remotes,
    or any live game's combat system.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
if not player then
    warn("[AXScripts Practice] Run this as a LocalScript.")
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("AXScriptsPracticeSim")
if oldGui then
    oldGui:Destroy()
end

-- Practice timing values. Adjust these later to experiment.
local WARNING_WINDOW = 0.85
local AUTO_BLOCK_REACTION_DELAY = 0.12
local MIN_GAP_BETWEEN_ATTACKS = 1.3
local MAX_GAP_BETWEEN_ATTACKS = 2.2

local autoBlockEnabled = false
local running = false
local warningActive = false
local isBlocking = false
local warningStartedAt = 0
local runId = 0
local cycleId = 0
local blockedCount = 0
local missedCount = 0

local random = Random.new()

-- Small UI helpers.
local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
end

local function makeLabel(parent, name, text, position, size, textSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(235, 238, 245)
    label.TextSize = textSize or 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "AXScriptsPracticeSim"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(370, 270)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
panel.BorderSizePixel = 0
panel.Parent = gui
addCorner(panel, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 72, 88)
stroke.Thickness = 1
stroke.Parent = panel

makeLabel(
    panel,
    "Title",
    "AXScripts  |  Auto Block Lab",
    UDim2.fromOffset(18, 14),
    UDim2.new(1, -36, 0, 26),
    17,
    Color3.fromRGB(255, 255, 255)
).Font = Enum.Font.GothamBold

makeLabel(
    panel,
    "Subtitle",
    "LOCAL PRACTICE SIMULATION  •  NO LIVE GAME CONNECTION",
    UDim2.fromOffset(18, 42),
    UDim2.new(1, -36, 0, 20),
    9,
    Color3.fromRGB(150, 160, 178)
)

local attackLabel = makeLabel(
    panel,
    "AttackState",
    "Waiting for simulated opponent...",
    UDim2.fromOffset(18, 78),
    UDim2.new(1, -36, 0, 42),
    15,
    Color3.fromRGB(210, 218, 230)
)
attackLabel.Font = Enum.Font.GothamSemibold

local statusLabel = makeLabel(
    panel,
    "Status",
    "Simulation stopped.",
    UDim2.fromOffset(18, 126),
    UDim2.new(1, -36, 0, 30),
    12,
    Color3.fromRGB(165, 175, 192)
)

local statsLabel = makeLabel(
    panel,
    "Stats",
    "BLOCKED: 0     MISSED: 0",
    UDim2.fromOffset(18, 163),
    UDim2.new(1, -36, 0, 22),
    12,
    Color3.fromRGB(235, 238, 245)
)
statsLabel.Font = Enum.Font.GothamBold

local function makeButton(name, text, position, size)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.Font = Enum.Font.GothamSemibold
    button.AutoButtonColor = true
    button.Parent = panel
    addCorner(button, 8)
    return button
end

local autoButton = makeButton(
    "AutoBlockButton",
    "Auto Block: OFF",
    UDim2.fromOffset(18, 202),
    UDim2.new(0.5, -24, 0, 34)
)

local startButton = makeButton(
    "SimulationButton",
    "Start Simulation",
    UDim2.new(0.5, 6, 0, 202),
    UDim2.new(0.5, -24, 0, 34)
)
startButton.BackgroundColor3 = Color3.fromRGB(75, 82, 105)

makeLabel(
    panel,
    "Footer",
    "Tip: enable Auto Block, then start the simulation.",
    UDim2.fromOffset(18, 243),
    UDim2.new(1, -36, 0, 18),
    10,
    Color3.fromRGB(135, 145, 164)
)

local function updateStats()
    statsLabel.Text = string.format(
        "BLOCKED: %d     MISSED: %d",
        blockedCount,
        missedCount
    )
end

local function setAutoBlock(enabled)
    autoBlockEnabled = enabled
    autoButton.Text = enabled and "Auto Block: ON" or "Auto Block: OFF"
    autoButton.BackgroundColor3 = enabled
        and Color3.fromRGB(35, 112, 83)
        or Color3.fromRGB(48, 54, 68)

    if enabled and warningActive then
        local thisRun = runId
        local thisCycle = cycleId

        task.delay(AUTO_BLOCK_REACTION_DELAY, function()
            if running
                and thisRun == runId
                and thisCycle == cycleId
                and warningActive
                and autoBlockEnabled
                and (os.clock() - warningStartedAt) < WARNING_WINDOW
            then
                isBlocking = true
                statusLabel.Text = "Auto Block engaged before simulated impact."
                statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
            end
        end)
    elseif not enabled then
        statusLabel.Text = "Auto Block disabled."
        statusLabel.TextColor3 = Color3.fromRGB(165, 175, 192)
    end
end

local function stopSimulation()
    running = false
    runId += 1
    warningActive = false
    isBlocking = false
    startButton.Text = "Start Simulation"
    attackLabel.Text = "Waiting for simulated opponent..."
    attackLabel.TextColor3 = Color3.fromRGB(210, 218, 230)
    statusLabel.Text = "Simulation stopped."
    statusLabel.TextColor3 = Color3.fromRGB(165, 175, 192)
end

local function startSimulation()
    if running then
        return
    end

    running = true
    runId += 1
    local thisRun = runId

    startButton.Text = "Stop Simulation"
    statusLabel.Text = "Simulation running..."
    statusLabel.TextColor3 = Color3.fromRGB(120, 190, 255)

    task.spawn(function()
        while running and thisRun == runId do
            task.wait(random:NextNumber(
                MIN_GAP_BETWEEN_ATTACKS,
                MAX_GAP_BETWEEN_ATTACKS
            ))

            if not running or thisRun ~= runId then
                break
            end

            cycleId += 1
            local thisCycle = cycleId

            warningActive = true
            isBlocking = false
            warningStartedAt = os.clock()

            attackLabel.Text = "⚠  ATTACK WIND-UP DETECTED"
            attackLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
            statusLabel.Text = "Simulated attack incoming..."
            statusLabel.TextColor3 = Color3.fromRGB(255, 190, 85)

            -- The practice detector reacts only to this simulated warning.
            if autoBlockEnabled then
                local thisWarningRun = runId
                task.delay(AUTO_BLOCK_REACTION_DELAY, function()
                    if running
                        and thisWarningRun == runId
                        and thisCycle == cycleId
                        and warningActive
                        and autoBlockEnabled
                        and (os.clock() - warningStartedAt) < WARNING_WINDOW
                    then
                        isBlocking = true
                        statusLabel.Text = "Auto Block engaged before simulated impact."
                        statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
                    end
                end)
            end

            task.wait(WARNING_WINDOW)

            if not running or thisRun ~= runId then
                break
            end

            warningActive = false

            if isBlocking then
                blockedCount += 1
                attackLabel.Text = "✓  SIMULATED ATTACK BLOCKED"
                attackLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
                statusLabel.Text = "Success: block was active at impact."
                statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
            else
                missedCount += 1
                attackLabel.Text = "✕  SIMULATED HIT"
                attackLabel.TextColor3 = Color3.fromRGB(255, 105, 105)
                statusLabel.Text = "No block was active at impact."
                statusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
            end

            isBlocking = false
            updateStats()
            task.wait(0.7)
        end
    end)
end

autoButton.Activated:Connect(function()
    setAutoBlock(not autoBlockEnabled)
end)

startButton.Activated:Connect(function()
    if running then
        stopSimulation()
    else
        startSimulation()
    end
end)

gui.Destroying:Connect(function()
    running = false
    runId += 1
end)
