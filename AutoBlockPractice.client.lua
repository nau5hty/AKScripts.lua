--[[
    AXScripts Auto Block Practice Lab
    ---------------------------------
    Standalone client-side practice simulator.

    This script only shows a local practice UI and simulated combat phases.
    It does NOT connect to Anime vs Anime, other players, NPCs, remotes,
    or any live game's combat system. Counter, catch, and dodge are
    display-only practice events; no game combat inputs are sent.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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

-- Simulated timing and guard values.
local WARNING_WINDOW = 1.15
local ATTACK_GAP = 0.45
local MIN_ATTACKS_PER_STRING = 2
local MAX_ATTACKS_PER_STRING = 4

local STOP_TO_COUNTER_DELAY = 1.0
local COUNTER_DISPLAY_TIME = 1.25
local CATCH_DISPLAY_TIME = 1.5

local MAX_BLOCK_HP = 100
local BLOCK_HP_DAMAGE_PER_HIT = 18
local DODGE_THRESHOLD = 30
local BLOCK_HP_RECOVERY = 12

local MIN_GAP_BETWEEN_STRINGS = 0.8
local MAX_GAP_BETWEEN_STRINGS = 1.3

local holdBlockEnabled = false
local autoCounterEnabled = false
local running = false
local warningActive = false
local attackSequenceActive = false
local recoveryActive = false
local isBlocking = false
local isDodging = false

local blockHP = MAX_BLOCK_HP
local runId = 0
local cycleId = 0

local blockedCount = 0
local missedCount = 0
local dodgedCount = 0
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
panel.Size = UDim2.fromOffset(410, 390)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
panel.BorderSizePixel = 0
panel.Parent = gui
addCorner(panel, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 72, 88)
stroke.Thickness = 1
stroke.Parent = panel

-- Drag the panel by its header area (mouse or touchscreen).
local dragHandle = Instance.new("Frame")
dragHandle.Name = "AXScriptsDragHandle"
dragHandle.BackgroundTransparency = 1
dragHandle.BorderSizePixel = 0
dragHandle.Position = UDim2.fromOffset(0, 0)
dragHandle.Size = UDim2.new(1, 0, 0, 62)
dragHandle.Active = true
dragHandle.ZIndex = 2
dragHandle.Parent = panel

local dragging = false
local dragInput = nil
local dragStart = nil
local panelStart = nil

dragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        panelStart = panel.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

dragHandle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input == dragInput
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            panelStart.X.Scale,
            panelStart.X.Offset + delta.X,
            panelStart.Y.Scale,
            panelStart.Y.Offset + delta.Y
        )
    end
end)

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
    "ATTACK-STRING PRACTICE  •  LOCAL SIMULATION ONLY",
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
    UDim2.fromOffset(18, 111),
    UDim2.new(1, -36, 0, 34),
    12,
    Color3.fromRGB(165, 175, 192)
)

local sequenceLabel = makeLabel(
    panel,
    "Sequence",
    "SEQUENCE: waiting",
    UDim2.fromOffset(18, 149),
    UDim2.new(1, -36, 0, 22),
    11,
    Color3.fromRGB(180, 190, 208)
)
sequenceLabel.Font = Enum.Font.GothamSemibold

local blockHealthLabel = makeLabel(
    panel,
    "BlockHealth",
    "BLOCK HP: 100 / 100",
    UDim2.fromOffset(18, 178),
    UDim2.new(1, -36, 0, 18),
    11,
    Color3.fromRGB(235, 238, 245)
)
blockHealthLabel.Font = Enum.Font.GothamBold

local healthBar = Instance.new("Frame")
healthBar.Name = "BlockHealthBar"
healthBar.Position = UDim2.fromOffset(18, 200)
healthBar.Size = UDim2.new(1, -36, 0, 12)
healthBar.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
healthBar.BorderSizePixel = 0
healthBar.ClipsDescendants = true
healthBar.Parent = panel
addCorner(healthBar, 6)

local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = Color3.fromRGB(63, 190, 129)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBar
addCorner(healthFill, 6)

local statsLabel = makeLabel(
    panel,
    "Stats",
    "BLOCKED: 0   MISSED: 0   DODGED: 0\nM1 COUNTERS: 0   M1 CATCHES: 0",
    UDim2.fromOffset(18, 220),
    UDim2.new(1, -36, 0, 38),
    10,
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
    UDim2.fromOffset(18, 270),
    UDim2.new(0.5, -24, 0, 34)
)

local counterButton = makeButton(
    "CounterButton",
    "Counter + Catch: OFF",
    UDim2.new(0.5, 6, 0, 270),
    UDim2.new(0.5, -24, 0, 34)
)

