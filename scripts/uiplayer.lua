local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local UiPlayer = {
    Properties = {
        Debug = false,
        PlayerNumber = 1
    }
}
function UiPlayer:OnActivate()
    self.playerNumber = tostring(math.floor(self.Properties.PlayerNumber))
    Utilities:InitLogging(self, "UiPlayer"..self.playerNumber)
    Events:Connect(self, Events.OnSetPlayerCard, "Player"..self.playerNumber)
end

function UiPlayer:HideAllChildren(parent)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        UiElementBus.Event.SetIsEnabled(children[i], false)
    end
end

function UiPlayer:OnSetPlayerCard(cardIndex, card)
    self:Log("OnSetPlayerCard " .. tostring(cardIndex))

    local entityId = UiElementBus.Event.FindChildByName(self.entityId, "Card"..tostring(cardIndex))
    if entityId == nil then
        self:Log("Card entity not found for index "..tostring(cardIndex))
        return
    end

    if card ~= nil and card.color ~= nil then
        UiElementBus.Event.SetIsEnabled(entityId, true)
        self:HideAllChildren(entityId)
        local child = UiElementBus.Event.FindChildByName(entityId, card.type)
        if child ~= nil and child:IsValid() then
            --self:Log("Found card image of type " .. tostring(card.type))
            UiElementBus.Event.SetIsEnabled(child, true)
        else
            self:Log("$7 Did not find card image of type " .. tostring(card.type))
        end

        child  = UiElementBus.Event.FindChildByName(entityId, "Text")
        if child ~= nil and child:IsValid() then
            UiElementBus.Event.SetIsEnabled(child, true)
        end 

        UiImageBus.Event.SetColor(entityId, card.color)
    else
        UiElementBus.Event.SetIsEnabled(entityId, false)
    end
end

function UiPlayer:OnDeactivate()
    Events:Disconnect(self, Events.OnSetPlayerCard, "Player"..self.playerNumber)
end

return UiPlayer