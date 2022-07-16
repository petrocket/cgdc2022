local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Card = require "scripts.card"

local UiEnemy = {
    Properties = {
        Debug = false,
        Name = EntityId(),
        Weaknesses = EntityId()
    }
}

function UiEnemy:OnActivate()
    Utilities:InitLogging(self, "UiEnemy")

    Events:Connect(self, Events.OnSetEnemy)
    Events:Connect(self, Events.OnTakeDamage)
    self:Log("OnActivate")
    self.weaknessAmounts = {}
end

function UiEnemy:Reset()
    self.weaknessAmounts = {}
    local weaknesses = UiElementBus.Event.GetChildren(self.Properties.Weaknesses)
    for i=1,#weaknesses do
        local weakness = weaknesses[i]
        self:HideAllChildren(weakness)
        UiElementBus.Event.SetIsEnabled(weakness, false)
    end
end

function UiEnemy:HideAllChildren(parent)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        UiElementBus.Event.SetIsEnabled(children[i], false)
    end
end

function UiEnemy:OnSetEnemy(enemy)
    self:Log("Set Enemy " .. tostring(enemy.Name)) 
    UiTextBus.Event.SetText(self.Properties.Name, enemy.Name)

    self:Reset()

    for weakness, data in pairs(enemy.Weaknesses) do
        self:UpdateWeaknessAmount(weakness, data.Amount)
    end
end

function UiEnemy:OnTakeDamage(cardType, unused)
    local weaknesses = Card:GetWeaknessesForCard(cardType)
    local damageTaken = false
    for weakness, amount in pairs(weaknesses) do
        local currentAmount = self:GetWeaknessAmount(weakness)
        self:Log("OnTakeDamage " .. tostring(weakness) .. " " .. tostring(amount) .. " current amount " .. tostring(currentAmount)) 
        if currentAmount > 0 then
            damageTaken = damageTaken or self:UpdateWeaknessAmount(weakness, currentAmount - amount)
        end
    end

    if not self:HasWeaknesses() then
        self:Log("No more weaknesses")
        Events:GlobalLuaEvent(Events.OnEnemyDefeated)
    end

    return damageTaken
end

function UiEnemy:GetWeaknessAmount(weakness)
    if self.weaknessAmounts[weakness] ~= nil then
        return self.weaknessAmounts[weakness]
    end
    return 0
end

function UiEnemy:UpdateWeaknessAmount(weakness, amount)
    if self.weaknessAmounts[weakness] == nil then
        self.weaknessAmounts[weakness] = 0
    end
    if self.weaknessAmounts[weakness] < 0 then
        self:Log("Trying to set weakness amount less than 0 for weakness " ..tostring(weakness))
        return false
    end

    local weaknesses = UiElementBus.Event.GetChildren(self.Properties.Weaknesses)

    if amount > self.weaknessAmounts[weakness] then
        -- append to end 

        for i=1,#weaknesses do
            local entityId = UiElementBus.Event.FindChildByName(self.Properties.Weaknesses, "Weakness"..tostring(i))
            local isEnabled = UiElementBus.Event.IsEnabled(entityId)
            if not isEnabled then
                -- look for an image element with the name that matches the weakness
                local child = UiElementBus.Event.FindChildByName(entityId, weakness)
                if child ~= nil and child:IsValid() then
                    UiElementBus.Event.SetIsEnabled(entityId, true)
                    UiElementBus.Event.SetIsEnabled(child, true)
                    self.weaknessAmounts[weakness] = self.weaknessAmounts[weakness] + 1
                    self:Log("Enabled weakness " ..weakness)

                    if self.weaknessAmounts[weakness] == amount then
                        -- done removing weaknesses
                        break
                    end
                else
                    self:Log("Failed to find child for weakness " ..tostring(weakness))
                end
            end
        end
    elseif amount < self.weaknessAmounts[weakness] then
        -- remove from end
        for i=#weaknesses, 1, -1 do
            local entityId = UiElementBus.Event.FindChildByName(self.Properties.Weaknesses, "Weakness"..tostring(i))
            local isEnabled = UiElementBus.Event.IsEnabled(entityId)
            if isEnabled then
                -- look for an image element with the name that matches the weakness
                local child = UiElementBus.Event.FindChildByName(entityId, weakness)
                if child ~= nil and child:IsValid() then
                    local childIsEnabled = UiElementBus.Event.IsEnabled(child)
                    if childIsEnabled then
                        UiElementBus.Event.SetIsEnabled(child, false)
                        self.weaknessAmounts[weakness] = self.weaknessAmounts[weakness] - 1
                        self:Log("Disabled weakness " ..weakness)

                        if self.weaknessAmounts[weakness] == amount then
                            -- done removing weaknesses
                            break 
                        end
                    end
                end
            end
        end
    end

    if amount ~= self.weaknessAmounts[weakness] then
        self:Log("Failed to update weaknesses for "..tostring(weakness))
    end

    Events:GlobalLuaEvent(Events.OnUpdateWeaknessAmount, weakness, amount)
    return true -- damage taken
end

function UiEnemy:HasWeaknesses()
    for weakness,amount in pairs(self.weaknessAmounts) do
        if amount > 0 then
            return true
        end
    end 
    return false
end

function UiEnemy:OnDeactivate()
    Events:Disconnect(self, Events.OnSetEnemy)
    Events:Disconnect(self, Events.OnTakeDamage)
end

return UiEnemy