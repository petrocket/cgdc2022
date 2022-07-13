
local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local UiPlayer = {
    Properties = {
        Debug = false,
        PlayerNumber = 1,
        Cards = {
            Card1 = EntityId(),
            Card2 = EntityId(),
            Card3 = EntityId(),
            Card4 = EntityId()
        }
    }
}
function UiPlayer:OnActivate()
    self.playerNumber = tostring(math.floor(self.Properties.PlayerNumber))
    Utilities:InitLogging(self, "UiPlayer"..self.playerNumber)
    Events:Connect(self, Events.OnSetPlayerCard, "Player"..self.playerNumber)
end

function UiPlayer:OnSetPlayerCard(cardIndex, card)
    self:Log("OnSetPlayerCard " .. tostring(cardIndex))
    local entityId = self.Properties.Cards["Card"..tostring(cardIndex)]
    if card ~= nil and card.color ~= nil then
        UiImageBus.Event.SetColor(entityId, card.color)
        UiElementBus.Event.SetIsEnabled(entityId, true)
    else
        UiElementBus.Event.SetIsEnabled(entityId, false)
    end
end

function UiPlayer:OnDeactivate()
    Events:Disconnect(self, Events.OnSetPlayerCard, "Player"..self.playerNumber)
end

return UiPlayer