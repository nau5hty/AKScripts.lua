-- AXScripts | Opponent Target Diagnostic
-- Read-only: displays visible upper-right HUD text and nearby live character models.
-- It does NOT block, attack, target-lock, call remotes, or change gameplay.
-- Run only in an environment where you are authorized to inspect the client UI.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[AX Target Diagnostic] LocalPlayer is unavailable. Run this as a client LocalScript.")
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GUI_NAME = "AXOpponentTargetDiagnostic"
local SCAN_RADIUS = 150
local MAX_ROWS = 12

local oldGui = PlayerGui:FindFirstChild(GUI_NAME)
if oldGui then
    oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(360, 330)
panel.Position = UDim2.fromOffset(16, 100)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(75, 82, 96)
panelStroke.Thickness = 1
panelStroke.Parent = panel

local titleBar = Instance.new("TextLabel")
titleBar.Name = "Title"
titleBar.Size = UDim2.new(1, -16, 0, 32)
titleBar.Position = UDim2.fromOffset(8, 5)
titleBar.BackgroundTransparency = 1
titleBar.Text = "AXScripts | Opponent Diagnostic"
titleBar.TextColor3 = Color3.fromRGB(245, 245, 248)
titleBar.Font = Enum.Font.GothamBold
titleBar.TextSize = 14
titleBar.TextXAlignment = Enum.TextXAlignment.Left
titleBar.Parent = panel

local refreshButton = Instance.new("TextButton")
refreshButton.Name = "Refresh"
refreshButton.Size = UDim2.fromOffset(88, 28)
refreshButton.Position = UDim2.new(1, -190, 0, 39)
refreshButton.BackgroundColor3 = Color3.fromRGB(48, 92, 145)
refreshButton.Text = "REFRESH"
refreshButton.TextColor3 = Color3.new(1, 1, 1)
refreshButton.Font = Enum.Font.GothamBold
refreshButton.TextSize = 11
refreshButton.Parent = panel
Instance.new("UICorner", refreshButton).CornerRadius = UDim.new(0, 6)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Size = UDim2.fromOffset(88, 28)
closeButton.Position = UDim2.new(1, -96, 0, 39)
closeButton.BackgroundColor3 = Color3.fromRGB(105, 52, 58)
closeButton.Text = "CLOSE"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 11
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

local output = Instance.new("ScrollingFrame")
output.Name = "Output"
output.Size = UDim2.new(1, -20, 1, -80)
output.Position = UDim2.fromOffset(10, 74)
output.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
output.BorderSizePixel = 0
output.ScrollBarThickness = 5
output.AutomaticCanvasSize = Enum.AutomaticSize.Y
output.CanvasSize = UDim2.new(0, 0, 0, 0)
output.Parent = panel
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 7)

local outputText = Instance.new("TextLabel")
outputText.Name = "OutputText"
outputText.Size = UDim2.new(1, -12, 0, 0)
outputText.AutomaticSize = Enum.AutomaticSize.Y
outputText.BackgroundTransparency = 1
outputText.TextColor3 = Color3.fromRGB(220, 226, 235)
outputText.Font = Enum.Font.Code
outputText.TextSize = 12
outputText.TextXAlignment = Enum.TextXAlignment.Left
outputText.TextYAlignment = Enum.TextYAlignment.Top
outputText.TextWrapped = true
outputText.RichText = false
outputText.Text = "Press REFRESH while a 1v1 match is active."
outputText.Parent = output

local outputPadding = Instance.new("UIPadding")
outputPadding.PaddingTop = UDim.new(0, 8)
outputPadding.PaddingBottom = UDim.new(0, 8)
outputPadding.PaddingLeft = UDim.new(0, 8)
outputPadding.PaddingRight = UDim.new(0, 8)
outputPadding.Parent = outputText

local function isGuiVisible(object)
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

