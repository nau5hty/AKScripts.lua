--[[
    AXScripts Auto Block Practice Lab
    ---------------------------------
    Standalone client-side practice simulator.

    This script only shows a local practice UI and simulated combat phases.
    It does NOT connect to Anime vs Anime, other players, NPCs, remotes,
    or any live game's combat system. Counter and catch are display-only
    practice events; no attack input is sent to a game.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
if not player then
    warn("[AXScripts Practice] Run this as a client-side LocalScript.")
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("AXScriptsPracticeSim")
if oldGui then
    oldGui:Destroy()
end

-- Simulated timing values.
local WARNING_WINDOW = 0.85
local RECOVERY_WINDOW = 1.15
local COUNTER_DELAY = 0.16
local CATCH_DELAY = 0.24
local MIN_GAP_BETWEEN_ATTACKS = 0.75
local MAX_GAP_BETWEEN_ATTACKS = 1.25

local holdBlockEnabled = false
local autoCounterEnabled = false
local running = false
local warningActive = false
local recoveryActive = false
local isBlocking = false

local runId = 0
local cycleId = 0

local blockedCount = 0
local missedCount = 0
local counterCount = 0
local catchCount = 0

local random = Random.new()

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
panel.Size = UDim2.fromOffset(390, 330)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
panel.BorderSizePixel = 0
panel.Parent = gui
addCorner(panel, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 72, 88)
stroke.Thickness = 1
stroke.Parent = panel

local title = makeLabel(
    panel,
    "Title",
    "AXScripts  |  Auto Block Lab",
    UDim2.fromOffset(18, 13),
    UDim2.new(1, -36, 0, 26),
    17,
    Color3.fromRGB(255, 255, 255)
)
title.Font = Enum.Font.GothamBold

makeLabel(
    panel,
    "Subtitle",
    "LOCAL PRACTICE SIMULATION  •  NO LIVE GAME CONNECTION",
    UDim2.fromOffset(18, 40),
    UDim2.new(1, -36, 0, 18),
    9,
    Color3.fromRGB(150, 160, 178)
)

local attackLabel = makeLabel(
    panel,
    "AttackState",
    "Waiting for simulated opponent...",
    UDim2.fromOffset(18, 70),
    UDim2.new(1, -36, 0, 40),
    15,
    Color3.fromRGB(210, 218, 230)
)
attackLabel.Font = Enum.Font.GothamSemibold

local statusLabel = makeLabel(
    panel,
    "Status",
    "Simulation stopped.",
    UDim2.fromOffset(18, 113),
    UDim2.new(1, -36, 0, 33),
    12,
    Color3.fromRGB(165, 175, 192)
)

local sequenceLabel = makeLabel(
    panel,
    "Sequence",
    "SEQUENCE: waiting",
    UDim2.fromOffset(18, 151),
    UDim2.new(1, -36, 0, 25),
    11,
    Color3.fromRGB(180, 190, 208)
)
sequenceLabel.Font = Enum.Font.GothamSemibold

local statsLabel = makeLabel(
    panel,
    "Stats",
    "BLOCKED: 0   MISSED: 0",
    UDim2.fromOffset(18, 183),
    UDim2.new(1, -36, 0, 36),
    11,
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
    button.TextSize = 12
    button.Font = Enum.Font.GothamSemibold
    button.AutoButtonColor = true
    button.Parent = panel
    addCorner(button, 8)
    return button
end

local holdButton = makeButton(
    "HoldBlockButton",
    "Hold Block: OFF",
    UDim2.fromOffset(18, 235),
    UDim2.new(0.5, -24, 0, 34)
)

local counterButton = makeButton(
    "CounterButton",
    "Counter + Catch: OFF",
    UDim2.new(0.5, 6, 0, 235),
    UDim2.new(0.5, -24, 0, 34)
)

local startButton = makeButton(
    "SimulationButton",
    "Start Simulation",
    UDim2.fromOffset(18, 278),
    UDim2.new(1, -36, 0, 34)
)
startButton.BackgroundColor3 = Color3.fromRGB(75, 82, 105)

makeLabel(
    panel,
    "Footer",
    "Hold Block covers the warning; Counter + Catch runs in simulated recovery.",
    UDim2.fromOffset(18, 313),
    UDim2.new(1, -36, 0, 14),
    8,
    Color3.fromRGB(135, 145, 164)
)

local function updateStats()
    statsLabel.Text = string.format(
        "BLOCKED: %d   MISSED: %d\nM1 COUNTERS: %d   M1 CATCHES: %d",
        blockedCount,
        missedCount,
        counterCount,
        catchCount
    )
end

local function setHoldBlock(enabled)
    holdBlockEnabled = enabled
    holdButton.Text = enabled and "Hold Block: ON" or "Hold Block: OFF"
    holdButton.BackgroundColor3 = enabled
        and Color3.fromRGB(35, 112, 83)
        or Color3.fromRGB(48, 54, 68)

    -- Apply the hold immediately if the simulated attack is already winding up.
    if warningActive then
        isBlocking = enabled
        if enabled then
            statusLabel.Text = "Block is being held through the attack warning."
            statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
        else
            statusLabel.Text = "Block released before simulated impact."
            statusLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
        end
    end
end

local function setAutoCounter(enabled)
    autoCounterEnabled = enabled
    counterButton.Text = enabled and "Counter + Catch: ON" or "Counter + Catch: OFF"
    counterButton.BackgroundColor3 = enabled
        and Color3.fromRGB(55, 91, 145)
        or Color3.fromRGB(48, 54, 68)

    if not enabled then
        sequenceLabel.Text = "SEQUENCE: disabled"
    elseif recoveryActive then
        sequenceLabel.Text = "SEQUENCE: waiting for next recovery"
    else
        sequenceLabel.Text = "SEQUENCE: armed for recovery"
    end
end

local function stopSimulation()
    running = false
    runId += 1
    warningActive = false
    recoveryActive = false
    isBlocking = false

    startButton.Text = "Start Simulation"
    attackLabel.Text = "Waiting for simulated opponent..."
    attackLabel.TextColor3 = Color3.fromRGB(210, 218, 230)
    statusLabel.Text = "Simulation stopped."
    statusLabel.TextColor3 = Color3.fromRGB(165, 175, 192)
    sequenceLabel.Text = "SEQUENCE: waiting"
end

local function runCounterCatchSequence(thisRun, thisCycle)
    if not autoCounterEnabled then
        sequenceLabel.Text = "SEQUENCE: recovery detected; counter disabled"
        return
    end

    -- These are simulated state changes and UI messages only.
    task.wait(COUNTER_DELAY)
    if not running or thisRun ~= runId or thisCycle ~= cycleId or not recoveryActive then
        return
    end

    counterCount += 1
    sequenceLabel.Text = "SEQUENCE: M1 COUNTER"
    statusLabel.Text = "Practice counter event registered."
    statusLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
    updateStats()

    task.wait(CATCH_DELAY)
    if not running or thisRun ~= runId or thisCycle ~= cycleId or not recoveryActive then
        return
    end

    catchCount += 1
    sequenceLabel.Text = "SEQUENCE: M1 CATCH"
    statusLabel.Text = "Practice catch event registered after counter."
    statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
    updateStats()
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

            -- Phase 1: simulated opponent attack wind-up.
            recoveryActive = false
            warningActive = true
            isBlocking = holdBlockEnabled

            attackLabel.Text = "⚠  SIMULATED ATTACK WIND-UP"
            attackLabel.TextColor3 = Color3.fromRGB(255, 190, 85)

            if isBlocking then
                statusLabel.Text = "Hold Block active before simulated impact."
                statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
            else
                statusLabel.Text = "Attack warning detected; block is not held."
                statusLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
            end

            task.wait(WARNING_WINDOW)
            if not running or thisRun ~= runId or thisCycle ~= cycleId then
                break
            end

            warningActive = false

            -- Phase 2: resolve the simulated impact.
            if isBlocking then
                blockedCount += 1
                attackLabel.Text = "✓  SIMULATED ATTACK BLOCKED"
                attackLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
                statusLabel.Text = "Block was held at simulated impact."
                statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
            else
                missedCount += 1
                attackLabel.Text = "✕  SIMULATED HIT"
                attackLabel.TextColor3 = Color3.fromRGB(255, 105, 105)
                statusLabel.Text = "No block was held at simulated impact."
                statusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
            end

            isBlocking = false
            updateStats()

            -- Phase 3: recovery/cooldown, where the practice combo is displayed.
            recoveryActive = true
            attackLabel.Text = "OPPONENT RECOVERING / COOLDOWN"
            attackLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
            sequenceLabel.Text = autoCounterEnabled
                and "SEQUENCE: recovery detected"
                or "SEQUENCE: counter disabled"

            runCounterCatchSequence(thisRun, thisCycle)

            local remainingRecovery = math.max(
                0,
                RECOVERY_WINDOW - COUNTER_DELAY - CATCH_DELAY
            )
            task.wait(remainingRecovery)

            if not running or thisRun ~= runId or thisCycle ~= cycleId then
                break
            end

            recoveryActive = false
            attackLabel.Text = "Opponent ready for next simulated attack."
            attackLabel.TextColor3 = Color3.fromRGB(210, 218, 230)
            if autoCounterEnabled then
                sequenceLabel.Text = "SEQUENCE: complete; waiting for recovery"
            else
                sequenceLabel.Text = "SEQUENCE: waiting"
            end

            task.wait(0.25)
        end
    end)
end

holdButton.Activated:Connect(function()
    setHoldBlock(not holdBlockEnabled)
end)

counterButton.Activated:Connect(function()
    setAutoCounter(not autoCounterEnabled)
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

updateStats()
