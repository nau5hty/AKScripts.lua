-- AXScripts | Opponent HUD Monitor
-- Read-only client HUD monitor. No combat inputs, remotes, target selection, or gameplay changes.
-- Run as a client-side LocalScript in an environment where client UI inspection is authorized.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[AX HUD Monitor] LocalPlayer unavailable. This must run on the client.")
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GUI_NAME = "AXOpponentHUDMonitor"

local oldGui = PlayerGui:FindFirstChild(GUI_NAME)
if oldGui then
    oldGui:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = GUI_NAME
screen.ResetOnSpawn = false
screen.DisplayOrder = 10000
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(330, 258)
panel.Position = UDim2.new(0, 16, 1, -276)
panel.BackgroundColor3 = Color3.fromRGB(19, 21, 27)
panel.BorderSizePixel = 0
panel.Parent = screen
panel.Visible = false
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(74, 82, 99)
stroke.Thickness = 1
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -18, 0, 28)
title.Position = UDim2.fromOffset(10, 7)
title.BackgroundTransparency = 1
title.Text = "AXScripts | Opponent HUD Monitor"
title.TextColor3 = Color3.fromRGB(245, 246, 250)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(28, 26)
close.Position = UDim2.new(1, -34, 0, 7)
close.BackgroundColor3 = Color3.fromRGB(104, 49, 55)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 12
close.Parent = panel
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -20, 0, 22)
status.Position = UDim2.fromOffset(10, 39)
status.BackgroundColor3 = Color3.fromRGB(43, 49, 61)
status.Text = "WAITING FOR 1V1 HUD"
status.TextColor3 = Color3.fromRGB(225, 230, 238)
status.Font = Enum.Font.GothamBold
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 5)

local function makeLine(name, y, initial)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.fromOffset(11, y)
    label.BackgroundTransparency = 1
    label.Text = initial
    label.TextColor3 = Color3.fromRGB(225, 230, 238)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = panel
    return label
end

local fighterLine = makeLine("Fighter", 68, "Fighter: --")
local timerLine = makeLine("Timer", 89, "Timer: --")
local hpLine = makeLine("Health", 110, "HUD HP values: -- / --")
local heartsLine = makeLine("Hearts", 131, "Hearts: --")
local extraLine = makeLine("Extra", 152, "Other HUD label: --")

local historyTitle = Instance.new("TextLabel")
historyTitle.Name = "HistoryTitle"
historyTitle.Size = UDim2.new(1, -20, 0, 17)
historyTitle.Position = UDim2.fromOffset(11, 178)
historyTitle.BackgroundTransparency = 1
historyTitle.Text = "RECENT HUD CHANGES"
historyTitle.TextColor3 = Color3.fromRGB(153, 173, 201)
historyTitle.Font = Enum.Font.GothamBold
historyTitle.TextSize = 9
historyTitle.TextXAlignment = Enum.TextXAlignment.Left
historyTitle.Parent = panel

local history = Instance.new("TextLabel")
history.Name = "History"
history.Size = UDim2.new(1, -20, 0, 54)
history.Position = UDim2.fromOffset(11, 196)
history.BackgroundTransparency = 1
history.Text = "Waiting for match data..."
history.TextColor3 = Color3.fromRGB(190, 198, 211)
history.Font = Enum.Font.Code
history.TextSize = 10
history.TextWrapped = true
history.TextYAlignment = Enum.TextYAlignment.Top
history.TextXAlignment = Enum.TextXAlignment.Left
history.Parent = panel

local function isVisible(object)
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

