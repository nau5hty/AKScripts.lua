-- AXScripts Practice Combat AI - Studio demo adapter
-- Put this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Put PracticeCombatAI.lua in ReplicatedStorage as a ModuleScript.
-- Tag one or more practice dummy Models with CollectionService tag "AXPracticeNPC".
--
-- This demo ONLY prints simulated M1/skill decisions. It does not damage anything
-- and does not connect to any live game's combat system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PracticeCombatAI = require(
    ReplicatedStorage:WaitForChild("PracticeCombatAI")
)

local skillCooldowns = {}
local SKILL_COOLDOWN = 3

local adapter = {
    CanM1 = function(target)
        return target ~= nil
    end,

    M1 = function(target)
        print("[AXScripts Demo] M1 decision -> " .. target.Name)
    end,

    CanUseSkill = function(skillId, target)
        return target ~= nil and (skillCooldowns[skillId] or 0) <= os.clock()
    end,

    UseSkill = function(skillId, target)
        skillCooldowns[skillId] = os.clock() + SKILL_COOLDOWN
        print("[AXScripts Demo] Skill decision -> " .. skillId .. " on " .. target.Name)
    end,

    -- No incoming-attack signal is simulated in this basic demo.
    GetIncomingAttack = function(character)
        return nil
    end,

    OnStateChanged = function(state, target, reason)
        print("[AXScripts Demo] State: " .. state
            .. " | Target: " .. (target and target.Name or "none")
            .. " | " .. tostring(reason))
    end,
}

local ai = PracticeCombatAI.new(adapter, {
    NPCTag = "AXPracticeNPC",
    SearchRadius = 60,
    AttackRange = 9,
    AutoM1 = true,
    AutoSkills = true,
    SmartBlock = false,
    AutoCounter = false,
})

local started, message = ai:Start()
print("[AXScripts Demo] " .. tostring(message))

script.Destroying:Connect(function()
    ai:Stop()
end)