local startButton = makeButton(
    "SimulationButton",
    "Start Simulation",
    UDim2.fromOffset(18, 313),
    UDim2.new(1, -36, 0, 34)
)
startButton.BackgroundColor3 = Color3.fromRGB(75, 82, 105)

makeLabel(
    panel,
    "Footer",
    "Low guard (< 30): simulated jump/dash dodge replaces blocking.",
    UDim2.fromOffset(18, 355),
    UDim2.new(1, -36, 0, 25),
    9,
    Color3.fromRGB(135, 145, 164)
)

local function updateStats()
    statsLabel.Text = string.format(
        "BLOCKED: %d   MISSED: %d   DODGED: %d\nM1 COUNTERS: %d   M1 CATCHES: %d",
        blockedCount,
        missedCount,
        dodgedCount,
        counterCount,
        catchCount
    )
end

local function updateBlockHealth()
    blockHP = math.clamp(blockHP, 0, MAX_BLOCK_HP)
    local fraction = blockHP / MAX_BLOCK_HP

    blockHealthLabel.Text = string.format(
        "BLOCK HP: %d / %d%s",
        math.floor(blockHP + 0.5),
        MAX_BLOCK_HP,
        blockHP <= DODGE_THRESHOLD and "  •  LOW GUARD" or ""
    )

    healthFill.Size = UDim2.fromScale(fraction, 1)

    if blockHP <= DODGE_THRESHOLD then
        healthFill.BackgroundColor3 = Color3.fromRGB(220, 76, 76)
        blockHealthLabel.TextColor3 = Color3.fromRGB(255, 125, 125)
    elseif blockHP <= 60 then
        healthFill.BackgroundColor3 = Color3.fromRGB(230, 174, 68)
        blockHealthLabel.TextColor3 = Color3.fromRGB(255, 210, 125)
    else
        healthFill.BackgroundColor3 = Color3.fromRGB(63, 190, 129)
        blockHealthLabel.TextColor3 = Color3.fromRGB(235, 238, 245)
    end
end

local function setHoldBlock(enabled)
    holdBlockEnabled = enabled
    holdButton.Text = enabled and "Hold Block: ON" or "Hold Block: OFF"
    holdButton.BackgroundColor3 = enabled
        and Color3.fromRGB(35, 112, 83)
        or Color3.fromRGB(48, 54, 68)

    if warningActive then
        isBlocking = enabled and blockHP > DODGE_THRESHOLD
        if isBlocking then
            statusLabel.Text = "Block held during the current simulated attack."
            statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
        elseif enabled and blockHP <= DODGE_THRESHOLD then
            isDodging = true
            statusLabel.Text = "Guard is low: simulated dodge instead of blocking."
            statusLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
        else
            isDodging = false
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
        sequenceLabel.Text = recoveryActive
            and "SEQUENCE: recovery; counter disabled"
            or "SEQUENCE: disabled"
    elseif recoveryActive then
        sequenceLabel.Text = "SEQUENCE: recovery detected"
    else
        sequenceLabel.Text = "SEQUENCE: armed; waiting for opponent to stop"
    end
end

local function stopSimulation()
    running = false
    runId += 1
    warningActive = false
    attackSequenceActive = false
    recoveryActive = false
    isBlocking = false
    isDodging = false

    startButton.Text = "Start Simulation"
    attackLabel.Text = "Waiting for simulated opponent..."
    attackLabel.TextColor3 = Color3.fromRGB(210, 218, 230)
    statusLabel.Text = "Simulation stopped."
    statusLabel.TextColor3 = Color3.fromRGB(165, 175, 192)
    sequenceLabel.Text = "SEQUENCE: waiting"
end

