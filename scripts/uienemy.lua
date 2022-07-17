local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Card = require "scripts.card"
local Easing = require "scripts.easing"

local UiEnemy = {
    Properties = {
        Debug = false,
        Name = EntityId(),
        Weaknesses = EntityId(),
        Victory = EntityId(),
        WeaknessesPanel = EntityId()
    }
}

local WeaknessState = {
    Hidden="Hidden",
    Visible="Visible",
    FadingIn="FadingIn",
    FadingOut="FadingOut"
}

function UiEnemy:OnActivate()
    Utilities:InitLogging(self, "UiEnemy")

    Events:Connect(self, Events.OnSetEnemy)
    Events:Connect(self, Events.OnTakeDamage)
    self:Log("OnActivate")
    self.weaknessAmounts = {}
    self.weaknesses = {}
end

function UiEnemy:Reset()
    self:Log("Reset")
    self.weaknessAmounts = {}
    UiElementBus.Event.SetIsEnabled(self.Properties.WeaknessesPanel, true)
    UiElementBus.Event.SetIsEnabled(self.Properties.Victory, false)
    local weaknesses = UiElementBus.Event.GetChildren(self.Properties.Weaknesses)
    for i=1,#weaknesses do
        -- get the entity by name to preserve order
        local entityId = UiElementBus.Event.FindChildByName(self.Properties.Weaknesses, "Weakness"..tostring(i))

        self.weaknesses[i] = {
            EntityId=entityId,
            State=WeaknessState.Hidden
        }
        self:HideAllChildren(entityId)
        UiElementBus.Event.SetIsEnabled(entityId, false)
    end
end

function UiEnemy:HideAllChildren(parent)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        UiElementBus.Event.SetIsEnabled(children[i], false)
    end
end

function UiEnemy:OnSetEnemy(enemy)
    self:Log("Set " .. tostring(enemy.Name) .. " with " ..tostring(Utilities:Count(enemy.Weaknesses)).. " weaknesses")
    UiTextBus.Event.SetText(self.Properties.Name, enemy.Name)

    self:Reset()

    local victoryText = UiElementBus.Event.FindChildByName(self.Properties.Victory,"Text")
    UiTextBus.Event.SetText(victoryText, "Defeated " .. enemy.Name)


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
            if self:UpdateWeaknessAmount(weakness, currentAmount - amount) then
                damageTaken = true
            end
        end
    end

    if not self:HasWeaknesses() then
        self:Log("No more weaknesses")
        Events:GlobalLuaEvent(Events.OnEnemyDefeated)
        UiElementBus.Event.SetIsEnabled(self.Properties.Victory, true)
        UiElementBus.Event.SetIsEnabled(self.Properties.WeaknessesPanel, false)
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
        --self:Log("Initializing to 0 - " ..tostring(weakness))
        self.weaknessAmounts[weakness] = 0
    end

    if self.weaknessAmounts[weakness] < 0 then
        self:Log("$5 Trying to set weakness amount less than 0 for weakness " ..tostring(weakness))
        return false
    end

    local weaknesses = UiElementBus.Event.GetChildren(self.Properties.Weaknesses)
    --self:Log("UpdateWeaknessAmount " .. tostring(weakness) .. " " ..tostring(amount))

    if amount > self.weaknessAmounts[weakness] then
        -- append to end 

        for i=1,#weaknesses do
            local _weakness = self.weaknesses[i]
            if _weakness.State == WeaknessState.Hidden then
                local entityId = _weakness.EntityId
                -- look for an image element with the name that matches the weakness
                local child = UiElementBus.Event.FindChildByName(entityId, weakness)
                if child ~= nil and child:IsValid() then
                    UiElementBus.Event.SetIsEnabled(entityId, true)
                    UiElementBus.Event.SetIsEnabled(child, true)
                    self.weaknessAmounts[weakness] = self.weaknessAmounts[weakness] + 1
                    self:Log("Enabled weakness " ..weakness)

                    _weakness.State = WeaknessState.Visible

                    if self.weaknessAmounts[weakness] == amount then
                        -- done removing weaknesses
                        break
                    end
                else
                    self:Log("$5 Failed to find child for weakness " ..tostring(weakness))
                end
            end
        end
    elseif amount < self.weaknessAmounts[weakness] then
        -- remove from end
        for i=#weaknesses, 1, -1 do
            local _weakness = self.weaknesses[i]
            if _weakness.State == WeaknessState.Visible then
                local entityId = _weakness.EntityId
                -- look for an image element with the name that matches the weakness
                local child = UiElementBus.Event.FindChildByName(entityId, weakness)
                if child ~= nil and child:IsValid() then
                    local childIsEnabled = UiElementBus.Event.IsEnabled(child)
                    if childIsEnabled then
                        UiElementBus.Event.SetIsEnabled(child, false)
                        self.weaknessAmounts[weakness] = self.weaknessAmounts[weakness] - 1
                        self:Log("Disabled weakness " ..weakness)
                        _weakness.State = WeaknessState.FadingOut
                        _weakness.FadeEntityId = UiElementBus.Event.FindChildByName(entityId, "White")

                        -- enable the white overlay
                        UiElementBus.Event.SetIsEnabled(_weakness.FadeEntityId, true)
                        UiImageBus.Event.SetAlpha(_weakness.FadeEntityId, 1.0)
                        _weakness.OnEasingUpdate = function(_self, jobId, value)
                            -- fade out the weakness
                            UiImageBus.Event.SetAlpha(_self.FadeEntityId, value)
                        end
                        _weakness.OnEasingEnd = function(_self, jobId)
                            -- disable the weakness after fadeout
                            UiElementBus.Event.SetIsEnabled(_self.EntityId, false)
                            _self.State = WeaknessState.Hidden
                        end
                        _weakness.jobId = Easing:Ease(Easing.OutCubic, 1000, 1, 0 ,_weakness)

                        if self.weaknessAmounts[weakness] == amount then
                            -- done removing weaknesses
                            break 
                        end
                    end
                end
            end
        end
    else
        self:Log("Enemy weakness "..tostring(weakness) .. " already set to " .. tostring(amount))
    end

    if amount ~= self.weaknessAmounts[weakness] then
        self:Log("$5 Failed to update weaknesses for "..tostring(weakness))
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