local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Card = require "scripts.card"

local UiEnemy = {
    Properties = {
        Debug = false,
        Name = EntityId(),
        Weaknesses = {
            Weakness1 = EntityId(),
            Weakness2 = EntityId(),
            Weakness3 = EntityId(),
            Weakness4 = EntityId()
        }
    }
}

function UiEnemy:OnActivate()
    Utilities:InitLogging(self, "UiEnemy")

    Events:Connect(self, Events.OnSetEnemy)
    Events:Connect(self, Events.OnTakeDamage)
end

function UiEnemy:OnSetEnemy(enemy)
    self:Log("Set Enemy " .. tostring(enemy.Name)) 
    UiTextBus.Event.SetText(self.Properties.Name, enemy.Name)
    for weakness, entityId in pairs(self.Properties.Weaknesses) do
        UiElementBus.Event.SetIsEnabled(entityId, false)
    end

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
    return damageTaken
end

function UiEnemy:GetWeaknessAmount(weakness)
    entityId, textEntityId = self:GetWeakness(weakness)
    if textEntityId and textEntityId:IsValid() and UiElementBus.Event.IsEnabled(textEntityId) then
        local amount = UiTextBus.Event.GetText(textEntityId)
        return math.floor(amount)
    end
    return 0
end

function UiEnemy:GetWeakness(weakness)
    for uiWeakness, entityId in pairs(self.Properties.Weaknesses) do 
        if weakness == uiWeakness then
            local textEntityId = UiElementBus.Event.FindDescendantByName(entityId, "Text")
            return entityId, textEntityId
        end
    end
    return nil, nil
end

function UiEnemy:UpdateWeaknessAmount(weakness, amount)
    local damageTaken = false
    entityId, textEntityId = self:GetWeakness(weakness)

    if entityId ~= nil and textEntityId ~= nil then
        self:Log("Update weakness ".. tostring(weakness) .. " amount to " .. tostring(amount)) 
        UiTextBus.Event.SetText(textEntityId, tostring(amount))
            
        if amount <= 0 then
            UiElementBus.Event.SetIsEnabled(entityId, false)
        else
            UiElementBus.Event.SetIsEnabled(entityId, true)
        end
        damageTaken = true 
        if not self:HasWeaknesses() then
            self:Log("No more weaknesses")
            Events:GlobalLuaEvent(Events.OnEnemyDefeated)
        else
            Events:GlobalLuaEvent(Events.OnUpdateWeaknessAmount, weakness, amount)
        end
    end
    return damageTaken
end

function UiEnemy:HasWeaknesses()
    for uiWeakness, entityId in pairs(self.Properties.Weaknesses) do 
        local textEntityId = UiElementBus.Event.FindDescendantByName(entityId, "Text")
        local amount = UiTextBus.Event.GetText(textEntityId)
        amount = math.floor(amount)
        local enabled = UiElementBus.Event.IsEnabled(entityId)
        if enabled and amount > 0 then
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