local function runCounterCatchSequence(thisRun, thisCycle)
    if not autoCounterEnabled then
        sequenceLabel.Text = "SEQUENCE: opponent stopped; counter disabled"
        return
    end

    -- Wait one full second after the simulated attack string ends.
    task.wait(STOP_TO_COUNTER_DELAY)
    if not running or thisRun ~= runId or thisCycle ~= cycleId or not recoveryActive then
        return
    end

    -- Display-only counter event. No M1 input is sent to a game.
    counterCount += 1
    sequenceLabel.Text = "SEQUENCE: M1 COUNTER"
    statusLabel.Text = "One second after opponent stopped: counter registered."
    statusLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
    updateStats()

    task.wait(COUNTER_DISPLAY_TIME)
    if not running or thisRun ~= runId or thisCycle ~= cycleId or not recoveryActive then
        return
    end

    -- Display-only catch event, following the counter.
    catchCount += 1
    sequenceLabel.Text = "SEQUENCE: M1 CATCH"
    statusLabel.Text = "Catch registered after the counter (practice event)."
    statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
    updateStats()

    task.wait(CATCH_DISPLAY_TIME)
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
                MIN_GAP_BETWEEN_STRINGS,
                MAX_GAP_BETWEEN_STRINGS
            ))

            if not running or thisRun ~= runId then
                break
            end

            cycleId += 1
            local thisCycle = cycleId
            local attackCount = random:NextInteger(
                MIN_ATTACKS_PER_STRING,
                MAX_ATTACKS_PER_STRING
            )

            -- Phase 1: opponent performs a multi-hit attack string.
            recoveryActive = false
            attackSequenceActive = true
            isBlocking = false
            isDodging = false

            for attackIndex = 1, attackCount do
                if not running or thisRun ~= runId or thisCycle ~= cycleId then
                    break
                end

                warningActive = true
                isBlocking = holdBlockEnabled and blockHP > DODGE_THRESHOLD
                isDodging = holdBlockEnabled and blockHP <= DODGE_THRESHOLD

                attackLabel.Text = string.format(
                    "⚠  OPPONENT ATTACKING  (%d / %d)",
                    attackIndex,
                    attackCount
                )
                attackLabel.TextColor3 = Color3.fromRGB(255, 190, 85)

                if isBlocking then
                    statusLabel.Text = "Hold Block is active; attack string is continuing."
                    statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
                elseif isDodging then
                    local dodgeName = random:NextInteger(1, 2) == 1
                        and "JUMP DODGE"
                        or "DASH DODGE"
                    statusLabel.Text = "LOW GUARD: simulated " .. dodgeName .. " for this hit."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
                else
                    statusLabel.Text = "Attack incoming; Hold Block is OFF."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
                end

                task.wait(WARNING_WINDOW)
                if not running or thisRun ~= runId or thisCycle ~= cycleId then
                    break
                end

                warningActive = false

                if isDodging then
                    dodgedCount += 1
                    attackLabel.Text = "↗  SIMULATED DODGE SUCCESS"
                    attackLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
                    statusLabel.Text = "Attack avoided; guard health preserved."
                    statusLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
                elseif isBlocking and holdBlockEnabled then
                    blockedCount += 1
                    blockHP -= BLOCK_HP_DAMAGE_PER_HIT
                    attackLabel.Text = "✓  SIMULATED ATTACK BLOCKED"
                    attackLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
                    statusLabel.Text = "Block held through impact; guard took simulated damage."
                    statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
                else
                    missedCount += 1
                    attackLabel.Text = "✕  SIMULATED HIT"
                    attackLabel.TextColor3 = Color3.fromRGB(255, 105, 105)
                    statusLabel.Text = "No block or dodge was active at impact."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
                end

                isBlocking = false
                isDodging = false
                updateBlockHealth()
                updateStats()

                if attackIndex < attackCount then
                    attackLabel.Text = string.format(
                        "OPPONENT STILL ATTACKING  (%d / %d)",
                        attackIndex,
                        attackCount
                    )
                    attackLabel.TextColor3 = Color3.fromRGB(255, 190, 85)
                    task.wait(ATTACK_GAP)
                end
            end

            if not running or thisRun ~= runId or thisCycle ~= cycleId then
                break
            end

            -- The opponent has ended the whole attack string.
            attackSequenceActive = false
            warningActive = false
            recoveryActive = true
            attackLabel.Text = "OPPONENT STOPPED  •  RECOVERY / COOLDOWN"
            attackLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
            statusLabel.Text = "Attack sequence ended. Waiting 1 second before counter."
            statusLabel.TextColor3 = Color3.fromRGB(180, 190, 208)
            sequenceLabel.Text = autoCounterEnabled
                and "SEQUENCE: opponent stopped; counter in 1.0s"
                or "SEQUENCE: opponent stopped; counter disabled"

            runCounterCatchSequence(thisRun, thisCycle)

            -- Guard begins recovering after the opponent's string ends.
            local beforeRecovery = blockHP
            blockHP = math.min(MAX_BLOCK_HP, blockHP + BLOCK_HP_RECOVERY)
            updateBlockHealth()

            if blockHP > beforeRecovery then
                statusLabel.Text = string.format(
                    "Recovery complete. Block HP restored to %d / %d.",
                    math.floor(blockHP + 0.5),
                    MAX_BLOCK_HP
                )
                statusLabel.TextColor3 = Color3.fromRGB(94, 220, 160)
            end

            if not running or thisRun ~= runId or thisCycle ~= cycleId then
                break
            end

            recoveryActive = false
            attackLabel.Text = "Opponent ready for next attack string."
            attackLabel.TextColor3 = Color3.fromRGB(210, 218, 230)
            if autoCounterEnabled then
                sequenceLabel.Text = "SEQUENCE: complete; waiting for next attack string"
            else
                sequenceLabel.Text = "SEQUENCE: waiting"
            end

            task.wait(0.4)
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

updateBlockHealth()
updateStats()
