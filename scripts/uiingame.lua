local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local UiInGame = {
    Properties = {
        Debug = false,
        PlayerCards = {
            default = {
                EntityId(), EntityId(), EntityId(), EntityId()
            }
        },
        EnemyCard = EntityId(),
        VerseChallenge = EntityId(),
    }
}

function UiInGame:OnActivate()
    Utilities:InitLogging(self, "UiInGame")

    Events:Connect(self, Events.OnSetEnemyCardVisible)
    Events:Connect(self, Events.OnSetPlayerCardsVisible)
    Events:Connect(self, Events.OnSetVerseChallengeVisible)
end

function UiInGame:OnSetEnemyCardVisible(visible)
    UiElementBus.Event.SetIsEnabled(self.Properties.EnemyCard, visible)
end

function UiInGame:OnSetVerseChallengeVisible(visible)
    UiElementBus.Event.SetIsEnabled(self.Properties.VerseChallenge, visible)
end

function UiInGame:OnSetPlayerCardsVisible(player, visible)
    self:Log("OnSetPlayerCardsVisible " .. tostring(player) .. " " .. tostring(#self.Properties.PlayerCards))
    if player > 0 and player <= #self.Properties.PlayerCards then
        local playerEntityId = self.Properties.PlayerCards[player]
        UiElementBus.Event.SetIsEnabled(playerEntityId, visible)
    end
end

function UiInGame:OnDeactivate()
    Events:Disconnect(self, Events.OnSetEnemyCardVisible)
    Events:Disconnect(self, Events.OnSetPlayerCardsVisible)
    Events:Disconnect(self, Events.OnSetVerseChallengeVisible)
end

return UiInGame