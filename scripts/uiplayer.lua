local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Easing = require "scripts.easing"

local UiPlayer = {
    Properties = {
        Debug = false,
        PlayerNumber = 1
    }
}
function UiPlayer:OnActivate()
    self.playerNumber = tostring(math.floor(self.Properties.PlayerNumber))
    Utilities:InitLogging(self, "UiPlayer"..self.playerNumber)
    self.player = "Player"..self.playerNumber
    self.anims = {}
    Events:Connect(self, Events.OnSetPlayerCard, self.player)
    Events:Connect(self, Events.OnCardDiscarded, self.player)
    Events:Connect(self, Events.OnCardUsed, self.player)
end

function UiPlayer:HideAllChildren(parent)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        UiElementBus.Event.SetIsEnabled(children[i], false)
    end
end

function UiPlayer:HideAllChildrenExcept(parent, skipEntityName)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        local name = UiElementBus.Event.GetName(children[i])
        if name ~= skipEntityName then
            UiElementBus.Event.SetIsEnabled(children[i], false)
        end
    end
end

function UiPlayer:OnCardUsed(cardIndex)
    self:FlashCard(cardIndex)
end

function UiPlayer:FlashCard(cardIndex)
    local entityId = UiElementBus.Event.FindChildByName(self.entityId, "Card"..tostring(cardIndex))
    if entityId == nil or not entityId:IsValid() then
        self:Log("$5 Card entity not found for index "..tostring(cardIndex))
        return
    end

    local fadeEntityId = UiElementBus.Event.FindChildByName(entityId, "White")
    if fadeEntityId == nil or not fadeEntityId:IsValid() then
        self:Log("$5 White fade entity not found for card index "..tostring(cardIndex))
        return
    end

    self:Log("OnCardUsed")
    UiElementBus.Event.SetIsEnabled(fadeEntityId, true)
    UiImageBus.Event.SetAlpha(fadeEntityId, 1.0)
    local anim = {
        FadeEntityId = fadeEntityId,
        Animating = true,
        Card = nil,
        UiPlayer = self
    }
    anim.OnEasingUpdate = function(_self, jobId, value)
        UiImageBus.Event.SetAlpha(_self.FadeEntityId, value)
    end
    anim.OnEasingEnd = function(_self, jobId)
        UiElementBus.Event.SetIsEnabled(_self.FadeEntityId, false)
        _self.Animating = false
    end
    anim.jobId = Easing:Ease(Easing.OutCubic, 1000, 1, 0 ,anim)
    self.anims["Card"..cardIndex] = anim
end

function UiPlayer:OnCardDiscarded(cardIndex)
    self:FlashCard(cardIndex)
end

function UiPlayer:OnSetPlayerCard(cardIndex, card)
    self:Log("OnSetPlayerCard " .. tostring(cardIndex))

    local entityId = UiElementBus.Event.FindChildByName(self.entityId, "Card"..tostring(cardIndex))
    if entityId == nil then
        self:Log("$5 Card entity not found for index "..tostring(cardIndex))
        return
    end

    if card ~= nil and card.color ~= nil then
        local anim = self.anims["Card"..cardIndex]
        if  anim ~= nil and anim.Animating then
            -- disable all except the animating entity
            self:HideAllChildrenExcept(entityId, "White")
        else
            UiElementBus.Event.SetIsEnabled(entityId, true)
            self:HideAllChildren(entityId)
        end

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
    Events:Disconnect(self, Events.OnSetPlayerCard, self.player)
    Events:Disconnect(self, Events.OnCardDiscarded, self.player)
    Events:Disconnect(self, Events.OnCardUsed, self.player)
end

return UiPlayer