local function cleanText(value)
    local text = tostring(value or "")
    text = text:gsub("<[^>]->", "")
    text = text:gsub("[%c]", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function isTimerText(value)
    return value:match("^%d+:%d%d$") ~= nil
end

local function isTopRight(object)
    local camera = Workspace.CurrentCamera
    if not camera then
        return false
    end

    local viewport = camera.ViewportSize
    local pos = object.AbsolutePosition
    local size = object.AbsoluteSize
    local centerX = pos.X + size.X / 2
    local centerY = pos.Y + size.Y / 2

    return centerX >= viewport.X * 0.48 and centerY <= viewport.Y * 0.58
end

local function getScreenGui(object)
    local current = object
    while current and current ~= PlayerGui do
        if current:IsA("ScreenGui") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function screenDistance(a, b)
    local ap = a.AbsolutePosition + a.AbsoluteSize / 2
    local bp = b.AbsolutePosition + b.AbsoluteSize / 2
    return (ap - bp).Magnitude
end

local function getMatchSnapshot()
    local timerCandidates = {}

    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
            and isVisible(object) and isTopRight(object) then

            local value = cleanText(object.Text)
            local objectName = string.lower(object.Name)

            if isTimerText(value) then
                table.insert(timerCandidates, {
                    object = object,
                    value = value,
                    score = objectName == "time" and 5 or 0
                })
            end
        end
    end

    if #timerCandidates == 0 then
        return nil
    end

    local best = nil
    local allObjects = PlayerGui:GetDescendants()

    for _, timerCandidate in ipairs(timerCandidates) do
        local timerObject = timerCandidate.object
        local timerScreen = getScreenGui(timerObject)
        local snapshot = {
            timer = timerCandidate.value,
            fighter = nil,
            hp = {},
            heartsLeft = nil,
            heartsRight = nil,
            extra = nil,
            score = timerCandidate.score
        }

        local nameCandidates = {}
        local hpCandidates = {}
        local extraCandidates = {}

        -- Search visible PlayerGui labels instead of requiring every HUD
        -- element to share one ScreenGui and the exact same screen region.
        for _, object in ipairs(allObjects) do
            if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
                and object ~= timerObject
                and isVisible(object) then

                local raw = tostring(object.Text or "")
                local value = cleanText(raw)
                local objectName = string.lower(object.Name)
                local distance = screenDistance(object, timerObject)
                local sameScreen = getScreenGui(object) == timerScreen

                -- Ignore very distant UI labels, but allow separate ScreenGuis.
                if distance <= 900 then
                    local scopeBonus = sameScreen and 250 or 0
                    local proximityScore = scopeBonus - distance

                    if objectName == "name" and value ~= "" and not isTimerText(value) then
                        table.insert(nameCandidates, {
                            value = value,
                            object = object,
                            score = proximityScore
                        })
                    elseif objectName == "hpnum" and tonumber(value) then
                        table.insert(hpCandidates, {
                            value = value,
                            object = object,
                            score = proximityScore
                        })
                    elseif objectName == "heartsl" and value ~= "" then
                        if not snapshot.heartsLeft or proximityScore > snapshot.heartsLeftScore then
                            snapshot.heartsLeft = countHearts(raw)
                            snapshot.heartsLeftScore = proximityScore
                        end
                    elseif objectName == "heartsr" and value ~= "" then
                        if not snapshot.heartsRight or proximityScore > snapshot.heartsRightScore then
                            snapshot.heartsRight = countHearts(raw)
                            snapshot.heartsRightScore = proximityScore
                        end
                    elseif objectName == "label" and value ~= "" then
                        table.insert(extraCandidates, {
                            value = value,
                            score = proximityScore
                        })
                    end
                end
            end
        end

        table.sort(nameCandidates, function(a, b)
            return a.score > b.score
        end)
        table.sort(hpCandidates, function(a, b)
            return a.score > b.score
        end)
        table.sort(extraCandidates, function(a, b)
            return a.score > b.score
        end)

        if nameCandidates[1] then
            snapshot.fighter = nameCandidates[1].value
            snapshot.score = snapshot.score + 10 + math.max(0, nameCandidates[1].score / 100)
        end

        for index = 1, math.min(#hpCandidates, 2) do
            table.insert(snapshot.hp, hpCandidates[index].value)
        end

        if #snapshot.hp >= 2 then
            snapshot.score = snapshot.score + 4
        elseif #snapshot.hp == 1 then
            snapshot.score = snapshot.score + 1
        end

        if snapshot.heartsLeft ~= nil or snapshot.heartsRight ~= nil then
            snapshot.score = snapshot.score + 2
        end

        snapshot.extra = extraCandidates[1] and extraCandidates[1].value or nil

        if snapshot.score > (best and best.score or -1) then
            best = snapshot
        end
    end

    return best
end

local events = {}
local previous = nil

local function addEvent(value)
    if events[1] == value then
        return
    end
    table.insert(events, 1, value)
    while #events > 4 do
        table.remove(events)
    end
    history.Text = table.concat(events, "\n")
end

local function update()
    local snapshot = getMatchSnapshot()

    -- Only show the monitor when the match HUD has all core signals:
    -- a running mm:ss timer, a fighter name, and both numeric HP readings.
    -- This avoids showing it for unrelated lobby/event timers.
    local matchActive = snapshot ~= nil
        and snapshot.fighter ~= nil
        and #snapshot.hp >= 2

    if not matchActive then
        panel.Visible = false

        if previous then
            events = {}
            history.Text = "Waiting for match data..."
            previous = nil
        end
        return
    end

    panel.Visible = true
    status.Text = "MATCH HUD DETECTED"
    status.BackgroundColor3 = Color3.fromRGB(35, 91, 67)

    fighterLine.Text = "Fighter: " .. snapshot.fighter
    timerLine.Text = "Timer: " .. (snapshot.timer or "--")
    hpLine.Text = "HUD HP values: " .. (snapshot.hp[1] or "--") .. " / " .. (snapshot.hp[2] or "--")

    if snapshot.heartsLeft ~= nil or snapshot.heartsRight ~= nil then
        heartsLine.Text = "Hearts (visible HUD): " .. tostring(snapshot.heartsLeft or "--")
            .. " / " .. tostring(snapshot.heartsRight or "--")
    else
        heartsLine.Text = "Hearts: not exposed in this HUD group"
    end

    extraLine.Text = "Other HUD label: " .. (snapshot.extra or "--")

    if not previous then
        addEvent("Match detected | " .. snapshot.fighter)
    else
        if snapshot.fighter ~= previous.fighter then
            addEvent("Fighter: " .. snapshot.fighter)
        end
        if snapshot.hp[1] ~= previous.hp[1] or snapshot.hp[2] ~= previous.hp[2] then
            addEvent("HP: " .. (snapshot.hp[1] or "--") .. " / " .. (snapshot.hp[2] or "--"))
        end
        if snapshot.heartsLeft ~= previous.heartsLeft or snapshot.heartsRight ~= previous.heartsRight then
            if snapshot.heartsLeft ~= nil or snapshot.heartsRight ~= nil then
                addEvent("Hearts: " .. tostring(snapshot.heartsLeft or "--")
                    .. " / " .. tostring(snapshot.heartsRight or "--"))
            end
        end
    end

    previous = snapshot
end

close.Activated:Connect(function()
    screen:Destroy()
end)

-- Drag from the title bar on mouse or touch.
local dragging = false
local dragInput
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
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

title.InputChanged:Connect(function(input)
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

task.spawn(function()
    while screen.Parent do
        local ok, err = pcall(update)
        if not ok then
            status.Text = "HUD READ ERROR"
            status.BackgroundColor3 = Color3.fromRGB(115, 47, 47)
            fighterLine.Text = tostring(err):sub(1, 70)
        end
        task.wait(0.3)
    end
end)

print("[AX HUD Monitor] Loaded. Waiting for a visible 1v1 HUD.")
