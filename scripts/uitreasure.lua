local Utilities = require "scripts.utilities"
local Events = require "scripts.events"
local Easing = require "scripts.easing"

local UITreasure = {
    Properties = {
        Debug = true,
        RevealSequenceName = "reveal",
        CanvasHeight = 1080,
        CardRevealDuration = 1.5
    }
}

function UITreasure:OnActivate()
    Utilities:InitLogging(self, "UITreasure")

    Events:Connect(self, Events.ModifyCoinAmount)
    Events:Connect(self, Events.AddCards)

    self.cards = {}

    -- the UITreasure script is on the canvas entity
    self:Log("Starting sequence " .. self.Properties.RevealSequenceName)
    UiAnimationBus.Event.StartSequence(self.entityId, self.Properties.RevealSequenceName)

    for i=1,5 do
        local cardEntityId = UiCanvasBus.Event.FindElementByName(self.entityId, "Card"..tostring(i))
        UiElementBus.Event.SetIsEnabled(cardEntityId, false)
    end
end

function UITreasure:AddCards(cards)
    for _,card in pairs(cards) do
        table.insert(self.cards, card)
    end

    -- execute next tick to make sure cards are ready
    if self.tickListener == nil then
        self.tickListener = TickBus.Connect(self, 0)
    end
end


function UITreasure:HideAllChildren(parent)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        UiElementBus.Event.SetIsEnabled(children[i], false)
    end
end

function UITreasure:OnTick(deltaTime, scriptTime)
    self.tickListener:Disconnect()

    local cardWidth = 200
    -- getcanvassize is not exposed so use prop
    --local canvasHeight = UiTransform2dBus.Event.GetLocalHeight(self.entityId)
    local canvasHeight = self.Properties.CanvasHeight
    local width = cardWidth * #self.cards
    self:Log(width)
    local xOffset = (- width / 2)  - cardWidth / 2

    for i=1,5 do
        local cardEntityId = UiCanvasBus.Event.FindElementByName(self.entityId, "Card"..tostring(i))
        if cardEntityId ~= nil and cardEntityId:IsValid() then
            self:HideAllChildren(cardEntityId)

            if i <= #self.cards then
                UiElementBus.Event.SetIsEnabled(cardEntityId, true)

                local card = self.cards[i]
                local imageEntityId = UiElementBus.Event.FindChildByName(cardEntityId, card.type)
                if imageEntityId ~= nil and imageEntityId:IsValid() then
                    UiElementBus.Event.SetIsEnabled(imageEntityId, true)
                end
                local cardXOffset = xOffset + (i * cardWidth)
                local cardYOffset = canvasHeight
                UiTransformBus.Event.SetLocalPositionX(cardEntityId, cardXOffset)
                UiTransformBus.Event.SetLocalPositionY(cardEntityId, cardYOffset)
                UiTransformBus.Event.SetScale(cardEntityId, Vector2(0,0))
                
                self:Log("Revealing "..card.type)
                if card == nil then
                    self:Log("self.cards["..tostring(i).."] is nil")
                else
                    card.OnEasingUpdate = function(_card, jobId, value)
                        local yOffset = Math.Lerp(cardYOffset, 0.0, value)
                        local scale = Math.Lerp(0,0.7,value)
                        UiTransformBus.Event.SetLocalPositionY(_card.entityId, yOffset)

                        UiTransformBus.Event.SetScale(_card.entityId, Vector2(scale,scale))
                    end
                    card.entityId = cardEntityId
                    card.jobId = Easing:Ease(Easing.OutCubic, self.Properties.CardRevealDuration * 1000 + i * 250, 0, 1, card)
                end
            else
                UiElementBus.Event.SetIsEnabled(cardEntityId, false)
            end
        else
            self:Log("$4 Could not find Card" ..tostring(i))
        end
    end
end

function UITreasure:OnDeactivate()
    Events:Disconnect(self, Events.AddCards)
    Events:Disconnect(self, Events.ModifyCoinAmount)
end

return UITreasure