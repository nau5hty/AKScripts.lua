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
panel.Position = UDim2.new(1, -348, 0, 90)
panel.BackgroundColor3 = Color3.fromRGB(19, 21, 27)
panel.BorderSizePixel = 0
panel.Parent = screen
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

local function nearbySameScope(candidate, timerObject)
    if getScreenGui(candidate) ~= getScreenGui(timerObject) then
        return false
    end
    if not isVisible(candidate) or not isTopRight(candidate) then
        return false
    end

    local a = candidate.AbsolutePosition + candidate.AbsoluteSize / 2
    local b = timerObject.AbsolutePosition + timerObject.AbsoluteSize / 2
    return (a - b).Magnitude <= 520
end

local function countHearts(raw)
    local _, count = tostring(raw or ""):gsub("♥", "")
    return count
end

local function getMatchSnapshot()
    local timerCandidates = {}

    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
            and isVisible(object) and isTopRight(object) then

            local value = cleanText(object.Text)
            local name = string.lower(object.Name)

            if isTimerText(value) or (name == "time" and isTimerText(value)) then
                table.insert(timerCandidates, {
                    object = object,
                    value = value,
                    score = (name == "time" and 5 or 0)
                })
            end
        end
    end

    if #timerCandidates == 0 then
        return nil
    end

    local best = nil
    for _, timerCandidate in ipairs(timerCandidates) do
        local timerObject = timerCandidate.object
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
        local leftHearts = nil
        local rightHearts = nil

        for _, object in ipairs(timerObject.Parent.Parent:GetDescendants()) do
            if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
                and nearbySameScope(object, timerObject) then

                local objectName = string.lower(object.Name)
                local raw = tostring(object.Text or "")
                local value = cleanText(raw)

                if objectName == "name" and value ~= "" and not isTimerText(value) then
                    table.insert(nameCandidates, {value = value, object = object})
                elseif objectName == "hpnum" and tonumber(value) then
                    table.insert(hpCandidates, {value = value, object = object})
                elseif objectName == "heartsl" and value ~= "" then
                    leftHearts = countHearts(raw)
                elseif objectName == "heartsr" and value ~= "" then
                    rightHearts = countHearts(raw)
                elseif objectName == "label" and value ~= "" then
                    table.insert(extraCandidates, value)
                end
            end
        end

        -- Some ScreenGuis use nested containers. If the timer's parent chain
        -- does not expose the ScreenGui, scan that ScreenGui directly.
        local root = getScreenGui(timerObject)
        if root then
            for _, object in ipairs(root:GetDescendants()) do
                if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
                    and nearbySameScope(object, timerObject) then
                    local objectName = string.lower(object.Name)
                    local raw = tostring(object.Text or "")
                    local value = cleanText(raw)

                    if objectName == "name" and value ~= "" and not isTimerText(value) then
                        local exists = false
                        for _, item in ipairs(nameCandidates) do
                            if item.object == object then exists = true break end
                        end
                        if not exists then table.insert(nameCandidates, {value = value, object = object}) end
                    elseif objectName == "hpnum" and tonumber(value) then
                        local exists = false
                        for _, item in ipairs(hpCandidates) do
                            if item.object == object then exists = true break end
                        end
                        if not exists then table.insert(hpCandidates, {value = value, object = object}) end
                    elseif objectName == "heartsl" and value ~= "" then
                        leftHearts = countHearts(raw)
                    elseif objectName == "heartsr" and value ~= "" then
                        rightHearts = countHearts(raw)
                    elseif objectName == "label" and value ~= "" then
                        table.insert(extraCandidates, value)
                    end
                end
            end
        end

        table.sort(nameCandidates, function(a, b)
            return (a.object.AbsolutePosition - timerObject.AbsolutePosition).Magnitude
                < (b.object.AbsolutePosition - timerObject.AbsolutePosition).Magnitude
        end)
        table.sort(hpCandidates, function(a, b)
            local ap = a.object.AbsolutePosition
            local bp = b.object.AbsolutePosition
            if ap.Y == bp.Y then return ap.X < bp.X end
            return ap.Y < bp.Y
        end)

        if nameCandidates[1] then
            snapshot.fighter = nameCandidates[1].value
            snapshot.score = snapshot.score + 10
        end

        for index = 1, math.min(#hpCandidates, 2) do
            table.insert(snapshot.hp, hpCandidates[index].value)
        end

        if #snapshot.hp >= 2 then
            snapshot.score = snapshot.score + 4
        elseif #snapshot.hp == 1 then
            snapshot.score = snapshot.score + 1
        end

        snapshot.heartsLeft = leftHearts
        snapshot.heartsRight = rightHearts
        snapshot.extra = extraCandidates[1]

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

    if not snapshot then
        status.Text = "WAITING FOR 1V1 HUD"
        status.BackgroundColor3 = Color3.fromRGB(43, 49, 61)
        fighterLine.Text = "Fighter: --"
        timerLine.Text = "Timer: --"
        hpLine.Text = "HUD HP values: -- / --"
        heartsLine.Text = "Hearts: --"
        extraLine.Text = "Other HUD label: --"

        if previous then
            addEvent("Match HUD disappeared")
            previous = nil
        end
        return
    end

    status.Text = snapshot.fighter and "MATCH HUD DETECTED" or "TIMER FOUND - HUD PARTIAL"
    status.BackgroundColor3 = snapshot.fighter and Color3.fromRGB(35, 91, 67) or Color3.fromRGB(111, 83, 40)

    fighterLine.Text = "Fighter: " .. (snapshot.fighter or "not found")
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
        addEvent("Match detected | " .. (snapshot.fighter or "fighter unknown"))
    else
        if snapshot.fighter ~= previous.fighter and snapshot.fighter then
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
