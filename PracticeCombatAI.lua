-- AXScripts Practice Combat AI
-- Studio-only decision engine for NPCs in a Roblox place you control.
-- It deliberately cannot run in a live experience.
--
-- Setup:
--   1) Add this file as a ModuleScript named PracticeCombatAI.
--   2) Tag your practice dummy Models with CollectionService tag "AXPracticeNPC".
--   3) Require this module from a LocalScript in StarterPlayerScripts.
--   4) Supply an adapter that calls YOUR OWN game's NPC-practice functions.
--
-- Adapter methods (only methods your own place implements):
--   CanM1(target) -> boolean
--   M1(target)
--   CanUseSkill(skillId, target) -> boolean
--   UseSkill(skillId, target)
--   GetIncomingAttack(character) -> { attacker = Model, timeToImpact = number } or nil
--   CanBlock() -> boolean
--   Block()
--   CanCounter(attacker) -> boolean
--   Counter(attacker)
--   IsTargetBlocking(target) -> boolean   -- optional; defaults to target:GetAttribute("IsBlocking")
--   OnStateChanged(state, target, reason)  -- optional
--
-- No remotes, executor hooks, player targeting, or game-specific internals are included.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local PracticeCombatAI = {}
PracticeCombatAI.__index = PracticeCombatAI

local DEFAULTS = {
    NPCTag = "AXPracticeNPC",
    SearchRadius = 60,
    AttackRange = 9,
    BlockReactionWindow = 0.35,
    TickInterval = 0.10,
    MoveRefreshInterval = 0.35,
    M1RetryInterval = 0.18,
    SkillRetryInterval = 0.20,
    PreferCounter = true,

    -- These are adapter identifiers, not remote names.
    SkillPriority = {
        "DivineDog",
        "ConsecutiveSlashes",
        "MaxElephant",
        "ShadowGeneral",
    },

    AutoM1 = true,
    AutoSkills = true,
    SmartBlock = true,
    AutoCounter = true,
}

local function copyConfig(config)
    local result = {}
    for key, value in pairs(DEFAULTS) do
        if type(value) == "table" then
            result[key] = table.clone(value)
        else
            result[key] = value
        end
    end

    for key, value in pairs(config or {}) do
        if key == "SkillPriority" and type(value) == "table" then
            result[key] = table.clone(value)
        else
            result[key] = value
        end
    end
    return result
end

local function getRoot(model)
    return model and model:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function isValidPracticeNPC(model, tag)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then
        return false
    end
    if not model:IsDescendantOf(Workspace) then
        return false
    end
    if not CollectionService:HasTag(model, tag) then
        return false
    end
    if Players:GetPlayerFromCharacter(model) then
        return false
    end

    local humanoid = getHumanoid(model)
    return humanoid ~= nil and humanoid.Health > 0 and getRoot(model) ~= nil
end

function PracticeCombatAI.new(adapter, config)
    assert(type(adapter) == "table", "PracticeCombatAI requires an adapter table")

    local self = setmetatable({}, PracticeCombatAI)
    self.Adapter = adapter
    self.Config = copyConfig(config)
    self.State = "STOPPED"
    self.Target = nil
    self.Reason = "Not started"
    self._connection = nil
    self._elapsed = 0
    self._nextMoveAt = 0
    self._nextM1At = 0
    self._nextSkillAt = 0
    self._lastAction = "None"
    return self
end

function PracticeCombatAI:_setState(state, target, reason)
    local changed = self.State ~= state or self.Target ~= target or self.Reason ~= reason
    self.State = state
    self.Target = target
    self.Reason = reason or ""

    if changed and type(self.Adapter.OnStateChanged) == "function" then
        pcall(self.Adapter.OnStateChanged, state, target, self.Reason)
    end
end

function PracticeCombatAI:_call(name, ...)
    local callback = self.Adapter[name]
    if type(callback) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(callback, ...)
    if not ok then
        warn("[AXScripts Practice AI] Adapter method " .. name .. " failed: " .. tostring(result))
        return false, nil
    end
    return true, result
end

function PracticeCombatAI:_getCharacter()
    local ok, character = self:_call("GetCharacter")
    if ok and character then
        return character
    end
    return LocalPlayer and LocalPlayer.Character
end

function PracticeCombatAI:_getNPCs()
    local ok, models = self:_call("GetNPCs", self.Config.NPCTag)
    if ok and type(models) == "table" then
        return models
    end
    return CollectionService:GetTagged(self.Config.NPCTag)
end

function PracticeCombatAI:_findTarget(characterRoot)
    local nearest = nil
    local nearestDistance = self.Config.SearchRadius

    for _, model in ipairs(self:_getNPCs()) do
        if isValidPracticeNPC(model, self.Config.NPCTag) then
            local targetRoot = getRoot(model)
            local distance = (targetRoot.Position - characterRoot.Position).Magnitude
            if distance < nearestDistance then
                nearest = model
                nearestDistance = distance
            end
        end
    end

    return nearest, nearestDistance
end

function PracticeCombatAI:_moveTo(targetRoot, humanoid)
    local now = os.clock()
    if now < self._nextMoveAt then
        return
    end
    self._nextMoveAt = now + self.Config.MoveRefreshInterval

    local ok = self:_call("MoveTo", targetRoot.Position, humanoid, targetRoot)
    if not ok then
        humanoid:MoveTo(targetRoot.Position)
    end
end

