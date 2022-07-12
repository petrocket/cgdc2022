local Events = require "scripts.events"
local Utilities = require "scripts.utilities"

local Enemy = {
    Properties = {
        Debug = false,
        Name = "Enemy",
        MiniBoss = false,
        Boss = false,
        Type = 0, -- mechanical, magical, natural
        Randomness = {
            Enabled = false,
            WeaknessTypes = {
                Min = 2,
                Max = 2
            },
            AmountPerType = {
                Min = 1,
                Max = 1
            }
        },
        Weaknesses = {
            Type1 = 0,
            Type2 = 0,
            Type3 = 0,
            Type4 = 0
        }
    }
}

function Enemy:OnActivate()
    Utilities:InitLogging(self, "Enemy")
    Events:Connect(self, Events.OnStateChange)

    local translation = TransformBus.Event.GetWorldTranslation(self.entityId)
    local gridPosition = tostring(math.floor(translation.x)) .. "_" .. tostring(math.floor(translation.y))
    self:Log(gridPosition)
    Events:Connect(self, Events.GetEnemy, gridPosition)

    Events:Connect(self, Events.OnEnterCombat, gridPosition)
    Events:Connect(self, Events.OnExitCombat, gridPosition)
end

function Enemy:OnEnterCombat()
    self.inCombat = true 
    Events:GlobalLuaEvent(Events.OnSetEnemy, self.data)

    Events:Connect(self, Events.OnUpdateWeaknessAmount)
end

function Enemy:OnUpdateWeaknessAmount(weakness, amount)
    -- TODO FIX this is backwards... the UI is telling us what 
    -- the new weakness is, that logic should be here and
    -- the UI should reflect our data
    if self.data.Weaknesses[weakness] ~= nil then
        self.data.Weaknesses[weakness].Amount = amount
    end
end

function Enemy:OnExitCombat()
    Events:Disconnect(self, Events.OnUpdateWeaknessAmount)
    self.inCombat = false
end

function Enemy:Reset()
    self:Log("Reset")
    self.data = {
        Name = self.Properties.Name,
        MiniBoss = self.Properties.MiniBoss,
        Boss = self.Properties.Boss,
        Type = self.Properties.Type,
        Weaknesses = {}
    }

    if self.Properties.Randomness.Enabled then
        local weaknessTypes = {1,2,3,4}
        local rules = self.Properties.Randomness
        Utilities:Shuffle(weaknessTypes)
        local numWeaknessTypes = math.random(rules.WeaknessTypes.Min, rules.WeaknessTypes.Max)
        self:Log("Giving enemy " .. tostring(numWeaknessTypes) .. " random weakness types ")
        for i=1,numWeaknessTypes do
            local weaknessType = weaknessTypes[i]
            local amount = math.random(rules.AmountPerType.Min, rules.AmountPerType.Max)
            self.data.Weaknesses["Weakness"..tostring(weaknessType)] =  { Amount=amount}
            self:Log("Gave enemy " .. tostring(amount) .. " of weakness type " .. tostring(weaknessType))
        end
    else
        self.data.Weaknesses.Weakness1 = { Amount=math.floor(self.Properties.Weaknesses.Type1)}
        self.data.Weaknesses.Weakness2 = { Amount=math.floor(self.Properties.Weaknesses.Type2)}
        self.data.Weaknesses.Weakness3 = { Amount=math.floor(self.Properties.Weaknesses.Type3)}
        self.data.Weaknesses.Weakness4 = { Amount=math.floor(self.Properties.Weaknesses.Type4)}
    end
end

function Enemy:GetEnemy()
    return self.data
end

function Enemy:OnStateChange(newState)
    if newState == 'LevelBuildOut' then
        self:Reset()
    end
end

function Enemy:OnDeactivate()
    Events:Disconnect(self, Events.GetEnemy)
    Events:Disconnect(self, Events.OnStateChange)
    Events:Disconnect(self, Events.OnEnterCombat)
    Events:Disconnect(self, Events.OnExitCombat)
end

return Enemy