local function readUpperRightHudText()
    local camera = Workspace.CurrentCamera
    if not camera then
        return {}
    end

    local viewport = camera.ViewportSize
    local matches = {}

    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            local value = tostring(object.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if value ~= "" and isGuiVisible(object) then
                local position = object.AbsolutePosition
                local size = object.AbsoluteSize
                local isUpperRight = position.X + size.X >= viewport.X * 0.52
                    and position.Y <= viewport.Y * 0.48

                if isUpperRight then
                    value = value:gsub("[%c]", " ")
                    if #value > 70 then
                        value = value:sub(1, 67) .. "..."
                    end
                    table.insert(matches, {
                        y = position.Y,
                        x = position.X,
                        text = object.Name .. " = " .. value
                    })
                end
            end
        end
    end

    table.sort(matches, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)

    local lines = {}
    for index = 1, math.min(#matches, 10) do
        table.insert(lines, matches[index].text)
    end
    return lines
end

local function getNearbyCharacters()
    local localCharacter = LocalPlayer.Character
    local localRoot = localCharacter and (
        localCharacter:FindFirstChild("HumanoidRootPart")
        or localCharacter.PrimaryPart
    )

    if not localRoot then
        return {}, "Your character root part was not found."
    end

    local found = {}
    local seen = {}

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") and object ~= localCharacter and not seen[object] then
            local humanoid = object:FindFirstChildOfClass("Humanoid")
            local root = object:FindFirstChild("HumanoidRootPart")
                or object.PrimaryPart
                or object:FindFirstChild("Torso")

            if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
                local distance = (root.Position - localRoot.Position).Magnitude
                if distance <= SCAN_RADIUS then
                    seen[object] = true
                    local player = Players:GetPlayerFromCharacter(object)
                    local kind = player and "PLAYER" or "NPC/UNKNOWN"
                    local displayName = humanoid.DisplayName

                    table.insert(found, {
                        model = object.Name,
                        display = displayName,
                        kind = kind,
                        distance = distance,
                        health = humanoid.Health,
                        maxHealth = humanoid.MaxHealth
                    })
                end
            end
        end
    end

    table.sort(found, function(a, b)
        return a.distance < b.distance
    end)

    return found
end

local function refresh()
    local lines = {}
    table.insert(lines, "READ-ONLY DIAGNOSTIC - no combat actions")
    table.insert(lines, "Radius: " .. tostring(SCAN_RADIUS) .. " studs")
    table.insert(lines, "")

    table.insert(lines, "TOP-RIGHT HUD TEXT:")
    local hudLines = readUpperRightHudText()
    if #hudLines == 0 then
        table.insert(lines, "  No visible text labels found in that area.")
        table.insert(lines, "  The HUD may use images or a different position.")
    else
        for _, line in ipairs(hudLines) do
            table.insert(lines, "  " .. line)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "NEARBY LIVE CHARACTERS (nearest first):")
    local characters, err = getNearbyCharacters()
    if err then
        table.insert(lines, "  " .. err)
    elseif #characters == 0 then
        table.insert(lines, "  None found within the scan radius.")
    else
        for index = 1, math.min(#characters, MAX_ROWS) do
            local item = characters[index]
            local line = string.format(
                "%d) %s | %s | %.0f studs | HP %.0f/%.0f",
                index,
                item.model,
                item.kind,
                item.distance,
                item.health,
                item.maxHealth
            )
            if item.display ~= "" and item.display ~= item.model then
                line = line .. " | Display: " .. item.display
            end
            table.insert(lines, line)
        end
        if #characters > MAX_ROWS then
            table.insert(lines, "... plus " .. tostring(#characters - MAX_ROWS) .. " more.")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Send the HUD lines and character list back.")
    outputText.Text = table.concat(lines, "\n")
end

refreshButton.Activated:Connect(refresh)
closeButton.Activated:Connect(function()
    screenGui:Destroy()
end)

-- Allow dragging the panel on mouse or touch devices.
local dragging = false
local dragInput
local dragStart
local startPosition

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

refresh()
print("[AX Target Diagnostic] Loaded. Use REFRESH during an active 1v1.")