function PracticeCombatAI:_stopMovement(humanoid)
    if type(self.Adapter.StopMoving) == "function" then
        self:_call("StopMoving", humanoid)
    else
        local root = humanoid.Parent and getRoot(humanoid.Parent)
        if root then
            humanoid:MoveTo(root.Position)
        end
    end
end

function PracticeCombatAI:_isTargetBlocking(target)
    local ok, result = self:_call("IsTargetBlocking", target)
    if ok then
        return result == true
    end
    return target:GetAttribute("IsBlocking") == true
end

function PracticeCombatAI:_handleDefense(character)
    if not self.Config.SmartBlock then
        return false
    end

    local ok, threat = self:_call("GetIncomingAttack", character)
    if not ok or type(threat) ~= "table" then
        return false
    end

    local timeToImpact = tonumber(threat.timeToImpact)
    if not timeToImpact or timeToImpact < 0 or timeToImpact > self.Config.BlockReactionWindow then
        return false
    end

    local attacker = threat.attacker
    if self.Config.AutoCounter and self.Config.PreferCounter then
        local canCounterOk, canCounter = self:_call("CanCounter", attacker)
        if canCounterOk and canCounter == true then
            local counterOk = self:_call("Counter", attacker)
            if counterOk then
                self._lastAction = "Counter"
                self:_setState("DEFEND", self.Target, "Countered an incoming NPC attack")
                return true
            end
        end
    end

    local canBlockOk, canBlock = self:_call("CanBlock")
    if canBlockOk and canBlock == true then
        local blockOk = self:_call("Block")
        if blockOk then
            self._lastAction = "Block"
            self:_setState("DEFEND", self.Target, "Blocked an incoming NPC attack")
            return true
        end
    end

    return false
end

function PracticeCombatAI:_attack(target)
    local now = os.clock()

    if self.Config.AutoSkills and now >= self._nextSkillAt then
        for _, skillId in ipairs(self.Config.SkillPriority) do
            local canUseOk, canUse = self:_call("CanUseSkill", skillId, target)
            if canUseOk and canUse == true then
                local useOk = self:_call("UseSkill", skillId, target)
                self._nextSkillAt = now + self.Config.SkillRetryInterval
                if useOk then
                    self._lastAction = "Skill: " .. tostring(skillId)
                    self:_setState("ATTACK", target, "Used available skill " .. tostring(skillId))
                    return true
                end
            end
        end
    end

    if self.Config.AutoM1 and now >= self._nextM1At then
        local canM1Ok, canM1 = self:_call("CanM1", target)
        if canM1Ok and canM1 == true then
            local m1Ok = self:_call("M1", target)
            self._nextM1At = now + self.Config.M1RetryInterval
            if m1Ok then
                self._lastAction = "M1"
                self:_setState("ATTACK", target, "Used basic attack")
                return true
            end
        end
    end

    self:_setState("RECOVER", target, "Waiting for an attack or skill cooldown")
    return false
end

function PracticeCombatAI:Step()
    if not RunService:IsStudio() then
        self:_setState("STOPPED", nil, "Practice AI is restricted to Roblox Studio")
        return self.State, self.Target, self.Reason
    end

    local character = self:_getCharacter()
    local humanoid = getHumanoid(character)
    local characterRoot = getRoot(character)

    if not character or not humanoid or humanoid.Health <= 0 or not characterRoot then
        self:_setState("SEARCH", nil, "Waiting for your character")
        return self.State, self.Target, self.Reason
    end

    local target, distance = self:_findTarget(characterRoot)
    if not target then
        self.Target = nil
        self:_stopMovement(humanoid)
        self:_setState("SEARCH", nil, "No tagged practice NPC in search radius")
        return self.State, self.Target, self.Reason
    end

    self.Target = target

    if self:_handleDefense(character) then
        return self.State, self.Target, self.Reason
    end

    local targetRoot = getRoot(target)
    if not targetRoot then
        self:_setState("SEARCH", nil, "Practice NPC has no root part")
        return self.State, self.Target, self.Reason
    end

    if distance > self.Config.AttackRange then
        self:_moveTo(targetRoot, humanoid)
        self:_setState("APPROACH", target, "Moving into attack range")
        return self.State, self.Target, self.Reason
    end

    if self:_isTargetBlocking(target) then
        self:_stopMovement(humanoid)
        self:_setState("OBSERVE", target, "Target is blocking; holding attacks")
        return self.State, self.Target, self.Reason
    end

    self:_attack(target)
    return self.State, self.Target, self.Reason
end

function PracticeCombatAI:Start()
    if not RunService:IsStudio() then
        self:_setState("STOPPED", nil, "Practice AI can only start in Roblox Studio")
        return false, self.Reason
    end
    if self._connection then
        return true, "Already running"
    end

    self._elapsed = 0
    self._connection = RunService.Heartbeat:Connect(function(deltaTime)
        self._elapsed += deltaTime
        if self._elapsed >= self.Config.TickInterval then
            self._elapsed = 0
            self:Step()
        end
    end)

    self:_setState("SEARCH", nil, "Practice AI started")
    return true, "Started"
end

function PracticeCombatAI:Stop()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self:_setState("STOPPED", nil, "Stopped by user")
end

function PracticeCombatAI:GetStatus()
    return {
        state = self.State,
        target = self.Target and self.Target.Name or nil,
        reason = self.Reason,
        lastAction = self._lastAction,
    }
end

return PracticeCombatAI
